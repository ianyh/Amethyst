//
//  FullscreenLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class FullscreenLayout<Window: WindowType>: Layout<Window> {
    override static var layoutName: String { return "Fullscreen" }
    override static var layoutKey: String { return "fullscreen" }

    override var layoutDescription: String { return "" }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let screenFrame = screen.adjustedFrame()
        return windowSet.windows.map { window in
            let resizeRules = ResizeRules(isMain: true, unconstrainedDimension: .horizontal, scaleFactor: 1)
            let frameAssignment = FrameAssignment<Window>(frame: screenFrame, window: window, screenFrame: screenFrame, resizeRules: resizeRules)
            return FrameAssignmentOperation(frameAssignment: frameAssignment, windowSet: windowSet)
        }
    }
}
