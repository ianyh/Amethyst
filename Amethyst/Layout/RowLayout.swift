//
//  RowLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class RowReflowOperation: ReflowOperation {
    let layout: RowLayout

    init(screen: NSScreen, windows: [SIWindow], layout: RowLayout, frameAssigner: FrameAssigner) {
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

        let mainPaneWindowHeight = round(screenFrame.size.height * (hasSecondaryPane ? CGFloat(layout.mainPaneRatio) : 1.0))
        let secondaryPaneWindowHeight = hasSecondaryPane ? round((screenFrame.size.height - mainPaneWindowHeight) / CGFloat(secondaryPaneCount)) : 0.0

        let focusedWindow = SIWindow.focused()

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            var windowFrame: CGRect = .zero

            if frameAssignments.count < mainPaneCount {
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(frameAssignments.count))
                windowFrame.size.width = screenFrame.width
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(mainPaneCount)) + (secondaryPaneWindowHeight * CGFloat(frameAssignments.count - mainPaneCount))
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
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        layout.performFrameAssignments(frameAssignments)
    }
}

final class RowLayout: Layout {
    static var layoutName: String { return "Row" }
    static var layoutKey: String { return "row" }

    let windowActivityCache: WindowActivityCache

    fileprivate var mainPaneCount: Int = 1
    internal var mainPaneRatio: CGFloat = 0.5

    init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        return RowReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self)
    }

    func assignedFrame(_ window: SIWindow, of windows: [SIWindow], on screen: NSScreen) -> FrameAssignment? {
        return RowReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self).frameAssignments.first { $0.window == window }
    }
}

extension RowLayout: PanedLayout {
    func setMainPaneRawRatio(rawRatio: CGFloat) {
        mainPaneRatio = rawRatio
    }

    func increaseMainPaneCount() {
        mainPaneCount += 1
    }

    func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }
}

extension RowLayout: FrameAssigner {}
