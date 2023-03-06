//
//  WindowsInfo.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/5/23.
//  Copyright © 2023 Ian Ynda-Hummel. All rights reserved.
//

import ArgumentParser
import Cocoa
import Foundation
import Silica

struct Windows: ParsableCommand {
    mutating func run() throws {
        let applications = NSWorkspace.shared.runningApplications.map { SIApplication(runningApplication: $0) }
        for application in applications {
            let windows: [SIWindow] = application.windows()
            print(windows)
        }
    }
}
