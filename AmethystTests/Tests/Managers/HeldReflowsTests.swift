//
//  HeldReflowsTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 10/30/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick

class HeldReflowsTests: QuickSpec {
    override func spec() {
        describe("reflows held for the mouse button") {
            it("starts empty") {
                var held = HeldReflows()

                expect(held.isEmpty).to(beTrue())
                expect(held.release()).to(beEmpty())
            }

            it("releases each held screen once, in the order first held") {
                var held = HeldReflows()
                held.hold("second")
                held.hold("first")
                held.hold("second")

                expect(held.isEmpty).to(beFalse())
                expect(held.release()).to(equal(["second", "first"]))
            }

            it("is empty again after a release") {
                var held = HeldReflows()
                held.hold("first")
                _ = held.release()

                expect(held.isEmpty).to(beTrue())
                expect(held.release()).to(beEmpty())
            }
        }
    }
}
