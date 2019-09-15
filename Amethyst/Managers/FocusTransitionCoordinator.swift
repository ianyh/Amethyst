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
    associatedtype Window: WindowType
    typealias Screen = Window.Screen

    var windowActivityCache: WindowActivityCache { get }
    var windows: [Window] { get }

    func executeTransition(_ transition: FocusTransition<Window>)

    func lastFocusedWindow(on screen: Screen) -> Window?
    func screen(at index: Int) -> Screen?
    func nextWindowIDClockwise(on screen: Screen) -> CGWindowID?
    func nextWindowIDCounterClockwise(on screen: Screen) -> CGWindowID?
    func nextScreenIndexClockwise(from screen: Screen) -> Int
    func nextScreenIndexCounterClockwise(from screen: Screen) -> Int
}

extension FocusTransitionTarget {
    func cachedWindows(on screen: Screen) -> [Window] {
        return windowActivityCache.windows(windows, on: screen)
    }
}

class FocusTransitionCoordinator<Target: FocusTransitionTarget> {
    typealias Window = Target.Window
    typealias Screen = Window.Screen

    weak var target: Target!

    init(target: Target) {
        self.target = target
    }

    func moveFocusCounterClockwise() {
        guard let focusedWindow = Window.currentlyFocused() else {
            focusScreen(at: 0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        let windows = target.cachedWindows(on: screen)

        guard !windows.isEmpty else {
            return
        }

        let windowToFocus = { () -> Window in
            if let nextWindowID = self.target.nextWindowIDCounterClockwise(on: screen) {
                let windowToFocusIndex = windows.index { $0.windowID() == nextWindowID } ?? 0
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

        let windows = target.cachedWindows(on: screen)

        guard !windows.isEmpty else {
            return
        }

        let windowToFocus = { () -> Window in
            if let nextWindowID = target.nextWindowIDClockwise(on: screen) {
                let windowToFocusIndex = windows.index { $0.windowID() == nextWindowID } ?? 0
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

        let windows = target.cachedWindows(on: screen)

        guard !windows.isEmpty else {
            return
        }

        windows[0].focus()
    }

    func focusScreen(at screenIndex: Int) {
        guard let screen = target.screen(at: screenIndex) else {
            return
        }

        // Do nothing if the screen is already focused
        if let focusedWindow = Window.currentlyFocused(), let focusedScreen = focusedWindow.screen(), focusedScreen == screen {
            return
        }

        // If the previous focus has been tracked, then focus the window that had the focus before.
        if let previouslyFocused = target.lastFocusedWindow(on: screen), previouslyFocused.isOnScreen() {
            target.executeTransition(.focusWindow(previouslyFocused))
            return
        }

        let windows = target.cachedWindows(on: screen)

        // If there are no windows on the screen focus the screen directly
        guard !windows.isEmpty else {
            target.executeTransition(.focusScreen(screen))
            return
        }

        // Otherwise find the topmost window on the screen
        let screenCenter = NSPointToCGPoint(NSPoint(x: screen.frame.midX, y: screen.frame.midY))

        // If there is no window at that point just focus the screen directly
        guard let topWindow = WindowsInformation.topWindowForScreenAtPoint(screenCenter, withWindows: windows) ?? windows.first else {
            target.executeTransition(.focusScreen(screen))
            return
        }

        // Otherwise focus the topmost window
        target.executeTransition(.focusWindow(topWindow))
    }

    func moveFocusScreenCounterClockwise() {
        guard let focusedScreen = Window.currentlyFocused()?.screen() else {
            return
        }

        focusScreen(at: target.nextScreenIndexCounterClockwise(from: focusedScreen))
    }

    func moveFocusScreenClockwise() {
        guard let focusedScreen = Window.currentlyFocused()?.screen() else {
            return
        }

        focusScreen(at: target.nextScreenIndexClockwise(from: focusedScreen))
    }
}

extension FocusTransitionCoordinator {}
