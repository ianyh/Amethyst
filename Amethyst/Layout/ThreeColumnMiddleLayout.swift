//
//  ThreeColumnMiddleLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/15/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class ThreeColumnMiddleReflowOperation: ReflowOperation {
    private let layout: ThreeColumnMiddleLayout

    init(screen: NSScreen, windows: [SIWindow], layout: ThreeColumnMiddleLayout, frameAssigner: FrameAssigner) {
        self.layout = layout
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    func frameAssignments() -> [FrameAssignment] {
        guard !windows.isEmpty else {
            return []
        }

        let mainPaneCount = min(windows.count, layout.mainPaneCount)
        let secondaryPaneCount = round(Double(windows.count - mainPaneCount) / 2.0)
        let tertiaryPaneCount = Double(windows.count - mainPaneCount) - secondaryPaneCount

        let hasSecondaryPane = secondaryPaneCount > 0
        let hasTertiaryPane = tertiaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()

        let mainPaneWindowHeight = round(screenFrame.height / CGFloat(mainPaneCount))
        let secondaryPaneWindowHeight = hasSecondaryPane ? round(screenFrame.height / CGFloat(secondaryPaneCount)) : 0.0
        let tertiaryPaneWindowHeight = hasTertiaryPane ? round(screenFrame.height / CGFloat(tertiaryPaneCount)) : 0.0

        var mainPaneWindowWidth: CGFloat = 0.0
        var secondaryPaneWindowWidth: CGFloat = 0.0
        if hasSecondaryPane && hasTertiaryPane {
            mainPaneWindowWidth = round(screenFrame.width * CGFloat(layout.mainPaneRatio))
            secondaryPaneWindowWidth = round((screenFrame.width - mainPaneWindowWidth) / 2)
        } else if hasSecondaryPane {
            secondaryPaneWindowWidth = round(screenFrame.width * CGFloat(layout.mainPaneRatio))
            mainPaneWindowWidth = screenFrame.width - secondaryPaneWindowWidth
        } else {
            mainPaneWindowWidth = screenFrame.width
        }

        let tertiaryPaneWindowWidth = screenFrame.width - mainPaneWindowWidth - secondaryPaneWindowWidth

        let focusedWindow = SIWindow.focused()

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let windowIndex = frameAssignments.count
            // main windows are indexes [0, mainPaneCount)
            let isMain = windowIndex < mainPaneCount
            // secondary windows are indexes [mainPaneCount, mainPaneCount + secondaryPaneCount)
            // tertiary windows are indexes [mainPaneCount + secondaryPaneCount, ...)
            let hasTertiary = windowIndex >= (mainPaneCount + Int(secondaryPaneCount))
            var scaleFactor: CGFloat

            scaleFactor = (screenFrame.width / secondaryPaneWindowWidth)
            if isMain { // main (center)
                let mainSubIndex = windowIndex
                scaleFactor = screenFrame.width / mainPaneWindowWidth
                windowFrame.origin.x = screenFrame.origin.x + (hasSecondaryPane ? secondaryPaneWindowWidth : 0)
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(mainSubIndex))
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else if hasTertiary { // tertiary (right)
                let tertiarySubIndex = windowIndex - (mainPaneCount + Int(secondaryPaneCount))
                windowFrame.origin.x = screenFrame.origin.x + secondaryPaneWindowWidth + mainPaneWindowWidth
                windowFrame.origin.y = screenFrame.origin.y + (tertiaryPaneWindowHeight * CGFloat(tertiarySubIndex))
                windowFrame.size.width = tertiaryPaneWindowWidth
                windowFrame.size.height = tertiaryPaneWindowHeight
            } else { // secondary (left)
                let secondarySubIndex = windowIndex - mainPaneCount
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * CGFloat(secondarySubIndex))
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
            }

            let isTertiaryMain = (hasTertiaryPane ? isMain : !isMain)

            let resizeRules = ResizeRules(isMain: isTertiaryMain, unconstrainedDimension: .horizontal, scaleFactor: scaleFactor)
            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isEqual(to: focusedWindow), screenFrame: screenFrame, resizeRules: resizeRules)

            assignments.append(frameAssignment)

            return assignments
        }
    }

    override func main() {

        guard !isCancelled else {
            return
        }

        layout.performFrameAssignments(frameAssignments())
    }
}

final class ThreeColumnMiddleLayout: Layout {
    static var layoutName: String { return "3Column Middle" }
    static var layoutKey: String { return "middle-wide" }  // for backwards compatibility with users who still have 'middle-wide' in their active layouts

    let windowActivityCache: WindowActivityCache

    fileprivate var mainPaneCount: Int = 1
    fileprivate(set) var mainPaneRatio: CGFloat = 0.5

    init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        return ThreeColumnMiddleReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self)
    }

    func assignedFrame(_ window: SIWindow, of windows: [SIWindow], on screen: NSScreen) -> FrameAssignment? {
        return ThreeColumnMiddleReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self).frameAssignments().first { $0.window == window }
    }
}

extension ThreeColumnMiddleLayout: PanedLayout {
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

extension ThreeColumnMiddleLayout: FrameAssigner {}
