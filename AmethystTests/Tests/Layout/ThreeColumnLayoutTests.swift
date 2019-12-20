//
//  ThreeColumnLayoutTests.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 12/19/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

class ThreeColumnLayoutTests: QuickSpec {
    override func spec() {
        afterEach {
            TestScreen.availableScreens = []
        }

        describe("TriplePaneArrangement") {
            describe("pane counts") {
                it("takes windows in main pane up to provided count") {
                    let mainPaneCount: UInt = 2
                    let screenSize = CGSize(width: 2000, height: 1000)
                    let count: (UInt) -> UInt = { windowCount -> UInt in
                        return TriplePaneArrangement(
                            mainPane: .left,
                            numWindows: windowCount,
                            numMainPane: mainPaneCount,
                            screenSize: screenSize,
                            mainPaneRatio: 0.5
                        ).count(.main)
                    }

                    expect(count(1)).to(equal(1))
                    expect(count(2)).to(equal(2))
                    expect(count(4)).to(equal(2))
                }

                it("splits non-main windows between two panes") {
                    let mainPaneCount: UInt = 0
                    let screenSize = CGSize(width: 2000, height: 1000)
                    let secondaryCount: (UInt) -> UInt = { windowCount -> UInt in
                        return TriplePaneArrangement(
                            mainPane: .left,
                            numWindows: windowCount,
                            numMainPane: mainPaneCount,
                            screenSize: screenSize,
                            mainPaneRatio: 0.5
                        ).count(.secondary)
                    }
                    let tertiaryCount: (UInt) -> UInt = { windowCount -> UInt in
                        return TriplePaneArrangement(
                            mainPane: .left,
                            numWindows: windowCount,
                            numMainPane: mainPaneCount,
                            screenSize: screenSize,
                            mainPaneRatio: 0.5
                        ).count(.tertiary)
                    }

                    expect(secondaryCount(1)).to(equal(1))
                    expect(secondaryCount(2)).to(equal(1))
                    expect(secondaryCount(3)).to(equal(2))
                    expect(secondaryCount(4)).to(equal(2))

                    expect(tertiaryCount(1)).to(equal(0))
                    expect(tertiaryCount(2)).to(equal(1))
                    expect(tertiaryCount(3)).to(equal(1))
                    expect(tertiaryCount(4)).to(equal(2))
                }
            }

            it("splits panes into rows") {
                let mainPaneCount: UInt = 2
                let screenSize = CGSize(width: 2000, height: 1000)
                let height: (UInt, Pane) -> CGFloat = { windowCount, pane -> CGFloat in
                    return TriplePaneArrangement(
                        mainPane: .left,
                        numWindows: windowCount,
                        numMainPane: mainPaneCount,
                        screenSize: screenSize,
                        mainPaneRatio: 0.5
                    ).height(pane)
                }

                expect(height(1, .main)).to(equal(1000))
                expect(height(2, .main)).to(equal(500))
                expect(height(3, .main)).to(equal(500))
                expect(height(1, .secondary)).to(equal(0))
                expect(height(2, .secondary)).to(equal(0))
                expect(height(3, .secondary)).to(equal(1000))
                expect(height(4, .secondary)).to(equal(1000))
                expect(height(5, .secondary)).to(equal(500))
                expect(height(6, .secondary)).to(equal(500))
                expect(height(1, .tertiary)).to(equal(0))
                expect(height(2, .tertiary)).to(equal(0))
                expect(height(3, .tertiary)).to(equal(0))
                expect(height(4, .tertiary)).to(equal(1000))
                expect(height(5, .tertiary)).to(equal(1000))
                expect(height(6, .tertiary)).to(equal(500))
            }
        }

        describe("middle layout") {
            it("separates into a main pane and two secondary panes") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow(id: $0.windowID(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = ThreeColumnMiddleLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(x: 500, y: 0, width: 1000, height: 1000)
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 1000),
                    CGRect(x: 1500, y: 0, width: 500, height: 1000)
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
                    LayoutWindow(id: $0.windowID(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = ThreeColumnMiddleLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 500, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 500),
                    CGRect(x: 0, y: 500, width: 500, height: 500),
                    CGRect(x: 1500, y: 0, width: 500, height: 1000)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(2))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<2])
                secondaryAssignments = frameAssignments.forWindows(windows[2...])

                mainAssignments.verify(frames: [
                    CGRect(x: 500, y: 0, width: 1000, height: 500),
                    CGRect(x: 500, y: 500, width: 1000, height: 500)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 1000),
                    CGRect(x: 1500, y: 0, width: 500, height: 1000)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(3))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<3])
                secondaryAssignments = frameAssignments.forWindows(windows[3...])

                mainAssignments.verify(frames: [
                    CGRect(x: 500, y: 0, width: 1000, height: 333),
                    CGRect(x: 500, y: 333, width: 1000, height: 333),
                    CGRect(x: 500, y: 666, width: 1000, height: 333)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 1000)
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
                    LayoutWindow(id: $0.windowID(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = ThreeColumnMiddleLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 500, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 1000),
                    CGRect(x: 1500, y: 0, width: 500, height: 1000)
                ])

                layout.recommendMainPaneRatio(0.75)
                expect(layout.mainPaneRatio).to(equal(0.75))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 250, y: 0, width: 1500, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 250, height: 1000),
                    CGRect(x: 1750, y: 0, width: 250, height: 1000)
                ])

                layout.recommendMainPaneRatio(0.25)
                expect(layout.mainPaneRatio).to(equal(0.25))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 750, y: 0, width: 500, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 750, height: 1000),
                    CGRect(x: 1250, y: 0, width: 750, height: 1000)
                ])
            }
        }

        describe("left layout") {
            it("separates into a main pane and two secondary panes") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow(id: $0.windowID(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = ThreeColumnLeftLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000)
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 500, height: 1000),
                    CGRect(x: 1500, y: 0, width: 500, height: 1000)
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
                    LayoutWindow(id: $0.windowID(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = ThreeColumnLeftLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 500, height: 500),
                    CGRect(x: 1000, y: 500, width: 500, height: 500),
                    CGRect(x: 1500, y: 0, width: 500, height: 1000)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(2))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<2])
                secondaryAssignments = frameAssignments.forWindows(windows[2...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 500),
                    CGRect(x: 0, y: 500, width: 1000, height: 500)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 500, height: 1000),
                    CGRect(x: 1500, y: 0, width: 500, height: 1000)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(3))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<3])
                secondaryAssignments = frameAssignments.forWindows(windows[3...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 333),
                    CGRect(x: 0, y: 333, width: 1000, height: 333),
                    CGRect(x: 0, y: 666, width: 1000, height: 333)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 500, height: 1000)
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
                    LayoutWindow(id: $0.windowID(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = ThreeColumnLeftLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 500, height: 1000),
                    CGRect(x: 1500, y: 0, width: 500, height: 1000)
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
                    CGRect(x: 1500, y: 0, width: 250, height: 1000),
                    CGRect(x: 1750, y: 0, width: 250, height: 1000)
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
                    CGRect(x: 500, y: 0, width: 750, height: 1000),
                    CGRect(x: 1250, y: 0, width: 750, height: 1000)
                ])
            }
        }

        describe("right layout") {
            it("separates into a main pane and two secondary panes") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow(id: $0.windowID(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = ThreeColumnRightLayout<TestWindow>()
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(layout.mainPaneCount).to(equal(1))

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000)
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 1000),
                    CGRect(x: 500, y: 0, width: 500, height: 1000)
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
                    LayoutWindow(id: $0.windowID(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = ThreeColumnRightLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 500),
                    CGRect(x: 0, y: 500, width: 500, height: 500),
                    CGRect(x: 500, y: 0, width: 500, height: 1000)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(2))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<2])
                secondaryAssignments = frameAssignments.forWindows(windows[2...])

                mainAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 500),
                    CGRect(x: 1000, y: 500, width: 1000, height: 500)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 1000),
                    CGRect(x: 500, y: 0, width: 500, height: 1000)
                ])

                layout.increaseMainPaneCount()
                expect(layout.mainPaneCount).to(equal(3))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<3])
                secondaryAssignments = frameAssignments.forWindows(windows[3...])

                mainAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 333),
                    CGRect(x: 1000, y: 333, width: 1000, height: 333),
                    CGRect(x: 1000, y: 666, width: 1000, height: 333)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 1000)
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
                    LayoutWindow(id: $0.windowID(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.windowID() == id } }
                )
                let layout = ThreeColumnRightLayout<TestWindow>()

                expect(layout.mainPaneCount).to(equal(1))

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 1000),
                    CGRect(x: 500, y: 0, width: 500, height: 1000)
                ])

                layout.recommendMainPaneRatio(0.75)
                expect(layout.mainPaneRatio).to(equal(0.75))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 500, y: 0, width: 1500, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 250, height: 1000),
                    CGRect(x: 250, y: 0, width: 250, height: 1000)
                ])

                layout.recommendMainPaneRatio(0.25)
                expect(layout.mainPaneRatio).to(equal(0.25))

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<1])
                secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 1500, y: 0, width: 500, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 750, height: 1000),
                    CGRect(x: 750, y: 0, width: 750, height: 1000)
                ])
            }
        }
    }
}
