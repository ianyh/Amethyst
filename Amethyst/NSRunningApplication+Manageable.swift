//
//  NSRunningApplication+Manageable.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Foundation

public extension NSRunningApplication {
    public var isManageable: Bool {
        guard let bundleIdentifier = bundleIdentifier where !isAgent() else {
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
