//
//  HotKeyManagerTests.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 4/18/17.
//  Copyright © 2017 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick

final class HotKeyManagerTests: QuickSpec {
    override func spec() {
        describe("hotKeyNameToDefaultsKey") {
            it("respects screen count") {
                let keyMapping = HotKeyManager.hotKeyNameToDefaultsKey(screenCount: 4)
                let screenCommands = keyMapping.filter { $0[1].hasPrefix(CommandKey.focusScreenPrefix.rawValue) }
                expect(screenCommands.count).to(equal(4))
            }
        }
    }
}
