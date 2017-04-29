//
//  NSRunningApplication+Manageable.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import AppKit
import Foundation

protocol BundleIdentifiable {
    var bundleIdentifier: String? { get }
}

extension NSRunningApplication: BundleIdentifiable {}

extension NSRunningApplication {
    var isManageable: Bool {
        guard let bundleIdentifier = bundleIdentifier, !isAgent() else {
            return false
        }

        switch bundleIdentifier {
        case "com.apple.dashboard":
            return false
        case "com.apple.loginwindow":
            return false
        default:
            return true
        }
    }
}
