//
//  ApplicationAdoptionTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 10/14/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Foundation
import Nimble
import Quick

private struct ObservationFailure: Error {}

/// Drives an adoption by hand: attempts fail a set number of times, and scheduled work is collected instead of run.
private final class AdoptionHarness {
    var attempts = 0
    var delays: [TimeInterval] = []
    var pending: [() -> Void] = []
    var reports: [String] = []
    var finishedCount = 0
    var isRunning = true

    func adoption(failing failuresBeforeSuccess: Int) -> ApplicationAdoption {
        return ApplicationAdoption(
            name: "Test App (pid 1)",
            attempt: { completion in
                self.attempts += 1
                completion(self.attempts <= failuresBeforeSuccess ? ObservationFailure() : nil)
            },
            isRunning: { self.isRunning },
            schedule: { delay, work in
                self.delays.append(delay)
                self.pending.append(work)
            },
            report: { self.reports.append($0) },
            finished: { self.finishedCount += 1 }
        )
    }

    /// Runs every piece of scheduled work in order, including work scheduled while running.
    func runPending() {
        while !pending.isEmpty {
            pending.removeFirst()()
        }
    }
}

class ApplicationAdoptionTests: QuickSpec {
    override func spec() {
        describe("application adoption") {
            it("adopts on the first attempt without waiting") {
                let harness = AdoptionHarness()
                harness.adoption(failing: 0).start()

                expect(harness.attempts).to(equal(1))
                expect(harness.delays).to(beEmpty())
                expect(harness.reports).to(beEmpty())
                expect(harness.finishedCount).to(equal(1))
            }

            it("waits longer before each repeated attempt") {
                let harness = AdoptionHarness()
                harness.adoption(failing: 3).start()
                harness.runPending()

                expect(harness.attempts).to(equal(4))
                expect(harness.delays).to(equal([1, 2, 4]))
                expect(harness.reports.count).to(equal(4))
                expect(harness.reports.last).to(contain("after 3 failed attempts"))
                expect(harness.finishedCount).to(equal(1))
            }

            it("gives up when the waits run out") {
                let harness = AdoptionHarness()
                harness.adoption(failing: .max).start()
                harness.runPending()

                expect(harness.attempts).to(equal(ApplicationAdoption.delays.count + 1))
                expect(harness.delays).to(equal(ApplicationAdoption.delays))
                expect(harness.reports.last).to(beginWith("Gave up observing Test App (pid 1)"))
                expect(harness.finishedCount).to(equal(1))
            }

            it("stops when the application quits") {
                let harness = AdoptionHarness()
                harness.adoption(failing: 1).start()
                harness.isRunning = false
                harness.runPending()

                expect(harness.attempts).to(equal(1))
                expect(harness.reports.last).to(contain("it has quit"))
                expect(harness.finishedCount).to(equal(1))
            }

            it("waits about a minute in all") {
                expect(ApplicationAdoption.delays.reduce(0, +)).to(equal(63))
            }
        }

        describe("window tracking retries") {
            it("start quickly and end with the application adoption waits") {
                expect(windowTrackingDelays.first).to(equal(0))
                expect(Array(windowTrackingDelays.suffix(ApplicationAdoption.delays.count))).to(equal(ApplicationAdoption.delays))
                expect(windowTrackingDelays.reduce(0, +)).to(beCloseTo(68.5, within: 0.01))
            }

            it("stop once the waits are used up") {
                expect(windowTrackingDelay(afterFailures: 0)).to(equal(.milliseconds(0)))
                expect(windowTrackingDelay(afterFailures: windowTrackingDelays.count - 1)).to(equal(.milliseconds(32_000)))
                expect(windowTrackingDelay(afterFailures: windowTrackingDelays.count)).to(beNil())
            }
        }
    }
}
