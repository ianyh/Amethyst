//
//  RowLayoutTests.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 9/21/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class RowLayoutTests: QuickSpec {
    override func spec() {
        afterEach {
            TestScreen.availableScreens = []
        }

        describe("layout") {
            it("separates windows into rows in main pane and rows in secondary pane") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map { LayoutWindow(id: $0.windowID(), frame: $0.frame()) }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = RowLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                // The main pane is full width and the top half of the screen
                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [CGRect(origin: .zero, size: CGSize(width: 2000, height: 500))])

                let secondaryFrames = secondaryAssignments.enumerated().map { index, _ in
                    return CGRect(x: 0, y: 500.0 + 166 * CGFloat(index), width: 2000, height: 166)
                }

                secondaryAssignments.verify(frames: secondaryFrames)
            }

            it("increases and decreases windows in the main pane") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map { LayoutWindow(id: $0.windowID(), frame: $0.frame()) }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = RowLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 2000, height: 500)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 500, width: 2000, height: 166),
                    CGRect(x: 0, y: 666, width: 2000, height: 166),
                    CGRect(x: 0, y: 832, width: 2000, height: 166)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(2))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<2])
                secondaryAssignments = frameAssignments.forWindows(windows[2...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 2000, height: 250),
                    CGRect(x: 0, y: 250, width: 2000, height: 250)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 500, width: 2000, height: 250),
                    CGRect(x: 0, y: 750, width: 2000, height: 250)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(3))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<3])
                secondaryAssignments = frameAssignments.forWindows(windows[3...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 2000, height: 166),
                    CGRect(x: 0, y: 166, width: 2000, height: 166),
                    CGRect(x: 0, y: 332, width: 2000, height: 166)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 498, width: 2000, height: 500)
                ])
            }

            it("changes distribution based on pane ratio") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map { LayoutWindow(id: $0.windowID(), frame: $0.frame()) }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = RowLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 2000, height: 500)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 500, width: 2000, height: 166),
                    CGRect(x: 0, y: 666, width: 2000, height: 166),
                    CGRect(x: 0, y: 832, width: 2000, height: 166)
                ])

                layout.recommendMainPaneRatio(0.75)
                expect(layout.mainPaneRatio).to(equal(0.75))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 2000, height: 750)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 750, width: 2000, height: 83),
                    CGRect(x: 0, y: 833, width: 2000, height: 83),
                    CGRect(x: 0, y: 916, width: 2000, height: 83)
                ])

                layout.recommendMainPaneRatio(0.25)
                expect(layout.mainPaneRatio).to(equal(0.25))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 2000, height: 250)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 250, width: 2000, height: 250),
                    CGRect(x: 0, y: 500, width: 2000, height: 250),
                    CGRect(x: 0, y: 750, width: 2000, height: 250)
                ])
            }
        }
    }
}
