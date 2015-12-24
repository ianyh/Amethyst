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

@objc public class ReflowOperation: NSOperation {
    public let screen: NSScreen
    public let windows: [SIWindow]
    private let windowActivityCache: WindowActivityCache

    public init(screen: NSScreen, windows: [SIWindow], windowActivityCache: WindowActivityCache) {
        self.screen = screen
        self.windows = windows
        self.windowActivityCache = windowActivityCache
        super.init()
    }

    public func adjustedFrameForLayout(screen: NSScreen) -> CGRect {
        var frame = AMConfiguration.sharedConfiguration().ignoreMenuBar() ? screen.frameIncludingDockAndMenu() : screen.frameWithoutDockOrMenu()

        if (AMConfiguration.sharedConfiguration().windowPaddingCollapse()) {
            /* Inset for producing half of the full padding around screen as collapse only adds half of it to all windows */
            let padding = floor(AMConfiguration.sharedConfiguration().windowPadding() / 2)

            frame.origin.x += padding
            frame.origin.y += padding
            frame.size.width -= 2 * padding
            frame.size.height -= 2 * padding
        }

        return frame
    }

    public func performFrameAssignments(frameAssignments: [FrameAssignment]) {
        if (self.cancelled) {
            return
        }

        if (self.screen.am_isFullscreen()) {
            return
        }

        for frameAssignment in frameAssignments {
            if !windowActivityCache.windowIsActive(frameAssignment.window) {
                return
            }
        }

        for frameAssignment in frameAssignments {
            self.assignFrame(frameAssignment.frame, toWindow: frameAssignment.window, focused: frameAssignment.focused, screenFrame: frameAssignment.screenFrame)
        }
    }

    private func assignFrame(frame: CGRect, toWindow window: SIWindow, focused: Bool, screenFrame: CGRect) {
        var padding = AMConfiguration.sharedConfiguration().windowPadding()
        var finalFrame = frame

        if AMConfiguration.sharedConfiguration().windowPaddingCollapse() {
            padding = floor(padding / 2)
        }

        finalFrame.origin.x += padding
        finalFrame.origin.y += padding
        finalFrame.size.width -= 2 * padding
        finalFrame.size.height -= 2 * padding

        var finalPosition = finalFrame.origin

        // Just resize the window
        finalFrame.origin = window.frame().origin
        window.setFrame(finalFrame)

        if (focused) {
            finalFrame.size = CGSize(width: max(window.frame().size.width, finalFrame.size.width), height: max(window.frame().size.height, finalFrame.size.height))
            if (!CGRectContainsRect(screenFrame, finalFrame)) {
                finalPosition.x = min(finalPosition.x, screenFrame.maxX - finalFrame.size.width)
                finalPosition.y = min(finalPosition.y, screenFrame.maxY - finalFrame.size.height)
            }
        }

        // Move the window to its final frame
        finalFrame.origin = finalPosition
        window.setFrame(finalFrame)
    }
}
