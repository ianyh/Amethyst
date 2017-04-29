//
//  ShortcutsPreferencesListItemView.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cartography
import Foundation
import MASShortcut

final class ShortcutsPreferencesListItemView: NSView {
    private(set) var nameLabel: NSTextField?
    private(set) var shortcutView: MASShortcutView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let label = NSTextField()
        let shortcutView = MASShortcutView(frame: NSRect(x: 0, y: 0, width: 120, height: 19))

        label.isBezeled = false
        label.isEditable = false
        label.stringValue = ""
        label.backgroundColor = NSColor.clear
        label.sizeToFit()

        addSubview(label)
        addSubview(shortcutView)

        constrain(label, shortcutView, self) { label, shortcutView, view in
            label.centerY == view.centerY
            label.left == view.left + 8

            shortcutView.centerY == view.centerY
            shortcutView.right == view.right - 16
            shortcutView.width == 120
            shortcutView.height == 19
        }

        self.nameLabel = label
        self.shortcutView = shortcutView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        shortcutView?.associatedUserDefaultsKey = nil
    }
}
