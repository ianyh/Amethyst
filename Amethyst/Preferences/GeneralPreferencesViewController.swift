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

final class GeneralPreferencesViewController: NSViewController, CCNPreferencesWindowControllerProtocol, NSTableViewDataSource, NSTableViewDelegate {
    private var layouts: [String] = []
    private var floatingBundleIdentifiers: [String] = []

    @IBOutlet var layoutsTableView: NSTableView?
    @IBOutlet var floatingTableView: NSTableView?

    private var editingFloatingBundleIdentifier = false

    override func awakeFromNib() {
        super.awakeFromNib()

        layoutsTableView?.dataSource = self
        layoutsTableView?.delegate = self

        floatingTableView?.dataSource = self
        floatingTableView?.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        layouts = UserConfiguration.shared.layoutStrings()
        floatingBundleIdentifiers = UserConfiguration.shared.floatingBundleIdentifiers()

        layoutsTableView?.reloadData()
        floatingTableView?.reloadData()
    }

    @IBAction func addLayout(_ sender: NSButton) {
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
            with: NSEvent.EventType.leftMouseDown,
            location: menuOrigin,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: sender.window!.windowNumber,
            context: sender.window!.graphicsContext,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )

        NSMenu.popUpContextMenu(layoutMenu, with: event!, for: sender)
    }

    @IBAction func addLayoutString(_ sender: NSMenuItem) {
        var layouts = self.layouts
        layouts.append(sender.title)
        self.layouts = layouts

        UserConfiguration.shared.setLayoutStrings(self.layouts)

        layoutsTableView?.reloadData()
    }

    @IBAction func removeLayout(_ sender: AnyObject) {
        guard let selectedRow = layoutsTableView?.selectedRow, selectedRow < self.layouts.count else {
            return
        }

        var layouts = self.layouts
        layouts.remove(at: selectedRow)
        self.layouts = layouts

        UserConfiguration.shared.setLayoutStrings(self.layouts)

        layoutsTableView?.reloadData()
    }

    @IBAction func addFloatingApplication(_ sender: NSButton) {
        let layoutMenu = NSMenu(title: "")
        let selectMenuItem = NSMenuItem(title: "Select from applications...", action: #selector(selectFloatingApplication(_:)), keyEquivalent: "")
        let manualMenuItem = NSMenuItem(title: "Manually enter identifier...", action: #selector(manuallyEnterFloatingApplication(_:)), keyEquivalent: "")

        layoutMenu.addItem(selectMenuItem)
        layoutMenu.addItem(manualMenuItem)

        let frame = sender.frame
        let menuOrigin = sender.superview!.convert(NSPoint(x: frame.origin.x, y: frame.origin.y + frame.size.height + 40), to: nil)

        let event = NSEvent.mouseEvent(
            with: NSEvent.EventType.leftMouseDown,
            location: menuOrigin,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: sender.window!.windowNumber,
            context: sender.window!.graphicsContext,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )

        NSMenu.popUpContextMenu(layoutMenu, with: event!, for: sender)
    }

    @objc func selectFloatingApplication(_ sender: AnyObject) {
        let openPanel = NSOpenPanel()
        let applicationDirectories = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)

        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.allowedFileTypes = ["app"]
        openPanel.prompt = "Select"
        openPanel.directoryURL = applicationDirectories.first

        guard case openPanel.runModal() = NSApplication.ModalResponse.cancel else {
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

    @objc func manuallyEnterFloatingApplication(_ sender: AnyObject) {
        editingFloatingBundleIdentifier = true
        floatingTableView?.reloadData()
        floatingTableView?.editColumn(0, row: floatingBundleIdentifiers.count, with: nil, select: true)
    }

    private func addFloatingApplicationBundleIdentifier(_ bundleIdentifier: String) {
        var floatingBundleIdentifiers = self.floatingBundleIdentifiers
        floatingBundleIdentifiers.append(bundleIdentifier)
        self.floatingBundleIdentifiers = floatingBundleIdentifiers

        UserConfiguration.shared.setFloatingBundleIdentifiers(self.floatingBundleIdentifiers)
    }

    @IBAction func removeFloatingApplication(_ sender: AnyObject) {
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

    func preferenceIdentifier() -> String! {
        return NSStringFromClass(type(of: self))
    }

    func preferenceIcon() -> NSImage! {
        return NSImage(named: .preferencesGeneral)
    }

    func preferenceTitle() -> String! {
        return "General"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableView {
        case layoutsTableView!:
            return layouts.count
        case floatingTableView!:
            return floatingBundleIdentifiers.count + (editingFloatingBundleIdentifier ? 1 : 0)
        default:
            return 0
        }
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
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

    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        guard tableView == floatingTableView && row == floatingBundleIdentifiers.count else {
            return false
        }

        return true
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
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
