//
//  UserConfigurationTests.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import SwiftyJSON
import Yams

class TestConfigurationStorage: ConfigurationStorage {
    var storage: [ConfigurationKey: Any] = [:]

    func object(forKey key: ConfigurationKey) -> Any? {
        return storage[key]
    }

    func array(forKey key: ConfigurationKey) -> [Any]? {
        return storage[key] as? [Any]
    }

    func bool(forKey key: ConfigurationKey) -> Bool {
        return (storage[key] as? Bool) ?? false
    }

    func float(forKey key: ConfigurationKey) -> Float {
        return (storage[key] as? Float) ?? 0
    }

    func stringArray(forKey key: ConfigurationKey) -> [String]? {
        return storage[key] as? [String]
    }

    func set(_ value: Any?, forKey key: ConfigurationKey) {
        storage[key] = value
    }

    func set(_ value: Bool, forKey key: ConfigurationKey) {
        storage[key] = value
    }
}

class UserConfigurationTests: QuickSpec {
    private class TestHotKeyRegistrar: HotKeyRegistrar {
        private(set) var keyString: String?
        private(set) var modifiers: AMModifierFlags?
        private(set) var handler: (() -> Void)?
        private(set) var defaultsKey: String?
        private(set) var override: Bool?

        init() {}

        func registerHotKey(with string: String?, modifiers: AMModifierFlags?, handler: @escaping () -> Void, defaultsKey: String, override: Bool) {
            keyString = string
            self.modifiers = modifiers
            self.handler = handler
            self.defaultsKey = defaultsKey
            self.override = override
        }
    }

    private class TestBundleIdentifiable: BundleIdentifiable {
        var bundleIdentifier: String?
    }

    override func spec() {
        describe("constructing commands") {
            context("overrides") {
                it("when user configuration exists") {
                    var configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configurationYAML = nil
                    configuration.configurationJSON = JSON(localConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    var registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())

                    configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.configurationYAML = localConfiguration
                    configuration.configurationJSON = nil
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())
                }

                it("when custom mod1 is specified") {
                    var configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "mod1": [
                            "command"
                        ]
                    ]
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configurationYAML = nil
                    configuration.configurationJSON = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    var registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())

                    configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.configurationYAML = localConfiguration
                    configuration.configurationJSON = nil
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())

                }

                it("when custom mod2 is specified") {
                    var configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "mod2": [
                            "command"
                        ]
                    ]
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configurationJSON = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    var registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())

                    configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.configurationYAML = localConfiguration
                    configuration.configurationJSON = nil
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())
                }
            }

            context("takes command") {
                it("from local configuration over default") {
                    var configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "2"
                        ]
                    ]
                    configuration.configurationJSON = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    var registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.keyString).to(equal("1"))

                    configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.configurationJSON = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.keyString).to(equal("1"))
                }

                it("from default in absence of local configuration") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configurationJSON = JSON([:])
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    let registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(configuration.defaultConfiguration?["test"]["key"].string).to(equal("1"))
                    expect(registrar.keyString).to(equal("1"))
                }
            }

            it("does not crash for malformed commands") {
                var configuration = UserConfiguration(storage: TestConfigurationStorage())
                let localConfiguration: [String: Any] = [
                    "test": [
                        "key": "2"
                    ]
                ]
                let defaultConfiguration: [String: Any] = [
                    "test": [
                        "mod": "mod1",
                        "key": "2"
                    ]
                ]
                configuration.configurationYAML = nil
                configuration.configurationJSON = JSON(localConfiguration)
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                var registrar = TestHotKeyRegistrar()

                expect() {
                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})
                }.toNot(throwError())

                configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.configurationYAML = localConfiguration
                configuration.configurationJSON = nil
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                registrar = TestHotKeyRegistrar()

                expect() {
                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})
                }.toNot(throwError())
            }
        }

        describe("floating application") {
            it("is not floating by default") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set([] as Any?, forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.notFloating)))
            }

            it("floats for exact matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.test.Test"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.floating)))
            }

            it("floats for wildcard matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.test.*"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.floating)))
            }

            it("floats for prefixed wildcard matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["*.Test"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.floating)))
            }

            it("floats for inline wildcard matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.*.Test"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.foo.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.floating)))
            }

            it("does not float for exact mismatches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.test.Other"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.notFloating)))
            }

            it("does not float for wildcard mismatches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.other.*"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.notFloating)))
            }

            context("as whitelist") {
                it("does not float for a matching window title") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let floatingBundle = FloatingBundle(id: "test.test.Test", windowTitles: ["test"])

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([floatingBundle])

                    let bundleIdentifiable = TestBundleIdentifiable()
                    let title = "test"
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.notFloating)))
                }

                it("does not float for a matching application with no specified window titles") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)
                    storage.set(["test.test.Test"], forKey: .floatingBundleIdentifiers)

                    let bundleIdentifiable = TestBundleIdentifiable()
                    let title = UUID().uuidString
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.notFloating)))
                }

                it("floats for no specified applications") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)
                    storage.set([], forKey: .floatingBundleIdentifiers)

                    let bundleIdentifiable = TestBundleIdentifiable()
                    let title = UUID().uuidString
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    let float = configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)
                    expect(float).to(equal(.reliable(.floating)))
                }
            }

            context("specified window titles") {
                it("only float windows with titles") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let floatingBundle = FloatingBundle(id: "test.test.Test", windowTitles: ["test1"])

                    storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([floatingBundle])

                    let bundleIdentifiable = TestBundleIdentifiable()
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "test1")).to(equal(.reliable(.floating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "test2")).to(equal(.reliable(.notFloating)))
                }

                it("only allow windows with titles") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let floatingBundle = FloatingBundle(id: "test.test.Test", windowTitles: ["test1"])

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([floatingBundle])

                    let bundleIdentifiable = TestBundleIdentifiable()
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "test1")).to(equal(.reliable(.notFloating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "test2")).to(equal(.reliable(.floating)))
                }

                it("treats empty and nil titles as unreliable") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let floatingBundle = FloatingBundle(id: "test.test.Test", windowTitles: ["test1"])

                    storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([floatingBundle])

                    let bundleIdentifiable = TestBundleIdentifiable()
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "")).to(equal(.unreliable(.notFloating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: nil)).to(equal(.unreliable(.notFloating)))

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "")).to(equal(.unreliable(.floating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: nil)).to(equal(.unreliable(.floating)))
                }

                it("treats empty and nil titles as reliable if no title would match anyway") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)

                    storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([])

                    let bundleIdentifiable = TestBundleIdentifiable()
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "")).to(equal(.reliable(.notFloating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: nil)).to(equal(.reliable(.notFloating)))

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "")).to(equal(.reliable(.floating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: nil)).to(equal(.reliable(.floating)))
                }
            }
        }

        describe("focus follows mouse") {
            it("toggles") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .focusFollowsMouse)

                expect(configuration.focusFollowsMouse()).to(beTrue())

                configuration.toggleFocusFollowsMouse()

                expect(configuration.focusFollowsMouse()).to(beFalse())
            }
        }

        describe("load configuration") {
            it("default configuration does not override existing configuration") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                let existingLayouts = ["wide"]
                let defaultConfiguration = [
                    "layouts": [
                        "tall"
                    ]
                ]

                storage.set(existingLayouts, forKey: .layouts)

                expect(configuration.layoutKeys()).to(equal(existingLayouts))
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutKeys()).to(equal(existingLayouts))
            }

            it("local json configuration does override existing configuration") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                let existingLayouts = ["wide"]
                let localConfiguration = [
                    "layouts": [
                        "fullscreen"
                    ]
                ]
                let defaultConfiguration = [
                    "layouts": [
                        "tall"
                    ]
                ]

                storage.set(existingLayouts, forKey: .layouts)

                expect(configuration.layoutKeys()).to(equal(existingLayouts))
                configuration.configurationYAML = nil
                configuration.configurationJSON = JSON(localConfiguration)
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutKeys()).to(equal(localConfiguration["layouts"]))
            }

            it("local yaml configuration does override existing configuration") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                let existingLayouts = ["wide"]
                let localConfiguration = [
                    "layouts": [
                        "fullscreen"
                    ]
                ]
                let defaultConfiguration = [
                    "layouts": [
                        "tall"
                    ]
                ]

                storage.set(existingLayouts, forKey: .layouts)

                expect(configuration.layoutKeys()).to(equal(existingLayouts))
                configuration.configurationYAML = localConfiguration
                configuration.configurationJSON = nil
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutKeys()).to(equal(localConfiguration["layouts"]))
            }

            it("prefers yaml over json for local configuration") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                let yamlConfiguration = [
                    "layouts": [
                        "fullscreen"
                    ]
                ]
                let jsonConfiguration = [
                    "layouts": [
                        "tall"
                    ]
                ]
                let defaultConfiguration = [
                    "layouts": [
                        "wide"
                    ]
                ]
                configuration.configurationYAML = yamlConfiguration
                configuration.configurationJSON = JSON(jsonConfiguration)
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutKeys()).to(equal(yamlConfiguration["layouts"]))
            }
        }

        describe("floating bundles") {
            describe("returned") {
                it("handles both strings and objects") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let bundlesData: [Any] = [
                        "test.test.1",
                        [
                            "id": "test.test.2",
                            "window-titles": [
                                "dialog"
                            ]
                        ],
                        "test.test.3"
                    ]

                    storage.set(bundlesData, forKey: .floatingBundleIdentifiers)

                    let bundles = configuration.floatingBundles()
                    let expectedBundles = [
                        FloatingBundle(id: "test.test.1", windowTitles: []),
                        FloatingBundle(id: "test.test.2", windowTitles: ["dialog"]),
                        FloatingBundle(id: "test.test.3", windowTitles: [])
                    ]
                    expect(bundles.count).to(equal(3))
                    expect(bundles).to(equal(expectedBundles))
                }
            }

            describe("set") {
                it("assigns bundles") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let bundles = [
                        FloatingBundle(id: "test.test.1", windowTitles: []),
                        FloatingBundle(id: "test.test.2", windowTitles: ["dialog"]),
                        FloatingBundle(id: "test.test.3", windowTitles: [])
                    ]

                    configuration.setFloatingBundles(bundles)

                    let bundlesData = storage.array(forKey: .floatingBundleIdentifiers).flatMap { JSON($0) }
                    let expectedBundlesData: JSON = JSON([
                        [
                            "id": "test.test.1",
                            "window-titles": []
                        ],
                        [
                            "id": "test.test.2",
                            "window-titles": [
                                "dialog"
                            ]
                        ],
                        [
                            "id": "test.test.3",
                            "window-titles": []
                        ]
                    ])
                    expect(bundlesData).to(equal(expectedBundlesData))
                }
            }
        }

        describe("floating bundles") {
            describe("returned") {
                it("handles both strings and objects") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let bundlesData: [Any] = [
                        // Normal string
                        "test.test.1",
                        // JSON formatted
                        [
                            "id": "test.test.2",
                            "window-titles": [
                                "dialog"
                            ]
                        ],
                        // Another string
                        "test.test.3",
                        // YAML formatted
                        [
                            "test.test.4": [
                                "window-titles": [
                                    "dialog2"
                                ]
                            ]
                        ]
                    ]

                    storage.set(bundlesData, forKey: .floatingBundleIdentifiers)

                    let bundles = configuration.floatingBundles()
                    let expectedBundles = [
                        FloatingBundle(id: "test.test.1", windowTitles: []),
                        FloatingBundle(id: "test.test.2", windowTitles: ["dialog"]),
                        FloatingBundle(id: "test.test.3", windowTitles: []),
                        FloatingBundle(id: "test.test.4", windowTitles: ["dialog2"])
                    ]
                    expect(bundles.count).to(equal(4))
                    expect(bundles).to(equal(expectedBundles))
                }
            }

            describe("set") {
                it("assigns bundles") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let bundles = [
                        FloatingBundle(id: "test.test.1", windowTitles: []),
                        FloatingBundle(id: "test.test.2", windowTitles: ["dialog"]),
                        FloatingBundle(id: "test.test.3", windowTitles: [])
                    ]

                    configuration.setFloatingBundles(bundles)

                    let bundlesData = storage.array(forKey: .floatingBundleIdentifiers).flatMap { JSON($0) }
                    let expectedBundlesData: JSON = JSON([
                        [
                            "id": "test.test.1",
                            "window-titles": []
                        ],
                        [
                            "id": "test.test.2",
                            "window-titles": [
                                "dialog"
                            ]
                        ],
                        [
                            "id": "test.test.3",
                            "window-titles": []
                        ]
                    ])
                    expect(bundlesData).to(equal(expectedBundlesData))
                }
            }
        }
    }
}
