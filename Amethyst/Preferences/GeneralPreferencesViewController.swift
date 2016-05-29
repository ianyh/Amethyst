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

    private var editingFloatingBundleIdentifier = false

    public override func awakeFromNib() {
        super.awakeFromNib()

        layoutsTableView?.setDataSource(self)
        layoutsTableView?.setDelegate(self)

        floatingTableView?.setDataSource(self)
        floatingTableView?.setDelegate(self)
    }

    public override func viewWillAppear() {
        super.viewWillAppear()

        layouts = UserConfiguration.sharedConfiguration.layoutStrings()
        floatingBundleIdentifiers = UserConfiguration.sharedConfiguration.floatingBundleIdentifiers()

        layoutsTableView?.reloadData()
        floatingTableView?.reloadData()
    }

    @IBAction public func addLayout(sender: NSButton) {
        let layoutMenu = NSMenu(title: "")

        for layoutString in LayoutManager.availableLayoutStrings() {
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

        UserConfiguration.sharedConfiguration.setLayoutStrings(self.layouts)

        layoutsTableView?.reloadData()
    }

    @IBAction public func removeLayout(sender: AnyObject) {
        guard layoutsTableView?.selectedRow < self.layouts.count else {
            return
        }

        var layouts = self.layouts
        layouts.removeAtIndex(layoutsTableView!.selectedRow)
        self.layouts = layouts

        UserConfiguration.sharedConfiguration.setLayoutStrings(self.layouts)

        layoutsTableView?.reloadData()
    }

    @IBAction public func addFloatingApplication(sender: NSButton) {
        let layoutMenu = NSMenu(title: "")
        let selectMenuItem = NSMenuItem(title: "Select from applications...", action: #selector(selectFloatingApplication(_:)), keyEquivalent: "")
        let manualMenuItem = NSMenuItem(title: "Manually enter identifier...", action: #selector(manuallyEnterFloatingApplication(_:)), keyEquivalent: "")

        layoutMenu.addItem(selectMenuItem)
        layoutMenu.addItem(manualMenuItem)

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

    public func selectFloatingApplication(sender: AnyObject) {
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

        for applicationURL in openPanel.URLs {
            guard let applicationBundleIdentifier = NSBundle(URL: applicationURL)?.bundleIdentifier else {
                continue
            }
            addFloatingApplicationBundleIdentifier(applicationBundleIdentifier)
        }

        floatingTableView?.reloadData()
    }

    public func manuallyEnterFloatingApplication(sender: AnyObject) {
        editingFloatingBundleIdentifier = true
        floatingTableView?.reloadData()
        floatingTableView?.editColumn(0, row: floatingBundleIdentifiers.count, withEvent: nil, select: true)
    }

    private func addFloatingApplicationBundleIdentifier(bundleIdentifier: String) {
        var floatingBundleIdentifiers = self.floatingBundleIdentifiers
        floatingBundleIdentifiers.append(bundleIdentifier)
        self.floatingBundleIdentifiers = floatingBundleIdentifiers

        UserConfiguration.sharedConfiguration.setFloatingBundleIdentifiers(self.floatingBundleIdentifiers)
    }

    @IBAction public func removeFloatingApplication(sender: AnyObject) {
        guard floatingTableView?.selectedRow < self.floatingBundleIdentifiers.count else {
            return
        }

        var floatingBundleIdentifiers = self.floatingBundleIdentifiers
        floatingBundleIdentifiers.removeAtIndex(floatingTableView!.selectedRow)
        self.floatingBundleIdentifiers = floatingBundleIdentifiers

        UserConfiguration.sharedConfiguration.setFloatingBundleIdentifiers(self.floatingBundleIdentifiers)

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
            return floatingBundleIdentifiers.count + (editingFloatingBundleIdentifier ? 1 : 0)
        default:
            return 0
        }
    }

    public func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        guard row > -1 else {
            return nil
        }

        switch tableView {
        case layoutsTableView!:
            return layouts[row]
        case floatingTableView!:
            if editingFloatingBundleIdentifier && row == floatingBundleIdentifiers.count {
                return nil
            }
            return floatingBundleIdentifiers[row]
        default:
            return nil
        }
    }

    public func tableView(tableView: NSTableView, shouldEditTableColumn tableColumn: NSTableColumn?, row: Int) -> Bool {
        guard tableView == floatingTableView && row == floatingBundleIdentifiers.count else {
            return false
        }

        return true
    }

    public func tableView(tableView: NSTableView, setObjectValue object: AnyObject?, forTableColumn tableColumn: NSTableColumn?, row: Int) {
        guard tableView == floatingTableView && row == floatingBundleIdentifiers.count else {
            return
        }

        editingFloatingBundleIdentifier = false

        if let identifier = object as? String {
            addFloatingApplicationBundleIdentifier(identifier)
        }

        floatingTableView?.reloadData()
    }
}
