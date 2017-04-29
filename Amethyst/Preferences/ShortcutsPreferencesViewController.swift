//
//  ShortcutsPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import CCNPreferencesWindowController_ObjC
import Cocoa
import Foundation
import MASShortcut

final class ShortcutsPreferencesViewController: NSViewController, CCNPreferencesWindowControllerProtocol, NSTableViewDataSource, NSTableViewDelegate {
    private var hotKeyNameToDefaultsKey: [[String]] = []
    @IBOutlet var tableView: NSTableView?

    override func awakeFromNib() {
        tableView?.dataSource = self
        tableView?.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        hotKeyNameToDefaultsKey = HotKeyManager.hotKeyNameToDefaultsKey()
        tableView?.reloadData()
    }

    func preferenceIdentifier() -> String! {
        return NSStringFromClass(type(of: self))
    }

    func preferenceIcon() -> NSImage! {
        return NSImage(named: NSImageNameAdvanced)
    }

    func preferenceTitle() -> String! {
        return "Shortcuts"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return hotKeyNameToDefaultsKey.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let frame = NSRect(x: 0, y: 0, width: tableView.frame.size.width, height: 30)
        let shortcutItemView = ShortcutsPreferencesListItemView(frame: frame)
        let name = hotKeyNameToDefaultsKey[row][0]
        let key = hotKeyNameToDefaultsKey[row][1]

        shortcutItemView.nameLabel?.stringValue = name
        shortcutItemView.shortcutView?.associatedUserDefaultsKey = key

        return shortcutItemView
    }

    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        return false
    }
}
