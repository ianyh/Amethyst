//
//  WindowModifier.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import Silica

protocol WindowMover {
    func screenManager(at screenIndex: Int) -> ScreenManager?
    func screenManager(for screen: NSScreen) -> ScreenManager?
    func screenManagerIndex(for screen: NSScreen) -> Int?
    func markScreenForReflow(_ screen: NSScreen, withChange change: WindowChange)
    func windows(on screen: NSScreen) -> [SIWindow]
    func activeWindows(on screen: NSScreen) -> [SIWindow]
    func windowIsFloating(_ window: SIWindow) -> Bool
    func switchWindow(_ window: SIWindow, with otherWindow: SIWindow)
}

protocol SingleScreenWindowMover: WindowMover {
    func moveFocusCounterClockwise()
    func moveFocusClockwise()
    func swapFocusedWindowToMain()
    func swapFocusedWindowCounterClockwise()
    func swapFocusedWindowClockwise()
}

protocol CrossScreenWindowMover: WindowMover {
    func throwToScreenAtIndex(_ screenIndex: Int)
    func swapFocusedWindowScreenClockwise()
    func swapFocusedWindowScreenCounterClockwise()
}

protocol CrossSpaceWindowMover: WindowMover {
    func currentFocusedSpace() -> CGSSpace?
    func spacesForFocusedScreen() -> [CGSSpace]?

    func pushFocusedWindowToSpace(_ space: UInt)
    func pushFocusedWindowToSpaceLeft()
    func pushFocusedWindowToSpaceRight()
}

protocol ScreenFocuser: WindowMover {
    func focusScreen(at screenIndex: Int)
}

extension SingleScreenWindowMover where Self: ScreenFocuser {
    func moveFocusCounterClockwise() {
        guard let focusedWindow = SIWindow.focused() else {
            focusScreen(at: 0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        let windows = self.windows(on: screen)

        guard !windows.isEmpty else {
            return
        }

        let windowToFocus: SIWindow = { () -> SIWindow in
            if let nextWindowID = self.screenManager(for: screen)?.nextWindowIDCounterClockwise() {
                let windowToFocusIndex = windows.index { $0.windowID() == nextWindowID } ?? 0
                return windows[windowToFocusIndex]
            } else {
                let windowIndex = windows.index(of: focusedWindow) ?? 0
                let windowToFocusIndex = (windowIndex == 0 ? windows.count - 1 : windowIndex - 1)
                return windows[windowToFocusIndex]
            }
        }()

        windowToFocus.am_focusWindow()
    }

    func moveFocusClockwise() {
        guard let focusedWindow = SIWindow.focused() else {
            focusScreen(at: 0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        let windows = self.windows(on: screen)

        guard !windows.isEmpty else {
            return
        }

        let windowToFocus: SIWindow = { () -> SIWindow in
            if let nextWindowID = self.screenManager(for: screen)?.nextWindowIDClockwise() {
                let windowToFocusIndex = windows.index { $0.windowID() == nextWindowID } ?? 0
                return windows[windowToFocusIndex]
            } else {
                let windowIndex = windows.index(of: focusedWindow) ?? windows.count - 1
                let windowToFocusIndex = (windowIndex + 1) % windows.count
                return windows[windowToFocusIndex]
            }
        }()

        windowToFocus.am_focusWindow()
    }

    func moveFocusToMain() {
        guard let focusedWindow = SIWindow.focused() else {
            focusScreen(at: 0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        let windows = self.windows(on: screen)

        guard !windows.isEmpty else {
            return
        }

        windows[0].am_focusWindow()
    }

    func swapFocusedWindowToMain() {
        guard let focusedWindow = SIWindow.focused(), !windowIsFloating(focusedWindow), let screen = focusedWindow.screen() else {
            return
        }

        let windows = activeWindows(on: screen)

        guard let focusedIndex = windows.index(of: focusedWindow) else {
            return
        }

        // if there are 2 windows, we can always swap.  Just make sure we don't swap focusedWindow with itself.
        switch windows.count {
        case 1:
            return
        case 2:
            switchWindow(focusedWindow, with: windows[1 - focusedIndex])
        default:
            switchWindow(focusedWindow, with: windows[0])
        }
        focusedWindow.am_focusWindow()
    }

    func swapFocusedWindowCounterClockwise() {
        guard let focusedWindow = SIWindow.focused(), !windowIsFloating(focusedWindow) else {
            focusScreen(at: 0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        let windows = activeWindows(on: screen)

        guard let focusedWindowIndex = windows.index(of: focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex == 0 ? windows.count - 1 : focusedWindowIndex - 1)]

        switchWindow(focusedWindow, with: windowToSwapWith)
        focusedWindow.am_focusWindow()
    }

    func swapFocusedWindowClockwise() {
        guard let focusedWindow = SIWindow.focused(), !windowIsFloating(focusedWindow) else {
            focusScreen(at: 0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        let windows = activeWindows(on: screen)

        guard let focusedWindowIndex = windows.index(of: focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex + 1) % windows.count]

        switchWindow(focusedWindow, with: windowToSwapWith)
        focusedWindow.am_focusWindow()
    }
}

extension CrossScreenWindowMover {
    func throwToScreenAtIndex(_ screenIndex: Int) {
        guard let screenManager = screenManager(at: screenIndex), let focusedWindow = SIWindow.focused() else {
            return
        }

        // If the window is already on the screen do nothing.
        guard let screen = focusedWindow.screen(), screen.screenIdentifier() != screenManager.screen.screenIdentifier() else {
            return
        }

        markScreenForReflow(screen, withChange: .remove(window: focusedWindow))
        focusedWindow.moveScaled(to: screenManager.screen)
        markScreenForReflow(screenManager.screen, withChange: .unknown)
        focusedWindow.am_focusWindow()
    }
}

extension CrossScreenWindowMover where Self: ScreenFocuser {
    func swapFocusedWindowScreenClockwise() {
        guard let focusedWindow = SIWindow.focused(), !windowIsFloating(focusedWindow) else {
            focusScreen(at: 0)
            return
        }

        guard let screen = focusedWindow.screen(), let screenManagerIndex = self.screenManagerIndex(for: screen) else {
            return
        }

        let screenIndex = (screenManagerIndex + 1) % (NSScreen.screens.count)

        guard let screenToMoveTo = screenManager(at: screenIndex)?.screen else {
            return
        }

        markScreenForReflow(screen, withChange: .remove(window: focusedWindow))
        focusedWindow.moveScaled(to: screenToMoveTo)
        markScreenForReflow(screenToMoveTo, withChange: .add(window: focusedWindow))
    }

    func swapFocusedWindowScreenCounterClockwise() {
        guard let focusedWindow = SIWindow.focused(), !windowIsFloating(focusedWindow) else {
            focusScreen(at: 0)
            return
        }

        guard let screen = focusedWindow.screen(), let screenManagerIndex = self.screenManagerIndex(for: screen) else {
            return
        }

        let screenIndex = (screenManagerIndex == 0 ? NSScreen.screens.count - 1 : screenManagerIndex - 1)

        guard let screenToMoveTo = self.screenManager(at: screenIndex)?.screen else {
            return
        }

        markScreenForReflow(screen, withChange: .remove(window: focusedWindow))
        focusedWindow.moveScaled(to: screenToMoveTo)
        markScreenForReflow(screenToMoveTo, withChange: .add(window: focusedWindow))
    }
}

extension CrossSpaceWindowMover {
    func pushFocusedWindowToSpace(_ space: UInt) {
        guard let focusedWindow = SIWindow.focused(), let screen = focusedWindow.screen() else {
            return
        }

        markScreenForReflow(screen, withChange: .remove(window: focusedWindow))
        focusedWindow.move(toSpace: space)
        focusedWindow.am_focusWindow()

        // *gags*
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let screen = focusedWindow.screen() else {
                return
            }
            self.markScreenForReflow(screen, withChange: .add(window: focusedWindow))
        }
    }

    func pushFocusedWindowToSpaceLeft() {
        guard let currentFocusedSpace = currentFocusedSpace(), let spaces = spacesForFocusedScreen() else {
            return
        }

        guard let index = spaces.index(of: currentFocusedSpace), index > 0 else {
            return
        }

        pushFocusedWindowToSpace(UInt(index))
    }

    func pushFocusedWindowToSpaceRight() {
        guard let currentFocusedSpace = currentFocusedSpace(), let spaces = spacesForFocusedScreen() else {
            return
        }

        guard let index = spaces.index(of: currentFocusedSpace), index - 2 < spaces.count else {
            return
        }

        pushFocusedWindowToSpace(UInt(index + 2))
    }
}

extension ScreenFocuser {
    func focusScreen(at screenIndex: Int) {
        guard let screenManager = screenManager(at: screenIndex) else {
            return
        }

        // Do nothing if the screen is already focused
        if let focusedWindow = SIWindow.focused(), let screen = focusedWindow.screen(), screen == screenManager.screen {
            return
        }

        // If the previous focus has been tracked, then focus the window that had the focus before.
        if let previouslyFocused = screenManager.lastFocusedWindow, previouslyFocused.isOnScreen() {
            previouslyFocused.am_focusWindow()
            return
        }

        let windows = self.windows(on: screenManager.screen)

        // If there are no windows on the screen focus the screen directly
        guard !windows.isEmpty else {
            screenManager.screen.focusScreen()
            return
        }

        // Otherwise find the topmost window on the screen
        let screenCenter = NSPointToCGPoint(NSPoint(x: screenManager.screen.frame.midX, y: screenManager.screen.frame.midY))

        // If there is no window at that point just focus the screen directly
        guard let topWindow = SIWindow.topWindowForScreenAtPoint(screenCenter, withWindows: windows) ?? windows.first else {
            screenManager.screen.focusScreen()
            return
        }

        // Otherwise focus the topmost window
        topWindow.am_focusWindow()
    }
}

extension WindowManager: CrossSpaceWindowMover {
    func spacesForScreen(_ screen: NSScreen) -> [CGSSpace]? {
        guard let screenDescriptions = NSScreen.screenDescriptions() else {
            return nil
        }

        let screenIdentifier = screen.screenIdentifier()

        if NSScreen.screensHaveSeparateSpaces {
            for screenDescription in screenDescriptions {
                guard screenDescription["Display Identifier"].string == screenIdentifier else {
                    continue
                }

                return screenDescription["Spaces"].array?.map { $0["ManagedSpaceID"].uInt64Value }
            }
        } else {
            guard let spaceDescriptions = screenDescriptions.first?["Spaces"].array else {
                return nil
            }

            return spaceDescriptions.map { $0["ManagedSpaceID"].uInt64Value }
        }

        return nil
    }

    func spacesForFocusedScreen() -> [CGSSpace]? {
        guard let focusedWindow = SIWindow.focused(), let screen = focusedWindow.screen() else {
            return nil
        }

        return spacesForScreen(screen)
    }

    func currentSpaceForScreen(_ screen: NSScreen) -> CGSSpace? {
        guard let screenDescriptions = NSScreen.screenDescriptions(), let screenIdentifier = screen.screenIdentifier() else {
            return nil
        }

        if NSScreen.screensHaveSeparateSpaces {
            for screenDescription in screenDescriptions {
                guard screenDescription["Display Identifier"].string == screenIdentifier else {
                    continue
                }

                return screenDescription["Current Space"]["ManagedSpaceID"].uInt64Value
            }
        } else {
            return screenDescriptions.first?["Current Space"]["ManagedSpaceID"].uInt64Value
        }

        return nil
    }

    func currentFocusedSpace() -> CGSSpace? {
        guard let focusedWindow = SIWindow.focused(), let screen = focusedWindow.screen() else {
            return nil
        }

        return currentSpaceForScreen(screen)
    }
}

extension WindowManager: WindowMover {
    func screenManager(for screen: NSScreen) -> ScreenManager? {
        return screenManagers.first { $0.screen.screenIdentifier() == screen.screenIdentifier() }
    }

    func screenManager(at screenIndex: Int) -> ScreenManager? {
        guard screenIndex < screenManagers.count else {
            return nil
        }
        return screenManagers[screenIndex]
    }

    func screenManagerIndex(for screen: NSScreen) -> Int? {
        return screenManagers.index { $0.screen.screenIdentifier() == screen.screenIdentifier() }
    }

    func markScreenForReflow(_ screen: NSScreen, withChange change: WindowChange) {
        screenManagers
            .filter { $0.screen.screenIdentifier() == screen.screenIdentifier() }
            .forEach { screenManager in
                screenManager.setNeedsReflowWithWindowChange(change)
            }
    }

    func windows(on screen: NSScreen) -> [SIWindow] {
        guard let screenIdentifier = screen.screenIdentifier() else {
            return []
        }

        guard let currentSpace = currentSpaceForScreen(screen) else {
            log.warning("Could not find a space for screen: \(screenIdentifier)")
            return []
        }

        let screenWindows = windows.filter { window in
            let windowIDsArray = [NSNumber(value: window.windowID() as UInt32)] as NSArray

            guard let spaces = CGSCopySpacesForWindows(_CGSDefaultConnection(), CGSSpaceSelector(7), windowIDsArray)?.takeRetainedValue() else {
                return false
            }

            let space = (spaces as NSArray as? [NSNumber])?.first?.uint64Value

            guard let windowScreen = window.screen(), space == currentSpace else {
                return false
            }

            return windowScreen.screenIdentifier() == screen.screenIdentifier() && self.windowIsActive(window)
        }

        return screenWindows
    }

    func activeWindows(on screen: NSScreen) -> [SIWindow] {
        return windows(on: screen).filter { window in
            return window.shouldBeManaged() && !windowIsFloating(window)
        }
    }

    func windowIsFloating(_ window: SIWindow) -> Bool {
        return floatingMap[window.windowID()] ?? false
    }

    func switchWindow(_ window: SIWindow, with otherWindow: SIWindow) {
        guard let windowIndex = windows.index(of: window), let otherWindowIndex = windows.index(of: otherWindow) else {
            return
        }

        guard windowIndex != otherWindowIndex else { return }

        windows[windowIndex] = otherWindow
        windows[otherWindowIndex] = window
        let theChange = WindowChange.windowSwap(window: window, otherWindow: otherWindow)

        markAllScreensForReflowWithChange(theChange)
    }
}

extension WindowManager: SingleScreenWindowMover, CrossScreenWindowMover, ScreenFocuser {}
