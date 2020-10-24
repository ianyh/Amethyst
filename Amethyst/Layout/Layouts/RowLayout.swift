//
//  RowLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class RowLayout<Window: WindowType>: Layout<Window>, PanedLayout {
    override static var layoutName: String { return "Row" }
    override static var layoutKey: String { return "row" }

    enum CodingKeys: String, CodingKey {
        case mainPaneCount
        case mainPaneRatio
    }

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

    func increaseMainPaneCount() {
        mainPaneCount += 1
    }

    func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        let mainPaneCount = min(windows.count, self.mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()

        let mainPaneHeight = floor(screenFrame.size.height * (hasSecondaryPane ? CGFloat(mainPaneRatio) : 1.0))
        let mainPaneWindowHeight = floor(mainPaneHeight / CGFloat(mainPaneCount))
        let secondaryPaneWindowHeight = hasSecondaryPane ? floor((screenFrame.size.height - mainPaneHeight) / CGFloat(secondaryPaneCount)) : 0.0

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignmentOperation<Window>] in
            var assignments = frameAssignments
            var windowFrame: CGRect = .zero
            let isMain = frameAssignments.count < mainPaneCount
            var scaleFactor: CGFloat

            if isMain {
                scaleFactor = screenFrame.size.height / mainPaneWindowHeight
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(frameAssignments.count))
                windowFrame.size.width = screenFrame.width
                windowFrame.size.height = mainPaneWindowHeight
            } else {
                scaleFactor = screenFrame.size.height / secondaryPaneWindowHeight / CGFloat(secondaryPaneCount)
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.origin.y + (mainPaneWindowHeight * CGFloat(mainPaneCount)) + (secondaryPaneWindowHeight * CGFloat(frameAssignments.count - mainPaneCount))
                windowFrame.size.width = screenFrame.width
                windowFrame.size.height = secondaryPaneWindowHeight
            }

            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: .vertical, scaleFactor: scaleFactor)
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
