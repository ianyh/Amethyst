//
//  TestWindow.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 9/14/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Foundation
import Silica

final class TestWindow: WindowType {
    typealias Screen = TestScreen
    typealias WindowID = String

    static var focused: TestWindow?

    private let element: SIAccessibilityElement?
    private let cgWindowID = CGWindowID(Int.random(in: 1...1000))
    private let uuid = UUID().uuidString
    private var _frame: CGRect = .zero
    var isFocusedValue = false

    static func currentlyFocused() -> Self? {
        return (focused as? Self)
    }

    required init?(element: SIAccessibilityElement?) {
        self.element = element
    }

    func id() -> WindowID {
        return uuid
    }

    func cgID() -> CGWindowID {
        return cgWindowID
    }

    func frame() -> CGRect {
        return _frame
    }

    func screen() -> Screen? {
        return nil
    }

    func setFrame(_ frame: CGRect, withThreshold threshold: CGSize) {
        _frame = frame
    }

    func isFocused() -> Bool {
        return isFocusedValue
    }

    func pid() -> pid_t {
        return pid_t(1234)
    }

    func title() -> String? {
        return nil
    }

    func shouldBeManaged() -> Bool {
        return true
    }

    func shouldFloat() -> Bool {
        return false
    }

    func isActive() -> Bool {
        return true
    }

    func focus() -> Bool {
        return false
    }

    func moveScaled(to screen: Screen) {

    }

    func isOnScreen() -> Bool {
        return true
    }

    func move(toSpace space: UInt) {

    }

    func move(toSpace spaceID: CGSSpaceID) {

    }

    static func == (lhs: TestWindow, rhs: TestWindow) -> Bool {
        return lhs.id() == rhs.id()
    }
}
