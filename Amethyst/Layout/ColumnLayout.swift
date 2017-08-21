//
//  ColumnLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class ColumnReflowOperation: ReflowOperation {
    let layout: ColumnLayout

    init(screen: NSScreen, windows: [SIWindow], layout: ColumnLayout, frameAssigner: FrameAssigner) {
        self.layout = layout
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    var frameAssignments: [FrameAssignment] {
        guard !windows.isEmpty else {
            return []
        }

        let mainPaneCount = min(windows.count, layout.mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()
        let mainPaneWindowWidth = round(screenFrame.width * (hasSecondaryPane ? CGFloat(layout.mainPaneRatio) : 1.0))
        let secondaryPaneWindowWidth = hasSecondaryPane ? round((screenFrame.width - mainPaneWindowWidth) / CGFloat(secondaryPaneCount)) : 0.0

        let focusedWindow = SIWindow.focused()

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
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
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        frameAssigner.performFrameAssignments(frameAssignments)
    }
}

final class ColumnLayout: Layout {
    static var layoutName: String { return "Column" }
    static var layoutKey: String { return "column" }

    let windowActivityCache: WindowActivityCache
    fileprivate var mainPaneCount: Int = 1
    fileprivate var mainPaneRatio: CGFloat = 0.5

    init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        return ColumnReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self)
    }

    func assignedFrame(_ window: SIWindow, of windows: [SIWindow], on screen: NSScreen) -> FrameAssignment? {
        return ColumnReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self).frameAssignments.first { $0.window == window }
    }

}

extension ColumnLayout: PanedLayout {
    func expandMainPane() {
        mainPaneRatio = max(0, mainPaneRatio + UserConfiguration.shared.windowResizeStep())
    }

    func shrinkMainPane() {
        mainPaneRatio = max(0, mainPaneRatio - UserConfiguration.shared.windowResizeStep())
    }

    func increaseMainPaneCount() {
        mainPaneCount += 1
    }

    func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }
}

extension ColumnLayout: FrameAssigner {}
