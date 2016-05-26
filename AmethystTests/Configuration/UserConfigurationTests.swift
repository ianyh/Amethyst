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
                    let configuration = UserConfiguration()
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
                    let configuration = UserConfiguration()
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
                    let configuration = UserConfiguration()
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
                    let configuration = UserConfiguration()
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
                    let configuration = UserConfiguration()
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
            afterEach() {
                NSUserDefaults.standardUserDefaults().removeObjectForKey("floating")
            }

            it("is not floating by default") {
                let configuration = UserConfiguration()
                let userDefaults = NSUserDefaults.standardUserDefaults()

                userDefaults.setObject([], forKey: "floating")

                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }

            it("floats for exact matches") {
                let configuration = UserConfiguration()
                let userDefaults = NSUserDefaults.standardUserDefaults()
                
                userDefaults.setObject(["test.test.Test"], forKey: "floating")

                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beTrue())
            }

            it("floats for wildcard matches") {
                let configuration = UserConfiguration()
                let userDefaults = NSUserDefaults.standardUserDefaults()
                
                userDefaults.setObject(["test.test.*"], forKey: "floating")
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beTrue())
            }

            it("does not float for exact mismatches") {
                let configuration = UserConfiguration()
                let userDefaults = NSUserDefaults.standardUserDefaults()
                
                userDefaults.setObject(["test.test.Other"], forKey: "floating")
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }

            it("does not float for wildcard mismatches") {
                let configuration = UserConfiguration()
                let userDefaults = NSUserDefaults.standardUserDefaults()
                
                userDefaults.setObject(["test.other.*"], forKey: "floating")
                
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"
                
                expect(configuration.runningApplicationShouldFloat(bundleIdentifiable)).to(beFalse())
            }
        }

        describe("focus follows mouse") {
            it("toggles") {
                let configuration = UserConfiguration()
                let userDefaults = NSUserDefaults.standardUserDefaults()

                userDefaults.setBool(true, forKey: "focus-follows-mouse")

                expect(configuration.focusFollowsMouse()).to(beTrue())

                configuration.toggleFocusFollowsMouse()

                expect(configuration.focusFollowsMouse()).to(beFalse())
            }
        }
    }
}
