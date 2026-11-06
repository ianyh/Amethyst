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
    @IBOutlet weak var revealWindowTitlesButton: NSButton?

    /// The preferences the pane reads; the app's shared ones unless a test supplies its own.
    var configuration = UserConfiguration.shared

    private var preferencesObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        preferencesObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateRevealWindowTitlesButton()
        }
        updateRevealWindowTitlesButton()
    }

    deinit {
        if let preferencesObserver = preferencesObserver {
            NotificationCenter.default.removeObserver(preferencesObserver)
        }
    }

    /// The profile only matters while something is written to the system log, so the button follows the two logging
    /// checkboxes.
    func updateRevealWindowTitlesButton() {
        revealWindowTitlesButton?.isEnabled = configuration.logsDiagnosticDetails() || configuration.logsWarningsAndErrors()
    }

    /// System Settings' pane for downloaded and installed profiles.
    static var profilesPaneURL: URL? {
        if #available(macOS 13, *) {
            return URL(string: "x-apple.systempreferences:com.apple.Profiles-Settings.extension")
        }
        return URL(string: "x-apple.systempreferences:com.apple.preferences.configurationprofiles")
    }

    /// Hands the bundled logging profile to macOS, then opens System Settings on the pane where the profile waits to
    /// be installed. Once installed, the system log on this Mac shows the window titles that are otherwise stored as
    /// private data.
    @IBAction func revealWindowTitles(_ sender: AnyObject) {
        guard let profile = Bundle.main.url(forResource: "RevealWindowTitles", withExtension: "mobileconfig") else {
            log.error("The profile that reveals window titles is missing from the app bundle")
            return
        }

        NSWorkspace.shared.open(profile)

        // macOS needs a moment to file the profile before the pane can show it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let pane = DebugPreferencesViewController.profilesPaneURL {
                NSWorkspace.shared.open(pane)
            }
        }
    }
}
