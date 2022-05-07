//
//  TwoPaneLayoutTests.swift
//  AmethystTests
//
//  Created by @mwz on 14/06/21.
//  Copyright © 2021 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class TwoPaneLayoutTests: QuickSpec {
    override func spec() {
        afterEach {
            TestScreen.availableScreens = []
        }

        describe("layout horizontal") {
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
                let layout = TwoPaneLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(origin: .zero, size: CGSize(width: 1000, height: 1000))
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000),
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000)
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
                let layout = TwoPaneLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(x: 100, y: 100, width: 1000, height: 1000)
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 1100, y: 100, width: 1000, height: 1000),
                    CGRect(x: 1100, y: 100, width: 1000, height: 1000)
                ])
            }

            it("does not increase and decrease windows in the main pane") {
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
                let layout = TwoPaneLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                let mainAssignments = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000),
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000),
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(1))

                layout.decreaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(1))
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
                let layout = TwoPaneLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000),
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000)
                ])

                layout.recommendMainPaneRatio(0.75)
                expect(layout.mainPaneRatio).to(equal(0.75))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1500, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1500, y: 0, width: 500, height: 1000),
                    CGRect(x: 1500, y: 0, width: 500, height: 1000)
                ])

                layout.recommendMainPaneRatio(0.25)
                expect(layout.mainPaneRatio).to(equal(0.25))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 500, y: 0, width: 1500, height: 1000),
                    CGRect(x: 500, y: 0, width: 1500, height: 1000)
                ])
            }
        }

        describe("layout vertical") {
            it("separates into a main pane and a secondary pane") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 1000, height: 2000)))
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
                let layout = TwoPaneLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(origin: .zero, size: CGSize(width: 1000, height: 1000))
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 1000, width: 1000, height: 1000),
                    CGRect(x: 0, y: 1000, width: 1000, height: 1000)
                ])
            }

            it("handles non-origin screen") {
                let screen = TestScreen(frame: CGRect(x: 100, y: 100, width: 1000, height: 2000))
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
                let layout = TwoPaneLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(x: 100, y: 100, width: 1000, height: 1000)
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 100, y: 1100, width: 1000, height: 1000),
                    CGRect(x: 100, y: 1100, width: 1000, height: 1000)
                ])
            }

            it("does not increase and decrease windows in the main pane") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 1000, height: 2000)))
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
                let layout = TwoPaneLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                let mainAssignments = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 1000, width: 1000, height: 1000),
                    CGRect(x: 0, y: 1000, width: 1000, height: 1000),
                    CGRect(x: 0, y: 1000, width: 1000, height: 1000)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(1))

                layout.decreaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(1))
            }

            it("changes distribution based on pane ratio") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 1000, height: 2000)))
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
                let layout = TwoPaneLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 1000, width: 1000, height: 1000),
                    CGRect(x: 0, y: 1000, width: 1000, height: 1000)
                ])

                layout.recommendMainPaneRatio(0.75)
                expect(layout.mainPaneRatio).to(equal(0.75))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1500)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 1500, width: 1000, height: 500),
                    CGRect(x: 0, y: 1500, width: 1000, height: 500)
                ])

                layout.recommendMainPaneRatio(0.25)
                expect(layout.mainPaneRatio).to(equal(0.25))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 500)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 500, width: 1000, height: 1500),
                    CGRect(x: 0, y: 500, width: 1000, height: 1500)
                ])
            }
        }

        describe("coding") {
            it("encodes and decodes") {
                let layout = TwoPaneLayout<TestWindow>()
                layout.increaseMainPaneCount()
                layout.recommendMainPaneRatio(0.45)

                expect(layout.mainPaneCount).to(equal(1))
                expect(layout.mainPaneRatio).to(equal(0.45))

                let encodedLayout = try! JSONEncoder().encode(layout)
                let decodedLayout = try! JSONDecoder().decode(TwoPaneLayout<TestWindow>.self, from: encodedLayout)

                expect(decodedLayout.mainPaneCount).to(equal(1))
                expect(decodedLayout.mainPaneRatio).to(equal(0.45))
            }
        }
    }
}
