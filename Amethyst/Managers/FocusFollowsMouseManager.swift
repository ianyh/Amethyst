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

        guard let windows = delegate?.windowsForFocusFollowsMouse() else {
            return
        }

        var mousePoint = NSPointToCGPoint(event.locationInWindow)
        mousePoint.y = NSScreen.mainScreen()!.frame.size.height - mousePoint.y

        if let focusedWindow = SIWindow.focusedWindow() {
            // If the point is already in the frame of the focused window do nothing.
            guard !focusedWindow.frame().contains(mousePoint) else {
                return
            }
        }

        guard let topWindow = SIWindow.topWindowForScreenAtPoint(mousePoint, withWindows: windows) else {
            return
        }

        topWindow.am_focusWindow()
    }
}

extension WindowManager: FocusFollowsMouseManagerDelegate {
    public func windowsForFocusFollowsMouse() -> [SIWindow] {
        return windows
    }
}
