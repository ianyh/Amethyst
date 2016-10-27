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

open class FocusFollowsMouseManager {
    open weak var delegate: FocusFollowsMouseManagerDelegate?

    fileprivate let userConfiguration: UserConfiguration
    fileprivate var mouseMovedEventHandler: AnyObject?

    public init(userConfiguration: UserConfiguration) {
        self.userConfiguration = userConfiguration
        mouseMovedEventHandler = NSEvent.addGlobalMonitorForEvents(matching: NSEventMask.mouseMoved) { event in
            self.focusWindowWithMouseMovedEvent(event)
        } as AnyObject?
    }

    fileprivate func focusWindowWithMouseMovedEvent(_ event: NSEvent) {
        guard userConfiguration.focusFollowsMouse() else {
            return
        }

        guard let windows = delegate?.windowsForFocusFollowsMouse() else {
            return
        }

        var mousePoint = NSPointToCGPoint(event.locationInWindow)
        mousePoint.y = NSScreen.main()!.frame.size.height - mousePoint.y

        if let focusedWindow = SIWindow.focused() {
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
