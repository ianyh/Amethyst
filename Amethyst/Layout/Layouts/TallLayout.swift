//
//  TallLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class TallReflowOperation<Window: WindowType>: ReflowOperation<Window> {
    let layout: TallLayout<Window>

    init(screen: NSScreen, windows: [AnyWindow<Window>], layout: TallLayout<Window>, frameAssigner: FrameAssigner) {
        self.layout = layout
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    override func frameAssignments() -> [FrameAssignment<Window>]? {
        guard !windows.isEmpty else {
            return []
        }

        let mainPaneCount = min(windows.count, layout.mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()

        let mainPaneWindowHeight = round(screenFrame.size.height / CGFloat(mainPaneCount))
        let secondaryPaneWindowHeight = hasSecondaryPane ? round(screenFrame.size.height / CGFloat(secondaryPaneCount)) : 0.0

        let mainPaneWindowWidth = round(screenFrame.size.width * (hasSecondaryPane ? CGFloat(layout.mainPaneRatio) : 1.0))
        let secondaryPaneWindowWidth = screenFrame.size.width - mainPaneWindowWidth

        return windows.reduce([]) { acc, window -> [FrameAssignment<Window>] in
            var assignments = acc
            var windowFrame = CGRect.zero
            let isMain = acc.count < mainPaneCount
            var scaleFactor: CGFloat

            if isMain {
                scaleFactor = screenFrame.size.width / mainPaneWindowWidth
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(acc.count))
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                scaleFactor = screenFrame.size.width / secondaryPaneWindowWidth
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth
                windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * CGFloat(acc.count - mainPaneCount))
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
            }

            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: .horizontal, scaleFactor: scaleFactor)
            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isFocused(), screenFrame: screenFrame, resizeRules: resizeRules)

            assignments.append(frameAssignment)

            return assignments
        }
    }
}

final class TallLayout<Window: WindowType>: Layout<Window>, PanedLayout {
    override static var layoutName: String { return "Tall" }
    override static var layoutKey: String { return "tall" }

    override var layoutDescription: String { return "" }

    private(set) var mainPaneCount: Int = 1
    private(set) var mainPaneRatio: CGFloat = 0.5

    func recommendMainPaneRawRatio(rawRatio: CGFloat) {
        mainPaneRatio = rawRatio
    }

    func increaseMainPaneCount() {
        mainPaneCount += 1
    }

    func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }

    override func reflow(_ windows: [AnyWindow<Window>], on screen: NSScreen) -> ReflowOperation<Window>? {
        let assigner = Assigner(windowActivityCache: windowActivityCache)
        return TallReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: assigner)
    }
}
