//
//  SystemLogDestinationTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 10/30/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
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
    }
}
