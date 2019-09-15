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

    lazy var internalFrame: CGRect = {
        return CGRect(x: 0, y: 0, width: CGFloat.random(in: 500...2000), height: CGFloat.random(in: 500...2000))
    }()

    func adjustedFrame() -> CGRect {
        return internalFrame
    }

    func frameIncludingDockAndMenu() -> CGRect {
        return internalFrame
    }

    func frameWithoutDockOrMenu() -> CGRect {
        return internalFrame
    }

    func screenIdentifier() -> String? {
        return id
    }

    func focusScreen() {

    }

    static func == (lhs: TestScreen, rhs: TestScreen) -> Bool {
        return lhs.id == rhs.id
    }
}
