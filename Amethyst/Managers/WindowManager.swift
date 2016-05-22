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

public class WindowManager: NSObject {
    internal var applications: [SIApplication] = []
    internal var windows: [SIWindow] = []
    internal let windowModifier = WindowModifier()

    internal var screenManagers: [ScreenManager] = []
    private let screenManagersCache: NSCache = NSCache()

    private let focusFollowsMouseManager = FocusFollowsMouseManager()

    internal var activeIDCache: [CGWindowID: Bool] = [:]
    internal var floatingMap: [CGWindowID: Bool] = [:]

    public override init() {
        super.init()

        focusFollowsMouseManager.delegate = self
        windowModifier.delegate = self

        for runningApplication in NSWorkspace.sharedWorkspace().runningApplications {
            guard runningApplication.isManageable else {
                continue
            }

            let application = SIApplication(runningApplication: runningApplication)
            addApplication(application)
        }

        addWorkspaceNotificationObserver(NSWorkspaceDidLaunchApplicationNotification, selector: #selector(applicationDidLaunch(_:)))
        addWorkspaceNotificationObserver(NSWorkspaceDidTerminateApplicationNotification, selector: #selector(applicationDidTerminate(_:)))
        addWorkspaceNotificationObserver(NSWorkspaceDidHideApplicationNotification, selector: #selector(applicationDidHide(_:)))
        addWorkspaceNotificationObserver(NSWorkspaceDidUnhideApplicationNotification, selector: #selector(applicationDidUnhide(_:)))
        addWorkspaceNotificationObserver(NSWorkspaceActiveSpaceDidChangeNotification, selector: #selector(activeSpaceDidChange(_:)))

        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplicationDidChangeScreenParametersNotification,
            object: nil
        )

        updateScreenManagers()
    }

    deinit {
        NSWorkspace.sharedWorkspace().notificationCenter.removeObserver(self)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    private func addWorkspaceNotificationObserver(name: String, selector: Selector) {
        let workspaceNotificationCenter = NSWorkspace.sharedWorkspace().notificationCenter
        workspaceNotificationCenter.addObserver(self, selector: selector, name: name, object: nil)
    }

    public func regenerateActiveIDCache() {
        var activeIDCache: [CGWindowID: Bool] = [:]
        defer {
            self.activeIDCache = activeIDCache
        }

        guard let windowDescriptions = SIWindow.windowDescriptions(.OptionOnScreenOnly, windowID: CGWindowID(0)) else {
            return
        }

        for windowDescription in windowDescriptions {
            guard let windowID = windowDescription[kCGWindowNumber as String] as? NSNumber else {
                continue
            }

            activeIDCache[CGWindowID(windowID.unsignedLongLongValue)] = true
        }
    }

    private func spaceIdentifierWithScreenDictionary(screenDictionary: [String: AnyObject]) -> String? {
        let spaceDictionary = screenDictionary["Current Space"] as? [String: AnyObject]
        return spaceDictionary?["uuid"] as? String
    }

    public func assignCurrentSpaceIdentifiers() {
        regenerateActiveIDCache()

        guard let screenDictionaries = NSScreen.screenDescriptions() else {
            return
        }

        if NSScreen.screensHaveSeparateSpaces() {
            for screenDictionary in screenDictionaries {
                let screenIdentifier = screenDictionary["Display Identifier"] as? String
                let screenManager = screenManagersCache.objectForKey(screenIdentifier!) as! ScreenManager

                guard let spaceIdentifier = spaceIdentifierWithScreenDictionary(screenDictionary) where screenManager.currentSpaceIdentifier != spaceIdentifier else {
                    continue
                }

                screenManager.currentSpaceIdentifier = spaceIdentifier
            }
        } else {
            for screenManager in screenManagers {
                let screenDictionary = screenDictionaries[0]

                guard let spaceIdentifier = spaceIdentifierWithScreenDictionary(screenDictionary) where screenManager.currentSpaceIdentifier != spaceIdentifier else {
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
            let intersection = windowFrame.intersect(screenFrame)
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

        application.observeNotification(kAXWindowCreatedNotification, withElement: application) { accessibilityElement in
            guard let window = accessibilityElement as? SIWindow else {
                return
            }
            self.floatingMap[window.windowID()] = floating
            self.addWindow(window)
        }
        application.observeNotification(kAXWindowDeminiaturizedNotification, withElement: application) { accessibilityElement in
            guard let window = accessibilityElement as? SIWindow else {
                return
            }
            self.addWindow(window)
        }
        application.observeNotification(kAXFocusedWindowChangedNotification, withElement:application) { accessibilityElement in
            guard let focusedWindow = SIWindow.focusedWindow() else {
                return
            }
            self.markScreenForReflow(focusedWindow.screen())
        }
        application.observeNotification(kAXApplicationActivatedNotification, withElement:application) { accessibilityElement in
            NSObject.cancelPreviousPerformRequestsWithTarget(
                self,
                selector: #selector(WindowManager.applicationActivated(_:)),
                object: nil
            )
            self.performSelector(#selector(WindowManager.applicationActivated(_:)), withObject: nil, afterDelay: 0.2)
        }
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
        for window in windows {
            if window.processIdentifier() == application.processIdentifier() {
                markScreenForReflow(window.screen())
            }
        }
    }

    private func deactivateApplication(application: SIApplication) {
        for window in windows {
            if window.processIdentifier() == application.processIdentifier() {
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
        if UserConfiguration.sharedConfiguration.floatSmallWindows() && window.frame().size.width < 500 && window.frame().size.height < 500 {
            floatingMap[window.windowID()] = true
        }

        application.observeNotification(kAXUIElementDestroyedNotification, withElement: window) { accessibilityElement in
            self.removeWindow(window)
        }
        application.observeNotification(kAXWindowMiniaturizedNotification, withElement: window) { accessibilityElement in
            self.markScreenForReflow(window.screen())
        }
        application.observeNotification(kAXWindowDeminiaturizedNotification, withElement: window) { accessibilityElement in
            self.markScreenForReflow(window.screen())
        }
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

    public func displayCurrentLayout() {
        for screenManager in screenManagers {
            screenManager.displayLayoutHUD()
        }
    }
}

extension WindowManager {
    public func applicationDidLaunch(notification: NSNotification) {
        guard let launchedApplication = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication else {
            return
        }
        let application = SIApplication(runningApplication: launchedApplication)
        addApplication(application)
    }

    public func applicationDidTerminate(notification: NSNotification) {
        guard let terminatedApplication = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithProcessIdentifier(terminatedApplication.processIdentifier) else {
            return
        }

        removeApplication(application)
    }

    public func applicationDidHide(notification: NSNotification) {
        guard let hiddenApplication = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithProcessIdentifier(hiddenApplication.processIdentifier) else {
            return
        }

        deactivateApplication(application)
    }

    public func applicationDidUnhide(notification: NSNotification) {
        guard let unhiddenApplication = notification.userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithProcessIdentifier(unhiddenApplication.processIdentifier) else {
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
}
