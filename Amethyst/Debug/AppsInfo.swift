//
//  AppsInfo.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/9/23.
//  Copyright © 2023 Ian Ynda-Hummel. All rights reserved.
//

import ArgumentParser
import Cocoa
import Silica

struct Apps: ParsableCommand {
    @Flag(help: "Include unmanaged applications.")
    var includeUnmanaged = false

    mutating func run() throws {
        let applications = NSWorkspace.shared.runningApplications
        for application in applications where includeUnmanaged || application.isManageable == .manageable {
            let app = SIApplication(runningApplication: application)
            print("""
            Title: \(app.title() ?? "<no title>")
            Bundle Identifier: \(application.bundleIdentifier ?? "<no id>")
            Activation Policy: \(application.activationPolicy)
            pid: \(app.pid())
            Manageable: \(application.isManageable)

            """)
        }
    }
}
