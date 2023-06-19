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

extension AXWindow {
    func debugInfo(redactTitles: Bool) -> String {
        let screenDescription = screen().map { AMScreen(screen: $0).debugDescription() }

        return """
        \tTitle: \(redactTitles ? "<redacted>" : title() ?? "<no title>")
        \tFrame: \(frame())
        \tid: \(windowID())
        \(screenDescription ?? "Screen: unknown")
        \tisActive: \(isActive())
        \tisOnScreen: \(isOnScreen())
        \tisFocused: \(isFocused())
        \tshouldBeManaged: \(shouldBeManaged())
        \tshouldFloat: \(shouldFloat())
        """
    }
}

struct Windows: ParsableCommand {
    @Flag(help: "Include windows of unmanaged applications.")
    var includeUnmanaged = false

    @Flag(help: "Redact window titles.")
    var redactWindowTitles = false

    mutating func run() throws {
        let applications = NSWorkspace.shared.runningApplications
        for application in applications where includeUnmanaged || application.isManageable == .manageable {
            let app = SIApplication(runningApplication: application)
            print("\(app.title() ?? "<no title>") (pid \(app.pid()))")
            /*
            for window in app.windows() {
                let axWindow = AXWindow(element: window)!
                print(axWindow.debugInfo(redactTitles: redactWindowTitles))
                print("")
            }
             */
        }
    }
}
