//
//  FocusFollowsMouseManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import Foundation
import Silica

public protocol FocusFollowsMouseManagerDelegate: class {
    func windowsForFocusFollowsMouse() -> [SIWindow]
}

public class FocusFollowsMouseManager {
    public weak var delegate: FocusFollowsMouseManagerDelegate?

    private var mouseMovedEventHandler: AnyObject?

    public init() {
        mouseMovedEventHandler = NSEvent.addGlobalMonitorForEventsMatchingMask(NSEventMask.MouseMovedMask) { event in
            self.focusWindowWithMouseMovedEvent(event)
        }
    }

    private func focusWindowWithMouseMovedEvent(event: NSEvent) {
        guard UserConfiguration.sharedConfiguration.focusFollowsMouse() else {
            return
        }

        var mousePoint = NSPointToCGPoint(event.locationInWindow)
        mousePoint.y = NSScreen.mainScreen()!.frame.size.height - mousePoint.y

        var window = SIWindow.focusedWindow()

        // If the point is already in the frame of the focused window do nothing.
        guard !window.frame().contains(mousePoint) else {
            return
        }

        guard
            let windowDescriptions = SIWindow.windowDescriptions(.OptionOnScreenOnly, windowID: CGWindowID(0))
            where windowDescriptions.count > 0
            else {
                return
        }

        var windowsAtPoint: [[String: AnyObject]] = []
        for windowDescription in windowDescriptions {
            var windowFrame: CGRect = CGRect.zero
            guard let windowFrameDictionary = windowDescription[kCGWindowBounds as String] as? [String: AnyObject] else {
                continue
            }
            CGRectMakeWithDictionaryRepresentation(windowFrameDictionary, &windowFrame)

            guard windowFrame.contains(mousePoint) else {
                continue
            }
            windowsAtPoint.append(windowDescription)
        }

        guard windowsAtPoint.count > 0 else {
            return
        }

        // If there is only one window at that point focus it
        guard windowsAtPoint.count > 1 else {
            let window = windowForCGWindowDescription(windowsAtPoint[0])
            window?.focusWindow()
            return
        }

        // Otherwise find the window that's actually on top
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
            return
        }

        window = windowForCGWindowDescription(windowDictionaryToFocus)
        window?.focusWindow()
    }

    private func windowForCGWindowDescription(windowDescription: [String: AnyObject]) -> SIWindow? {
        guard let windows = delegate?.windowsForFocusFollowsMouse() else {
            return nil
        }

        for window in windows {
            guard
                let windowOwnerProcessIdentifier = windowDescription[kCGWindowOwnerPID as String] as? NSNumber
                where windowOwnerProcessIdentifier.intValue == window.processIdentifier()
                else {
                    continue
            }

            var windowFrame: CGRect = CGRect.zero
            guard let boundsDictionary = windowDescription[kCGWindowBounds as String] as? [String: AnyObject] else {
                continue
            }
            CGRectMakeWithDictionaryRepresentation(boundsDictionary, &windowFrame)
            if !CGRectEqualToRect(windowFrame, window.frame()) {
                continue
            }

            guard let windowTitle = windowDescription[kCGWindowName as String] as? String where windowTitle == window.stringForKey(kAXTitleAttribute) else {
                continue
            }

            return window
        }

        return nil
    }
}

extension WindowManager: FocusFollowsMouseManagerDelegate {
    public func windowsForFocusFollowsMouse() -> [SIWindow] {
        return windows
    }
}
