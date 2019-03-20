//
//  TallRightLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class TallRightReflowOperation<Window: WindowType>: ReflowOperation<Window> {
    let layout: TallRightLayout<Window>

    init(screen: NSScreen, windows: [AnyWindow<Window>], layout: TallRightLayout<Window>, frameAssigner: FrameAssigner) {
        self.layout = layout
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    override func frameAssignments() -> [FrameAssignment<Window>]? {
        guard !windows.isEmpty else {
            return []
        }

        let mainPaneCount = min(windows.count, layout.mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()

        let mainPaneWindowHeight = round(screenFrame.size.height / CGFloat(mainPaneCount))
        let secondaryPaneWindowHeight = hasSecondaryPane ? round(screenFrame.size.height / CGFloat(secondaryPaneCount)) : 0.0

        let mainPaneWindowWidth = round(screenFrame.size.width * (hasSecondaryPane ? CGFloat(layout.mainPaneRatio) : 1.0))
        let secondaryPaneWindowWidth = screenFrame.size.width - mainPaneWindowWidth

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment<Window>] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let isMain = frameAssignments.count < mainPaneCount
            var scaleFactor: CGFloat

            if isMain {
                scaleFactor = screenFrame.size.width / mainPaneWindowWidth
                windowFrame.origin.x = screenFrame.origin.x + secondaryPaneWindowWidth
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(frameAssignments.count))
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                scaleFactor = screenFrame.size.width / secondaryPaneWindowWidth
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.maxY - (secondaryPaneWindowHeight * CGFloat(frameAssignments.count - mainPaneCount + 1))
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
            }

            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: .horizontal, scaleFactor: scaleFactor)
            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isFocused(), screenFrame: screenFrame, resizeRules: resizeRules)

            assignments.append(frameAssignment)

            return assignments
        }
    }
}

final class TallRightLayout<Window: WindowType>: Layout<Window>, PanedLayout {
    override static var layoutName: String { return "Tall Right" }
    override static var layoutKey: String { return "tall-right" }

    private(set) var mainPaneCount: Int = 1
    private(set) var mainPaneRatio: CGFloat = 0.5

    func recommendMainPaneRawRatio(rawRatio: CGFloat) {
        mainPaneRatio = rawRatio
    }

    func increaseMainPaneCount() {
        mainPaneCount += 1
    }

    func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }

    override func reflow(_ windows: [AnyWindow<Window>], on screen: NSScreen) -> ReflowOperation<Window>? {
        let assigner = Assigner(windowActivityCache: windowActivityCache)
        return TallRightReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: assigner)
    }
}
