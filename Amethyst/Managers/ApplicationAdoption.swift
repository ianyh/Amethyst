//
//  ApplicationAdoption.swift
//  Amethyst
//
//  Created by Don Patterson on 10/14/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import os.log

/// Log for how applications and their windows come under management: adoption attempts, the waits between them, the reasons they fail, and windows that float by default.
let applicationLog = OSLog(subsystem: "com.amethyst.Amethyst", category: "applications")

/**
 Repeats an attempt to bring an application under management until it succeeds.

 Registering Accessibility observers on an application fails while the application is not answering Accessibility requests, which is common in the first seconds after it launches. Each failed attempt is reported and followed by a longer wait, about a minute in all. The attempts stop as soon as one succeeds, when the application quits, or when the waits run out.

 An adoption keeps itself alive while a repeated attempt is pending, so the caller does not need to hold on to it.
 */
final class ApplicationAdoption {
    /// The wait before each repeated attempt, in seconds.
    static let delays: [TimeInterval] = [1, 2, 4, 8, 16, 32]

    private let name: String
    private let attempt: (_ completion: @escaping (Error?) -> Void) -> Void
    private let isRunning: () -> Bool
    private let schedule: (_ delay: TimeInterval, _ work: @escaping () -> Void) -> Void
    private let report: (String) -> Void
    private let finished: () -> Void
    private var failures = 0

    /**
     - Parameters:
         - name: How the application is named in reports.
         - attempt: Makes one attempt and passes `nil` to its completion on success, or the error on failure.
         - isRunning: Whether the application is still running. A repeated attempt is skipped once it is not.
         - schedule: Runs work after a delay. The default waits on the main queue.
         - report: Receives one line per failure, give-up, late success, or quit. The default writes to the unified log.
         - finished: Called once, when the attempts stop for any reason.
     */
    init(
        name: String,
        attempt: @escaping (_ completion: @escaping (Error?) -> Void) -> Void,
        isRunning: @escaping () -> Bool,
        schedule: @escaping (_ delay: TimeInterval, _ work: @escaping () -> Void) -> Void = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        },
        report: @escaping (String) -> Void = { message in
            os_log("%{public}@", log: applicationLog, type: .default, message)
        },
        finished: @escaping () -> Void = {}
    ) {
        self.name = name
        self.attempt = attempt
        self.isRunning = isRunning
        self.schedule = schedule
        self.report = report
        self.finished = finished
    }

    /// Makes the first attempt.
    func start() {
        attempt { error in
            self.handle(error)
        }
    }

    private func handle(_ error: Error?) {
        guard let error = error else {
            if failures > 0 {
                report("Observing \(name) after \(failures) failed attempt\(failures == 1 ? "" : "s")")
            }
            finished()
            return
        }

        failures += 1

        guard failures <= Self.delays.count else {
            report("Gave up observing \(name) after \(failures) attempts: \(error)")
            finished()
            return
        }

        let delay = Self.delays[failures - 1]
        report("Could not observe \(name) on attempt \(failures): \(error); trying again in \(Int(delay))s")
        schedule(delay) {
            guard self.isRunning() else {
                self.report("Stopped trying to observe \(self.name): it has quit")
                self.finished()
                return
            }

            self.attempt { error in
                self.handle(error)
            }
        }
    }
}
