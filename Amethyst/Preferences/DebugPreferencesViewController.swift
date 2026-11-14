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

    /// Explains how to install the profile while the titles are hidden, and how to remove it once they are revealed.
    /// Either way, System Settings opens only when the instructions are accepted.
    @IBAction func revealOrHideWindowTitles(_ sender: AnyObject) {
        if windowTitlesAreRevealed {
            show(removalInstructions()) {
                DebugPreferencesViewController.openProfilesPane()
            }
        } else {
            show(installationInstructions()) { [weak self] in
                self?.offerProfile()
            }
        }
    }

    /// The steps for installing the profile, with a button that hands the profile to macOS and opens the System
    /// Settings pane where it waits.
    func installationInstructions() -> NSAlert {
        return instructions(
            title: "Install the profile to reveal window titles",
            text: "The system log on this Mac hides window titles until the profile "
                + "“\(DebugPreferencesViewController.profileName)” is installed. To show them, open System Settings, "
                + "double-click that profile and click Install. Installing it needs an administrator."
        )
    }

    /// The steps for removing the profile, with a button that opens the System Settings pane that lists it.
    func removalInstructions() -> NSAlert {
        return instructions(
            title: "Remove the profile to hide window titles",
            text: "The system log on this Mac shows window titles because the profile "
                + "“\(DebugPreferencesViewController.profileName)” is installed. To hide them again, open System Settings, "
                + "select that profile and remove it with the minus (–) button. Removing it needs an administrator."
        )
    }

    private func instructions(title: String, text: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    /// Shows the instructions on the preferences window, and carries on only if Open System Settings is chosen.
    private func show(_ instructions: NSAlert, thenOpenSystemSettings open: @escaping () -> Void) {
        guard let window = view.window else {
            return
        }

        instructions.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else {
                return
            }

            open()
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
            DebugPreferencesViewController.openProfilesPane()
        }
    }

    private static func openProfilesPane() {
        if let pane = profilesPaneURL {
            NSWorkspace.shared.open(pane)
        }
    }
}
