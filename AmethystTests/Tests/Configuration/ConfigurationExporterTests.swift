//
//  ConfigurationExporterTests.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 9/20/25.
//  Copyright © 2025 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Carbon
import Cocoa
import Nimble
import Quick
import Yams

class ConfigurationExporterTests: QuickSpec {
    private class TestKeyBindingStorage: KeyBindingStorage {
        var keyBindings: [String: KeyBinding] = [:]

        func keyBinding(forCommandKey commandKey: String) -> KeyBinding? {
            return keyBindings[commandKey]
        }
    }

    private class TestHotKeyRegistrar: HotKeyRegistrar {
        private(set) var keyString: String?
        private(set) var modifiers: AMModifierFlags?

        func registerHotKey(with string: String?, modifiers: AMModifierFlags?, handler: @escaping () -> Void, defaultsKey: String, override: Bool) {
            keyString = string
            self.modifiers = modifiers
        }
    }

    /// Enough of the real key code map to exercise the export, including a key that needs quoting
    /// and a key that only has a special name.
    private static let keyCodeToString: [AMKeyCode: String] = [
        kVK_ANSI_A: "a",
        kVK_ANSI_B: "b",
        kVK_ANSI_C: "c",
        kVK_ANSI_Comma: ",",
        kVK_ANSI_Period: ".",
        kVK_Space: "space"
    ]

    private static func exporter(storage: TestConfigurationStorage, keyBindings: TestKeyBindingStorage) -> ConfigurationExporter {
        return ConfigurationExporter(
            userConfiguration: UserConfiguration(storage: storage),
            keyBindings: keyBindings,
            keyCodeToString: keyCodeToString
        )
    }

    /// The export is only useful if Amethyst can read it back, so the assertions are made against
    /// the parsed document rather than against the text.
    private static func load(_ export: ConfigurationExporter.Export) -> [String: Any] {
        return ((try? Yams.load(yaml: export.yaml)) as? [String: Any]) ?? [:]
    }

    override func spec() {
        describe("exporting values") {
            it("writes values with the type the configuration file expects") {
                let storage = TestConfigurationStorage()
                storage.set(true as Any?, forKey: .mouseFollowsFocus)
                storage.set(false as Any?, forKey: .windowMargins)
                storage.set(Float(5) as Any?, forKey: .windowMarginSize)
                storage.set(Float(2.5) as Any?, forKey: .windowResizeStep)
                storage.set(["tall", "wide"] as Any?, forKey: .layouts)

                let export = Self.exporter(storage: storage, keyBindings: TestKeyBindingStorage()).export(commandKeys: [])
                let configuration = Self.load(export)

                expect(configuration["mouse-follows-focus"] as? Bool).to(beTrue())
                expect(configuration["window-margins"] as? Bool).to(beFalse())
                expect(configuration["window-margin-size"] as? Int).to(equal(5))
                expect(configuration["window-resize-step"] as? Double).to(equal(2.5))
                expect(configuration["layouts"] as? [String]).to(equal(["tall", "wide"]))
            }

            it("leaves out values that have never been set") {
                let storage = TestConfigurationStorage()
                storage.set(true as Any?, forKey: .mouseFollowsFocus)

                let export = Self.exporter(storage: storage, keyBindings: TestKeyBindingStorage()).export(commandKeys: [])
                let configuration = Self.load(export)

                expect(configuration.keys.contains("mouse-follows-focus")).to(beTrue())
                expect(configuration.keys.contains("focus-follows-mouse")).to(beFalse())
            }

            it("writes floating bundles in a form it can read back") {
                let storage = TestConfigurationStorage()
                let bundles = [
                    FloatingBundle(id: "com.apple.Terminal", windowTitles: []),
                    FloatingBundle(id: "com.google.Chrome", windowTitles: ["Picture in Picture"])
                ]
                storage.set(bundles.map { $0.encoded() } as Any?, forKey: .floatingBundleIdentifiers)

                let export = Self.exporter(storage: storage, keyBindings: TestKeyBindingStorage()).export(commandKeys: [])
                let configuration = Self.load(export)
                let exportedBundles = (configuration["floating"] as? [Any])?.compactMap { FloatingBundle.from($0) }

                expect(exportedBundles).to(equal(bundles))
            }

            it("writes an empty floating list as a list") {
                let storage = TestConfigurationStorage()
                storage.set([] as Any?, forKey: .floatingBundleIdentifiers)

                let export = Self.exporter(storage: storage, keyBindings: TestKeyBindingStorage()).export(commandKeys: [])
                let configuration = Self.load(export)

                expect(configuration["floating"] as? [String]).to(equal([]))
            }
        }

        describe("exporting commands") {
            it("writes bindings against the existing modifier definitions") {
                let storage = TestConfigurationStorage()
                storage.set(["option", "shift"] as Any?, forKey: .mod1)
                storage.set(["option", "shift", "control"] as Any?, forKey: .mod2)

                let keyBindings = TestKeyBindingStorage()
                keyBindings.keyBindings = [
                    "focus-ccw": KeyBinding(keyCode: kVK_ANSI_A, modifiers: [.option, .shift]),
                    "swap-ccw": KeyBinding(keyCode: kVK_Space, modifiers: [.option, .shift, .control])
                ]

                let export = Self.exporter(storage: storage, keyBindings: keyBindings).export(commandKeys: ["focus-ccw", "swap-ccw"])
                let configuration = Self.load(export)

                expect(export.unrepresentableCommandKeys).to(beEmpty())
                expect(configuration["mod1"] as? [String]).to(equal(["option", "shift"]))
                expect(configuration["mod2"] as? [String]).to(equal(["option", "shift", "control"]))
                expect(configuration["focus-ccw"] as? [String: String]).to(equal(["mod": "mod1", "key": "a"]))
                expect(configuration["swap-ccw"] as? [String: String]).to(equal(["mod": "mod2", "key": "space"]))
            }

            it("quotes keys that yaml would otherwise misread") {
                let keyBindings = TestKeyBindingStorage()
                keyBindings.keyBindings = [
                    "increase-main": KeyBinding(keyCode: kVK_ANSI_Comma, modifiers: [.command]),
                    "decrease-main": KeyBinding(keyCode: kVK_ANSI_Period, modifiers: [.command])
                ]

                let export = Self.exporter(storage: TestConfigurationStorage(), keyBindings: keyBindings)
                    .export(commandKeys: ["increase-main", "decrease-main"])
                let configuration = Self.load(export)

                expect(configuration["increase-main"] as? [String: String]).to(equal(["mod": "mod1", "key": ","]))
                expect(configuration["decrease-main"] as? [String: String]).to(equal(["mod": "mod1", "key": "."]))
            }

            it("declares modifier combinations that are not already defined") {
                let storage = TestConfigurationStorage()
                storage.set(["option", "shift"] as Any?, forKey: .mod1)

                let keyBindings = TestKeyBindingStorage()
                keyBindings.keyBindings = [
                    "focus-ccw": KeyBinding(keyCode: kVK_ANSI_A, modifiers: [.option, .shift]),
                    "focus-cw": KeyBinding(keyCode: kVK_ANSI_B, modifiers: [.command, .control])
                ]

                let export = Self.exporter(storage: storage, keyBindings: keyBindings).export(commandKeys: ["focus-ccw", "focus-cw"])
                let configuration = Self.load(export)

                expect(export.unrepresentableCommandKeys).to(beEmpty())
                expect(configuration["mod1"] as? [String]).to(equal(["option", "shift"]))
                expect(configuration["mod2"] as? [String]).to(equal(["control", "command"]))
                expect(configuration["focus-cw"] as? [String: String]).to(equal(["mod": "mod2", "key": "b"]))
            }

            it("disables commands that have no binding") {
                let export = Self.exporter(storage: TestConfigurationStorage(), keyBindings: TestKeyBindingStorage())
                    .export(commandKeys: ["enable-tiling"])
                let configuration = Self.load(export)

                expect(export.unrepresentableCommandKeys).to(beEmpty())
                expect(configuration["enable-tiling"] as? Bool).to(beFalse())
            }

            it("reports bindings that use a key it cannot name") {
                let keyBindings = TestKeyBindingStorage()
                keyBindings.keyBindings = ["focus-ccw": KeyBinding(keyCode: kVK_F1, modifiers: [.option, .shift])]

                let export = Self.exporter(storage: TestConfigurationStorage(), keyBindings: keyBindings)
                    .export(commandKeys: ["focus-ccw"])
                let configuration = Self.load(export)

                expect(export.unrepresentableCommandKeys).to(equal(["focus-ccw"]))
                expect(configuration["focus-ccw"] as? Bool).to(beFalse())
            }

            it("reports bindings that need a fifth modifier combination") {
                let keyBindings = TestKeyBindingStorage()
                let combinations: [AMModifierFlags] = [
                    [.option],
                    [.shift],
                    [.control],
                    [.command],
                    [.option, .command]
                ]
                let commandKeys = (0..<combinations.count).map { "command\($0)" }

                // The last combination is bound once and the rest twice, so it is the one that
                // gets dropped when the modifier slots run out.
                for (index, combination) in combinations.enumerated() {
                    keyBindings.keyBindings["command\(index)"] = KeyBinding(keyCode: kVK_ANSI_A, modifiers: combination)
                }
                for (index, combination) in combinations.dropLast().enumerated() {
                    keyBindings.keyBindings["duplicate\(index)"] = KeyBinding(keyCode: kVK_ANSI_B, modifiers: combination)
                }

                let export = Self.exporter(storage: TestConfigurationStorage(), keyBindings: keyBindings)
                    .export(commandKeys: commandKeys + keyBindings.keyBindings.keys.filter { $0.hasPrefix("duplicate") }.sorted())
                let configuration = Self.load(export)

                expect(export.unrepresentableCommandKeys).to(equal(["command4"]))
                expect(configuration["command4"] as? Bool).to(beFalse())
                expect(configuration["command0"] as? [String: String]).toNot(beNil())
                expect(configuration.keys.contains("mod4")).to(beTrue())
                expect(configuration.keys.contains("mod5")).to(beFalse())
            }

            it("ignores modifiers that the configuration file has no name for") {
                let storage = TestConfigurationStorage()
                storage.set(["option", "shift"] as Any?, forKey: .mod1)

                let keyBindings = TestKeyBindingStorage()
                keyBindings.keyBindings = ["focus-ccw": KeyBinding(keyCode: kVK_ANSI_A, modifiers: [.option, .shift, .function])]

                let export = Self.exporter(storage: storage, keyBindings: keyBindings).export(commandKeys: ["focus-ccw"])
                let configuration = Self.load(export)

                expect(export.unrepresentableCommandKeys).to(beEmpty())
                expect(configuration["focus-ccw"] as? [String: String]).to(equal(["mod": "mod1", "key": "a"]))
            }
        }

        describe("reading the export back") {
            it("produces a configuration that resolves to the values it was given") {
                let storage = TestConfigurationStorage()
                storage.set(["tall", "column"] as Any?, forKey: .layouts)
                storage.set(["option", "shift"] as Any?, forKey: .mod1)
                storage.set(Float(12) as Any?, forKey: .windowMarginSize)
                storage.set(true as Any?, forKey: .windowMargins)

                let keyBindings = TestKeyBindingStorage()
                keyBindings.keyBindings = ["focus-ccw": KeyBinding(keyCode: kVK_ANSI_C, modifiers: [.option, .shift])]

                let export = Self.exporter(storage: storage, keyBindings: keyBindings).export(commandKeys: ["focus-ccw"])

                // Feed the exported document back through the configuration the way a dotfile is
                // loaded, and check that it lands on the same values.
                let reloadedStorage = TestConfigurationStorage()
                let reloaded = UserConfiguration(storage: reloadedStorage)
                reloaded.configurationYAML = (try? Yams.load(yaml: export.yaml)) as? [String: Any]
                reloaded.loadConfiguration()

                expect(reloadedStorage.stringArray(forKey: .layouts)).to(equal(["tall", "column"]))
                expect(reloadedStorage.object(forKey: .windowMarginSize) as? Int).to(equal(12))
                expect(reloadedStorage.bool(forKey: .windowMargins)).to(beTrue())

                reloaded.modifier1 = reloaded.modifierFlagsForStrings(reloaded.configurationYAML?["mod1"] as? [String] ?? [])

                let registrar = TestHotKeyRegistrar()
                reloaded.constructCommand(for: registrar, commandKey: "focus-ccw", handler: {})

                expect(registrar.keyString).to(equal("c"))
                expect(registrar.modifiers).to(equal([.option, .shift]))
            }
        }
    }
}
