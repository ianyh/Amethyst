//
//  ColumnLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class ColumnLayout<Window: WindowType>: Layout<Window>, PanedLayout {
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

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignment<Window>]? {
        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        let mainPaneCount = min(windows.count, self.mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()
        let mainPaneWidth = round(screenFrame.width * (hasSecondaryPane ? CGFloat(mainPaneRatio) : 1.0))
        let mainPaneWindowWidth = round(mainPaneWidth / CGFloat(mainPaneCount))
        let secondaryPaneWindowWidth = hasSecondaryPane ? round((screenFrame.width - mainPaneWidth) / CGFloat(secondaryPaneCount)) : 0.0

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
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWidth + (secondaryPaneWindowWidth * CGFloat(frameAssignments.count - mainPaneCount))
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = screenFrame.height
            }

            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: .horizontal, scaleFactor: scaleFactor)
            let frameAssignment = FrameAssignment<Window>(
                frame: windowFrame,
                window: window,
                screenFrame: screenFrame,
                resizeRules: resizeRules
            )

            assignments.append(frameAssignment)

            return assignments
        }
    }
}
