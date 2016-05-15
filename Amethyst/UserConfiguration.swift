//
//  UserConfiguration.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import SwiftyJSON

internal enum ConfigurationKey: String {
    case Layouts = "layouts"
    case CommandMod = "mod"
    case CommandKey = "key"
    case Mod1 = "mod1"
    case Mod2 = "mod2"
    case Screens = "screens"
    case WindowMargins = "window-margins"
    case WindowMarginSize = "window-margin-size"
    case FloatingBundleIdentifiers = "floating"
    case IgnoreMenuBar = "ignore-menu-bar"
    case FloatSmallWindows = "float-small-windows"
    case MouseFollowsFocus = "mouse-follows-focus"
    case FocusFollowsMouse = "focus-follows-mouse"
    case LayoutHUD = "enables-layout-hud"
    case LayoutHUDOnSpaceChange = "enables-layout-hud-on-space-change"
    case UseCanaryBuild = "use-canary-build"

    static var defaultsKeys: [ConfigurationKey] {
        return [
            .Layouts,
            .FloatingBundleIdentifiers,
            .IgnoreMenuBar,
            .FloatSmallWindows,
            .MouseFollowsFocus,
            .FocusFollowsMouse,
            .LayoutHUD,
            .LayoutHUDOnSpaceChange,
            .UseCanaryBuild,
            .WindowMargins,
            .WindowMarginSize
        ]
    }
}

internal enum CommandKey: String {
    case CycleLayoutForward = "cycle-layout"
    case CycleLayoutBackward = "cycle-layout-backward"
    case ShrinkMain = "shrink-main"
    case ExpandMain = "expand-main"
    case IncreaseMain = "increase-main"
    case DecreaseMain = "decrease-main"
    case FocusCCW = "focus-ccw"
    case FocusCW = "focus-cw"
    case SwapScreenCCW = "swap-screen-ccw"
    case SwapScreenCW = "swap-screen-cw"
    case SwapCCW = "swap-ccw"
    case SwapCW = "swap-cw"
    case SwapMain = "swap-main"
    case ThrowSpacePrefix = "throw-space"
    case FocusScreenPrefix = "focus-screen"
    case ThrowScreenPrefix = "throw-screen"
    case ToggleFloat = "toggle-float"
    case DisplayCurrentLayout = "display-current-layout"
    case ToggleTiling = "toggle-tiling"
}

public class UserConfiguration: NSObject {
    public typealias HotKeyHandler = () -> ()

    public static let sharedConfiguration = UserConfiguration()

    public var tilingEnabled = true

    internal var configuration: JSON?
    internal var defaultConfiguration: JSON?

    internal var modifier1: AMModifierFlags?
    internal var modifier2: AMModifierFlags?
    internal var screens: Int?

    private func configurationValueForKey<T>(key: ConfigurationKey) -> T? {
        guard let configurationValue = configuration?[key.rawValue].rawValue as? T else {
            return defaultConfiguration![key.rawValue].object as? T
        }

        return configurationValue
    }

    internal func modifierFlagsForStrings(modifierStrings: [String]) -> AMModifierFlags {
        var flags: UInt = 0
        for modifierString in modifierStrings {
            switch modifierString {
            case "option":
                flags = flags | NSEventModifierFlags.AlternateKeyMask.rawValue
            case "shift":
                flags = flags | NSEventModifierFlags.ShiftKeyMask.rawValue
            case "control":
                flags = flags | NSEventModifierFlags.ControlKeyMask.rawValue
            case "command":
                flags = flags | NSEventModifierFlags.CommandKeyMask.rawValue
            default:
                print("Unrecognized modifier string: \(modifierString)")
            }
        }
        return flags
    }

    private static func layoutClassForString(layoutString: String) -> Layout.Type? {
        switch layoutString {
        case "tall":
            return TallLayout.self
        case "tall-right":
            return TallRightLayout.self
        case "wide":
            return WideLayout.self
        case "middle-wide":
            return MiddleWideLayout.self
        case "fullscreen":
            return FullscreenLayout.self
        case "column":
            return ColumnLayout.self
        case "row":
            return RowLayout.self
        case "floating":
            return FloatingLayout.self
        case "widescreen-tall":
            return WidescreenTallLayout.self
        default:
            return nil
        }
    }

    private static func stringForLayoutClass(layoutClass: Layout.Type) -> String {
        return layoutClass.layoutKey
    }

    public func loadConfiguration() {
        loadConfigurationFile()

        let userDefaults = NSUserDefaults.standardUserDefaults()
        for key in ConfigurationKey.defaultsKeys {
            let value = configuration?[key.rawValue]
            let defaultValue = defaultConfiguration?[key.rawValue]
            let existingValue = userDefaults.objectForKey(key.rawValue)

            guard value?.error == nil || (defaultValue?.error == nil && existingValue == nil) else {
                continue
            }

            userDefaults.setObject(value?.error == nil ? value?.object : defaultValue?.object, forKey: key.rawValue)
        }
    }

    internal func jsonForConfigAtPath(path: String) -> JSON? {
        guard NSFileManager.defaultManager().fileExistsAtPath(path, isDirectory: nil) else {
            return nil
        }

        guard let data = NSData(contentsOfFile: path) else {
            return nil
        }

        return JSON(data: data)
    }

    internal func loadConfigurationFile() {
        let amethystConfigPath = NSHomeDirectory().stringByAppendingString("/.amethyst")
        let defaultAmethystConfigPath = NSBundle.mainBundle().pathForResource("default", ofType: "amethyst")

        if NSFileManager.defaultManager().fileExistsAtPath(amethystConfigPath, isDirectory: nil) {
            configuration = jsonForConfigAtPath(amethystConfigPath)

            if configuration == nil {
                print("error loading configuration")

                let alert = NSAlert()
                alert.alertStyle = .CriticalAlertStyle
                alert.messageText = "Error loading configuration"
                alert.runModal()
            }
        }

        defaultConfiguration = jsonForConfigAtPath(defaultAmethystConfigPath ?? "")
        if defaultConfiguration == nil {
            print("error loading default configuration")

            let alert = NSAlert()
            alert.alertStyle = .CriticalAlertStyle
            alert.messageText = "Error loading default configuration"
            alert.runModal()
        }

        let mod1Strings: [String] = configurationValueForKey(.Mod1)!
        let mod2Strings: [String] = configurationValueForKey(.Mod2)!

        modifier1 = modifierFlagsForStrings(mod1Strings)
        modifier2 = modifierFlagsForStrings(mod2Strings)
        let screens: NSNumber = configurationValueForKey(.Screens)!
        self.screens = screens.integerValue
    }

    private func constructLayoutKeyString(layoutString: String) -> String {
        return "select-\(layoutString)-layout"
    }

    public func hasCustomConfiguration() -> Bool {
        return configuration != nil
    }

    private func modifierFlagsForModifierString(modifierString: String) -> AMModifierFlags {
        switch modifierString {
        case "mod1":
            return modifier1!
        case "mod2":
            return modifier2!
        default:
            print("Unknown modifier string: \(modifierString)")
            return modifier1!
        }
    }

    internal func constructCommandWithHotKeyRegistrar(hotKeyRegistrar: HotKeyRegistrar, commandKey: String, handler: HotKeyHandler) {
        var override = false
        var command: [String: String]? = configuration?[commandKey].object as? [String: String]
        if command != nil {
            override = true
        } else {
            if configuration?[ConfigurationKey.Mod1.rawValue] != nil || configuration?[ConfigurationKey.Mod2.rawValue] != nil {
                override = true
            }
            command = defaultConfiguration?[commandKey].object as? [String: String]
        }

        let commandKeyString = command![ConfigurationKey.CommandKey.rawValue]!
        let commandModifierString = command![ConfigurationKey.CommandMod.rawValue]!
        var commandFlags: AMModifierFlags?

        switch commandModifierString {
        case "mod1":
            commandFlags = modifier1
        case "mod2":
            commandFlags = modifier2
        default:
            print("Unknown modifier string: \(commandModifierString)")
            return
        }

        hotKeyRegistrar.registerHotKeyWithKeyString(
            commandKeyString,
            modifiers: commandFlags!,
            handler: handler,
            defaultsKey: commandKey,
            override: override
        )
    }

    public func setUpWithHotKeyManager(hotKeyManager: HotKeyManager, windowManager: WindowManager) {
        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.CycleLayoutForward.rawValue) {
            windowManager.focusedScreenManager()?.cycleLayoutForward()
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.CycleLayoutBackward.rawValue) {
            windowManager.focusedScreenManager()?.cycleLayoutBackward()
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.ShrinkMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout() { layout in
                layout.shrinkMainPane()
            }
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.ExpandMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout() { layout in
                layout.expandMainPane()
            }
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.IncreaseMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout() { layout in
                layout.increaseMainPaneCount()
            }
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.DecreaseMain.rawValue) {
            windowManager.focusedScreenManager()?.updateCurrentLayout() { layout in
                layout.decreaseMainPaneCount()
            }
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.FocusCCW.rawValue) {
            windowManager.moveFocusCounterClockwise()
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.FocusCW.rawValue) {
            windowManager.moveFocusClockwise()
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.SwapScreenCCW.rawValue) {
            windowManager.swapFocusedWindowCounterClockwise()
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.SwapScreenCW.rawValue) {
            windowManager.swapFocusedWindowScreenClockwise()
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.SwapCCW.rawValue) {
            windowManager.swapFocusedWindowCounterClockwise()
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.SwapCW.rawValue) {
            windowManager.swapFocusedWindowClockwise()
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.SwapMain.rawValue) {
            windowManager.swapFocusedWindowToMain()
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.DisplayCurrentLayout.rawValue) {
            windowManager.displayCurrentLayout()
        }

        (1..<screens!).forEach { screenNumber in
            let focusCommandKey = "\(CommandKey.FocusScreenPrefix.rawValue)-\(screenNumber)"
            let throwCommandKey = "\(CommandKey.ThrowScreenPrefix.rawValue)-\(screenNumber)"

            self.constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: focusCommandKey) {
                windowManager.focusScreenAtIndex(screenNumber)
            }

            self.constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: throwCommandKey) {
                windowManager.throwToScreenAtIndex(screenNumber)
            }
        }

        (1..<10).forEach { spaceNumber in
            let commandKey = "\(CommandKey.ThrowSpacePrefix.rawValue)-\(spaceNumber)"

            self.constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: commandKey) {
                windowManager.pushFocusedWindowToSpace(UInt(spaceNumber))
            }
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.ToggleFloat.rawValue) {
            windowManager.toggleFloatForFocusedWindow()
        }

        constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: CommandKey.ToggleTiling.rawValue) {
            UserConfiguration.sharedConfiguration.tilingEnabled = !UserConfiguration.sharedConfiguration.tilingEnabled
            windowManager.markAllScreensForReflow()
        }

        let layoutStrings: [String] = configurationValueForKey(ConfigurationKey.Layouts)!
        layoutStrings.forEach { layoutString in
            guard let layoutClass = UserConfiguration.layoutClassForString(layoutString) else {
                return
            }

            self.constructCommandWithHotKeyRegistrar(hotKeyManager, commandKey: self.constructLayoutKeyString(layoutString)) {
                windowManager.focusedScreenManager()?.selectLayout(layoutClass)
            }
        }
    }

    public func layoutsWithWindowActivityCache(windowActivityCache: WindowActivityCache) -> [Layout] {
        let layoutStrings: [String] = configurationValueForKey(.Layouts)!
        let layouts = layoutStrings.map { layoutString -> Layout? in
            guard let layoutClass = UserConfiguration.layoutClassForString(layoutString) else {
                print("Unrecognized layout string \(layoutString)")
                return nil
            }

            return layoutClass.init(windowActivityCache: windowActivityCache)
        }

        return layouts.filter { $0 != nil }.map { $0! }
    }

    public func layoutStrings() -> [String] {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        let layoutStrings = userDefaults.arrayForKey(ConfigurationKey.Layouts.rawValue) as? [String]
        return layoutStrings ?? []
    }

    public func setLayoutStrings(layoutStrings: [String]) {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setObject(layoutStrings, forKey: ConfigurationKey.Layouts.rawValue)
    }

    public func availableLayoutStrings() -> [String] {
        let layoutClasses: [Layout.Type] = [
            TallLayout.self,
            TallRightLayout.self,
            WideLayout.self,
            MiddleWideLayout.self,
            FullscreenLayout.self,
            ColumnLayout.self,
            RowLayout.self,
            FloatingLayout.self,
            WidescreenTallLayout.self
        ]

        return layoutClasses.map { UserConfiguration.stringForLayoutClass($0) }
    }

    public func runningApplicationShouldFloat(runningApplication: BundleIdentifiable) -> Bool {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        guard let floatingBundleIdentifiers = userDefaults.objectForKey(ConfigurationKey.FloatingBundleIdentifiers.rawValue) as? [String] else {
            return false
        }

        for floatingBundleIdentifier in floatingBundleIdentifiers {
            if floatingBundleIdentifier.containsString("*") {
                let sanitizedIdentifier = floatingBundleIdentifier.stringByReplacingOccurrencesOfString("*", withString: "")
                if runningApplication.bundleIdentifier?.hasPrefix(sanitizedIdentifier) == true {
                    return true
                }
            } else {
                if floatingBundleIdentifier == runningApplication.bundleIdentifier {
                    return true
                }
            }
        }

        return false
    }

    public func ignoreMenuBar() -> Bool {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.boolForKey(ConfigurationKey.IgnoreMenuBar.rawValue)
    }

    public func floatSmallWindows() -> Bool {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.boolForKey(ConfigurationKey.FloatSmallWindows.rawValue)
    }

    public func mouseFollowsFocus() -> Bool {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.boolForKey(ConfigurationKey.MouseFollowsFocus.rawValue)
    }

    public func focusFollowsMouse() -> Bool {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.boolForKey(ConfigurationKey.FocusFollowsMouse.rawValue)
    }

    public func enablesLayoutHUD() -> Bool {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.boolForKey(ConfigurationKey.LayoutHUD.rawValue)
    }

    public func enablesLayoutHUDOnSpaceChange() -> Bool {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.boolForKey(ConfigurationKey.LayoutHUDOnSpaceChange.rawValue)
    }

    public func useCanaryBuild() -> Bool {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.boolForKey(ConfigurationKey.UseCanaryBuild.rawValue)
    }

    public func windowMarginSize() -> CGFloat {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return CGFloat(userDefaults.floatForKey(ConfigurationKey.WindowMarginSize.rawValue))
    }

    public func windowMargins() -> Bool {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.boolForKey(ConfigurationKey.WindowMargins.rawValue)
    }

    public func floatingBundleIdentifiers() -> [String] {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        let floatingBundleIdentifiers = userDefaults.stringArrayForKey(ConfigurationKey.FloatingBundleIdentifiers.rawValue)
        return floatingBundleIdentifiers ?? []
    }

    public func setFloatingBundleIdentifiers(floatingBundleIdentifiers: [String]) {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setObject(floatingBundleIdentifiers, forKey: ConfigurationKey.FloatingBundleIdentifiers.rawValue)
    }

    public func hotKeyNameToDefaultsKey() -> [[String]] {
        var hotKeyNameToDefaultsKey: [[String]] = []

        hotKeyNameToDefaultsKey.append(["Cycle layout forward", CommandKey.CycleLayoutForward.rawValue])
        hotKeyNameToDefaultsKey.append(["Cycle layout backwards", CommandKey.CycleLayoutBackward.rawValue])
        hotKeyNameToDefaultsKey.append(["Shrink main pane", CommandKey.ShrinkMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Expand main pane", CommandKey.ExpandMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Increase main pane count", CommandKey.IncreaseMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Decrease main pane count", CommandKey.DecreaseMain.rawValue])
        hotKeyNameToDefaultsKey.append(["Move focus counter clockwise", CommandKey.FocusCCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Move focus clockwise", CommandKey.FocusCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window to counter clockwise screen", CommandKey.SwapScreenCCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window to clockwise screen", CommandKey.SwapScreenCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window counter clockwise", CommandKey.SwapCCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window clockwise", CommandKey.SwapCW.rawValue])
        hotKeyNameToDefaultsKey.append(["Swap focused window with main window", CommandKey.SwapMain.rawValue])

        (1..<10).forEach { spaceNumber in
            let name = "Throw focused window to space \(spaceNumber)"
            hotKeyNameToDefaultsKey.append([name, "\(CommandKey.ThrowSpacePrefix.rawValue)-\(spaceNumber)"])
        }

        (1..<3).forEach { screenNumber in
            let focusCommandName = "Focus screen \(screenNumber)"
            let throwCommandName = "Throw focused window to screen \(screenNumber)"
            let focusCommandKey = "\(CommandKey.FocusScreenPrefix.rawValue)-\(screenNumber)"
            let throwCommandKey = "\(CommandKey.ThrowScreenPrefix.rawValue)-\(screenNumber)"

            hotKeyNameToDefaultsKey.append([focusCommandName, focusCommandKey])
            hotKeyNameToDefaultsKey.append([throwCommandName, throwCommandKey])
        }

        hotKeyNameToDefaultsKey.append(["Toggle float for focused window", CommandKey.ToggleFloat.rawValue])
        hotKeyNameToDefaultsKey.append(["Display current layout", CommandKey.DisplayCurrentLayout.rawValue])
        hotKeyNameToDefaultsKey.append(["Toggle global tiling", CommandKey.ToggleTiling.rawValue])

        for layoutString in availableLayoutStrings() {
            let commandName = "Select \(layoutString) layout"
            let commandKey = "select-\(layoutString)-layout"
            hotKeyNameToDefaultsKey.append([commandName, commandKey])
        }

        return hotKeyNameToDefaultsKey
    }
}
