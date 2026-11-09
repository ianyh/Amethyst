//
//  SystemLogDestinationTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 10/30/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Foundation
import Nimble
import Quick
import Security
import SwiftyBeaver

class SystemLogDestinationTests: QuickSpec {
    override func spec() {
        // AppKit views are made on the main thread, which is not where a test body runs.
        func onMainThread(_ work: () -> Void) {
            if Thread.isMainThread {
                work()
            } else {
                DispatchQueue.main.sync(execute: work)
            }
        }

        // A stand-in for the file macOS writes when a logging profile for the app is installed.
        func loggingOptions(privateData: Bool) -> URL {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("logging-options-\(UUID().uuidString).plist")
            let options: NSDictionary = ["DEFAULT-OPTIONS": ["Enable-Private-Data": privateData]]
            options.write(to: url, atomically: true)
            return url
        }

        describe("a line for the system log") {
            it("carries the level, the source and the message, and no time of its own") {
                let destination = SystemLogDestination()
                let line = destination.send(
                    .debug,
                    msg: "Adding window",
                    thread: "",
                    file: "/Users/someone/Amethyst/Managers/WindowManager.swift",
                    function: "add(window:)",
                    line: 536
                )

                expect(line).to(equal("DEBUG WindowManager.add(window:):536 - Adding window"))
            }

            it("is written under the app's bundle identifier") {
                expect(SystemLogDestination.subsystem).to(equal("com.amethyst.Amethyst"))
            }
        }

        describe("a window in a log line") {
            it("names the process, the window and its frame, and never the title") {
                let text = windowLogDescription(pid: 4821, windowID: 318, frame: CGRect(x: 0, y: 0, width: 1280, height: 800))

                expect(text).to(equal("pid 4821, window 318, frame 0,0 1280x800"))
            }

            it("says when the frame is unknown") {
                let text = windowLogDescription(pid: 4821, windowID: 318, frame: .null)

                expect(text).to(equal("pid 4821, window 318, frame unknown"))
            }

            it("hands the title over as private data beside the text") {
                let window = TestWindow(element: nil)!
                window.windowTitle = "Quarterly report.xlsx"

                let fields = SystemLogDestination.fields(text: "Adding window: pid 1234", context: PrivateWindowTitle(of: window))

                expect(fields.text).to(equal("Adding window: pid 1234"))
                expect(fields.privateTitle).to(equal("Quarterly report.xlsx"))
            }

            it("joins the titles when a line names two windows") {
                let first = TestWindow(element: nil)!
                first.windowTitle = "One"
                let second = TestWindow(element: nil)!
                second.windowTitle = "Two"

                let fields = SystemLogDestination.fields(text: "Windows are the same", context: PrivateWindowTitle(of: first, second))

                expect(fields.privateTitle).to(equal("One / Two"))
            }

            it("adds no private field when the window has no title or the line names no window") {
                let window = TestWindow(element: nil)!

                expect(SystemLogDestination.fields(text: "line", context: PrivateWindowTitle(of: window)).privateTitle).to(beNil())
                expect(SystemLogDestination.fields(text: "line", context: nil).privateTitle).to(beNil())
            }

            it("reads the title only when the line is written") {
                let window = TestWindow(element: nil)!
                let title = PrivateWindowTitle(of: window)
                window.windowTitle = "Set after the line was queued"

                expect(title.title).to(equal("Set after the line was queued"))
            }
        }

        describe("the system's logging options") {
            it("are looked for under the app's subsystem") {
                expect(SystemLogDestination.optionsURL.path).to(equal("/Library/Preferences/Logging/Subsystems/com.amethyst.Amethyst.plist"))
            }

            it("show private data only when a file turns it on") {
                let missing = FileManager.default.temporaryDirectory.appendingPathComponent("logging-options-\(UUID().uuidString).plist")
                let turnedOn = loggingOptions(privateData: true)
                let turnedOff = loggingOptions(privateData: false)
                defer {
                    try? FileManager.default.removeItem(at: turnedOn)
                    try? FileManager.default.removeItem(at: turnedOff)
                }

                expect(SystemLogDestination.showsPrivateData(optionsAt: missing)).to(beFalse())
                expect(SystemLogDestination.showsPrivateData(optionsAt: turnedOn)).to(beTrue())
                expect(SystemLogDestination.showsPrivateData(optionsAt: turnedOff)).to(beFalse())
            }
        }

        describe("the Debug tab") {
            it("offers the profile only while something is written to the system log") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                var title: String?
                var enabledWhileOff: Bool?
                var enabledWhileWarningsOn: Bool?
                var enabledWhileDetailsOn: Bool?
                onMainThread {
                    let controller = DebugPreferencesViewController(nibName: "DebugPreferencesViewController", bundle: nil)
                    controller.configuration = configuration
                    controller.loggingOptionsURL = FileManager.default.temporaryDirectory.appendingPathComponent("logging-options-\(UUID().uuidString).plist")
                    _ = controller.view

                    storage.set(false, forKey: .debugLogDetails)
                    storage.set(false, forKey: .debugLogWarnings)
                    controller.updateRevealWindowTitlesButton()
                    title = controller.revealWindowTitlesButton?.title
                    enabledWhileOff = controller.revealWindowTitlesButton?.isEnabled

                    storage.set(true, forKey: .debugLogWarnings)
                    controller.updateRevealWindowTitlesButton()
                    enabledWhileWarningsOn = controller.revealWindowTitlesButton?.isEnabled

                    storage.set(false, forKey: .debugLogWarnings)
                    storage.set(true, forKey: .debugLogDetails)
                    controller.updateRevealWindowTitlesButton()
                    enabledWhileDetailsOn = controller.revealWindowTitlesButton?.isEnabled
                }

                expect(title).to(equal("Reveal Window Titles in System Logs"))
                expect(enabledWhileOff).to(beFalse())
                expect(enabledWhileWarningsOn).to(beTrue())
                expect(enabledWhileDetailsOn).to(beTrue())
            }

            it("offers to hide the titles while the profile is installed, whatever is being logged") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                let options = loggingOptions(privateData: true)

                var titleWhileInstalled: String?
                var noteWhileInstalled: String?
                var enabledWhileInstalled: Bool?
                var titleOnceRemoved: String?
                var noteOnceRemoved: String?
                var enabledOnceRemoved: Bool?
                onMainThread {
                    let controller = DebugPreferencesViewController(nibName: "DebugPreferencesViewController", bundle: nil)
                    controller.configuration = configuration
                    controller.loggingOptionsURL = options
                    _ = controller.view

                    storage.set(false, forKey: .debugLogDetails)
                    storage.set(false, forKey: .debugLogWarnings)
                    controller.updateRevealWindowTitlesButton()
                    titleWhileInstalled = controller.revealWindowTitlesButton?.title
                    noteWhileInstalled = controller.revealWindowTitlesNote?.stringValue
                    enabledWhileInstalled = controller.revealWindowTitlesButton?.isEnabled

                    try? FileManager.default.removeItem(at: options)
                    controller.updateRevealWindowTitlesButton()
                    titleOnceRemoved = controller.revealWindowTitlesButton?.title
                    noteOnceRemoved = controller.revealWindowTitlesNote?.stringValue
                    enabledOnceRemoved = controller.revealWindowTitlesButton?.isEnabled
                }

                expect(titleWhileInstalled).to(equal("Hide Window Titles in System Logs"))
                expect(noteWhileInstalled).to(contain("remove the profile"))
                expect(enabledWhileInstalled).to(beTrue())
                expect(titleOnceRemoved).to(equal("Reveal Window Titles in System Logs"))
                expect(noteOnceRemoved).to(contain("<private>"))
                expect(enabledOnceRemoved).to(beFalse())
            }

            it("explains how to remove the profile and offers to open System Settings") {
                var text: String?
                var buttons: [String]?
                onMainThread {
                    let controller = DebugPreferencesViewController(nibName: "DebugPreferencesViewController", bundle: nil)
                    let alert = controller.removalInstructions()
                    text = alert.informativeText
                    buttons = alert.buttons.map { $0.title }
                }

                expect(text).to(contain(DebugPreferencesViewController.profileName))
                expect(buttons).to(equal(["Open System Settings", "Cancel"]))
            }
        }

        describe("the pane the button opens") {
            it("is System Settings' profiles pane") {
                let pane = DebugPreferencesViewController.profilesPaneURL

                expect(pane?.scheme).to(equal("x-apple.systempreferences"))
                expect(pane?.absoluteString).to(contain("Profiles"))
            }
        }

        describe("the profile that reveals window titles") {
            // A release build signs the profile, which wraps the property list in a CMS envelope.
            func profileContents(of data: Data) -> Data? {
                if (try? PropertyListSerialization.propertyList(from: data, format: nil)) != nil {
                    return data
                }

                var decoder: CMSDecoder?
                guard CMSDecoderCreate(&decoder) == errSecSuccess, let decoder = decoder else {
                    return nil
                }

                let updated = data.withUnsafeBytes { bytes -> OSStatus in
                    guard let base = bytes.baseAddress else {
                        return errSecParam
                    }
                    return CMSDecoderUpdateMessage(decoder, base, data.count)
                }
                guard updated == errSecSuccess, CMSDecoderFinalizeMessage(decoder) == errSecSuccess else {
                    return nil
                }

                var contents: CFData?
                guard CMSDecoderCopyContent(decoder, &contents) == errSecSuccess else {
                    return nil
                }
                return contents as Data?
            }

            it("is bundled with the app and turns on private data for the app's log lines only") {
                guard let url = Bundle.main.url(forResource: "RevealWindowTitles", withExtension: "mobileconfig"),
                      let data = try? Data(contentsOf: url),
                      let contents = profileContents(of: data),
                      let profile = (try? PropertyListSerialization.propertyList(from: contents, format: nil)) as? [String: Any],
                      let payloads = profile["PayloadContent"] as? [[String: Any]],
                      let logging = payloads.first,
                      let subsystems = logging["Subsystems"] as? [String: [String: Any]],
                      let options = subsystems[SystemLogDestination.subsystem]?["DEFAULT-OPTIONS"] as? [String: Any] else {
                    fail("the profile is missing from the bundle or not in the expected shape")
                    return
                }

                expect(profile["PayloadDisplayName"] as? String).to(equal(DebugPreferencesViewController.profileName))
                expect(profile["PayloadType"] as? String).to(equal("Configuration"))
                expect(profile["PayloadScope"] as? String).to(equal("System"))
                expect(payloads.count).to(equal(1))
                expect(logging["PayloadType"] as? String).to(equal("com.apple.system.logging"))
                expect(Array(subsystems.keys)).to(equal([SystemLogDestination.subsystem]))
                expect(options["Enable-Private-Data"] as? Bool).to(beTrue())
            }
        }
    }
}
