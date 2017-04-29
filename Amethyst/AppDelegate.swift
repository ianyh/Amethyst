//
//  AppDelegate.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import CCNLaunchAtLoginItem
import CCNPreferencesWindowController_ObjC
import CoreServices
import Crashlytics
import Fabric
import Foundation
import RxCocoa
import RxSwift
import Sparkle

open class AppDelegate: NSObject, NSApplicationDelegate {
    fileprivate var loginItem: CCNLaunchAtLoginItem?
    @IBOutlet public var preferencesWindowController: CCNPreferencesWindowController?

    fileprivate var windowManager: WindowManager?
    fileprivate var hotKeyManager: HotKeyManager?

    fileprivate var statusItem: NSStatusItem?
    @IBOutlet open var statusItemMenu: NSMenu?
    @IBOutlet open var versionMenuItem: NSMenuItem?
    @IBOutlet open var startAtLoginMenuItem: NSMenuItem?

    private var isFirstLaunch = true

    open func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.index(of: "--log") == nil {
            LogManager.log?.minLevel = .warning
        } else {
            LogManager.log?.minLevel = .trace
        }

        #if DEBUG
            LogManager.log?.minLevel = .trace
        #endif

        LogManager.log?.info("Logging is enabled")

        UserConfiguration.shared.delegate = self
        UserConfiguration.shared.load()

        #if RELEASE
            let appcastURLString = { () -> String? in
                if UserConfiguration.shared.useCanaryBuild() {
                    return Bundle.main.infoDictionary?["SUCanaryFeedURL"] as? String
                } else {
                    return Bundle.main.infoDictionary?["SUFeedURL"] as? String
                }
            }()!

            SUUpdater.shared().feedURL = URL(string: appcastURLString)

            if let fabricData = Bundle.main.infoDictionary?["Fabric"] as? [String: AnyObject], fabricData["APIKey"] != nil {
                if UserConfiguration.shared.shouldSendCrashReports() {
                    LogManager.log?.info("Crash reporting enabled")
                    Fabric.with([Crashlytics.self])
                }
            }
        #endif

        preferencesWindowController?.centerToolbarItems = false
        preferencesWindowController?.allowsVibrancy = true
        let preferencesViewControllers = [
            GeneralPreferencesViewController(),
            ShortcutsPreferencesViewController()
        ]
        preferencesWindowController?.setPreferencesViewControllers(preferencesViewControllers)

        windowManager = WindowManager(userConfiguration: UserConfiguration.shared)
        hotKeyManager = HotKeyManager(userConfiguration: UserConfiguration.shared)

        hotKeyManager?.setUpWithHotKeyManager(windowManager!, configuration: UserConfiguration.shared)
    }

    open override func awakeFromNib() {
        super.awakeFromNib()

        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let statusItemImage = NSImage(named: "icon-statusitem")
        statusItemImage?.isTemplate = true

        statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
        statusItem?.image = statusItemImage
        statusItem?.menu = statusItemMenu
        statusItem?.highlightMode = true

        versionMenuItem?.title = "Version \(shortVersion) (\(version))"

        loginItem = CCNLaunchAtLoginItem(for: Bundle.main)
        startAtLoginMenuItem?.state = (loginItem!.isActive() ? NSOnState : NSOffState)
    }

    public func applicationDidBecomeActive(_ notification: Notification) {
        guard !isFirstLaunch else {
            isFirstLaunch = false
            return
        }

        showPreferencesWindow(self)
    }

    @IBAction open func toggleStartAtLogin(_ sender: AnyObject) {
        if startAtLoginMenuItem?.state == NSOffState {
            loginItem?.activate()
        } else {
            loginItem?.deActivate()
        }
        startAtLoginMenuItem?.state = (loginItem!.isActive() ? NSOnState : NSOffState)
    }

    @IBAction open func relaunch(_ sender: AnyObject) {
        let executablePath = Bundle.main.executablePath! as NSString
        let fileSystemRepresentedPath = executablePath.fileSystemRepresentation
        let fileSystemPath = FileManager.default.string(withFileSystemRepresentation: fileSystemRepresentedPath, length: Int(strlen(fileSystemRepresentedPath)))
        Process.launchedProcess(launchPath: fileSystemPath, arguments: [])
        NSApp.terminate(self)
    }

    @IBAction open func showPreferencesWindow(_ sender: AnyObject) {
        if UserConfiguration.shared.hasCustomConfiguration() {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Warning"
            alert.informativeText = "You have a .amethyst file, which can override in-app preferences. You may encounter unexpected behavior."
            alert.runModal()
        }

        preferencesWindowController?.showPreferencesWindow()
    }

    @IBAction open func checkForUpdates(_ sender: AnyObject) {
        #if RELEASE
            SUUpdater.shared().checkForUpdates(sender)
        #endif
    }
}

extension AppDelegate: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        windowManager?.preferencesDidClose()
    }
}

extension AppDelegate: UserConfigurationDelegate {
    public func configurationGlobalTilingDidChange(_ userConfiguration: UserConfiguration) {
        var statusItemImage: NSImage?
        if UserConfiguration.shared.tilingEnabled == true {
            statusItemImage = NSImage(named: "icon-statusitem")
        } else {
            statusItemImage = NSImage(named: "icon-statusitem-disabled")
        }
        statusItemImage?.isTemplate = true
        statusItem?.image = statusItemImage
    }
}
