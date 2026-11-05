//
//  LogManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/19/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import os.log
import SwiftyBeaver

let log = SwiftyBeaver.self

/// Writes log lines to the unified system log under the app's bundle identifier, in the category `diagnostics`.
final class SystemLogDestination: BaseDestination {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.amethyst.Amethyst"

    private let systemLog = OSLog(subsystem: SystemLogDestination.subsystem, category: "diagnostics")

    override init() {
        super.init()
        // The system log stamps every line with the time, so a line carries only the level, the source and the message.
        format = "$L $N.$F:$l - $M"
    }

    override func send(
        _ level: SwiftyBeaver.Level,
        msg: String,
        thread: String,
        file: String,
        function: String,
        line: Int,
        context: Any? = nil
    ) -> String? {
        let formatted = super.send(level, msg: msg, thread: thread, file: file, function: function, line: line, context: context)
        if let formatted = formatted {
            os_log("%{public}s", log: systemLog, type: level == .error ? .error : .default, formatted)
        }
        return formatted
    }
}

/// Connects the system log destination according to the Debug preferences and the `--log` argument, and follows the preferences as they change.
final class DiagnosticLogging {
    static let shared = DiagnosticLogging()

    private var destination: SystemLogDestination?
    private var commandLineRequestsDetails = false
    private var preferencesObserver: NSObjectProtocol?

    /// The lowest level worth writing for the preferences, or nil when nothing is to be written.
    static func threshold(details: Bool, warnings: Bool) -> SwiftyBeaver.Level? {
        if details {
            return .verbose
        }
        if warnings {
            return .warning
        }
        return nil
    }

    func start(commandLineRequestsDetails: Bool) {
        self.commandLineRequestsDetails = commandLineRequestsDetails
        if preferencesObserver == nil {
            preferencesObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.apply()
            }
        }
        apply()
    }

    private func apply() {
        let configuration = UserConfiguration.shared

        // Every detail includes the warnings and errors, and the preference says so.
        if configuration.logsDiagnosticDetails(), !configuration.logsWarningsAndErrors() {
            configuration.setLogsWarningsAndErrors(true)
        }

        let threshold = DiagnosticLogging.threshold(
            details: commandLineRequestsDetails || configuration.logsDiagnosticDetails(),
            warnings: configuration.logsWarningsAndErrors()
        )

        switch (threshold, destination) {
        case let (level?, connected?):
            connected.minLevel = level
        case let (level?, nil):
            let connected = SystemLogDestination()
            connected.minLevel = level
            log.addDestination(connected)
            destination = connected
        case let (nil, connected?):
            log.removeDestination(connected)
            destination = nil
        case (nil, nil):
            break
        }
    }
}
