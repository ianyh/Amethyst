//
//  SIWindow+Amethyst.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import ApplicationServices
import Foundation
import Silica

public extension SIWindow {
    public func shouldBeManaged() -> Bool {
        guard isResizable() || isMovable() else {
            return false
        }

        guard let subrole = stringForKey(kAXSubroleAttribute) where subrole == kAXStandardWindowSubrole as String else {
            return false
        }

        return true
    }

    public func am_focusWindow() -> Bool {
        guard self.focusWindow() else {
            return false
        }

        guard UserConfiguration.sharedConfiguration.mouseFollowsFocus() else {
            return true
        }

        let windowFrame = frame()
        let mouseCursorPoint = NSMakePoint(NSMidX(windowFrame), NSMidY(windowFrame))
        guard let mouseMoveEvent = CGEventCreateMouseEvent(nil, .MouseMoved, mouseCursorPoint, .Left) else {
            return true
        }
        CGEventSetFlags(mouseMoveEvent, CGEventFlags(rawValue: 0)!)
        CGEventPost(CGEventTapLocation.CGHIDEventTap, mouseMoveEvent)

        return true
    }
}
