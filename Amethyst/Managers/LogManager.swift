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
