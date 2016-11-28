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
    func throwToScreenAtIndex(_ screenIndex: Int)
    func focusScreenAtIndex(_ screenIndex: Int)
    func moveFocusCounterClockwise()
    func moveFocusClockwise()
    func swapFocusedWindowToMain()
    func swapFocusedWindowCounterClockwise()
    func swapFocusedWindowClockwise()
    func swapFocusedWindowScreenClockwise()
    func swapFocusedWindowScreenCounterClockwise()
    func pushFocusedWindowToSpace(_ space: UInt)
    func pushFocusedWindowToSpaceLeft()
    func pushFocusedWindowToSpaceRight()
}

public protocol WindowModifierDelegate: class {
    func focusedWindow() -> SIWindow?
    func currentFocusedSpace() -> CGSSpace?
    func spacesForFocusedScreen() -> [CGSSpace]?
    func screenManagerForScreen(_ screen: NSScreen) -> ScreenManager?
    func screenManagerForScreenIndex(_ screenIndex: Int) -> ScreenManager?
    func screenManagerIndexForScreen(_ screen: NSScreen) -> Int?
    func markScreenForReflow(_ screen: NSScreen, withChange change: WindowChange)
    func windowsForScreen(_ screen: NSScreen) -> [SIWindow]
    func activeWindowsForScreen(_ screen: NSScreen) -> [SIWindow]
    func windowIsFloating(_ window: SIWindow) -> Bool
    func switchWindow(_ window: SIWindow, withWindow otherWindow: SIWindow)
}

open class WindowModifier: WindowModifierType {
    open weak var delegate: WindowModifierDelegate?

    internal func windowIsFloating(_ window: SIWindow) -> Bool {
        return delegate?.windowIsFloating(window) ?? false
    }

    open func throwToScreenAtIndex(_ screenIndex: Int) {
        guard let screenManager = delegate?.screenManagerForScreenIndex(screenIndex), let focusedWindow = delegate?.focusedWindow() else {
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        // If the window is already on the screen do nothing.
        guard screen.screenIdentifier() != screenManager.screen.screenIdentifier() else {
            return
        }

        delegate?.markScreenForReflow(screen, withChange: .remove(window: focusedWindow))
        focusedWindow.move(to: screenManager.screen)
        delegate?.markScreenForReflow(screenManager.screen, withChange: .unknown)
        focusedWindow.am_focusWindow()
    }

    open func focusScreenAtIndex(_ screenIndex: Int) {
        guard let screenManager = delegate?.screenManagerForScreenIndex(screenIndex) else {
            return
        }

        guard let focusedWindow = SIWindow.focused(), let screen = focusedWindow.screen(), screen != screenManager.screen else {
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

        topWindow.am_focusWindow()
    }

    open func moveFocusCounterClockwise() {
        guard let focusedWindow = delegate?.focusedWindow() else {
            focusScreenAtIndex(0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = delegate?.windowsForScreen(screen), windows.count > 0 else {
            return
        }

        let windowToFocus: SIWindow = { () -> SIWindow in
            if let nextWindowID = delegate?.screenManagerForScreen(screen)?.nextWindowIDCounterClockwise() {
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

    open func moveFocusClockwise() {
        guard let focusedWindow = delegate?.focusedWindow() else {
            focusScreenAtIndex(0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = delegate?.windowsForScreen(screen), windows.count > 0 else {
            return
        }

        let windowToFocus: SIWindow = { () -> SIWindow in
            if let nextWindowID = delegate?.screenManagerForScreen(screen)?.nextWindowIDClockwise() {
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

    open func swapFocusedWindowToMain() {
        guard let focusedWindow = delegate?.focusedWindow(), !windowIsFloating(focusedWindow) else {
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = delegate?.activeWindowsForScreen(screen), windows.count > 0 else {
            return
        }

        guard windows.index(of: focusedWindow) != nil else {
            return
        }

        delegate?.switchWindow(focusedWindow, withWindow: windows[0])
        focusedWindow.am_focusWindow()
    }

    open func swapFocusedWindowCounterClockwise() {
        guard let focusedWindow = delegate?.focusedWindow(), !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = delegate?.activeWindowsForScreen(screen) else {
            return
        }

        guard let focusedWindowIndex = windows.index(of: focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex == 0 ? windows.count - 1 : focusedWindowIndex - 1)]

        delegate?.switchWindow(focusedWindow, withWindow: windowToSwapWith)
        focusedWindow.am_focusWindow()
    }

    open func swapFocusedWindowClockwise() {
        guard let focusedWindow = delegate?.focusedWindow(), !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let windows = delegate?.activeWindowsForScreen(screen) else {
            return
        }

        guard let focusedWindowIndex = windows.index(of: focusedWindow) else {
            return
        }

        let windowToSwapWith = windows[(focusedWindowIndex + 1) % windows.count]

        delegate?.switchWindow(focusedWindow, withWindow: windowToSwapWith)
        focusedWindow.am_focusWindow()
    }

    open func swapFocusedWindowScreenClockwise() {
        guard let focusedWindow = delegate?.focusedWindow(), !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let screenManagerIndex = delegate?.screenManagerIndexForScreen(screen) else {
            return
        }

        let screenIndex = (screenManagerIndex + 1) % (NSScreen.screens()!.count)
        guard let screenToMoveTo = delegate?.screenManagerForScreenIndex(screenIndex)?.screen else {
            return
        }

        delegate?.markScreenForReflow(screen, withChange: .remove(window: focusedWindow))
        focusedWindow.move(to: screenToMoveTo)
        delegate?.markScreenForReflow(screenToMoveTo, withChange: .add(window: focusedWindow))
    }

    open func swapFocusedWindowScreenCounterClockwise() {
        guard let focusedWindow = delegate?.focusedWindow(), !windowIsFloating(focusedWindow) else {
            focusScreenAtIndex(0)
            return
        }

        guard let screen = focusedWindow.screen() else {
            return
        }

        guard let screenManagerIndex = delegate?.screenManagerIndexForScreen(screen) else {
            return
        }

        let screenIndex = (screenManagerIndex == 0 ? NSScreen.screens()!.count - 1 : screenManagerIndex - 1)
        guard let screenToMoveTo = delegate?.screenManagerForScreenIndex(screenIndex)?.screen else {
            return
        }

        delegate?.markScreenForReflow(screen, withChange: .remove(window: focusedWindow))
        focusedWindow.move(to: screenToMoveTo)
        delegate?.markScreenForReflow(screenToMoveTo, withChange: .add(window: focusedWindow))
    }

    open func pushFocusedWindowToSpace(_ space: UInt) {
        guard let focusedWindow = delegate?.focusedWindow(), let screen = focusedWindow.screen() else {
            return
        }

        delegate?.markScreenForReflow(screen, withChange: .remove(window: focusedWindow))
        focusedWindow.move(toSpace: space)
        focusedWindow.am_focusWindow()

        // *gags*
        let delay = Int64(0.5 * Double(NSEC_PER_SEC))
        let popTime = DispatchTime.now() + Double(delay) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: popTime) {
            guard let screen = focusedWindow.screen() else {
                return
            }
            self.delegate?.markScreenForReflow(screen, withChange: .add(window: focusedWindow))
        }
    }

    open func pushFocusedWindowToSpaceLeft() {
        guard let currentFocusedSpace = delegate?.currentFocusedSpace(), let spaces = delegate?.spacesForFocusedScreen() else {
            return
        }

        guard let index = spaces.index(of: currentFocusedSpace), index > 0 else {
            return
        }

        pushFocusedWindowToSpace(UInt(index))
    }

    open func pushFocusedWindowToSpaceRight() {
        guard let currentFocusedSpace = delegate?.currentFocusedSpace(), let spaces = delegate?.spacesForFocusedScreen() else {
            return
        }

        guard let index = spaces.index(of: currentFocusedSpace), index - 2 < spaces.count else {
            return
        }

        pushFocusedWindowToSpace(UInt(index + 2))
    }
}

extension WindowManager: WindowModifierType {
    public func throwToScreenAtIndex(_ screenIndex: Int) {
        windowModifier.throwToScreenAtIndex(screenIndex)
    }

    public func focusScreenAtIndex(_ screenIndex: Int) {
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

    public func pushFocusedWindowToSpace(_ space: UInt) {
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
        return SIWindow.focused()
    }

    public func spacesForScreen(_ screen: NSScreen) -> [CGSSpace]? {
        guard let screenDescriptions = NSScreen.screenDescriptions() else {
            return nil
        }

        let screenIdentifier = screen.screenIdentifier()

        if NSScreen.screensHaveSeparateSpaces() {
            for screenDescription in screenDescriptions {
                guard let describedScreenIdentifier = screenDescription["Display Identifier"] as? String, describedScreenIdentifier == screenIdentifier,
                    let spaceDescriptions = screenDescription["Spaces"] as? [[String: AnyObject]]
                    else {
                        continue
                }

                return spaceDescriptions.map { ($0["ManagedSpaceID"] as! NSNumber).uint64Value as CGSSpace }
            }
        } else {
            guard let screenDescription = screenDescriptions.first,
                let spaceDescriptions = screenDescription["Spaces"] as? [[String: AnyObject]]
                else {
                    return nil
            }

            return spaceDescriptions.map { $0["ManagedSpaceID"] as! CGSSpace }
        }

        return nil
    }

    public func spacesForFocusedScreen() -> [CGSSpace]? {
        guard let focusedWindow = SIWindow.focused(), let screen = focusedWindow.screen() else {
            return nil
        }

        return spacesForScreen(screen)
    }

    public func currentSpaceForScreen(_ screen: NSScreen) -> CGSSpace? {
        guard let screenDescriptions = NSScreen.screenDescriptions() else {
            return nil
        }

        let screenIdentifier = screen.screenIdentifier()

        if NSScreen.screensHaveSeparateSpaces() {
            for screenDescription in screenDescriptions {
                guard let describedScreenIdentifier = screenDescription["Display Identifier"] as? String, describedScreenIdentifier == screenIdentifier,
                    let cfCurrentSpace = screenDescription["Current Space"] as? [String: AnyObject],
                    let spaceNumber = cfCurrentSpace["ManagedSpaceID"] as? NSNumber
                    else {
                        continue
                }

                return spaceNumber.uint64Value
            }
        } else {
            guard let screenDescription = screenDescriptions.first,
                let cfCurrentSpace = screenDescription["Current Space"] as? [String: AnyObject],
                let spaceNumber = cfCurrentSpace["ManagedSpaceID"] as? NSNumber
                else {
                    return nil
            }

            return spaceNumber.uint64Value
        }

        return nil
    }

    public func currentFocusedSpace() -> CGSSpace? {
        guard let focusedWindow = SIWindow.focused(), let screen = focusedWindow.screen() else {
            return nil
        }

        return currentSpaceForScreen(screen)
    }

    public func screenManagerForScreen(_ screen: NSScreen) -> ScreenManager? {
        return screenManagers.filter { $0.screen.screenIdentifier() == screen.screenIdentifier() }.first
    }

    public func screenManagerForScreenIndex(_ screenIndex: Int) -> ScreenManager? {
        guard screenIndex < screenManagers.count else {
            return nil
        }
        return screenManagers[screenIndex]
    }

    public func screenManagerIndexForScreen(_ screen: NSScreen) -> Int? {
        return screenManagers.index() { $0.screen.screenIdentifier() == screen.screenIdentifier() }
    }

    public func markScreenForReflow(_ screen: NSScreen, withChange change: WindowChange) {
        for screenManager in screenManagers {
            guard screenManager.screen.screenIdentifier() == screen.screenIdentifier() else {
                continue
            }

            screenManager.setNeedsReflowWithWindowChange(change)
        }
    }

    public func windowsForScreen(_ screen: NSScreen) -> [SIWindow] {
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

                    currentSpace = spaceIdentifier.uint64Value
                    break
                }
            }
        } else {
            let spaceDictionary = spaces[0]["Current Space"] as? [String: AnyObject]
            currentSpace = (spaceDictionary?["ManagedSpaceID"] as? NSNumber)?.uint64Value
        }

        guard currentSpace != nil else {
            LogManager.log?.warning("Could not find a space for screen: \(screenIdentifier)")
            return []
        }

        let screenWindows = windows.filter() { window in
            let windowIDsArray = [NSNumber(value: window.windowID() as UInt32)] as NSArray
            let spaces = CGSCopySpacesForWindows(_CGSDefaultConnection(), CGSSpaceSelector(7), windowIDsArray).takeRetainedValue() as NSArray as? [NSNumber]
            let space = spaces?.first?.uint64Value

            guard let windowScreen = window.screen(), space == currentSpace else {
                return false
            }

            return windowScreen.screenIdentifier() == screen.screenIdentifier() && window.isActive() && self.activeIDCache[window.windowID()] == true
        }
        return screenWindows
    }

    public func activeWindowsForScreen(_ screen: NSScreen) -> [SIWindow] {
        let activeWindows = windowsForScreen(screen).filter() { window in
            return window.shouldBeManaged() && !windowIsFloating(window)
        }
        return activeWindows
    }

    public func windowIsFloating(_ window: SIWindow) -> Bool {
        return floatingMap[window.windowID()] ?? false
    }

    public func switchWindow(_ window: SIWindow, withWindow otherWindow: SIWindow) {
        guard let windowIndex = windows.index(of: window) else {
            return
        }

        guard let otherWindowIndex = windows.index(of: otherWindow) else {
            return
        }

        windows[windowIndex] = otherWindow
        windows[otherWindowIndex] = window

        markAllScreensForReflowWithChange(.windowSwap(window: window, otherWindow: otherWindow))
    }
}
