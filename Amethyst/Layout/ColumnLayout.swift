//
//  ColumnLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class ColumnReflowOperation: ReflowOperation {
    fileprivate let layout: ColumnLayout

    fileprivate init(screen: NSScreen, windows: [SIWindow], layout: ColumnLayout, windowActivityCache: WindowActivityCache) {
        self.layout = layout
        super.init(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }

    fileprivate override func main() {
        if windows.count == 0 {
            return
        }

        let screenFrame = adjustedFrameForLayout(screen)
        let windowWidth = screenFrame.width / CGFloat(windows.count)

        let focusedWindow = SIWindow.focused()

        let frameAssignments = windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            let originX = screenFrame.origin.x + CGFloat(frameAssignments.count) * windowWidth
            let windowFrame = CGRect(x: originX, y: screenFrame.origin.y, width: windowWidth, height: screenFrame.size.height)

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

open class ColumnLayout: Layout {
    override open class var layoutName: String { return "Column" }
    override open class var layoutKey: String { return "column" }

    override open func reflowOperationForScreen(_ screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return ColumnReflowOperation(screen: screen, windows: windows, layout: self, windowActivityCache: windowActivityCache)
    }
}
