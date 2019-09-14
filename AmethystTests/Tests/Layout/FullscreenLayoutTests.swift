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
        describe("layout") {
            it("makes all windows fullscreen") {
                let window1 = TestWindow(element: nil)!
                let window2 = TestWindow(element: nil)!
                let window3 = TestWindow(element: nil)!
                let layout = FullscreenLayout<TestWindow>(windowActivityCache: self)
                let fullscreenOperation = FullscreenReflowOperation(
                    screen: NSScreen.main!,
                    windows: [window1, window2, window3],
                    layout: layout,
                    frameAssigner: Assigner(windowActivityCache: self)
                )

                waitUntil { done in
                    self.operationQueue.addOperation(fullscreenOperation)
                    self.operationQueue.addOperation {
                        done()
                    }
                }

                expect(window1.frame()).to(equal(NSScreen.main!.adjustedFrame()))
                expect(window2.frame()).to(equal(NSScreen.main!.adjustedFrame()))
                expect(window3.frame()).to(equal(NSScreen.main!.adjustedFrame()))
            }
        }
    }
}

extension FullscreenLayoutTests: WindowActivityCache {
    func windowIsFloating<Window>(_ window: Window) -> Bool where Window: WindowType {
        return false
    }

    func windowIsActive<Window>(_ window: Window) -> Bool where Window: WindowType {
        return window.isActive()
    }
}
