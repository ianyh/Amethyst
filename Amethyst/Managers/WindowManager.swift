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

enum WindowChange<Window: WindowType> {
    case add(window: Window)
    case remove(window: Window)
    case focusChanged(window: Window)
    case windowSwap(window: Window, otherWindow: Window)
    case unknown
}

// These are the possible actions that the mouse might be taking (that we care about).
//  We use this enum to convey some information about the window that the mouse
//  might be interacting with.
enum MouseState<Window: WindowType> {
    case pointing
    case clicking
    case dragging
    case moving(window: Window)
    case resizing(screen: NSScreen, ratio: CGFloat)
    case doneDragging(atTime: Date)
}

// MouseStateKeeper will need a few things to do its job effectively
protocol MouseStateKeeperDelegate: class {
    associatedtype Window: WindowType
    func recommendMainPaneRatio(_ ratio: CGFloat)
    func swapDraggedWindowWithDropzone(_ draggedWindow: Window)
}

// MouseStateKeeper exists because we need a single shared mouse state between all
//  SIApplications being observed.  This class captures the state and coordinates
//  any Amethyst reflow actions that are required in response to mouse events.
// Note that some actions may be initiated here and some actions may be completed
//  here; we don't know whether the mouse event stream or the accessibility event
//  stream will fire first.
// This class by itself can only understand clicking, dragging, and "pointing"
//  (no mouse buttons down).  The SIApplication observers are able to augment that
//  understanding of state by "upgrading" a drag action to a "window move" or a
//  "window resize" event since those observers will have proper context.
class MouseStateKeeper<Delegate: MouseStateKeeperDelegate> {
    public let dragRaceThresholdSeconds = 0.15 // prevent race conditions during drag ops
    public var state: MouseState<Delegate.Window>
    private(set) weak var delegate: Delegate?
    private var monitor: Any?

    init(delegate: Delegate) {
        self.delegate = delegate

        state = .pointing
        let mouseEventsToWatch: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .leftMouseDragged]
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEventsToWatch, handler: self.handleMouseEvent)
    }

    deinit {
        guard let oldMonitor = monitor else { return }
        NSEvent.removeMonitor(oldMonitor)
    }

    // Update our understanding of the current state unless an observer has already
    // done it for us.  mouseUp events take precedence over anything an observer had
    // found -- you can't be dragging or resizing with a mouse button up, even if
    // you're using the "3 finger drag" accessibility option, where no physical button
    // is being pressed.
    func handleMouseEvent(anEvent: NSEvent) {
        switch anEvent.type {
        case .leftMouseDown:
            self.state = .clicking
        case .leftMouseDragged:
            switch self.state {
            case .moving, .resizing:
            break // ignore - we have what we need
            case .pointing, .clicking, .dragging, .doneDragging:
                self.state = .dragging
            }

        case .leftMouseUp:
            switch self.state {
            case .dragging:
                // assume window move event will come shortly after
                self.state = .doneDragging(atTime: Date())
            case let .moving(draggedWindow):
                self.state = .pointing // flip state first to prevent race condition
                self.swapDraggedWindowWithDropzone(draggedWindow)
            case let .resizing(_, ratio):
                self.state = .pointing
                self.resizeFrameToDraggedWindowBorder(ratio)
            case .doneDragging:
                self.state = .doneDragging(atTime: Date()) // reset the clock I guess
            case .pointing, .clicking:
                self.state = .pointing
            }

        default: ()
        }

    }

    // React to a reflow event.  Typically this means that any window we were dragging
    // is no longer valid and should be de-correlated from the mouse
    func handleReflowEvent() {
        switch self.state {
        case .doneDragging:
            self.state = .pointing // remove associated timestamp
        case .moving:
            self.state = .dragging // remove associated window
        default: ()
        }
    }

    // Execute an action that was initiated by the observer and completed by the state keeper
    func resizeFrameToDraggedWindowBorder(_ ratio: CGFloat) {
        delegate?.recommendMainPaneRatio(ratio)
    }

    // Execute an action that was initiated by the observer and completed by the state keeper
    func swapDraggedWindowWithDropzone(_ draggedWindow: Delegate.Window) {
        delegate?.swapDraggedWindowWithDropzone(draggedWindow)
    }
}

// This class sets up accessibility API event subscriptions for a given SIApplication,
// handling references to the window manager and mouse state.  The observers themselves
// react to mouse / accessibility state by either changing window positions or updating
// the mouse state based on new information
private struct ObserveApplicationNotifications<Application: ApplicationType> {
    typealias Window = Application.Window

    enum Error: Swift.Error {
        case failed
    }

    private enum Notification {
        case created
        case windowDeminiaturized
        case applicationHidden
        case applicationShown
        case focusedWindowChanged
        case applicationActivated
        case windowMoved
        case windowResized
        case mainWindowChanged

        var string: String {
            switch self {
            case .created:
                return kAXCreatedNotification
            case .windowDeminiaturized:
                return kAXWindowDeminiaturizedNotification
            case .applicationHidden:
                return kAXApplicationHiddenNotification
            case .applicationShown:
                return kAXApplicationShownNotification
            case .focusedWindowChanged:
                return kAXFocusedWindowChangedNotification
            case .applicationActivated:
                return kAXApplicationActivatedNotification
            case .windowMoved:
                return kAXWindowMovedNotification
            case .windowResized:
                return kAXWindowResizedNotification
            case .mainWindowChanged:
                return kAXMainWindowChangedNotification
            }
        }
    }

    init() {}

    fileprivate func addObservers(application: AnyApplication<Application>, windowManager: WindowManager<Application>) -> Observable<Void> {
        return _addObservers(application, windowManager).retry(.exponentialDelayed(maxCount: 4, initial: 0.1, multiplier: 2))
    }

    private func _addObservers(_ application: AnyApplication<Application>, _ windowManager: WindowManager<Application>) -> Observable<Void> {
        let notifications: [Notification] = [
            .created,
            .windowDeminiaturized,
            .applicationHidden,
            .applicationShown,
            .focusedWindowChanged,
            .applicationActivated,
            .windowMoved,
            .windowResized,
            .mainWindowChanged
        ]

        return Observable.from(notifications)
            .scan([]) { [weak application, weak windowManager] observed, notification -> [Notification] in
                guard let application = application, let windowManager = windowManager else {
                    throw Error.failed
                }

                do {
                    try self.addObserver(for: notification, application: application, windowManager: windowManager)
                } catch {
                    log.error("Failed to add observer \(notification) on application \(application.title() ?? "<unknown>")")
                    self.removeObservers(notifications: observed, application: application)
                    throw error
                }

                return observed + [notification]
            }
            .map { _ in }
    }

    private func addObserver(for notification: Notification, application: AnyApplication<Application>, windowManager: WindowManager<Application>) throws {
        let success = application.observe(notification: notification.string) { [weak application, weak windowManager] element in
            guard let application = application, let windowManager = windowManager else {
                return
            }

            let window = Window(element: element)

            self.handle(notification: notification, window: window, application: application, windowManager: windowManager)
        }

        guard success else {
            throw Error.failed
        }
    }

    private func removeObservers(notifications: [Notification], application: AnyApplication<Application>) {
        notifications.forEach { application.unobserve(notification: $0.string) }
    }
}

extension ObserveApplicationNotifications {
    private func handle(notification: Notification, window: Window, application: AnyApplication<Application>, windowManager: WindowManager<Application>) {
        switch notification {
        case .created:
            windowManager.swapInTab(window: window)
        case .windowDeminiaturized:
            windowManager.add(window: window)
        case .applicationHidden:
            windowManager.removeWindow(window)
        case .applicationShown:
            windowManager.add(window: window)
        case .focusedWindowChanged:
            guard let focusedWindow: Application.Window = Application.Window.currentlyFocused(), let screen = focusedWindow.screen() else {
                return
            }
            windowManager.lastFocusDate = Date()
            if windowManager.windows.index(of: focusedWindow) == nil {
                windowManager.markScreenForReflow(screen, withChange: .unknown)
            } else {
                windowManager.markScreenForReflow(screen, withChange: .focusChanged(window: focusedWindow))
                windowManager.screenManager(for: screen)?.lastFocusedWindow = focusedWindow
            }
        case .applicationActivated:
            NSObject.cancelPreviousPerformRequests(
                withTarget: windowManager,
                selector: #selector(WindowManager<Application>.applicationActivated(_:)),
                object: nil
            )
            windowManager.perform(#selector(WindowManager<Application>.applicationActivated(_:)), with: nil, afterDelay: 0.2)
        case .windowMoved:
            guard windowManager.userConfiguration.mouseSwapsWindows() else {
                return
            }

            guard let screen = window.screen(), windowManager.activeWindows(on: screen).contains(window) else {
                    return
            }

            switch windowManager.mouseStateKeeper.state {
            case .dragging:
                // be aware of last reflow time, again to prevent race condition
                let reflowEndInterval = Date().timeIntervalSince(windowManager.lastReflowTime)
                guard reflowEndInterval > windowManager.mouseStateKeeper.dragRaceThresholdSeconds else { break }

                // record window and wait for mouse up
                windowManager.mouseStateKeeper.state = .moving(window: window)
            case let .doneDragging(lmbUpMoment):
                windowManager.mouseStateKeeper.state = .pointing // flip state first to prevent race condition

                // if mouse button recently came up, assume window move is related
                let dragEndInterval = Date().timeIntervalSince(lmbUpMoment)
                guard dragEndInterval < windowManager.mouseStateKeeper.dragRaceThresholdSeconds else { break }

                windowManager.mouseStateKeeper.swapDraggedWindowWithDropzone(window)
            default:
                break
            }
        case .windowResized:
            guard windowManager.userConfiguration.mouseResizesWindows() else {
                return
            }

            guard let screen = window.screen(), windowManager.activeWindows(on: screen).contains(window) else {
                return
            }

            guard
                let screenManager: ScreenManager<Application.Window> = windowManager.focusedScreenManager(),
                let layout = screenManager.currentLayout,
                layout is PanedLayout,
                let oldFrame = layout.assignedFrame(window, of: windowManager.activeWindowsForScreenManager(screenManager), on: screen)
            else {
                return
            }

            let ratio = oldFrame.impliedMainPaneRatio(windowFrame: window.frame())

            switch windowManager.mouseStateKeeper.state {
            case .dragging, .resizing:
                // record window and wait for mouse up
                windowManager.mouseStateKeeper.state = .resizing(screen: screen, ratio: ratio)
            case let .doneDragging(lmbUpMoment):
                // if mouse button recently came up, assume window resize is related
                let dragEndInterval = Date().timeIntervalSince(lmbUpMoment)
                if dragEndInterval < windowManager.mouseStateKeeper.dragRaceThresholdSeconds {
                    windowManager.mouseStateKeeper.state = .pointing // flip state first to prevent race condition

                    if let screenManager: ScreenManager<Application.Window> = windowManager.focusedScreenManager() {
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
        case .mainWindowChanged:
            windowManager.swapInTab(window: window)
        }
    }
}

final class WindowManager<Application: ApplicationType>: NSObject {
    typealias Window = Application.Window

    private var applications: [AnyApplication<Application>] = []
    private(set) lazy var mouseStateKeeper = MouseStateKeeper(delegate: self)
    var windows: [Window] = []
    fileprivate let userConfiguration: UserConfiguration

    private(set) var screenManagers: [ScreenManager<Window>] = []
    private var screenManagersCache: [String: ScreenManager<Window>] = [:]

    private let focusFollowsMouseManager: FocusFollowsMouseManager<WindowManager<Application>>

    fileprivate private(set) var activeIDCache: Set<CGWindowID> = Set()
    private(set) var floatingMap: [CGWindowID: Bool] = [:]

    public private(set) var lastReflowTime: Date

    private let disposeBag = DisposeBag()

    var lastFocusDate: Date?

    init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        self.focusFollowsMouseManager = FocusFollowsMouseManager(userConfiguration: userConfiguration)
        lastReflowTime = Date()
        super.init()

        focusFollowsMouseManager.delegate = self

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
        updateScreenManagers()
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
        var activeIDCache: Set<CGWindowID> = Set()

        defer {
            self.activeIDCache = activeIDCache
        }

        guard let windowDescriptions = WindowDescriptions(options: .optionOnScreenOnly, windowID: CGWindowID(0)) else {
            return
        }

        for windowDescription in windowDescriptions.descriptions {
            guard let windowID = windowDescription[kCGWindowNumber as String] as? NSNumber else {
                continue
            }

            activeIDCache.insert(CGWindowID(windowID.uint64Value))
        }
    }

    private func spaceIdentifier(from screenDictionary: JSON) -> String? {
        return screenDictionary["Current Space"]["uuid"].string
    }

    fileprivate func assignCurrentSpaceIdentifiers() {
        regenerateActiveIDCache()

        guard let screenDictionaries = NSScreen.screenDescriptions() else {
            return
        }

        if NSScreen.screensHaveSeparateSpaces {
            for screenDictionary in screenDictionaries {
                guard let screenIdentifier = screenDictionary["Display Identifier"].string else {
                    log.error("Could not identify screen with info: \(screenDictionary)")
                    continue
                }

                guard let screenManager = screenManagersCache[screenIdentifier] else {
                    log.error("Screen with identifier not managed: \(screenIdentifier)")
                    continue
                }

                guard let spaceIdentifier = spaceIdentifier(from: screenDictionary), screenManager.currentSpaceIdentifier != spaceIdentifier else {
                    continue
                }

                screenManager.currentSpaceIdentifier = spaceIdentifier
            }
        } else {
            for screenManager in screenManagers {
                let screenDictionary = screenDictionaries[0]

                guard let spaceIdentifier = spaceIdentifier(from: screenDictionary), screenManager.currentSpaceIdentifier != spaceIdentifier else {
                    continue
                }

                screenManager.currentSpaceIdentifier = spaceIdentifier
            }
        }
    }

    private func screenManagerForCGWindowDescription(_ description: [String: AnyObject]) -> ScreenManager<Window>? {
        let windowFrameDictionary = description[kCGWindowBounds as String] as! [String: Any]
        let windowFrame = CGRect(dictionaryRepresentation: windowFrameDictionary as CFDictionary)!

        var lastVolume: CGFloat = 0
        var lastScreenManager: ScreenManager<Window>?

        for screenManager in screenManagers {
            let screenFrame = screenManager.screen.frameIncludingDockAndMenu()
            let intersection = windowFrame.intersection(screenFrame)
            let volume = intersection.size.width * intersection.size.height

            if volume > lastVolume {
                lastVolume = volume
                lastScreenManager = screenManager
            }
        }

        return lastScreenManager
    }

    func preferencesDidClose() {
        DispatchQueue.main.async {
            self.focusScreen(at: 0)
        }
    }

    func focusedScreenManager<Window>() -> ScreenManager<Window>? {
        guard let focusedWindow: Window = Window.currentlyFocused() else {
            return nil
        }
        for screenManager in screenManagers {
            guard let typedScreenManager = screenManager as? ScreenManager<Window> else {
                continue
            }

            if typedScreenManager.screen.screenIdentifier() == focusedWindow.screen()?.screenIdentifier() {
                return typedScreenManager
            }
        }
        return nil
    }

    fileprivate func applicationWithProcessIdentifier(_ processIdentifier: pid_t) -> AnyApplication<Application>? {
        for application in applications {
            if application.pid() == processIdentifier {
                return application
            }
        }

        return nil
    }

    fileprivate func addApplication(_ application: AnyApplication<Application>) {
        guard !applications.contains(application) else {
            for window in application.windows() {
                add(window: window)
            }
            return
        }

        ObserveApplicationNotifications().addObservers(application: application, windowManager: self)
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

    fileprivate func removeApplication(_ application: AnyApplication<Application>) {
        for window in application.windows() {
            removeWindow(window)
        }
        guard let applicationIndex = applications.index(of: application) else {
            return
        }
        applications.remove(at: applicationIndex)
    }

    fileprivate func activateApplication(_ application: AnyApplication<Application>) {
        for window in windows {
            if window.pid() == application.pid() {
                guard let screen = window.screen() else {
                    return
                }
                markScreenForReflow(screen, withChange: .unknown)
            }
        }
    }

    fileprivate func deactivateApplication(_ application: AnyApplication<Application>) {
        for window in windows {
            if window.pid() == application.pid() {
                guard let screen = window.screen() else {
                    return
                }
                markScreenForReflow(screen, withChange: .unknown)
            }
        }
    }

    fileprivate func removeWindow(_ window: Window) {
        let change: WindowChange<Window> = .remove(window: window)
        markAllScreensForReflowWithChange(change)

        let application = applicationWithProcessIdentifier(window.pid())
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
        guard let focusedWindow: Window = Window.currentlyFocused() else {
            return
        }

        for window in windows {
            if let screen = window.screen(), window == focusedWindow {
                let windowChange: WindowChange = windowIsFloating(window) ? .add(window: window) : .remove(window: window)
                floatingMap[window.windowID()] = !windowIsFloating(window)
                markScreenForReflow(screen, withChange: windowChange)
                return
            }
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        let windowChange: WindowChange<Window> = .add(window: focusedWindow)
        add(window: focusedWindow)
        floatingMap[focusedWindow.windowID()] = false
        markScreenForReflow(screen, withChange: windowChange)
    }

    fileprivate func updateScreenManagers() {
        var screenManagers: [ScreenManager<Window>] = []

        for screen in NSScreen.screens {
            guard let screenIdentifier = screen.screenIdentifier() else {
                continue
            }

            var screenManager = screenManagersCache[screenIdentifier]

            if screenManager == nil {
                screenManager = ScreenManager(screen: screen, screenIdentifier: screenIdentifier, delegate: self, userConfiguration: userConfiguration)
                screenManager!.onReflowInitiation = { [weak self] in
                    self?.mouseStateKeeper.handleReflowEvent()
                }
                screenManager!.onReflowCompletion = { [weak self] in
                    // This handler will be executed by the Operation, in a queue.  Although async
                    // (and although the docs say that it executes in a separate thread), I consider
                    // this to be thread safe, at least safe enough, because we always want the
                    // latest time that a reflow took place.
                    self?.mouseStateKeeper.handleReflowEvent()
                    self?.lastReflowTime = Date()
                }
                screenManagersCache[screenIdentifier] = screenManager
            }

            screenManager!.screen = screen

            screenManagers.append(screenManager!)
        }

        // Window managers are sorted by screen position along the x-axis.
        screenManagers.sort { screenManager1, screenManager2 -> Bool in
            let originX1 = screenManager1.screen.frameWithoutDockOrMenu().origin.x
            let originX2 = screenManager2.screen.frameWithoutDockOrMenu().origin.x

            return originX1 < originX2
        }

        self.screenManagers = screenManagers

        assignCurrentSpaceIdentifiers()
        markAllScreensForReflowWithChange(.unknown)
    }

    func markAllScreensForReflowWithChange(_ windowChange: WindowChange<Window>) {
        for screenManager in screenManagers {
            screenManager.setNeedsReflowWithWindowChange(windowChange)
        }
    }

    func displayCurrentLayout() {
        for screenManager in screenManagers {
            screenManager.displayLayoutHUD()
        }
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
            switchWindow(existingWindow, with: window)
            regenerateActiveIDCache()
            markScreenForReflow(screen, withChange: .unknown)

            return
        }

        // If we've reached this point we haven't found any tab to switch out, but this window could still be new.
        add(window: window)
    }

    @objc func applicationActivated(_ sender: AnyObject) {
        guard let focusedWindow: Window = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
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

        guard let application = applicationWithProcessIdentifier(terminatedApplication.processIdentifier) else {
            return
        }

        removeApplication(application)
    }

    @objc func applicationDidHide(_ notification: Notification) {
        guard let hiddenApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithProcessIdentifier(hiddenApplication.processIdentifier) else {
            return
        }

        deactivateApplication(application)
    }

    @objc func applicationDidUnhide(_ notification: Notification) {
        guard let unhiddenApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithProcessIdentifier(unhiddenApplication.processIdentifier) else {
            return
        }

        activateApplication(application)
    }

    @objc func activeSpaceDidChange(_ notification: Notification) {
        assignCurrentSpaceIdentifiers()

        for runningApplication in NSWorkspace.shared.runningApplications {
            guard runningApplication.isManageable else {
                continue
            }

            let processIdentifier = runningApplication.processIdentifier
            guard let application = applicationWithProcessIdentifier(processIdentifier) else {
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
        updateScreenManagers()
    }
}

extension WindowManager {
    func add(runningApplication: NSRunningApplication) {
        let application = AnyApplication(Application(runningApplication: runningApplication))
        addApplication(application)
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
}

extension WindowManager {
    fileprivate func add(window: Window) {
        guard !windows.contains(window) && window.shouldBeManaged() else {
            return
        }

        regenerateActiveIDCache()

        if userConfiguration.sendNewWindowsToMainPane() {
            windows.insert(window, at: 0)
        } else {
            windows.append(window)
        }

        guard let application = applicationWithProcessIdentifier(window.pid()) else {
            log.error("Tried to add a window without an application")
            return
        }

        if let windowTitle = window.title(), application.windowWithTitleShouldFloat(windowTitle) {
            floatingMap[window.windowID()] = true
        } else {
            floatingMap[window.windowID()] = window.shouldFloat()
        }

        application.observe(notification: kAXUIElementDestroyedNotification, window: window) { element in
            let window = Window(element: element)
            self.removeWindow(window)
        }
        application.observe(notification: kAXWindowMiniaturizedNotification, window: window) { element in
            let window = Window(element: element)

            self.removeWindow(window)

            guard let screen = window.screen() else {
                return
            }
            self.markScreenForReflow(screen, withChange: .remove(window: window))
        }

        guard let screen = window.screen() else {
            return
        }

        let windowChange: WindowChange = windowIsFloating(window) ? .unknown : .add(window: window)
        markScreenForReflow(screen, withChange: windowChange)
    }
}

extension WindowManager: WindowActivityCache {
    func windowIsActive<W: WindowType>(_ window: W) -> Bool {
        return window.isActive() && activeIDCache.contains(window.windowID())
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

        let windows: [Window] = self.windows(on: screen)

        // need to flip mouse coordinate system to fit Amethyst https://stackoverflow.com/a/45289010/2063546
        let flippedPointerLocation = NSPointToCGPoint(NSEvent.mouseLocation)
        let unflippedY = NSScreen.globalHeight() - flippedPointerLocation.y + screen.frameIncludingDockAndMenu().origin.y
        let pointerLocation = NSPointToCGPoint(NSPoint(x: flippedPointerLocation.x, y: unflippedY))

        if let screenManager: ScreenManager<Window> = focusedScreenManager(), let layout = screenManager.currentLayout {
            if let framedWindow = layout.windowAtPoint(pointerLocation, of: windows, on: screen) {
                return switchWindow(draggedWindow, with: framedWindow)
            }
        }

        // Ignore if there is no window at that point
        guard let secondWindow = WindowsInformation.alternateWindowForScreenAtPoint(pointerLocation, withWindows: windows, butNot: draggedWindow) else {
            return
        }
        switchWindow(draggedWindow, with: secondWindow)
    }
}
