//
//  FullscreenLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class FullscreenReflowOperation: ReflowOperation {
    fileprivate override func main() {
        let screenFrame = adjustedFrameForLayout(screen)
        let frameAssignments: [FrameAssignment] = windows.map { window in
            return FrameAssignment(frame: screenFrame, window: window, focused: false, screenFrame: screenFrame)
        }

        if isCancelled {
            return
        }

        performFrameAssignments(frameAssignments)
    }
}

open class FullscreenLayout: Layout {
    override open class var layoutName: String { return "Fullscreen" }
    override open class var layoutKey: String { return "fullscreen" }

    override open func reflowOperationForScreen(_ screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return FullscreenReflowOperation(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }
}
