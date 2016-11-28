//
//  RowLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class RowReflowOperation: ReflowOperation {
    fileprivate let layout: RowLayout

    fileprivate init(screen: NSScreen, windows: [SIWindow], layout: RowLayout, windowActivityCache: WindowActivityCache) {
        self.layout = layout
        super.init(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }

    fileprivate override func main() {
        if windows.count == 0 {
            return
        }

        let screenFrame = adjustedFrameForLayout(screen)
        let windowHeight = screenFrame.height / CGFloat(windows.count)

        let focusedWindow = SIWindow.focused()

        let frameAssignments = windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            let originY = screenFrame.origin.y + CGFloat(frameAssignments.count) * windowHeight
            let windowFrame = CGRect(x: screenFrame.origin.x, y: originY, width: screenFrame.width, height: windowHeight)

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

open class RowLayout: Layout {
    override open class var layoutName: String { return "Row" }
    override open class var layoutKey: String { return "row" }

    override open func reflowOperationForScreen(_ screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return RowReflowOperation(screen: screen, windows: windows, layout: self, windowActivityCache: windowActivityCache)
    }
}
