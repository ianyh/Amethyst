//
//  FullscreenLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class FullscreenReflowOperation: ReflowOperation {
    private let layout: FullscreenLayout

    init(screen: NSScreen, windows: [SIWindow], layout: FullscreenLayout, frameAssigner: FrameAssigner) {
        self.layout = layout
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    func frameAssignments() -> [FrameAssignment] {
        let screenFrame = screen.adjustedFrame()
        return windows.map { window in
            let resizeRules = ResizeRules(isMain: true, unconstrainedDimension: .horizontal, scaleFactor: 1)
            return FrameAssignment(frame: screenFrame, window: window, focused: false, screenFrame: screenFrame, resizeRules: resizeRules)
        }
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        frameAssigner.performFrameAssignments(frameAssignments())
    }
}

final class FullscreenLayout: Layout {
    static var layoutName: String { return "Fullscreen" }
    static var layoutKey: String { return "fullscreen" }

    let windowActivityCache: WindowActivityCache

    init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        return FullscreenReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self)
    }

    func assignedFrame(_ window: SIWindow, of windows: [SIWindow], on screen: NSScreen) -> FrameAssignment? {
        return FullscreenReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self).frameAssignments().first { $0.window == window }
    }
}

extension FullscreenLayout: FrameAssigner {}
