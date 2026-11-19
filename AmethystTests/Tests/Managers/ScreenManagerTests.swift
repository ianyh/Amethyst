//
//  ScreenManagerTests.swift
//  AmethystTests
//
//  Created by Ian Ynda-Hummel on 2/11/20.
//  Copyright © 2020 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Nimble
import Quick
import Silica

private final class TestDelegate: ScreenManagerDelegate {
    typealias Window = TestWindow

    func applyWindowLimit(forScreenManager screenManager: ScreenManager<TestDelegate>, minimizingIn range: (Int) -> Range<Int>) {
        fatalError()
    }
    func activeWindowSet(forScreenManager screenManager: ScreenManager<TestDelegate>, on screen: TestScreen) -> WindowSet<TestWindow> {
        fatalError()
    }
    func onReflowInitiation() {
        fatalError()
    }
    func onReflowCompletion() {
        fatalError()
    }
}

class ScreenManagerTests: QuickSpec {
    override func spec() {
        describe("cycling layouts") {
            it("leaves the layout empty when both cycle commands are used") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys([])
                let manager = ScreenManager(screen: TestScreen(), delegate: TestDelegate(), userConfiguration: configuration)
                manager.cycleLayoutForward()
                manager.cycleLayoutBackward()
                expect(manager.currentLayout).to(beNil())
            }
        }

        it("looks up coincident same-app windows by their Core Graphics number") {
            let first = TestWindow(element: nil)!
            let second = TestWindow(element: nil)!
            first.cgWindowID = 101
            second.cgWindowID = 102
            for window in [first, second] {
                let description = [kCGWindowNumber as String: NSNumber(value: window.cgID())]
                expect(WindowsInformation.windowInWindows([first, second], withCGWindowDescription: description)).to(equal(window))
            }
        }

        it("delivers moves to the destination Space even while another Space is active") {
            let configuration = UserConfiguration(storage: TestConfigurationStorage())
            configuration.setLayoutKeys(["bsp"])
            let manager = ScreenManager(screen: TestScreen(), delegate: TestDelegate(), userConfiguration: configuration)
            let first = Space(id: 1, type: CGSSpaceTypeUser, uuid: "first")
            let second = Space(id: 2, type: CGSSpaceTypeUser, uuid: "second")
            let firstWindow = TestWindow(element: nil)!
            let secondWindow = TestWindow(element: nil)!
            let savedFocus = TestWindow.focused
            defer { TestWindow.focused = savedFocus }

            manager.updateSpace(to: first)
            manager.distributeEvent(.add(window: firstWindow), to: first)
            manager.distributeEvent(.add(window: secondWindow), to: second)
            expect(manager.lastFocusedWindow).to(equal(firstWindow))
            TestWindow.focused = firstWindow
            expect(manager.nextWindowIDClockwise()).to(equal(firstWindow.id()))
            manager.updateSpace(to: second)
            expect(manager.nextWindowIDClockwise()).to(beNil())
            TestWindow.focused = secondWindow
            expect(manager.nextWindowIDClockwise()).to(equal(secondWindow.id()))
        }

        it("restores each Space's selected layout after configuration reordering") {
            let configuration = UserConfiguration(storage: TestConfigurationStorage())
            configuration.setLayoutKeys(["tall", "wide", "fullscreen"])
            let manager = ScreenManager(screen: TestScreen(), delegate: TestDelegate(), userConfiguration: configuration)
            let first = Space(id: 1, type: CGSSpaceTypeUser, uuid: "first")
            let second = Space(id: 2, type: CGSSpaceTypeUser, uuid: "second")
            manager.updateSpace(to: first)
            manager.selectLayout("wide")
            manager.updateSpace(to: second)
            manager.selectLayout("fullscreen")
            let data = try JSONEncoder().encode(manager)

            let saved = UserDefaults.standard.object(forKey: ConfigurationKey.layouts.rawValue)
            defer { UserDefaults.standard.set(saved, forKey: ConfigurationKey.layouts.rawValue) }
            UserConfiguration.shared.setLayoutKeys(["fullscreen", "tall", "wide"])
            let restored = try JSONDecoder().decode(ScreenManager<TestDelegate>.self, from: data)
            restored.updateSpace(to: first)
            expect(restored.currentLayout?.layoutKey).to(equal("wide"))
            restored.updateSpace(to: second)
            expect(restored.currentLayout?.layoutKey).to(equal("fullscreen"))

            var legacy = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            legacy.removeValue(forKey: "selectionsBySpaceUUID")
            let legacyData = try JSONSerialization.data(withJSONObject: legacy)
            let old = try JSONDecoder().decode(ScreenManager<TestDelegate>.self, from: legacyData)
            old.updateSpace(to: first)
            expect(old.currentLayout?.layoutKey).to(equal("fullscreen"))
        }

        describe("window tracking") {
            it("forgets destroyed windows even after tab replacement") {
                let windows = TrackedWindows<TestWindow>()
                let closing = TestWindow(element: nil)!
                let remaining = TestWindow(element: nil)!
                windows.add(window: closing, atFront: false)
                windows.setFloating(true, forWindow: closing)
                windows.replace(window: closing, withWindow: remaining)
                windows.rememberMainWindow(closing, on: 1)
                windows.rememberMainWindow(remaining, on: 2)
                windows.rememberMainWindow(closing, on: 3)

                windows.remove(window: closing)

                expect(windows.lastMainWindows[1]).to(beNil())
                expect(windows.lastMainWindows[2]).to(equal(remaining))
                expect(windows.lastMainWindows[3]).to(beNil())
                expect(windows.isWindowFloating(closing)).to(beFalse())
                expect(windows.isWindowTracked(remaining)).to(beTrue())
            }
        }

        describe("coding") {
            it("decodes layouts") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys(LayoutType<TestWindow>.standardLayoutClasses().map { $0.layoutKey })

                let layouts = LayoutType<TestWindow>.standardLayoutClasses().map { $0.init() }
                let encoder = JSONEncoder()
                let encodedLayouts = layouts.map { ["key": $0.layoutKey.data(using: .utf8)!, "data": try! encoder.encode($0)] }
                let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                expect(decodedLayouts.count).to(equal(layouts.count))
                expect(decodedLayouts.count).to(equal(encodedLayouts.count))
                expect(decodedLayouts.map { $0.layoutKey }).to(equal(layouts.map { $0.layoutKey }))
            }

            it("replaces incorrectly encoded layouts") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys([FullscreenLayout<TestWindow>.layoutKey, TallLayout<TestWindow>.layoutKey])

                let encoder = JSONEncoder()
                let encodedLayouts = [
                    ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                    ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(["incorrect": "encoding"])]
                ]
                let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                expect {
                    try JSONDecoder().decode(TallLayout<TestWindow>.self, from: encodedLayouts[1]["data"]!)
                }.to(throwError())

                expect(decodedLayouts.count).to(equal(2))
                expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
            }

            it("replaces incorrectly keyed layouts") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.setLayoutKeys([FullscreenLayout<TestWindow>.layoutKey, TallLayout<TestWindow>.layoutKey])

                let encoder = JSONEncoder()
                let encodedLayouts = [
                    ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                    ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(TallLayout<TestWindow>())]
                ]
                let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                expect(decodedLayouts.count).to(equal(2))
                expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
            }

            context("layout list changes") {
                it("maintains encoded layouts on insertions") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        FullscreenLayout<TestWindow>.layoutKey,
                        WideLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let tallLayout = TallLayout<TestWindow>()
                    tallLayout.increaseMainPaneCount()

                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    expect(decodedLayouts.count).to(equal(3))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
                    expect((decodedLayouts.last as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }

                it("maintains encoded layouts on appends") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        FullscreenLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey,
                        WideLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let tallLayout = TallLayout<TestWindow>()
                    tallLayout.increaseMainPaneCount()

                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    expect(decodedLayouts.count).to(equal(3))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
                    expect((decodedLayouts[1] as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }

                it("maintains encoded layouts on prepends") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        WideLayout<TestWindow>.layoutKey,
                        FullscreenLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let tallLayout = TallLayout<TestWindow>()
                    tallLayout.increaseMainPaneCount()

                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    expect(decodedLayouts.count).to(equal(3))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
                    expect((decodedLayouts.last as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }

                it("maintains existing layouts on deletes") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.setLayoutKeys([
                        WideLayout<TestWindow>.layoutKey,
                        TallLayout<TestWindow>.layoutKey
                    ])

                    let encoder = JSONEncoder()
                    let wideLayout = WideLayout<TestWindow>()
                    let tallLayout = TallLayout<TestWindow>()
                    wideLayout.increaseMainPaneCount()
                    tallLayout.increaseMainPaneCount()

                    expect(wideLayout.mainPaneCount).to(equal(2))
                    expect(tallLayout.mainPaneCount).to(equal(2))

                    let encodedLayouts = [
                        ["key": WideLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(wideLayout)],
                        ["key": FullscreenLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(FullscreenLayout<TestWindow>())],
                        ["key": TallLayout<TestWindow>.layoutKey.data(using: .utf8)!, "data": try! encoder.encode(tallLayout)]
                    ]
                    let decodedLayouts = try! ScreenManager<TestDelegate>.decodedLayouts(from: encodedLayouts, userConfiguration: configuration)

                    expect(decodedLayouts.count).to(equal(2))
                    expect(decodedLayouts.map { $0.layoutKey }).to(equal(configuration.layoutKeys()))
                    expect((decodedLayouts.first as? WideLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                    expect((decodedLayouts.last as? TallLayout<TestWindow>)?.mainPaneCount).to(equal(2))
                }
            }
        }
    }
}
