//
//  WindowManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/14/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import AppKit
import Foundation
import Silica

public class WindowManager: NSObject, ScreenManagerDelegate {
    private var applications: [SIApplication] = []
    private var windows: [SIWindow] = []

    private var screenManagers: [ScreenManager] = []
    private let screenManagersCache: NSCache = NSCache()

    private var mouseMovedEventHandler: AnyObject?

    private var activeIDCache: [CGWindowID: Bool] = [:]
    private var floatingMap: [CGWindowID: Bool] = [:]

    public override init() {
        super.init()

        for runningApplication in NSWorkspace.sharedWorkspace().runningApplications {
            guard runningApplication.isManageable else {
                continue
            }

            let application = SIApplication(runningApplication: runningApplication)
            addApplication(application)
        }

        let workspaceNotificationCenter = NSWorkspace.sharedWorkspace().notificationCenter
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(applicationDidLaunch(_:)),
            name: NSWorkspaceDidLaunchApplicationNotification,
            object: nil
        )
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTerminate(_:)),
            name: NSWorkspaceDidTerminateApplicationNotification,
            object: nil
        )
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(applicationDidHide(_:)),
            name: NSWorkspaceDidHideApplicationNotification,
            object: nil
        )
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(applicationDidUnhide(_:)),
            name: NSWorkspaceDidUnhideApplicationNotification,
            object: nil
        )
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange(_:)),
            name: NSWorkspaceActiveSpaceDidChangeNotification,
            object: nil
        )

        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplicationDidChangeScreenParametersNotification,
            object: nil
        )

        mouseMovedEventHandler = NSEvent.addGlobalMonitorForEventsMatchingMask(NSEventMask.MouseMovedMask) { event in
            self.focusWindowWithMouseMovedEvent(event)
        }

        updateScreenManagers()
    }

    deinit {
        NSWorkspace.sharedWorkspace().notificationCenter.removeObserver(self)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    private func windowDescriptions(options: CGWindowListOption, windowID: CGWindowID) -> [[String: AnyObject]]? {
        guard
            let cfWindowDescriptions = CGWindowListCopyWindowInfo(options, windowID),
            let windowDescriptions = cfWindowDescriptions as NSArray as? [[String: AnyObject]]
        else {
            return nil
        }
        return windowDescriptions
    }

    private func screenDescriptions() -> [[String: AnyObject]]? {
        let cfScreenDescriptions = CGSCopyManagedDisplaySpaces(_CGSDefaultConnection()).takeRetainedValue()
        guard let screenDescriptions = cfScreenDescriptions as NSArray as? [[String: AnyObject]] else {
            return nil
        }
        return screenDescriptions
    }

    private func windowIsFloating(window: SIWindow) -> Bool {
        return floatingMap[window.windowID()] ?? false
    }

    public func regenerateActiveIDCache() {
        var activeIDCache: [CGWindowID: Bool] = [:]
        defer {
            self.activeIDCache = activeIDCache
        }

        guard let windowDescriptions = windowDescriptions(.OptionOnScreenOnly, windowID: CGWindowID(0)) else {
            return
        }

        for windowDescription in windowDescriptions {
            guard let windowID = windowDescription[kCGWindowNumber as String] as? NSNumber else {
                continue
            }

            activeIDCache[CGWindowID(windowID.unsignedLongLongValue)] = true
        }
    }

    public func assignCurrentSpaceIdentifiers() {
        regenerateActiveIDCache()

        guard let screenDictionaries = screenDescriptions() else {
            return
        }

        if NSScreen.screensHaveSeparateSpaces() {
            for screenDictionary in screenDictionaries {
                let screenIdentifier = screenDictionary["Display Identifier"] as? String
                let spaceDictionary = screenDictionary["Current Space"] as? [String: AnyObject]
                let spaceIdentifier = spaceDictionary?["uuid"] as? String
                let screenManager = screenManagersCache.objectForKey(screenIdentifier!) as! ScreenManager

                guard screenManager.currentSpaceIdentifier != spaceIdentifier else {
                    continue
                }

                screenManager.currentSpaceIdentifier = spaceIdentifier
            }
        } else {
            for screenManager in screenManagers {
                let screenDictionary = screenDictionaries.first
                let spaceDictionary = screenDictionary?["Current Space"] as? [String: AnyObject]
                let spaceIdentifier = spaceDictionary?["uuid"] as? String

                guard screenManager.currentSpaceIdentifier != spaceIdentifier else {
                    continue
                }

                screenManager.currentSpaceIdentifier = spaceIdentifier
            }
        }
    }

    public func screenManagerForCGWindowDescription(description: [String: AnyObject]) -> ScreenManager? {
        var windowFrame: CGRect = CGRect.zero
        let windowFrameDictionary = description[kCGWindowBounds as String] as? [String: AnyObject]
        CGRectMakeWithDictionaryRepresentation(windowFrameDictionary, &windowFrame)

        var lastVolume: CGFloat = 0
        var lastScreenManager: ScreenManager?

        for screenManager in screenManagers {
            let screenFrame = screenManager.screen.frameIncludingDockAndMenu()
            let intersection = CGRectIntersection(windowFrame, screenFrame)
            let volume = intersection.size.width * intersection.size.height

            if volume > lastVolume {
                lastVolume = volume
                lastScreenManager = screenManager
            }
        }

        return lastScreenManager
    }

    public func focusedScreenManager() -> ScreenManager? {
        let focusedWindow = SIWindow.focusedWindow()
        for screenManager in screenManagers {
            if screenManager.screen.screenIdentifier() == focusedWindow.screen().screenIdentifier() {
                return screenManager
            }
        }
        return nil
    }

    public func throwToScreenAtIndex(screenIndex: Int) {
        let screenArrayIndex = screenIndex - 1

        guard screenArrayIndex < NSScreen.screens()?.count else {
            return
        }

        let screenManager = screenManagers[screenArrayIndex]
        var focusedWindow = SIWindow.focusedWindow()

        // Have to find the managed window object so that we can clear it's screen cache.
        for window in windows {
            if window == focusedWindow {
                focusedWindow = window
            }
        }

        // If the window is already on the screen do nothing.
        guard focusedWindow.screen().screenIdentifier() != screenManager.screen.screenIdentifier() else {
            return
        }

        markScreenForReflow(focusedWindow.screen())
        focusedWindow.moveToScreen(screenManager.screen)
        markScreenForReflow(screenManager.screen)
        focusedWindow.am_focusWindow()
    }

    public func focusScreenAtIndex(screenIndex: Int) {
        let screenArrayIndex = screenIndex - 1

        guard screenArrayIndex < NSScreen.screens()?.count else {
            return
        }

        let screenManager = screenManagers[screenArrayIndex]
        let windows = windowsForScreen(screenManager.screen)

        if windows.count == 0 && Configuration.sharedConfiguration.mouseFollowsFocus() {
            screenManager.screen.focusScreen()
        } else if windows.count > 0 {
            windows.first?.am_focusWindow()
        }
    }

    public func moveFocusCounterClockwise() {
        guard let focusedWindow = SIWindow.focusedWindow() else {
            focusScreenAtIndex(1)
            return
        }

        let screen = focusedWindow.screen()
        let windows = windowsForScreen(screen)

        // If there are no windows there is nothing to change focus to.
        guard windows.count > 0 else {
            return
        }

        let windowIndex = windows.indexOf(focusedWindow) ?? 0
        let windowToFocusIndex = (windowIndex == 0 ? windows.count - 1 : windowIndex - 1)
        let windowToFocus = windows[windowToFocusIndex]

        windowToFocus.am_focusWindow()
    }

    public func moveFocusClockwise() {
        guard let focusedWindow = SIWindow.focusedWindow() else {
            focusScreenAtIndex(1)
            return
        }

        let screen = focusedWindow.screen()
        let windows = windowsForScreen(screen)

        // If there are no windows there is nothing to change focus to.
        guard windows.count > 0 else {
            return
        }

        var windowIndex = windows.indexOf(focusedWindow) ?? NSNotFound
        if windowIndex == NSNotFound {
            windowIndex = windows.count - 1
        }

        let windowToFocus = windows[(windowIndex + 1) % windows.count]

        windowToFocus.am_focusWindow()
    }

    public func swapFocusedWindowToMain() {
        guard let focusedWindow = SIWindow.focusedWindow() where !windowIsFloating(focusedWindow) else {
            return
        }

        let screen = focusedWindow.screen()
        let windows = activeWindowsForScreen(screen)

        guard windows.count > 0 else {
            return
        }

        guard
            let mainWindowIndex = windows.indexOf(windows[0]),
            let focusedWindowIndex = windows.indexOf(focusedWindow)
        else {
            return
        }

        let mainWindow = self.windows[mainWindowIndex]

        self.windows[mainWindowIndex] = focusedWindow
        self.windows[focusedWindowIndex] = mainWindow

        markScreenForReflow(focusedWindow.screen())
        focusedWindow.am_focusWindow()
    }

    public func swapFocusedWindowCounterClockwise() {
        guard let focusedWindow = SIWindow.focusedWindow() where !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(1)
            return
        }

        let screen = focusedWindow.screen()
        let windows = activeWindowsForScreen(screen)

        guard let focusedWindowIndex = windows.indexOf(focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex == 0 ? windows.count - 1 : focusedWindowIndex - 1)]

        guard
            let focusedWindowActiveIndex = self.windows.indexOf(focusedWindow),
            let windowToSwapWithActiveIndex = self.windows.indexOf(windowToSwapWith)
        else {
            return
        }

        self.windows[focusedWindowActiveIndex] = windowToSwapWith
        self.windows[windowToSwapWithActiveIndex] = focusedWindow

        markScreenForReflow(focusedWindow.screen())
        focusedWindow.am_focusWindow()
    }

    public func swapFocusedWindowClockwise() {
        guard let focusedWindow = SIWindow.focusedWindow() where !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(1)
            return
        }

        let screen = focusedWindow.screen()
        let windows = activeWindowsForScreen(screen)

        let focusedWindowIndex = windows.indexOf(focusedWindow) ?? NSNotFound
        guard focusedWindowIndex != NSNotFound else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex + 1) % windows.count]

        guard
            let focusedWindowActiveIndex = self.windows.indexOf(focusedWindow),
            let windowToSwapWithActiveIndex = self.windows.indexOf(windowToSwapWith)
        else {
            return
        }

        self.windows[focusedWindowActiveIndex] = windowToSwapWith
        self.windows[windowToSwapWithActiveIndex] = focusedWindow

        markScreenForReflow(focusedWindow.screen())
        focusedWindow.am_focusWindow()
    }

    public func swapFocusedWindowScreenClockwise() {
        guard let focusedWindow = SIWindow.focusedWindow() where !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(1)
            return
        }

        let screen = focusedWindow.screen()
        var screenIndex = screenManagers.indexOf() { screenManager -> Bool in
            if screenManager.screen.screenIdentifier() == screen.screenIdentifier() {
                return true
            }
            return false
        } ?? NSNotFound
        if screenIndex == NSNotFound {
            return
        }

        screenIndex = (screenIndex + 1) % screenManagers.count

        let screenToMoveTo = screenManagers[screenIndex].screen
        focusedWindow.moveToScreen(screenToMoveTo)

        markScreenForReflow(screen)
        markScreenForReflow(screenToMoveTo)
    }

    public func swapFocusedWindowScreenCounterClockwise() {
        guard let focusedWindow = SIWindow.focusedWindow() where !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(1)
            return
        }

        let screen = focusedWindow.screen()
        var screenIndex = screenManagers.indexOf() { screenManager -> Bool in
            if screenManager.screen.screenIdentifier() == screen.screenIdentifier() {
                return true
            }
            return false
        } ?? NSNotFound
        if screenIndex == NSNotFound {
            return
        }

        screenIndex = (screenIndex == 0 ? screenManagers.count - 1 : screenIndex - 1)

        let screenToMoveTo = self.screenManagers[screenIndex].screen
        focusedWindow.moveToScreen(screenToMoveTo)

        markScreenForReflow(screen)
        markScreenForReflow(screenToMoveTo)
    }

    public func pushFocusedWindowToSpace(space: UInt) {
        guard let focusedWindow = SIWindow.focusedWindow() else {
            return
        }

        focusedWindow.moveToSpace(space)
        focusedWindow.am_focusWindow()
    }

    public func applicationDidLaunch(notification: NSNotification) {
        guard let launchedApplication = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication else {
            return
        }
        let application = SIApplication(runningApplication: launchedApplication)
        addApplication(application)
    }

    public func applicationDidTerminate(notification: NSNotification) {
        guard
            let terminatedApplication = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication,
            let application = applicationWithProcessIdentifier(terminatedApplication.processIdentifier)
        else {
            return
        }
        removeApplication(application)
    }

    public func applicationDidHide(notification: NSNotification) {
        guard
            let hiddenApplication = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication,
            let application = applicationWithProcessIdentifier(hiddenApplication.processIdentifier)
        else {
            return
        }
        deactivateApplication(application)
    }

    public func applicationDidUnhide(notification: NSNotification) {
        guard
            let unhiddenApplication = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication,
            let application = applicationWithProcessIdentifier(unhiddenApplication.processIdentifier)
        else {
            return
        }
        activateApplication(application)
    }

    public func activeSpaceDidChange(notification: NSNotification) {
        assignCurrentSpaceIdentifiers()

        for runningApplication in NSWorkspace.sharedWorkspace().runningApplications {
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

        markAllScreensForReflow()
    }

    public func screenParametersDidChange(notification: NSNotification) {
        updateScreenManagers()
    }

    private func applicationWithProcessIdentifier(processIdentifier: pid_t) -> SIApplication? {
        for application in applications {
            if application.processIdentifier() == processIdentifier {
                return application
            }
        }

        return nil
    }

    private func addApplication(application: SIApplication) {
        guard !applications.contains(application) else {
            return
        }

        applications.append(application)

        for window in application.windows() as! [SIWindow] {
            addWindow(window)
        }

        let floating = application.floating()

        application.observeNotification(
            kAXWindowCreatedNotification,
            withElement: application,
            handler: { accessibilityElement in
                guard let window = accessibilityElement as? SIWindow else {
                    return
                }
                self.floatingMap[window.windowID()] = floating
                self.addWindow(window)
            }
        )
        application.observeNotification(
            kAXFocusedWindowChangedNotification,
            withElement:application,
            handler: { accessibilityElement in
                guard let focusedWindow = SIWindow.focusedWindow() else {
                    return
                }
                self.markScreenForReflow(focusedWindow.screen())
            }
        )
        application.observeNotification(
            kAXApplicationActivatedNotification,
            withElement:application,
            handler: { accessibilityElement in
                NSObject.cancelPreviousPerformRequestsWithTarget(
                    self,
                    selector: #selector(WindowManager.applicationActivated(_:)),
                    object: nil
                )
                self.performSelector(#selector(WindowManager.applicationActivated(_:)), withObject: nil, afterDelay: 0.2)
            }
        )
    }

    public func applicationActivated(sender: AnyObject) {
        guard let focusedWindow = SIWindow.focusedWindow() else {
            return
        }
        markScreenForReflow(focusedWindow.screen())
    }

    private func removeApplication(application: SIApplication) {
        for window in application.windows() as! [SIWindow] {
            removeWindow(window)
        }
        guard let applicationIndex = applications.indexOf(application) else {
            return
        }
        applications.removeAtIndex(applicationIndex)
    }

    private func activateApplication(application: SIApplication) {
        let processIdentifier = application.processIdentifier()
        for window in windows {
            if window.processIdentifier() == processIdentifier {
                markScreenForReflow(window.screen())
            }
        }
    }

    private func deactivateApplication(application: SIApplication) {
        let processIdentifier = application.processIdentifier()
        for window in windows {
            if window.processIdentifier() == processIdentifier {
                markScreenForReflow(window.screen())
            }
        }
    }

    private func addWindow(window: SIWindow) {
        guard !windows.contains(window) && window.shouldBeManaged() else {
            return
        }

        regenerateActiveIDCache()

        windows.append(window)
        markScreenForReflow(window.screen())

        guard let application = applicationWithProcessIdentifier(window.processIdentifier()) else {
            return
        }

        floatingMap[window.windowID()] = application.floating()
        if Configuration.sharedConfiguration.floatSmallWindows() && window.frame().size.width < 500 && window.frame().size.height < 500 {
            floatingMap[window.windowID()] = true
        }

        application.observeNotification(
            kAXUIElementDestroyedNotification,
            withElement: window,
            handler: { accessibilityElement in
                self.removeWindow(window)
            }
        )
        application.observeNotification(
            kAXWindowMiniaturizedNotification,
            withElement: window,
            handler: { accessibilityElement in
                self.markScreenForReflow(window.screen())
            }
        )
        application.observeNotification(
            kAXWindowDeminiaturizedNotification,
            withElement: window,
            handler: { accessibilityElement in
                self.markScreenForReflow(window.screen())
            }
        )
    }

    private func removeWindow(window: SIWindow) {
        markAllScreensForReflow()

        let application = applicationWithProcessIdentifier(window.processIdentifier())
        application?.unobserveNotification(kAXUIElementDestroyedNotification, withElement: window)
        application?.unobserveNotification(kAXWindowMiniaturizedNotification, withElement: window)
        application?.unobserveNotification(kAXWindowDeminiaturizedNotification, withElement: window)

        regenerateActiveIDCache()
        guard let windowIndex = windows.indexOf(window) else {
            return
        }
        windows.removeAtIndex(windowIndex)
    }

    private func windowsForScreen(screen: NSScreen) -> [SIWindow] {
        let screenIdentifier = screen.screenIdentifier()
        guard let spaces = screenDescriptions() else {
            return []
        }

        var currentSpace: CGSSpace?
        if NSScreen.screensHaveSeparateSpaces() {
            for screenDictionary in spaces {
                let spaceScreenIdentifier = screenDictionary["Display Identifier"] as? String

                if spaceScreenIdentifier == screenIdentifier {
                    guard
                        let spaceDictionary = screenDictionary["Current Space"] as? [String: AnyObject],
                        let spaceIdentifier = spaceDictionary["ManagedSpaceID"] as? NSNumber
                    else {
                        continue
                    }
                    currentSpace = spaceIdentifier.unsignedLongLongValue
                    break
                }
            }
        } else {
            let spaceDictionary = spaces[0]["Current Space"] as? [String: AnyObject]
            currentSpace = (spaceDictionary?["ManagedSpaceID"] as? NSNumber)?.unsignedLongLongValue
        }

        guard currentSpace != nil else {
            print("Could not find a space for screen: \(screenIdentifier)")
            return []
        }

        let screenWindows = windows.filter() { window in
            let windowIDsArray = [NSNumber(unsignedInt: window.windowID())] as NSArray
            let spaces = CGSCopySpacesForWindows(_CGSDefaultConnection(), CGSSpaceSelector(7), windowIDsArray).takeRetainedValue() as NSArray as? [NSNumber]
            let space = spaces?.first?.unsignedLongLongValue

            guard space == currentSpace else {
                return false
            }

            return window.screen().screenIdentifier() == screen.screenIdentifier() && window.isActive() && self.activeIDCache[window.windowID()] == true
        }
        return screenWindows
    }

    private func activeWindowsForScreen(screen: NSScreen) -> [SIWindow] {
        let activeWindows = windowsForScreen(screen).filter() { window in
            return window.shouldBeManaged() && !windowIsFloating(window)
        }
        return activeWindows
    }

    public func toggleFloatForFocusedWindow() {
        guard let focusedWindow = SIWindow.focusedWindow() else {
            return
        }

        for window in windows {
            if window == focusedWindow {
                floatingMap[window.windowID()] = !windowIsFloating(window)
                markScreenForReflow(window.screen())
                return
            }
        }

        addWindow(focusedWindow)
        floatingMap[focusedWindow.windowID()] = false
        markScreenForReflow(focusedWindow.screen())
    }

    private func updateScreenManagers() {
        var screenManagers: [ScreenManager] = []

        for screen in NSScreen.screens() ?? [] {
            let screenIdentifier = screen.screenIdentifier()
            var screenManager: ScreenManager? = screenManagersCache.objectForKey(screenIdentifier) as? ScreenManager

            if screenManager == nil {
                screenManager = ScreenManager(screen:screen, screenIdentifier:screenIdentifier, delegate:self)
                screenManagersCache.setObject(screenManager!, forKey:screenIdentifier)
            }

            screenManager!.screen = screen

            screenManagers.append(screenManager!)
        }

        // Window managers are sorted by screen position along the x-axis.
        screenManagers.sortInPlace() { screenManager1, screenManager2 -> Bool in
            let x1 = screenManager1.screen.frameWithoutDockOrMenu().origin.x
            let x2 = screenManager2.screen.frameWithoutDockOrMenu().origin.x

            return x1 < x2
        }

        self.screenManagers = screenManagers

        assignCurrentSpaceIdentifiers()
        markAllScreensForReflow()
    }

    public func markAllScreensForReflow() {
        for screenManager in screenManagers {
            screenManager.setNeedsReflow()
        }
    }

    private func markScreenForReflow(screen: NSScreen) {
        for screenManager in screenManagers {
            guard screenManager.screen.screenIdentifier() == screen.screenIdentifier() else {
                continue
            }

            screenManager.setNeedsReflow()
        }
    }

    public func displayCurrentLayout() {
        for screenManager in screenManagers {
            screenManager.displayLayoutHUD()
        }
    }

    public func activeWindowsForScreenManager(screenManager: ScreenManager) -> [SIWindow] {
        return activeWindowsForScreen(screenManager.screen)
    }

    public func windowIsActive(window: SIWindow) -> Bool {
        if !window.isActive() {
            return false
        }
        if activeIDCache[window.windowID()] == nil {
            return false
        }
        return true
    }

    private func focusWindowWithMouseMovedEvent(event: NSEvent) {
        guard Configuration.sharedConfiguration.focusFollowsMouse() else {
            return
        }

        var mousePoint = NSPointToCGPoint(event.locationInWindow)
        mousePoint.y = NSScreen.mainScreen()!.frame.size.height - mousePoint.y

        var window = SIWindow.focusedWindow()

        // If the point is already in the frame of the focused window do nothing.
        guard !CGRectContainsPoint(window.frame(), mousePoint) else {
            return
        }

        guard
            let windowDescriptions = windowDescriptions(.OptionOnScreenOnly, windowID: CGWindowID(0))
            where windowDescriptions.count > 0
        else {
            return
        }

        var windowsAtPoint: [[String: AnyObject]] = []
        for windowDescription in windowDescriptions {
            var windowFrame: CGRect = CGRect.zero
            guard let windowFrameDictionary = windowDescription[kCGWindowBounds as String] as? [String: AnyObject] else {
                continue
            }
            CGRectMakeWithDictionaryRepresentation(windowFrameDictionary, &windowFrame)

            guard CGRectContainsPoint(windowFrame, mousePoint) else {
                continue
            }
            windowsAtPoint.append(windowDescription)
        }

        guard windowsAtPoint.count > 0 else {
            return
        }

        // If there is only one window at that point focus it
        guard windowsAtPoint.count > 1 else {
            let window = windowForCGWindowDescription(windowsAtPoint[0])
            window?.focusWindow()
            return
        }

        // Otherwise find the window that's actually on top
        var windowToFocus: [String: AnyObject]?
        var minCount = windowDescriptions.count
        for windowDescription in windowsAtPoint {
            guard
                let windowID = windowDescription[kCGWindowNumber as String] as? NSNumber,
                let windowsAboveWindow = self.windowDescriptions(.OptionOnScreenAboveWindow, windowID: windowID.unsignedIntValue)
            else {
                continue
            }

            if windowsAboveWindow.count < minCount {
                windowToFocus = windowDescription
                minCount = windowsAboveWindow.count
            }
        }

        guard let windowDictionaryToFocus = windowToFocus else {
            return
        }

        window = windowForCGWindowDescription(windowDictionaryToFocus)
        window?.focusWindow()
    }

    private func windowForCGWindowDescription(windowDescription: [String: AnyObject]) -> SIWindow? {
        for window in windows {
            guard
                let windowOwnerProcessIdentifier = windowDescription[kCGWindowOwnerPID as String] as? NSNumber
                where windowOwnerProcessIdentifier.intValue == window.processIdentifier()
            else {
                continue
            }

            var windowFrame: CGRect = CGRect.zero
            guard let boundsDictionary = windowDescription[kCGWindowBounds as String] as? [String: AnyObject] else {
                continue
            }
            CGRectMakeWithDictionaryRepresentation(boundsDictionary, &windowFrame)
            if !CGRectEqualToRect(windowFrame, window.frame()) {
                continue
            }

            guard let windowTitle = windowDescription[kCGWindowName as String] as? String where windowTitle == window.stringForKey(kAXTitleAttribute) else {
                continue
            }

            return window
        }

        return nil
    }
}
