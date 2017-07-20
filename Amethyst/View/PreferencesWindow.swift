//
//  PreferencesWindow.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 7/19/17.
//  Copyright © 2017 Ian Ynda-Hummel. All rights reserved.
//

import AppKit

final class PreferencesWindow: NSWindow {
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
