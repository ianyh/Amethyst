//
//  UserConfiguration.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import SwiftyJSON

public protocol ConfigurationStorage {
    func objectForKey(defaultName: String) -> AnyObject?
    func arrayForKey(defaultName: String) -> [AnyObject]?
    func boolForKey(defaultName: String) -> Bool
    func floatForKey(defaultName: String) -> Float
    func stringArrayForKey(defaultName: String) -> [String]?

    func setObject(value: AnyObject?, forKey defaultName: String)
    func setBool(value: Bool, forKey defaultName: String)
}

extension NSUserDefaults: ConfigurationStorage {}

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
    case NewWindowsToMain = "new-windows-to-main"
    case SendCrashReports = "send-crash-reports"

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
            .WindowMarginSize,
            .SendCrashReports
        ]
    }
}

public enum CommandKey: String {
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
    case ThrowSpaceLeft = "throw-space-left"
    case ThrowSpaceRight = "throw-space-right"
    case ToggleFloat = "toggle-float"
    case DisplayCurrentLayout = "display-current-layout"
    case ToggleTiling = "toggle-tiling"
    case ReevaluateWindows = "reevaluate-windows"
    case ToggleFocusFollowsMouse = "toggle-focus-follows-mouse"
}

public class UserConfiguration: NSObject {
    public static let sharedConfiguration = UserConfiguration()
    internal var storage: ConfigurationStorage

    public var tilingEnabled = true

    internal var configuration: JSON?
    internal var defaultConfiguration: JSON?

    internal var modifier1: AMModifierFlags?
    internal var modifier2: AMModifierFlags?
    internal var screens: Int?

    public init(storage: ConfigurationStorage) {
        self.storage = storage
    }

    public override convenience init() {
        self.init(storage: NSUserDefaults.standardUserDefaults())
    }

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
                LogManager.log?.warning("Unrecognized modifier string: \(modifierString)")
            }
        }
        return flags
    }

    public func load() {
        loadConfigurationFile()
        loadConfiguration()
    }

    internal func loadConfiguration() {
        for key in ConfigurationKey.defaultsKeys {
            let value = configuration?[key.rawValue]
            let defaultValue = defaultConfiguration?[key.rawValue]
            let existingValue = storage.objectForKey(key.rawValue)

            let hasLocalConfigurationValue = (value != nil && value?.error == nil)
            let hasDefaultConfigurationValue = (defaultValue != nil && defaultValue?.error == nil)
            let hasExistingValue = (existingValue != nil)

            guard hasLocalConfigurationValue || (hasDefaultConfigurationValue && !hasExistingValue) else {
                continue
            }

            storage.setObject(hasLocalConfigurationValue ? value?.object : defaultValue?.object, forKey: key.rawValue)
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
                LogManager.log?.error("error loading configuration")

                let alert = NSAlert()
                alert.alertStyle = .CriticalAlertStyle
                alert.messageText = "Error loading configuration"
                alert.runModal()
            }
        }

        defaultConfiguration = jsonForConfigAtPath(defaultAmethystConfigPath ?? "")
        if defaultConfiguration == nil {
            LogManager.log?.error("error loading default configuration")

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

    public static func constructLayoutKeyString(layoutString: String) -> String {
        return "select-\(layoutString)-layout"
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

        guard let commandInfo = command else {
            LogManager.log?.warning("Unrecognized command key: command")
            return
        }

        let commandKeyString = commandInfo[ConfigurationKey.CommandKey.rawValue]!
        let commandModifierString = commandInfo[ConfigurationKey.CommandMod.rawValue]!
        var commandFlags: AMModifierFlags?

        switch commandModifierString {
        case "mod1":
            commandFlags = modifier1
        case "mod2":
            commandFlags = modifier2
        default:
            LogManager.log?.warning("Unknown modifier string: \(commandModifierString)")
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
            LogManager.log?.warning("Unknown modifier string: \(modifierString)")
            return modifier1!
        }
    }

    public func layoutStrings() -> [String] {
        let layoutStrings = storage.arrayForKey(ConfigurationKey.Layouts.rawValue) as? [String]
        return layoutStrings ?? []
    }

    public func setLayoutStrings(layoutStrings: [String]) {
        storage.setObject(layoutStrings, forKey: ConfigurationKey.Layouts.rawValue)
    }

    public func runningApplicationShouldFloat(runningApplication: BundleIdentifiable) -> Bool {
        guard let floatingBundleIdentifiers = storage.objectForKey(ConfigurationKey.FloatingBundleIdentifiers.rawValue) as? [String] else {
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
        return storage.boolForKey(ConfigurationKey.IgnoreMenuBar.rawValue)
    }

    public func floatSmallWindows() -> Bool {
        return storage.boolForKey(ConfigurationKey.FloatSmallWindows.rawValue)
    }

    public func mouseFollowsFocus() -> Bool {
        return storage.boolForKey(ConfigurationKey.MouseFollowsFocus.rawValue)
    }

    public func focusFollowsMouse() -> Bool {
        return storage.boolForKey(ConfigurationKey.FocusFollowsMouse.rawValue)
    }

    public func toggleFocusFollowsMouse() {
        storage.setBool(!focusFollowsMouse(), forKey: ConfigurationKey.FocusFollowsMouse.rawValue)
    }

    public func enablesLayoutHUD() -> Bool {
        return storage.boolForKey(ConfigurationKey.LayoutHUD.rawValue)
    }

    public func enablesLayoutHUDOnSpaceChange() -> Bool {
        return storage.boolForKey(ConfigurationKey.LayoutHUDOnSpaceChange.rawValue)
    }

    public func useCanaryBuild() -> Bool {
        return storage.boolForKey(ConfigurationKey.UseCanaryBuild.rawValue)
    }

    public func windowMarginSize() -> CGFloat {
        return CGFloat(storage.floatForKey(ConfigurationKey.WindowMarginSize.rawValue))
    }

    public func windowMargins() -> Bool {
        return storage.boolForKey(ConfigurationKey.WindowMargins.rawValue)
    }

    public func floatingBundleIdentifiers() -> [String] {
        let floatingBundleIdentifiers = storage.stringArrayForKey(ConfigurationKey.FloatingBundleIdentifiers.rawValue)
        return floatingBundleIdentifiers ?? []
    }

    public func setFloatingBundleIdentifiers(floatingBundleIdentifiers: [String]) {
        storage.setObject(floatingBundleIdentifiers, forKey: ConfigurationKey.FloatingBundleIdentifiers.rawValue)
    }

    public func sendNewWindowsToMainPane() -> Bool {
        return storage.boolForKey(ConfigurationKey.NewWindowsToMain.rawValue)
    }

    public func shouldSendCrashReports() -> Bool {
        return storage.boolForKey(ConfigurationKey.SendCrashReports.rawValue)
    }
}
