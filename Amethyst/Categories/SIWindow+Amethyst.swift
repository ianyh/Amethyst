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

extension SIWindow {
    // convert SIWindow objects to CGWindowIDs.
    // additionally, return the full set of window descriptions (which is unsorted and may contain extra windows)
    fileprivate static func windowInformation(_ windows: [SIWindow]) -> (IDs: Set<CGWindowID>, descriptions: [[String: AnyObject]]?) {
        let ids = Set(windows.map { $0.windowID() })
        return (IDs: ids, descriptions: windowDescriptions(.optionOnScreenOnly, windowID: CGWindowID(0)))
    }

    fileprivate static func onScreenWindowsAtPoint(_ point: CGPoint,
                                                   withIDs windowIDs: Set<CGWindowID>,
                                                   withDescriptions windowDescriptions: [[String: AnyObject]]) -> [[String: AnyObject]] {
        var ret: [[String: AnyObject]] = []

        // build a list of windows at this point
        for windowDescription in windowDescriptions {
            guard let windowID = (windowDescription[kCGWindowNumber as String] as? NSNumber).flatMap({ CGWindowID($0.intValue) }),
                windowIDs.contains(windowID) else {
                continue
            }

            // only consider windows with bounds
            guard let windowFrameDictionary = windowDescription[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            // only consider window bounds that contain the given point
            let windowFrame = CGRect(dictionaryRepresentation: windowFrameDictionary as CFDictionary)!
            guard windowFrame.contains(point) else {
                continue
            }
            ret.append(windowDescription)
        }

        return ret
    }

    // if there are several windows at a given screen point, take the top one
    static func topWindowForScreenAtPoint(_ point: CGPoint, withWindows windows: [SIWindow]) -> SIWindow? {
        let (ids, maybeWindowDescriptions) = windowInformation(windows)
        guard let windowDescriptions = maybeWindowDescriptions, !windowDescriptions.isEmpty else {
            return nil
        }

        let windowsAtPoint = onScreenWindowsAtPoint(point, withIDs: ids, withDescriptions: windowDescriptions)

        guard !windowsAtPoint.isEmpty else {
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

            guard let windowsAboveWindow = SIWindow.windowDescriptions(.optionOnScreenAboveWindow, windowID: windowID.uint32Value) else {
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

    // get the first window at a certain point, excluding one specific window from consideration
    static func alternateWindowForScreenAtPoint(_ point: CGPoint, withWindows windows: [SIWindow], butNot ignoreWindow: SIWindow?) -> SIWindow? {
        // only consider windows on this screen
        let (ids, maybeWindowDescriptions) = windowInformation(windows)
        guard let windowDescriptions = maybeWindowDescriptions, !windowDescriptions.isEmpty else {
            return nil
        }

        let windowsAtPoint = onScreenWindowsAtPoint(point, withIDs: ids, withDescriptions: windowDescriptions)

        for windowDescription in windowsAtPoint {
            if let window = windowInWindows(windows, withCGWindowDescription: windowDescription) {
                if window != ignoreWindow {
                    return window
                }
            }
        }

        return nil
    }

    // find a window based on its window description within an array of SIWindow objects
    static func windowInWindows(_ windows: [SIWindow], withCGWindowDescription windowDescription: [String: AnyObject]) -> SIWindow? {
        for window in windows {
            guard
                let windowOwnerProcessIdentifier = windowDescription[kCGWindowOwnerPID as String] as? NSNumber, windowOwnerProcessIdentifier.int32Value == window.processIdentifier()
            else {
                continue
            }

            guard let boundsDictionary = windowDescription[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            let windowFrame = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)!

            guard windowFrame.equalTo(window.frame()) else {
                continue
            }

            guard let windowTitle = windowDescription[kCGWindowName as String] as? String, windowTitle == window.string(forKey: kAXTitleAttribute as CFString!) else {
                continue
            }

            return window
        }

        return nil
    }

    // return an array of dictionaries of window information for all windows relative to windowID
    // if windowID is 0, this will return all window information
    static func windowDescriptions(_ options: CGWindowListOption, windowID: CGWindowID) -> [[String: AnyObject]]? {
        guard let cfWindowDescriptions = CGWindowListCopyWindowInfo(options, windowID) else {
            return nil
        }

        guard let windowDescriptions = cfWindowDescriptions as NSArray as? [[String: AnyObject]] else {
            return nil
        }

        return windowDescriptions
    }

    func shouldBeManaged() -> Bool {
        guard isMovable() else {
            return false
        }

        guard let subrole = string(forKey: kAXSubroleAttribute as CFString!), subrole == kAXStandardWindowSubrole as String else {
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

    @discardableResult func am_focusWindow() -> Bool {
        guard self.focus() else {
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
}
