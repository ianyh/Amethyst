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

public protocol WindowModifierType {
    func throwToScreenAtIndex(screenIndex: Int)
    func focusScreenAtIndex(screenIndex: Int)
    func moveFocusCounterClockwise()
    func moveFocusClockwise()
    func swapFocusedWindowToMain()
    func swapFocusedWindowCounterClockwise()
    func swapFocusedWindowClockwise()
    func swapFocusedWindowScreenClockwise()
    func swapFocusedWindowScreenCounterClockwise()
    func pushFocusedWindowToSpace(space: UInt)
}

public protocol WindowModifierDelegate: class {
    func focusedWindow() -> SIWindow?
    func screenManagerForScreenIndex(screenIndex: Int) -> ScreenManager?
    func screenManagerIndexForScreen(screen: NSScreen) -> Int?
    func markScreenForReflow(screen: NSScreen)
    func windowsForScreen(screen: NSScreen) -> [SIWindow]
    func activeWindowsForScreen(screen: NSScreen) -> [SIWindow]
    func windowIsFloating(window: SIWindow) -> Bool
    func switchWindow(window: SIWindow, withWindow otherWindow: SIWindow)
}

public class WindowModifier: WindowModifierType {
    public weak var delegate: WindowModifierDelegate?

    internal func windowIsFloating(window: SIWindow) -> Bool {
        return delegate?.windowIsFloating(window) ?? false
    }

    public func throwToScreenAtIndex(screenIndex: Int) {
        guard let screenManager = delegate?.screenManagerForScreenIndex(screenIndex), focusedWindow = delegate?.focusedWindow() else {
            return
        }

        // If the window is already on the screen do nothing.
        guard focusedWindow.screen().screenIdentifier() != screenManager.screen.screenIdentifier() else {
            return
        }

        delegate?.markScreenForReflow(focusedWindow.screen())
        focusedWindow.moveToScreen(screenManager.screen)
        delegate?.markScreenForReflow(screenManager.screen)
        focusedWindow.am_focusWindow()
    }

    public func focusScreenAtIndex(screenIndex: Int) {
        guard let screenManager = delegate?.screenManagerForScreenIndex(screenIndex) else {
            return
        }

        let windows = delegate?.windowsForScreen(screenManager.screen) ?? []

        if windows.count == 0 && UserConfiguration.sharedConfiguration.mouseFollowsFocus() {
            screenManager.screen.focusScreen()
        } else if windows.count > 0 {
            windows.first?.am_focusWindow()
        }
    }

    public func moveFocusCounterClockwise() {
        guard let focusedWindow = delegate?.focusedWindow() else {
            focusScreenAtIndex(0)
            return
        }

        let screen = focusedWindow.screen()
        guard let windows = delegate?.windowsForScreen(screen) where windows.count > 0 else {
            return
        }

        let windowIndex = windows.indexOf(focusedWindow) ?? 0
        let windowToFocusIndex = (windowIndex == 0 ? windows.count - 1 : windowIndex - 1)
        let windowToFocus = windows[windowToFocusIndex]

        windowToFocus.am_focusWindow()
    }

    public func moveFocusClockwise() {
        guard let focusedWindow = delegate?.focusedWindow() else {
            focusScreenAtIndex(0)
            return
        }

        let screen = focusedWindow.screen()
        guard let windows = delegate?.windowsForScreen(screen) where windows.count > 0 else {
            return
        }

        var windowIndex = windows.indexOf(focusedWindow) ?? NSNotFound
        if windowIndex == NSNotFound {
            windowIndex = windows.count - 1
        }

        let windowToFocus = windows[(windowIndex + 1) % windows.count]

        windowToFocus.am_focusWindow()
    }

    public func swapFocusedWindowToMain() {
        guard let focusedWindow = delegate?.focusedWindow() where !windowIsFloating(focusedWindow) else {
            return
        }

        let screen = focusedWindow.screen()
        guard let windows = delegate?.activeWindowsForScreen(screen) where windows.count > 0 else {
            return
        }

        guard windows.indexOf(focusedWindow) != nil else {
            return
        }

        delegate?.switchWindow(focusedWindow, withWindow: windows[0])
        delegate?.markScreenForReflow(focusedWindow.screen())
        focusedWindow.am_focusWindow()
    }

    public func swapFocusedWindowCounterClockwise() {
        guard let focusedWindow = delegate?.focusedWindow() where !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(0)
            return
        }

        let screen = focusedWindow.screen()
        guard let windows = delegate?.activeWindowsForScreen(screen) else {
            return
        }

        guard let focusedWindowIndex = windows.indexOf(focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex == 0 ? windows.count - 1 : focusedWindowIndex - 1)]

        delegate?.switchWindow(focusedWindow, withWindow: windowToSwapWith)
        delegate?.markScreenForReflow(focusedWindow.screen())
        focusedWindow.am_focusWindow()
    }

    public func swapFocusedWindowClockwise() {
        guard let focusedWindow = delegate?.focusedWindow() where !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(0)
            return
        }

        let screen = focusedWindow.screen()
        guard let windows = delegate?.activeWindowsForScreen(screen) else {
            return
        }

        guard let focusedWindowIndex = windows.indexOf(focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex + 1) % windows.count]

        delegate?.switchWindow(focusedWindow, withWindow: windowToSwapWith)
        delegate?.markScreenForReflow(focusedWindow.screen())
        focusedWindow.am_focusWindow()
    }

    public func swapFocusedWindowScreenClockwise() {
        guard let focusedWindow = delegate?.focusedWindow() where !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(0)
            return
        }

        let screen = focusedWindow.screen()
        guard let screenManagerIndex = delegate?.screenManagerIndexForScreen(screen) else {
            return
        }

        let screenIndex = (screenManagerIndex + 1) % (NSScreen.screens()!.count - 1)
        guard let screenToMoveTo = delegate?.screenManagerForScreenIndex(screenIndex)?.screen else {
            return
        }

        focusedWindow.moveToScreen(screenToMoveTo)

        delegate?.markScreenForReflow(screen)
        delegate?.markScreenForReflow(screenToMoveTo)
    }

    public func swapFocusedWindowScreenCounterClockwise() {
        guard let focusedWindow = delegate?.focusedWindow() where !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(0)
            return
        }

        let screen = focusedWindow.screen()
        guard let screenManagerIndex = delegate?.screenManagerIndexForScreen(screen) else {
            return
        }

        let screenIndex = (screenManagerIndex == 0 ? NSScreen.screens()!.count - 1 : screenManagerIndex - 1)
        guard let screenToMoveTo = delegate?.screenManagerForScreenIndex(screenIndex)?.screen else {
            return
        }

        focusedWindow.moveToScreen(screenToMoveTo)

        delegate?.markScreenForReflow(screen)
        delegate?.markScreenForReflow(screenToMoveTo)
    }

    public func pushFocusedWindowToSpace(space: UInt) {
        guard let focusedWindow = delegate?.focusedWindow() else {
            return
        }

        focusedWindow.moveToSpace(space)
        focusedWindow.am_focusWindow()
    }
}

extension WindowManager: WindowModifierType {
    public func throwToScreenAtIndex(screenIndex: Int) {
        windowModifier.throwToScreenAtIndex(screenIndex)
    }

    public func focusScreenAtIndex(screenIndex: Int) {
        windowModifier.focusScreenAtIndex(screenIndex)
    }

    public func moveFocusCounterClockwise() {
        windowModifier.moveFocusCounterClockwise()
    }

    public func moveFocusClockwise() {
        windowModifier.moveFocusClockwise()
    }

    public func swapFocusedWindowToMain() {
        windowModifier.swapFocusedWindowToMain()
    }

    public func swapFocusedWindowCounterClockwise() {
        windowModifier.swapFocusedWindowCounterClockwise()
    }

    public func swapFocusedWindowClockwise() {
        windowModifier.swapFocusedWindowClockwise()
    }

    public func swapFocusedWindowScreenClockwise() {
        windowModifier.swapFocusedWindowScreenClockwise()
    }

    public func swapFocusedWindowScreenCounterClockwise() {
        windowModifier.swapFocusedWindowScreenCounterClockwise()
    }

    public func pushFocusedWindowToSpace(space: UInt) {
        windowModifier.pushFocusedWindowToSpace(space)
    }
}

extension WindowManager: WindowModifierDelegate {
    public func focusedWindow() -> SIWindow? {
        return SIWindow.focusedWindow()
    }

    public func screenManagerForScreenIndex(screenIndex: Int) -> ScreenManager? {
        guard screenIndex < screenManagers.count else {
            return nil
        }
        return screenManagers[screenIndex]
    }

    public func screenManagerIndexForScreen(screen: NSScreen) -> Int? {
        return screenManagers.indexOf() { screenManager in
            return screenManager.screen.screenIdentifier() == screen.screenIdentifier()
        }
    }

    public func markScreenForReflow(screen: NSScreen) {
        for screenManager in screenManagers {
            guard screenManager.screen.screenIdentifier() == screen.screenIdentifier() else {
                continue
            }

            screenManager.setNeedsReflow()
        }
    }

    public func windowsForScreen(screen: NSScreen) -> [SIWindow] {
        let screenIdentifier = screen.screenIdentifier()
        guard let spaces = NSScreen.screenDescriptions() else {
            return []
        }

        var currentSpace: CGSSpace?
        if NSScreen.screensHaveSeparateSpaces() {
            for screenDictionary in spaces {
                let spaceScreenIdentifier = screenDictionary["Display Identifier"] as? String

                if spaceScreenIdentifier == screenIdentifier {
                    guard let spaceDictionary = screenDictionary["Current Space"] as? [String: AnyObject] else {
                        continue
                    }

                    guard let spaceIdentifier = spaceDictionary["ManagedSpaceID"] as? NSNumber else {
                        continue
                    }

                    currentSpace = spaceIdentifier.unsignedLongLongValue
                    break
                }
            }
        } else {
            let spaceDictionary = spaces[0]["Current Space"] as? [String: AnyObject]
            currentSpace = (spaceDictionary?["ManagedSpaceID"] as? NSNumber)?.unsignedLongLongValue
        }

        guard currentSpace != nil else {
            LogManager.log?.warning("Could not find a space for screen: \(screenIdentifier)")
            return []
        }

        let screenWindows = windows.filter() { window in
            let windowIDsArray = [NSNumber(unsignedInt: window.windowID())] as NSArray
            let spaces = CGSCopySpacesForWindows(_CGSDefaultConnection(), CGSSpaceSelector(7), windowIDsArray).takeRetainedValue() as NSArray as? [NSNumber]
            let space = spaces?.first?.unsignedLongLongValue

            guard space == currentSpace else {
                return false
            }

            return window.screen().screenIdentifier() == screen.screenIdentifier() && window.isActive() && self.activeIDCache[window.windowID()] == true
        }
        return screenWindows
    }

    public func activeWindowsForScreen(screen: NSScreen) -> [SIWindow] {
        let activeWindows = windowsForScreen(screen).filter() { window in
            return window.shouldBeManaged() && !windowIsFloating(window)
        }
        return activeWindows
    }

    public func windowIsFloating(window: SIWindow) -> Bool {
        return floatingMap[window.windowID()] ?? false
    }

    public func switchWindow(window: SIWindow, withWindow otherWindow: SIWindow) {
        guard let windowIndex = windows.indexOf(window) else {
            return
        }

        guard let otherWindowIndex = windows.indexOf(otherWindow) else {
            return
        }

        windows[windowIndex] = otherWindow
        windows[otherWindowIndex] = window
    }
}
