//
//  GeneralPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import CCNPreferencesWindowController
import Cocoa
import Foundation

public class GeneralPreferencesViewController: NSViewController, CCNPreferencesWindowControllerProtocol, NSTableViewDataSource, NSTableViewDelegate {
    private var layouts: [String] = []
    private var floatingBundleIdentifiers: [String] = []

    @IBOutlet public var layoutsTableView: NSTableView?
    @IBOutlet public var floatingTableView: NSTableView?

    public override func awakeFromNib() {
        super.awakeFromNib()

        layoutsTableView?.setDataSource(self)
        layoutsTableView?.setDelegate(self)

        floatingTableView?.setDataSource(self)
        floatingTableView?.setDelegate(self)
    }

    public override func viewWillAppear() {
        super.viewWillAppear()

        layouts = Configuration.sharedConfiguration.layoutStrings()
        floatingBundleIdentifiers = Configuration.sharedConfiguration.floatingBundleIdentifiers()

        layoutsTableView?.reloadData()
        floatingTableView?.reloadData()
    }

    @IBAction public func addLayout(sender: NSButton) {
        let layoutMenu = NSMenu(title: "")

        for layoutString in Configuration.sharedConfiguration.availableLayoutStrings() {
            let menuItem = NSMenuItem(title: layoutString, action: #selector(addLayoutString(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.action = #selector(addLayoutString(_:))

            layoutMenu.addItem(menuItem)
        }

        let frame = sender.frame
        let menuOrigin = sender.superview!.convertPoint(NSMakePoint(frame.origin.x, frame.origin.y + frame.size.height + 40), toView: nil)

        let event = NSEvent.mouseEventWithType(
            NSEventType.LeftMouseDown,
            location: menuOrigin,
            modifierFlags: NSEventModifierFlags(),
            timestamp: 0,
            windowNumber: sender.window!.windowNumber,
            context: sender.window!.graphicsContext,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )

        NSMenu.popUpContextMenu(layoutMenu, withEvent: event!, forView: sender)
    }

    @IBAction public func addLayoutString(sender: NSMenuItem) {
        var layouts = self.layouts
        layouts.append(sender.title)
        self.layouts = layouts

        Configuration.sharedConfiguration.setLayoutStrings(self.layouts)

        layoutsTableView?.reloadData()
    }

    @IBAction public func removeLayout(sender: AnyObject) {
        guard layoutsTableView?.selectedRow < self.layouts.count else {
            return
        }

        var layouts = self.layouts
        layouts.removeAtIndex(layoutsTableView!.selectedRow)
        self.layouts = layouts

        Configuration.sharedConfiguration.setLayoutStrings(self.layouts)

        layoutsTableView?.reloadData()
    }

    @IBAction public func addFloatingApplication(sender: AnyObject) {
        let openPanel = NSOpenPanel()
        let applicationDirectories = NSFileManager.defaultManager().URLsForDirectory(.ApplicationDirectory, inDomains: .LocalDomainMask)

        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.allowedFileTypes = ["app"]
        openPanel.prompt = "Select"
        openPanel.directoryURL = applicationDirectories.first

        guard openPanel.runModal() != NSFileHandlingPanelCancelButton else {
            return
        }

        var floatingBundleIdentifiers = self.floatingBundleIdentifiers
        for applicationURL in openPanel.URLs {
            guard let applicationBundleIdentifier = NSBundle(URL: applicationURL)?.bundleIdentifier else {
                continue
            }
            floatingBundleIdentifiers.append(applicationBundleIdentifier)
        }
        self.floatingBundleIdentifiers = floatingBundleIdentifiers

        Configuration.sharedConfiguration.setFloatingBundleIdentifiers(self.floatingBundleIdentifiers)

        floatingTableView?.reloadData()
    }

    @IBAction public func removeFloatingApplication(sender: AnyObject) {
        guard floatingTableView?.selectedRow < self.floatingBundleIdentifiers.count else {
            return
        }

        var floatingBundleIdentifiers = self.floatingBundleIdentifiers
        floatingBundleIdentifiers.removeAtIndex(floatingTableView!.selectedRow)
        self.floatingBundleIdentifiers = floatingBundleIdentifiers

        Configuration.sharedConfiguration.setFloatingBundleIdentifiers(self.floatingBundleIdentifiers)

        floatingTableView?.reloadData()
    }

    public func preferenceIdentifier() -> String! {
        return NSStringFromClass(self.dynamicType)
    }

    public func preferenceIcon() -> NSImage! {
        return NSImage(named: NSImageNamePreferencesGeneral)
    }

    public func preferenceTitle() -> String! {
        return "General"
    }

    public func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        switch tableView {
        case layoutsTableView!:
            return layouts.count
        case floatingTableView!:
            return floatingBundleIdentifiers.count
        default:
            return 0
        }
    }

    public func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        switch tableView {
        case layoutsTableView!:
            return layouts[row]
        case floatingTableView!:
            return floatingBundleIdentifiers[row]
        default:
            return nil
        }
    }
}
