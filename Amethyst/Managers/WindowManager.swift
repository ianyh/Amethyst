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
    private let screens: Screens
    private let windows = Windows()
    private var lastReflowTime = Date()
    private var lastFocusDate: Date?

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

        reevaluateWindows()
        screens.updateScreens(windowManager: self)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    private func addWorkspaceNotificationObserver(_ name: NSNotification.Name, selector: Selector) {
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        workspaceNotificationCenter.addObserver(self, selector: selector, name: name, object: nil)
    }

    @objc func applicationActivated(_ sender: AnyObject) {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return
        }
        markScreen(screen, forReflowWithChange: .applicationActivate)
//        doMouseFollowsFocus(focusedWindow: focusedWindow)
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
        application.dropWindowsCache()
    }

    @objc func applicationDidUnhide(_ notification: Notification) {
        guard let unhiddenApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithPID(unhiddenApplication.processIdentifier) else {
            return
        }

        application.dropWindowsCache()
        activate(application: application)
    }

    @objc func activeSpaceDidChange(_ notification: Notification) {
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

        screens.updateSpaces()
        windows.regenerateActiveIDCache()
        markAllScreensForReflow(withChange: .spaceChange)
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
    }

    fileprivate func activate(application: AnyApplication<Application>) {
        windows.activateApplication(withPID: application.pid())
        markAllScreensForReflow(withChange: .applicationActivate)
    }

    fileprivate func deactivate(application: AnyApplication<Application>) {
        windows.deactivateApplication(withPID: application.pid())
        markAllScreensForReflow(withChange: .applicationDeactivate)
    }

    fileprivate func remove(window: Window) {
        markAllScreensForReflow(withChange: .remove(window: window))

        let application = applicationWithPID(window.pid())
        application?.unobserve(notification: kAXUIElementDestroyedNotification, window: window)
        application?.unobserve(notification: kAXWindowMiniaturizedNotification, window: window)
        application?.unobserve(notification: kAXWindowDeminiaturizedNotification, window: window)

        windows.regenerateActiveIDCache()
        windows.remove(window: window)
    }

    func toggleFloatForFocusedWindow() {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return
        }

        guard windows.windows(onScreen: screen).contains(focusedWindow) else {
            let windowChange: Change<Window> = .add(window: focusedWindow)
            add(window: focusedWindow)
            guard windows.window(withID: focusedWindow.id()) != nil else {
                return
            }
            windows.setFloating(false, forWindow: focusedWindow)
            markScreen(screen, forReflowWithChange: windowChange)
            return
        }

        let windowChange: Change = windows.isWindowFloating(focusedWindow) ? .add(window: focusedWindow) : .remove(window: focusedWindow)
        windows.setFloating(!windows.isWindowFloating(focusedWindow), forWindow: focusedWindow)
        markScreen(screen, forReflowWithChange: windowChange)
    }

    func markScreen(_ screen: Screen, forReflowWithChange change: Change<Window>) {
        screens.markScreen(screen, forReflowWithChange: change)
    }

    func markAllScreensForReflow(withChange windowChange: Change<Window>) {
        screens.markAllScreensForReflow(withChange: windowChange)
    }

    func displayCurrentLayout() {
        for screenManager in screens.screenManagers {
            screenManager.displayLayoutHUD()
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
        markAllScreensForReflow(withChange: .none)
    }

    private func add(window: Window, retries: Int = 5) {
        guard !windows.isWindowTracked(window) else {
            log.warning("skipping window")
            return
        }

        guard window.shouldBeManaged() else {
            return
        }

        guard let application = applicationWithPID(window.pid()) else {
            log.error("Tried to add a window without an application")
            return
        }

        switch application.defaultFloatForWindow(window) {
        case .unreliable where retries > 0:
            return DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.add(window: window, retries: retries - 1)
            }
        case .reliable(.floating), .unreliable(.floating):
            windows.setFloating(true, forWindow: window)
        case .reliable(.notFloating), .unreliable(.notFloating):
            windows.setFloating(false, forWindow: window)
        }

        windows.regenerateActiveIDCache()
        windows.add(window: window, atFront: userConfiguration.sendNewWindowsToMainPane())

        application.observe(notification: kAXUIElementDestroyedNotification, window: window) { _ in
            self.remove(window: window)
        }
        application.observe(notification: kAXWindowMiniaturizedNotification, window: window) { _ in
            self.remove(window: window)

            guard let screen = window.screen() else {
                return
            }
            self.markScreen(screen, forReflowWithChange: .remove(window: window))
        }

        guard let screen = window.screen() else {
            return
        }
        let space = CGWindowsInfo.windowSpace(window)

        let windowChange: Change = windows.isWindowFloating(window) || space == nil ? .unknown : .add(window: window)
        markScreen(screen, forReflowWithChange: windowChange)
    }

    func swapInTab(window: Window) {
        guard let screen = window.screen() else {
            return
        }

        // We do this to avoid triggering tab swapping when just switching focus between apps.
        // If the window's app is not running by this point then it's not a tab switch.
        guard let runningApp = NSRunningApplication(processIdentifier: window.pid()), runningApp.isActive else {
            return
        }

        // We take the windows that are being tracked so we can properly detect when a tab switch is a new tab.
        let applicationWindows = windows.windows(forApplicationWithPID: window.pid())

        for existingWindow in applicationWindows {
            guard existingWindow != window else {
                continue
            }

            let didLeaveScreen = windows.isWindowActive(existingWindow) && !existingWindow.isOnScreen()
            let isInvalid = existingWindow.cgID() == kCGNullWindowID

            // The window needs to have either left the screen and therefore is being replaced
            // or be invalid and therefore being removed and can be replaced.
            guard didLeaveScreen || isInvalid else {
                continue
            }

            // We have to make sure that we haven't had a focus change too recently as that could mean
            // the window is already active, but just became focused by swapping window focus.
            // The time is in seconds, and too long a time ends up with quick switches triggering tabs to incorrectly
            // swap.
            if let lastFocusChange = lastFocusDate, abs(lastFocusChange.timeIntervalSinceNow) < 0.1 && !isInvalid {
                continue
            }

            // Add the new window to be tracked, swap it with the existing window, regenerate cache to account
            // for the change, and then reflow.
            add(window: window)
            executeTransition(.switchWindows(existingWindow, window))
            windows.regenerateActiveIDCache()
            markScreen(screen, forReflowWithChange: .tabChange)

            return
        }

        // If we've reached this point we haven't found any tab to switch out, but this window could still be new.
        add(window: window)
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

        lastFocusDate = Date()

        if !windows.isWindowTracked(window) {
            markScreen(screen, forReflowWithChange: .unknown)
        } else {
            markScreen(screen, forReflowWithChange: .focusChanged(window: window))
        }

//        doMouseFollowsFocus(focusedWindow: window)
    }

    func application(_ application: AnyApplication<Application>, didFindPotentiallyNewWindow window: Window) {
        swapInTab(window: window)
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
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(applicationActivated(_:)),
            object: nil
        )
        perform(#selector(applicationActivated(_:)), with: nil, afterDelay: 0.2)
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

            markAllScreensForReflow(withChange: .windowSwap(window: window, otherWindow: otherWindow))
        case let .moveWindowToScreen(window, screen):
            let currentScreen = window.screen()
            window.moveScaled(to: screen)
            if let currentScreen = currentScreen {
                markScreen(currentScreen, forReflowWithChange: .remove(window: window))
            }
            markScreen(screen, forReflowWithChange: .add(window: window))
            window.focus()
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
            if targetScreen.screenID() != screen.screenID() {
                // necessary to set frame here as window is expected to be at origin relative to targe screen when moved, can be improved.
                window.moveScaled(to: targetScreen)
                markScreen(screen, forReflowWithChange: .remove(window: window))
                markScreen(targetScreen, forReflowWithChange: .add(window: window))
            }
            if !UserConfiguration.shared.followWindowsThrownBetweenSpaces() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
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

    func nextWindowIDClockwise(on screen: Screen) -> Window.WindowID? {
        return screenManager(for: screen)?.nextWindowIDClockwise()
    }

    func nextWindowIDCounterClockwise(on screen: Screen) -> Window.WindowID? {
        return screenManager(for: screen)?.nextWindowIDCounterClockwise()
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
