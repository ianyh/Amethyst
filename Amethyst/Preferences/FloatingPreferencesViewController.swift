//
//  GeneralPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation

final class FloatingPreferencesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var floatingBundleIdentifiers: [String] = []

    @IBOutlet var floatingTableView: NSTableView?

    private var editingFloatingBundleIdentifier = false

    override func awakeFromNib() {
        super.awakeFromNib()

        floatingTableView?.dataSource = self
        floatingTableView?.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        floatingBundleIdentifiers = UserConfiguration.shared.floatingBundleIdentifiers()

        floatingTableView?.reloadData()
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

        guard case openPanel.runModal() = NSApplication.ModalResponse.OK else {
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

        guard floatingTableView.selectedRow < self.floatingBundleIdentifiers.count, floatingTableView.selectedRow != NSTableView.noRowSelectedIndex else {
            return
        }

        var floatingBundleIdentifiers = self.floatingBundleIdentifiers
        floatingBundleIdentifiers.remove(at: floatingTableView.selectedRow)
        self.floatingBundleIdentifiers = floatingBundleIdentifiers

        UserConfiguration.shared.setFloatingBundleIdentifiers(self.floatingBundleIdentifiers)

        floatingTableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return floatingBundleIdentifiers.count + (editingFloatingBundleIdentifier ? 1 : 0)
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row > -1 else {
            return nil
        }

        if editingFloatingBundleIdentifier && row == floatingBundleIdentifiers.count {
            return nil
        }

        return floatingBundleIdentifiers[row]
    }

    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        return row == floatingBundleIdentifiers.count
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard row == floatingBundleIdentifiers.count else {
            return
        }

        editingFloatingBundleIdentifier = false

        if let identifier = object as? String {
            addFloatingApplicationBundleIdentifier(identifier)
        }

        floatingTableView?.reloadData()
    }
}

@objc(FloatingBlacklistIntBooleanTransformer) class FloatingBlacklistIntBooleanTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let number = value as? Int else {
            return nil
        }

        switch number {
        case 0:
            return true
        case 1:
            return false
        default:
            return nil
        }
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let boolean = value as? Bool else {
            return nil
        }

        return boolean ? 0 : 1
    }
}
