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
    func object(forKey defaultName: String) -> Any?
    func array(forKey defaultName: String) -> [Any]?
    func bool(forKey defaultName: String) -> Bool
    func float(forKey defaultName: String) -> Float
    func stringArray(forKey defaultName: String) -> [String]?

    func set(_ value: Any?, forKey defaultName: String)
    func set(_ value: Bool, forKey defaultName: String)
}

extension UserDefaults: ConfigurationStorage {}

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
    case AnimateWindows = "animate-windows"
    case LayoutHUD = "enables-layout-hud"
    case LayoutHUDOnSpaceChange = "enables-layout-hud-on-space-change"
    case UseCanaryBuild = "use-canary-build"
    case NewWindowsToMain = "new-windows-to-main"
    case SendCrashReports = "send-crash-reports"
    case WindowResizeStep = "window-resize-step"

    static var defaultsKeys: [ConfigurationKey] {
        return [
            .Layouts,
            .FloatingBundleIdentifiers,
            .IgnoreMenuBar,
            .FloatSmallWindows,
            .MouseFollowsFocus,
            .FocusFollowsMouse,
            .AnimateWindows,
            .LayoutHUD,
            .LayoutHUDOnSpaceChange,
            .UseCanaryBuild,
            .WindowMargins,
            .WindowMarginSize,
            .SendCrashReports,
            .WindowResizeStep
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
    case ToggleAnimateWindows = "toggle-animate-windows"
    case ThrowScreenPrefix = "throw-screen"
    case ThrowSpaceLeft = "throw-space-left"
    case ThrowSpaceRight = "throw-space-right"
    case ToggleFloat = "toggle-float"
    case DisplayCurrentLayout = "display-current-layout"
    case ToggleTiling = "toggle-tiling"
    case ReevaluateWindows = "reevaluate-windows"
    case ToggleFocusFollowsMouse = "toggle-focus-follows-mouse"
}

public protocol UserConfigurationDelegate: class {
    func configurationGlobalTilingDidChange(_ userConfiguration: UserConfiguration)
}

public class UserConfiguration: NSObject {
    public static let shared = UserConfiguration()
    internal var storage: ConfigurationStorage

    public weak var delegate: UserConfigurationDelegate?

    public var tilingEnabled = true {
        didSet {
            delegate?.configurationGlobalTilingDidChange(self)
        }
    }

    internal var configuration: JSON?
    internal var defaultConfiguration: JSON?

    internal var modifier1: AMModifierFlags?
    internal var modifier2: AMModifierFlags?
    internal var screens: Int?

    public init(storage: ConfigurationStorage) {
        self.storage = storage
    }

    public override convenience init() {
        self.init(storage: UserDefaults.standard)
    }

    fileprivate func configurationValueForKey<T>(_ key: ConfigurationKey) -> T? {
        guard let configurationValue = configuration?[key.rawValue].rawValue as? T else {
            return defaultConfiguration![key.rawValue].object as? T
        }

        return configurationValue
    }

    internal func modifierFlagsForStrings(_ modifierStrings: [String]) -> AMModifierFlags {
        var flags: UInt = 0
        for modifierString in modifierStrings {
            switch modifierString {
            case "option":
                flags = flags | NSEventModifierFlags.option.rawValue
            case "shift":
                flags = flags | NSEventModifierFlags.shift.rawValue
            case "control":
                flags = flags | NSEventModifierFlags.control.rawValue
            case "command":
                flags = flags | NSEventModifierFlags.command.rawValue
            default:
                LogManager.log?.warning("Unrecognized modifier string: \(modifierString)")
            }
        }
        return flags
    }

    open func load() {
        loadConfigurationFile()
        loadConfiguration()
    }

    internal func loadConfiguration() {
        for key in ConfigurationKey.defaultsKeys {
            let value = configuration?[key.rawValue]
            let defaultValue = defaultConfiguration?[key.rawValue]
            let existingValue = storage.object(forKey: key.rawValue)

            let hasLocalConfigurationValue = (value != nil && value?.error == nil)
            let hasDefaultConfigurationValue = (defaultValue != nil && defaultValue?.error == nil)
            let hasExistingValue = (existingValue != nil)

            guard hasLocalConfigurationValue || (hasDefaultConfigurationValue && !hasExistingValue) else {
                continue
            }

            storage.set(hasLocalConfigurationValue ? value?.object : defaultValue?.object as Any?, forKey: key.rawValue)
        }
    }

    internal func jsonForConfig(at path: String) -> JSON? {
        guard FileManager.default.fileExists(atPath: path, isDirectory: nil) else {
            return nil
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }

        return JSON(data: data)
    }

    internal func loadConfigurationFile() {
        let amethystConfigPath = NSHomeDirectory() + "/.amethyst"
        let defaultAmethystConfigPath = Bundle.main.path(forResource: "default", ofType: "amethyst")

        if FileManager.default.fileExists(atPath: amethystConfigPath, isDirectory: nil) {
            configuration = jsonForConfig(at: amethystConfigPath)

            if configuration == nil {
                LogManager.log?.error("error loading configuration")

                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Error loading configuration"
                alert.runModal()
            }
        }

        defaultConfiguration = jsonForConfig(at: defaultAmethystConfigPath ?? "")
        if defaultConfiguration == nil {
            LogManager.log?.error("error loading default configuration")

            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Error loading default configuration"
            alert.runModal()
        }

        let mod1Strings: [String] = configurationValueForKey(.Mod1)!
        let mod2Strings: [String] = configurationValueForKey(.Mod2)!

        modifier1 = modifierFlagsForStrings(mod1Strings)
        modifier2 = modifierFlagsForStrings(mod2Strings)
        let screens: NSNumber = configurationValueForKey(.Screens)!
        self.screens = screens.intValue
    }

    open static func constructLayoutKeyString(_ layoutString: String) -> String {
        return "select-\(layoutString)-layout"
    }

    internal func constructCommandWithHotKeyRegistrar(_ hotKeyRegistrar: HotKeyRegistrar, commandKey: String, handler: @escaping HotKeyHandler) {
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

        hotKeyRegistrar.registerHotKey(
            with: commandKeyString,
            modifiers: commandFlags!,
            handler: handler,
            defaultsKey: commandKey,
            override: override
        )
    }

    open func hasCustomConfiguration() -> Bool {
        return configuration != nil
    }

    fileprivate func modifierFlagsForModifierString(_ modifierString: String) -> AMModifierFlags {
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

    open func layoutStrings() -> [String] {
        let layoutStrings = storage.array(forKey: ConfigurationKey.Layouts.rawValue) as? [String]
        return layoutStrings ?? []
    }

    open func setLayoutStrings(_ layoutStrings: [String]) {
        storage.set(layoutStrings as Any?, forKey: ConfigurationKey.Layouts.rawValue)
    }

    open func runningApplicationShouldFloat(_ runningApplication: BundleIdentifiable) -> Bool {
        guard let floatingBundleIdentifiers = storage.object(forKey: ConfigurationKey.FloatingBundleIdentifiers.rawValue) as? [String] else {
            return false
        }

        for floatingBundleIdentifier in floatingBundleIdentifiers {
            if floatingBundleIdentifier.contains("*") {
                let sanitizedIdentifier = floatingBundleIdentifier.replacingOccurrences(of: "*", with: "")
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

    open func ignoreMenuBar() -> Bool {
        return storage.bool(forKey: ConfigurationKey.IgnoreMenuBar.rawValue)
    }

    open func floatSmallWindows() -> Bool {
        return storage.bool(forKey: ConfigurationKey.FloatSmallWindows.rawValue)
    }

    open func mouseFollowsFocus() -> Bool {
        return storage.bool(forKey: ConfigurationKey.MouseFollowsFocus.rawValue)
    }

    open func focusFollowsMouse() -> Bool {
        return storage.bool(forKey: ConfigurationKey.FocusFollowsMouse.rawValue)
    }

    open func toggleFocusFollowsMouse() {
        storage.set(!focusFollowsMouse(), forKey: ConfigurationKey.FocusFollowsMouse.rawValue)
    }

    open func animateWindows() -> Bool {
        return storage.bool(forKey: ConfigurationKey.AnimateWindows.rawValue)
    }

    open func toggleAnimateWindows() {
        storage.set(!animateWindows(), forKey: ConfigurationKey.AnimateWindows.rawValue)
    }

    open func enablesLayoutHUD() -> Bool {
        return storage.bool(forKey: ConfigurationKey.LayoutHUD.rawValue)
    }

    open func enablesLayoutHUDOnSpaceChange() -> Bool {
        return storage.bool(forKey: ConfigurationKey.LayoutHUDOnSpaceChange.rawValue)
    }

    open func useCanaryBuild() -> Bool {
        return storage.bool(forKey: ConfigurationKey.UseCanaryBuild.rawValue)
    }

    open func windowMarginSize() -> CGFloat {
        return CGFloat(storage.float(forKey: ConfigurationKey.WindowMarginSize.rawValue))
    }

    open func windowMargins() -> Bool {
        return storage.bool(forKey: ConfigurationKey.WindowMargins.rawValue)
    }

    open func windowResizeStep() -> CGFloat {
        return CGFloat(storage.float(forKey: ConfigurationKey.WindowResizeStep.rawValue) / 100.0)
    }

    open func floatingBundleIdentifiers() -> [String] {
        let floatingBundleIdentifiers = storage.stringArray(forKey: ConfigurationKey.FloatingBundleIdentifiers.rawValue)
        return floatingBundleIdentifiers ?? []
    }

    open func setFloatingBundleIdentifiers(_ floatingBundleIdentifiers: [String]) {
        storage.set(floatingBundleIdentifiers as Any?, forKey: ConfigurationKey.FloatingBundleIdentifiers.rawValue)
    }

    open func sendNewWindowsToMainPane() -> Bool {
        return storage.bool(forKey: ConfigurationKey.NewWindowsToMain.rawValue)
    }

    open func shouldSendCrashReports() -> Bool {
        return storage.bool(forKey: ConfigurationKey.SendCrashReports.rawValue)
    }
}
