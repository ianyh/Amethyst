//
//  DiagnosticLoggingTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 10/30/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import AppKit
import Nimble
import Quick
import SwiftyBeaver

class DiagnosticLoggingTests: QuickSpec {
    override func spec() {
        describe("what is written to the system log") {
            it("is everything when every detail is asked for") {
                expect(DiagnosticLogging.threshold(details: true, warnings: false)).to(equal(.verbose))
                expect(DiagnosticLogging.threshold(details: true, warnings: true)).to(equal(.verbose))
            }

            it("is warnings and errors when only those are asked for") {
                expect(DiagnosticLogging.threshold(details: false, warnings: true)).to(equal(.warning))
            }

            it("is nothing when neither is asked for") {
                expect(DiagnosticLogging.threshold(details: false, warnings: false)).to(beNil())
            }
        }

        describe("the logging preferences") {
            it("ship with warnings and errors on and every detail off") {
                let url = Bundle.main.url(forResource: "default", withExtension: "amethyst")!
                let defaults = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]

                expect(defaults["debug-log-warnings"] as? Bool).to(beTrue())
                expect(defaults["debug-log-details"] as? Bool).to(beFalse())
            }

            it("read back what is set") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                expect(configuration.logsDiagnosticDetails()).to(beFalse())
                expect(configuration.logsWarningsAndErrors()).to(beFalse())

                storage.set(true, forKey: .debugLogDetails)
                configuration.setLogsWarningsAndErrors(true)

                expect(configuration.logsDiagnosticDetails()).to(beTrue())
                expect(configuration.logsWarningsAndErrors()).to(beTrue())
            }
        }

        describe("the Debug preferences pane") {
            it("offers the logging checkboxes and greys the warnings out while every detail is logged") {
                let controller = DebugPreferencesViewController()
                let view = controller.view
                view.layoutSubtreeIfNeeded()

                let checkboxes = view.subviews.compactMap { $0 as? NSButton }
                expect(checkboxes.map { $0.title }).to(contain("All diagnostic details", "Warnings and errors", "About layouts", "Get development builds"))

                let details = checkboxes.first { $0.title == "All diagnostic details" }
                let warnings = checkboxes.first { $0.title == "Warnings and errors" }
                expect(details?.infoForBinding(.value)?[.observedKeyPath] as? String).to(equal("values.debug-log-details"))
                expect(warnings?.infoForBinding(.value)?[.observedKeyPath] as? String).to(equal("values.debug-log-warnings"))
                expect(warnings?.infoForBinding(.enabled)?[.observedKeyPath] as? String).to(equal("values.debug-log-details"))
                expect(view.hasAmbiguousLayout).to(beFalse())
            }
        }
    }
}
