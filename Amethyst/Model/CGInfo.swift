//
//  CGInfo.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/29/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica
import SwiftyJSON

/// Windows info as taken from the underlying system.
struct CGWindowsInfo {
    /// An array of dictionaries of window information
    let descriptions: [[String: AnyObject]]

    /**
     - Parameters:
     - options: Any options for getting info.
     - windowID: ID of window to find windows relative to. 0 gets all windows.
     */
    init?(options: CGWindowListOption, windowID: CGWindowID) {
        guard let cfWindowDescriptions = CGWindowListCopyWindowInfo(options, windowID) else {
            return nil
        }

        guard let windowDescriptions = cfWindowDescriptions as? [[String: AnyObject]] else {
            return nil
        }

        self.descriptions = windowDescriptions
    }

    /**
     - Returns:
     The set of windows that are currently active.
     */
    func activeIDs() -> Set<CGWindowID> {
        var ids: Set<CGWindowID> = Set()

        for windowDescription in descriptions {
            guard let windowID = windowDescription[kCGWindowNumber as String] as? NSNumber else {
                continue
            }

            ids.insert(CGWindowID(windowID.uint64Value))
        }

        return ids
    }
}

struct CGScreensInfo {
    let descriptions: [JSON]

    init?() {
        guard let descriptions = NSScreen.screenDescriptions() else {
            return nil
        }

        self.descriptions = descriptions
    }

    func spaceIdentifier(at index: Int) -> String? {
        return descriptions[index]["Current Space"]["uuid"].string
    }
}

struct CGSpacesInfo<Window: WindowType> {
    static func spacesForScreen(_ screen: NSScreen) -> [CGSSpaceID]? {
        guard let screenDescriptions = NSScreen.screenDescriptions() else {
            return nil
        }

        let screenIdentifier = screen.screenIdentifier()

        if NSScreen.screensHaveSeparateSpaces {
            for screenDescription in screenDescriptions {
                guard screenDescription["Display Identifier"].string == screenIdentifier else {
                    continue
                }

                return screenDescription["Spaces"].array?.map { $0["ManagedSpaceID"].intValue }
            }
        } else {
            guard let spaceDescriptions = screenDescriptions.first?["Spaces"].array else {
                return nil
            }

            return spaceDescriptions.map { $0["ManagedSpaceID"].intValue }
        }

        return nil
    }

    static func spacesForFocusedScreen() -> [CGSSpaceID]? {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return nil
        }

        return spacesForScreen(screen)
    }

    static func currentSpaceForScreen(_ screen: NSScreen) -> CGSSpaceID? {
        guard let screenDescriptions = NSScreen.screenDescriptions(), let screenIdentifier = screen.screenIdentifier() else {
            return nil
        }

        if NSScreen.screensHaveSeparateSpaces {
            for screenDescription in screenDescriptions {
                guard screenDescription["Display Identifier"].string == screenIdentifier else {
                    continue
                }

                return screenDescription["Current Space"]["ManagedSpaceID"].intValue
            }
        } else {
            return screenDescriptions.first?["Current Space"]["ManagedSpaceID"].intValue
        }

        return nil
    }

    static func currentFocusedSpace() -> CGSSpaceID? {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return nil
        }

        return currentSpaceForScreen(screen)
    }

    static func spaceIdentifier(from screenDictionary: JSON) -> String? {
        return screenDictionary["Current Space"]["uuid"].string
    }
}
