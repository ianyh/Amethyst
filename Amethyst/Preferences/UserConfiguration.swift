//
//  UserConfiguration.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import SwiftyJSON
import Yams

enum DefaultFloat: Equatable {
    case floating
    case notFloating

    fileprivate static func from(_ bool: Bool) -> DefaultFloat {
        return bool ? .floating : .notFloating
    }
}

protocol ConfigurationStorage {
    func object(forKey key: ConfigurationKey) -> Any?
    func array(forKey key: ConfigurationKey) -> [Any]?
    func bool(forKey key: ConfigurationKey) -> Bool
    func float(forKey key: ConfigurationKey) -> Float
    func stringArray(forKey key: ConfigurationKey) -> [String]?

    func set(_ value: Any?, forKey key: ConfigurationKey)
    func set(_ value: Bool, forKey key: ConfigurationKey)
}

extension UserDefaults: ConfigurationStorage {
    func object(forKey key: ConfigurationKey) -> Any? {
        return object(forKey: key.rawValue)
    }

    func array(forKey key: ConfigurationKey) -> [Any]? {
        return array(forKey: key.rawValue)
    }

    func bool(forKey key: ConfigurationKey) -> Bool {
        return bool(forKey: key.rawValue)
    }

    func float(forKey key: ConfigurationKey) -> Float {
        return float(forKey: key.rawValue)
    }

    func stringArray(forKey key: ConfigurationKey) -> [String]? {
        return stringArray(forKey: key.rawValue)
    }

    func set(_ value: Any?, forKey key: ConfigurationKey) {
        set(value, forKey: key.rawValue)
    }

    func set(_ value: Bool, forKey key: ConfigurationKey) {
        set(value, forKey: key.rawValue)
    }
}

enum ConfigurationKey: String {
    case layouts = "layouts"
    case commandMod = "mod"
    case commandKey = "key"
    case mod1 = "mod1"
    case mod2 = "mod2"
    case mod3 = "mod3"
    case mod4 = "mod4"
    case windowMargins = "window-margins"
    case smartWindowMargins = "smart-window-margins"
    case windowMarginSize = "window-margin-size"
    case windowMinimumHeight = "window-minimum-height"
    case windowMinimumWidth = "window-minimum-width"
    case windowMaxCount = "window-max-count"
    case floatingBundleIdentifiers = "floating"
    case floatingBundleIdentifiersIsBlacklist = "floating-is-blacklist"
    case ignoreMenuBar = "ignore-menu-bar"
    case floatSmallWindows = "float-small-windows"
    case mouseFollowsFocus = "mouse-follows-focus"
    case focusFollowsMouse = "focus-follows-mouse"
    case mouseSwapsWindows = "mouse-swaps-windows"
    case mouseResizesWindows = "mouse-resizes-windows"
    case layoutHUD = "enables-layout-hud"
    case layoutHUDOnSpaceChange = "enables-layout-hud-on-space-change"
    case useCanaryBuild = "use-canary-build"
    case newWindowsToMain = "new-windows-to-main"
    case followSpaceThrownWindows = "follow-space-thrown-windows"
    case windowResizeStep = "window-resize-step"
    case screenPaddingLeft = "screen-padding-left"
    case screenPaddingRight = "screen-padding-right"
    case screenPaddingTop = "screen-padding-top"
    case screenPaddingBottom = "screen-padding-bottom"
    case debugLayoutInfo = "debug-layout-info"
    case restoreLayoutsOnLaunch = "restore-layouts-on-launch"
    case disablePaddingOnBuiltinDisplay = "disable-padding-on-builtin-display"
    case hideMenuBarIcon = "hide-menu-bar-icon"
}

extension ConfigurationKey: CaseIterable {}

enum CommandKey: String {
    case cycleLayoutForward = "cycle-layout"
    case cycleLayoutBackward = "cycle-layout-backward"
    case shrinkMain = "shrink-main"
    case expandMain = "expand-main"
    case increaseMain = "increase-main"
    case decreaseMain = "decrease-main"
    case command1 = "command1"
    case command2 = "command2"
    case command3 = "command3"
    case command4 = "command4"
    case focusCCW = "focus-ccw"
    case focusCW = "focus-cw"
    case focusMain = "focus-main"
    case focusScreenCCW = "focus-screen-ccw"
    case focusScreenCW = "focus-screen-cw"
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
    case relaunchAmethyst = "relaunch-amethyst"
}

protocol UserConfigurationDelegate: AnyObject {
    func configurationGlobalTilingDidChange(_ userConfiguration: UserConfiguration)
    func configurationAccessibilityPermissionsDidChange(_ userConfiguration: UserConfiguration)
}

class FloatingBundle: NSObject {
    @objc dynamic let id: String
    @objc dynamic let windowTitles: [String]

    init(id: String, windowTitles: [String]) {
        self.id = id
        self.windowTitles = windowTitles
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FloatingBundle else {
            return false
        }

        return other.id == id && other.windowTitles == windowTitles
    }

    func encoded() -> Any {
        return [
            "id": id,
            "window-titles": windowTitles
        ]
    }

    static func from(_ object: Any) -> FloatingBundle? {
        if let id = object as? String {
            return FloatingBundle(id: id, windowTitles: [])
        } else if let dict = object as? [String: Any] {
            var json = JSON(dict)

            if let id = json["id"].string, let windowTitles = json["window-titles"].arrayObject as? [String] {
                return FloatingBundle(id: id, windowTitles: windowTitles)
            }

            guard let key = dict.keys.first, dict.count == 1 else {
                return nil
            }

            json = json[key]

            if let windowTitles = json["window-titles"].arrayObject as? [String] {
                return FloatingBundle(id: key, windowTitles: windowTitles)
            }

            return nil
        } else {
            return nil
        }
    }
}

class UserConfiguration: NSObject {
    static let shared = UserConfiguration()
    private let storage: ConfigurationStorage

    weak var delegate: UserConfigurationDelegate?

    var tilingEnabled = true {
        didSet {
            delegate?.configurationGlobalTilingDidChange(self)
        }
    }
    var hasAccessibilityPermissions = true {
        didSet {
            delegate?.configurationAccessibilityPermissionsDidChange(self)
        }
    }

    var configurationYAML: [String: Any]?
    var configurationJSON: JSON?
    var defaultConfiguration: JSON?

    var modifier1: AMModifierFlags?
    var modifier2: AMModifierFlags?
    var modifier3: AMModifierFlags?
    var modifier4: AMModifierFlags?

    init(storage: ConfigurationStorage) {
        self.storage = storage
    }

    override convenience init() {
        self.init(storage: UserDefaults.standard)
    }

    private func configurationValueForKey<T>(_ key: ConfigurationKey, fallbackToDefault: Bool = true) -> T? {
        return configurationValue(forKeyValue: key.rawValue, fallbackToDefault: fallbackToDefault)
    }

    private func configurationValue<T>(forKeyValue keyValue: String, fallbackToDefault: Bool = true) -> T? {
        if let yamlValue = configurationYAML?[keyValue] {
            if yamlValue is NSNull {
                return nil
            } else {
                return yamlValue as? T
            }
        }

        if let jsonValue = configurationJSON?[keyValue], jsonValue.exists(), jsonValue.error == nil {
            return jsonValue.rawValue as? T
        }

        if fallbackToDefault {
            return defaultConfiguration![keyValue].rawValue as? T
        }

        return nil
    }

    func modifierFlagsForStrings(_ modifierStrings: [String]) -> AMModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        for modifierString in modifierStrings {
            switch modifierString {
            case "option":
                flags.insert(.option)
            case "shift":
                flags.insert(.shift)
            case "control":
                flags.insert(.control)
            case "command":
                flags.insert(.command)
            default:
                log.warning("Unrecognized modifier string: \(modifierString)")
            }
        }
        return flags
    }

    func load() {
        let hasAccessibilityPermissions = confirmAccessibilityPermissions()
        if self.hasAccessibilityPermissions != hasAccessibilityPermissions {
            self.hasAccessibilityPermissions = hasAccessibilityPermissions
        }
        loadConfigurationFile()
        loadConfiguration()
    }

    func loadConfiguration() {
        for key in ConfigurationKey.allCases {
            let value: Any? = configurationValueForKey(key, fallbackToDefault: false)
            let defaultValue = defaultConfiguration?[key.rawValue]
            let existingValue = storage.object(forKey: key)

            let hasLocalConfigurationValue = value != nil
            let hasDefaultConfigurationValue = (defaultValue != nil && defaultValue?.error == nil)
            let hasExistingValue = (existingValue != nil)

            guard hasLocalConfigurationValue || (hasDefaultConfigurationValue && !hasExistingValue) else {
                continue
            }

            storage.set(hasLocalConfigurationValue ? value : defaultValue?.rawValue, forKey: key)
        }
    }

    private func yamlForConfig(at path: String) -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: path, isDirectory: nil) else {
            return nil
        }

        let configPath = URL(fileURLWithPath: path)

        guard let string = try? String(contentsOf: configPath) else {
            return nil
        }

        do {
            let yaml = try Yams.load(yaml: string)
            return yaml as? [String: Any]
        } catch {
            log.debug(error)
            return nil
        }
    }

    private func jsonForConfig(at path: String) -> JSON? {
        guard FileManager.default.fileExists(atPath: path, isDirectory: nil) else {
            return nil
        }

        let configPath = URL(fileURLWithPath: path)

        guard let data = try? Data(contentsOf: configPath) else {
            return nil
        }

        return try? JSON(data: data)
    }

    private func loadConfigurationFile() {
        let xdgConfigPath = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] ?? NSHomeDirectory().appending("/.config")
        let amethystXDGConfigPath = xdgConfigPath.appending("/amethyst")
        let amethystYAMLConfigPath = NSHomeDirectory().appending("/.amethyst.yml")
        let amethystJSONConfigPath = NSHomeDirectory().appending("/.amethyst")
        let defaultAmethystConfigPath = Bundle.main.path(forResource: "default", ofType: "amethyst")

        var isDirectory: ObjCBool = false
        /**
         Prioritiy order for config files:
         1. yml in home dir
         2. yml in xdg path
         3. json in home dir
         4. default json
         */
        if FileManager.default.fileExists(atPath: amethystYAMLConfigPath, isDirectory: &isDirectory) {
            configurationYAML = yamlForConfig(at: amethystYAMLConfigPath)

            if configurationYAML == nil {
                log.error("error loading configuration as yaml")

                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Error loading configuration"
                alert.runModal()
            }
        } else if FileManager.default.fileExists(atPath: amethystXDGConfigPath, isDirectory: &isDirectory) {
            configurationYAML = yamlForConfig(at: isDirectory.boolValue ? amethystXDGConfigPath.appending("/amethyst.yml") : amethystXDGConfigPath)

            if configurationYAML == nil {
                log.error("error loading configuration as yaml")

                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Error loading configuration"
                alert.runModal()
            }
        } else if FileManager.default.fileExists(atPath: amethystJSONConfigPath, isDirectory: &isDirectory) {
            configurationJSON = jsonForConfig(at: amethystJSONConfigPath)

            if configurationJSON == nil {
                log.error("error loading configuration as json")

                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Error loading configuration"
                alert.runModal()
            }
        }

        defaultConfiguration = jsonForConfig(at: defaultAmethystConfigPath ?? "")
        if defaultConfiguration == nil {
            log.error("error loading default configuration")

            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Error loading default configuration"
            alert.runModal()
        }

        let mod1Strings: [String] = configurationValueForKey(.mod1)!
        let mod2Strings: [String] = configurationValueForKey(.mod2)!
        let mod3Strings: [String]? = configurationValueForKey(.mod3)
        let mod4Strings: [String]? = configurationValueForKey(.mod4)

        modifier1 = modifierFlagsForStrings(mod1Strings)
        modifier2 = modifierFlagsForStrings(mod2Strings)

        if let mod3Strings = mod3Strings {
            modifier3 = modifierFlagsForStrings(mod3Strings)
        }

        if let mod4Strings = mod4Strings {
            modifier4 = modifierFlagsForStrings(mod4Strings)
        }
    }

    static func constructLayoutKeyString(_ layoutKey: String) -> String {
        return "select-\(layoutKey)-layout"
    }

    func constructCommand(for hotKeyRegistrar: HotKeyRegistrar, commandKey: String, handler: @escaping HotKeyHandler) {
        var override = false
        var command: [String: String]? = configurationValue(forKeyValue: commandKey, fallbackToDefault: false)
        if command != nil {
            override = true
        } else if let enabled: Bool = configurationValue(forKeyValue: commandKey, fallbackToDefault: false), !enabled {
            override = true
            command = nil
        } else {
            let mod1: [String]? = configurationValueForKey(.mod1, fallbackToDefault: false)
            let mod2: [String]? = configurationValueForKey(.mod2, fallbackToDefault: false)
            let mod3: [String]? = configurationValueForKey(.mod3, fallbackToDefault: false)
            let mod4: [String]? = configurationValueForKey(.mod4, fallbackToDefault: false)
            if mod1 != nil || mod2 != nil || mod3 != nil || mod4 != nil {
                override = true
            }
            command = defaultConfiguration?[commandKey].rawValue as? [String: String]
        }

        let commandKeyString = command?[ConfigurationKey.commandKey.rawValue]
        let commandModifierString = command?[ConfigurationKey.commandMod.rawValue]

        var commandFlags: AMModifierFlags?

        if let modifierString = commandModifierString {
            switch modifierString {
            case "mod1":
                commandFlags = modifier1
            case "mod2":
                commandFlags = modifier2
            case "mod3":
                commandFlags = modifier3
            case "mod4":
                commandFlags = modifier4
            default:
                log.warning("Unknown modifier string: \(modifierString)")
                return
            }
        }

        let injectedHandler: () -> Void = { [weak self] in
            guard let `self` = self else {
                return
            }

            let hasAccessibilityPermissions = self.confirmAccessibilityPermissions()

            if self.hasAccessibilityPermissions != hasAccessibilityPermissions {
                self.hasAccessibilityPermissions = hasAccessibilityPermissions
            }

            guard hasAccessibilityPermissions else {
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                handler()
            }
        }

        hotKeyRegistrar.registerHotKey(
            with: commandKeyString,
            modifiers: commandFlags,
            handler: injectedHandler,
            defaultsKey: commandKey,
            override: override
        )
    }

    func hasCustomConfiguration() -> Bool {
        return configurationYAML != nil || configurationJSON != nil
    }

    private func modifierFlagsForModifierString(_ modifierString: String) -> AMModifierFlags {
        switch modifierString {
        case "mod1":
            return modifier1!
        case "mod2":
            return modifier2!
        case "mod3":
            return modifier3!
        case "mod4":
            return modifier4!
        default:
            log.warning("Unknown modifier string: \(modifierString)")
            return modifier1!
        }
    }

    func layoutKeys() -> [String] {
        let layoutKeys = storage.array(forKey: .layouts) as? [String]
        return layoutKeys ?? []
    }

    func setLayoutKeys(_ layoutKeys: [String]) {
        storage.set(layoutKeys as Any?, forKey: .layouts)
    }

    func runningApplication(_ runningApplication: BundleIdentifiable, byDefaultFloatsForTitle title: String?) -> Reliable<DefaultFloat> {
        let useIdentifiersAsBlacklist = floatingBundleIdentifiersIsBlacklist()

        // If the application is in the floating list we need to continue to check title
        // Otherwise
        //   - Blacklist means not floating
        //   - Whitelist menas floating
        guard let floatingBundle = runningApplicationFloatingBundle(runningApplication) else {
            return .reliable(DefaultFloat.from(!useIdentifiersAsBlacklist))
        }

        // If the window list is empty then all windows are included in the list
        //   - Blacklist means floating
        //   - Whitelist means not floating
        if floatingBundle.windowTitles.isEmpty {
            return .reliable(DefaultFloat.from(useIdentifiersAsBlacklist))
        }

        // If the title is `nil` then we cannot make a determination so we fall back to the default. However, we have to treat this value as unreliable as the window could have just been created and be in the process of loading.
        guard let title = title else {
            return .unreliable(DefaultFloat.from(!useIdentifiersAsBlacklist))
        }

        // If the title matches it is included
        //   - Blacklist means floating
        //   - Whitelist means not floating
        if floatingBundle.windowTitles.contains(where: { windowTitle in
            if title.range(of: windowTitle, options: .regularExpression) != nil {
                return true
            } else {
                return false
            }
        }) {
            return .reliable(DefaultFloat.from(useIdentifiersAsBlacklist))
        }

        // Otherwise the window is not included
        //   - Blacklist means not floating
        //   - Whitelist means floating
        let defaultFloat = DefaultFloat.from(!useIdentifiersAsBlacklist)

        // If the title is empty the window could have just been created and in the process of loading. Our float determination could still be correct, but to account for the potential change we mark it as unreliable.
        if title.isEmpty {
            return .unreliable(defaultFloat)
        }

        return .reliable(defaultFloat)
    }

    func runningApplicationFloatingBundle(_ runningApplication: BundleIdentifiable) -> FloatingBundle? {
        let floatingBundles = self.floatingBundles()

        let bundleIdentifier = runningApplication.bundleIdentifier ?? ""

        for floatingBundle in floatingBundles {
            if floatingBundle.id.contains("*") {
                do {
                    let pattern = floatingBundle.id
                        .replacingOccurrences(of: ".", with: "\\.")
                        .replacingOccurrences(of: "*", with: ".*")
                    let regex = try NSRegularExpression(pattern: "^\(pattern)$", options: [])
                    let fullRange = NSRange(location: 0, length: bundleIdentifier.count)

                    if regex.firstMatch(in: bundleIdentifier, options: [], range: fullRange) != nil {
                        return floatingBundle
                    }
                } catch {
                    continue
                }
            } else {
                if floatingBundle.id == runningApplication.bundleIdentifier {
                    return floatingBundle
                }
            }
        }

        return nil
    }

    func ignoreMenuBar() -> Bool {
        return storage.bool(forKey: .ignoreMenuBar)
    }

    func floatSmallWindows() -> Bool {
        return storage.bool(forKey: .floatSmallWindows)
    }

    func mouseFollowsFocus() -> Bool {
        return storage.bool(forKey: .mouseFollowsFocus)
    }

    func focusFollowsMouse() -> Bool {
        return storage.bool(forKey: .focusFollowsMouse)
    }

    func toggleFocusFollowsMouse() {
        storage.set(!focusFollowsMouse(), forKey: .focusFollowsMouse)
    }

    func mouseSwapsWindows() -> Bool {
        return storage.bool(forKey: .mouseSwapsWindows)
    }

    func mouseResizesWindows() -> Bool {
        return storage.bool(forKey: .mouseResizesWindows)
    }

    func enablesLayoutHUD() -> Bool {
        return storage.bool(forKey: .layoutHUD)
    }

    func enablesLayoutHUDOnSpaceChange() -> Bool {
        return storage.bool(forKey: .layoutHUDOnSpaceChange)
    }

    func useCanaryBuild() -> Bool {
        return storage.bool(forKey: .useCanaryBuild)
    }

    func windowMarginSize() -> CGFloat {
        return CGFloat(storage.float(forKey: .windowMarginSize))
    }

    func windowMargins() -> Bool {
        if !storage.bool(forKey: .windowMargins) {
            return false
        }
        // if smartWindowMargins is not enabled, enable window margins
        if !smartWindowMargins() {
            return true
        }
        // if smartWindowMargins is enabled, enabled window margins if there are more than one visible windows on screen
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
        let infoList = windowsListInfo as! [[String: Any]]
        let visibleWindows = infoList.filter { $0["kCGWindowLayer"] as! Int == 0 }
        return visibleWindows.count > 1
    }

    func smartWindowMargins() -> Bool {
        return storage.bool(forKey: .smartWindowMargins)
    }

    func windowMinimumHeight() -> CGFloat {
        return CGFloat(storage.float(forKey: .windowMinimumHeight))
    }

    func windowMinimumWidth() -> CGFloat {
        return CGFloat(storage.float(forKey: .windowMinimumWidth))
    }

    func windowMaxCount() -> Int? {
        let int = Int(storage.float(forKey: .windowMaxCount))
        return int == 0 ? nil : int
    }

    func windowResizeStep() -> CGFloat {
        return CGFloat(storage.float(forKey: .windowResizeStep) / 100.0)
    }

    func screenPaddingTop() -> CGFloat {
        return CGFloat(storage.float(forKey: .screenPaddingTop))
    }

    func screenPaddingBottom() -> CGFloat {
        return CGFloat(storage.float(forKey: .screenPaddingBottom))
    }

    func screenPaddingLeft() -> CGFloat {
        return CGFloat(storage.float(forKey: .screenPaddingLeft))
    }

    func screenPaddingRight() -> CGFloat {
        return CGFloat(storage.float(forKey: .screenPaddingRight))
    }

    func floatingBundleIdentifiersIsBlacklist() -> Bool {
        guard storage.object(forKey: .floatingBundleIdentifiersIsBlacklist) != nil else {
            return true
        }
        return storage.bool(forKey: .floatingBundleIdentifiersIsBlacklist)
    }

    func floatingBundles() -> [FloatingBundle] {
        guard let floatingBundles = storage.array(forKey: .floatingBundleIdentifiers) else {
            return []
        }

        return floatingBundles.compactMap { FloatingBundle.from($0) }
    }

    func setFloatingBundles(_ floatingBundles: [FloatingBundle]) {
        storage.set(floatingBundles.map { $0.encoded() }, forKey: .floatingBundleIdentifiers)
    }

    func sendNewWindowsToMainPane() -> Bool {
        return storage.bool(forKey: .newWindowsToMain)
    }

    func disablePaddingOnBuiltinDisplay() -> Bool {
        return storage.bool(forKey: .disablePaddingOnBuiltinDisplay)
    }

    func followWindowsThrownBetweenSpaces() -> Bool {
        return storage.bool(forKey: .followSpaceThrownWindows)
    }

    func restoreLayoutsOnLaunch() -> Bool {
        return storage.bool(forKey: .restoreLayoutsOnLaunch)
    }

    func hideMenuBarIcon() -> Bool {
        return storage.bool(forKey: .hideMenuBarIcon)
    }
}

extension UserConfiguration {
    @discardableResult func confirmAccessibilityPermissions() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
        ]

        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
