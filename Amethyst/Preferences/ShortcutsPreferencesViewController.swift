//
//  ShortcutsPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import KeyboardShortcuts
import Silica

class ShortcutsPreferencesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var hotKeyNameToDefaultsKey: [[String]] = []
    @IBOutlet var tableView: NSTableView?

    override func awakeFromNib() {
        tableView?.dataSource = self
        tableView?.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        hotKeyNameToDefaultsKey = HotKeyManager<SIApplication>.hotKeyNameToDefaultsKey()
        tableView?.reloadData()
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
        shortcutItemView.setShortcutName(name: KeyboardShortcuts.Name(key))

        return shortcutItemView
    }

    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        return false
    }
}
