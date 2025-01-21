//
//  HotKeyRegistrar.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import KeyboardShortcuts
import MASShortcut

protocol HotKeyRegistrar {
    func registerHotKey(with string: String?, modifiers: AMModifierFlags?, handler: @escaping () -> Void, defaultsKey: String, override: Bool)
}

extension HotKeyManager: HotKeyRegistrar {
    func registerHotKey(with string: String?, modifiers: AMModifierFlags?, handler: @escaping () -> Void, defaultsKey: String, override: Bool) {
        let name = KeyboardShortcuts.Name(defaultsKey)
        let migrationKey = "migrated-\(name.rawValue)"
        let isMigrated = UserDefaults.standard.bool(forKey: migrationKey)

        defer {
            UserDefaults.standard.set(true, forKey: migrationKey)
            KeyboardShortcuts.onKeyUp(for: name, action: handler)
        }

        if override {
            MASShortcutBinder.shared().breakBinding(withDefaultsKey: defaultsKey)
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            KeyboardShortcuts.setShortcut(nil, for: name)
        }

        guard KeyboardShortcuts.getShortcut(for: name) == nil && (!isMigrated || override) else {
            return
        }

        if let value = UserDefaults.standard.object(forKey: defaultsKey),
           let shortcut = ValueTransformer(forName: .keyedUnarchiveFromDataTransformerName)?.transformedValue(value) as? MASShortcut {
            let shortcutKey = KeyboardShortcuts.Key(rawValue: shortcut.keyCode)
            let newShortcut = KeyboardShortcuts.Shortcut(shortcutKey, modifiers: shortcut.modifierFlags)
            // Keeping the old shortcuts in defaults for now to prevent data loss
//            UserDefaults.standard.removeObject(forKey: defaultsKey)
            KeyboardShortcuts.setShortcut(newShortcut, for: name)
            return
        }

        if let string = string, let modifiers = modifiers {
            if let keyCodes = stringToKeyCodes[string.lowercased()], !keyCodes.isEmpty {
                let shortcutKey = KeyboardShortcuts.Key(rawValue: keyCodes[0])
                let shortcut = KeyboardShortcuts.Shortcut(shortcutKey, modifiers: modifiers)
                KeyboardShortcuts.setShortcut(shortcut, for: name)
            } else {
                log.warning("String \"\(string)\" does not map to any keycodes")
            }
        }
    }
}
