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
import SwiftyBeaver

class SystemLogDestinationTests: QuickSpec {
    override func spec() {
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

        describe("the profile that reveals window titles") {
            it("is bundled with the app and turns on private data for the app's log lines only") {
                guard let url = Bundle.main.url(forResource: "RevealWindowTitles", withExtension: "mobileconfig"),
                      let data = try? Data(contentsOf: url),
                      let profile = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
                      let payloads = profile["PayloadContent"] as? [[String: Any]],
                      let logging = payloads.first,
                      let subsystems = logging["Subsystems"] as? [String: [String: Any]],
                      let options = subsystems[SystemLogDestination.subsystem]?["DEFAULT-OPTIONS"] as? [String: Any] else {
                    fail("the profile is missing from the bundle or not in the expected shape")
                    return
                }

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
