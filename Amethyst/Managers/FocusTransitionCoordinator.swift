//
//  FocusTransitionCoordinator.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/24/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import Silica

enum FocusTransition<Window: WindowType> {
    typealias Screen = Window.Screen
    case focusWindow(_ window: Window)
    case focusScreen(_ screen: Screen)
}

protocol FocusTransitionTarget: class {
    associatedtype Application: ApplicationType
    typealias Window = Application.Window
    typealias Screen = Window.Screen

    func executeTransition(_ transition: FocusTransition<Window>)

    func lastFocusedWindow(on screen: Screen) -> Window?
    func screen(at index: Int) -> Screen?
    func windows(onScreen screen: Screen) -> [Window]
    func nextWindowIDClockwise(on screen: Screen) -> Window.WindowID?
    func nextWindowIDCounterClockwise(on screen: Screen) -> Window.WindowID?
    func nextScreenIndexClockwise(from screen: Screen) -> Int
    func nextScreenIndexCounterClockwise(from screen: Screen) -> Int
}

class FocusTransitionCoordinator<Target: FocusTransitionTarget> {
    typealias Window = Target.Window
    typealias Screen = Window.Screen

    weak var target: Target?

    private let userConfiguration: UserConfiguration
    private let focusFollowsMouseManager: FocusFollowsMouseManager<FocusTransitionCoordinator<Target>>

    init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        self.focusFollowsMouseManager = FocusFollowsMouseManager(userConfiguration: userConfiguration)
        self.focusFollowsMouseManager.delegate = self
    }

    func moveFocusCounterClockwise() {
        guard let focusedWindow = Window.currentlyFocused() else {
            focusScreen(at: 0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = target?.windows(onScreen: screen), !windows.isEmpty else {
            return
        }

        let windowToFocus = { () -> Window in
            if let nextWindowID = self.target?.nextWindowIDCounterClockwise(on: screen) {
                let windowToFocusIndex = windows.index { $0.id() == nextWindowID } ?? 0
                return windows[windowToFocusIndex]
            } else {
                let windowIndex = windows.index(of: focusedWindow) ?? 0
                let windowToFocusIndex = (windowIndex == 0 ? windows.count - 1 : windowIndex - 1)
                return windows[windowToFocusIndex]
            }
        }()

        windowToFocus.focus()
    }

    func moveFocusClockwise() {
        guard let focusedWindow = Window.currentlyFocused() else {
            focusScreen(at: 0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = target?.windows(onScreen: screen), !windows.isEmpty else {
            return
        }

        let windowToFocus = { () -> Window in
            if let nextWindowID = target?.nextWindowIDClockwise(on: screen) {
                let windowToFocusIndex = windows.index { $0.id() == nextWindowID } ?? 0
                return windows[windowToFocusIndex]
            } else {
                let windowIndex = windows.index(of: focusedWindow) ?? windows.count - 1
                let windowToFocusIndex = (windowIndex + 1) % windows.count
                return windows[windowToFocusIndex]
            }
        }()

        windowToFocus.focus()
    }

    func moveFocusToMain() {
        guard let focusedWindow = Window.currentlyFocused() else {
            focusScreen(at: 0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = target?.windows(onScreen: screen), !windows.isEmpty else {
            return
        }

        windows[0].focus()
    }

    func focusScreen(at screenIndex: Int) {
        guard let screen = target?.screen(at: screenIndex) else {
            return
        }

        // Do nothing if the screen is already focused
        if let focusedWindow = Window.currentlyFocused(), let focusedScreen = focusedWindow.screen(), focusedScreen == screen {
            return
        }

        // If the previous focus has been tracked, then focus the window that had the focus before.
        if let previouslyFocused = target?.lastFocusedWindow(on: screen), previouslyFocused.isOnScreen() {
            target?.executeTransition(.focusWindow(previouslyFocused))
            return
        }

        // If there are no windows on the screen focus the screen directly
        guard let windows = target?.windows(onScreen: screen), !windows.isEmpty else {
            target?.executeTransition(.focusScreen(screen))
            return
        }

        // Otherwise find the topmost window on the screen
        let screenCenter = NSPointToCGPoint(NSPoint(
            x: screen.frameIncludingDockAndMenu().midX,
            y: screen.frameIncludingDockAndMenu().midY
        ))

        // If there is no window at that point just focus the screen directly
        guard let topWindow = WindowsInformation.topWindowForScreenAtPoint(screenCenter, withWindows: windows) ?? windows.first else {
            target?.executeTransition(.focusScreen(screen))
            return
        }

        // Otherwise focus the topmost window
        target?.executeTransition(.focusWindow(topWindow))
    }

    func moveFocusScreenCounterClockwise() {
        guard let focusedScreen = Window.currentlyFocused()?.screen() else {
            return
        }

        guard let nextScreenIndex = target?.nextScreenIndexCounterClockwise(from: focusedScreen) else {
            return
        }

        focusScreen(at: nextScreenIndex)
    }

    func moveFocusScreenClockwise() {
        guard let focusedScreen = Window.currentlyFocused()?.screen() else {
            return
        }

        guard let screenIndex = target?.nextScreenIndexClockwise(from: focusedScreen) else {
            return
        }

        focusScreen(at: screenIndex)
    }

    func recentlyTriggeredFocusFollowsMouse() -> Bool {
        return focusFollowsMouseManager.recentlyTriggeredFocusFollowsMouse()
    }
}

extension FocusTransitionCoordinator: FocusFollowsMouseManagerDelegate {
    func windows(onScreen screen: Screen) -> [Window] {
        return target?.windows(onScreen: screen) ?? []
    }
}
