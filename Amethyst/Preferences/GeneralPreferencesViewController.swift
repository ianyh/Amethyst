//
//  GeneralPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import Silica

class GeneralPreferencesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var layoutKeys: [String] = []

    @IBOutlet var layoutsTableView: NSTableView?

    override func awakeFromNib() {
        super.awakeFromNib()

        layoutsTableView?.dataSource = self
        layoutsTableView?.delegate = self
        layoutsTableView?.registerForDraggedTypes([.string])
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        layoutKeys = UserConfiguration.shared.layoutKeys()

        layoutsTableView?.reloadData()
    }

    @IBAction func addLayout(_ sender: NSButton) {
        let layoutMenu = NSMenu(title: "")

        for (layoutKey, layoutName) in LayoutType<AXWindow>.availableLayoutStrings() {
            let menuItem = NSMenuItem(title: layoutName, action: #selector(addLayoutString(_:)), keyEquivalent: "")
            menuItem.representedObject = layoutKey
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
        guard let layoutKey: String = sender.representedObject as? String else { return }

        var layoutKeys = self.layoutKeys
        layoutKeys.append(layoutKey)
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

        return LayoutType<AXWindow>.layoutNameForKey(layoutKeys[row])
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        if let dragData = info.draggingPasteboard.data(forType: .string),
            let rowString = String(bytes: dragData, encoding: .utf8),
            let oldRow = Int(rowString) {

            layoutKeys.move(from: oldRow, to: oldRow < row ? row-1 : row)
            UserConfiguration.shared.setLayoutKeys(self.layoutKeys)
            layoutsTableView?.reloadData()
            return true
        }
        return false
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return []

    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: .string)
        return item
    }
}

extension Array {
    mutating func move(from oldIndex: Index, to newIndex: Index) {
        if oldIndex == newIndex { return }
        if abs(newIndex - oldIndex) == 1 { return self.swapAt(oldIndex, newIndex) }
        self.insert(self.remove(at: oldIndex), at: newIndex)
    }
}
