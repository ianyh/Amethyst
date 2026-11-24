//
//  CustomLayoutTests.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 7/8/21.
//  Copyright © 2021 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Cocoa
import Nimble
import Quick

class CustomLayoutTests: QuickSpec {
    override func spec() {
        // The expected frames assume no window margins. The tests run inside the app, where the shared configuration reads the machine's own preferences, so the margin settings are turned off for the duration of each test and put back afterwards.
        let marginKeys = ["window-margins", "window-margin-size", "smart-window-margins"]
        var savedMargins: [String: Any?] = [:]

        beforeEach {
            let defaults = UserDefaults.standard
            for key in marginKeys {
                savedMargins[key] = defaults.object(forKey: key)
                defaults.removeObject(forKey: key)
            }
        }

        afterEach {
            TestScreen.availableScreens = []

            let defaults = UserDefaults.standard
            for key in marginKeys {
                if let value = savedMargins[key] ?? nil {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
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

        describe("scale factor") {
            it("uses a frame's own scale factor and otherwise derives one from the frame") {
                let screen = TestScreen(frame: CGRect(x: 0, y: 0, width: 2000, height: 1000))
                TestScreen.availableScreens = [screen]

                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = CustomLayout<TestWindow>(key: "scale-factor", fileURL: Bundle.layoutFile(key: "scale-factor")!)
                let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                expect(frameAssignments.count).to(equal(2))
                expect(frameAssignments[0].frameAssignment.resizeRules.scaleFactor).to(equal(2))
                expect(frameAssignments[1].frameAssignment.resizeRules.scaleFactor).to(equal(4))
            }
        }

        describe("settings") {
            it("passes layouts exactly the documented settings") {
                let layout = CustomLayout<TestWindow>(key: "resize-step-commands", fileURL: Bundle.layoutFile(key: "resize-step-commands")!)
                let settings = layout.layoutSettings()

                expect(Set(settings.keys)).to(equal(Set(["windowResizeStep", "newWindowsToMain"])))
                expect(settings["windowResizeStep"] as? CGFloat).to(equal(UserConfiguration.shared.windowResizeStep()))
                expect(settings["newWindowsToMain"] as? Bool).to(equal(UserConfiguration.shared.sendNewWindowsToMainPane()))
            }

            it("hands getFrameAssignments the user's choice of where new windows go") {
                let defaults = UserDefaults.standard
                let savedNewWindowsToMain = defaults.object(forKey: "new-windows-to-main")
                defer { defaults.set(savedNewWindowsToMain, forKey: "new-windows-to-main") }

                // A layout that reports the setting through the width it gives every window.
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: directory) }
                let fileURL = directory.appendingPathComponent("settings-reporter.js")
                try! """
                function layout() {
                    return {
                        name: "Settings Reporter",
                        getFrameAssignments: (windows, screenFrame, state, extendedFrames, settings) =>
                            windows.reduce((frames, window) => ({
                                ...frames,
                                [window.id]: { x: 0, y: 0, width: settings.newWindowsToMain ? 200 : 100, height: 100 }
                            }), {})
                    };
                }
                """.write(to: fileURL, atomically: true, encoding: .utf8)

                let screen = TestScreen(frame: CGRect(x: 0, y: 0, width: 2000, height: 1000))
                TestScreen.availableScreens = [screen]

                let windows = [TestWindow(element: nil)!]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = CustomLayout<TestWindow>(key: "settings-reporter", fileURL: fileURL)

                defaults.set(true, forKey: "new-windows-to-main")
                expect(layout.frameAssignments(windowSet, on: screen)?.first?.frameAssignment.frame.width).to(equal(200))

                defaults.set(false, forKey: "new-windows-to-main")
                expect(layout.frameAssignments(windowSet, on: screen)?.first?.frameAssignment.frame.width).to(equal(100))
            }
        }

        describe("resize step") {
            it("hands commands the user's resize step") {
                let defaults = UserDefaults.standard
                let savedStep = defaults.object(forKey: "window-resize-step")
                defaults.set(10, forKey: "window-resize-step")
                defer { defaults.set(savedStep, forKey: "window-resize-step") }

                let screen = TestScreen(frame: CGRect(x: 0, y: 0, width: 2000, height: 1000))
                TestScreen.availableScreens = [screen]

                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let layout = CustomLayout<TestWindow>(key: "resize-step-commands", fileURL: Bundle.layoutFile(key: "resize-step-commands")!)

                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                expect(frameAssignments[0].frameAssignment.frame.width).to(equal(1000))

                layout.expandMainPane()
                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                expect(frameAssignments[0].frameAssignment.frame.width).to(equal(1200))

                layout.shrinkMainPane()
                layout.shrinkMainPane()
                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                expect(frameAssignments[0].frameAssignment.frame.width).to(equal(800))
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

                frameAssignments.verify(frames: expectedFrames)
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
                frameAssignments.verify(frames: expectedFrames)
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

        describe("static ratio tall layout with proxied native commands") {
            it("defines a name") {
                let layout = CustomLayout<TestWindow>(key: "static-ratio-tall-native-commands", fileURL: Bundle.layoutFile(key: "static-ratio-tall-native-commands")!)
                expect(layout.layoutName).to(equal("Static Ratio Tall with Native Commands"))
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
                let layout = CustomLayout<TestWindow>(key: "static-ratio-tall-native-commands", fileURL: Bundle.layoutFile(key: "static-ratio-tall-native-commands")!)
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
                let layout = CustomLayout<TestWindow>(key: "static-ratio-tall-native-commands", fileURL: Bundle.layoutFile(key: "static-ratio-tall-native-commands")!)
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
                let layout = CustomLayout<TestWindow>(key: "static-ratio-tall-native-commands", fileURL: Bundle.layoutFile(key: "static-ratio-tall-native-commands")!)

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

                layout.increaseMainPaneCount()

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

                layout.increaseMainPaneCount()

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

        describe("subset layout") {
            it("defines a name") {
                let layout = CustomLayout<TestWindow>(key: "subset", fileURL: Bundle.layoutFile(key: "subset")!)
                expect(layout.layoutName).to(equal("Subset"))
            }

            describe("subset") {
                it("starts empty") {
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
                    let layout = CustomLayout<TestWindow>(key: "subset", fileURL: Bundle.layoutFile(key: "subset")!)
                    let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                    frameAssignments.verify(frames: [
                        CGRect(x: 1000, y: 0, width: 1000, height: 250),
                        CGRect(x: 1000, y: 250, width: 1000, height: 250),
                        CGRect(x: 1000, y: 500, width: 1000, height: 250),
                        CGRect(x: 1000, y: 750, width: 1000, height: 250)
                    ], inOrder: false)
                }

                it("adds and removes ids to the subset") {
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
                    let layout = CustomLayout<TestWindow>(key: "subset", fileURL: Bundle.layoutFile(key: "subset")!)

                    var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                    frameAssignments.verify(frames: [
                        CGRect(x: 1000, y: 0, width: 1000, height: 250),
                        CGRect(x: 1000, y: 250, width: 1000, height: 250),
                        CGRect(x: 1000, y: 500, width: 1000, height: 250),
                        CGRect(x: 1000, y: 750, width: 1000, height: 250)
                    ])

                    TestWindow.focused = windows[0]
                    layout.command3()
                    TestWindow.focused = windows[3]
                    layout.command3()

                    frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                    frameAssignments.verify(frames: [
                        CGRect(x: 0, y: 0, width: 1000, height: 500),
                        CGRect(x: 1000, y: 0, width: 1000, height: 500),
                        CGRect(x: 1000, y: 500, width: 1000, height: 500),
                        CGRect(x: 0, y: 500, width: 1000, height: 500)
                    ])

                    TestWindow.focused = windows[0]
                    layout.command4()

                    frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                    frameAssignments.verify(frames: [
                        CGRect(x: 1000, y: 0, width: 1000, height: 333),
                        CGRect(x: 1000, y: 333, width: 1000, height: 333),
                        CGRect(x: 1000, y: 666, width: 1000, height: 333),
                        CGRect(x: 0, y: 0, width: 1000, height: 1000)
                    ])

                    TestWindow.focused = windows[3]
                    layout.command4()

                    frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                    frameAssignments.verify(frames: [
                        CGRect(x: 1000, y: 0, width: 1000, height: 250),
                        CGRect(x: 1000, y: 250, width: 1000, height: 250),
                        CGRect(x: 1000, y: 500, width: 1000, height: 250),
                        CGRect(x: 1000, y: 750, width: 1000, height: 250)
                    ])
                }

                it("swaps subset state on window swaps") {
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
                    let layout = CustomLayout<TestWindow>(key: "subset", fileURL: Bundle.layoutFile(key: "subset")!)

                    var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                    frameAssignments.verify(frames: [
                        windows[0].id(): CGRect(x: 1000, y: 0, width: 1000, height: 250),
                        windows[1].id(): CGRect(x: 1000, y: 250, width: 1000, height: 250),
                        windows[2].id(): CGRect(x: 1000, y: 500, width: 1000, height: 250),
                        windows[3].id(): CGRect(x: 1000, y: 750, width: 1000, height: 250)
                    ])

                    TestWindow.focused = windows[0]
                    layout.command3()
                    TestWindow.focused = windows[3]
                    layout.command3()

                    frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                    frameAssignments.verify(frames: [
                        windows[0].id(): CGRect(x: 0, y: 0, width: 1000, height: 500),
                        windows[1].id(): CGRect(x: 1000, y: 0, width: 1000, height: 500),
                        windows[2].id(): CGRect(x: 1000, y: 500, width: 1000, height: 500),
                        windows[3].id(): CGRect(x: 0, y: 500, width: 1000, height: 500)
                    ])

                    layout.updateWithChange(.windowSwap(window: windows[1], otherWindow: windows[0]))

                    frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                    frameAssignments.verify(frames: [
                        windows[0].id(): CGRect(x: 1000, y: 0, width: 1000, height: 500),
                        windows[1].id(): CGRect(x: 0, y: 0, width: 1000, height: 500),
                        windows[2].id(): CGRect(x: 1000, y: 500, width: 1000, height: 500),
                        windows[3].id(): CGRect(x: 0, y: 500, width: 1000, height: 500)
                    ])

                    layout.updateWithChange(.windowSwap(window: windows[3], otherWindow: windows[2]))

                    frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                    frameAssignments.verify(frames: [
                        windows[0].id(): CGRect(x: 1000, y: 0, width: 1000, height: 500),
                        windows[1].id(): CGRect(x: 0, y: 0, width: 1000, height: 500),
                        windows[2].id(): CGRect(x: 0, y: 500, width: 1000, height: 500),
                        windows[3].id(): CGRect(x: 1000, y: 500, width: 1000, height: 500)
                    ])
                }
            }
        }

        describe("extended") {
            describe("tall right") {
                it("swaps columns") {
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
                    let layout = CustomLayout<TestWindow>(key: "extended", fileURL: Bundle.layoutFile(key: "extended")!)
                    let frameAssignments = layout.frameAssignments(windowSet, on: screen)!

                    let mainAssignment = frameAssignments.forWindows(windows[..<1])
                    let secondaryAssignments = frameAssignments.forWindows(windows[1...])

                    mainAssignment.verify(frames: [
                        CGRect(x: 1000, y: 0, width: 1000, height: 1000)
                    ])
                    secondaryAssignments.verify(frames: [
                        CGRect(x: 0, y: 0, width: 1000, height: 500),
                        CGRect(x: 0, y: 500, width: 1000, height: 500)
                    ])
                }
            }
        }

        describe("recommend main pane ratio") {
            it("receives correct ratio") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let window = TestWindow(element: nil)!
                let layoutWindow = LayoutWindow<TestWindow>(id: window.id(), frame: window.frame(), isFocused: false)
                let windowSet = WindowSet<TestWindow>(
                    windows: [layoutWindow],
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { _ in window }
                )
                let layout = CustomLayout<TestWindow>(key: "recommended-main-pane-ratio", fileURL: Bundle.layoutFile(key: "recommended-main-pane-ratio")!)
                var frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                var mainAssignment = frameAssignments.forWindows([window])

                mainAssignment.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000)
                ])

                layout.recommendMainPaneRawRatio(rawRatio: 0.25)
                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignment = frameAssignments.forWindows([window])

                mainAssignment.verify(frames: [
                    CGRect(x: 0, y: 0, width: 500, height: 1000)
                ])

                layout.recommendMainPaneRawRatio(rawRatio: 0.75)
                frameAssignments = layout.frameAssignments(windowSet, on: screen)!
                mainAssignment = frameAssignments.forWindows([window])

                mainAssignment.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1500, height: 1000)
                ])
            }
        }

        describe("coding") {
            var key: String!
            var installedFileURL: URL!

            beforeEach {
                key = "coding-test-\(UUID().uuidString)"
                installedFileURL = try! FileManager.default.layoutFile(key: key)
                try! FileManager.default.copyItem(at: Bundle.layoutFile(key: "fullscreen")!, to: installedFileURL)
            }

            afterEach {
                try? FileManager.default.removeItem(at: installedFileURL)
            }

            it("encodes only the key") {
                let layout = CustomLayout<TestWindow>(key: key, fileURL: installedFileURL)
                let encodedLayout = try! JSONEncoder().encode(layout)
                let json = try! JSONSerialization.jsonObject(with: encodedLayout) as! [String: Any]

                expect(json.keys.sorted()).to(equal(["key"]))
                expect(json["key"] as? String).to(equal(key))
            }

            it("decodes the layout file from the layouts directory") {
                let layout = CustomLayout<TestWindow>(key: key, fileURL: Bundle.layoutFile(key: "fullscreen")!)
                let encodedLayout = try! JSONEncoder().encode(layout)
                let decodedLayout = try! JSONDecoder().decode(CustomLayout<TestWindow>.self, from: encodedLayout)

                expect(decodedLayout.layoutKey).to(equal(key))
                expect(decodedLayout.layoutName).to(equal("Fullscreen"))
            }

            it("ignores a file URL from previously encoded layouts") {
                let staleFileURL = Bundle.layoutFile(key: "undefined")!
                let legacyJSON = try! JSONSerialization.data(withJSONObject: [
                    "key": key!,
                    "fileURL": staleFileURL.absoluteString
                ])
                let decodedLayout = try! JSONDecoder().decode(CustomLayout<TestWindow>.self, from: legacyJSON)

                expect(decodedLayout.layoutKey).to(equal(key))
                expect(decodedLayout.layoutName).to(equal("Fullscreen"))
            }
        }
    }
}
