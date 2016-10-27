//
//  MiddleWideLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/15/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class MiddleWideReflowOperation: ReflowOperation {
    fileprivate let layout: MiddleWideLayout

    fileprivate init(screen: NSScreen, windows: [SIWindow], layout: MiddleWideLayout, windowActivityCache: WindowActivityCache) {
        self.layout = layout
        super.init(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }

    fileprivate override func main() {
        if windows.count == 0 {
            return
        }

        let secondaryPaneCount = round(Double(windows.count - 1) / 2.0)
        let tertiaryPaneCount = Double(windows.count - 1) - secondaryPaneCount

        let hasSecondaryPane = secondaryPaneCount > 0
        let hasTertiaryPane = tertiaryPaneCount > 0

        let screenFrame = adjustedFrameForLayout(screen)

        let mainPaneWindowHeight = screenFrame.height
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

        let frameAssignments = windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let windowIndex = frameAssignments.count

            if windowIndex == 0 {
                windowFrame.origin.x = screenFrame.origin.x + (hasSecondaryPane ? secondaryPaneWindowWidth : 0)
                windowFrame.origin.y = screenFrame.origin.y
                windowFrame.size.width = mainPaneWindowWidth
                windowFrame.size.height = mainPaneWindowHeight
            } else if windowIndex > Int(secondaryPaneCount) { // tertiary
                windowFrame.origin.x = screenFrame.origin.x + secondaryPaneWindowWidth + mainPaneWindowWidth
                windowFrame.origin.y = screenFrame.origin.y + (tertiaryPaneWindowHeight * CGFloat(Double(windowIndex) - (1 + secondaryPaneCount)))
                windowFrame.size.width = tertiaryPaneWindowWidth
                windowFrame.size.height = tertiaryPaneWindowHeight
            } else { // secondary
                windowFrame.origin.x = screenFrame.origin.x
                windowFrame.origin.y = screenFrame.maxY - secondaryPaneWindowHeight * CGFloat(windowIndex)
                windowFrame.size.width = secondaryPaneWindowWidth
                windowFrame.size.height = secondaryPaneWindowHeight
            }

            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isEqual(to: focusedWindow), screenFrame: screenFrame)

            assignments.append(frameAssignment)

            return assignments
        }

        if isCancelled {
            return
        }

        performFrameAssignments(frameAssignments)
    }
}

open class MiddleWideLayout: Layout {
    override open class var layoutName: String { return "Middle Wide" }
    override open class var layoutKey: String { return "middle-wide" }

    fileprivate var mainPaneRatio: CGFloat = 0.5

    override open func reflowOperationForScreen(_ screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return MiddleWideReflowOperation(screen: screen, windows: windows, layout: self, windowActivityCache: windowActivityCache)
    }

    override open func expandMainPane() {
        mainPaneRatio = min(1, mainPaneRatio + UserConfiguration.shared.windowResizeStep())
    }

    override open func shrinkMainPane() {
        mainPaneRatio = max(0, mainPaneRatio - UserConfiguration.shared.windowResizeStep())
    }
}
