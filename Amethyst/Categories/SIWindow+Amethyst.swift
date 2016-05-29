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
    public static func topWindowForScreenAtPoint(point: CGPoint, withWindows windows: [SIWindow]) -> SIWindow? {
        guard let windowDescriptions = windowDescriptions(.OptionOnScreenOnly, windowID: CGWindowID(0)) where windowDescriptions.count > 0 else {
            return nil
        }

        var windowsAtPoint: [[String: AnyObject]] = []
        for windowDescription in windowDescriptions {
            var windowFrame = CGRect.zero
            guard let windowFrameDictionary = windowDescription[kCGWindowBounds as String] as? [String: AnyObject] else {
                continue
            }

            CGRectMakeWithDictionaryRepresentation(windowFrameDictionary, &windowFrame)

            guard windowFrame.contains(point) else {
                continue
            }

            windowsAtPoint.append(windowDescription)
        }

        guard windowsAtPoint.count > 0 else {
            return nil
        }

        guard windowsAtPoint.count > 1 else {
            return windowInWindows(windows, withCGWindowDescription: windowsAtPoint[0])
        }

        var windowToFocus: [String: AnyObject]?
        var minCount = windowDescriptions.count
        for windowDescription in windowsAtPoint {
            guard let windowID = windowDescription[kCGWindowNumber as String] as? NSNumber else {
                continue
            }

            guard let windowsAboveWindow = SIWindow.windowDescriptions(.OptionOnScreenAboveWindow, windowID: windowID.unsignedIntValue) else {
                continue
            }

            if windowsAboveWindow.count < minCount {
                windowToFocus = windowDescription
                minCount = windowsAboveWindow.count
            }
        }

        guard let windowDictionaryToFocus = windowToFocus else {
            return nil
        }

        return windowInWindows(windows, withCGWindowDescription: windowDictionaryToFocus)
    }

    internal static func windowInWindows(windows: [SIWindow], withCGWindowDescription windowDescription: [String: AnyObject]) -> SIWindow? {
        for window in windows {
            guard
                let windowOwnerProcessIdentifier = windowDescription[kCGWindowOwnerPID as String] as? NSNumber
                where windowOwnerProcessIdentifier.intValue == window.processIdentifier()
            else {
                continue
            }

            guard let boundsDictionary = windowDescription[kCGWindowBounds as String] as? [String: AnyObject] else {
                continue
            }

            var windowFrame: CGRect = CGRect.zero
            CGRectMakeWithDictionaryRepresentation(boundsDictionary, &windowFrame)

            guard CGRectEqualToRect(windowFrame, window.frame()) else {
                continue
            }

            guard let windowTitle = windowDescription[kCGWindowName as String] as? String where windowTitle == window.stringForKey(kAXTitleAttribute) else {
                continue
            }

            return window
        }

        return nil
    }

    public static func windowDescriptions(options: CGWindowListOption, windowID: CGWindowID) -> [[String: AnyObject]]? {
        guard let cfWindowDescriptions = CGWindowListCopyWindowInfo(options, windowID) else {
            return nil
        }

        guard let windowDescriptions = cfWindowDescriptions as NSArray as? [[String: AnyObject]] else {
            return nil
        }

        return windowDescriptions
    }

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
