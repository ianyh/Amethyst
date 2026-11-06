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
        describe("layout HUD") {
            func screenManager(with configuration: UserConfiguration, layoutKey: String = "tall") -> ScreenManager<TestDelegate> {
                configuration.setLayoutKeys([layoutKey])
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                return ScreenManager<TestDelegate>(screen: screen, delegate: TestDelegate(), userConfiguration: configuration)
            }

            it("names the layout and leaves the description empty while tiling is enabled") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                let content = screenManager(with: configuration).layoutHUDContent()

                expect(content.title).to(equal("Tall"))
                expect(content.description).to(equal(""))
            }

            it("shows the layout's own description only when the About layouts debug option is on") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                expect(screenManager(with: configuration, layoutKey: "bsp").layoutHUDContent().description).to(equal(""))

                storage.set(true, forKey: .debugLayoutInfo)
                expect(screenManager(with: configuration, layoutKey: "bsp").layoutHUDContent().description).toNot(beEmpty())
            }

            it("says that tiling is disabled under the layout name, whatever the debug option says") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                configuration.tilingEnabled = false

                var content = screenManager(with: configuration, layoutKey: "bsp").layoutHUDContent()
                expect(content.title).to(equal("Binary Space Partitioning"))
                expect(content.description).to(equal("Tiling Disabled"))

                storage.set(true, forKey: .debugLayoutInfo)
                content = screenManager(with: configuration, layoutKey: "bsp").layoutHUDContent()
                expect(content.description).to(equal("Tiling Disabled"))
            }
        }

        describe("layout HUD window") {
            // AppKit allows windows and views to be touched on the main thread only, and the examples may run elsewhere.
            func onMainThread(_ work: () -> Void) {
                if Thread.isMainThread {
                    work()
                } else {
                    DispatchQueue.main.sync(execute: work)
                }
            }

            func descriptionLine(after title: String, description: String) -> (hidden: Bool?, text: String?) {
                var result: (hidden: Bool?, text: String?) = (nil, nil)
                onMainThread {
                    guard let window = LayoutNameWindowController(windowNibName: "LayoutNameWindow").window as? LayoutNameWindow else {
                        return
                    }
                    window.displayNotification(title: title, description: description)
                    result = (window.layoutDescriptionLabel?.isHidden, window.layoutDescriptionLabel?.stringValue)
                }
                return result
            }

            it("hides the description line when there is nothing to say") {
                let line = descriptionLine(after: "Tall", description: "")

                expect(line.hidden).to(beTrue())
            }

            it("shows the description line when there is something to say") {
                let line = descriptionLine(after: "Tall", description: "Tiling Disabled")

                expect(line.hidden).to(beFalse())
                expect(line.text).to(equal("Tiling Disabled"))
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
