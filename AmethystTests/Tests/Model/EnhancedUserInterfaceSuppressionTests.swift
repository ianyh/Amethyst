//
//  EnhancedUserInterfaceSuppressionTests.swift
//  AmethystTests
//

@testable import Amethyst
import Foundation
import Nimble
import Quick

class EnhancedUserInterfaceSuppressionTests: QuickSpec {
    override func spec() {
        describe("enhanced user interface suppression") {
            var suppression: EnhancedUserInterfaceSuppression!
            var clears: [pid_t] = []
            var restores: [pid_t] = []

            func begin(_ pid: pid_t, flagWasSet: Bool = true) {
                suppression.begin(for: pid) {
                    clears.append(pid)
                    return flagWasSet
                }
            }

            func end(_ pid: pid_t) {
                suppression.end(for: pid) {
                    restores.append(pid)
                }
            }

            beforeEach {
                suppression = EnhancedUserInterfaceSuppression()
                clears = []
                restores = []
            }

            it("clears the flag for the first window and restores it only after the last window ends") {
                begin(1)
                begin(1)
                expect(clears) == [1]

                end(1)
                expect(restores) == []

                end(1)
                expect(restores) == [1]
            }

            it("leaves an application alone whose flag was not set") {
                begin(1, flagWasSet: false)
                end(1)
                expect(clears) == [1]
                expect(restores) == []
            }

            it("tracks applications independently") {
                begin(1)
                begin(2)
                end(1)
                expect(restores) == [1]

                end(2)
                expect(restores) == [1, 2]
            }

            it("ignores an end without a matching begin") {
                end(1)
                expect(restores) == []

                begin(1)
                end(1)
                end(1)
                expect(clears) == [1]
                expect(restores) == [1]
            }

            it("clears the flag again for a later animation") {
                begin(1)
                end(1)
                begin(1)
                end(1)
                expect(clears) == [1, 1]
                expect(restores) == [1, 1]
            }
        }
    }
}
