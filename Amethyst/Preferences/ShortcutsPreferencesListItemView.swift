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

class ShortcutsPreferencesListItemView: NSView {
    private(set) var nameLabel: NSTextField?
    private(set) var shortcutView: MASShortcutView?
    private(set) var shortcutDraft: MASShortcutView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let label = NSTextField()
        let shortcutView = MASShortcutView(frame: NSRect(x: 0, y: 0, width: 105, height: 19))
        let shortcutDraft = MASShortcutView(frame: NSRect(x: 0, y: 0, width: 105, height: 19))

        label.isBezeled = false
        label.isEditable = false
        label.stringValue = ""
        label.backgroundColor = NSColor.clear
        label.sizeToFit()

        shortcutDraft.isEnabled = false

        addSubview(label)
        addSubview(shortcutView)
        addSubview(shortcutDraft)

        constrain(label, shortcutView, shortcutDraft, self) { label, shortcutView, shortcutDraft, view in
            shortcutView.centerY == view.centerY
            shortcutView.right == view.right - 108
            shortcutView.width == 100
            shortcutView.height == 19

            label.centerY == view.centerY
            label.left == view.left + 8
            label.right == shortcutView.left - 2

            shortcutDraft.centerY == view.centerY
            shortcutDraft.right == view.right
            shortcutDraft.width == 100
            shortcutDraft.height == 19
        }

        self.nameLabel = label
        self.shortcutView = shortcutView
        self.shortcutDraft = shortcutDraft
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        shortcutView?.associatedUserDefaultsKey = nil
        shortcutDraft?.associatedUserDefaultsKey = nil
    }
}
