//
//  WidescreenTallLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/15/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class WidescreenTallReflowOperation: ReflowOperation {
    private let layout: WidescreenTallLayout

    private init(screen: NSScreen, windows: [SIWindow], layout: WidescreenTallLayout, windowActivityCache: WindowActivityCache) {
        self.layout = layout
        super.init(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }

    private override func main() {
        if windows.count == 0 {
            return
        }

        let mainPaneCount = min(windows.count, layout.mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount

        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = adjustedFrameForLayout(screen)

        let mainPaneWindowHeight = screenFrame.height
        let secondaryPaneWindowHeight = hasSecondaryPane ? round(screenFrame.height / CGFloat(secondaryPaneCount)) : 0.0

        let mainPaneWindowWidth = CGFloat(round(screenFrame.size.width * CGFloat(hasSecondaryPane ? self.layout.mainPaneRatio : 1))) / CGFloat(mainPaneCount)
        let secondaryPaneWindowWidth = screenFrame.width - mainPaneWindowWidth * CGFloat(mainPaneCount)

        let focusedWindow = SIWindow.focusedWindow()

        let frameAssignments = windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let windowIndex = frameAssignments.count

            if windowIndex < mainPaneCount {
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * CGFloat(windowIndex)
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * CGFloat(mainPaneCount)
                windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * CGFloat(windowIndex - mainPaneCount))
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
            }

            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isEqualTo(focusedWindow), screenFrame: screenFrame)

            assignments.append(frameAssignment)

            return assignments
        }

        if cancelled {
            return
        }

        performFrameAssignments(frameAssignments)
    }
}

public class WidescreenTallLayout: Layout {
    override public class var layoutName: String { return "Widescreen Tall" }
    override public class var layoutKey: String { return "widescreen-tall" }

    private var mainPaneCount: Int = 1
    private var mainPaneRatio: CGFloat = 0.5

    override public func reflowOperationForScreen(screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return WidescreenTallReflowOperation(screen: screen, windows: windows, layout: self, windowActivityCache: windowActivityCache)
    }

    override public func expandMainPane() {
        mainPaneRatio = min(1, mainPaneRatio + UserConfiguration.sharedConfiguration.windowResizeStep())
    }

    override public func shrinkMainPane() {
        mainPaneRatio = max(0, mainPaneRatio - UserConfiguration.sharedConfiguration.windowResizeStep())
    }

    override public func increaseMainPaneCount() {
        mainPaneCount = mainPaneCount + 1
    }

    override public func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }
}
