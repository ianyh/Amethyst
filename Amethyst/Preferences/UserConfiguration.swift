//
//  UserConfiguration.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import SwiftyJSON

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
    case windowMargins = "window-margins"
    case smartWindowMargins = "smart-window-margins"
    case windowMarginSize = "window-margin-size"
    case windowMinimumHeight = "window-minimum-height"
    case windowMinimumWidth = "window-minimum-width"
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
            let json = JSON(dict)

            guard let id = json["id"].string, let windowTitles = json["window-titles"].arrayObject as? [String] else {
                return nil
            }

            return FloatingBundle(id: id, windowTitles: windowTitles)
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

    var configuration: JSON?
    var defaultConfiguration: JSON?

    var modifier1: AMModifierFlags?
    var modifier2: AMModifierFlags?

    init(storage: ConfigurationStorage) {
        self.storage = storage
    }

    override convenience init() {
        self.init(storage: UserDefaults.standard)
    }

    private func configurationValueForKey<T>(_ key: ConfigurationKey) -> T? {
        guard let exists = configuration?[key.rawValue].exists(), exists else {
            return defaultConfiguration![key.rawValue].object as? T
        }

        guard let configurationValue = configuration?[key.rawValue].rawValue as? T else {
            return defaultConfiguration![key.rawValue].object as? T
        }

        return configurationValue
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
            let value = configuration?[key.rawValue]
            let defaultValue = defaultConfiguration?[key.rawValue]
            let existingValue = storage.object(forKey: key)

            let hasLocalConfigurationValue = (value != nil && value?.error == nil)
            let hasDefaultConfigurationValue = (defaultValue != nil && defaultValue?.error == nil)
            let hasExistingValue = (existingValue != nil)

            guard hasLocalConfigurationValue || (hasDefaultConfigurationValue && !hasExistingValue) else {
                continue
            }

            storage.set(hasLocalConfigurationValue ? value?.object : defaultValue?.object as Any?, forKey: key)
        }
    }

    private func jsonForConfig(at path: String) -> JSON? {
        guard FileManager.default.fileExists(atPath: path, isDirectory: nil) else {
            return nil
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }

        return try? JSON(data: data)
    }

    private func loadConfigurationFile() {
        let amethystConfigPath = NSHomeDirectory() + "/.amethyst"
        let defaultAmethystConfigPath = Bundle.main.path(forResource: "default", ofType: "amethyst")

        if FileManager.default.fileExists(atPath: amethystConfigPath, isDirectory: nil) {
            configuration = jsonForConfig(at: amethystConfigPath)

            if configuration == nil {
                log.error("error loading configuration")

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

        modifier1 = modifierFlagsForStrings(mod1Strings)
        modifier2 = modifierFlagsForStrings(mod2Strings)
    }

    static func constructLayoutKeyString(_ layoutKey: String) -> String {
        return "select-\(layoutKey)-layout"
    }

    func constructCommand(for hotKeyRegistrar: HotKeyRegistrar, commandKey: String, handler: @escaping HotKeyHandler) {
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

        let commandKeyString = command?[ConfigurationKey.commandKey.rawValue]
        let commandModifierString = command?[ConfigurationKey.commandMod.rawValue]

        var commandFlags: AMModifierFlags?

        if let modifierString = commandModifierString {
            switch modifierString {
            case "mod1":
                commandFlags = modifier1
            case "mod2":
                commandFlags = modifier2
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
        return configuration != nil
    }

    private func modifierFlagsForModifierString(_ modifierString: String) -> AMModifierFlags {
        switch modifierString {
        case "mod1":
            return modifier1!
        case "mod2":
            return modifier2!
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

        for floatingBundle in floatingBundles {
            if floatingBundle.id.contains("*") {
                do {
                    guard let bundleIdentifier = runningApplication.bundleIdentifier else {
                        continue
                    }

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
        return storage.bool(forKey: .floatingBundleIdentifiersIsBlacklist)
    }

    func floatingBundleIdentifiers() -> [String] {
        let floatingBundleIdentifiers = storage.stringArray(forKey: .floatingBundleIdentifiers)
        return floatingBundleIdentifiers ?? []
    }

    func floatingBundles() -> [FloatingBundle] {
        guard let floatingBundles = storage.array(forKey: .floatingBundleIdentifiers) else {
            return []
        }

        return floatingBundles.compactMap { FloatingBundle.from($0) }
    }

    func setFloatingBundleIdentifiers(_ floatingBundleIdentifiers: [String]) {
        storage.set(floatingBundleIdentifiers as Any?, forKey: .floatingBundleIdentifiers)
    }

    func setFloatingBundles(_ floatingBundles: [FloatingBundle]) {
        storage.set(floatingBundles.map { $0.encoded() }, forKey: .floatingBundleIdentifiers)
    }

    func sendNewWindowsToMainPane() -> Bool {
        return storage.bool(forKey: .newWindowsToMain)
    }

    func followWindowsThrownBetweenSpaces() -> Bool {
        return storage.bool(forKey: .followSpaceThrownWindows)
    }

    func restoreLayoutsOnLaunch() -> Bool {
        return storage.bool(forKey: .restoreLayoutsOnLaunch)
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
