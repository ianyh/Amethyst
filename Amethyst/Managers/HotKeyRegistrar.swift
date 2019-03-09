//
//  HotKeyRegistrar.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import MASShortcut

protocol HotKeyRegistrar {
    func registerHotKey(with string: String?, modifiers: AMModifierFlags?, handler: @escaping () -> Void, defaultsKey: String, override: Bool)
}

extension HotKeyManager: HotKeyRegistrar {
    func registerHotKey(with string: String?, modifiers: AMModifierFlags?, handler: @escaping () -> Void, defaultsKey: String, override: Bool) {
        let userDefaults = UserDefaults.standard

        if userDefaults.object(forKey: defaultsKey) != nil && !override {
            MASShortcutBinder.shared().bindShortcut(withDefaultsKey: defaultsKey, toAction: handler)
            return
        }

        // If a command is specified, set it as the default shortcut
        if let string = string, let modifiers = modifiers {
            if let keyCodes = stringToKeyCodes[string.lowercased()], !keyCodes.isEmpty {
                let shortcut = MASShortcut(keyCode: UInt(keyCodes[0]), modifierFlags: modifiers)
                MASShortcutBinder.shared().registerDefaultShortcuts([ defaultsKey: shortcut as Any ])
            } else {
                log.warning("String \"\(string)\" does not map to any keycodes")
            }
        }

        MASShortcutBinder.shared().bindShortcut(withDefaultsKey: defaultsKey, toAction: handler)

        // Note that the shortcut binder above only sets the default value, not the stored value, so we explicitly store it here.
        userDefaults.set(userDefaults.object(forKey: defaultsKey), forKey: defaultsKey)
    }
}
