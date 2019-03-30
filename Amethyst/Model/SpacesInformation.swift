//
//  SpacesInformation.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/24/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

struct SpacesInformation<Window: WindowType> {
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
}
