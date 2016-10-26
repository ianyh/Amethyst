//
//  RowLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class RowReflowOperation: ReflowOperation {
    private let layout: RowLayout

    private init(screen: NSScreen, windows: [SIWindow], layout: RowLayout, windowActivityCache: WindowActivityCache) {
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

        let mainPaneWindowHeight = round(screenFrame.size.height * (hasSecondaryPane ? CGFloat(layout.mainPaneRatio) : 1.0))
        let secondaryPaneWindowHeight = hasSecondaryPane ? round((screenFrame.size.height - mainPaneWindowHeight) / CGFloat(secondaryPaneCount)) : 0.0

        let focusedWindow = SIWindow.focusedWindow()

        let frameAssignments = windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero

            // let windowFrame = CGRect(x: screenFrame.origin.x, y: originY, width: screenFrame.width, height: windowHeight)

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
                focused: window.isEqualTo(focusedWindow),
                screenFrame: screenFrame
            )

            assignments.append(frameAssignment)

            return assignments
        }

        if cancelled {
            return
        }

        performFrameAssignments(frameAssignments)
    }
}

// TODO(glib): there is quite a lot of this copied around between Layouts... probably should abstract
public class RowLayout: Layout {
    override public class var layoutName: String { return "Row" }
    override public class var layoutKey: String { return "row" }

    private var mainPaneCount: Int = 1
    private var mainPaneRatio: CGFloat = 0.5

    override public func reflowOperationForScreen(screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return RowReflowOperation(screen: screen, windows: windows, layout: self, windowActivityCache: windowActivityCache)
    }

    override public func expandMainPane() {
        mainPaneRatio = max(0, mainPaneRatio + 0.05)
    }

    override public func shrinkMainPane() {
        mainPaneRatio = max(0, mainPaneRatio - 0.05)
    }

    override public func increaseMainPaneCount() {
        mainPaneCount = mainPaneCount + 1
    }

    override public func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }
}
