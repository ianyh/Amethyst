//
//  ShortcutsPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import CCNPreferencesWindowController
import Cocoa
import Foundation
import MASShortcut

@objc public class ShortcutsPreferencesViewController: NSViewController, CCNPreferencesWindowControllerProtocol, NSTableViewDataSource, NSTableViewDelegate {
    private var hotKeyNameToDefaultsKey: [[String]] = []
    @IBOutlet public var tableView: NSTableView?

    public override func awakeFromNib() {
        tableView?.setDataSource(self)
        tableView?.setDelegate(self)
    }

    public override func viewWillAppear() {
        super.viewWillAppear()

        hotKeyNameToDefaultsKey = HotKeyManager.hotKeyNameToDefaultsKey()
        tableView?.reloadData()
    }

    public func preferenceIdentifier() -> String! {
        return NSStringFromClass(self.dynamicType)
    }

    public func preferenceIcon() -> NSImage! {
        return NSImage(named: NSImageNameAdvanced)
    }

    public func preferenceTitle() -> String! {
        return "Shortcuts"
    }

    public func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return hotKeyNameToDefaultsKey.count
    }

    public func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let frame = NSMakeRect(0, 0, tableView.frame.size.width, 30)
        let shortcutItemView = ShortcutsPreferencesListItemView(frame: frame)
        let name = hotKeyNameToDefaultsKey[row][0]
        let key = hotKeyNameToDefaultsKey[row][1]

        shortcutItemView.nameLabel?.stringValue = name
        shortcutItemView.shortcutView?.associatedUserDefaultsKey = key

        return shortcutItemView
    }

    public func selectionShouldChangeInTableView(tableView: NSTableView) -> Bool {
        return false
    }
}
