//
//  WindowManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/14/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import AppKit
import Foundation
import RxSwift
import RxSwiftExt
import Silica
import SwiftyJSON

class WindowManager<Application: ApplicationType>: NSObject {
    typealias Window = Application.Window
    typealias Screen = Window.Screen

    private(set) var windows: [Window] = []
    private(set) lazy var windowTransitionCoordinator = WindowTransitionCoordinator(target: self)
    private(set) lazy var focusTransitionCoordinator = FocusTransitionCoordinator(target: self)

    private var applications: [AnyApplication<Application>] = []
    private let screens = Screens()
    private var activeIDCache: Set<CGWindowID> = Set()
    private var floatingMap: [CGWindowID: Bool] = [:]
    private var lastReflowTime = Date()
    private var lastFocusDate: Date?

    private lazy var mouseStateKeeper = MouseStateKeeper(delegate: self)
    private lazy var focusFollowsMouseManager = FocusFollowsMouseManager(delegate: self, userConfiguration: self.userConfiguration)
    private let userConfiguration: UserConfiguration
    private let disposeBag = DisposeBag()

    init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        super.init()

        addWorkspaceNotificationObserver(NSWorkspace.didLaunchApplicationNotification, selector: #selector(applicationDidLaunch(_:)))
        addWorkspaceNotificationObserver(NSWorkspace.didTerminateApplicationNotification, selector: #selector(applicationDidTerminate(_:)))
        addWorkspaceNotificationObserver(NSWorkspace.didHideApplicationNotification, selector: #selector(applicationDidHide(_:)))
        addWorkspaceNotificationObserver(NSWorkspace.didUnhideApplicationNotification, selector: #selector(applicationDidUnhide(_:)))
        addWorkspaceNotificationObserver(NSWorkspace.activeSpaceDidChangeNotification, selector: #selector(activeSpaceDidChange(_:)))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        reevaluateWindows()
        screens.updateScreenManagers(windowManager: self)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    private func addWorkspaceNotificationObserver(_ name: NSNotification.Name, selector: Selector) {
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        workspaceNotificationCenter.addObserver(self, selector: selector, name: name, object: nil)
    }

    private func regenerateActiveIDCache() {
        let windowDescriptions = CGWindowsInfo(options: .optionOnScreenOnly, windowID: CGWindowID(0))
        activeIDCache = windowDescriptions?.activeIDs() ?? Set()
    }

    func screenManager(screen: Screen, screenID: String) -> ScreenManager<Window> {
        let screenManager = ScreenManager<Window>(
            screen: screen,
            screenID: screenID,
            delegate: self,
            userConfiguration: userConfiguration
        )
        screenManager.onReflowInitiation = { [weak self] in
            self?.mouseStateKeeper.handleReflowEvent()
        }
        screenManager.onReflowCompletion = { [weak self] in
            // This handler will be executed by the Operation, in a queue.  Although async
            // (and although the docs say that it executes in a separate thread), I consider
            // this to be thread safe, at least safe enough, because we always want the
            // latest time that a reflow took place.
            self?.mouseStateKeeper.handleReflowEvent()
            self?.lastReflowTime = Date()
        }

        return screenManager
    }

    func preferencesDidClose() {
        DispatchQueue.main.async {
            self.focusTransitionCoordinator.focusScreen(at: 0)
        }
    }

    func focusedScreenManager<Window>() -> ScreenManager<Window>? {
        return screens.focusedScreenManager()
    }

    fileprivate func applicationWithPID(_ pid: pid_t) -> AnyApplication<Application>? {
        for application in applications {
            if application.pid() == pid {
                return application
            }
        }

        return nil
    }

    fileprivate func add(application: AnyApplication<Application>) {
        guard !applications.contains(application) else {
            for window in application.windows() {
                add(window: window)
            }
            return
        }

        ApplicationObservation(application: application, delegate: self)
            .addObservers()
            .subscribe(
                onCompleted: { [weak self] in
                    guard let strongSelf = self else { return }

                    strongSelf.applications.append(application)

                    for window in application.windows() {
                        strongSelf.add(window: window)
                    }
                }
            )
            .disposed(by: disposeBag)
    }

    fileprivate func remove(application: AnyApplication<Application>) {
        for window in application.windows() {
            remove(window: window)
        }
        guard let applicationIndex = applications.index(of: application) else {
            return
        }
        applications.remove(at: applicationIndex)
    }

    fileprivate func activate(application: AnyApplication<Application>) {
        for window in windows {
            if window.pid() == application.pid() {
                guard let screen = window.screen() else {
                    return
                }
                markScreenForReflow(screen, withChange: .unknown)
            }
        }
    }

    fileprivate func deactivate(application: AnyApplication<Application>) {
        for window in windows {
            if window.pid() == application.pid() {
                guard let screen = window.screen() else {
                    return
                }
                markScreenForReflow(screen, withChange: .unknown)
            }
        }
    }

    fileprivate func remove(window: Window) {
        markAllScreensForReflowWithChange(.remove(window: window))

        let application = applicationWithPID(window.pid())
        application?.unobserve(notification: kAXUIElementDestroyedNotification, window: window)
        application?.unobserve(notification: kAXWindowMiniaturizedNotification, window: window)
        application?.unobserve(notification: kAXWindowDeminiaturizedNotification, window: window)

        regenerateActiveIDCache()

        guard let windowIndex = windows.index(of: window) else {
            return
        }

        windows.remove(at: windowIndex)
    }

    func toggleFloatForFocusedWindow() {
        guard let focusedWindow = Window.currentlyFocused() else {
            return
        }

        for window in windows {
            if let screen = window.screen(), window == focusedWindow {
                let windowChange: Change = windowIsFloating(window) ? .add(window: window) : .remove(window: window)
                floatingMap[window.windowID()] = !windowIsFloating(window)
                markScreenForReflow(screen, withChange: windowChange)
                return
            }
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        let windowChange: Change<Window> = .add(window: focusedWindow)
        add(window: focusedWindow)
        floatingMap[focusedWindow.windowID()] = false
        markScreenForReflow(screen, withChange: windowChange)
    }

    func markScreenForReflow(_ screen: Screen, withChange change: Change<Window>) {
        screens.markScreenForReflow(screen, withChange: change)
    }

    func markAllScreensForReflowWithChange(_ windowChange: Change<Window>) {
        screens.markAllScreensForReflowWithChange(windowChange)
    }

    func displayCurrentLayout() {
        for screenManager in screens.screenManagers {
            screenManager.displayLayoutHUD()
        }
    }

    @objc func applicationActivated(_ sender: AnyObject) {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return
        }
        markScreenForReflow(screen, withChange: .unknown)
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
        regenerateActiveIDCache()
        screens.assignCurrentSpaceIdentifiers()

        for runningApplication in NSWorkspace.shared.runningApplications {
            guard runningApplication.isManageable else {
                continue
            }

            let pid = runningApplication.processIdentifier
            guard let application = applicationWithPID(pid) else {
                continue
            }

            application.dropWindowsCache()

            for window in application.windows() {
                add(window: window)
            }
        }

        markAllScreensForReflowWithChange(.unknown)
    }

    @objc func screenParametersDidChange(_ notification: Notification) {
        screens.updateScreenManagers(windowManager: self)
    }
}

extension WindowManager {
    func add(runningApplication: NSRunningApplication) {
        let application = AnyApplication(Application(runningApplication: runningApplication))
        add(application: application)
    }

    func reevaluateWindows() {
        for runningApplication in NSWorkspace.shared.runningApplications {
            guard runningApplication.isManageable else {
                continue
            }

            add(runningApplication: runningApplication)
        }
        markAllScreensForReflowWithChange(.unknown)
    }

    private func add(window: Window, retries: Int = 5) {
        guard !windows.contains(window) && window.shouldBeManaged() else {
            return
        }

        guard let application = applicationWithPID(window.pid()) else {
            log.error("Tried to add a window without an application")
            return
        }

        switch application.defaultFloatForWindowWithTitle(window.title()) {
        case .unreliable where retries > 0:
            return DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.add(window: window, retries: retries - 1)
            }
        case .reliable(.floating), .unreliable(.floating):
            floatingMap[window.windowID()] = true
        case .reliable(.notFloating), .unreliable(.notFloating):
            floatingMap[window.windowID()] = false
        }

        regenerateActiveIDCache()

        if userConfiguration.sendNewWindowsToMainPane() {
            windows.insert(window, at: 0)
        } else {
            windows.append(window)
        }

        application.observe(notification: kAXUIElementDestroyedNotification, window: window) { element in
            guard let window = Window(element: element) else {
                return
            }
            self.remove(window: window)
        }
        application.observe(notification: kAXWindowMiniaturizedNotification, window: window) { element in
            guard let window = Window(element: element) else {
                return
            }

            self.remove(window: window)

            guard let screen = window.screen() else {
                return
            }
            self.markScreenForReflow(screen, withChange: .remove(window: window))
        }

        guard let screen = window.screen() else {
            return
        }

        let windowChange: Change = windowIsFloating(window) ? .unknown : .add(window: window)
        markScreenForReflow(screen, withChange: windowChange)
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
        let applicationWindows = windows.filter { $0.pid() == window.pid() }

        for existingWindow in applicationWindows {
            guard existingWindow != window else {
                continue
            }

            let didLeaveScreen = windowIsActive(existingWindow) && !existingWindow.isOnScreen()
            let isInvalid = existingWindow.windowID() == kCGNullWindowID

            // The window needs to have either left the screen and therefore is being replaced
            // or be invalid and therefore being removed and can be replaced.
            guard didLeaveScreen || isInvalid else {
                continue
            }

            // We need to tolerate a bit more height because a window that goes from untabbed to tabbed can change
            // the height of the titlebar (e.g., Terminal)
            let tolerance = CGRect(x: 10, y: 10, width: 10, height: 30)
            let isApproximatelyInFrame = existingWindow.frame().approximatelyEqual(to: window.frame(), within: tolerance)

            // If the window is in the same position and is going off screen it is likely a tab being replaced
            guard isApproximatelyInFrame || isInvalid else {
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
            regenerateActiveIDCache()
            markScreenForReflow(screen, withChange: .unknown)

            return
        }

        // If we've reached this point we haven't found any tab to switch out, but this window could still be new.
        add(window: window)
    }
}

extension WindowManager: WindowActivityCache {
    func windowIsActive<W: WindowType>(_ window: W) -> Bool {
        return window.isActive() && activeIDCache.contains(window.windowID())
    }

    func windowIsFloating<Window: WindowType>(_ window: Window) -> Bool {
        return floatingMap[window.windowID()] ?? false
    }
}

extension WindowManager: MouseStateKeeperDelegate {
    func recommendMainPaneRatio(_ ratio: CGFloat) {
        guard let screenManager: ScreenManager<Window> = focusedScreenManager() else { return }

        screenManager.updateCurrentLayout { layout in
            if let panedLayout = layout as? PanedLayout {
                panedLayout.recommendMainPaneRatio(ratio)
            }
        }
    }

    func swapDraggedWindowWithDropzone(_ draggedWindow: Application.Window) {
        guard let screen = draggedWindow.screen() else { return }

        let windows: [Window] = self.windows(self.windows, on: screen)

        // need to flip mouse coordinate system to fit Amethyst https://stackoverflow.com/a/45289010/2063546
        let flippedPointerLocation = NSPointToCGPoint(NSEvent.mouseLocation)
        let unflippedY = Screen.globalHeight() - flippedPointerLocation.y + screen.frameIncludingDockAndMenu().origin.y
        let pointerLocation = NSPointToCGPoint(NSPoint(x: flippedPointerLocation.x, y: unflippedY))

        if let screenManager: ScreenManager<Window> = focusedScreenManager(), let layout = screenManager.currentLayout {
            if let framedWindow = layout.windowAtPoint(pointerLocation, of: windows, on: screen) {
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

extension WindowManager: ApplicationObservationDelegate {
    func application(_ application: AnyApplication<Application>, didAddWindow window: Application.Window) {
        add(window: window)
    }

    func application(_ application: AnyApplication<Application>, didRemoveWindow window: Application.Window) {
        remove(window: window)
    }

    func application(_ application: AnyApplication<Application>, didFocusWindow window: Application.Window) {
        guard let screen = window.screen() else {
            return
        }

        lastFocusDate = Date()
        if windows.index(of: window) == nil {
            markScreenForReflow(screen, withChange: .unknown)
        } else {
            markScreenForReflow(screen, withChange: .focusChanged(window: window))
        }
    }

    func application(_ application: AnyApplication<Application>, didFindPotentiallyNewWindow window: Application.Window) {
        swapInTab(window: window)
    }

    func application(_ application: AnyApplication<Application>, didMoveWindow window: Application.Window) {
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

    func application(_ application: AnyApplication<Application>, didResizeWindow window: Application.Window) {
        guard userConfiguration.mouseResizesWindows() else {
            return
        }

        guard let screen = window.screen(), activeWindows(on: screen).contains(window) else {
            return
        }

        guard
            let screenManager: ScreenManager<Window> = focusedScreenManager(),
            let layout = screenManager.currentLayout,
            layout is PanedLayout,
            let oldFrame = layout.assignedFrame(window, of: activeWindowsForScreenManager(screenManager), on: screen)
        else {
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

                if let screenManager: ScreenManager<Window> = focusedScreenManager() {
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

    func screenManager(at screenIndex: Int) -> ScreenManager<Window>? {
        guard screenIndex > -1 && screenIndex < screens.screenManagers.count else {
            return nil
        }

        return screens.screenManagers[screenIndex]
    }

    func screenManager(for screen: Screen) -> ScreenManager<Window>? {
        return screens.screenManagers.first { $0.screen.screenID() == screen.screenID() }
    }

    func screenManagerIndex(for screen: Screen) -> Int? {
        return screens.screenManagers.index { $0.screen.screenID() == screen.screenID() }
    }
}

extension WindowManager: WindowTransitionTarget {
    func executeTransition(_ transition: WindowTransition<Window>) {
        switch transition {
        case let .switchWindows(window, otherWindow):
            guard let windowIndex = windows.index(of: window), let otherWindowIndex = windows.index(of: otherWindow) else {
                return
            }

            guard windowIndex != otherWindowIndex else { return }

            windows[windowIndex] = otherWindow
            windows[otherWindowIndex] = window

            markAllScreensForReflowWithChange(.windowSwap(window: window, otherWindow: otherWindow))
        case let .moveWindowToScreen(window, screen):
            if let currentScreen = window.screen() {
                markScreenForReflow(currentScreen, withChange: .remove(window: window))
            }
            window.moveScaled(to: screen)
            markScreenForReflow(screen, withChange: .add(window: window))
            window.focus()
        case let .moveWindowToSpaceAtIndex(window, spaceIndex):
            guard
                let screen = window.screen(),
                let spaces = CGSpacesInfo<Window>.spacesForScreen(screen, includeOnlyUserSpaces: true),
                spaceIndex < spaces.count
            else {
                return
            }

            let targetSpace = spaces[spaceIndex]

            markScreenForReflow(screen, withChange: .remove(window: window))
            window.move(toSpace: targetSpace.id)
        case .resetFocus:
            if let screen = screens.screenManagers.first?.screen {
                executeTransition(.focusScreen(screen))
            }
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
}

extension WindowManager: FocusTransitionTarget {
    var windowActivityCache: WindowActivityCache { return self }

    func executeTransition(_ transition: FocusTransition<Window>) {
        switch transition {
        case let .focusWindow(window):
            window.focus()
        case let .focusScreen(screen):
            screen.focusScreen()
        }
    }

    func lastFocusedWindow(on screen: Screen) -> Window? {
        return screens.screenManagers.first { $0.screen.screenID() == screen.screenID() }?.lastFocusedWindow
    }

    func nextWindowIDClockwise(on screen: Screen) -> CGWindowID? {
        return screenManager(for: screen)?.nextWindowIDClockwise()
    }

    func nextWindowIDCounterClockwise(on screen: Screen) -> CGWindowID? {
        return screenManager(for: screen)?.nextWindowIDCounterClockwise()
    }
}
