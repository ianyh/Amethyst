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

open class ShortcutsPreferencesViewController: NSViewController, CCNPreferencesWindowControllerProtocol, NSTableViewDataSource, NSTableViewDelegate {
    fileprivate var hotKeyNameToDefaultsKey: [[String]] = []
    @IBOutlet open var tableView: NSTableView?

    open override func awakeFromNib() {
        tableView?.dataSource = self
        tableView?.delegate = self
    }

    open override func viewWillAppear() {
        super.viewWillAppear()

        let configuration = UserConfiguration.shared
        hotKeyNameToDefaultsKey = HotKeyManager.hotKeyNameToDefaultsKey(screenCount: configuration.screens!)
        tableView?.reloadData()
    }

    open func preferenceIdentifier() -> String! {
        return NSStringFromClass(type(of: self))
    }

    open func preferenceIcon() -> NSImage! {
        return NSImage(named: NSImageNameAdvanced)
    }

    open func preferenceTitle() -> String! {
        return "Shortcuts"
    }

    open func numberOfRows(in tableView: NSTableView) -> Int {
        return hotKeyNameToDefaultsKey.count
    }

    open func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let frame = NSRect(x: 0, y: 0, width: tableView.frame.size.width, height: 30)
        let shortcutItemView = ShortcutsPreferencesListItemView(frame: frame)
        let name = hotKeyNameToDefaultsKey[row][0]
        let key = hotKeyNameToDefaultsKey[row][1]

        shortcutItemView.nameLabel?.stringValue = name
        shortcutItemView.shortcutView?.associatedUserDefaultsKey = key

        return shortcutItemView
    }

    open func selectionShouldChange(in tableView: NSTableView) -> Bool {
        return false
    }
}
