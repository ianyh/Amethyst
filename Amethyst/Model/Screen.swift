//
//  Screen.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 9/14/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import Silica
import SwiftyJSON

/// Generic protocol for objects acting as screens in the system.
protocol ScreenType: Equatable {
    /// The list of all the screens available to the system. This is assumed to be meaningfuly ordered such that the first screen is the primary screen.
    static var availableScreens: [Self] { get }
    
    /// If `true` this means that each screen has its own set of spaces. If `false` there is only one set of spaces shared by all screens.
    static var screensHaveSeparateSpaces: Bool { get }
    
    /**
     Descriptions of all screens taken from the underlying graphics system.
     
     These are used to correlate information from multiple sources.
     */
    static func screenDescriptions() -> [JSON]?
    
    /**
     The total height of all screens taking relative layout into account.
     
     Depending on the arrangement of multiple screens, it is possible to get a height that is larger than any of the individual screens. This function looks at each display frame's y-coordinates to calculate that height.
     */
    static func globalHeight() -> CGFloat

    /// The raw frame of the screen.
    var frame: NSRect { get }
    
    /// The frame adjusted for app modifiers; e.g., window margins.
    func adjustedFrame() -> CGRect
    
    /// The frame adjusted to contain both the dock and the status menu.
    func frameIncludingDockAndMenu() -> CGRect
    
    /// The frame adjusted such that the dock and menu are not included.
    func frameWithoutDockOrMenu() -> CGRect
    
    /// The opaque idenfitifer for the screen in the underlying graphics system.
    func screenIdentifier() -> String?
    
    /// Raises the window to the foreground.
    func focusScreen()
}

extension ScreenType {
    static func globalHeight() -> CGFloat {
        return (availableScreens.map { $0.frame.maxY }.max() ?? 0) - (availableScreens.map { $0.frame.minY }.min() ?? 0)
    }
}

struct AMScreen: ScreenType {
    static var availableScreens: [AMScreen] { return NSScreen.screens.map { AMScreen(screen: $0) } }
    static var screensHaveSeparateSpaces: Bool { return NSScreen.screensHaveSeparateSpaces }

    let screen: NSScreen

    var frame: NSRect { return screen.frame }

    func adjustedFrame() -> CGRect {
        var frame = UserConfiguration.shared.ignoreMenuBar() ? frameIncludingDockAndMenu() : frameWithoutDockOrMenu()

        if UserConfiguration.shared.windowMargins() {
            /* Inset for producing half of the full padding around screen as collapse only adds half of it to all windows */
            let padding = floor(UserConfiguration.shared.windowMarginSize() / 2)

            frame.origin.x += padding
            frame.origin.y += padding
            frame.size.width -= 2 * padding
            frame.size.height -= 2 * padding
        }

        let windowMinimumWidth = UserConfiguration.shared.windowMinimumWidth()
        let windowMinimumHeight = UserConfiguration.shared.windowMinimumHeight()

        if windowMinimumWidth > frame.size.width {
            frame.origin.x -= (windowMinimumWidth - frame.size.width) / 2
            frame.size.width = windowMinimumWidth
        }

        if windowMinimumHeight > frame.size.height {
            frame.origin.y -= (windowMinimumHeight - frame.size.height) / 2
            frame.size.height = windowMinimumHeight
        }

        let paddingTop = UserConfiguration.shared.screenPaddingTop()
        let paddingBottom = UserConfiguration.shared.screenPaddingBottom()
        let paddingLeft = UserConfiguration.shared.screenPaddingLeft()
        let paddingRight = UserConfiguration.shared.screenPaddingRight()
        frame.origin.y += paddingTop
        frame.origin.x += paddingLeft
        // subtract the right padding, and also any amount that we pushed the frame to the left with the left padding
        frame.size.width -= (paddingRight + paddingLeft)
        // subtract the bottom padding, and also any amount that we pushed the frame down with the top padding
        frame.size.height -= (paddingBottom + paddingTop)

        return frame
    }

    func frameIncludingDockAndMenu() -> CGRect {
        return screen.frameIncludingDockAndMenu()
    }

    func frameWithoutDockOrMenu() -> CGRect {
        return screen.frameWithoutDockOrMenu()
    }

    func screenIdentifier() -> String? {
        guard let managedDisplay = CGSCopyBestManagedDisplayForRect(CGSMainConnectionID(), frameIncludingDockAndMenu()) else {
            return nil
        }
        return String(managedDisplay.takeRetainedValue())
    }

    func focusScreen() {
        let screenFrame = self.frame
        let mouseCursorPoint = NSPoint(x: screenFrame.midX, y: screenFrame.midY)
        let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: mouseCursorPoint, mouseButton: .left)
        mouseMoveEvent?.flags = CGEventFlags(rawValue: 0)
        mouseMoveEvent?.post(tap: .cghidEventTap)
    }

    static func screenDescriptions() -> [JSON]? {
        guard let cfScreenDescriptions = CGSCopyManagedDisplaySpaces(CGSMainConnectionID())?.takeRetainedValue() else {
            return nil
        }
        guard let screenDescriptions = cfScreenDescriptions as NSArray as? [[String: AnyObject]] else {
            return nil
        }
        return screenDescriptions.map { JSON($0) }
    }
}
