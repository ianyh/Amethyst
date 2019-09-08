//
//  NSScreen+Amethyst.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/8/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import ApplicationServices
import Foundation
import Silica
import SwiftyJSON

extension NSScreen {
    static func screenDescriptions() -> [JSON]? {
        guard let cfScreenDescriptions = CGSCopyManagedDisplaySpaces(CGSMainConnectionID())?.takeRetainedValue() else {
            return nil
        }
        guard let screenDescriptions = cfScreenDescriptions as NSArray as? [[String: AnyObject]] else {
            return nil
        }
        return screenDescriptions.map { JSON($0) }
    }

    // Depending on the arrangement of multiple monitors, it's possible to get a height that's larger
    // than any of the individual screens.  This function looks at each display frame's Y coordinates
    // to calculate that height
    static func globalHeight() -> CGFloat {
        return (screens.map { $0.frame.maxY }.max() ?? 0) - (screens.map { $0.frame.minY }.min() ?? 0)
    }

    func screenIdentifier() -> String? {
        guard let managedDisplay = CGSCopyBestManagedDisplayForRect(CGSMainConnectionID(), frameIncludingDockAndMenu()) else {
            return nil
        }
        return String(managedDisplay.takeRetainedValue())
    }

    /// Returns the screen's frame translated to Quartz' coordinate system: The screen's frame (and bounds and so on)
    /// are in cocoa coordinates which are used for views. This coordinate space differs from from Quartz coordinate
    /// space which is used for events.
    /// See https://stackoverflow.com/a/19887161 for details.
    func cgRect() -> CGRect {
        guard let primaryScreen = NSScreen.screens.first else {
            return CGRect(origin: frame.origin, size: frame.size)
        }
        return CGRect(x: frame.origin.x, y: primaryScreen.frame.maxY - self.frame.maxY,
                      width: frame.width, height: frame.height)
    }

    func focusScreen() {
        let frame = cgRect()
        let mouseCursorPoint = CGPoint(x: frame.midX, y: frame.midY)
        let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: mouseCursorPoint, mouseButton: .left)
        mouseMoveEvent?.flags = CGEventFlags(rawValue: 0)
        mouseMoveEvent?.post(tap: .cghidEventTap)
    }

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
}
