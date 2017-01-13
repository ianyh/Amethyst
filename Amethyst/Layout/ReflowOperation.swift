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

        if UserConfiguration.shared.animateWindows() {
            for i in stride(from:0, to:101, by:10) {
                for frameAssignment in frameAssignments {
                    LogManager.log?.debug("Screen: \(screen.screenIdentifier()) -- Frame Assignment: \(frameAssignment)")

                    let dx = frameAssignment.frame.origin.x - frameAssignment.window.frame().origin.x
                    let x = Float(frameAssignment.window.frame().origin.x) + (Float(i)/100.0)*Float(dx)
                    let dy = frameAssignment.frame.origin.y - frameAssignment.window.frame().origin.y
                    let y = Float(frameAssignment.window.frame().origin.y) + (Float(i)/100.0)*Float(dy)
                    let dw = frameAssignment.frame.width - frameAssignment.window.frame().width
                    let width = Float(frameAssignment.window.frame().width) + (Float(i)/100.0)*Float(dw)
                    let dh = frameAssignment.frame.height - frameAssignment.window.frame().height
                    let height = Float(frameAssignment.window.frame().height) + (Float(i)/100.0)*Float(dh)
                    self.assignFrame(CGRect(x: CGFloat(x),
					                        y: CGFloat(y),
										width: CGFloat(width),
									   height: CGFloat(height)),
                                     toWindow: frameAssignment.window,
									  focused: frameAssignment.focused,
								  screenFrame: frameAssignment.screenFrame)
                }
            }
            
        }
        else{
            for frameAssignment in frameAssignments {
                LogManager.log?.debug("Screen: \(screen.screenIdentifier()) -- Frame Assignment: \(frameAssignment)")

                self.assignFrame(frameAssignment.frame,toWindow: frameAssignment.window, focused: frameAssignment.focused, screenFrame: frameAssignment.screenFrame)
            }
        }
    }

    open func isDegenerateWindow(window: SIWindow) -> Bool {
        let window_frame = window.frame()
        if window_frame.origin.x.isInfinite {
            return true
        }
        if window_frame.origin.x.isNaN {
            return true
        }
        if window_frame.origin.y.isInfinite {
            return true
        }
        if window_frame.origin.y.isNaN {
            return true
        }
        if window_frame.width <= 0.0 {
            return true
        }
        if window_frame.width.isInfinite {
            return true
        }
        if window_frame.width.isNaN {
            return true
        }
        if window_frame.height <= 0.0 {
            return true
        }
        if window_frame.height.isInfinite {
            return true
        }
        if window_frame.height.isNaN {
            return true
        }
        return false
    }

    private func categorizeWindows(candidateFrames: [CGRect]) -> ([SIWindow], [SIWindow]) {

        var displaced: [SIWindow] = []
        var aligned: [SIWindow] = []
        for window in self.windows {
            //Sometimes the windows become degenerate for some reason, ignore them
            if !isDegenerateWindow(window:window) {
                var min_distance = FLT_MAX
                let window_frame = window.frame()
                let windows_center_x = window_frame.origin.x + (window_frame.width/2.0)
                let windows_center_y = window_frame.origin.y + (window_frame.height/2.0)
                for frame in candidateFrames {
                    let frame_center_x = frame.origin.x + (frame.width/2.0)
                    let frame_center_y = frame.origin.y + (frame.height/2.0)
                    let distance_x = (frame_center_x - windows_center_x)
                    let distance_y = (frame_center_y - windows_center_y)
                    let distance = sqrt(distance_x*distance_x + distance_y*distance_y)
                    if Float(distance) < min_distance {
                        min_distance = Float(distance)
                    }
                }
                if min_distance < 1.0 {
                    aligned.append(window)
                }
                else {
                    displaced.append(window)
                }
            }
        }
        return (displaced, aligned)

    }

    open func assignWindowsToFramesBasedOnDistance(candidateFrames: [CGRect]) {

        var candidateFramesMutable = candidateFrames
        //Find those windows that are not perfectly on top of a frame to assign first, because those are the ones that have been newly created or manually moved
        let (displacedWindows, alignedWindows) = categorizeWindows(candidateFrames: candidateFrames)

        //Now preferentially assign displaced windows a location
        let screenFrame = adjustedFrameForLayout(screen)
        let focusedWindow = SIWindow.focused()
        var frameAssignments: [FrameAssignment] = []
        for window in displacedWindows {
            var min_distance = FLT_MAX
            var min_index = -1

            //Sometimes the windows become degenerate for some reason
            if !isDegenerateWindow(window:window) {
                let window_frame = window.frame()
                let windows_center_x = window_frame.origin.x + (window_frame.width/2.0)
                let windows_center_y = window_frame.origin.y + (window_frame.height/2.0)
                for (index, frame) in candidateFramesMutable.enumerated() {
                    let frame_center_x = frame.origin.x + (frame.width/2.0)
                    let frame_center_y = frame.origin.y + (frame.height/2.0)
                    let distance_x = (frame_center_x - windows_center_x)
                    let distance_y = (frame_center_y - windows_center_y)
                    let distance = sqrt(distance_x*distance_x + distance_y*distance_y)
                    if Float(distance) < min_distance {
                        min_distance = Float(distance)
                        min_index = index
                    }
                }
            }
            if min_index != -1 {
                let frameAssignment = FrameAssignment(frame: candidateFramesMutable[min_index], window: window, focused: window.isEqual(to: focusedWindow), screenFrame: screenFrame)
                frameAssignments.append(frameAssignment)
                candidateFramesMutable.remove(at: min_index)
            }
        }

        //Now assigned aligned windows that are still aligned a location
        var alignedNoMoreWindows: [SIWindow] = []
        for window in alignedWindows {
            var min_distance = FLT_MAX
            var min_index = -1

            //Sometimes the windows become degenerate for some reason, ignore them
            if !isDegenerateWindow(window:window) {
                let window_frame = window.frame()
                let windows_center_x = window_frame.origin.x + (window_frame.width/2.0)
                let windows_center_y = window_frame.origin.y + (window_frame.height/2.0)
                for (index, frame) in candidateFramesMutable.enumerated() {
                    let frame_center_x = frame.origin.x + (frame.width/2.0)
                    let frame_center_y = frame.origin.y + (frame.height/2.0)
                    let distance_x = (frame_center_x - windows_center_x)
                    let distance_y = (frame_center_y - windows_center_y)
                    let distance = sqrt(distance_x*distance_x + distance_y*distance_y)
                    if Float(distance) < min_distance {
                        min_distance = Float(distance)
                        min_index = index
                    }
                }
            }
            //If a displaced window took the frame that the previously aligned window was aligned to, then it is no longer aligned
            if min_distance >= 1.0 {
                alignedNoMoreWindows.append(window)
            }
            else {
                let frameAssignment = FrameAssignment(frame: candidateFramesMutable[min_index], window: window, focused: window.isEqual(to: focusedWindow), screenFrame: screenFrame)
                frameAssignments.append(frameAssignment)
                candidateFramesMutable.remove(at: min_index)
            }
        }

        //Now assigned anything that is left
        for window in alignedNoMoreWindows {
            var min_distance = FLT_MAX
            var min_index = -1
            let window_frame = window.frame()
            //Sometimes the windows become degenerate for some reason, ignore them
            if !isDegenerateWindow(window:window) {
                let windows_center_x = window_frame.origin.x + (window_frame.width/2.0)
                let windows_center_y = window_frame.origin.y + (window_frame.height/2.0)
                for (index, frame) in candidateFramesMutable.enumerated() {
                    let frame_center_x = frame.origin.x + (frame.width/2.0)
                    let frame_center_y = frame.origin.y + (frame.height/2.0)
                    let distance_x = (frame_center_x - windows_center_x)
                    let distance_y = (frame_center_y - windows_center_y)
                    let distance = sqrt(distance_x*distance_x + distance_y*distance_y)
                    if Float(distance) < min_distance {
                        min_distance = Float(distance)
                        min_index = index
                    }
                }
            }
            if min_index != -1 {
                let frameAssignment = FrameAssignment(frame: candidateFramesMutable[min_index], window: window, focused: window.isEqual(to: focusedWindow), screenFrame: screenFrame)
                frameAssignments.append(frameAssignment)
                candidateFramesMutable.remove(at: min_index)
            }
        }

        performFrameAssignments(frameAssignments)
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
