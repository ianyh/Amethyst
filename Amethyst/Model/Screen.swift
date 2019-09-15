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

protocol ScreenType: Equatable {
    static var availableScreens: [Self] { get }
    static var screensHaveSeparateSpaces: Bool { get }
    static func screenDescriptions() -> [JSON]?
    static func globalHeight() -> CGFloat

    var frame: NSRect { get }
    func adjustedFrame() -> CGRect
    func frameIncludingDockAndMenu() -> CGRect
    func frameWithoutDockOrMenu() -> CGRect
    func screenIdentifier() -> String?
    func focusScreen()
}

extension ScreenType {
    // Depending on the arrangement of multiple monitors, it's possible to get a height that's larger
    // than any of the individual screens.  This function looks at each display frame's Y coordinates
    // to calculate that height
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
