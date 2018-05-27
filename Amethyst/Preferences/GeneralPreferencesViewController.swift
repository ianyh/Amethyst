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
    private var layouts: [String] = []

    @IBOutlet var layoutsTableView: NSTableView?

    override func awakeFromNib() {
        super.awakeFromNib()

        layoutsTableView?.dataSource = self
        layoutsTableView?.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        layouts = UserConfiguration.shared.layoutStrings()

        layoutsTableView?.reloadData()
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
        guard let selectedRow = layoutsTableView?.selectedRow, selectedRow < self.layouts.count, selectedRow != NSTableView.noRowSelectedIndex else { return }

        layouts.remove(at: selectedRow)

        UserConfiguration.shared.setLayoutStrings(layouts)

        layoutsTableView?.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return layouts.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row > -1 else {
            return nil
        }

        return layouts[row]
    }
}
