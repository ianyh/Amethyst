//
//  CGSpacesInfoTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 10/16/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Foundation
import Nimble
import Quick
import SwiftyJSON

class CGSpacesInfoTests: QuickSpec {
    override func spec() {
        describe("the screen for a Space") {
            let first = TestScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
            let second = TestScreen(frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000))

            func description(of screen: TestScreen, spaces: [Int]) -> JSON {
                return JSON([
                    "Display Identifier": screen.screenID()!,
                    "Current Space": ["ManagedSpaceID": spaces[0], "type": 0],
                    "Spaces": spaces.map { ["ManagedSpaceID": $0, "type": 0] }
                ])
            }

            beforeEach {
                TestScreen.screensHaveSeparateSpaces = true
                TestScreen.availableScreens = [first, second]
                TestScreen.descriptions = [description(of: first, spaces: [11, 12]), description(of: second, spaces: [21, 22])]
            }

            afterEach {
                TestScreen.screensHaveSeparateSpaces = true
                TestScreen.availableScreens = []
                TestScreen.descriptions = []
            }

            it("is the screen of the display that lists the Space") {
                expect(CGSpacesInfo<TestWindow>.screenForSpaceID(12)).to(equal(first))
                expect(CGSpacesInfo<TestWindow>.screenForSpaceID(21)).to(equal(second))
            }

            it("is unknown for a Space no display lists") {
                expect(CGSpacesInfo<TestWindow>.screenForSpaceID(99)).to(beNil())
            }

            it("is unknown when displays share their Spaces") {
                TestScreen.screensHaveSeparateSpaces = false
                expect(CGSpacesInfo<TestWindow>.screenForSpaceID(12)).to(beNil())
            }
        }
    }
}
