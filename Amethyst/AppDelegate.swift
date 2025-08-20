//
//  AppDelegate.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import CoreServices
import Foundation
import LoginServiceKit
import RxCocoa
import RxSwift
import Silica
import Sparkle
import SwiftyBeaver

class AppDelegate: NSObject, NSApplicationDelegate {
    static let windowManagerEncodingKey = "EncodedWindowManager"

    @IBOutlet var preferencesWindowController: PreferencesWindowController?

    fileprivate var windowManager: WindowManager<SIApplication>?
    private var hotKeyManager: HotKeyManager<SIApplication>?

    fileprivate var statusItem: NSStatusItem?
    @IBOutlet var statusItemMenu: NSMenu?
    @IBOutlet var versionMenuItem: NSMenuItem?
    @IBOutlet var startAtLoginMenuItem: NSMenuItem?
    @IBOutlet var toggleGlobalTilingMenuItem: NSMenuItem?
    @IBOutlet var layoutsMenuItem: NSMenuItem?

    private var isFirstLaunch = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
            log.addDestination(ConsoleDestination())
        #endif

        if CommandLine.arguments.contains("--log") {
            let destination = ConsoleDestination()
            destination.useNSLog = true
            log.addDestination(destination)
        }

        log.info("Logging is enabled")
        log.debug("Debug logging is enabled")

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
        #endif

        preferencesWindowController?.window?.level = .floating

        if let encodedWindowManager = UserDefaults.standard.data(forKey: AppDelegate.windowManagerEncodingKey), UserConfiguration.shared.restoreLayoutsOnLaunch() {
            let decoder = JSONDecoder()
            windowManager = try? decoder.decode(WindowManager<SIApplication>.self, from: encodedWindowManager)
        }

        windowManager = windowManager ?? WindowManager(userConfiguration: UserConfiguration.shared)
        hotKeyManager = HotKeyManager(userConfiguration: UserConfiguration.shared)

        hotKeyManager?.setUpWithWindowManager(windowManager!, configuration: UserConfiguration.shared, appDelegate: self)

        // Populate layouts menu now that windowManager is initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.populateLayoutsMenu()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let statusItemImage = NSImage(named: "icon-statusitem")
        statusItemImage?.isTemplate = true

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.image = statusItemImage
        statusItem?.menu = statusItemMenu
        statusItem?.highlightMode = true

        let hideMenuBarIcon: Bool = UserConfiguration.shared.hideMenuBarIcon()
        statusItem?.isVisible = !hideMenuBarIcon

        versionMenuItem?.title = "Version \(shortVersion) (\(version))"
        toggleGlobalTilingMenuItem?.title = "Disable"

        startAtLoginMenuItem?.state = (LoginServiceKit.isExistLoginItems(at: Bundle.main.bundlePath) ? .on : .off)

        // Set up layouts menu delegate to refresh when opened
        layoutsMenuItem?.submenu?.delegate = self

        populateLayoutsMenu()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !isFirstLaunch else {
            isFirstLaunch = false
            return
        }

        showPreferencesWindow(self)
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard let windowManager = windowManager else {
            return
        }

        do {
            let encoder = JSONEncoder()
            let encodedWindowManager = try encoder.encode(windowManager)
            UserDefaults.standard.set(encodedWindowManager, forKey: AppDelegate.windowManagerEncodingKey)
        } catch {
            log.error("Failed to encode window manager: \(error)")
        }
    }

    @IBAction func toggleStartAtLogin(_ sender: AnyObject) {
        if startAtLoginMenuItem?.state == .off {
            LoginServiceKit.addLoginItems(at: Bundle.main.bundlePath)
        } else {
            LoginServiceKit.removeLoginItems(at: Bundle.main.bundlePath)
        }
        startAtLoginMenuItem?.state = (LoginServiceKit.isExistLoginItems(at: Bundle.main.bundlePath) ? .on : .off)
    }

    @IBAction func toggleGlobalTiling(_ sender: AnyObject) {
        UserConfiguration.shared.tilingEnabled = !UserConfiguration.shared.tilingEnabled
        windowManager?.markAllScreensForReflow(withChange: .unknown)
    }

    @IBAction func resetLayouts(_ sender: AnyObject) {
        UserDefaults.standard.removeObject(forKey: AppDelegate.windowManagerEncodingKey)
        windowManager?.reset()
    }

    @IBAction func relaunch(_ sender: AnyObject) {
        AppManager.relaunch()
    }

    @IBAction func showPreferencesWindow(_ sender: AnyObject) {
        guard let isVisible = preferencesWindowController?.window?.isVisible, !isVisible else {
            return
        }

        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        presentDotfileWarningIfNecessary()
    }

    @IBAction func checkForUpdates(_ sender: AnyObject) {
        #if RELEASE
            SUUpdater.shared().checkForUpdates(sender)
        #endif
    }

    private func presentDotfileWarningIfNecessary() {
        let shouldWarn = !UserDefaults.standard.bool(forKey: "disable-dotfile-conflict-warning")
        if shouldWarn && UserConfiguration.shared.hasCustomConfiguration() {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Warning"
            alert.informativeText = "You have a .amethyst file, which can override in-app preferences. You may encounter unexpected behavior."
            alert.showsSuppressionButton = true
            alert.runModal()

            if alert.suppressionButton?.state == .on {
                UserDefaults.standard.set(true, forKey: "disable-dotfile-conflict-warning")
            }
        }
    }

    private func populateLayoutsMenu() {
        guard let layoutsMenuItem = layoutsMenuItem,
              let submenu = layoutsMenuItem.submenu else {
            return
        }

        // Clear existing items
        submenu.removeAllItems()

        // Get enabled layout keys from user configuration
        let enabledLayoutKeys = UserConfiguration.shared.layoutKeys()

        // Get all available layouts with their display names
        let availableLayouts = LayoutType<SIApplication.Window>.availableLayoutStrings()

        // Get current layout
        let focusedScreenManager = windowManager?.focusedScreenManager()
        var currentLayoutKey = focusedScreenManager?.currentLayout?.layoutKey

        // If no focused screen manager, fallback to the first screen manager
        if focusedScreenManager == nil, let firstScreenManager = windowManager?.screenManager(at: 0) {
            currentLayoutKey = firstScreenManager.currentLayout?.layoutKey
        }

        // Filter to only enabled layouts and add menu items
        for layoutKey in enabledLayoutKeys {
            guard let layoutInfo = availableLayouts.first(where: { $0.key == layoutKey }) else {
                continue
            }

            let menuItem = NSMenuItem(title: layoutInfo.name, action: #selector(selectLayout(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = layoutKey

            // Mark current layout with checkmark
            let isCurrentLayout = layoutKey == currentLayoutKey
            menuItem.state = isCurrentLayout ? .on : .off

            submenu.addItem(menuItem)
        }

        // If no layouts are enabled, show a disabled message
        if enabledLayoutKeys.isEmpty {
            let noLayoutsItem = NSMenuItem(title: "No layouts enabled", action: nil, keyEquivalent: "")
            noLayoutsItem.isEnabled = false
            submenu.addItem(noLayoutsItem)
        }
    }

    @IBAction func selectLayout(_ sender: NSMenuItem) {
        guard let layoutKey = sender.representedObject as? String,
              let windowManager = windowManager,
              let screenManager = windowManager.focusedScreenManager() else {
            return
        }

        screenManager.selectLayout(layoutKey)
        // Menu will be refreshed automatically when next opened via NSMenuDelegate
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        windowManager?.preferencesDidClose()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Refresh layouts menu when it's about to be shown
        if menu == layoutsMenuItem?.submenu {
            populateLayoutsMenu()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Also refresh when menu is about to open
        if menu == layoutsMenuItem?.submenu {
            populateLayoutsMenu()
        }
    }
}

extension AppDelegate: UserConfigurationDelegate {
    func configurationGlobalTilingDidChange(_ userConfiguration: UserConfiguration) {
        var statusItemImage: NSImage?
        if UserConfiguration.shared.tilingEnabled == true {
            statusItemImage = NSImage(named: "icon-statusitem")
            toggleGlobalTilingMenuItem?.title = "Disable Tiling"
        } else {
            statusItemImage = NSImage(named: "icon-statusitem-disabled")
            toggleGlobalTilingMenuItem?.title = "Enable Tiling"
        }
        statusItemImage?.isTemplate = true
        statusItem?.image = statusItemImage
    }

    func configurationAccessibilityPermissionsDidChange(_ userConfiguration: UserConfiguration) {
        windowManager?.reevaluateWindows()
    }
}
