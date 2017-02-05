//
//  UserConfigurationTests.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Nimble
import Quick

@testable import Amethyst

import SwiftyJSON

private class TestConfigurationStorage: ConfigurationStorage {
    var storage: [String: Any] = [:]

    fileprivate func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }

    fileprivate func array(forKey defaultName: String) -> [Any]? {
        return storage[defaultName] as? [Any]
    }

    fileprivate func bool(forKey defaultName: String) -> Bool {
        return (storage[defaultName] as? Bool) ?? false
    }

    fileprivate func float(forKey defaultName: String) -> Float {
        return (storage[defaultName] as? Float) ?? 0
    }

    fileprivate func stringArray(forKey defaultName: String) -> [String]? {
        return storage[defaultName] as? [String]
    }
    
    fileprivate func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    fileprivate func set(_ value: Bool, forKey defaultName: String) {
        storage[defaultName] = value as AnyObject?
    }
}

public class UserConfigurationTests: QuickSpec {
    private class TestHotKeyRegistrar: HotKeyRegistrar {
        fileprivate private(set) var keyString: String?
        fileprivate private(set) var modifiers: AMModifierFlags?
        fileprivate private(set) var handler: (() -> ())?
        fileprivate private(set) var defaultsKey: String?
        fileprivate private(set) var override: Bool?

        fileprivate init() {}

        fileprivate func registerHotKey(with string: String, modifiers: AMModifierFlags, handler: @escaping () -> (), defaultsKey: String, override: Bool) {
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

    public override func spec() {
        describe("constructing commands") {
            context("overrides") {
                it("when user configuration exists") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configuration = JSON(localConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    let registrar = TestHotKeyRegistrar()

                    configuration.constructCommandWithHotKeyRegistrar(registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())
                }

                it("when custom mod1 is specified") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
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
                    configuration.configuration = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    let registrar = TestHotKeyRegistrar()

                    configuration.constructCommandWithHotKeyRegistrar(registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())
                }

                it("when custom mod2 is specified") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
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
                    configuration.configuration = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])
                    
                    let registrar = TestHotKeyRegistrar()
                    
                    configuration.constructCommandWithHotKeyRegistrar(registrar, commandKey: "test", handler: {})
                    
                    expect(registrar.override).to(beTrue())
                }
            }

            context("takes command") {
                it("from local configuration over default") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
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
                    configuration.configuration = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    let registrar = TestHotKeyRegistrar()

                    configuration.constructCommandWithHotKeyRegistrar(registrar, commandKey: "test", handler: {})

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
                    configuration.configuration = JSON([:])
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])
                    
                    let registrar = TestHotKeyRegistrar()
                    
                    configuration.constructCommandWithHotKeyRegistrar(registrar, commandKey: "test", handler: {})

                    expect(configuration.defaultConfiguration?["test"]["key"].string).to(equal("1"))
                    expect(registrar.keyString).to(equal("1"))
                }
            }
        }

        describe("floating application") {
            it("is not floating by default") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set([], forKey: "floating")

                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }

            it("floats for exact matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.set(["test.test.Test"], forKey: "floating")

                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beTrue())
            }

            it("floats for wildcard matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.set(["test.test.*"], forKey: "floating")
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beTrue())
            }

            it("does not float for exact mismatches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.set(["test.test.Other"], forKey: "floating")
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }

            it("does not float for wildcard mismatches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.set(["test.other.*"], forKey: "floating")
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }
        }

        describe("focus follows mouse") {
            it("toggles") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: "focus-follows-mouse")

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

                storage.set(existingLayouts, forKey: ConfigurationKey.Layouts.rawValue)

                expect(configuration.layoutStrings()).to(equal(existingLayouts))
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutStrings()).to(equal(existingLayouts))
            }

            it("local configuration does override existing configuration") {
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
                
                storage.set(existingLayouts, forKey: ConfigurationKey.Layouts.rawValue)
                
                expect(configuration.layoutStrings()).to(equal(existingLayouts))
                configuration.configuration = JSON(localConfiguration)
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutStrings()).to(equal(localConfiguration["layouts"]))
            }

            describe("screen count") {
                it("favors explicit config") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let localConfiguration = ["screens": 2]
                    let defaultConfiguration = ["screens": 1]
                    
                    configuration.configuration = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    
                    expect(configuration.screenCount()).to(equal(2))
                }

                it("falls back on default if no explicit config exists") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let defaultConfiguration = ["screens": 1]

                    configuration.configuration = JSON([:])
                    configuration.defaultConfiguration = JSON(defaultConfiguration)

                    expect(configuration.screenCount()).to(equal(1))
                }

                it("converts strings if necessary") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let localConfiguration = ["screens": "3"]
                    let defaultConfiguration = ["screens": 1]
                    
                    configuration.configuration = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    
                    expect(configuration.screenCount()).to(equal(3))
                }
            }
        }
    }
}
