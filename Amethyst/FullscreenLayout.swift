//
//  FullscreenLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class FullscreenReflowOperation: ReflowOperation {
    private override func main() {
        let screenFrame = adjustedFrameForLayout(screen)
        let frameAssignments: [FrameAssignment] = windows.map { window in
            return FrameAssignment(frame: screenFrame, window: window, focused: false, screenFrame: screenFrame)
        }

        if cancelled {
            return
        }

        performFrameAssignments(frameAssignments)
    }
}

@objc public class FullscreenLayout: Layout {
    override public class var layoutName: String { return "Fullscreen" }
    override public class var layoutKey: String { return "fullscreen" }

    override public func reflowOperationForScreen(screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return FullscreenReflowOperation(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }
}
