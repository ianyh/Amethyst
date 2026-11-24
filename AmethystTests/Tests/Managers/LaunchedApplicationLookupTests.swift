//
//  LaunchedApplicationLookupTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 11/12/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Cocoa
import Nimble
import Quick

/// Drives a lookup by hand: a set number of lookups come back empty, and scheduled work is collected instead of run.
private final class LookupHarness {
    var lookups = 0
    var delays: [TimeInterval] = []
    var pending: [() -> Void] = []
    var outcomes: [LaunchedApplicationLookup.Outcome] = []
    var isProcessAlive = true

    func lookup(listedAfter emptyLookups: Int) -> LaunchedApplicationLookup {
        return LaunchedApplicationLookup(
            pid: 1,
            lookUp: { _ in
                self.lookups += 1
                return self.lookups > emptyLookups ? NSRunningApplication.current : nil
            },
            isProcessAlive: { _ in self.isProcessAlive },
            schedule: { delay, work in
                self.delays.append(delay)
                self.pending.append(work)
            },
            completion: { self.outcomes.append($0) }
        )
    }

    /// Runs every piece of scheduled work in order, including work scheduled while running.
    func runPending() {
        while !pending.isEmpty {
            pending.removeFirst()()
        }
    }
}

class LaunchedApplicationLookupTests: QuickSpec {
    override func spec() {
        describe("launched application lookup") {
            it("finds a listed application at once") {
                let harness = LookupHarness()
                harness.lookup(listedAfter: 0).start()

                expect(harness.lookups).to(equal(1))
                expect(harness.delays).to(beEmpty())
                expect(harness.outcomes).to(equal([.found(NSRunningApplication.current, emptyLookups: 0)]))
            }

            it("waits longer before each repeated lookup until the application is listed") {
                let harness = LookupHarness()
                harness.lookup(listedAfter: 2).start()
                harness.runPending()

                expect(harness.lookups).to(equal(3))
                expect(harness.delays).to(equal([0.1, 0.4]))
                expect(harness.outcomes).to(equal([.found(NSRunningApplication.current, emptyLookups: 2)]))
            }

            it("gives up once the waits run out") {
                let harness = LookupHarness()
                harness.lookup(listedAfter: .max).start()
                harness.runPending()

                expect(harness.lookups).to(equal(LaunchedApplicationLookup.delays.count + 1))
                expect(harness.delays).to(equal(LaunchedApplicationLookup.delays))
                expect(harness.outcomes).to(equal([.notListed]))
            }

            it("stops when the process exits") {
                let harness = LookupHarness()
                harness.lookup(listedAfter: .max).start()
                harness.isProcessAlive = false
                harness.runPending()

                expect(harness.lookups).to(equal(2))
                expect(harness.delays).to(equal([0.1]))
                expect(harness.outcomes).to(equal([.processExited]))
            }

            it("knows the current process is alive") {
                expect(LaunchedApplicationLookup.isProcessAlive(ProcessInfo.processInfo.processIdentifier)).to(beTrue())
            }
        }
    }
}
