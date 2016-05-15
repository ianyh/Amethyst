//
//  HotKeyRegistrar.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import MASShortcut

public protocol HotKeyRegistrar {
    func registerHotKeyWithKeyString(string: String, modifiers: AMModifierFlags, handler: () -> (), defaultsKey: String, override: Bool)
}

extension HotKeyManager: HotKeyRegistrar {
    public func registerHotKeyWithKeyString(string: String, modifiers: AMModifierFlags, handler: () -> (), defaultsKey: String, override: Bool) {
        let userDefaults = NSUserDefaults.standardUserDefaults()

        if userDefaults.objectForKey(defaultsKey) != nil && !override {
            MASShortcutBinder.sharedBinder().bindShortcutWithDefaultsKey(defaultsKey, toAction: handler)
            return
        }

        guard let keyCodes = stringToKeyCodes[string.lowercaseString] where keyCodes.count > 0 else {
            print("String \"\(string)\" does not map to any keycodes")
            return
        }

        let shortcut = MASShortcut(keyCode: UInt(keyCodes[0]), modifierFlags: modifiers)

        MASShortcutBinder.sharedBinder().registerDefaultShortcuts([ defaultsKey: shortcut ])
        MASShortcutBinder.sharedBinder().bindShortcutWithDefaultsKey(defaultsKey, toAction: handler)

        // Note that the shortcut binder above only sets the default value, not the stored value, so we explicitly store it here.
        userDefaults.setObject(userDefaults.objectForKey(defaultsKey), forKey:defaultsKey)
    }
}
