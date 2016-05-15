//
//  AppDelegate.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import CCNLaunchAtLoginItem
import CCNPreferencesWindowController
import CocoaLumberjack
import CoreServices
import Crashlytics
import Fabric
import Foundation
import RxCocoa
import RxSwift
import Sparkle

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var loginItem: CCNLaunchAtLoginItem?
    private var preferencesWindowController: CCNPreferencesWindowController?

    private var windowManager: WindowManager?
    private var hotKeyManager: AMHotKeyManager?

    private var statusItem: NSStatusItem?
    @IBOutlet public var statusItemMenu: NSMenu?
    @IBOutlet public var versionMenuItem: NSMenuItem?
    @IBOutlet public var startAtLoginMenuItem: NSMenuItem?

    public func applicationDidFinishLaunching(notification: NSNotification) {
        DDLog.addLogger(DDASLLogger.sharedInstance())
        DDLog.addLogger(DDTTYLogger.sharedInstance())

        Configuration.sharedConfiguration.loadConfiguration()

        let appcastURLString = { () -> String? in
            if Configuration.sharedConfiguration.useCanaryBuild() {
                return NSBundle.mainBundle().infoDictionary?["SUCanaryFeedURL"] as? String
            } else {
                return NSBundle.mainBundle().infoDictionary?["SUFeedURL"] as? String
            }
        }()!

        SUUpdater.sharedUpdater().feedURL = NSURL(string: appcastURLString)

        _ = Configuration.sharedConfiguration
            .rx_observe(Bool.self, "tilingEnabled")
            .subscribeNext() { [weak self] tilingEnabled in
                var statusItemImage: NSImage?
                if tilingEnabled == true {
                    statusItemImage = NSImage(named: "icon-statusitem")
                } else {
                    statusItemImage = NSImage(named: "icon-statusitem-disabled")
                }
                statusItemImage?.template = true
                self?.statusItem?.image = statusItemImage
            }

        let crashlyticsAPIKey = NSBundle.mainBundle().infoDictionary?["AMCrashlyticsAPIKey"]
        if crashlyticsAPIKey != nil {
            Fabric.with([Crashlytics.self])
            #if DEBUG
                Crashlytics.sharedInstance().debugMode = true
            #endif
        }

        preferencesWindowController = CCNPreferencesWindowController()
        preferencesWindowController?.centerToolbarItems = false
        preferencesWindowController?.allowsVibrancy = true
        let preferencesViewControllers = [
            AMGeneralPreferencesViewController(),
            AMShortcutsPreferencesViewController()
        ]
        preferencesWindowController?.setPreferencesViewControllers(preferencesViewControllers)

        windowManager = WindowManager()
        hotKeyManager = AMHotKeyManager()

        Configuration.sharedConfiguration.setUpWithHotKeyManager(hotKeyManager!, windowManager: windowManager!)
    }

    public override func awakeFromNib() {
        super.awakeFromNib()

        let version = NSBundle.mainBundle().infoDictionary?["CFBundleVersion"] as! String
        let shortVersion = NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as! String

        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
        statusItem?.image = NSImage(named: "icon-statusitem")
        statusItem?.menu = statusItemMenu
        statusItem?.highlightMode = true

        versionMenuItem?.title = "Version \(shortVersion) (\(version))"

        loginItem = CCNLaunchAtLoginItem(forBundle: NSBundle.mainBundle())
        startAtLoginMenuItem?.state = (loginItem!.isActive() ? NSOnState : NSOffState)
    }

    @IBAction public func toggleStartAtLogin(sender: AnyObject) {
        if startAtLoginMenuItem?.state == NSOffState {
            loginItem?.activate()
        } else {
            loginItem?.deActivate()
        }
        startAtLoginMenuItem?.state = (loginItem!.isActive() ? NSOnState : NSOffState)
    }

    @IBAction public func relaunch(sender: AnyObject) {
        let executablePath = NSBundle.mainBundle().executablePath! as NSString
        let fileSystemRepresentedPath = executablePath.fileSystemRepresentation
        let fileSystemPath = NSFileManager.defaultManager().stringWithFileSystemRepresentation(fileSystemRepresentedPath, length: Int(strlen(fileSystemRepresentedPath)))
        NSTask.launchedTaskWithLaunchPath(fileSystemPath, arguments: [])
        NSApp.terminate(self)
    }

    @IBAction public func showPreferencesWindow(sender: AnyObject) {
        if Configuration.sharedConfiguration.hasCustomConfiguration() {
            let alert = NSAlert()
            alert.alertStyle = .WarningAlertStyle
            alert.messageText = "Warning"
            alert.informativeText = "You have a .amethyst file, which can override in-app preferences. You may encounter unexpected behavior."
            alert.runModal()
        }

        preferencesWindowController?.showPreferencesWindow()
    }
}
