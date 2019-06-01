//
//  Screens.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/29/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

extension WindowManager {
    class Screens {
        private(set) var screenManagers: [ScreenManager<Window>] = []
        private var screenManagersCache: [String: ScreenManager<Window>] = [:]

        init() {}

        func assignCurrentSpaceIdentifiers() {
            guard let screensInfo = CGScreensInfo() else {
                return
            }

            if NSScreen.screensHaveSeparateSpaces {
                for screenDictionary in screensInfo.descriptions {
                    guard let screenIdentifier = screenDictionary["Display Identifier"].string else {
                        log.error("Could not identify screen with info: \(screenDictionary)")
                        continue
                    }

                    guard let screenManager = screenManagersCache[screenIdentifier] else {
                        log.error("Screen with identifier not managed: \(screenIdentifier)")
                        continue
                    }

                    guard let spaceIdentifier = CGSpacesInfo<Window>.spaceIdentifier(from: screenDictionary), screenManager.currentSpaceIdentifier != spaceIdentifier else {
                        continue
                    }

                    screenManager.currentSpaceIdentifier = spaceIdentifier
                }
            } else {
                for screenManager in screenManagers {
                    let screenDictionary = screensInfo.descriptions[0]

                    guard let spaceIdentifier = CGSpacesInfo<Window>.spaceIdentifier(from: screenDictionary), screenManager.currentSpaceIdentifier != spaceIdentifier else {
                        continue
                    }

                    screenManager.currentSpaceIdentifier = spaceIdentifier
                }
            }
        }

        func focusedScreenManager<Window>() -> ScreenManager<Window>? {
            guard let focusedWindow = Window.currentlyFocused() else {
                return nil
            }
            for screenManager in screenManagers {
                guard let typedScreenManager = screenManager as? ScreenManager<Window> else {
                    continue
                }

                if typedScreenManager.screen.screenIdentifier() == focusedWindow.screen()?.screenIdentifier() {
                    return typedScreenManager
                }
            }
            return nil
        }

        func updateScreenManagers(windowManager: WindowManager) {
            var screenManagers: [ScreenManager<Window>] = []

            for screen in NSScreen.screens {
                guard let screenIdentifier = screen.screenIdentifier() else {
                    continue
                }

                let screenManager = screenManagersCache[screenIdentifier] ?? windowManager.screenManager(screen: screen, screenID: screenIdentifier)
                screenManager.screen = screen

                screenManagersCache[screenIdentifier] = screenManager

                screenManagers.append(screenManager)
            }

            // Window managers are sorted by screen position along the x-axis.
            // See `ScreenManager`'s `Comparable` conformance
            self.screenManagers = screenManagers.sorted()

            assignCurrentSpaceIdentifiers()
            markAllScreensForReflowWithChange(.unknown)
        }

        func markScreenForReflow(_ screen: NSScreen, withChange change: Change<Window>) {
            screenManagers
                .filter { $0.screen.screenIdentifier() == screen.screenIdentifier() }
                .forEach { screenManager in
                    screenManager.setNeedsReflowWithWindowChange(change)
            }
        }

        func markAllScreensForReflowWithChange(_ windowChange: Change<Window>) {
            for screenManager in screenManagers {
                screenManager.setNeedsReflowWithWindowChange(windowChange)
            }
        }
    }
}
