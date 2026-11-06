//
//  DebugPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/9/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import AppKit
import Foundation

class DebugPreferencesViewController: NSViewController {
    /// Hands the bundled logging profile to macOS, which offers to install it in System Settings. Once installed, the
    /// system log on this Mac shows the window titles that are otherwise stored as private data.
    @IBAction func revealWindowTitles(_ sender: AnyObject) {
        guard let profile = Bundle.main.url(forResource: "RevealWindowTitles", withExtension: "mobileconfig") else {
            log.error("The profile that reveals window titles is missing from the app bundle")
            return
        }

        NSWorkspace.shared.open(profile)
    }
}
