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
        private(set) var screenManagers: [ScreenManager<WindowManager<Application>>] = []
        private var screenManagersCache: [String: ScreenManager<WindowManager<Application>>] = [:]

        init() {}

        func updateSpaces() {
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

                    guard screenManager.space != space else {
                        continue
                    }

                    screenManager.updateSpace(to: space)
                }
            } else {
                for screenManager in screenManagers {
                    let space = CGSpacesInfo<Window>.space(fromScreenDescription: screensInfo.descriptions[0])

                    guard screenManager.space != space else {
                        continue
                    }

                    screenManager.updateSpace(to: space)
                }
            }
        }

        func focusedScreenManager() -> ScreenManager<WindowManager<Application>>? {
            guard let focusedWindow = Window.currentlyFocused() else {
                return nil
            }
            for screenManager in screenManagers {
                if screenManager.screen.screenID() == focusedWindow.screen()?.screenID() {
                    return screenManager
                }
            }
            return nil
        }

        func updateScreens(windowManager: WindowManager) {
            var screenManagers: [ScreenManager<WindowManager<Application>>] = []

            for screen in Screen.availableScreens {
                guard let screenID = screen.screenID() else {
                    continue
                }

                let screenManager = screenManagersCache[screenID] ?? windowManager.screenManager(screen: screen)
                screenManager.updateScreen(to: screen)

                screenManagersCache[screenID] = screenManager

                screenManagers.append(screenManager)
            }

            // Window managers are sorted by screen position along the x-axis.
            // See `ScreenManager`'s `Comparable` conformance
            self.screenManagers = screenManagers.sorted()

            updateSpaces()
            markAllScreensForReflow(withChange: .unknown)
        }

        func markScreen(_ screen: Screen, forReflowWithChange change: Change<Window>) {
            screenManagers
                .filter { $0.screen.screenID() == screen.screenID() }
                .forEach { screenManager in
                    screenManager.setNeedsReflowWithWindowChange(change)
                }
        }

        func markAllScreensForReflow(withChange windowChange: Change<Window>) {
            for screenManager in screenManagers {
                screenManager.setNeedsReflowWithWindowChange(windowChange)
            }
        }
    }
}
