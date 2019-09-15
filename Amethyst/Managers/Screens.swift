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
            guard let screensInfo = CGScreensInfo<Window>() else {
                return
            }

            if Screen.screensHaveSeparateSpaces {
                for screenDictionary in screensInfo.descriptions {
                    guard let screenID = screenDictionary["Display Identifier"].string else {
                        log.error("Could not identify screen with info: \(screenDictionary)")
                        continue
                    }

                    guard let screenManager = screenManagersCache[screenID] else {
                        log.error("Screen with identifier not managed: \(screenID)")
                        continue
                    }

                    let space = CGSpacesInfo<Window>.space(fromScreenDescription: screenDictionary)

                    guard screenManager.currentSpace != space else {
                        continue
                    }

                    screenManager.currentSpace = space
                }
            } else {
                for screenManager in screenManagers {
                    let space = CGSpacesInfo<Window>.space(fromScreenDescription: screensInfo.descriptions[0])

                    guard screenManager.currentSpace != space else {
                        continue
                    }

                    screenManager.currentSpace = space
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

                if typedScreenManager.screen.screenID() == focusedWindow.screen()?.screenID() {
                    return typedScreenManager
                }
            }
            return nil
        }

        func updateScreenManagers(windowManager: WindowManager) {
            var screenManagers: [ScreenManager<Window>] = []

            for screen in Screen.availableScreens {
                guard let screenID = screen.screenID() else {
                    continue
                }

                let screenManager = screenManagersCache[screenID] ?? windowManager.screenManager(screen: screen, screenID: screenID)
                screenManager.screen = screen

                screenManagersCache[screenID] = screenManager

                screenManagers.append(screenManager)
            }

            // Window managers are sorted by screen position along the x-axis.
            // See `ScreenManager`'s `Comparable` conformance
            self.screenManagers = screenManagers.sorted()

            assignCurrentSpaceIdentifiers()
            markAllScreensForReflowWithChange(.unknown)
        }

        func markScreenForReflow(_ screen: Screen, withChange change: Change<Window>) {
            screenManagers
                .filter { $0.screen.screenID() == screen.screenID() }
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
