//
//  DebugPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/9/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import AppKit
import Foundation
import KeyboardShortcuts
import Silica

/// The key bindings as they are currently registered with the shortcut recorders in preferences.
struct RegisteredKeyBindings: KeyBindingStorage {
    func keyBinding(forCommandKey commandKey: String) -> KeyBinding? {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: KeyboardShortcuts.Name(commandKey)), let key = shortcut.key else {
            return nil
        }

        return KeyBinding(keyCode: key.rawValue, modifiers: shortcut.modifiers)
    }
}

class DebugPreferencesViewController: NSViewController {
    @IBAction func exportConfiguration(_ sender: AnyObject) {
        let exporter = ConfigurationExporter(
            userConfiguration: UserConfiguration.shared,
            keyBindings: RegisteredKeyBindings(),
            keyCodeToString: HotKeyManager<SIApplication>.constructKeyCodeToStringMap()
        )
        let commandKeys = HotKeyManager<SIApplication>.hotKeyNameToDefaultsKey().map { $0[1] }
        let export = exporter.export(commandKeys: commandKeys)

        let savePanel = NSSavePanel()
        savePanel.title = "Export Configuration"
        savePanel.message = "Amethyst reads this file from ~/.amethyst.yml or ~/.config/amethyst/amethyst.yml."
        savePanel.nameFieldStringValue = "amethyst.yml"
        savePanel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        savePanel.showsHiddenFiles = true

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = savePanel.url else {
                return
            }

            do {
                try export.yaml.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                log.error("Failed to export configuration: \(error)")
                self.presentAlert(style: .critical, messageText: "Could not export configuration", informativeText: "\(error.localizedDescription)")
                return
            }

            guard !export.unrepresentableCommandKeys.isEmpty else {
                return
            }

            self.presentAlert(
                style: .warning,
                messageText: "Some shortcuts could not be exported",
                informativeText: """
                    A configuration file has room for four modifier combinations and has no name for keys such as the function keys. \
                    The following commands were written out as disabled:

                    \(export.unrepresentableCommandKeys.joined(separator: "\n"))
                    """
            )
        }

        if let window = view.window {
            savePanel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            savePanel.begin(completionHandler: handler)
        }
    }

    private func presentAlert(style: NSAlert.Style, messageText: String, informativeText: String) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.runModal()
    }
}
