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
typealias AMKeyCode = Int

// Type for defining modifier flags.
typealias AMModifierFlags = UInt

// Specific key code defined to be invalid.
// Can be used to identify if a returned key code is valid or not.
private let AMKeyCodeInvalid: AMKeyCode = 0xFF

typealias HotKeyHandler = () -> Void

final class HotKeyManager: NSObject {
    private let userConfiguration: UserConfiguration

    private(set) lazy var stringToKeyCodes: [String: [AMKeyCode]] = {
        return self.constructKeyCodeMap()
    }()

    init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        super.init()
        _ = constructKeyCodeMap()
        MASShortcutValidator.shared().allowAnyShortcutWithOptionModifier = true
    }

    private static func keyCodeForNumber(_ number: NSNumber) -> AMKeyCode {
        let string = "\(number)"

        guard !string.characters.isEmpty else {
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

    func setUpWithWindowManager(_ windowManager: WindowManager, configuration: UserConfiguration) {
        constructCommandWithCommandKey(CommandKey.cycleLayoutForward.rawValue) {
            windowManager.focusedScreenManager()?.cycleLayoutForward()
        }

        constructCommandWithCommandKey(CommandKey.cycleLayoutBackward.rawValue) {
            windowManager.focusedScreenManager()?.cycleLayoutBackward()
        }

        constructCommandWithCommandKey(CommandKey.shrinkMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout { layout in
                if let panedLayout = layout as? PanedLayout {
                    panedLayout.shrinkMainPane()
                }
            }
        }

        constructCommandWithCommandKey(CommandKey.expandMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout { layout in
                if let panedLayout = layout as? PanedLayout {
                    panedLayout.expandMainPane()
                }
            }
        }

        constructCommandWithCommandKey(CommandKey.increaseMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout { layout in
                if let panedLayout = layout as? PanedLayout {
                    panedLayout.increaseMainPaneCount()
                }
            }
        }

        constructCommandWithCommandKey(CommandKey.decreaseMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout { layout in
                if let panedLayout = layout as? PanedLayout {
                    panedLayout.decreaseMainPaneCount()
                }
            }
        }

        constructCommandWithCommandKey(CommandKey.focusCCW.rawValue) {
            windowManager.moveFocusCounterClockwise()
        }

        constructCommandWithCommandKey(CommandKey.focusCW.rawValue) {
            windowManager.moveFocusClockwise()
        }

        constructCommandWithCommandKey(CommandKey.swapScreenCCW.rawValue) {
            windowManager.swapFocusedWindowScreenCounterClockwise()
        }

        constructCommandWithCommandKey(CommandKey.swapScreenCW.rawValue) {
            windowManager.swapFocusedWindowScreenClockwise()
        }

        constructCommandWithCommandKey(CommandKey.swapCCW.rawValue) {
            windowManager.swapFocusedWindowCounterClockwise()
        }

        constructCommandWithCommandKey(CommandKey.swapCW.rawValue) {
            windowManager.swapFocusedWindowClockwise()
        }

        constructCommandWithCommandKey(CommandKey.swapMain.rawValue) {
            windowManager.swapFocusedWindowToMain()
        }

        constructCommandWithCommandKey(CommandKey.displayCurrentLayout.rawValue) {
            windowManager.displayCurrentLayout()
        }

        (1...4).forEach { screenNumber in
            let focusCommandKey = "\(CommandKey.focusScreenPrefix.rawValue)-\(screenNumber)"
            let throwCommandKey = "\(CommandKey.throwScreenPrefix.rawValue)-\(screenNumber)"

            self.constructCommandWithCommandKey(focusCommandKey) {
                windowManager.focusScreen(at: screenNumber - 1)
            }

            self.constructCommandWithCommandKey(throwCommandKey) {
                windowManager.throwToScreenAtIndex(screenNumber - 1)
            }
        }

        (1...10).forEach { spaceNumber in
            let commandKey = "\(CommandKey.throwSpacePrefix.rawValue)-\(spaceNumber)"

            self.constructCommandWithCommandKey(commandKey) {
                windowManager.pushFocusedWindowToSpace(UInt(spaceNumber))
            }
        }

        constructCommandWithCommandKey(CommandKey.throwSpaceLeft.rawValue) {
            windowManager.pushFocusedWindowToSpaceLeft()
        }

        constructCommandWithCommandKey(CommandKey.throwSpaceRight.rawValue) {
            windowManager.pushFocusedWindowToSpaceRight()
        }

        constructCommandWithCommandKey(CommandKey.toggleFloat.rawValue) {
            windowManager.toggleFloatForFocusedWindow()
        }

        constructCommandWithCommandKey(CommandKey.toggleTiling.rawValue) {
            self.userConfiguration.tilingEnabled = !self.userConfiguration.tilingEnabled
            windowManager.markAllScreensForReflowWithChange(.unknown)
        }

        constructCommandWithCommandKey(CommandKey.reevaluateWindows.rawValue) {
            windowManager.reevaluateWindows()
        }

        constructCommandWithCommandKey(CommandKey.toggleFocusFollowsMouse.rawValue) {
            self.userConfiguration.toggleFocusFollowsMouse()
        }

        LayoutManager.availableLayoutStrings().forEach { layoutString in
            self.constructCommandWithCommandKey(UserConfiguration.constructLayoutKeyString(layoutString)) {
                windowManager.focusedScreenManager()?.selectLayout(layoutString)
            }
        }
    }

    private func constructKeyCodeMap() -> [String: [AMKeyCode]] {
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
        let layoutData = unsafeBitCast(rawLayoutData, to: CFData.self)
        let layout: UnsafePointer<UCKeyboardLayout> = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

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

    private func constructCommandWithCommandKey(_ commandKey: String, handler: @escaping HotKeyHandler) {
        userConfiguration.constructCommand(for: self, commandKey: commandKey, handler: handler)
    }

    private func carbonModifiersFromModifiers(_ modifiers: UInt) -> UInt32 {
        var carbonModifiers: UInt32 = 0

        if (modifiers & UInt(NSEvent.ModifierFlags.shift.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(shiftKey)
        }

        if (modifiers & UInt(NSEvent.ModifierFlags.command.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(cmdKey)
        }

        if (modifiers & UInt(NSEvent.ModifierFlags.option.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(optionKey)
        }

        if (modifiers & UInt(NSEvent.ModifierFlags.control.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(controlKey)
        }

        return carbonModifiers
    }

    static func hotKeyNameToDefaultsKey() -> [[String]] {
        var hotKeyNameToDefaultsKey: [[String]] = []

        hotKeyNameToDefaultsKey.append(["Cycle layout forward", CommandKey.cycleLayoutForward.rawValue])
        hotKeyNameToDefaultsKey.append(["Cycle layout backwards", CommandKey.cycleLayoutBackward.rawValue])
        hotKeyNameToDefaultsKey.append(["Shrink main pane", CommandKey.shrinkMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Expand main pane", CommandKey.expandMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Increase main pane count", CommandKey.increaseMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Decrease main pane count", CommandKey.decreaseMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Move focus counter clockwise", CommandKey.focusCCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Move focus clockwise", CommandKey.focusCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window to counter clockwise screen", CommandKey.swapScreenCCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window to clockwise screen", CommandKey.swapScreenCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window counter clockwise", CommandKey.swapCCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window clockwise", CommandKey.swapCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window with main window", CommandKey.swapMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Force windows to be reevaluated", CommandKey.reevaluateWindows.rawValue])
        hotKeyNameToDefaultsKey.append(["Throw focused window to space left", CommandKey.throwSpaceLeft.rawValue])
        hotKeyNameToDefaultsKey.append(["Throw focused window to space right", CommandKey.throwSpaceRight.rawValue])

        (1...10).forEach { spaceNumber in
            let name = "Throw focused window to space \(spaceNumber)"

            hotKeyNameToDefaultsKey.append([name, "\(CommandKey.throwSpacePrefix.rawValue)-\(spaceNumber)"])
        }

        (1...4).forEach { screenNumber in
            let focusCommandName = "Focus screen \(screenNumber)"
            let throwCommandName = "Throw focused window to screen \(screenNumber)"
            let focusCommandKey = "\(CommandKey.focusScreenPrefix.rawValue)-\(screenNumber)"
            let throwCommandKey = "\(CommandKey.throwScreenPrefix.rawValue)-\(screenNumber)"

            hotKeyNameToDefaultsKey.append([focusCommandName, focusCommandKey])
            hotKeyNameToDefaultsKey.append([throwCommandName, throwCommandKey])
        }

        hotKeyNameToDefaultsKey.append(["Toggle float for focused window", CommandKey.toggleFloat.rawValue])
        hotKeyNameToDefaultsKey.append(["Display current layout", CommandKey.displayCurrentLayout.rawValue])
        hotKeyNameToDefaultsKey.append(["Toggle global tiling", CommandKey.toggleTiling.rawValue])

        for layoutString in LayoutManager.availableLayoutStrings() {
            let commandName = "Select \(layoutString) layout"
            let commandKey = "select-\(layoutString)-layout"
            hotKeyNameToDefaultsKey.append([commandName, commandKey])
        }

        return hotKeyNameToDefaultsKey
    }
}
