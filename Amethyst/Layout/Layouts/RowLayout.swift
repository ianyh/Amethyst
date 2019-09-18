//
//  RowLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class RowLayout<Window: WindowType>: Layout<Window>, PanedLayout {
    override static var layoutName: String { return "Row" }
    override static var layoutKey: String { return "row" }

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

        let mainPaneWindowHeight = round(screenFrame.size.height * (hasSecondaryPane ? CGFloat(mainPaneRatio) : 1.0))
        let secondaryPaneWindowHeight = hasSecondaryPane ? round((screenFrame.size.height - mainPaneWindowHeight) / CGFloat(secondaryPaneCount)) : 0.0

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment<Window>] in
            var assignments = frameAssignments
            var windowFrame: CGRect = .zero
            let isMain = frameAssignments.count < mainPaneCount
            var scaleFactor: CGFloat

            if isMain {
                scaleFactor = screenFrame.size.height / mainPaneWindowHeight
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(frameAssignments.count))
                windowFrame.size.width = screenFrame.width
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                scaleFactor = screenFrame.size.height / secondaryPaneWindowHeight / CGFloat(secondaryPaneCount)
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(mainPaneCount)) + (secondaryPaneWindowHeight * CGFloat(frameAssignments.count - mainPaneCount))
                windowFrame.size.width = screenFrame.width
                windowFrame.size.height = secondaryPaneWindowHeight
            }

            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: .vertical, scaleFactor: scaleFactor)
            let frameAssignment = FrameAssignment<Window>(
                frame: windowFrame,
                window: window,
                focused: windowSet.isWindowFloating(window),
                screenFrame: screenFrame,
                resizeRules: resizeRules
            )

            assignments.append(frameAssignment)

            return assignments
        }
    }
}
