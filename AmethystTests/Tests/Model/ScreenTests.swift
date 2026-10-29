//
//  ScreenTests.swift
//  AmethystTests
//
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Foundation
import Nimble
import Quick

class ScreenTests: QuickSpec {
    override func spec() {
        describe("converting a point from Cocoa coordinates") {
            afterEach {
                TestScreen.availableScreens = []
            }

            it("flips a point on a single screen") {
                TestScreen.availableScreens = [TestScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 800))]

                expect(TestScreen.convertFromCocoa(CGPoint(x: 100, y: 700))).to(equal(CGPoint(x: 100, y: 100)))
            }

            context("with screens offset above and below the primary screen") {
                // A 3200x1800 primary, a laptop to its right sitting 324pt lower at the top,
                // and a 2160x1920 portrait screen to its left extending 768pt below the primary.
                let primary = TestScreen(frame: CGRect(x: 0, y: 0, width: 3200, height: 1800))
                let laptop = TestScreen(frame: CGRect(x: 3200, y: 324, width: 1512, height: 982))
                let portrait = TestScreen(frame: CGRect(x: -2160, y: 648, width: 2160, height: 1920))

                beforeEach {
                    TestScreen.availableScreens = [laptop, primary, portrait]
                }

                it("maps the primary screen's center onto itself") {
                    let point = TestScreen.convertFromCocoa(CGPoint(x: 1600, y: 900))

                    expect(point).to(equal(CGPoint(x: 1600, y: 900)))
                    expect(primary.frameIncludingDockAndMenu().contains(point)).to(beTrue())
                }

                it("maps a point on a screen above the primary's bottom edge onto that screen") {
                    let point = TestScreen.convertFromCocoa(CGPoint(x: 3956, y: 985))

                    expect(point).to(equal(CGPoint(x: 3956, y: 815)))
                    expect(laptop.frameIncludingDockAndMenu().contains(point)).to(beTrue())
                }

                it("maps a point below the primary screen onto the screen that extends below it") {
                    let point = TestScreen.convertFromCocoa(CGPoint(x: -1080, y: -192))

                    expect(point).to(equal(CGPoint(x: -1080, y: 1992)))
                    expect(portrait.frameIncludingDockAndMenu().contains(point)).to(beTrue())
                }
            }
        }
    }
}
