//
//  TallLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class TallReflowOperation: ReflowOperation {
    let layout: TallLayout

    init(screen: NSScreen, windows: [SIWindow], layout: TallLayout, frameAssigner: FrameAssigner) {
        self.layout = layout
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    override func main() {
        guard !windows.isEmpty else {
            return
        }

        let mainPaneCount = min(windows.count, layout.mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()

        let mainPaneWindowHeight = round(screenFrame.size.height / CGFloat(mainPaneCount))
        let secondaryPaneWindowHeight = hasSecondaryPane ? round(screenFrame.size.height / CGFloat(secondaryPaneCount)) : 0.0

        let mainPaneWindowWidth = round(screenFrame.size.width * (hasSecondaryPane ? CGFloat(layout.mainPaneRatio) : 1.0))
        let secondaryPaneWindowWidth = screenFrame.size.width - mainPaneWindowWidth

        let focusedWindow = SIWindow.focused()

        let frameAssignments = windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            let focused = focusedWindow != nil && window.processIdentifier() == focusedWindow?.processIdentifier()
            var assignments = frameAssignments
            var windowFrame = CGRect.zero

            if frameAssignments.count < mainPaneCount {
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(frameAssignments.count))
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth
                windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * CGFloat(frameAssignments.count - mainPaneCount))
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
            }

            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: focused, screenFrame: screenFrame)

            assignments.append(frameAssignment)

            return assignments
        }

        guard !isCancelled else {
            return
        }

        frameAssigner.performFrameAssignments(frameAssignments)
    }
}

final class TallLayout: Layout {
    static var layoutName: String { return "Tall" }
    static var layoutKey: String { return "tall" }

    let windowActivityCache: WindowActivityCache

    fileprivate var mainPaneCount: Int = 1
    fileprivate var mainPaneRatio: CGFloat = 0.5

    init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        return TallReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self)
    }
}

extension TallLayout: PanedLayout {
    func expandMainPane() {
        mainPaneRatio = min(1, mainPaneRatio + UserConfiguration.shared.windowResizeStep())
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

extension TallLayout: FrameAssigner {}
