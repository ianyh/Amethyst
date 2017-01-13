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
        
		//Set intermediate positions for the windows
        if UserConfiguration.shared.animateWindows(){
            let step: CGFloat = CGFloat(0.05)
            for i in stride(from:step, to:1.0, by:step) {
                for frameAssignment in frameAssignments {
                    LogManager.log?.debug("Intermediate Screen: \(screen.screenIdentifier()) -- Frame Assignment: \(frameAssignment)")

                    let dx = frameAssignment.frame.origin.x - frameAssignment.window.frame().origin.x
                    let x = frameAssignment.window.frame().origin.x + i*dx
                    let dy = frameAssignment.frame.origin.y - frameAssignment.window.frame().origin.y
                    let y = frameAssignment.window.frame().origin.y + i*dy
                    let dw = frameAssignment.frame.width - frameAssignment.window.frame().width
                    let width = frameAssignment.window.frame().width + i*dw
                    let dh = frameAssignment.frame.height - frameAssignment.window.frame().height
                    let height = frameAssignment.window.frame().height + i*dh
                    if x != frameAssignment.window.frame().origin.x ||
                       y != frameAssignment.window.frame().origin.y ||
                       width != frameAssignment.window.frame().width ||
                       height != frameAssignment.window.frame().height {
                        self.assignFrame(CGRect(x: x,
                                                y: y,
                                            width: width,
                                           height: height),
                                         toWindow: frameAssignment.window,
									      focused: frameAssignment.focused,
								      screenFrame: frameAssignment.screenFrame)
                    }
                }
            }
        }

        //Set the final position for the windows
        for frameAssignment in frameAssignments {
            LogManager.log?.debug("Screen: \(screen.screenIdentifier()) -- Frame Assignment: \(frameAssignment)")

            self.assignFrame(frameAssignment.frame,toWindow: frameAssignment.window, focused: frameAssignment.focused, screenFrame: frameAssignment.screenFrame)
        }
    }

    fileprivate func assignFrame(_ frame: CGRect, toWindow window: SIWindow, focused: Bool, screenFrame: CGRect) {
        var padding = UserConfiguration.shared.windowMarginSize()
        var correctedFrame = frame

        //If there is padding to do....
        if UserConfiguration.shared.windowMargins() && padding > CGFloat(0.0) {
            padding = floor(padding / 2)

            correctedFrame.origin.x += padding
            correctedFrame.origin.y += padding
            correctedFrame.size.width -= 2 * padding
            correctedFrame.size.height -= 2 * padding
            
        }
        window.setFrame(correctedFrame)
    }
}
