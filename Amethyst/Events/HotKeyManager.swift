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

open class HotKey: NSObject {
    open let hotKeyRef: EventHotKeyRef
    open let handler: () -> Void

    public init(hotKeyRef: EventHotKeyRef, handler: @escaping () -> Void) {
        self.hotKeyRef = hotKeyRef
        self.handler = handler
    }
}

public typealias HotKeyHandler = () -> Void

open class HotKeyManager: NSObject {
    fileprivate let userConfiguration: UserConfiguration

    open lazy var stringToKeyCodes: [String: [AMKeyCode]] = {
        return self.constructKeyCodeMap()
    }()

    public init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        super.init()
        _ = constructKeyCodeMap()
        MASShortcutValidator.shared().allowAnyShortcutWithOptionModifier = true
    }

    fileprivate static func keyCodeForNumber(_ number: NSNumber) -> AMKeyCode {
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

    open func setUpWithHotKeyManager(_ windowManager: WindowManager, configuration: UserConfiguration) {
        constructCommandWithCommandKey(CommandKey.cycleLayoutForward.rawValue) {
            windowManager.focusedScreenManager()?.cycleLayoutForward()
        }

        constructCommandWithCommandKey(CommandKey.cycleLayoutBackward.rawValue) {
            windowManager.focusedScreenManager()?.cycleLayoutBackward()
        }

        constructCommandWithCommandKey(CommandKey.shrinkMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout { layout in
                layout.shrinkMainPane()
            }
        }

        constructCommandWithCommandKey(CommandKey.expandMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout { layout in
                layout.expandMainPane()
            }
        }

        constructCommandWithCommandKey(CommandKey.increaseMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout { layout in
                layout.increaseMainPaneCount()
            }
        }

        constructCommandWithCommandKey(CommandKey.decreaseMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout { layout in
                layout.decreaseMainPaneCount()
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
                windowManager.focusScreenAtIndex(screenNumber - 1)
            }

            self.constructCommandWithCommandKey(throwCommandKey) {
                windowManager.throwToScreenAtIndex(screenNumber - 1)
            }
        }

        (1..<10).forEach { spaceNumber in
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

        let layoutStrings: [String] = userConfiguration.layoutStrings()
        layoutStrings.forEach { layoutString in
            guard let layoutClass = LayoutManager.layoutClassForString(layoutString) else {
                return
            }

            self.constructCommandWithCommandKey(UserConfiguration.constructLayoutKeyString(layoutString)) {
                windowManager.focusedScreenManager()?.selectLayout(layoutClass)
            }
        }
    }

    open func constructKeyCodeMap() -> [String: [AMKeyCode]] {
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

    internal func constructCommandWithCommandKey(_ commandKey: String, handler: @escaping HotKeyHandler) {
        userConfiguration.constructCommandWithHotKeyRegistrar(self, commandKey: commandKey, handler: handler)
    }

    fileprivate func carbonModifiersFromModifiers(_ modifiers: UInt) -> UInt32 {
        var carbonModifiers: UInt32 = 0

        if (modifiers & UInt(NSEventModifierFlags.shift.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(shiftKey)
        }

        if (modifiers & UInt(NSEventModifierFlags.command.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(cmdKey)
        }

        if (modifiers & UInt(NSEventModifierFlags.option.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(optionKey)
        }

        if (modifiers & UInt(NSEventModifierFlags.control.rawValue)) > 0 {
            carbonModifiers = carbonModifiers | UInt32(controlKey)
        }

        return carbonModifiers
    }

    open static func hotKeyNameToDefaultsKey() -> [[String]] {
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

        (1..<10).forEach { spaceNumber in
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
