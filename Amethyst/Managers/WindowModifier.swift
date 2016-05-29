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
    func pushFocusedWindowToSpaceLeft()
    func pushFocusedWindowToSpaceRight()
}

public protocol WindowModifierDelegate: class {
    func focusedWindow() -> SIWindow?
    func currentFocusedSpace() -> CGSSpace?
    func spacesForFocusedScreen() -> [CGSSpace]?
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

        guard let focusedWindow = SIWindow.focusedWindow() where focusedWindow.screen() != screenManager.screen else {
            return
        }

        let windows = delegate?.windowsForScreen(screenManager.screen) ?? []

        guard windows.count > 0 else {
            screenManager.screen.focusScreen()
            return
        }

        let screenCenter = NSPointToCGPoint(NSPoint(x: screenManager.screen.frame.midX, y: screenManager.screen.frame.midY))
        guard let topWindow = SIWindow.topWindowForScreenAtPoint(screenCenter, withWindows: windows) ?? windows.first else {
            screenManager.screen.focusScreen()
            return
        }

        if UserConfiguration.sharedConfiguration.mouseFollowsFocus() {
            topWindow.am_focusWindow()
        } else {
            topWindow.focusWindow()
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

    public func pushFocusedWindowToSpaceLeft() {
        guard let currentFocusedSpace = delegate?.currentFocusedSpace(), spaces = delegate?.spacesForFocusedScreen() else {
            return
        }

        guard let index = spaces.indexOf(currentFocusedSpace) where index > 0 else {
            return
        }

        pushFocusedWindowToSpace(UInt(index))
    }

    public func pushFocusedWindowToSpaceRight() {
        guard let currentFocusedSpace = delegate?.currentFocusedSpace(), spaces = delegate?.spacesForFocusedScreen() else {
            return
        }

        guard let index = spaces.indexOf(currentFocusedSpace) where index - 2 < spaces.count else {
            return
        }

        pushFocusedWindowToSpace(UInt(index + 2))
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

    public func pushFocusedWindowToSpaceLeft() {
        windowModifier.pushFocusedWindowToSpaceLeft()
    }

    public func pushFocusedWindowToSpaceRight() {
        windowModifier.pushFocusedWindowToSpaceRight()
    }
}

extension WindowManager: WindowModifierDelegate {
    public func focusedWindow() -> SIWindow? {
        return SIWindow.focusedWindow()
    }

    public func spacesForScreen(screen: NSScreen) -> [CGSSpace]? {
        guard let screenDescriptions = NSScreen.screenDescriptions() else {
            return nil
        }

        let screenIdentifier = screen.screenIdentifier()

        if NSScreen.screensHaveSeparateSpaces() {
            for screenDescription in screenDescriptions {
                guard let describedScreenIdentifier = screenDescription["Display Identifier"] as? String
                    where describedScreenIdentifier == screenIdentifier,
                    let spaceDescriptions = screenDescription["Spaces"] as? [[String: AnyObject]]
                    else {
                        continue
                }

                return spaceDescriptions.map { ($0["ManagedSpaceID"] as! NSNumber).unsignedLongLongValue as CGSSpace }
            }
        } else {
            guard let screenDescription = screenDescriptions.first,
                spaceDescriptions = screenDescription["Spaces"] as? [[String: AnyObject]]
                else {
                    return nil
            }

            return spaceDescriptions.map { $0["ManagedSpaceID"] as! CGSSpace }
        }

        return nil
    }

    public func spacesForFocusedScreen() -> [CGSSpace]? {
        guard let focusedWindow = SIWindow.focusedWindow() else {
            return nil
        }

        return spacesForScreen(focusedWindow.screen())
    }

    public func currentSpaceForScreen(screen: NSScreen) -> CGSSpace? {
        guard let screenDescriptions = NSScreen.screenDescriptions() else {
            return nil
        }

        let screenIdentifier = screen.screenIdentifier()

        if NSScreen.screensHaveSeparateSpaces() {
            for screenDescription in screenDescriptions {
                guard let describedScreenIdentifier = screenDescription["Display Identifier"] as? String
                    where describedScreenIdentifier == screenIdentifier,
                    let cfCurrentSpace = screenDescription["Current Space"] as? [String: AnyObject],
                    spaceNumber = cfCurrentSpace["ManagedSpaceID"] as? NSNumber
                    else {
                        continue
                }

                return spaceNumber.unsignedLongLongValue
            }
        } else {
            guard let screenDescription = screenDescriptions.first,
                cfCurrentSpace = screenDescription["Current Space"] as? [String: AnyObject],
                spaceNumber = cfCurrentSpace["ManagedSpaceID"] as? NSNumber
                else {
                    return nil
            }

            return spaceNumber.unsignedLongLongValue
        }

        return nil
    }

    public func currentFocusedSpace() -> CGSSpace? {
        guard let focusedWindow = SIWindow.focusedWindow() else {
            return nil
        }

        return currentSpaceForScreen(focusedWindow.screen())
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
