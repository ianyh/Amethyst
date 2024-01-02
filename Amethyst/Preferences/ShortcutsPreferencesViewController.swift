//
//  ShortcutsPreferencesViewController.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import MASShortcut
import Silica

enum Profile: String {
    case profile1 = "profile-1"
    case profile2 = "profile-2"
    case profile3 = "profile-3"
}

class ShortcutsPreferencesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    private var hotKeyNameToDefaultsKey: [[String]] = []

    @IBOutlet var tableView: NSTableView?
    @IBOutlet weak var profileSelector: NSPopUpButton?

    @IBAction func selectedProfileChanged(_ sender: Any) {
        tableView?.reloadData()
    }

    @IBAction func loadProfileClicked(_ sender: Any) {
        guard let selectedProfile = self.selectedProfile else {
            return
        }
        UserConfiguration.shared.loadCommandKeysFromProfile(profile: selectedProfile, commandKeys: hotKeyNameToDefaultsKey.map({ $0[1] })
        )
    }

    @IBAction func saveProfileClicked(_ sender: Any) {
        guard let selectedProfile = self.selectedProfile else {
            return
        }
        UserConfiguration.shared.saveCommandKeysToProfile(profile: selectedProfile, commandKeys: hotKeyNameToDefaultsKey.map({ $0[1] })
        )
    }

    var selectedProfile: Profile? {
        guard let selectedProfileRawValue = profileSelector?.selectedItem?.identifier?.rawValue else {
            return nil
        }
        return Profile.init(rawValue: selectedProfileRawValue)
    }

    override func awakeFromNib() {
        tableView?.dataSource = self
        tableView?.delegate = self
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        hotKeyNameToDefaultsKey = HotKeyManager<SIApplication>.hotKeyNameToDefaultsKey()
        tableView?.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return hotKeyNameToDefaultsKey.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let frame = NSRect(x: 0, y: 0, width: tableView.frame.size.width, height: 30)
        let shortcutItemView = ShortcutsPreferencesListItemView(frame: frame)
        let name = hotKeyNameToDefaultsKey[row][0]
        let key = hotKeyNameToDefaultsKey[row][1]

        shortcutItemView.nameLabel?.stringValue = name
        shortcutItemView.shortcutView?.associatedUserDefaultsKey = key

        if let selectedProfile = self.selectedProfile {
            let constrCommandKey = UserConfiguration.constructProfileCommandKeyString(profile: selectedProfile, commandKey: key)
            shortcutItemView.shortcutDraft?.associatedUserDefaultsKey = constrCommandKey
        }
        return shortcutItemView
    }

    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        return false
    }
}
