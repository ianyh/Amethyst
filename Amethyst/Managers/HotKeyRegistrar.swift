//
//  HotKeyRegistrar.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import KeyboardShortcuts

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
            KeyboardShortcuts.setShortcut(nil, for: name)
        }

        guard KeyboardShortcuts.getShortcut(for: name) == nil else {
            return
        }

        // If a command is specified, set it as the default shortcut
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
