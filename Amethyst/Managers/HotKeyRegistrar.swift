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

        defer {
            KeyboardShortcuts.onKeyUp(for: name, action: handler)
        }

        if override {
            MASShortcutBinder.shared().breakBinding(withDefaultsKey: defaultsKey)
            // Setting the shortcut via KeyboardShortcuts should overwrite this regardless, but we remove it here for good measure
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            KeyboardShortcuts.setShortcut(nil, for: name)
        }

        // If there is an existing shortcut defined by MASShortcut we need to parse and convert it before continuing
        if let value = UserDefaults.standard.dictionary(forKey: defaultsKey), let shortcut = MASDictionaryTransformer().transformedValue(value) as? MASShortcut {
            let shortcutKey = KeyboardShortcuts.Key(rawValue: shortcut.keyCode)
            let newShortcut = KeyboardShortcuts.Shortcut(shortcutKey, modifiers: shortcut.modifierFlags)
            // Setting the shortcut via KeyboardShortcuts should overwrite this regardless, but we remove it here for good measure
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            KeyboardShortcuts.setShortcut(newShortcut, for: name)
        }

        guard KeyboardShortcuts.getShortcut(for: name) == nil else {
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
