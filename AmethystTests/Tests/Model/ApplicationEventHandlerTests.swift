//
//  ApplicationEventHandlerTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 11/10/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Carbon
import Foundation
import Nimble
import Quick

/// Records what the handler asks of its delegate.
private final class RecordingDelegate: ApplicationEventHandlerDelegate {
    var added: [pid_t] = []
    var removed: [pid_t] = []
    var sweeps = 0

    func add(applicationWithPID pid: pid_t) {
        added.append(pid)
    }

    func remove(applicationWithPID pid: pid_t) {
        removed.append(pid)
    }

    func removeTerminatedApplications() {
        sweeps += 1
    }
}

class ApplicationEventHandlerTests: QuickSpec {
    override func spec() {
        describe("application events") {
            /// Hands the handler a Carbon application event for the given process serial number and returns its status.
            func handle(_ kind: Int, psn: ProcessSerialNumber, with delegate: RecordingDelegate) -> OSStatus {
                var event: EventRef?
                expect(CreateEvent(nil, UInt32(kEventClassApplication), UInt32(kind), 0, EventAttributes(kEventAttributeNone), &event)).to(equal(noErr))
                var psn = psn
                expect(SetEventParameter(event!, EventParamName(kEventParamProcessID), EventParamType(typeProcessSerialNumber), MemoryLayout<ProcessSerialNumber>.size, &psn)).to(equal(noErr))
                defer { ReleaseEvent(event!) }

                return ApplicationEventHandler(delegate: delegate).handleEvent(event!)
            }

            let thisProcess = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
            let noProcess = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kNoProcess))

            it("names the application that exited while the system still knows its process") {
                let delegate = RecordingDelegate()

                expect(handle(kEventAppTerminated, psn: thisProcess, with: delegate)).to(equal(noErr))

                expect(delegate.removed).to(equal([getpid()]))
                expect(delegate.sweeps).to(equal(0))
                expect(delegate.added).to(beEmpty())
            }

            it("has every tracked application checked when the exited process is already gone") {
                let delegate = RecordingDelegate()

                expect(handle(kEventAppTerminated, psn: noProcess, with: delegate)).to(equal(noErr))

                expect(delegate.sweeps).to(equal(1))
                expect(delegate.removed).to(beEmpty())
                expect(delegate.added).to(beEmpty())
            }

            it("names the application that launched") {
                let delegate = RecordingDelegate()

                expect(handle(kEventAppLaunched, psn: thisProcess, with: delegate)).to(equal(noErr))

                expect(delegate.added).to(equal([getpid()]))
                expect(delegate.removed).to(beEmpty())
                expect(delegate.sweeps).to(equal(0))
            }

            it("leaves the delegate alone when a launched process is already gone") {
                let delegate = RecordingDelegate()

                expect(handle(kEventAppLaunched, psn: noProcess, with: delegate)).to(equal(OSStatus(eventNotHandledErr)))

                expect(delegate.added).to(beEmpty())
                expect(delegate.removed).to(beEmpty())
                expect(delegate.sweeps).to(equal(0))
            }
        }
    }
}
