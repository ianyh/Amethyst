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
    case layouts = "layouts"
    case commandMod = "mod"
    case commandKey = "key"
    case mod1 = "mod1"
    case mod2 = "mod2"
    case windowMargins = "window-margins"
    case windowMarginSize = "window-margin-size"
    case floatingBundleIdentifiers = "floating"
    case ignoreMenuBar = "ignore-menu-bar"
    case floatSmallWindows = "float-small-windows"
    case mouseFollowsFocus = "mouse-follows-focus"
    case focusFollowsMouse = "focus-follows-mouse"
    case layoutHUD = "enables-layout-hud"
    case layoutHUDOnSpaceChange = "enables-layout-hud-on-space-change"
    case useCanaryBuild = "use-canary-build"
    case newWindowsToMain = "new-windows-to-main"
    case sendCrashReports = "send-crash-reports"
    case windowResizeStep = "window-resize-step"

    static var defaultsKeys: [ConfigurationKey] {
        return [
            .layouts,
            .floatingBundleIdentifiers,
            .ignoreMenuBar,
            .floatSmallWindows,
            .mouseFollowsFocus,
            .focusFollowsMouse,
            .layoutHUD,
            .layoutHUDOnSpaceChange,
            .useCanaryBuild,
            .windowMargins,
            .windowMarginSize,
            .sendCrashReports,
            .windowResizeStep
        ]
    }
}

public enum CommandKey: String {
    case cycleLayoutForward = "cycle-layout"
    case cycleLayoutBackward = "cycle-layout-backward"
    case shrinkMain = "shrink-main"
    case expandMain = "expand-main"
    case increaseMain = "increase-main"
    case decreaseMain = "decrease-main"
    case focusCCW = "focus-ccw"
    case focusCW = "focus-cw"
    case swapScreenCCW = "swap-screen-ccw"
    case swapScreenCW = "swap-screen-cw"
    case swapCCW = "swap-ccw"
    case swapCW = "swap-cw"
    case swapMain = "swap-main"
    case throwSpacePrefix = "throw-space"
    case focusScreenPrefix = "focus-screen"
    case throwScreenPrefix = "throw-screen"
    case throwSpaceLeft = "throw-space-left"
    case throwSpaceRight = "throw-space-right"
    case toggleFloat = "toggle-float"
    case displayCurrentLayout = "display-current-layout"
    case toggleTiling = "toggle-tiling"
    case reevaluateWindows = "reevaluate-windows"
    case toggleFocusFollowsMouse = "toggle-focus-follows-mouse"
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

    public init(storage: ConfigurationStorage) {
        self.storage = storage
    }

    public override convenience init() {
        self.init(storage: UserDefaults.standard)
    }

    fileprivate func configurationValueForKey<T>(_ key: ConfigurationKey) -> T? {
        guard let exists = configuration?[key.rawValue].exists(), exists else {
            return defaultConfiguration![key.rawValue].object as? T
        }

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

        let mod1Strings: [String] = configurationValueForKey(.mod1)!
        let mod2Strings: [String] = configurationValueForKey(.mod2)!

        modifier1 = modifierFlagsForStrings(mod1Strings)
        modifier2 = modifierFlagsForStrings(mod2Strings)
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
            if configuration?[ConfigurationKey.mod1.rawValue] != nil || configuration?[ConfigurationKey.mod2.rawValue] != nil {
                override = true
            }
            command = defaultConfiguration?[commandKey].object as? [String: String]
        }

        guard let commandInfo = command else {
            LogManager.log?.warning("Unrecognized command key: command")
            return
        }

        guard let commandKeyString = commandInfo[ConfigurationKey.commandKey.rawValue] else {
            LogManager.log?.warning("No keys specified for command: \(commandKey)")
            return
        }

        guard let commandModifierString = commandInfo[ConfigurationKey.commandMod.rawValue] else {
            LogManager.log?.warning("No mod specified for command: \(commandKey)")
            return
        }

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
        let layoutStrings = storage.array(forKey: ConfigurationKey.layouts.rawValue) as? [String]
        return layoutStrings ?? []
    }

    open func setLayoutStrings(_ layoutStrings: [String]) {
        storage.set(layoutStrings as Any?, forKey: ConfigurationKey.layouts.rawValue)
    }

    open func runningApplicationShouldFloat(_ runningApplication: BundleIdentifiable) -> Bool {
        guard let floatingBundleIdentifiers = storage.object(forKey: ConfigurationKey.floatingBundleIdentifiers.rawValue) as? [String] else {
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
        return storage.bool(forKey: ConfigurationKey.ignoreMenuBar.rawValue)
    }

    open func floatSmallWindows() -> Bool {
        return storage.bool(forKey: ConfigurationKey.floatSmallWindows.rawValue)
    }

    open func mouseFollowsFocus() -> Bool {
        return storage.bool(forKey: ConfigurationKey.mouseFollowsFocus.rawValue)
    }

    open func focusFollowsMouse() -> Bool {
        return storage.bool(forKey: ConfigurationKey.focusFollowsMouse.rawValue)
    }

    open func toggleFocusFollowsMouse() {
        storage.set(!focusFollowsMouse(), forKey: ConfigurationKey.focusFollowsMouse.rawValue)
    }

    open func enablesLayoutHUD() -> Bool {
        return storage.bool(forKey: ConfigurationKey.layoutHUD.rawValue)
    }

    open func enablesLayoutHUDOnSpaceChange() -> Bool {
        return storage.bool(forKey: ConfigurationKey.layoutHUDOnSpaceChange.rawValue)
    }

    open func useCanaryBuild() -> Bool {
        return storage.bool(forKey: ConfigurationKey.useCanaryBuild.rawValue)
    }

    open func windowMarginSize() -> CGFloat {
        return CGFloat(storage.float(forKey: ConfigurationKey.windowMarginSize.rawValue))
    }

    open func windowMargins() -> Bool {
        return storage.bool(forKey: ConfigurationKey.windowMargins.rawValue)
    }

    open func windowResizeStep() -> CGFloat {
        return CGFloat(storage.float(forKey: ConfigurationKey.windowResizeStep.rawValue) / 100.0)
    }

    open func floatingBundleIdentifiers() -> [String] {
        let floatingBundleIdentifiers = storage.stringArray(forKey: ConfigurationKey.floatingBundleIdentifiers.rawValue)
        return floatingBundleIdentifiers ?? []
    }

    open func setFloatingBundleIdentifiers(_ floatingBundleIdentifiers: [String]) {
        storage.set(floatingBundleIdentifiers as Any?, forKey: ConfigurationKey.floatingBundleIdentifiers.rawValue)
    }

    open func sendNewWindowsToMainPane() -> Bool {
        return storage.bool(forKey: ConfigurationKey.newWindowsToMain.rawValue)
    }

    open func shouldSendCrashReports() -> Bool {
        return storage.bool(forKey: ConfigurationKey.sendCrashReports.rawValue)
    }
}
