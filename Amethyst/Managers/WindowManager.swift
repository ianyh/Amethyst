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

public enum WindowChange {
    case add(window: SIWindow)
    case remove(window: SIWindow)
    case focusChanged(window: SIWindow)
    case windowSwap(window: SIWindow, otherWindow: SIWindow)
    case unknown
}

open class WindowManager: NSObject {
    internal var applications: [SIApplication] = []
    internal var windows: [SIWindow] = []
    internal let windowModifier = WindowModifier()
    internal let userConfiguration: UserConfiguration

    internal var screenManagers: [ScreenManager] = []
    fileprivate var screenManagersCache: [String: ScreenManager] = [:]

    fileprivate let focusFollowsMouseManager: FocusFollowsMouseManager

    internal var activeIDCache: [CGWindowID: Bool] = [:]
    internal var floatingMap: [CGWindowID: Bool] = [:]

    public init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        self.focusFollowsMouseManager = FocusFollowsMouseManager(userConfiguration: userConfiguration)

        super.init()

        focusFollowsMouseManager.delegate = self
        windowModifier.delegate = self

        addWorkspaceNotificationObserver(NSNotification.Name.NSWorkspaceDidLaunchApplication.rawValue, selector: #selector(applicationDidLaunch(_:)))
        addWorkspaceNotificationObserver(NSNotification.Name.NSWorkspaceDidTerminateApplication.rawValue, selector: #selector(applicationDidTerminate(_:)))
        addWorkspaceNotificationObserver(NSNotification.Name.NSWorkspaceDidHideApplication.rawValue, selector: #selector(applicationDidHide(_:)))
        addWorkspaceNotificationObserver(NSNotification.Name.NSWorkspaceDidUnhideApplication.rawValue, selector: #selector(applicationDidUnhide(_:)))
        addWorkspaceNotificationObserver(NSNotification.Name.NSWorkspaceActiveSpaceDidChange.rawValue, selector: #selector(activeSpaceDidChange(_:)))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSNotification.Name.NSApplicationDidChangeScreenParameters,
            object: nil
        )

        reevaluateWindows()
        updateScreenManagers()
    }

    deinit {
        NSWorkspace.shared().notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    fileprivate func addWorkspaceNotificationObserver(_ name: String, selector: Selector) {
        let workspaceNotificationCenter = NSWorkspace.shared().notificationCenter
        workspaceNotificationCenter.addObserver(self, selector: selector, name: NSNotification.Name(rawValue: name), object: nil)
    }

    fileprivate func regenerateActiveIDCache() {
        var activeIDCache: [CGWindowID: Bool] = [:]
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

            activeIDCache[CGWindowID(windowID.uint64Value)] = true
        }
    }

    fileprivate func spaceIdentifierWithScreenDictionary(_ screenDictionary: [String: AnyObject]) -> String? {
        let spaceDictionary = screenDictionary["Current Space"] as? [String: AnyObject]
        return spaceDictionary?["uuid"] as? String
    }

    fileprivate func assignCurrentSpaceIdentifiers() {
        regenerateActiveIDCache()

        guard let screenDictionaries = NSScreen.screenDescriptions() else {
            return
        }

        if NSScreen.screensHaveSeparateSpaces() {
            for screenDictionary in screenDictionaries {
                guard let screenIdentifier = screenDictionary["Display Identifier"] as? String else {
                    LogManager.log?.error("Could not identify screen with info: \(screenDictionary)")
                    continue
                }

                guard let screenManager = screenManagersCache[screenIdentifier] else {
                    LogManager.log?.error("Screen with identifier not managed: \(screenIdentifier)")
                    continue
                }

                guard let spaceIdentifier = spaceIdentifierWithScreenDictionary(screenDictionary), screenManager.currentSpaceIdentifier != spaceIdentifier else {
                    continue
                }

                screenManager.currentSpaceIdentifier = spaceIdentifier
            }
        } else {
            for screenManager in screenManagers {
                let screenDictionary = screenDictionaries[0]

                guard let spaceIdentifier = spaceIdentifierWithScreenDictionary(screenDictionary), screenManager.currentSpaceIdentifier != spaceIdentifier else {
                    continue
                }

                screenManager.currentSpaceIdentifier = spaceIdentifier
            }
        }
    }

    fileprivate func screenManagerForCGWindowDescription(_ description: [String: AnyObject]) -> ScreenManager? {
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

    open func reevaluateWindows() {
        for runningApplication in NSWorkspace.shared().runningApplications {
            guard runningApplication.isManageable else {
                continue
            }

            let application = SIApplication(runningApplication: runningApplication)
            addApplication(application!)
        }
        markAllScreensForReflowWithChange(.unknown)
    }

    open func focusedScreenManager() -> ScreenManager? {
        guard let focusedWindow = SIWindow.focused() else {
            return nil
        }
        for screenManager in screenManagers {
            if screenManager.screen.screenIdentifier() == focusedWindow.screen().screenIdentifier() {
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

        applications.append(application)

        for window in application.windows() as! [SIWindow] {
            addWindow(window)
        }

        let floating = application.floating()

        application.observeNotification(kAXWindowCreatedNotification as CFString!, with: application) { accessibilityElement in
            guard let window = accessibilityElement as? SIWindow else {
                return
            }
            self.floatingMap[window.windowID()] = floating
            self.addWindow(window)
        }
        application.observeNotification(kAXWindowDeminiaturizedNotification as CFString!, with: application) { accessibilityElement in
            guard let window = accessibilityElement as? SIWindow else {
                return
            }
            self.addWindow(window)
        }
        application.observeNotification(kAXFocusedWindowChangedNotification as CFString!, with: application) { accessibilityElement in
            guard let focusedWindow = SIWindow.focused(), let screen = focusedWindow.screen() else {
                return
            }
            if self.windows.index(of: focusedWindow) == nil {
                self.markScreenForReflow(screen, withChange: .unknown)
            } else {
                self.markScreenForReflow(screen, withChange: .focusChanged(window: focusedWindow))
            }
        }
        application.observeNotification(kAXApplicationActivatedNotification as CFString!, with: application) { accessibilityElement in
            NSObject.cancelPreviousPerformRequests(
                withTarget: self,
                selector: #selector(self.applicationActivated(_:)),
                object: nil
            )
            self.perform(#selector(self.applicationActivated(_:)), with: nil, afterDelay: 0.2)
        }
    }

    open func applicationActivated(_ sender: AnyObject) {
        guard let focusedWindow = SIWindow.focused(), let screen = focusedWindow.screen() else {
            return
        }
        markScreenForReflow(screen, withChange: .unknown)
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

        floatingMap[window.windowID()] = application.floating()
        if userConfiguration.floatSmallWindows() && window.frame().size.width < 500 && window.frame().size.height < 500 {
            floatingMap[window.windowID()] = true
        }

        application.observeNotification(kAXUIElementDestroyedNotification as CFString!, with: window) { accessibilityElement in
            self.removeWindow(window)
        }
        application.observeNotification(kAXWindowMiniaturizedNotification as CFString!, with: window) { accessibilityElement in
            guard let screen = window.screen() else {
                return
            }
            self.markScreenForReflow(screen, withChange: .remove(window: window))
        }
        application.observeNotification(kAXWindowDeminiaturizedNotification as CFString!, with: window) { accessibilityElement in
            guard let screen = window.screen() else {
                return
            }
            self.markScreenForReflow(screen, withChange: .add(window: window))
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
        application?.unobserveNotification(kAXUIElementDestroyedNotification as CFString!, with: window)
        application?.unobserveNotification(kAXWindowMiniaturizedNotification as CFString!, with: window)
        application?.unobserveNotification(kAXWindowDeminiaturizedNotification as CFString!, with: window)

        regenerateActiveIDCache()
        guard let windowIndex = windows.index(of: window) else {
            return
        }
        windows.remove(at: windowIndex)
    }

    open func toggleFloatForFocusedWindow() {
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

        for screen in NSScreen.screens() ?? [] {
            let screenIdentifier = screen.screenIdentifier()
            var screenManager = screenManagersCache[screenIdentifier]

            if screenManager == nil {
                screenManager = ScreenManager(screen: screen, screenIdentifier: screenIdentifier, delegate: self, userConfiguration: userConfiguration)
                screenManagersCache[screenIdentifier] = screenManager
            }

            screenManager!.screen = screen

            screenManagers.append(screenManager!)
        }

        // Window managers are sorted by screen position along the x-axis.
        screenManagers.sort() { screenManager1, screenManager2 -> Bool in
            let x1 = screenManager1.screen.frameWithoutDockOrMenu().origin.x
            let x2 = screenManager2.screen.frameWithoutDockOrMenu().origin.x

            return x1 < x2
        }

        self.screenManagers = screenManagers

        assignCurrentSpaceIdentifiers()
        markAllScreensForReflowWithChange(.unknown)
    }

    open func markAllScreensForReflowWithChange(_ windowChange: WindowChange) {
        for screenManager in screenManagers {
            screenManager.setNeedsReflowWithWindowChange(windowChange)
        }
    }

    open func displayCurrentLayout() {
        for screenManager in screenManagers {
            screenManager.displayLayoutHUD()
        }
    }
}

extension WindowManager {
    public func applicationDidLaunch(_ notification: Notification) {
        guard let launchedApplication = (notification as NSNotification).userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication else {
            return
        }
        let application = SIApplication(runningApplication: launchedApplication)
        addApplication(application!)
    }

    public func applicationDidTerminate(_ notification: Notification) {
        guard let terminatedApplication = (notification as NSNotification).userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithProcessIdentifier(terminatedApplication.processIdentifier) else {
            return
        }

        removeApplication(application)
    }

    public func applicationDidHide(_ notification: Notification) {
        guard let hiddenApplication = (notification as NSNotification).userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithProcessIdentifier(hiddenApplication.processIdentifier) else {
            return
        }

        deactivateApplication(application)
    }

    public func applicationDidUnhide(_ notification: Notification) {
        guard let unhiddenApplication = (notification as NSNotification).userInfo?[NSWorkspaceApplicationKey] as? NSRunningApplication else {
            return
        }

        guard let application = applicationWithProcessIdentifier(unhiddenApplication.processIdentifier) else {
            return
        }

        activateApplication(application)
    }

    public func activeSpaceDidChange(_ notification: Notification) {
        assignCurrentSpaceIdentifiers()

        for runningApplication in NSWorkspace.shared().runningApplications {
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

    public func screenParametersDidChange(_ notification: Notification) {
        updateScreenManagers()
    }
}
