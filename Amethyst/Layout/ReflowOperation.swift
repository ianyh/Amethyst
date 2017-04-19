//
//  ReflowOperation.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/3/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

public struct FrameAssignment {
    let frame: CGRect
    let window: SIWindow
    let focused: Bool
    let screenFrame: CGRect
}

open class ReflowOperation: Operation {
    open let screen: NSScreen
    open let windows: [SIWindow]
    fileprivate let windowActivityCache: WindowActivityCache

    public init(screen: NSScreen, windows: [SIWindow], windowActivityCache: WindowActivityCache) {
        self.screen = screen
        self.windows = windows
        self.windowActivityCache = windowActivityCache
        super.init()
    }

    open func adjustedFrameForLayout(_ screen: NSScreen) -> CGRect {
        var frame = UserConfiguration.shared.ignoreMenuBar() ? screen.frameIncludingDockAndMenu() : screen.frameWithoutDockOrMenu()

        if UserConfiguration.shared.windowMargins() {
            /* Inset for producing half of the full padding around screen as collapse only adds half of it to all windows */
            let padding = floor(UserConfiguration.shared.windowMarginSize() / 2)

            frame.origin.x += padding
            frame.origin.y += padding
            frame.size.width -= 2 * padding
            frame.size.height -= 2 * padding
        }

        return frame
    }

    open func performFrameAssignments(_ frameAssignments: [FrameAssignment]) {
        if self.isCancelled {
            return
        }

        for frameAssignment in frameAssignments {
            if !windowActivityCache.windowIsActive(frameAssignment.window) {
                return
            }
        }

        for frameAssignment in frameAssignments {
            LogManager.log?.debug("Screen: \(screen.screenIdentifier() ?? "") -- Frame Assignment: \(frameAssignment)")

            self.assignFrame(frameAssignment.frame, toWindow: frameAssignment.window, focused: frameAssignment.focused, screenFrame: frameAssignment.screenFrame)
        }
    }

    fileprivate func assignFrame(_ frame: CGRect, toWindow window: SIWindow, focused: Bool, screenFrame: CGRect) {
        var padding = UserConfiguration.shared.windowMarginSize()
        var finalFrame = frame

        if UserConfiguration.shared.windowMargins() {
            padding = floor(padding / 2)

            finalFrame.origin.x += padding
            finalFrame.origin.y += padding
            finalFrame.size.width -= 2 * padding
            finalFrame.size.height -= 2 * padding
        }

        var finalPosition = finalFrame.origin

        // Just resize the window
        finalFrame.origin = window.frame().origin
        window.setFrame(finalFrame)

        if focused {
            finalFrame.size = CGSize(width: max(window.frame().size.width, finalFrame.size.width), height: max(window.frame().size.height, finalFrame.size.height))
            if !screenFrame.contains(finalFrame) {
                finalPosition.x = min(finalPosition.x, screenFrame.maxX - finalFrame.size.width)
                finalPosition.y = min(finalPosition.y, screenFrame.maxY - finalFrame.size.height)
            }
        }

        // Move the window to its final frame
        finalFrame.origin = finalPosition
        window.setFrame(finalFrame)
    }
}
