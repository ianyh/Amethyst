//
//  TwoRowLayout.swift
//  Amethyst
//
//  Created by @joelee on 10/21/2022.
//  Copyright © 2022 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class TwoRowLayout<Window: WindowType>: Layout<Window>, PanedLayout {
    override static var layoutName: String { return "Two Row" }
    override static var layoutKey: String { return "two-row" }

    enum CodingKeys: String, CodingKey {
        case mainPaneCount
        case mainPaneRatio
        case mainMaxPane
        case secondaryMaxPane
    }

    override var layoutDescription: String { return "" }

    private(set) var mainPaneCount: Int = 1
    private(set) var mainPaneRatio: CGFloat = 0.68
    private(set) var mainMaxPane: Int = 3
    private(set) var secondaryMaxPane: Int = 4

    required init() {
        super.init()
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.mainPaneCount = try values.decode(Int.self, forKey: .mainPaneCount)
        self.mainPaneRatio = try values.decode(CGFloat.self, forKey: .mainPaneRatio)
        self.mainMaxPane = try values.decode(Int.self, forKey: .mainMaxPane)
        self.secondaryMaxPane = try values.decode(Int.self, forKey: .secondaryMaxPane)
        log.debug("TwoRow.init - mc:\(self.mainPaneCount) mr:\(self.mainPaneRatio) mM:\(self.mainMaxPane) 2M:\(self.secondaryMaxPane)")
        super.init()
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mainPaneCount, forKey: .mainPaneCount)
        try container.encode(mainPaneRatio, forKey: .mainPaneRatio)
        try container.encode(mainMaxPane, forKey: .mainMaxPane)
        try container.encode(secondaryMaxPane, forKey: .secondaryMaxPane)
    }

    func recommendMainPaneRawRatio(rawRatio: CGFloat) {
        log.debug("recommendMainPaneRawRatio: \(rawRatio)")
        mainPaneRatio = rawRatio
    }

    func increaseMainPaneCount() {
        if mainPaneCount <= mainMaxPane {
            mainPaneCount += 1
        }
        log.debug("increaseMainPaneCount: \(mainPaneCount)")
    }

    func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
        log.debug("decreaseMainPaneCount: \(mainPaneCount)")
    }

    // Decrease Maximum Main Pane Count
    func command1() {
        mainMaxPane = max(1, mainMaxPane - 1)
        if mainPaneCount > mainMaxPane {
            mainPaneCount = mainMaxPane
        }
        log.debug("cmd1 mainMaxPane: \(mainMaxPane)")
    }

    // Increase Maximum Main Pane Count
    func command2() {
        mainMaxPane += 1
        log.debug("cmd2 mainMaxPane: \(mainMaxPane)")
    }

    // Decrease Maximum Secondary Pane Count
    func command3() {
        secondaryMaxPane = max(1, secondaryMaxPane - 1)
        log.debug("cmd3 secondaryMaxPane: \(secondaryMaxPane)")
    }

    // Increase Maximum Secondary Pane Count
    func command4() {
        secondaryMaxPane += 1
        log.debug("cmd4 secondaryMaxPane: \(secondaryMaxPane)")
    }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        let mainPaneCount = min(windows.count, mainPaneCount)
        let secondaryPaneCount = windows.count - mainPaneCount > secondaryMaxPane ? secondaryMaxPane : windows.count - mainPaneCount
        let hasSecondaryPane = secondaryPaneCount > 0

        let screenFrame = screen.adjustedFrame()

        let mainPaneWindowHeight = round(screenFrame.size.height * CGFloat(mainPaneRatio))
        let secondaryPaneWindowHeight = hasSecondaryPane ? round(screenFrame.size.height - mainPaneWindowHeight) : 0.0

        let mainPaneWindowWidth = round(screenFrame.size.width / CGFloat(mainPaneCount))
        let secondaryPaneWindowWidth = hasSecondaryPane ? round(screenFrame.size.width / CGFloat(min(secondaryPaneCount, secondaryMaxPane))) : 0.0
        log.debug("*** frameA SF: \(screenFrame.size.width)x\(screenFrame.size.height) M:\(mainPaneCount)@\(mainPaneWindowHeight) 2:\(secondaryPaneCount)@\(secondaryPaneWindowHeight)")

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignmentOperation<Window>] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let isMain = frameAssignments.count < mainPaneCount
            var scaleFactor: CGFloat

            if isMain {
                scaleFactor = screenFrame.height / mainPaneWindowHeight
                windowFrame.origin.x = screenFrame.origin.x + (mainPaneWindowWidth * CGFloat(frameAssignments.count))
                windowFrame.origin.y = screenFrame.origin.y + secondaryPaneWindowWidth
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
                log.debug("frameA MF \(frameAssignments.count): \(windowFrame.origin.x)x\(windowFrame.origin.y) SF:\(scaleFactor) S:\(screenFrame.origin.x)x\(screenFrame.origin.y)")
            } else {
                scaleFactor = screenFrame.height / secondaryPaneWindowHeight
                let secondaryPosition = CGFloat((frameAssignments.count - mainPaneCount) % self.secondaryMaxPane)
                windowFrame.origin.x = screenFrame.origin.x + (secondaryPaneWindowWidth * secondaryPosition)
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
                log.debug("frameA 2F \(frameAssignments.count): \(windowFrame.origin.x)x\(windowFrame.origin.y) SF:\(scaleFactor) S:\(screenFrame.origin.x)x\(screenFrame.origin.y)")
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
