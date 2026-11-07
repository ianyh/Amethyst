//
//  ConfigurationExporter.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 9/20/25.
//  Copyright © 2025 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Yams

/// A key binding as it is currently registered with the application.
struct KeyBinding: Equatable {
    /// Modifiers that the configuration file is able to describe. Anything else — the function or
    /// numeric pad flags, say — has no spelling in the file and is ignored.
    static let supportedModifiers: AMModifierFlags = [.option, .shift, .control, .command]

    let keyCode: AMKeyCode
    let modifiers: AMModifierFlags

    init(keyCode: AMKeyCode, modifiers: AMModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(KeyBinding.supportedModifiers)
    }
}

/// Read-only access to the key bindings that are currently registered.
protocol KeyBindingStorage {
    func keyBinding(forCommandKey commandKey: String) -> KeyBinding?
}

/// Writes the configuration currently held in preferences back out in the `.amethyst.yml` format
/// so that it can be kept alongside a user's other dotfiles.
///
/// Only values that preferences actually hold are written. A value that has never been set is left
/// out, so that Amethyst applies the same default to it that it applies today.
struct ConfigurationExporter {
    struct Export {
        /// The contents of the configuration file.
        let yaml: String

        /// Commands whose binding the configuration file has no way of expressing, either because
        /// the key has no name in the file — the function keys, for example — or because the
        /// bindings as a whole use more modifier combinations than the file has room for. They are
        /// written out as disabled and listed in a comment at the top of the file.
        let unrepresentableCommandKeys: [String]
    }

    /// The configuration file declares modifier combinations up front and commands refer to them
    /// by name, so only this many distinct combinations can be expressed.
    static let modifierSlotKeys: [ConfigurationKey] = [.mod1, .mod2, .mod3, .mod4]

    /// Keys that the export writes itself rather than through the generic value handling, either
    /// because of where they belong in the file or because they are not values at all.
    private static let separatelyHandledKeys: Set<ConfigurationKey> = [
        .layouts,
        .mod1,
        .mod2,
        .mod3,
        .mod4,
        .commandMod,
        .commandKey
    ]

    private let userConfiguration: UserConfiguration
    private let keyBindings: KeyBindingStorage
    private let keyCodeToString: [AMKeyCode: String]

    init(userConfiguration: UserConfiguration, keyBindings: KeyBindingStorage, keyCodeToString: [AMKeyCode: String]) {
        self.userConfiguration = userConfiguration
        self.keyBindings = keyBindings
        self.keyCodeToString = keyCodeToString
    }

    /// - Parameter commandKeys: the commands to write out, in the order they should appear.
    func export(commandKeys: [String]) -> Export {
        let bindings = commandKeys.map { ($0, keyBindings.keyBinding(forCommandKey: $0)) }
        let slots = modifierSlots(bindings: bindings.compactMap { $0.1 })

        var commandLines: [String] = []
        var unrepresentableCommandKeys: [String] = []

        for (commandKey, binding) in bindings {
            guard let binding = binding else {
                // The command has no binding at all, which the configuration file spells as the
                // command being turned off.
                commandLines.append("\(commandKey): false")
                continue
            }

            guard let keyString = keyCodeToString[binding.keyCode],
                  let slot = slots.firstIndex(of: binding.modifiers) else {
                unrepresentableCommandKeys.append(commandKey)
                commandLines.append("\(commandKey): false")
                continue
            }

            commandLines.append("\(commandKey):")
            commandLines.append("  mod: mod\(slot + 1)")
            commandLines.append("  key: \(scalar(keyString))")
        }

        var sections: [[String]] = [header(unrepresentableCommandKeys: unrepresentableCommandKeys)]

        if let layouts = lines(for: .layouts) {
            sections.append(layouts)
        }

        for (index, flags) in slots.enumerated() {
            sections.append(lines("mod\(index + 1)", list: userConfiguration.modifierStringsForFlags(flags).map { scalar($0) }))
        }

        sections.append(commandLines)

        for key in ConfigurationKey.allCases where !ConfigurationExporter.separatelyHandledKeys.contains(key) {
            if let keyLines = lines(for: key) {
                sections.append(keyLines)
            }
        }

        let yaml = sections
            .filter { !$0.isEmpty }
            .map { $0.joined(separator: "\n") }
            .joined(separator: "\n\n")

        return Export(yaml: yaml + "\n", unrepresentableCommandKeys: unrepresentableCommandKeys)
    }

    private func header(unrepresentableCommandKeys: [String]) -> [String] {
        var lines = [
            "# Amethyst configuration exported from preferences.",
            "#",
            "# Move this file to `~/.amethyst.yml` and restart Amethyst to use it. Note that while",
            "# a configuration file is in place it takes precedence over the preferences window."
        ]

        guard !unrepresentableCommandKeys.isEmpty else {
            return lines
        }

        lines.append("#")
        lines.append("# The following commands were written out as disabled because a configuration file")
        lines.append("# cannot express their shortcuts. A configuration file has room for four modifier")
        lines.append("# combinations and has no name for keys such as the function keys.")

        for commandKey in unrepresentableCommandKeys {
            lines.append("#   - \(commandKey)")
        }

        return lines
    }

    /// Picks the modifier combinations that the exported file will declare.
    ///
    /// Combinations that are already declared keep their slots so that an exported file carries
    /// the same meaning of `mod1` and `mod2` that the user is used to. Whatever room is left over
    /// goes to the combinations the bindings use most, which is where dropping one would do the
    /// most damage.
    private func modifierSlots(bindings: [KeyBinding]) -> [AMModifierFlags] {
        var slots: [AMModifierFlags] = []

        for key in ConfigurationExporter.modifierSlotKeys {
            guard let modifierStrings = userConfiguration.storage.stringArray(forKey: key) else {
                continue
            }

            let flags = userConfiguration.modifierFlagsForStrings(modifierStrings)

            if !flags.isEmpty && !slots.contains(flags) {
                slots.append(flags)
            }
        }

        var counts: [UInt: Int] = [:]

        for binding in bindings where !binding.modifiers.isEmpty && !slots.contains(binding.modifiers) {
            counts[binding.modifiers.rawValue, default: 0] += 1
        }

        let unslotted = counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { AMModifierFlags(rawValue: $0.key) }

        slots.append(contentsOf: unslotted.prefix(ConfigurationExporter.modifierSlotKeys.count - slots.count))

        return slots
    }

    private func lines(for key: ConfigurationKey) -> [String]? {
        let storage = userConfiguration.storage
        let name = key.rawValue

        guard storage.object(forKey: key) != nil else {
            return nil
        }

        switch key.valueType {
        case .commandComponent:
            return nil
        case .bool:
            return ["\(name): \(scalar(storage.bool(forKey: key)))"]
        case .number:
            let value = storage.float(forKey: key)
            // The file reads better with whole numbers written as such, and every value that is
            // meant to be whole — a pixel count, a percentage — is stored as a float regardless.
            return ["\(name): \(scalar(value == value.rounded() ? Int(value) : Double(value)))"]
        case .stringList:
            guard let strings = storage.stringArray(forKey: key) else {
                return nil
            }

            return lines(name, list: strings.map { scalar($0) })
        case .floatingBundleList:
            guard let objects = storage.array(forKey: key) else {
                return nil
            }

            let bundles = objects.compactMap { FloatingBundle.from($0) }

            guard !bundles.isEmpty else {
                return ["\(name): []"]
            }

            return [name + ":"] + bundles.flatMap { bundle -> [String] in
                guard !bundle.windowTitles.isEmpty else {
                    return ["  - \(scalar(bundle.id))"]
                }

                return ["  - id: \(scalar(bundle.id))", "    window-titles:"]
                    + bundle.windowTitles.map { "      - \(scalar($0))" }
            }
        }
    }

    private func lines(_ name: String, list items: [String]) -> [String] {
        guard !items.isEmpty else {
            return ["\(name): []"]
        }

        return [name + ":"] + items.map { "  - \($0)" }
    }

    /// Renders a value the way YAML needs it written, including any quoting it requires.
    private func scalar(_ value: Any) -> String {
        guard let dumped = try? Yams.dump(object: value) else {
            return "\(value)"
        }

        // A dumped scalar is a document in its own right, so it can carry an end-of-document
        // marker along with it.
        return dumped
            .components(separatedBy: .newlines)
            .first { !$0.isEmpty && $0 != "..." } ?? "\(value)"
    }
}
