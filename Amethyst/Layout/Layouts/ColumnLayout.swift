//
//  ColumnLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class ColumnReflowOperation<Window: WindowType>: ReflowOperation<Window> {
    let layout: ColumnLayout<Window>

    init(screen: NSScreen, windows: [AnyWindow<Window>], layout: ColumnLayout<Window>, frameAssigner: FrameAssigner) {
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
        let mainPaneWindowWidth = round(screenFrame.width * (hasSecondaryPane ? CGFloat(layout.mainPaneRatio) : 1.0))
        let secondaryPaneWindowWidth = hasSecondaryPane ? round((screenFrame.width - mainPaneWindowWidth) / CGFloat(secondaryPaneCount)) : 0.0

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment<Window>] in
            var assignments = frameAssignments
            var windowFrame: CGRect = .zero
            let isMain = frameAssignments.count < mainPaneCount
            var scaleFactor: CGFloat

            if isMain {
                scaleFactor = screenFrame.width / mainPaneWindowWidth
                windowFrame.origin.x = screenFrame.origin.x + (mainPaneWindowWidth * CGFloat(frameAssignments.count))
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = screenFrame.height
            } else {
                scaleFactor = (screenFrame.width / secondaryPaneWindowWidth) / CGFloat(secondaryPaneCount)
                windowFrame.origin.x = screenFrame.origin.x + (mainPaneWindowWidth * CGFloat(mainPaneCount)) + (secondaryPaneWindowWidth * CGFloat(frameAssignments.count - mainPaneCount))
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = screenFrame.height
            }

            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: .horizontal, scaleFactor: scaleFactor)
            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isFocused(), screenFrame: screenFrame, resizeRules: resizeRules)

            assignments.append(frameAssignment)

            return assignments
        }
    }
}

final class ColumnLayout<Window: WindowType>: Layout<Window>, PanedLayout {
    override static var layoutName: String { return "Column" }
    override static var layoutKey: String { return "column" }

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
        return ColumnReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: assigner)
    }
}
