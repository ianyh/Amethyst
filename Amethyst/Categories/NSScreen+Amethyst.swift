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

public extension NSScreen {
    public func screenIdentifier() -> String {
        let managedDisplay = CGSCopyBestManagedDisplayForRect(_CGSDefaultConnection(), self.frameIncludingDockAndMenu())
        return String(managedDisplay.takeRetainedValue())
    }

    public func focusScreen() {
        let screenFrame = self.frame
        let mouseCursorPoint = NSMakePoint(NSMidX(screenFrame), NSMidY(screenFrame))
        let mouseMoveEvent = CGEventCreateMouseEvent(nil, .MouseMoved, mouseCursorPoint, .Left)
        CGEventSetFlags(mouseMoveEvent, CGEventFlags(rawValue: 0)!)
        CGEventPost(.CGHIDEventTap, mouseMoveEvent)
    }
}
