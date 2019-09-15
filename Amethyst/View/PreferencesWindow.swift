//
//  PreferencesWindow.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 7/19/17.
//  Copyright © 2017 Ian Ynda-Hummel. All rights reserved.
//

import AppKit

class PreferencesWindowController: NSWindowController {
    override func awakeFromNib() {
        super.awakeFromNib()

        window?.title = ""

        guard let firstItem = window?.toolbar?.items.first else {
            return
        }

        window?.toolbar?.selectedItemIdentifier = firstItem.itemIdentifier
        selectPane(firstItem)
    }

    @IBAction func selectPane(_ sender: NSToolbarItem) {
        switch sender.itemIdentifier.rawValue {
        case "general":
            contentViewController = GeneralPreferencesViewController()
        case "shortcuts":
            contentViewController = ShortcutsPreferencesViewController()
        case "floating":
            contentViewController = FloatingPreferencesViewController()
        case "debug":
            contentViewController = DebugPreferencesViewController()
        default:
            break
        }
    }
}

class PreferencesWindow: NSWindow {
    @IBOutlet var closeMenuItem: NSMenuItem?

    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)

        guard let closeMenuItem = closeMenuItem else {
            return
        }

        let eventModifierMask = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        guard closeMenuItem.keyEquivalentModifierMask == eventModifierMask && closeMenuItem.keyEquivalent == event.characters else {
            return
        }

        close()
    }
}
