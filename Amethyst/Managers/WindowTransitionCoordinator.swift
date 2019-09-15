//
//  WindowTransitionCoordinator.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/24/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import Silica

enum WindowTransition<Window: WindowType> {
    typealias Screen = Window.Screen
    case switchWindows(_ window1: Window, _ window2: Window)
    case moveWindowToScreen(_ window: Window, screen: Screen)
    case moveWindowToSpaceAtIndex(_ window: Window, spaceIndex: Int)
    case resetFocus
}

protocol WindowTransitionTarget: class {
    associatedtype Window: WindowType
    typealias Screen = Window.Screen

    var windowActivityCache: WindowActivityCache { get }
    var windows: [Window] { get }

    func executeTransition(_ transition: WindowTransition<Window>)

    func screen(at index: Int) -> Screen?
    func nextScreenIndexClockwise(from screen: Screen) -> Int
    func nextScreenIndexCounterClockwise(from screen: Screen) -> Int
}

extension WindowTransitionTarget {
    func activeWindows(on screen: Screen) -> [Window] {
        return windowActivityCache.windows(windows, on: screen).filter { window in
            return window.shouldBeManaged() && !self.windowActivityCache.windowIsFloating(window)
        }
    }
}

class WindowTransitionCoordinator<Target: WindowTransitionTarget> {
    typealias Window = Target.Window
    typealias Screen = Window.Screen

    private(set) weak var target: Target!

    init(target: Target) {
        self.target = target
    }

    func swapFocusedWindowToMain() {
        guard let focusedWindow = Window.currentlyFocused(), !target.windowActivityCache.windowIsFloating(focusedWindow), let screen = focusedWindow.screen() else {
            return
        }

        let windows = target.activeWindows(on: screen)

        guard let focusedIndex = windows.index(of: focusedWindow) else {
            return
        }

        // if there are 2 windows, we can always swap.  Just make sure we don't swap focusedWindow with itself.
        switch windows.count {
        case 1:
            return
        case 2:
            target.executeTransition(.switchWindows(focusedWindow, windows[1 - focusedIndex]))
        default:
            target.executeTransition(.switchWindows(focusedWindow, windows[0]))
        }
    }

    func swapFocusedWindowCounterClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), !target.windowActivityCache.windowIsFloating(focusedWindow) else {
            target.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        let windows = target.activeWindows(on: screen)

        guard let focusedWindowIndex = windows.index(of: focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex == 0 ? windows.count - 1 : focusedWindowIndex - 1)]

        target.executeTransition(.switchWindows(focusedWindow, windowToSwapWith))
    }

    func swapFocusedWindowClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), !target.windowActivityCache.windowIsFloating(focusedWindow) else {
            target.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        let windows = target.activeWindows(on: screen)

        guard let focusedWindowIndex = windows.index(of: focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex + 1) % windows.count]

        target.executeTransition(.switchWindows(focusedWindow, windowToSwapWith))
        focusedWindow.focus()
    }

    func throwToScreenAtIndex(_ screenIndex: Int) {
        guard let screen = target.screen(at: screenIndex), let focusedWindow = Window.currentlyFocused() else {
            return
        }

        // If the window is already on the screen do nothing.
        guard let focusedScreen = focusedWindow.screen(), focusedScreen.screenID() != screen.screenID() else {
            return
        }

        target.executeTransition(.moveWindowToScreen(focusedWindow, screen: screen))
    }

    func swapFocusedWindowScreenClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), !target.windowActivityCache.windowIsFloating(focusedWindow) else {
            target.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let nextScreen = target.screen(at: target.nextScreenIndexClockwise(from: screen)) else {
            return
        }

        target.executeTransition(.moveWindowToScreen(focusedWindow, screen: nextScreen))
    }

    func swapFocusedWindowScreenCounterClockwise() {
        guard let focusedWindow = Window.currentlyFocused(), !target.windowActivityCache.windowIsFloating(focusedWindow) else {
            target.executeTransition(.resetFocus)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let nextScreen = target.screen(at: target.nextScreenIndexCounterClockwise(from: screen)) else {
            return
        }

        target.executeTransition(.moveWindowToScreen(focusedWindow, screen: nextScreen))
    }

    func pushFocusedWindowToSpace(_ space: Int) {
        guard let focusedWindow = Window.currentlyFocused(), focusedWindow.screen() != nil else {
            return
        }

        target.executeTransition(.moveWindowToSpaceAtIndex(focusedWindow, spaceIndex: space))
    }

    func pushFocusedWindowToSpaceLeft() {
        guard let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(), let spaces = CGSpacesInfo<Window>.spacesForFocusedScreen() else {
            return
        }

        guard let index = spaces.index(of: currentFocusedSpace), index > 0 else {
            return
        }

        pushFocusedWindowToSpace(index - 1)
    }

    func pushFocusedWindowToSpaceRight() {
        guard let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(), let spaces = CGSpacesInfo<Window>.spacesForFocusedScreen() else {
            return
        }

        guard let index = spaces.index(of: currentFocusedSpace), index + 1 < spaces.count else {
            return
        }

        pushFocusedWindowToSpace(index + 1)
    }
}
