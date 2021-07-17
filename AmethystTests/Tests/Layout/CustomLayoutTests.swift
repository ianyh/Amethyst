//
//  CustomLayoutTests.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 7/8/21.
//  Copyright © 2021 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick

class CustomLayoutTests: QuickSpec {
    override func spec() {
        afterEach {
            TestScreen.availableScreens = []
        }

        describe("undefined layout") {
            it("defines a name") {
                let layout = CustomLayout<TestWindow>(key: "undefined", fileURL: Bundle.layoutFile(key: "undefined")!)
                expect(layout.layoutName).to(equal("Undefined"))
            }

            it("defines no frame assignments") {
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
                let layout = CustomLayout<TestWindow>(key: "undefined", fileURL: Bundle.layoutFile(key: "undefined")!)

                expect(layout.frameAssignments(windowSet, on: screen)).to(beNil())
            }
        }

        describe("null layout") {
            it("defines a name") {
                let layout = CustomLayout<TestWindow>(key: "null", fileURL: Bundle.layoutFile(key: "null")!)
                expect(layout.layoutName).to(equal("Null"))
            }

            it("defines no frame assignments") {
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
                let layout = CustomLayout<TestWindow>(key: "null", fileURL: Bundle.layoutFile(key: "null")!)

                expect(layout.frameAssignments(windowSet, on: screen)).to(beNil())
            }
        }

        describe("fullscreen layout") {
            it("defines a name") {
                let layout = CustomLayout<TestWindow>(key: "fullscreen", fileURL: Bundle.layoutFile(key: "fullscreen")!)
                expect(layout.layoutName).to(equal("Fullscreen"))
            }

            it("makes all windows fullscreen") {
                let screen = TestScreen()
                TestScreen.availableScreens = [screen]

                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!, TestWindow(element: nil)!]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = CustomLayout<TestWindow>(key: "fullscreen", fileURL: Bundle.layoutFile(key: "fullscreen")!)
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(frameAssignments.count).to(equal(layoutWindows.count))

                frameAssignments.forEach { assignment in
                    expect(assignment.frameAssignment.frame).to(equal(screen.adjustedFrame()))
                    expect(assignment.frameAssignment.finalFrame).to(equal(screen.adjustedFrame()))
                }
            }

            it("handles non-origin screen") {
                let screen = TestScreen(frame: CGRect(x: 100, y: 100, width: 2000, height: 1000))
                TestScreen.availableScreens = [screen]

                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!, TestWindow(element: nil)!]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = CustomLayout<TestWindow>(key: "fullscreen", fileURL: Bundle.layoutFile(key: "fullscreen")!)
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(frameAssignments.count).to(equal(layoutWindows.count))

                frameAssignments.forEach { assignment in
                    expect(assignment.frameAssignment.frame).to(equal(screen.adjustedFrame()))
                    expect(assignment.frameAssignment.finalFrame).to(equal(screen.adjustedFrame()))
                }
            }
        }

        describe("columns layout") {
            it("defines a name") {
                let layout = CustomLayout<TestWindow>(key: "uniform-columns", fileURL: Bundle.layoutFile(key: "uniform-columns")!)
                expect(layout.layoutName).to(equal("Uniform Columns"))
            }

            it("puts windows in uniform columns") {
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
                let layout = CustomLayout<TestWindow>(key: "uniform-columns", fileURL: Bundle.layoutFile(key: "uniform-columns")!)
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(frameAssignments.count).to(equal(layoutWindows.count))

                let expectedFrames = [
                    CGRect(x: 0, y: 0, width: 500, height: 1000),
                    CGRect(x: 500, y: 0, width: 500, height: 1000),
                    CGRect(x: 1000, y: 0, width: 500, height: 1000),
                    CGRect(x: 1500, y: 0, width: 500, height: 1000)
                ]

                zip(frameAssignments.map { $0.frameAssignment.frame }, expectedFrames).forEach {
                    expect($0).to(equal($1))
                }
            }

            it("handles non-origin screen") {
                let screen = TestScreen(frame: CGRect(x: 100, y: 100, width: 2000, height: 1000))
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
                let layout = CustomLayout<TestWindow>(key: "uniform-columns", fileURL: Bundle.layoutFile(key: "uniform-columns")!)
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(frameAssignments.count).to(equal(layoutWindows.count))

                let expectedFrames = [
                    CGRect(x: 100, y: 100, width: 500, height: 1000),
                    CGRect(x: 600, y: 100, width: 500, height: 1000),
                    CGRect(x: 1100, y: 100, width: 500, height: 1000),
                    CGRect(x: 1600, y: 100, width: 500, height: 1000)
                ]

                zip(frameAssignments.map { $0.frameAssignment.frame }, expectedFrames).forEach {
                    expect($0).to(equal($1))
                }
            }
        }

        describe("static ratio tall layout") {
            it("defines a name") {
                let layout = CustomLayout<TestWindow>(key: "static-ratio-tall", fileURL: Bundle.layoutFile(key: "static-ratio-tall")!)
                expect(layout.layoutName).to(equal("Static Ratio Tall"))
            }

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
                let layout = CustomLayout<TestWindow>(key: "static-ratio-tall", fileURL: Bundle.layoutFile(key: "static-ratio-tall")!)
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(origin: .zero, size: CGSize(width: 1000, height: 1000))
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 500),
                    CGRect(x: 1000, y: 500, width: 1000, height: 500)
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
                let layout = CustomLayout<TestWindow>(key: "static-ratio-tall", fileURL: Bundle.layoutFile(key: "static-ratio-tall")!)
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                let mainAssignment = frameAssignments.forWindows(windows[..<1])
                let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignment.verify(frames: [
                    CGRect(x: 100, y: 100, width: 1000, height: 1000)
                ])
                secondaryAssignments.verify(frames: [
                    CGRect(x: 1100, y: 100, width: 1000, height: 500),
                    CGRect(x: 1100, y: 600, width: 1000, height: 500)
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
                let layout = CustomLayout<TestWindow>(key: "static-ratio-tall", fileURL: Bundle.layoutFile(key: "static-ratio-tall")!)

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignments = frameAssignments.forWindows(windows[..<1])
                var secondaryAssignments = frameAssignments.forWindows(windows[1...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 333),
                    CGRect(x: 1000, y: 333, width: 1000, height: 333),
                    CGRect(x: 1000, y: 666, width: 1000, height: 333)
                ])

                layout.command3()

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<2])
                secondaryAssignments = frameAssignments.forWindows(windows[2...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 500),
                    CGRect(x: 0, y: 500, width: 1000, height: 500)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 500),
                    CGRect(x: 1000, y: 500, width: 1000, height: 500)
                ])

                layout.command3()

                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignments = frameAssignments.forWindows(windows[..<3])
                secondaryAssignments = frameAssignments.forWindows(windows[3...])

                mainAssignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 333),
                    CGRect(x: 0, y: 333, width: 1000, height: 333),
                    CGRect(x: 0, y: 666, width: 1000, height: 333)
                ])

                secondaryAssignments.verify(frames: [
                    CGRect(x: 1000, y: 0, width: 1000, height: 1000)
                ])
            }
        }
    }
}
