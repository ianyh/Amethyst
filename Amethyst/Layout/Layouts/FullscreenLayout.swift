//
//  FullscreenLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class FullscreenReflowOperation<Window: WindowType>: ReflowOperation<Window> {
    private let layout: FullscreenLayout<Window>

    init(screen: NSScreen, windows: [AnyWindow<Window>], layout: FullscreenLayout<Window>, frameAssigner: FrameAssigner) {
        self.layout = layout
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    override func frameAssignments() -> [FrameAssignment<Window>]? {
        let screenFrame = screen.adjustedFrame()
        return windows.map { window in
            let resizeRules = ResizeRules(isMain: true, unconstrainedDimension: .horizontal, scaleFactor: 1)
            return FrameAssignment(frame: screenFrame, window: window, focused: false, screenFrame: screenFrame, resizeRules: resizeRules)
        }
    }
}

final class FullscreenLayout<Window: WindowType>: Layout<Window> {
    override static var layoutName: String { return "Fullscreen" }
    override static var layoutKey: String { return "fullscreen" }

    override var layoutDescription: String { return "" }

    override func reflow(_ windows: [AnyWindow<Window>], on screen: NSScreen) -> ReflowOperation<Window>? {
        let assigner = Assigner(windowActivityCache: windowActivityCache)
        return FullscreenReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: assigner)
    }
}
