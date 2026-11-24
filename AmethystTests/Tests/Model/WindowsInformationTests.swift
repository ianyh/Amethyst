//
//  WindowsInformationTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 11/12/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Foundation
import Nimble
import Quick

class WindowsInformationTests: QuickSpec {
    override func spec() {
        describe("nearest point of a rect") {
            let rect = CGRect(x: 100, y: -1570, width: 1277, height: 1566)

            it("is the point itself when it lies inside") {
                let inside = CGPoint(x: 500, y: -1000)
                expect(rect.nearestPoint(to: inside)).to(equal(inside))
            }

            it("is the point itself on the edge") {
                let onEdge = CGPoint(x: 100, y: -4)
                expect(rect.nearestPoint(to: onEdge)).to(equal(onEdge))
            }

            it("drops straight down onto the top edge from above") {
                expect(rect.nearestPoint(to: CGPoint(x: 900, y: -1590))).to(equal(CGPoint(x: 900, y: -1570)))
            }

            it("moves sideways onto the nearest side edge") {
                expect(rect.nearestPoint(to: CGPoint(x: 1500, y: -800))).to(equal(CGPoint(x: 1377, y: -800)))
                expect(rect.nearestPoint(to: CGPoint(x: 20, y: -800))).to(equal(CGPoint(x: 100, y: -800)))
            }

            it("is the corner when the point is past both edges") {
                expect(rect.nearestPoint(to: CGPoint(x: -50, y: -1700))).to(equal(CGPoint(x: 100, y: -1570)))
                expect(rect.nearestPoint(to: CGPoint(x: 2000, y: 300))).to(equal(CGPoint(x: 1377, y: -4)))
            }

            it("leaves the point alone for a null rect") {
                let point = CGPoint(x: 5, y: 6)
                expect(CGRect.null.nearestPoint(to: point)).to(equal(point))
            }
        }
    }
}
