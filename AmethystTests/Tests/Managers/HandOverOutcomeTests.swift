//
//  HandOverOutcomeTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 10/30/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick

class HandOverOutcomeTests: QuickSpec {
    override func spec() {
        describe("a move notification for a tiled window") {
            func decide(mouseButtonsArePressed: Bool = false, screenID: String? = "second", previousScreenID: String? = "first") -> HandOverOutcome {
                return HandOverOutcome.decide(
                    mouseButtonsArePressed: mouseButtonsArePressed,
                    currentScreenID: { screenID },
                    previousScreenID: { previousScreenID }
                )
            }

            it("hands a released window over to the screen it now lies on") {
                expect(decide()).to(equal(.move(fromScreen: "first", toScreen: "second")))
            }

            it("checks again while the mouse button is down") {
                expect(decide(mouseButtonsArePressed: true)).to(equal(.checkAgain))
            }

            it("leaves a window on the screen whose layout holds it") {
                expect(decide(screenID: "first")).to(equal(.stay))
            }

            it("leaves a window no layout has placed or whose screen is unknown") {
                expect(decide(previousScreenID: nil)).to(equal(.stay))
                expect(decide(screenID: nil)).to(equal(.stay))
            }

            it("looks up no screen while the mouse button is down") {
                var lookups = 0
                let outcome = HandOverOutcome.decide(
                    mouseButtonsArePressed: true,
                    currentScreenID: { () -> String? in
                        lookups += 1
                        return "second"
                    },
                    previousScreenID: { () -> String? in
                        lookups += 1
                        return "first"
                    }
                )

                expect(outcome).to(equal(.checkAgain))
                expect(lookups).to(equal(0))
            }
        }
    }
}
