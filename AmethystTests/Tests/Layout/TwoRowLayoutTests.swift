//
//  TwoRowLayoutTests.swift
//  AmethystTests
//
//  Created by @joelee on 10/21/2022.
//  Copyright © 2022 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class TwoRowLayoutTests: QuickSpec {
    override func spec() {
        afterEach {
            TestScreen.availableScreens = []
        }

        describe("layout") {
            it("separates into a main pane and a secondary pane") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = TwoRowLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(origin: .zero, size: CGSize(width: 2000, height: 680))
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 320),
                    CGRect(x: 1000, y: 0, width: 1000, height: 320)
                ])
            }

            it("handles non-origin screen") {
                let screen = TestScreen(frame: CGRect(x: 100, y: 100, width: 2000, height: 1000))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = TwoRowLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(x: 100, y: 420, width: 2000, height: 680)
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 100, y: 100, width: 1000, height: 320),
                    CGRect(x: 1100, y: 100, width: 1000, height: 320)
                ])
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
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = TwoRowLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 320, width: 2000, height: 680)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 667, height: 320),
                    CGRect(x: 667, y: 0, width: 667, height: 320),
                    CGRect(x: 1334, y: 0, width: 667, height: 320)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(2))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<2])
                secondaryAssignments = frameAssignments.forWindows(windows[2...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 320, width: 1000, height: 680),
                    CGRect(x: 1000, y: 320, width: 1000, height: 680)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 320),
                    CGRect(x: 1000, y: 0, width: 1000, height: 320)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(3))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<3])
                secondaryAssignments = frameAssignments.forWindows(windows[3...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 320, width: 667, height: 680),
                    CGRect(x: 667, y: 320, width: 667, height: 680),
                    CGRect(x: 1334, y: 320, width: 667, height: 680)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 2000, height: 320)
                ])
            }

            it("changes distribution based on pane ratio") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = TwoRowLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 320, width: 2000, height: 680)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 320),
                    CGRect(x: 1000, y: 0, width: 1000, height: 320)
                ])

                layout.recommendMainPaneRatio(0.75)
                expect(layout.mainPaneRatio).to(equal(0.75))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 250, width: 2000, height: 750)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 250),
                    CGRect(x: 1000, y: 0, width: 1000, height: 250)
                ])

                layout.recommendMainPaneRatio(0.25)
                expect(layout.mainPaneRatio).to(equal(0.25))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 750, width: 2000, height: 250)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 750),
                    CGRect(x: 1000, y: 0, width: 1000, height: 750)
                ])
            }
        }

        describe("coding") {
            it("encodes and decodes") {
                let layout = TwoRowLayout<TestWindow>()
                layout.increaseMainPaneCount()
                layout.recommendMainPaneRatio(0.45)

                expect(layout.mainPaneCount).to(equal(2))
                expect(layout.mainPaneRatio).to(equal(0.45))

                let encodedLayout = try! JSONEncoder().encode(layout)
                let decodedLayout = try! JSONDecoder().decode(TwoRowLayout<TestWindow>.self, from: encodedLayout)

                expect(decodedLayout.mainPaneCount).to(equal(2))
                expect(decodedLayout.mainPaneRatio).to(equal(0.45))
            }
        }
    }
}
