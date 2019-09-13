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

struct CGScreensInfo<Window: WindowType> {
    let descriptions: [JSON]

    init?() {
        guard let descriptions = NSScreen.screenDescriptions() else {
            return nil
        }

        self.descriptions = descriptions
    }

    func space(at index: Int) -> Space {
        return CGSpacesInfo<Window>.space(fromScreenDescription: descriptions[index])
    }
}

struct CGSpacesInfo<Window: WindowType> {
    static func spacesForScreen(_ screen: NSScreen, includeOnlyUserSpaces: Bool = false) -> [Space]? {
        guard let screenDescriptions = NSScreen.screenDescriptions() else {
            return nil
        }

        guard !screenDescriptions.isEmpty else {
            return nil
        }

        let screenIdentifier = screen.screenIdentifier()
        let spaces: [Space]?

        if NSScreen.screensHaveSeparateSpaces {
            spaces = screenDescriptions
                .first { $0["Display Identifier"].string == screenIdentifier }
                .flatMap { screenDescription -> [Space]? in
                    return screenDescription["Spaces"].array?.map { space(fromSpaceDescription: $0) }
                }
        } else {
            spaces = screenDescriptions[0]["Spaces"].arrayValue.map { space(fromSpaceDescription: $0) }
        }

        if includeOnlyUserSpaces {
            return spaces?.filter { $0.type == CGSSpaceTypeUser }
        }

        return spaces
    }

    static func spacesForFocusedScreen() -> [Space]? {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return nil
        }

        return spacesForScreen(screen)
    }

    static func currentSpaceForScreen(_ screen: NSScreen) -> Space? {
        guard let screenDescriptions = NSScreen.screenDescriptions(), let screenIdentifier = screen.screenIdentifier() else {
            return nil
        }

        guard screenDescriptions.count > 0 else {
            return nil
        }

        if NSScreen.screensHaveSeparateSpaces {
            for screenDescription in screenDescriptions {
                guard screenDescription["Display Identifier"].string == screenIdentifier else {
                    continue
                }

                return space(fromScreenDescription: screenDescription)
            }
        } else {
            return space(fromScreenDescription: screenDescriptions[0])
        }

        return nil
    }

    static func currentFocusedSpace() -> Space? {
        guard let focusedWindow = Window.currentlyFocused(), let screen = focusedWindow.screen() else {
            return nil
        }

        return currentSpaceForScreen(screen)
    }

    static func space(fromScreenDescription screenDictionary: JSON) -> Space {
        return space(fromSpaceDescription: screenDictionary["Current Space"])
    }

    static func space(fromSpaceDescription spaceDictionary: JSON) -> Space {
        let id: CGSSpaceID = spaceDictionary["ManagedSpaceID"].intValue
        let type = CGSSpaceType(rawValue: spaceDictionary["type"].uInt32Value)
        let uuid = spaceDictionary["uuid"].stringValue
        return Space(id: id, type: type, uuid: uuid)
    }
}
