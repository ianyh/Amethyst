//
//  NSRunningApplication+Manageable.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import AppKit
import Foundation

enum Manageable {
    case manageable
    case unmanageable
    case undetermined
}

private let ignoredBundleIDs = Set([
    "com.apple.dashboard",
    "com.apple.loginwindow",
    "com.apple.notificationcenterui",
    "com.apple.wifi.WiFiAgent",
    "com.apple.Spotlight",
    "com.apple.systemuiserver",
    "com.apple.dock",
    "com.apple.AirPlayUIAgent",
    "com.apple.dock.extra",
    "com.apple.PowerChime",
    "com.apple.WebKit.Networking",
    "com.apple.WebKit.WebContent",
    "com.apple.WebKit.GPU",
    "com.apple.FollowUpUI",
    "com.apple.controlcenter",
    "com.apple.SoftwareUpdateNotificationManager",
    "com.apple.TextInputMenuAgent",
    "com.apple.TextInputSwitcher"
])

protocol BundleIdentifiable {
    var bundleIdentifier: String? { get }
}

extension NSRunningApplication: BundleIdentifiable {}

extension NSRunningApplication {
    var isManageable: Manageable {
        if let bundleIdentifier = bundleIdentifier, ignoredBundleIDs.contains(bundleIdentifier) {
            return .unmanageable
        }

        guard isFinishedLaunching else {
            return .undetermined
        }

        if case .prohibited = activationPolicy {
            return .undetermined
        }

        return .manageable
    }
}
