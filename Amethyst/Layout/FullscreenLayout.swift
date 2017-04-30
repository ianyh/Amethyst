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

    override func main() {
        let screenFrame = screen.adjustedFrame()
        let frameAssignments: [FrameAssignment] = windows.map { window in
            return FrameAssignment(frame: screenFrame, window: window, focused: false, screenFrame: screenFrame)
        }

        guard !isCancelled else {
            return
        }

        frameAssigner.performFrameAssignments(frameAssignments)
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
}

extension FullscreenLayout: FrameAssigner {}
