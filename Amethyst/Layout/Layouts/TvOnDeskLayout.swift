//
//  TVOnDesk.swift
//  Amethyst
//
//  Created by @joelee on 10/21/2022.
//  Copyright © 2022 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class TvOnDeskLayout<Window: WindowType>: Layout<Window>, PanedLayout {
    override static var layoutName: String { return "TV on Desk" }
    override static var layoutKey: String { return "tv-on-desk" }

    enum CodingKeys: String, CodingKey {
        case mainPaneCount
        case mainPaneRatio
    }

    override var layoutDescription: String { return "" }

    private(set) var mainPaneCount: Int = 1
    private(set) var mainPaneRatio: CGFloat = 0.68

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
        if mainPaneCount <= 3 {
            mainPaneCount += 1
        }
        log.info("increaseMainPaneCount: \(mainPaneCount)")
    }

    func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
        log.info("decreaseMainPaneCount: \(mainPaneCount)")
    }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows
        let maxSecondaryPane = 3

        guard !windows.isEmpty else {
            return []
        }

        let mainPaneCount = min(windows.count, self.mainPaneCount)
        let secondaryPaneCount = windows.count > maxSecondaryPane ? maxSecondaryPane : windows.count
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()

        let mainPaneWindowHeight = round(screenFrame.size.height * CGFloat(self.mainPaneRatio))
        let secondaryPaneWindowHeight = hasSecondaryPane ? round(screenFrame.size.height - mainPaneWindowHeight) : 0.0

        let mainPaneWindowWidth = round(screenFrame.size.width / CGFloat(mainPaneCount))
        let secondaryPaneWindowWidth = hasSecondaryPane ? round(screenFrame.size.width / CGFloat(maxSecondaryPane)) : 0.0
        log.info("Screen (W:\(windows.count)): \(screenFrame.size.width)x\(screenFrame.size.height)")
        log.info("Main: \(mainPaneWindowWidth)x\(mainPaneWindowHeight)/\(mainPaneCount)")
        log.info("2ndary: \(secondaryPaneWindowWidth)x\(secondaryPaneWindowHeight)/\(secondaryPaneCount)")

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignmentOperation<Window>] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let isMain = frameAssignments.count < mainPaneCount
            var scaleFactor: CGFloat
            var secondaryPosition: CGFloat

            if isMain {
                scaleFactor = screenFrame.size.height / mainPaneWindowHeight
                windowFrame.origin.x = screenFrame.origin.x + (mainPaneWindowWidth * CGFloat(frameAssignments.count))
                windowFrame.origin.y = screenFrame.origin.y + secondaryPaneWindowWidth
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
                log.info("Main frame \(frameAssignments.count): \(windowFrame.origin.x)x\(windowFrame.origin.y)/\(scaleFactor)")
            } else {
                scaleFactor = screenFrame.size.height / secondaryPaneWindowHeight
                secondaryPosition = CGFloat((frameAssignments.count - mainPaneCount) % 3)
                windowFrame.origin.x = screenFrame.origin.x + (secondaryPaneWindowWidth * secondaryPosition)
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
                log.info("2nd frame \(frameAssignments.count): \(windowFrame.origin.x)x\(windowFrame.origin.y)/\(scaleFactor)")
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
