//
//  WindowManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/14/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import AppKit
import Carbon
import Foundation
import RxSwift
import Silica
import SwiftyJSON

enum TrackingError: Error {
    case unreliableFloating
    case unknownScreen
    case unknownSpace
    case alreadyTracked
}

/**
 The tolerant interval between the click and the application of a mouse move from focus.
 
 - Note:
 
 At the time of the check we confirm that the mouse is not _currently_ clicked. However, it is possible that the click happened faster than the focus notification could be processed so that when we process the focus the mouse is no longer clicked. In this case we could incorrectly move the mouse to the center of the focused window.
 
 This value is an approximation of the time between a fast click and the focus event being processed. For values larger than this we would expect the mouse to still be clicked.
 */
private let mouseMoveClickSpeedTolerance: TimeInterval = 0.3

final class WindowManager<Application: ApplicationType>: NSObject, Codable {
    typealias Window = Application.Window
    typealias Screen = Window.Screen

    private struct UndeterminedApplication {
        let application: NSRunningApplication
        let activationPolicyObservation: NSKeyValueObservation?
        let isFinishedLaunchingObservation: NSKeyValueObservation?

        func invalidate() {
            activationPolicyObservation?.invalidate()
            isFinishedLaunchingObservation?.invalidate()
        }
    }

    enum CodingKeys: String, CodingKey {
        case screens
    }

    let windowTransitionCoordinator: WindowTransitionCoordinator<WindowManager<Application>>
    let focusTransitionCoordinator: FocusTransitionCoordinator<WindowManager<Application>>

    private var applications: [pid_t: AnyApplication<Application>] = [:]
    private var applicationObservations: [pid_t: UndeterminedApplication] = [:]
    private var screens: Screens
    private let windows = Windows()
    private var lastReflowTime = Date()

    /// Coalesces multiple reflow requests within the same RunLoop cycle into a single pass.
    private var reflowPending = false

    private lazy var mouseStateKeeper = MouseStateKeeper(delegate: self)
    private lazy var applicationEventHandler = ApplicationEventHandler(delegate: self)
    private let userConfiguration: UserConfiguration
    private let disposeBag = DisposeBag()

    init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        self.screens = Screens()
        self.windowTransitionCoordinator = WindowTransitionCoordinator<WindowManager<Application>>()
        self.focusTransitionCoordinator = FocusTransitionCoordinator<WindowManager<Application>>(userConfiguration: userConfiguration)
        super.init()
        initialize()
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.screens = try values.decode(Screens.self, forKey: .screens)
        self.userConfiguration = UserConfiguration.shared
        self.windowTransitionCoordinator = WindowTransitionCoordinator<WindowManager<Application>>()
        self.focusTransitionCoordinator = FocusTransitionCoordinator<WindowManager<Application>>(userConfiguration: userConfiguration)
        super.init()
        initialize()
    }

    private func initialize() {
        windowTransitionCoordinator.target = self
        focusTransitionCoordinator.target = self

        addWorkspaceNotificationObserver(NSWorkspace.didHideApplicationNotification, selector: #selector(applicationDidHide(_:)))
        addWorkspaceNotificationObserver(NSWorkspace.didUnhideApplicationNotification, selector: #selector(applicationDidUnhide(_:)))
        addWorkspaceNotificationObserver(NSWorkspace.activeSpaceDidChangeNotification, selector: #selector(activeSpaceDidChange(_:)))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        installApplicationMonitor()

        // updateScreens must run before reevaluateWindows so that screenManagers exist and
        // have their spaces set before windows are tracked and the first reflow is scheduled.
        screens.updateScreens(windowManager: self)
        reevaluateWindows()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Reflow

    /// Schedule a reflow pass, coalescing multiple calls within the same RunLoop cycle.
    ///
    /// Multiple window events firing in quick succession (e.g., focus + mainWindowChanged during a
    /// tab switch, or multiple events during a space transition) produce a single reflow instead of
    /// 3-4 overlapping ones. Layouts are stateless and derive everything from the current window
    /// list, so a reflow simply refreshes the active window cache and re-applies layouts.
    func scheduleReflow() {
        log.debug("Reflow scheduled (pending: \(reflowPending))")
        guard !reflowPending else {
            return
        }
        reflowPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reflowPending = false
            self.windows.regenerateActiveIDCache()
            self.markAllScreensForReflow()
        }
    }

    /// Query the system for current on-screen window IDs.
    private func querySystemWindowIDs() -> Set<CGWindowID> {
        return CGWindowsInfo<Window>(options: .optionOnScreenOnly, windowID: CGWindowID(0))?.activeIDs() ?? []
    }

    func reset() {
        screens = Screens()
        screens.updateScreens(windowManager: self)
        reevaluateWindows()
    }

    private func addWorkspaceNotificationObserver(_ name: NSNotification.Name, selector: Selector) {
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        workspaceNotificationCenter.addObserver(self, selector: selector, name: name, object: nil)
    }

    @objc func applicationActivated(_ sender: AnyObject) {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return
        }
        recordLastFocusedWindow(focusedWindow, on: screen)
        scheduleReflow()
    }

    @objc func applicationDidLaunch(_ notification: Notification) {
        guard let launchedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        add(runningApplication: launchedApplication)
    }

    @objc func applicationDidTerminate(_ notification: Notification) {
        guard let terminatedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithPID(terminatedApplication.processIdentifier) else {
            return
        }

        remove(application: application)
    }

    @objc func applicationDidHide(_ notification: Notification) {
        guard let hiddenApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithPID(hiddenApplication.processIdentifier) else {
            return
        }

        deactivate(application: application)
    }

    @objc func applicationDidUnhide(_ notification: Notification) {
        guard let unhiddenApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithPID(unhiddenApplication.processIdentifier) else {
            return
        }

        application.dropWindowsCache()
        for window in application.windows() {
            add(window: window)
        }
        activate(application: application)
    }

    @objc func activeSpaceDidChange(_ notification: Notification) {
        // Update spaces across screens so that windows get assigned to the correct layouts
        screens.updateSpaces()

        // Re-track windows from all applications on the new space
        for runningApplication in NSWorkspace.shared.runningApplications {
            let pid = runningApplication.processIdentifier
            guard let application = applicationWithPID(pid) else {
                continue
            }

            application.dropWindowsCache()

            for window in application.windows() {
                add(window: window)
            }
        }

        // Coalesce the reflow with any AX events that fire during the space transition
        scheduleReflow()
    }

    @objc func screenParametersDidChange(_ notification: Notification) {
        screens.updateScreens(windowManager: self)
    }
}

extension WindowManager: ApplicationEventHandlerDelegate {
    private func installApplicationMonitor() {
        let target = GetApplicationEventTarget()
        let launchedEventSpec = EventTypeSpec(eventClass: OSType(kEventClassApplication), eventKind: OSType(kEventAppLaunched))
        let terminatedEventSpec = EventTypeSpec(eventClass: OSType(kEventClassApplication), eventKind: OSType(kEventAppTerminated))
        var eventSpecs = [launchedEventSpec, terminatedEventSpec]
        let eventHandler = UnsafeMutableRawPointer(Unmanaged.passUnretained(applicationEventHandler).toOpaque())
        let error = InstallEventHandler(target, applicationEventHandlerUPP, 2, &eventSpecs, eventHandler, nil)

        if error != noErr {
            log.error("error installing app launch monitor: \(error)")
        }
    }

    func add(applicationWithPID pid: pid_t) {
        guard let runningApplication = NSRunningApplication(processIdentifier: pid) else {
            log.warning("process launched with no application: \(pid)")
            return
        }

        add(runningApplication: runningApplication)
    }

    func remove(applicationWithPID pid: pid_t) {
        guard let application = applicationWithPID(pid) else {
            log.warning("process terminated with no application: \(pid)")
            return
        }

        remove(application: application)
    }
}

extension WindowManager {
    func preferencesDidClose() {
        DispatchQueue.main.async {
            self.focusTransitionCoordinator.focusScreen(at: 0)
        }
    }

    func focusedScreenManager() -> ScreenManager<WindowManager<Application>>? {
        return screens.focusedScreenManager()
    }

    fileprivate func applicationWithPID(_ pid: pid_t) -> AnyApplication<Application>? {
        return applications[pid]
    }

    fileprivate func add(application: AnyApplication<Application>) {
        guard applications[application.pid()] == nil else {
            for window in application.windows() {
                add(window: window)
            }
            return
        }

        ApplicationObservation(application: application, delegate: self)
            .addObservers()
            .subscribe(
                onCompleted: { [weak self] in
                    self?.applications[application.pid()] = application

                    for window in application.windows() {
                        self?.add(window: window)
                    }
                }
            )
            .disposed(by: disposeBag)
    }

    fileprivate func remove(application: AnyApplication<Application>) {
        for window in application.windows() {
            remove(window: window)
        }
        applications.removeValue(forKey: application.pid())
        windows.clearTrackedMainWindow(forPID: application.pid())
    }

    fileprivate func activate(application: AnyApplication<Application>) {
        windows.activateApplication(withPID: application.pid())
        scheduleReflow()
    }

    fileprivate func deactivate(application: AnyApplication<Application>) {
        windows.deactivateApplication(withPID: application.pid())
        scheduleReflow()
    }

    fileprivate func remove(window: Window) {
        log.debug("Removing window: \(window)")
        windows.clearTrackedMainWindow(forWindow: window)
        clearLastFocusedWindowAcrossScreens(window)
        windows.remove(window: window)
        scheduleReflow()
    }

    func toggleFloatForFocusedWindow() {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return
        }

        guard windows.windows(onScreen: screen).contains(focusedWindow) else {
            add(window: focusedWindow)
            guard windows.window(withID: focusedWindow.id()) != nil else {
                return
            }
            windows.setFloating(false, forWindow: focusedWindow)
            scheduleReflow()
            return
        }

        windows.setFloating(!windows.isWindowFloating(focusedWindow), forWindow: focusedWindow)
        scheduleReflow()
    }

    /// Update the last-focused window for the screen containing `window`. Used by
    /// "focus main" to toggle back to the previously focused window.
    private func recordLastFocusedWindow(_ window: Window, on screen: Screen) {
        screenManager(for: screen)?.setLastFocusedWindow(window)
    }

    /// Clear the last-focused window on any screen that referenced it (e.g. on removal).
    private func clearLastFocusedWindowAcrossScreens(_ window: Window) {
        for screenManager in screens.screenManagers where screenManager.lastFocusedWindow == window {
            screenManager.setLastFocusedWindow(nil)
        }
    }

    func markAllScreensForReflow() {
        screens.markAllScreensForReflow()
    }

    func displayCurrentLayout() {
        for screenManager in screens.screenManagers {
            screenManager.displayLayoutHUD()
        }
    }

    func displayWindowCountHUD() {
        guard userConfiguration.enablesWindowCountHUD() else {
            return
        }

        for screenManager in screens.screenManagers {
            let currentCount = userConfiguration.windowMaxCount() ?? 0
            let countText = currentCount == 0 ? "Unlimited" : "\(currentCount)"
            let title = "Window Max Count: \(countText)"
            screenManager.displayCustomHUD(title: title)
        }
    }

    func add(runningApplication: NSRunningApplication) {
        switch runningApplication.isManageable {
        case .manageable:
            let application = AnyApplication(Application(runningApplication: runningApplication))
            add(application: application)
        case .undetermined:
            monitorUndeterminedApplication(runningApplication)
        case .unmanageable:
            break
        }
    }

    func monitorUndeterminedApplication(_ runningApplication: NSRunningApplication) {
        let pid = runningApplication.processIdentifier

        if let previousApplication = applicationObservations[pid] {
            previousApplication.invalidate()
            applicationObservations.removeValue(forKey: pid)
        }

        let activationPolicyObservation = runningApplication.observe(\.activationPolicy) { [weak self] runningApplication, change in
            guard case .setting = change.kind else {
                return
            }

            if runningApplication.activationPolicy == .regular {
                self?.applicationObservations[runningApplication.processIdentifier]?.invalidate()
                self?.applicationObservations.removeValue(forKey: runningApplication.processIdentifier)
                self?.add(runningApplication: runningApplication)
            }
        }

        let isFinishedLaunchingObservation = runningApplication.observe(\.isFinishedLaunching) { [weak self] runningApplication, change in
            guard case .setting = change.kind else {
                return
            }

            if runningApplication.isFinishedLaunching {
                self?.applicationObservations[runningApplication.processIdentifier]?.invalidate()
                self?.applicationObservations.removeValue(forKey: runningApplication.processIdentifier)
                self?.add(runningApplication: runningApplication)
            }
        }

        applicationObservations[pid] = UndeterminedApplication(
            application: runningApplication,
            activationPolicyObservation: activationPolicyObservation,
            isFinishedLaunchingObservation: isFinishedLaunchingObservation
        )
    }

    func reevaluateWindows() {
        for runningApplication in NSWorkspace.shared.runningApplications {
            add(runningApplication: runningApplication)
        }
        scheduleReflow()
    }

    private func add(window: Window, afterWindow otherWindow: Window? = nil) {
        log.debug("Adding window: \(window)")
        guard window.shouldBeManaged() else {
            log.debug("Window should not be managed: \(window)")
            return
        }

        guard let application = applicationWithPID(window.pid()) else {
            log.error("Tried to add a window without an application: \(window)")
            return
        }

        defer {
            windows.regenerateActiveIDCache()
        }

        guard !windows.isWindowTracked(window) else {
            log.debug("Window was already tracked: \(window)")
            return
        }

        ApplicationObservation(application: application, delegate: self)
            .addObserversForWindow(window)
            .map { try self.determineFloatForWindow(window, application: application, force: false) }
            .retry { error in
                error.enumerated().flatMap { count, error -> Observable<Int> in
                    guard error is TrackingError, count < 6 else {
                        return .error(error)
                    }

                    log.debug("error in determining float for window: \(window) - \(error)")
                    return .timer(.milliseconds((count ^ 2 * 100)), scheduler: MainScheduler.instance)
                }
            }
            .catch { error in
                guard error is TrackingError else {
                    throw error
                }
                log.debug("forcing float for window: \(window)")
                try self.determineFloatForWindow(window, application: application, force: true)
                return .just(())
            }
            .map { try self.track(window: window, application: application, afterWindow: otherWindow) }
            .retry { error in
                error.enumerated().flatMap { count, error -> Observable<Int> in
                    guard error is TrackingError, count < 6 else {
                        return .error(error)
                    }

                    log.debug("encountered an error trying to track window: \(error)")
                    return .timer(.milliseconds((count ^ 2 * 100)), scheduler: MainScheduler.instance)
                }
            }
            .subscribe()
            .disposed(by: disposeBag)
    }

    private func determineFloatForWindow(_ window: Window, application: AnyApplication<Application>, force: Bool) throws {
        switch application.defaultFloatForWindow(window) {
        case .unreliable where !force:
            throw TrackingError.unreliableFloating
        case .reliable(.floating), .unreliable(.floating):
            windows.setFloating(true, forWindow: window)
        case .reliable(.notFloating), .unreliable(.notFloating):
            windows.setFloating(false, forWindow: window)
        }
    }

    private func track(window: Window, application: AnyApplication<Application>, afterWindow otherWindow: Window? = nil) throws {
        guard !windows.isWindowTracked(window) else {
            log.warning("Trying to track a window that is already tracked: \(window)")
            throw TrackingError.alreadyTracked
        }

        guard window.screen() != nil else {
            throw TrackingError.unknownScreen
        }

        guard CGWindowsInfo.windowSpace(window) != nil else {
            throw TrackingError.unknownSpace
        }

        // Layouts are stateless and derive their windows from `activeWindows(onScreen:)`, which
        // already filters by current space / active / not-hidden / not-floating at reflow time.
        // So tracking just needs to maintain the master window list; off-screen, other-space, and
        // floating windows are excluded from layouts automatically.
        //
        // Tab swap: when a new window replaces a departed tab, take the departed window's slot in
        // the list so the layout keeps the tile stable. Guard on the departed window still being
        // tracked — the async add pipeline can race with an AX destruction notification that
        // removes it before track() runs (replacing against a gone window corrupts the list).
        if let otherWindow = otherWindow, windows.isWindowTracked(otherWindow) {
            windows.replace(window: window, withWindow: otherWindow)
            windows.recordTrackedMainWindow(window)
        } else {
            windows.add(window: window, atFront: userConfiguration.sendNewWindowsToMainPane())
            if !windows.isWindowFloating(window) {
                windows.recordTrackedMainWindow(window)
            }
        }

        scheduleReflow()
    }

    func onReflowInitiation() {
        mouseStateKeeper.handleReflowEvent()
    }

    func onReflowCompletion() {
//        if let focusedWindow = Window.currentlyFocused() {
//            doMouseFollowsFocus(focusedWindow: focusedWindow)
//        }

        // This handler will be executed by the Operation, in a queue.  Although async
        // (and although the docs say that it executes in a separate thread), I consider
        // this to be thread safe, at least safe enough, because we always want the
        // latest time that a reflow took place.
        mouseStateKeeper.handleReflowEvent()
        lastReflowTime = Date()
    }

    func doMouseFollowsFocus(focusedWindow: Window) {
        guard UserConfiguration.shared.mouseFollowsFocus() else {
            return
        }

        guard NSEvent.pressedMouseButtons == 0 else {
            // If a mouse button is pressed, then the user is probably dragging something between windows. Do not move the mouse.
            return
        }

        // See the description of mouseMoveClickSpeedTolerance for details.
        if let interval = mouseStateKeeper.lastClick?.timeIntervalSinceNow, abs(interval) < mouseMoveClickSpeedTolerance {
            return
        }

        if focusTransitionCoordinator.recentlyTriggeredFocusFollowsMouse() {
            // If we have recently triggered focus-follows-mouse, then disable mouse-follows-focus. Otherwise, the moment
            // focus-follows-mouse is triggered, the mouse will jump to the center of the focused window.
            return
        }

        let windowFrame = focusedWindow.frame()
        let mouseCursorPoint = NSPoint(x: windowFrame.midX, y: windowFrame.midY)
        if let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: mouseCursorPoint, mouseButton: .left) {
            mouseMoveEvent.flags = CGEventFlags(rawValue: 0)
            mouseMoveEvent.post(tap: CGEventTapLocation.cghidEventTap)
        }
    }
}

extension WindowManager: MouseStateKeeperDelegate {
    func recommendMainPaneRatio(_ ratio: CGFloat) {
        guard let screenManager: ScreenManager<WindowManager<Application>> = focusedScreenManager() else { return }

        screenManager.updateCurrentLayout { layout in
            if let panedLayout = layout as? PanedLayout {
                panedLayout.recommendMainPaneRatio(ratio)
            }
        }
    }

    func swapDraggedWindowWithDropzone(_ draggedWindow: Window) {
        guard let screen = draggedWindow.screen() else { return }

        let windows: [Window] = self.windows.windows(onScreen: screen)

        // need to flip mouse coordinate system to fit Amethyst https://stackoverflow.com/a/45289010/2063546
        let flippedPointerLocation = NSPointToCGPoint(NSEvent.mouseLocation)
        let unflippedY = Screen.globalHeight() - flippedPointerLocation.y + screen.frameIncludingDockAndMenu().origin.y
        let pointerLocation = NSPointToCGPoint(NSPoint(x: flippedPointerLocation.x, y: unflippedY))

        if let screenManager: ScreenManager<WindowManager<Application>> = focusedScreenManager(), let layout = screenManager.currentLayout {
            let windowSet = self.windows.windowSet(forWindowsOnScreen: screen)
            if let layoutWindow = layout.windowAtPoint(pointerLocation, of: windowSet, on: screen), let framedWindow = self.windows.window(withID: layoutWindow.id) {
                executeTransition(.switchWindows(draggedWindow, framedWindow))
                return
            }
        }

        // Ignore if there is no window at that point
        guard let secondWindow = WindowsInformation.alternateWindowForScreenAtPoint(pointerLocation, withWindows: windows, butNot: draggedWindow) else {
            return
        }
        executeTransition(.switchWindows(draggedWindow, secondWindow))
    }
}

// MARK: ApplicationObservationDelegate
extension WindowManager: ApplicationObservationDelegate {
    func application(_ application: AnyApplication<Application>, didAddWindow window: Window) {
        add(window: window)
    }

    func application(_ application: AnyApplication<Application>, didRemoveWindow window: Window) {
        remove(window: window)
    }

    func application(_ application: AnyApplication<Application>, didFocusWindow window: Window) {
        guard let screen = window.screen() else {
            return
        }

        if windows.isWindowTracked(window) {
            windows.recordTrackedMainWindow(window)
            recordLastFocusedWindow(window, on: screen)
        }

        scheduleReflow()
    }

    func application(_ application: AnyApplication<Application>, didFindPotentiallyNewWindow window: Window) {
        if windows.isWindowTracked(window) {
            // Tracked window became main -- record it as focused and as the main window
            // so the next untracked-main-window event for this PID can resolve to it.
            windows.recordTrackedMainWindow(window)
            if let screen = window.screen() {
                recordLastFocusedWindow(window, on: screen)
            }
            scheduleReflow()
            return
        }

        let pid = window.pid()
        let departedWindow = classifyDepartedTab(forPID: pid, newWindow: window)

        if let departedWindow = departedWindow {
            log.debug("Tab switch detected: \(departedWindow) -> \(window)")
            add(window: window, afterWindow: departedWindow)
        } else {
            log.debug("New window (not a tab switch): \(window)")
            add(window: window)
        }
    }

    /// Pick the previously-tracked window of `pid` that the new untracked main window is
    /// replacing, if any. Priority order:
    /// 1. The recorded `lastTrackedMainWindow[pid]` — but only if its `cgID` is no longer
    ///    on-screen, signalling a real tab departure rather than a focus switch between
    ///    two simultaneously-visible windows of a multi-window app (e.g. VS Code).
    /// 2. A tracked window for the PID whose `cgID` has dropped off the on-screen list.
    /// 3. None — caller treats `newWindow` as a fresh window.
    private func classifyDepartedTab(forPID pid: pid_t, newWindow: Window) -> Window? {
        let activeIDs = querySystemWindowIDs()

        if let recorded = windows.trackedMainWindow(forPID: pid),
           recorded.id() != newWindow.id(),
           windows.isWindowTracked(recorded),
           !activeIDs.contains(recorded.cgID()) {
            log.debug("Tab classification: using recorded main window \(recorded) for pid \(pid) (off-screen)")
            return recorded
        }

        let trackedForPID = windows.windows(forApplicationWithPID: pid)
        let departed = trackedForPID.first { !activeIDs.contains($0.cgID()) }
        log.debug("Tab classification for pid \(pid): \(trackedForPID.count) tracked, \(activeIDs.count) active on screen, departed=\(departed.map(String.init(describing:)) ?? "nil")")
        return departed
    }

    func application(_ application: AnyApplication<Application>, didMoveWindow window: Window) {
        guard userConfiguration.mouseSwapsWindows() else {
            return
        }

        guard let screen = window.screen(), activeWindows(on: screen).contains(window) else {
            return
        }

        switch mouseStateKeeper.state {
        case .dragging:
            // be aware of last reflow time, again to prevent race condition
            let reflowEndInterval = Date().timeIntervalSince(lastReflowTime)
            guard reflowEndInterval > mouseStateKeeper.dragRaceThresholdSeconds else { break }

            // record window and wait for mouse up
            mouseStateKeeper.state = .moving(window: window)
        case let .doneDragging(lmbUpMoment):
            mouseStateKeeper.state = .pointing // flip state first to prevent race condition

            // if mouse button recently came up, assume window move is related
            let dragEndInterval = Date().timeIntervalSince(lmbUpMoment)
            guard dragEndInterval < mouseStateKeeper.dragRaceThresholdSeconds else { break }

            mouseStateKeeper.swapDraggedWindowWithDropzone(window)
        default:
            break
        }
    }

    func application(_ application: AnyApplication<Application>, didResizeWindow window: Window) {
        guard userConfiguration.mouseResizesWindows() else {
            return
        }

        guard let screen = window.screen(), activeWindows(on: screen).contains(window) else {
            return
        }

        guard
            let screenManager: ScreenManager<WindowManager<Application>> = focusedScreenManager(),
            let layout = screenManager.currentLayout,
            layout is PanedLayout
        else {
            return
        }

        guard let oldFrame = layout.assignedFrame(window, of: windows.windowSet(forActiveWindowsOnScreen: screen), on: screen) else {
            return
        }

        let ratio = oldFrame.impliedMainPaneRatio(windowFrame: window.frame())

        switch mouseStateKeeper.state {
        case .dragging, .resizing:
            // record window and wait for mouse up
            mouseStateKeeper.state = .resizing(screen: screen, ratio: ratio)
        case let .doneDragging(lmbUpMoment):
            // if mouse button recently came up, assume window resize is related
            let dragEndInterval = Date().timeIntervalSince(lmbUpMoment)
            if dragEndInterval < mouseStateKeeper.dragRaceThresholdSeconds {
                mouseStateKeeper.state = .pointing // flip state first to prevent race condition

                if let screenManager: ScreenManager<WindowManager<Application>> = focusedScreenManager() {
                    screenManager.updateCurrentLayout { layout in
                        if let panedLayout = layout as? PanedLayout {
                            panedLayout.recommendMainPaneRatio(ratio)
                        }
                    }
                }
            }
        default:
            break
        }
    }

    func applicationDidActivate(_ application: AnyApplication<Application>) {
        // Reflow coalescing replaces the previous 0.2s delay hack.
        // Multiple activation events within the same RunLoop cycle produce a single reflow pass.
        scheduleReflow()
    }
}

// MARK: Transition Coordination
extension WindowManager {
    func screen(at index: Int) -> Screen? {
        return screenManager(at: index)?.screen
    }

    func screenManager(at screenIndex: Int) -> ScreenManager<WindowManager<Application>>? {
        guard screenIndex > -1 && screenIndex < screens.screenManagers.count else {
            return nil
        }

        return screens.screenManagers[screenIndex]
    }

    func screenManager(for screen: Screen) -> ScreenManager<WindowManager<Application>>? {
        return screens.screenManagers.first { $0.screen?.screenID() == screen.screenID() }
    }

    func screenManagerIndex(for screen: Screen) -> Int? {
        return screens.screenManagers.firstIndex { $0.screen?.screenID() == screen.screenID() }
    }
}

// MARK: Window Transition
extension WindowManager: WindowTransitionTarget {
    func executeTransition(_ transition: WindowTransition<Window>) {
        switch transition {
        case let .switchWindows(window, otherWindow):
            guard windows.swap(window: window, withWindow: otherWindow) else {
                return
            }

            scheduleReflow()
        case let .moveWindowToScreen(window, screen):
            // Layouts derive their windows from `window.screen()`, so moving the window updates
            // both the source and destination layouts on the next reflow automatically.
            window.moveScaled(to: screen)
            window.focus()
            scheduleReflow()
        case let .moveWindowToSpaceAtIndex(window, spaceIndex, sourceSpaceIndex):
            guard
                let screen = window.screen(),
                let spaces = CGSpacesInfo<Window>.spacesForAllScreens(includeOnlyUserSpaces: true),
                spaceIndex < spaces.count
            else {
                return
            }

            let targetSpace = spaces[spaceIndex]
            guard let targetScreen = CGSpacesInfo<Window>.screenForSpace(space: targetSpace) else {
                return
            }
            window.move(toSpaceAtIndex: UInt(spaceIndex + 1))
            // The window leaves the current space immediately; the target space picks it up via
            // `activeSpaceDidChange` when activated. Reflow the source now.
            scheduleReflow()
            if targetScreen.screenID() != screen.screenID() {
                // necessary to set frame here as window is expected to be at origin relative to targe screen when moved, can be improved.
                window.moveScaled(to: targetScreen)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if !UserConfiguration.shared.followWindowsThrownBetweenSpaces() {
                    SISystemWideElement.switch(toSpace: UInt(sourceSpaceIndex + 1))
                }
            }
        case .resetFocus:
            if let screen = screens.screenManagers.first?.screen {
                executeTransition(.focusScreen(screen))
            }
        }
    }

    func isWindowFloating(_ window: Window) -> Bool {
        return windows.isWindowFloating(window)
    }

    func currentLayout() -> Layout<Application.Window>? {
        return focusedScreenManager()?.currentLayout
    }

    func activeWindows(on screen: Screen) -> [Window] {
        return windows.activeWindows(onScreen: screen).filter { window in
            return window.shouldBeManaged() && !self.windows.isWindowFloating(window)
        }
    }

    func nextScreenIndexClockwise(from screen: Screen) -> Int {
        guard let screenManagerIndex = self.screenManagerIndex(for: screen) else {
            return -1
        }

        return (screenManagerIndex + 1) % (screens.screenManagers.count)
    }

    func nextScreenIndexCounterClockwise(from screen: Screen) -> Int {
        guard let screenManagerIndex = self.screenManagerIndex(for: screen) else {
            return -1
        }

        return (screenManagerIndex == 0 ? screens.screenManagers.count - 1 : screenManagerIndex - 1)
    }

    func lastMainWindowForCurrentSpace() -> Window? {
        guard let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(),
              let lastMainWindow = windows.lastMainWindows[currentFocusedSpace.id]
        else {
            return nil
        }
        return lastMainWindow
    }
}

// MARK: Focus Transition
extension WindowManager: FocusTransitionTarget {
    func windows(onScreen screen: Screen) -> [Window] {
        return windows.activeWindows(onScreen: screen)
    }

    func executeTransition(_ transition: FocusTransition<Window>) {
        switch transition {
        case let .focusWindow(window):
            window.focus()
        case let .focusScreen(screen):
            screen.focusScreen()
        }
    }

    func lastFocusedWindow(on screen: Screen) -> Window? {
        return screens.screenManagers.first { $0.screen?.screenID() == screen.screenID() }?.lastFocusedWindow
    }
}

extension WindowManager: ScreenManagerDelegate {
    func applyWindowLimit(forScreenManager screenManager: ScreenManager<WindowManager<Application>>, minimizingIn range: (Int) -> Range<Int>) {
        guard let screen = screenManager.screen else {
            return
        }

        let windows = screenManager.currentLayout is FloatingLayout
            ? self.windows(onScreen: screen).filter { $0.shouldBeManaged() }
            : activeWindows(on: screen)
        windows[range(windows.count)].forEach {
            $0.minimize()
        }
    }

    func activeWindowSet(forScreenManager screenManager: ScreenManager<WindowManager<Application>>) -> WindowSet<Window> {
        return windows.windowSet(forActiveWindowsOnScreen: screenManager.screen!)
    }
}
