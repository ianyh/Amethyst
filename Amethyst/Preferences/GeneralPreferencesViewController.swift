//
//  GeneralPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation

final class GeneralPreferencesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var layoutKeys: [String] = []

    @IBOutlet var layoutsTableView: NSTableView?

    override func awakeFromNib() {
        super.awakeFromNib()

        layoutsTableView?.dataSource = self
        layoutsTableView?.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        layoutKeys = UserConfiguration.shared.layoutKeys()

        layoutsTableView?.reloadData()
    }

    @IBAction func addLayout(_ sender: NSButton) {
        let layoutMenu = NSMenu(title: "")

        for (layoutKey, layoutName) in LayoutManager.availableLayoutStrings() {
            let menuItem = NSMenuItem(title: layoutKey, action: #selector(addLayoutString(_:)), keyEquivalent: "")
            menuItem.attributedTitle = NSAttributedString(string: layoutName)
            menuItem.title = layoutKey
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
        var layoutKeys = self.layoutKeys
        layoutKeys.append(sender.title)
        self.layoutKeys = layoutKeys

        UserConfiguration.shared.setLayoutKeys(self.layoutKeys)

        layoutsTableView?.reloadData()
    }

    @IBAction func removeLayout(_ sender: AnyObject) {
        guard let selectedRow = layoutsTableView?.selectedRow, selectedRow < self.layoutKeys.count, selectedRow != NSTableView.noRowSelectedIndex else { return }

        layoutKeys.remove(at: selectedRow)

        UserConfiguration.shared.setLayoutKeys(layoutKeys)

        layoutsTableView?.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return layoutKeys.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row > -1 else {
            return nil
        }

        return LayoutManager.layoutNameForKey(layoutKeys[row])
    }
}
