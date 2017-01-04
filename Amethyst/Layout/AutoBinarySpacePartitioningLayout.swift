//
//  AutoBinarySpacePartitioningLayout.swift
//  Amethyst
//
//  Created by Donald J Patterson on 1/3/17.
//  Copyright © 2017 Donald J Patterson. All rights reserved.
//

import Silica

private class AutoBSPReflowOperation: ReflowOperation {
    fileprivate let layout: AutoBinarySpacePartitioningLayout

    fileprivate init(screen: NSScreen, windows: [SIWindow], layout: AutoBinarySpacePartitioningLayout, windowActivityCache: WindowActivityCache) {
        self.layout = layout
        super.init(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }

    fileprivate override func main() {
        if windows.count == 0 {
            return
        }
        // Create an array to hold all the window frames
        var binaryFrames = [CGRect]()
        // Add the first frame which is the whole screen
        let screenFrame = adjustedFrameForLayout(screen)
        binaryFrames.append(screenFrame)

        // Split until we have the right number of frames to hold the windows
        while binaryFrames.count < windows.count {
            //Find the frame with the largest area and then split it
            var largestArea: Float = -1.0
            var largestAreaIndex = -1
            for index in 0...(binaryFrames.count-1) {
                let candidate: CGRect = binaryFrames[index]

                let area = Float(candidate.size.width) * Float(candidate.size.height)
                if area >= largestArea { //Prefer later matches
                    largestArea = area
                    largestAreaIndex = index
                }
            }

            //Sanity check solution
            if largestAreaIndex < 0  {
                NSLog("Unable to find a window to split: Index of window of -1 is invalid")
                return
            }
            if largestArea <= 0  {
                NSLog("Unable to find a window to split: Largest window area of < 1 is invalid")
                return
            }

            //Calculate two child frames
            let splittableFrame = binaryFrames[largestAreaIndex]
            var childFrame1: CGRect
            var childFrame2: CGRect

            //Figure out how to split the frame
            if splittableFrame.size.width > splittableFrame.size.height  {
                //split vertically x | x
                let newWidth1 = floor(splittableFrame.size.width * layout.mainPaneRatio)
                let newWidth2 = ceil(splittableFrame.size.width - newWidth1)
                let newHeight1 = floor(splittableFrame.size.height)
                let newHeight2 = ceil(splittableFrame.size.height)
                childFrame1 = CGRect(x:splittableFrame.origin.x, y:splittableFrame.origin.y, width:newWidth1, height:newHeight1)
                childFrame2 = CGRect(x:(splittableFrame.origin.x + newWidth1), y:splittableFrame.origin.y, width:newWidth2, height:newHeight2)
            }
            else {
                //split horizontally  x
                //                    -
                //                    x
                let newWidth1 = floor(splittableFrame.size.width)
                let newWidth2 = ceil(splittableFrame.size.width)
                let newHeight1 = floor(splittableFrame.size.height * layout.mainPaneRatio)
                let newHeight2 = ceil(splittableFrame.size.height - newHeight1)
                childFrame1 = CGRect(x:splittableFrame.origin.x, y:splittableFrame.origin.y, width:newWidth1, height:newHeight1)
                childFrame2 = CGRect(x:splittableFrame.origin.x, y:splittableFrame.origin.y+newHeight1, width:newWidth2, height:newHeight2)
            }
            //Insert them in the list, replacing the parent
            binaryFrames[largestAreaIndex] = childFrame1
            binaryFrames.append(childFrame2)
        }

        //Assign windows to binaryFrames
        let focusedWindow = SIWindow.focused()

        let frameAssignments = windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments

            let windowFrame = binaryFrames[frameAssignments.count]

            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isEqual(to: focusedWindow), screenFrame: screenFrame)

            assignments.append(frameAssignment)

            return assignments
        }

        if isCancelled {
            return
        }

        performFrameAssignments(frameAssignments)
    }
}

open class AutoBinarySpacePartitioningLayout: Layout {
    override open class var layoutName: String { return "Auto Binary Space Partition" }
    override open class var layoutKey: String { return "absp" }

    fileprivate var mainPaneCount: Int = 1
    fileprivate var mainPaneRatio: CGFloat = 0.5

    override open func reflowOperationForScreen(_ screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return AutoBSPReflowOperation(screen: screen, windows: windows, layout: self, windowActivityCache: windowActivityCache)
    }

    override open func expandMainPane() {
        mainPaneRatio = min(1, mainPaneRatio + UserConfiguration.shared.windowResizeStep())
    }

    override open func shrinkMainPane() {
        mainPaneRatio = max(0, mainPaneRatio - UserConfiguration.shared.windowResizeStep())
    }

    override open func increaseMainPaneCount() {
        mainPaneCount = mainPaneCount + 1
    }

    override open func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }
}
