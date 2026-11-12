//
//  LaunchedApplicationLookup.swift
//  Amethyst
//
//  Created by Don Patterson on 11/12/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa

/**
 Finds the application for a process that has just launched.

 The system can report a launch a moment before it lists the new process as an application, so a lookup made as soon as the launch is reported can come back empty for a process that is alive and about to be listed. An empty lookup is repeated after a short wait, longer each time, until one succeeds, the process exits, or the waits run out.

 A lookup keeps itself alive while a repeated attempt is pending, so the caller does not need to hold on to it.
 */
final class LaunchedApplicationLookup {
    /// How a lookup ended.
    enum Outcome: Equatable {
        /// The application, and how many lookups came back empty before it was listed.
        case found(NSRunningApplication, emptyLookups: Int)
        /// The process exited before it was listed as an application.
        case processExited
        /// The process is alive but was never listed as an application.
        case notListed
    }

    /// The wait before each repeated lookup, in seconds.
    static let delays: [TimeInterval] = [0.1, 0.4, 0.9, 1.6]

    private let pid: pid_t
    private let lookUp: (pid_t) -> NSRunningApplication?
    private let isProcessAlive: (pid_t) -> Bool
    private let schedule: (_ delay: TimeInterval, _ work: @escaping () -> Void) -> Void
    private let completion: (Outcome) -> Void
    private var emptyLookups = 0

    /**
     - Parameters:
         - pid: The process to find the application for.
         - lookUp: Returns the application for a process, or `nil` while the system does not list one. The default asks the system.
         - isProcessAlive: Whether a process is still running. The default asks the kernel.
         - schedule: Runs work after a delay. The default waits on the main queue.
         - completion: Receives the outcome once, when the lookups stop.
     */
    init(
        pid: pid_t,
        lookUp: @escaping (pid_t) -> NSRunningApplication? = { NSRunningApplication(processIdentifier: $0) },
        isProcessAlive: @escaping (pid_t) -> Bool = LaunchedApplicationLookup.isProcessAlive,
        schedule: @escaping (_ delay: TimeInterval, _ work: @escaping () -> Void) -> Void = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        },
        completion: @escaping (Outcome) -> Void
    ) {
        self.pid = pid
        self.lookUp = lookUp
        self.isProcessAlive = isProcessAlive
        self.schedule = schedule
        self.completion = completion
    }

    /// Makes the first lookup.
    func start() {
        attempt()
    }

    private func attempt() {
        if let runningApplication = lookUp(pid) {
            completion(.found(runningApplication, emptyLookups: emptyLookups))
            return
        }

        guard isProcessAlive(pid) else {
            completion(.processExited)
            return
        }

        guard emptyLookups < Self.delays.count else {
            completion(.notListed)
            return
        }

        let delay = Self.delays[emptyLookups]
        emptyLookups += 1
        schedule(delay) {
            self.attempt()
        }
    }

    /// Whether the kernel has a process with this pid, whoever owns it.
    static func isProcessAlive(_ pid: pid_t) -> Bool {
        return kill(pid, 0) == 0 || errno == EPERM
    }
}
