//
//  GeneralPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation

class ManualFloatingBundleID: NSObject {
    @objc dynamic var id: String = ""
    @objc dynamic var windowTitles: [String] = []
}

final class FloatingPreferencesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var floatingBundles: [FloatingBundle] = [] {
        didSet {
            guard let arrayController = arrayController else {
                return
            }

            arrayController.remove(contentsOf: arrayController.arrangedObjects as! [Any])
            arrayController.add(contentsOf: floatingBundles)
        }
    }

    @IBOutlet var floatingTableView: NSTableView!
    @IBOutlet var windowTitlesTableView: NSTableView!
    @IBOutlet var windowTitlesCoverView: NSView!
    @IBOutlet var arrayController: NSArrayController!

    override func awakeFromNib() {
        super.awakeFromNib()

        windowTitlesCoverView.wantsLayer = true
        windowTitlesCoverView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        floatingBundles = UserConfiguration.shared.floatingBundles()
        arrayController?.setSelectionIndexes(IndexSet())
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
    }

    @objc func manuallyEnterFloatingApplication(_ sender: AnyObject) {
        guard let window = view.window else {
            return
        }

        let alert = NSAlert()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = field
        alert.icon = nil
        alert.messageText = "Application Bundle ID"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else {
                return
            }

            self?.addFloatingApplicationBundleIdentifier(field.stringValue)
        }
    }

    private func addFloatingApplicationBundleIdentifier(_ bundleIdentifier: String) {
        var floatingBundles = self.floatingBundles
        let floatingBundle = FloatingBundle(id: bundleIdentifier, windowTitles: [])
        floatingBundles.append(floatingBundle)
        self.floatingBundles = floatingBundles

        UserConfiguration.shared.setFloatingBundles(self.floatingBundles)
    }

    @IBAction func removeFloatingApplication(_ sender: AnyObject) {
        guard let floatingTableView = floatingTableView else {
            return
        }

        guard floatingTableView.selectedRow < floatingBundles.count, floatingTableView.selectedRow != NSTableView.noRowSelectedIndex else {
            return
        }

        floatingBundles.remove(at: floatingTableView.selectedRow)

        UserConfiguration.shared.setFloatingBundles(self.floatingBundles)
    }

    @IBAction func addWindowTitle(_ sender: AnyObject) {
        guard let window = view.window else {
            return
        }

        let alert = NSAlert()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = field
        alert.icon = nil
        alert.messageText = "Window Title"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else {
                return
            }

            self?.addWindowTitleToSelectedApplication(field.stringValue)
        }
    }

    @IBAction func removeWindowTitle(_ sender: AnyObject) {
        let selection = arrayController.selection as AnyObject

        guard let id = selection.value(forKey: "id") as? String, let windowTitles = selection.value(forKey: "windowTitles") as? [String] else {
            return
        }

        guard windowTitlesTableView.selectedRow < windowTitles.count, windowTitlesTableView.selectedRow != NSTableView.noRowSelectedIndex else {
            return
        }

        let title = windowTitles[windowTitlesTableView.selectedRow]
        let updatedBundle = FloatingBundle(id: id, windowTitles: windowTitles.filter { $0 != title })
        floatingBundles.index { $0.id == id }.flatMap { floatingBundles[$0] = updatedBundle }

        UserConfiguration.shared.setFloatingBundles(self.floatingBundles)
    }

    private func addWindowTitleToSelectedApplication(_ title: String) {
        let selection = arrayController.selection as AnyObject

        guard let id = selection.value(forKey: "id") as? String, let windowTitles = selection.value(forKey: "windowTitles") as? [String] else {
            return
        }

        let updatedBundle = FloatingBundle(id: id, windowTitles: windowTitles + [title])
        floatingBundles.index { $0.id == id }.flatMap { floatingBundles[$0] = updatedBundle }

        UserConfiguration.shared.setFloatingBundles(self.floatingBundles)
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

@objc(AllWindowsHiddenTitlesCountTransformer) class AllWindowsHiddenTitlesCountTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let count = value as? Int else {
            return false
        }

        return count != 0
    }
}
