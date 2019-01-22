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

enum WindowChange {
    case add(window: SIWindow)
    case remove(window: SIWindow)
    case focusChanged(window: SIWindow)
    case windowSwap(window: SIWindow, otherWindow: SIWindow)
    case unknown
}

// These are the possible actions that the mouse might be taking (that we care about).
//  We use this enum to convey some information about the window that the mouse
//  might be interacting with.
enum MouseState {
    case pointing
    case clicking
    case dragging
    case moving(window: SIWindow)
    case resizing(screen: NSScreen, ratio: CGFloat)
    case doneDragging(atTime: Date)
}

// MouseStateKeeper will need a few things to do its job effectively
protocol MouseStateKeeperDelegate: class {
    func focusedScreenManager() -> ScreenManager?
    func windows(on screen: NSScreen) -> [SIWindow]
    func switchWindow(_ window: SIWindow, with otherWindow: SIWindow)
    var lastReflowTime: Date { get }
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
class MouseStateKeeper {
    public let dragRaceThresholdSeconds = 0.15 // prevent race conditions during drag ops
    public var state: MouseState
    weak var delegate: MouseStateKeeperDelegate?
    private var monitor: Any?

    init() {
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
        guard let delegate = self.delegate else { return }
        delegate.focusedScreenManager()?.updateCurrentLayout { layout in
            if let panedLayout = layout as? PanedLayout {
                panedLayout.recommendMainPaneRatio(ratio)
            }
        }
    }

    // Execute an action that was initiated by the observer and completed by the state keeper
    func swapDraggedWindowWithDropzone(_ draggedWindow: SIWindow) {
        guard let delegate = self.delegate else { return }
        guard let screen = draggedWindow.screen() else { return }

        let windows = delegate.windows(on: screen)

        // need to flip mouse coordinate system to fit Amethyst https://stackoverflow.com/a/45289010/2063546
        let flippedPointerLocation = NSPointToCGPoint(NSEvent.mouseLocation)
        let unflippedY = NSScreen.globalHeight() - flippedPointerLocation.y + screen.frameIncludingDockAndMenu().origin.y
        let pointerLocation = NSPointToCGPoint(NSPoint(x: flippedPointerLocation.x, y: unflippedY))

        if let layout = delegate.focusedScreenManager()?.currentLayout {
            if let framedWindow = layout.windowAtPoint(pointerLocation, of: windows, on: screen) {
                return delegate.switchWindow(draggedWindow, with: framedWindow)
            }
        }

        // Ignore if there is no window at that point
        guard let secondWindow = SIWindow.alternateWindowForScreenAtPoint(pointerLocation, withWindows: windows, butNot: draggedWindow) else {
            return
        }
        delegate.switchWindow(draggedWindow, with: secondWindow)
    }
}

// This class sets up accessibility API event subscriptions for a given SIApplication,
// handling references to the window manager and mouse state.  The observers themselves
// react to mouse / accessibility state by either changing window positions or updating
// the mouse state based on new information
private class ObserveApplicationNotifications {
    enum Error: Swift.Error {
        case failed
    }

    fileprivate let application: SIApplication
    fileprivate let windowManager: WindowManager
    fileprivate let mouse: MouseStateKeeper

    init(application: SIApplication, windowManager: WindowManager) {
        self.application = application
        self.windowManager = windowManager
        mouse = windowManager.mouseStateKeeper
    }

    fileprivate func addObservers() -> Observable<Bool> {
        return _addObservers().retry(.exponentialDelayed(maxCount: 4, initial: 0.1, multiplier: 2))
    }

    private func _addObservers() -> Observable<Bool> {
        let application = self.application
        let windowManager = self.windowManager

        return Observable.create { observer in
            var success: Bool = false

            success = application.observeNotification(kAXCreatedNotification as CFString, with: application) { accessibilityElement in
                guard let window = accessibilityElement as? SIWindow else {
                    return
                }
                windowManager.addWindow(window)
            }

            guard success else {
                observer.on(.error(Error.failed))
                return Disposables.create()
            }

            application.observeNotification(kAXWindowDeminiaturizedNotification as CFString, with: application) { accessibilityElement in
                guard let window = accessibilityElement as? SIWindow else {
                    return
                }
                windowManager.addWindow(window)
            }

            application.observeNotification(kAXApplicationHiddenNotification as CFString, with: application) { accessibilityElement in
                guard let window = accessibilityElement as? SIWindow else {
                    return
                }
                windowManager.removeWindow(window)
            }

            application.observeNotification(kAXApplicationShownNotification as CFString, with: application) { accessibilityElement in
                guard let window = accessibilityElement as? SIWindow else {
                    return
                }
                windowManager.addWindow(window)
            }

            application.observeNotification(kAXFocusedWindowChangedNotification as CFString, with: application) { _ in
                guard let focusedWindow = SIWindow.focused(), let screen = focusedWindow.screen() else {
                    return
                }
                if windowManager.windows.index(of: focusedWindow) == nil {
                    windowManager.markScreenForReflow(screen, withChange: .unknown)
                } else {
                    windowManager.markScreenForReflow(screen, withChange: .focusChanged(window: focusedWindow))
                }
                windowManager.screenManager(for: screen)?.lastFocusedWindow = focusedWindow
            }

            application.observeNotification(kAXApplicationActivatedNotification as CFString, with: application) { _ in
                NSObject.cancelPreviousPerformRequests(
                    withTarget: windowManager,
                    selector: #selector(WindowManager.applicationActivated(_:)),
                    object: nil
                )
                windowManager.perform(#selector(WindowManager.applicationActivated(_:)), with: nil, afterDelay: 0.2)
            }

            application.observeNotification(kAXWindowMovedNotification as CFString, with: application) { accessibilityElement in
                guard windowManager.userConfiguration.mouseSwapsWindows() else {
                    return
                }

                guard let movedWindow = accessibilityElement as? SIWindow else {
                    return
                }

                guard let screen = movedWindow.screen(),
                    windowManager.activeWindows(on: screen).contains(movedWindow) else {
                    return
                }

                switch self.mouse.state {
                case .dragging:
                    // be aware of last reflow time, again to prevent race condition
                    guard let delegate = self.mouse.delegate else { break }
                    let reflowEndInterval = Date().timeIntervalSince(delegate.lastReflowTime)
                    guard reflowEndInterval > self.mouse.dragRaceThresholdSeconds else { break }

                    // record window and wait for mouse up
                    self.mouse.state = .moving(window: movedWindow)
                case let .doneDragging(lmbUpMoment):
                    self.mouse.state = .pointing // flip state first to prevent race condition

                    // if mouse button recently came up, assume window move is related
                    let dragEndInterval = Date().timeIntervalSince(lmbUpMoment)
                    guard dragEndInterval < self.mouse.dragRaceThresholdSeconds else { break }

                    self.mouse.swapDraggedWindowWithDropzone(movedWindow)
                default:
                    break
                }
            }

            application.observeNotification(kAXWindowResizedNotification as CFString, with: application) { accessibilityElement in
                guard windowManager.userConfiguration.mouseResizesWindows() else {
                    return
                }

                guard let resizedWindow = accessibilityElement as? SIWindow else {
                    return
                }

                guard let screen = resizedWindow.screen(),
                    windowManager.activeWindows(on: screen).contains(resizedWindow) else {
                        return
                }

                guard let screenManager = windowManager.focusedScreenManager(),
                    let layout = screenManager.currentLayout as? Layout & PanedLayout,
                    let oldFrame = layout.assignedFrame(resizedWindow, of: windowManager.activeWindowsForScreenManager(screenManager), on: screen) else {
                        return
                }

                let ratio = oldFrame.impliedMainPaneRatio(windowFrame: resizedWindow.frame())

                switch self.mouse.state {
                case .dragging, .resizing:
                    // record window and wait for mouse up
                    self.mouse.state = .resizing(screen: screen, ratio: ratio)
                case let .doneDragging(lmbUpMoment):
                    // if mouse button recently came up, assume window resize is related
                    let dragEndInterval = Date().timeIntervalSince(lmbUpMoment)
                    if dragEndInterval < self.mouse.dragRaceThresholdSeconds {
                        self.mouse.state = .pointing // flip state first to prevent race condition
                        windowManager.focusedScreenManager()?.updateCurrentLayout { layout in
                            if let panedLayout = layout as? PanedLayout {
                                panedLayout.recommendMainPaneRatio(ratio)
                            }
                        }
                    }
                default:
                    break
                }

            }
            observer.on(.next(true))
            observer.on(.completed)
            return Disposables.create()
        }
    }
}

final class WindowManager: NSObject, MouseStateKeeperDelegate {
    private var applications: [SIApplication] = []
    private(set) var mouseStateKeeper = MouseStateKeeper()
    var windows: [SIWindow] = []
    fileprivate let userConfiguration: UserConfiguration

    private(set) var screenManagers: [ScreenManager] = []
    private var screenManagersCache: [String: ScreenManager] = [:]

    private let focusFollowsMouseManager: FocusFollowsMouseManager

    fileprivate private(set) var activeIDCache: Set<CGWindowID> = Set()
    private(set) var floatingMap: [CGWindowID: Bool] = [:]

    public private(set) var lastReflowTime: Date

    private let disposeBag = DisposeBag()

    init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        self.focusFollowsMouseManager = FocusFollowsMouseManager(userConfiguration: userConfiguration)
        lastReflowTime = Date()
        super.init()

        mouseStateKeeper.delegate = self
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

        guard let windowDescriptions = SIWindow.windowDescriptions(.optionOnScreenOnly, windowID: CGWindowID(0)) else {
            return
        }

        for windowDescription in windowDescriptions {
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
                    LogManager.log?.error("Could not identify screen with info: \(screenDictionary)")
                    continue
                }

                guard let screenManager = screenManagersCache[screenIdentifier] else {
                    LogManager.log?.error("Screen with identifier not managed: \(screenIdentifier)")
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

    private func screenManagerForCGWindowDescription(_ description: [String: AnyObject]) -> ScreenManager? {
        let windowFrameDictionary = description[kCGWindowBounds as String] as! [String: Any]
        let windowFrame = CGRect(dictionaryRepresentation: windowFrameDictionary as CFDictionary)!

        var lastVolume: CGFloat = 0
        var lastScreenManager: ScreenManager?

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

    func reevaluateWindows() {
        for runningApplication in NSWorkspace.shared.runningApplications {
            guard runningApplication.isManageable else {
                continue
            }

            let application = SIApplication(runningApplication: runningApplication)
            addApplication(application)
        }
        markAllScreensForReflowWithChange(.unknown)
    }

    func focusedScreenManager() -> ScreenManager? {
        guard let focusedWindow = SIWindow.focused() else {
            return nil
        }
        for screenManager in screenManagers {
            if screenManager.screen.screenIdentifier() == focusedWindow.screen()?.screenIdentifier() {
                return screenManager
            }
        }
        return nil
    }

    fileprivate func applicationWithProcessIdentifier(_ processIdentifier: pid_t) -> SIApplication? {
        for application in applications {
            if application.processIdentifier() == processIdentifier {
                return application
            }
        }

        return nil
    }

    fileprivate func addApplication(_ application: SIApplication) {
        guard !applications.contains(application) else {
            for window in application.windows() as! [SIWindow] {
                addWindow(window)
            }
            return
        }

        let applicationObservers = ObserveApplicationNotifications(application: application, windowManager: self)

        applicationObservers.addObservers()
            .subscribe(
                onCompleted: { [weak self] in
                    guard let strongSelf = self else { return }

                    strongSelf.applications.append(application)

                    for window in application.windows() as! [SIWindow] {
                        strongSelf.addWindow(window)
                    }
                }
            )
            .disposed(by: disposeBag)
    }

    fileprivate func removeApplication(_ application: SIApplication) {
        for window in application.windows() as! [SIWindow] {
            removeWindow(window)
        }
        guard let applicationIndex = applications.index(of: application) else {
            return
        }
        applications.remove(at: applicationIndex)
    }

    fileprivate func activateApplication(_ application: SIApplication) {
        for window in windows {
            if window.processIdentifier() == application.processIdentifier() {
                guard let screen = window.screen() else {
                    return
                }
                markScreenForReflow(screen, withChange: .unknown)
            }
        }
    }

    fileprivate func deactivateApplication(_ application: SIApplication) {
        for window in windows {
            if window.processIdentifier() == application.processIdentifier() {
                guard let screen = window.screen() else {
                    return
                }
                markScreenForReflow(screen, withChange: .unknown)
            }
        }
    }

    fileprivate func addWindow(_ window: SIWindow) {
        guard !windows.contains(window) && window.shouldBeManaged() else {
            return
        }

        regenerateActiveIDCache()

        if userConfiguration.sendNewWindowsToMainPane() {
            windows.insert(window, at: 0)
        } else {
            windows.append(window)
        }

        guard let application = applicationWithProcessIdentifier(window.processIdentifier()) else {
            LogManager.log?.error("Tried to add a window without an application")
            return
        }

        if let windowTitle = window.title(), application.windowWithTitleShouldFloat(windowTitle) {
            floatingMap[window.windowID()] = true
        } else {
            floatingMap[window.windowID()] = window.shouldFloat()
        }

        application.observeNotification(kAXUIElementDestroyedNotification as CFString, with: window) { element in
            guard let window = element as? SIWindow else {
                return
            }
            self.removeWindow(window)
        }
        application.observeNotification(kAXWindowMiniaturizedNotification as CFString, with: window) { element in
            guard let window = element as? SIWindow else {
                return
            }
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

    fileprivate func removeWindow(_ window: SIWindow) {
        markAllScreensForReflowWithChange(.remove(window: window))

        let application = applicationWithProcessIdentifier(window.processIdentifier())
        application?.unobserveNotification(kAXUIElementDestroyedNotification as CFString, with: window)
        application?.unobserveNotification(kAXWindowMiniaturizedNotification as CFString, with: window)
        application?.unobserveNotification(kAXWindowDeminiaturizedNotification as CFString, with: window)

        regenerateActiveIDCache()

        guard let windowIndex = windows.index(of: window) else {
            return
        }

        windows.remove(at: windowIndex)
    }

    func toggleFloatForFocusedWindow() {
        guard let focusedWindow = SIWindow.focused() else {
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

        let windowChange: WindowChange = .add(window: focusedWindow)
        addWindow(focusedWindow)
        floatingMap[focusedWindow.windowID()] = false
        markScreenForReflow(screen, withChange: windowChange)
    }

    fileprivate func updateScreenManagers() {
        var screenManagers: [ScreenManager] = []

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

    func markAllScreensForReflowWithChange(_ windowChange: WindowChange) {
        for screenManager in screenManagers {
            screenManager.setNeedsReflowWithWindowChange(windowChange)
        }
    }

    func displayCurrentLayout() {
        for screenManager in screenManagers {
            screenManager.displayLayoutHUD()
        }
    }
}

extension WindowManager {
    @objc func applicationActivated(_ sender: AnyObject) {
        guard let focusedWindow = SIWindow.focused(), let screen = focusedWindow.screen() else {
            return
        }
        markScreenForReflow(screen, withChange: .unknown)
    }

    @objc func applicationDidLaunch(_ notification: Notification) {
        guard let launchedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        let application = SIApplication(runningApplication: launchedApplication)
        addApplication(application)
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

            for window in application.windows() as! [SIWindow] {
                addWindow(window)
            }
        }

        markAllScreensForReflowWithChange(.unknown)
    }

    @objc func screenParametersDidChange(_ notification: Notification) {
        updateScreenManagers()
    }
}

extension WindowManager: WindowActivityCache {
    func windowIsActive(_ window: SIWindow) -> Bool {
        return window.isActive() && activeIDCache.contains(window.windowID())
    }
}
