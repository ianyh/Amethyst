//
//  GeneralPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import CCNPreferencesWindowController_ObjC
import Cocoa
import Foundation

fileprivate func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}


open class GeneralPreferencesViewController: NSViewController, CCNPreferencesWindowControllerProtocol, NSTableViewDataSource, NSTableViewDelegate {
    fileprivate var layouts: [String] = []
    fileprivate var floatingBundleIdentifiers: [String] = []

    @IBOutlet open var layoutsTableView: NSTableView?
    @IBOutlet open var floatingTableView: NSTableView?

    fileprivate var editingFloatingBundleIdentifier = false

    open override func awakeFromNib() {
        super.awakeFromNib()

        layoutsTableView?.dataSource = self
        layoutsTableView?.delegate = self

        floatingTableView?.dataSource = self
        floatingTableView?.delegate = self
    }

    open override func viewWillAppear() {
        super.viewWillAppear()

        layouts = UserConfiguration.shared.layoutStrings()
        floatingBundleIdentifiers = UserConfiguration.shared.floatingBundleIdentifiers()

        layoutsTableView?.reloadData()
        floatingTableView?.reloadData()
    }

    @IBAction open func addLayout(_ sender: NSButton) {
        let layoutMenu = NSMenu(title: "")

        for layoutString in LayoutManager.availableLayoutStrings() {
            let menuItem = NSMenuItem(title: layoutString, action: #selector(addLayoutString(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.action = #selector(addLayoutString(_:))

            layoutMenu.addItem(menuItem)
        }

        let frame = sender.frame
        let menuOrigin = sender.superview!.convert(NSPoint(x: frame.origin.x, y: frame.origin.y + frame.size.height + 40), to: nil)

        let event = NSEvent.mouseEvent(
            with: NSEventType.leftMouseDown,
            location: menuOrigin,
            modifierFlags: NSEventModifierFlags(),
            timestamp: 0,
            windowNumber: sender.window!.windowNumber,
            context: sender.window!.graphicsContext,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )

        NSMenu.popUpContextMenu(layoutMenu, with: event!, for: sender)
    }

    @IBAction open func addLayoutString(_ sender: NSMenuItem) {
        var layouts = self.layouts
        layouts.append(sender.title)
        self.layouts = layouts

        UserConfiguration.shared.setLayoutStrings(self.layouts)

        layoutsTableView?.reloadData()
    }

    @IBAction open func removeLayout(_ sender: AnyObject) {
        guard layoutsTableView?.selectedRow < self.layouts.count else {
            return
        }

        var layouts = self.layouts
        layouts.remove(at: layoutsTableView!.selectedRow)
        self.layouts = layouts

        UserConfiguration.shared.setLayoutStrings(self.layouts)

        layoutsTableView?.reloadData()
    }

    @IBAction open func addFloatingApplication(_ sender: NSButton) {
        let layoutMenu = NSMenu(title: "")
        let selectMenuItem = NSMenuItem(title: "Select from applications...", action: #selector(selectFloatingApplication(_:)), keyEquivalent: "")
        let manualMenuItem = NSMenuItem(title: "Manually enter identifier...", action: #selector(manuallyEnterFloatingApplication(_:)), keyEquivalent: "")

        layoutMenu.addItem(selectMenuItem)
        layoutMenu.addItem(manualMenuItem)

        let frame = sender.frame
        let menuOrigin = sender.superview!.convert(NSPoint(x: frame.origin.x, y: frame.origin.y + frame.size.height + 40), to: nil)

        let event = NSEvent.mouseEvent(
            with: NSEventType.leftMouseDown,
            location: menuOrigin,
            modifierFlags: NSEventModifierFlags(),
            timestamp: 0,
            windowNumber: sender.window!.windowNumber,
            context: sender.window!.graphicsContext,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )

        NSMenu.popUpContextMenu(layoutMenu, with: event!, for: sender)
    }

    open func selectFloatingApplication(_ sender: AnyObject) {
        let openPanel = NSOpenPanel()
        let applicationDirectories = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)

        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.allowedFileTypes = ["app"]
        openPanel.prompt = "Select"
        openPanel.directoryURL = applicationDirectories.first

        guard openPanel.runModal() != NSFileHandlingPanelCancelButton else {
            return
        }

        for applicationURL in openPanel.urls {
            guard let applicationBundleIdentifier = Bundle(url: applicationURL)?.bundleIdentifier else {
                continue
            }
            addFloatingApplicationBundleIdentifier(applicationBundleIdentifier)
        }

        floatingTableView?.reloadData()
    }

    open func manuallyEnterFloatingApplication(_ sender: AnyObject) {
        editingFloatingBundleIdentifier = true
        floatingTableView?.reloadData()
        floatingTableView?.editColumn(0, row: floatingBundleIdentifiers.count, with: nil, select: true)
    }

    fileprivate func addFloatingApplicationBundleIdentifier(_ bundleIdentifier: String) {
        var floatingBundleIdentifiers = self.floatingBundleIdentifiers
        floatingBundleIdentifiers.append(bundleIdentifier)
        self.floatingBundleIdentifiers = floatingBundleIdentifiers

        UserConfiguration.shared.setFloatingBundleIdentifiers(self.floatingBundleIdentifiers)
    }

    @IBAction open func removeFloatingApplication(_ sender: AnyObject) {
        guard let floatingTableView = floatingTableView else {
            return
        }

        guard floatingTableView.selectedRow < self.floatingBundleIdentifiers.count else {
            return
        }

        var floatingBundleIdentifiers = self.floatingBundleIdentifiers
        floatingBundleIdentifiers.remove(at: floatingTableView.selectedRow)
        self.floatingBundleIdentifiers = floatingBundleIdentifiers

        UserConfiguration.shared.setFloatingBundleIdentifiers(self.floatingBundleIdentifiers)

        floatingTableView.reloadData()
    }

    open func preferenceIdentifier() -> String! {
        return NSStringFromClass(type(of: self))
    }

    open func preferenceIcon() -> NSImage! {
        return NSImage(named: NSImageNamePreferencesGeneral)
    }

    open func preferenceTitle() -> String! {
        return "General"
    }

    open func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableView {
        case layoutsTableView!:
            return layouts.count
        case floatingTableView!:
            return floatingBundleIdentifiers.count + (editingFloatingBundleIdentifier ? 1 : 0)
        default:
            return 0
        }
    }

    open func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row > -1 else {
            return nil
        }

        if tableView == layoutsTableView {
            return layouts[row]
        } else if tableView == floatingTableView {
            if editingFloatingBundleIdentifier && row == floatingBundleIdentifiers.count {
                return nil
            }
            return floatingBundleIdentifiers[row]
        } else {
            return nil
        }
    }

    open func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        guard tableView == floatingTableView && row == floatingBundleIdentifiers.count else {
            return false
        }

        return true
    }

    open func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
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
