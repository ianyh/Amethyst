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
    public static func screenDescriptions() -> [[String: AnyObject]]? {
        let cfScreenDescriptions = CGSCopyManagedDisplaySpaces(_CGSDefaultConnection()).takeRetainedValue()
        guard let screenDescriptions = cfScreenDescriptions as NSArray as? [[String: AnyObject]] else {
            return nil
        }
        return screenDescriptions
    }

    public func screenIdentifier() -> String {
        let managedDisplay = CGSCopyBestManagedDisplayForRect(_CGSDefaultConnection(), self.frameIncludingDockAndMenu())
        return String(managedDisplay!.takeRetainedValue())
    }

    public func focusScreen() {
        let screenFrame = self.frame
        let mouseCursorPoint = NSPoint(x: screenFrame.midX, y: screenFrame.midY)
        let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: mouseCursorPoint, mouseButton: .left)
        mouseMoveEvent?.flags = CGEventFlags(rawValue: 0)
        mouseMoveEvent?.post(tap: .cghidEventTap)
    }
}
