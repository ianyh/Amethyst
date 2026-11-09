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
    /// The name System Settings lists the bundled profile under.
    static let profileName = "Amethyst: Reveal Window Titles in the System Log"

    @IBOutlet weak var revealWindowTitlesButton: NSButton?
    @IBOutlet weak var revealWindowTitlesNote: NSTextField?

    /// The preferences the pane reads; the app's shared ones unless a test supplies its own.
    var configuration = UserConfiguration.shared

    /// The system's logging options for the app, which exist while the profile is installed; the real file unless a
    /// test supplies its own.
    var loggingOptionsURL = SystemLogDestination.optionsURL

    private var observers: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // The checkboxes change the preferences, and the profile is installed and removed over in System Settings, so
        // the button is brought up to date on every preference change and whenever the app comes back to the front.
        observers = [UserDefaults.didChangeNotification, NSApplication.didBecomeActiveNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.updateRevealWindowTitlesButton()
            }
        }
        updateRevealWindowTitlesButton()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updateRevealWindowTitlesButton()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Whether the system log on this Mac shows window titles, which it does while the profile is installed.
    var windowTitlesAreRevealed: Bool {
        return SystemLogDestination.showsPrivateData(optionsAt: loggingOptionsURL)
    }

    /// While the profile is installed the button offers to hide the titles again, and it stays available so that the
    /// profile can always be removed. Otherwise the profile only matters while something is written to the system
    /// log, so the button follows the two logging checkboxes.
    func updateRevealWindowTitlesButton() {
        let revealed = windowTitlesAreRevealed
        let logging = configuration.logsDiagnosticDetails() || configuration.logsWarningsAndErrors()

        revealWindowTitlesButton?.title = revealed ? "Hide Window Titles in System Logs" : "Reveal Window Titles in System Logs"
        revealWindowTitlesButton?.isEnabled = revealed || logging
        revealWindowTitlesNote?.stringValue = revealed
            ? "Shows how to remove the profile in System Settings; removing it needs an administrator. Until then, titles stay visible."
            : "Opens a profile in System Settings; installing it needs an administrator. Until then, titles appear as <private>."
    }

    /// System Settings' pane for downloaded and installed profiles.
    static var profilesPaneURL: URL? {
        if #available(macOS 13, *) {
            return URL(string: "x-apple.systempreferences:com.apple.Profiles-Settings.extension")
        }
        return URL(string: "x-apple.systempreferences:com.apple.preferences.configurationprofiles")
    }

    /// Offers the profile while the titles are hidden, and explains how to remove it once they are revealed.
    @IBAction func revealOrHideWindowTitles(_ sender: AnyObject) {
        if windowTitlesAreRevealed {
            showRemovalInstructions()
        } else {
            offerProfile()
        }
    }

    /// Hands the bundled logging profile to macOS, then opens System Settings on the pane where the profile waits to
    /// be installed. Once installed, the system log on this Mac shows the window titles that are otherwise stored as
    /// private data.
    private func offerProfile() {
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

    /// The steps for removing the profile, with a button that opens the System Settings pane that lists it.
    func removalInstructions() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Remove the profile to hide window titles"
        alert.informativeText = "The system log on this Mac shows window titles because the profile "
            + "“\(DebugPreferencesViewController.profileName)” is installed. To hide them again, open System Settings, "
            + "select that profile and remove it with the minus (–) button. Removing it needs an administrator."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    private func showRemovalInstructions() {
        guard let window = view.window else {
            return
        }

        removalInstructions().beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn, let pane = DebugPreferencesViewController.profilesPaneURL else {
                return
            }

            NSWorkspace.shared.open(pane)
        }
    }
}
