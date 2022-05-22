//
//  TestScreen.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 9/14/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Foundation
import SwiftyJSON

final class TestScreen: ScreenType {
    static var availableScreens: [TestScreen] = []
    static var screensHaveSeparateSpaces = true

    static func screenDescriptions() -> [JSON]? {
        return []
    }

    private let id: String = UUID().uuidString
    private let internalFrame: CGRect

    init(frame: CGRect) {
        internalFrame = frame
    }

    convenience init() {
        let frame = CGRect(x: 0, y: 0, width: round(CGFloat.random(in: 500...2000)), height: round(CGFloat.random(in: 500...2000)))
        self.init(frame: frame)
    }

    func adjustedFrame(disableWindowMargins: Bool) -> CGRect {
        return internalFrame
    }

    func frameIncludingDockAndMenu() -> CGRect {
        return internalFrame
    }

    func frameWithoutDockOrMenu() -> CGRect {
        return internalFrame
    }

    func frame() -> CGRect {
        return internalFrame
    }

    func screenID() -> String? {
        return id
    }

    func focusScreen() {

    }

    static func == (lhs: TestScreen, rhs: TestScreen) -> Bool {
        return lhs.id == rhs.id
    }
}
