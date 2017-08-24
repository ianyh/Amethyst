//
//  WidescreenTallLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/15/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class WidescreenTallReflowOperation: ReflowOperation {
    let layout: WidescreenTallLayout

    init(screen: NSScreen, windows: [SIWindow], layout: WidescreenTallLayout, frameAssigner: FrameAssigner) {
        self.layout = layout
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    var frameAssignments: [FrameAssignment] {
        if windows.count == 0 {
            return []
        }

        let mainPaneCount = min(windows.count, layout.mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount

        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()

        let mainPaneWindowHeight = screenFrame.height
        let secondaryPaneWindowHeight = hasSecondaryPane ? round(screenFrame.height / CGFloat(secondaryPaneCount)) : 0.0

        let mainPaneWindowWidth = CGFloat(round(screenFrame.size.width * CGFloat(hasSecondaryPane ? self.layout.mainPaneRatio : 1))) / CGFloat(mainPaneCount)
        let secondaryPaneWindowWidth = screenFrame.width - mainPaneWindowWidth * CGFloat(mainPaneCount)

        let focusedWindow = SIWindow.focused()

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let windowIndex = frameAssignments.count
            let isMain = windowIndex < mainPaneCount
            var scaleFactor: CGFloat

            if isMain {
                scaleFactor = CGFloat(screenFrame.size.width / mainPaneWindowWidth)
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * CGFloat(windowIndex)
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                scaleFactor = CGFloat(screenFrame.size.width / secondaryPaneWindowWidth)
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * CGFloat(mainPaneCount)
                windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * CGFloat(windowIndex - mainPaneCount))
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
            }

            let resizeRules = ResizeRules(isMain: isMain, scaleFactor: scaleFactor, unconstrainedDimension: .horizontal)
            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isEqual(to: focusedWindow), screenFrame: screenFrame, resizeRules: resizeRules)

            assignments.append(frameAssignment)

            return assignments
        }
    }

    override func main() {

        if isCancelled {
            return
        }

        frameAssigner.performFrameAssignments(frameAssignments)
    }
}

final class WidescreenTallLayout: Layout {
    static var layoutName: String { return "Widescreen Tall" }
    static var layoutKey: String { return "widescreen-tall" }

    let windowActivityCache: WindowActivityCache

    fileprivate var mainPaneCount: Int = 1
    internal var mainPaneRatio: CGFloat = 0.5

    init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        return WidescreenTallReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self)
    }

    func assignedFrame(_ window: SIWindow, of windows: [SIWindow], on screen: NSScreen) -> FrameAssignment? {
        return WidescreenTallReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self).frameAssignments.first { $0.window == window }
    }
}

extension WidescreenTallLayout: PanedLayout {
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

extension WidescreenTallLayout: FrameAssigner {}
