//
//  ShortcutsPreferencesListItemView.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cartography
import Cocoa
import Foundation
import KeyboardShortcuts

class ShortcutsPreferencesListItemView: NSView {
    private(set) var nameLabel: NSTextField?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let label = NSTextField()

        label.isBezeled = false
        label.isEditable = false
        label.stringValue = ""
        label.backgroundColor = NSColor.clear
        label.sizeToFit()

        addSubview(label)

        constrain(label, self) { label, view in
            label.centerY == view.centerY
            label.left == view.left + 8
        }

        self.nameLabel = label
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setShortcutName(name: KeyboardShortcuts.Name) {
        let shortcutView = KeyboardShortcuts.RecorderCocoa(for: name)

        addSubview(shortcutView)

        constrain(shortcutView, self) { shortcutView, view in
            shortcutView.centerY == view.centerY
            shortcutView.right == view.right - 16
        }
    }
}
