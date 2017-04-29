//
//  RowLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private final class RowReflowOperation: ReflowOperation {
    let layout: RowLayout

    init(screen: NSScreen, windows: [SIWindow], layout: RowLayout, windowActivityCache: WindowActivityCache) {
        self.layout = layout
        super.init(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }

    override func main() {
        if windows.count == 0 {
            return
        }

        let mainPaneCount = min(windows.count, layout.mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = adjustedFrameForLayout(screen)

        let mainPaneWindowHeight = round(screenFrame.size.height * (hasSecondaryPane ? CGFloat(layout.mainPaneRatio) : 1.0))
        let secondaryPaneWindowHeight = hasSecondaryPane ? round((screenFrame.size.height - mainPaneWindowHeight) / CGFloat(secondaryPaneCount)) : 0.0

        let focusedWindow = SIWindow.focused()

        let frameAssignments = windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            var windowFrame: CGRect = .zero

            if frameAssignments.count < mainPaneCount {
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(frameAssignments.count))
                windowFrame.size.width = screenFrame.width
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + mainPaneWindowHeight + (secondaryPaneWindowHeight * CGFloat(frameAssignments.count - mainPaneCount))
                windowFrame.size.width = screenFrame.width
                windowFrame.size.height = secondaryPaneWindowHeight
            }

            let frameAssignment = FrameAssignment(
                frame: windowFrame,
                window: window,
                focused: window.isEqual(to: focusedWindow),
                screenFrame: screenFrame
            )

            assignments.append(frameAssignment)

            return assignments
        }

        guard !isCancelled else {
            return
        }

        performFrameAssignments(frameAssignments)
    }
}

final class RowLayout: Layout {
    override class var layoutName: String { return "Row" }
    override class var layoutKey: String { return "row" }

    fileprivate var mainPaneCount: Int = 1
    fileprivate var mainPaneRatio: CGFloat = 0.5

    override func reflowOperationForScreen(_ screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return RowReflowOperation(screen: screen, windows: windows, layout: self, windowActivityCache: windowActivityCache)
    }

    override func expandMainPane() {
        mainPaneRatio = max(0, mainPaneRatio + UserConfiguration.shared.windowResizeStep())
    }

    override func shrinkMainPane() {
        mainPaneRatio = max(0, mainPaneRatio - UserConfiguration.shared.windowResizeStep())
    }

    override func increaseMainPaneCount() {
        mainPaneCount += 1
    }

    override func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }
}
