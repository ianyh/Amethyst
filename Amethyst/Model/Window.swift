//
//  Window.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/10/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

/**
 Final subclass of the Silica `SIWindow`.
 
 A final class is necessary for satisfying the `focusedWindow()` requirement in the `WindowType` protocol. Otherwise, as `SIWindow` is not final, the type system does not know how to constrain `Self`.
 */
final class AXWindow: SIWindow {}

/// Generic protocol for objects acting as windows in the system.
protocol WindowType: Equatable {
    /// Returns the currently focused window of its type.
    static func currentlyFocused() -> Self?

    /// Returns the window's ID
    func windowID() -> CGWindowID

    /// Returns the window's current frame.
    func frame() -> CGRect

    /// Returns the screen, if any, that the window is currently on.
    func screen() -> NSScreen?

    /**
     Sets the frame of the window with an error threshold for what constitutes a new frame.
     
     The tolerance for error is necessary as for performance reasons we avoid performing unnecessary frame assignments, but some windows (e.g., Terminal's windows) have some constraints on their size such that `frame` and `window.frame()` will differ by some small amount even if `frame` has been applied before. We want to treat that frame as equivalent if it is close enough so that we get the performance benefit.
     
     - Parameters:
         - frame: The frame to apply.
         - threshold: The error tolerance for what constitutes a new frame.
     */

    func setFrame(_ frame: CGRect, withThreshold threshold: CGSize)

    /// Whether or not the window is currently holding focus.
    func isFocused() -> Bool

    /// The process ID of the process that owns the window.
    func pid() -> pid_t

    /**
     The title of the window.
     
     - Note: Windows do not necessarily have titles so this can be `nil`.
     */
    func title() -> String?

    /// Whether or not the window should actually be managed by Amethyst.
    func shouldBeManaged() -> Bool

    /// Whether or not the window should float by default.
    func shouldFloat() -> Bool

    /// Whether or not the window is currently active.
    func isActive() -> Bool

    /**
     Focuses the window.
     
     - Returns:
     `true` if the window was successfully focused, `false` otherwise.
     */
    @discardableResult func focus() -> Bool

    /**
     Moves the window to a screen.
     
     This method takes into account the dimensions of the screen to ensure that the window actually fits onto it.
     
     - Parameters:
        - screen: The screen to move the window to.
     */
    func moveScaled(to screen: NSScreen)

    /// Whether or not the window is currently on any screen.
    func isOnScreen() -> Bool

    /**
     Moves the window to a space.
     
     - Parameters:
        - space: The index of the space.
     */
    func move(toSpace space: UInt)
}

/**
 A type-erased container for a window.
 */
final class AnyWindow<Window: WindowType>: WindowType {
    let internalWindow: Window

    static func == (lhs: AnyWindow<Window>, rhs: AnyWindow<Window>) -> Bool {
        return lhs.internalWindow == rhs.internalWindow
    }

    static func currentlyFocused() -> AnyWindow<Window>? {
        return Window.currentlyFocused().flatMap { AnyWindow($0) }
    }

    init(_ window: Window) {
        self.internalWindow = window
    }

    func windowID() -> CGWindowID { return internalWindow.windowID() }
    func frame() -> CGRect { return internalWindow.frame() }
    func screen() -> NSScreen? { return internalWindow.screen() }
    func setFrame(_ frame: CGRect, withThreshold threshold: CGSize) { internalWindow.setFrame(frame, withThreshold: threshold) }
    func isFocused() -> Bool { return internalWindow.isFocused() }
    func pid() -> pid_t { return internalWindow.pid() }
    func title() -> String? { return internalWindow.title() }
    func shouldBeManaged() -> Bool { return internalWindow.shouldBeManaged() }
    func shouldFloat() -> Bool { return internalWindow.shouldFloat() }
    func isActive() -> Bool { return internalWindow.isActive() }

    @discardableResult func focus() -> Bool {
        return internalWindow.focus()
    }

    func moveScaled(to screen: NSScreen) {
        internalWindow.moveScaled(to: screen)
    }

    func isOnScreen() -> Bool {
        return internalWindow.isOnScreen()
    }

    func move(toSpace space: UInt) {
        internalWindow.move(toSpace: space)
    }
}

func != <Window: WindowType>(lhs: Window, rhs: Window) -> Bool {
    return !(lhs == rhs)
}

struct WindowDescriptions {
    let descriptions: [[String: AnyObject]]

    // return an array of dictionaries of window information for all windows relative to windowID
    // if windowID is 0, this will return all window information
    init?(options: CGWindowListOption, windowID: CGWindowID) {
        guard let cfWindowDescriptions = CGWindowListCopyWindowInfo(options, windowID) else {
            return nil
        }

        guard let windowDescriptions = cfWindowDescriptions as? [[String: AnyObject]] else {
            return nil
        }

        self.descriptions = windowDescriptions
    }
}

extension AXWindow: WindowType {
    static func currentlyFocused() -> AXWindow? {
        return SIWindow.focused().flatMap { AXWindow(axElement: $0.axElementRef) }
    }

    func pid() -> pid_t {
        return processIdentifier()
    }

    func shouldBeManaged() -> Bool {
        guard isMovable() else {
            return false
        }

        guard let subrole = string(forKey: kAXSubroleAttribute as CFString), subrole == kAXStandardWindowSubrole as String else {
            return false
        }

        return true
    }

    func shouldFloat() -> Bool {
        let userConfiguration = UserConfiguration.shared
        let frame = self.frame()

        if userConfiguration.floatSmallWindows() && frame.size.width < 500 && frame.size.height < 500 {
            return true
        }

        return false
    }

    func isFocused() -> Bool {
        guard let focused = AXWindow.focused() else {
            return false
        }

        return isEqual(to: focused)
    }

    @discardableResult override func focus() -> Bool {
        guard super.focus() else {
            return false
        }

        guard UserConfiguration.shared.mouseFollowsFocus() else {
            return true
        }

        let windowFrame = frame()
        let mouseCursorPoint = NSPoint(x: windowFrame.midX, y: windowFrame.midY)
        guard let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: mouseCursorPoint, mouseButton: .left) else {
            return true
        }
        mouseMoveEvent.flags = CGEventFlags(rawValue: 0)
        mouseMoveEvent.post(tap: CGEventTapLocation.cghidEventTap)

        return true
    }

    func moveScaled(to screen: NSScreen) {
        let screenFrame = screen.frameWithoutDockOrMenu()
        let currentFrame = frame()
        var scaledFrame = currentFrame

        if scaledFrame.width > screenFrame.width {
            scaledFrame.size.width = screenFrame.width
        }

        if scaledFrame.height > screenFrame.height {
            scaledFrame.size.height = screenFrame.height
        }

        if scaledFrame != currentFrame {
            setFrame(scaledFrame)
        }

        move(to: screen)
    }
}
