//
//  Window.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/10/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

protocol WindowType: Equatable {
    static func currentlyFocused() -> Self?

    func windowID() -> CGWindowID
    func frame() -> CGRect
    func screen() -> NSScreen?
    func setFrame(_ frame: CGRect, withThreshold threshold: CGSize)
    func isFocused() -> Bool
    func pid() -> pid_t
    func title() -> String?
    func shouldBeManaged() -> Bool
    func shouldFloat() -> Bool
    func isActive() -> Bool

    @discardableResult func focus() -> Bool
    func moveScaled(to screen: NSScreen)
    func isOnScreen() -> Bool
    func move(toSpace space: UInt)
}

extension WindowType where Self: AXWindow {
    func pid() -> pid_t {
        return processIdentifier()
    }
}

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

// A final class is necessary for satisfying the focusedWindow() requirement in the WindowType protocol
final class AXWindow: SIWindow {}

extension AXWindow: WindowType {
    static func currentlyFocused() -> AXWindow? {
        return SIWindow.focused().flatMap { AXWindow(axElement: $0.axElementRef) }
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
