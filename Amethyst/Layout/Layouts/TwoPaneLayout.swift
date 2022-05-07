//
//  TwoPaneLayout.swift
//  Amethyst
//
//  Created by @mwz on 10/06/2021.
//  Copyright © 2021 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class TwoPaneLayout<Window: WindowType>: Layout<Window>, PanedLayout {
    override static var layoutName: String { return "Two Pane" }
    override static var layoutKey: String { return "two-pane" }

    enum CodingKeys: String, CodingKey {
        case mainPaneCount
        case mainPaneRatio
    }

    override var layoutDescription: String { return "" }

    private(set) var mainPaneCount: Int = 1
    private(set) var mainPaneRatio: CGFloat = 0.5

    required init() {
        super.init()
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.mainPaneCount = try values.decode(Int.self, forKey: .mainPaneCount)
        self.mainPaneRatio = try values.decode(CGFloat.self, forKey: .mainPaneRatio)
        super.init()
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mainPaneCount, forKey: .mainPaneCount)
        try container.encode(mainPaneRatio, forKey: .mainPaneRatio)
    }

    func recommendMainPaneRawRatio(rawRatio: CGFloat) {
        mainPaneRatio = rawRatio
    }

    func increaseMainPaneCount() {}

    func decreaseMainPaneCount() {}

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        let mainPaneCount = min(windows.count, self.mainPaneCount)
        let secondaryPaneCount = windows.count > 1 ? 1 : 0
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()
        let isHorizontal = (screenFrame.size.width / screenFrame.size.height) >= 1

        let mainPaneWindowHeight = screenFrame.size.height * (!isHorizontal && hasSecondaryPane ? mainPaneRatio : 1)
        let secondaryPaneWindowHeight = isHorizontal ? mainPaneWindowHeight : screenFrame.size.height - mainPaneWindowHeight

        let mainPaneWindowWidth = screenFrame.size.width * (isHorizontal && hasSecondaryPane ? mainPaneRatio : 1)
        let secondaryPaneWindowWidth = !isHorizontal ? mainPaneWindowWidth : screenFrame.size.width - mainPaneWindowWidth

        return windows.reduce([]) { acc, window -> [FrameAssignmentOperation<Window>] in
            var assignments = acc
            var windowFrame = CGRect.zero
            let isMain = acc.count < mainPaneCount
            var scaleFactor: CGFloat

            if isMain {
                scaleFactor = screenFrame.size.width / mainPaneWindowWidth
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                scaleFactor = screenFrame.size.width / secondaryPaneWindowWidth
                windowFrame.origin.x = screenFrame.origin.x + (isHorizontal ? mainPaneWindowWidth : 0)
                windowFrame.origin.y = screenFrame.origin.y + (isHorizontal ? 0 : mainPaneWindowHeight)
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
            }

            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: .horizontal, scaleFactor: scaleFactor)
            let frameAssignment = FrameAssignment<Window>(
                frame: windowFrame,
                window: window,
                screenFrame: screenFrame,
                resizeRules: resizeRules
            )

            assignments.append(FrameAssignmentOperation(frameAssignment: frameAssignment, windowSet: windowSet))

            return assignments
        }
    }
}
