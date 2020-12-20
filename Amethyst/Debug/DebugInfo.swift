//
//  DebugInfo.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 2/24/20.
//  Copyright © 2020 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa

struct DebugInfo {
    static func description() -> String {
        return [
            "Version: \(version())",
            "OS version: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Screens:\n\(screens())",
            "Manageable applications:\n\(applications())",
            "Configuration:\n\(config())"
        ].joined(separator: "\n\n")
    }

    static func version() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        return "\(shortVersion) (\(version))"
    }

    static func isProcessTrusted() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false
        ]

        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func screens() -> String {
        return NSScreen.screens.map { "\t\($0.frame) [\($0.frameIncludingDockAndMenu())]" }.joined(separator: "\n")
    }

    static func applications() -> String {
        return NSWorkspace.shared.runningApplications
            .filter { $0.isManageable }
            .map { "\t\($0.localizedName ?? "<unknown name>") (\($0.bundleIdentifier ?? "<unknown bundle id>"))" }
            .joined(separator: "\n")
    }

    static func config() -> String {
        return UserDefaults.standard.dictionaryRepresentation()
            .filter { ConfigurationKey(rawValue: $0.key) != nil }
            .map { "\($0): \($1)" }.joined(separator: "\n")
    }
}
