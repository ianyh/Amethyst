//
//  WidescreenTallLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/15/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class WidescreenTallLayout<Window: WindowType>: Layout<Window> {
    class var isRight: Bool { fatalError("Must be implemented by subclass") }
    private(set) var mainPaneCount: Int = 1
    private(set) var mainPaneRatio: CGFloat = 0.5

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignment<Window>]? {
        let windows = windowSet.windows

        if windows.count == 0 {
            return []
        }

        let mainPaneCount = min(windows.count, self.mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount

        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()

        let mainPaneWindowHeight = screenFrame.height
        let secondaryPaneWindowHeight = hasSecondaryPane ? round(screenFrame.height / CGFloat(secondaryPaneCount)) : 0.0

        let mainPaneWindowWidth = CGFloat(round(screenFrame.size.width * CGFloat(hasSecondaryPane ? mainPaneRatio : 1))) / CGFloat(mainPaneCount)
        let secondaryPaneWindowWidth = screenFrame.width - mainPaneWindowWidth * CGFloat(mainPaneCount)

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment<Window>] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let windowIndex = frameAssignments.count
            let isMain = windowIndex < mainPaneCount
            var scaleFactor: CGFloat

            if isMain {
                scaleFactor = CGFloat(screenFrame.size.width / mainPaneWindowWidth) / CGFloat(mainPaneCount)
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * CGFloat(windowIndex)
                if type(of: self).isRight {
                    windowFrame.origin.x += secondaryPaneWindowWidth
                }
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                scaleFactor = CGFloat(screenFrame.size.width / secondaryPaneWindowWidth)
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * CGFloat(mainPaneCount)
                windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * CGFloat(windowIndex - mainPaneCount))
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
                if type(of: self).isRight {
                    windowFrame.origin.x = screenFrame.origin.x
                }
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

extension WidescreenTallLayout: PanedLayout {
    func recommendMainPaneRawRatio(rawRatio: CGFloat) {
        mainPaneRatio = rawRatio
    }

    func increaseMainPaneCount() {
        mainPaneCount += 1
    }

    func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }
}

class WidescreenTallLayoutRight<Window: WindowType>: WidescreenTallLayout<Window> {
    override class var isRight: Bool { return false }
    override static var layoutName: String { return "Widescreen Tall" }
    override static var layoutKey: String { return "widescreen-tall" }
}

class WidescreenTallLayoutLeft<Window: WindowType>: WidescreenTallLayout<Window> {
    override class var isRight: Bool { return true }
    override static var layoutName: String { return "Widescreen Tall Right" }
    override static var layoutKey: String { return "widescreen-tall-right" }
}
