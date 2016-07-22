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
    var storage: [String: AnyObject] = [:]

    func objectForKey(defaultName: String) -> AnyObject? {
        return storage[defaultName]
    }

    func arrayForKey(defaultName: String) -> [AnyObject]? {
        return storage[defaultName] as? [AnyObject]
    }

    func boolForKey(defaultName: String) -> Bool {
        return (storage[defaultName] as? Bool) ?? false
    }

    func floatForKey(defaultName: String) -> Float {
        return (storage[defaultName] as? Float) ?? 0
    }

    func stringArrayForKey(defaultName: String) -> [String]? {
        return storage[defaultName] as? [String]
    }
    
    func setObject(value: AnyObject?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func setBool(value: Bool, forKey defaultName: String) {
        storage[defaultName] = value
    }
}

public class UserConfigurationTests: QuickSpec {
    internal class TestHotKeyRegistrar: HotKeyRegistrar {
        private(set) var keyString: String?
        private(set) var modifiers: AMModifierFlags?
        private(set) var handler: (() -> ())?
        private(set) var defaultsKey: String?
        private(set) var override: Bool?

        init() {}

        internal func registerHotKeyWithKeyString(string: String, modifiers: AMModifierFlags, handler: () -> (), defaultsKey: String, override: Bool) {
            keyString = string
            self.modifiers = modifiers
            self.handler = handler
            self.defaultsKey = defaultsKey
            self.override = override
        }
    }

    internal class TestBundleIdentifiable: BundleIdentifiable {
        var bundleIdentifier: String?
    }

    public override func spec() {
        describe("constructing commands") {
            context("overrides") {
                it("when user configuration exists") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: AnyObject] = [
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
                    let localConfiguration: [String: AnyObject] = [
                        "mod1": [
                            "command"
                        ]
                    ]
                    let defaultConfiguration: [String: AnyObject] = [
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
                    let localConfiguration: [String: AnyObject] = [
                        "mod2": [
                            "command"
                        ]
                    ]
                    let defaultConfiguration: [String: AnyObject] = [
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
                    let localConfiguration: [String: AnyObject] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    let defaultConfiguration: [String: AnyObject] = [
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
                    let defaultConfiguration: [String: AnyObject] = [
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

                storage.setObject([], forKey: "floating")

                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }

            it("floats for exact matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.setObject(["test.test.Test"], forKey: "floating")

                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beTrue())
            }

            it("floats for wildcard matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.setObject(["test.test.*"], forKey: "floating")
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beTrue())
            }

            it("does not float for exact mismatches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.setObject(["test.test.Other"], forKey: "floating")
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }

            it("does not float for wildcard mismatches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                
                storage.setObject(["test.other.*"], forKey: "floating")
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }
        }

        describe("focus follows mouse") {
            it("toggles") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.setBool(true, forKey: "focus-follows-mouse")

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

                storage.setObject(existingLayouts, forKey: ConfigurationKey.Layouts.rawValue)

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
                
                storage.setObject(existingLayouts, forKey: ConfigurationKey.Layouts.rawValue)
                
                expect(configuration.layoutStrings()).to(equal(existingLayouts))
                configuration.configuration = JSON(localConfiguration)
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutStrings()).to(equal(localConfiguration["layouts"]))
            }
        }
    }
}
