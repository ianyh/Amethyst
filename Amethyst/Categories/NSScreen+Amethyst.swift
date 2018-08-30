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
        guard let cfScreenDescriptions = CGSCopyManagedDisplaySpaces(_CGSDefaultConnection())?.takeRetainedValue() else {
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
        guard let managedDisplay = CGSCopyBestManagedDisplayForRect(_CGSDefaultConnection(), frameIncludingDockAndMenu()) else {
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
}
