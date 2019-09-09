//
//  WidescreenTallLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/15/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

final class WidescreenTallReflowOperation<Window: WindowType>: ReflowOperation<Window> {
    let layout: WidescreenTallLayout<Window>

    init(screen: NSScreen, windows: [Window], layout: WidescreenTallLayout<Window>, frameAssigner: FrameAssigner) {
        self.layout = layout
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    override func frameAssignments() -> [FrameAssignment<Window>]? {
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

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment<Window>] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let windowIndex = frameAssignments.count
            let isMain = windowIndex < mainPaneCount
            var scaleFactor: CGFloat

            if isMain {
                scaleFactor = CGFloat(screenFrame.size.width / mainPaneWindowWidth) / CGFloat(mainPaneCount)
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * CGFloat(windowIndex)
                if type(of: layout).isRight {
                    windowFrame.origin.x += secondaryPaneWindowWidth
                }
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                scaleFactor = CGFloat(screenFrame.size.width / secondaryPaneWindowWidth)
                windowFrame.origin.x = screenFrame.origin.x + mainPaneWindowWidth * CGFloat(mainPaneCount)
                windowFrame.origin.y = screenFrame.origin.y + (secondaryPaneWindowHeight * CGFloat(windowIndex - mainPaneCount))
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
                if type(of: layout).isRight {
                    windowFrame.origin.x = 0
                }
            }

            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: .horizontal, scaleFactor: scaleFactor)
            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isFocused(), screenFrame: screenFrame, resizeRules: resizeRules)

            assignments.append(frameAssignment)

            return assignments
        }
    }
}

class WidescreenTallLayout<Window: WindowType>: Layout<Window> {
    class var isRight: Bool { fatalError("Must be implemented by subclass") }
    private(set) var mainPaneCount: Int = 1
    private(set) var mainPaneRatio: CGFloat = 0.5

    override func reflow(_ windows: [Window], on screen: NSScreen) -> ReflowOperation<Window>? {
        let assigner = Assigner(windowActivityCache: windowActivityCache)
        return WidescreenTallReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: assigner)
    }
}

extension WidescreenTallLayout: PanedLayout {
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

final class WidescreenTallLayoutRight<Window: WindowType>: WidescreenTallLayout<Window> {
    override class var isRight: Bool { return false }
    override static var layoutName: String { return "Widescreen Tall" }
    override static var layoutKey: String { return "widescreen-tall" }
}

final class WidescreenTallLayoutLeft<Window: WindowType>: WidescreenTallLayout<Window> {
    override class var isRight: Bool { return true }
    override static var layoutName: String { return "Widescreen Tall Right" }
    override static var layoutKey: String { return "widescreen-tall-right" }
}
