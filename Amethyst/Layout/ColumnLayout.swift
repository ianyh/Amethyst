//
//  ColumnLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class ColumnReflowOperation: ReflowOperation {
    fileprivate let layout: ColumnLayout

    fileprivate init(screen: NSScreen, windows: [SIWindow], layout: ColumnLayout, windowActivityCache: WindowActivityCache) {
        self.layout = layout
        super.init(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }

    fileprivate override func main() {
        guard !windows.isEmpty else {
            return
        }

        let mainPaneCount = min(windows.count, layout.mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = adjustedFrameForLayout(screen)
        let mainPaneWindowWidth = round(screenFrame.width * (hasSecondaryPane ? CGFloat(layout.mainPaneRatio) : 1.0))
        let secondaryPaneWindowWidth = hasSecondaryPane ? round((screenFrame.width - mainPaneWindowWidth) / CGFloat(secondaryPaneCount)) : 0.0

        let focusedWindow = SIWindow.focused()

        let frameAssignments = windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            var windowFrame: CGRect = .zero

            if frameAssignments.count < mainPaneCount {
                windowFrame.origin.x = screenFrame.origin.x + (mainPaneWindowWidth * CGFloat(frameAssignments.count))
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = screenFrame.height
            } else {
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth + (secondaryPaneWindowWidth * CGFloat(frameAssignments.count - mainPaneCount))
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = screenFrame.height
            }

            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isEqual(to: focusedWindow), screenFrame: screenFrame)

            assignments.append(frameAssignment)

            return assignments
        }

        guard !isCancelled else {
            return
        }

        performFrameAssignments(frameAssignments)
    }
}

open class ColumnLayout: Layout {
    override open class var layoutName: String { return "Column" }
    override open class var layoutKey: String { return "column" }

    fileprivate var mainPaneCount: Int = 1
    fileprivate var mainPaneRatio: CGFloat = 0.5

    override open func reflowOperationForScreen(_ screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return ColumnReflowOperation(screen: screen, windows: windows, layout: self, windowActivityCache: windowActivityCache)
    }

    override public func expandMainPane() {
        mainPaneRatio = max(0, mainPaneRatio + UserConfiguration.shared.windowResizeStep())
    }

    override public func shrinkMainPane() {
        mainPaneRatio = max(0, mainPaneRatio - UserConfiguration.shared.windowResizeStep())
    }

    override public func increaseMainPaneCount() {
        mainPaneCount += 1
    }

    override public func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }
}
