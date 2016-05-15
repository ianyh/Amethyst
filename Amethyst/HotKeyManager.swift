//
//  HotKeyManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import MASShortcut

// Type for defining key code.
public typealias AMKeyCode = Int

// Type for defining modifier flags.
public typealias AMModifierFlags = UInt

// Specific key code defined to be invalid.
// Can be used to identify if a returned key code is valid or not.
public let AMKeyCodeInvalid: AMKeyCode = 0xFF

public class HotKey: NSObject {
    public let hotKeyRef: EventHotKeyRef
    public let handler: () -> ()

    public init(hotKeyRef: EventHotKeyRef, handler: () -> ()) {
        self.hotKeyRef = hotKeyRef
        self.handler = handler
    }
}

public class HotKeyManager: NSObject {
    public lazy var stringToKeyCodes: [String: [AMKeyCode]] = {
        return self.constructKeyCodeMap()
    }()

    public override init() {
        super.init()
        self.constructKeyCodeMap()
        MASShortcutValidator.sharedValidator().allowAnyShortcutWithOptionModifier = true
    }

    private static func keyCodeForNumber(number: NSNumber) -> AMKeyCode {
        let string = "\(number)"

        guard string.characters.count > 0 else {
            return AMKeyCodeInvalid
        }

        switch string.characters.last! {
        case "1":
            return kVK_ANSI_1
        case "2":
            return kVK_ANSI_2
        case "3":
            return kVK_ANSI_3
        case "4":
            return kVK_ANSI_4
        case "5":
            return kVK_ANSI_5
        case "6":
            return kVK_ANSI_6
        case "7":
            return kVK_ANSI_7
        case "8":
            return kVK_ANSI_8
        case "9":
            return kVK_ANSI_9
        case "0":
            return kVK_ANSI_0
        default:
            return AMKeyCodeInvalid
        }
    }

    public func constructKeyCodeMap() -> [String: [AMKeyCode]] {
        var stringToKeyCodes: [String: [AMKeyCode]] = [:]

        // Generate unicode character keymapping from keyboard layout data.  We go
        // through all keycodes and create a map of string representations to a list
        // of key codes. It has to map to a list because a string representation
        // canmap to multiple codes (e.g., 1 and numpad 1 both have string
        // representation "1").
        var currentKeyboard = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        var rawLayoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData)

        if rawLayoutData == nil {
            currentKeyboard = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeUnretainedValue()
            rawLayoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData)
        }

        // Get the layout
        let layoutData = unsafeBitCast(rawLayoutData, CFDataRef.self)
        let layout: UnsafePointer<UCKeyboardLayout> = unsafeBitCast(CFDataGetBytePtr(layoutData), UnsafePointer<UCKeyboardLayout>.self)

        var keysDown: UInt32 = 0
        var chars: [UniChar] = [0, 0, 0, 0]
        var realLength: Int = 0

        for keyCode in (0..<AMKeyCodeInvalid) {
            switch keyCode {
            case kVK_ANSI_Keypad0:
                fallthrough
            case kVK_ANSI_Keypad1:
                fallthrough
            case kVK_ANSI_Keypad2:
                fallthrough
            case kVK_ANSI_Keypad3:
                fallthrough
            case kVK_ANSI_Keypad4:
                fallthrough
            case kVK_ANSI_Keypad5:
                fallthrough
            case kVK_ANSI_Keypad6:
                fallthrough
            case kVK_ANSI_Keypad7:
                fallthrough
            case kVK_ANSI_Keypad8:
                fallthrough
            case kVK_ANSI_Keypad9:
                continue
            default:
                break
            }

            UCKeyTranslate(layout,
                           UInt16(keyCode),
                           UInt16(kUCKeyActionDisplay),
                           0,
                           UInt32(LMGetKbdType()),
                           UInt32(kUCKeyTranslateNoDeadKeysBit),
                           &keysDown,
                           chars.count,
                           &realLength,
                           &chars)

            let string = CFStringCreateWithCharacters(kCFAllocatorDefault, chars, realLength) as String

            if let keyCodes = stringToKeyCodes[string] {
                var mutableKeyCodes = keyCodes
                mutableKeyCodes.append(keyCode)
                stringToKeyCodes[string] = mutableKeyCodes
            } else {
                stringToKeyCodes[string] = [keyCode]
            }
        }

        // Add codes for non-printable characters. They are not printable so they
        // are not generated from the keyboard layout data.
        stringToKeyCodes["space"] = [kVK_Space]
        stringToKeyCodes["enter"] = [kVK_Return]
        stringToKeyCodes["up"] = [kVK_UpArrow]
        stringToKeyCodes["right"] = [kVK_RightArrow]
        stringToKeyCodes["down"] = [kVK_DownArrow]
        stringToKeyCodes["left"] = [kVK_LeftArrow]

        return stringToKeyCodes
    }

    private func carbonModifiersFromModifiers(modifiers: UInt) -> UInt32 {
        var carbonModifiers: UInt32 = 0

        if (modifiers & UInt(NSEventModifierFlags.ShiftKeyMask.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(shiftKey)
        }

        if (modifiers & UInt(NSEventModifierFlags.CommandKeyMask.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(cmdKey)
        }

        if (modifiers & UInt(NSEventModifierFlags.AlternateKeyMask.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(optionKey)
        }

        if (modifiers & UInt(NSEventModifierFlags.ControlKeyMask.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(controlKey)
        }

        return carbonModifiers
    }

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
