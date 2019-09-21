//
//  FullscreenLayoutTests.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 9/14/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class FullscreenLayoutTests: QuickSpec {
    private lazy var operationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        return operationQueue
    }()

    override func spec() {
        afterEach {
            TestScreen.availableScreens = []
        }

        describe("layout") {
            it("makes all windows fullscreen") {
                let screen = TestScreen()
                TestScreen.availableScreens = [screen]

                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!, TestWindow(element: nil)!]
                let layoutWindows = windows.map {
                    LayoutWindow(id: $0.windowID(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = FullscreenLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                frameAssignments.forEach { assignment in
                    expect(assignment.frame).to(equal(screen.adjustedFrame()))
                    expect(assignment.finalFrame).to(equal(screen.adjustedFrame()))
                }
            }
        }
    }
}
