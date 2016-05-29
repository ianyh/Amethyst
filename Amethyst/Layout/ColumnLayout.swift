//
//  ColumnLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class ColumnReflowOperation: ReflowOperation {
    private let layout: ColumnLayout

    private init(screen: NSScreen, windows: [SIWindow], layout: ColumnLayout, windowActivityCache: WindowActivityCache) {
        self.layout = layout
        super.init(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }

    private override func main() {
        if windows.count == 0 {
            return
        }

        let screenFrame = adjustedFrameForLayout(screen)
        let windowWidth = screenFrame.width / CGFloat(windows.count)

        let focusedWindow = SIWindow.focusedWindow()

        let frameAssignments = windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            let originX = screenFrame.origin.x + CGFloat(frameAssignments.count) * windowWidth
            let windowFrame = CGRect(x: originX, y: screenFrame.origin.y, width: windowWidth, height: screenFrame.size.height)

            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isEqualTo(focusedWindow), screenFrame: screenFrame)

            assignments.append(frameAssignment)

            return assignments
        }

        if cancelled {
            return
        }

        performFrameAssignments(frameAssignments)
    }
}

public class ColumnLayout: Layout {
    override public class var layoutName: String { return "Column" }
    override public class var layoutKey: String { return "column" }

    override public func reflowOperationForScreen(screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return ColumnReflowOperation(screen: screen, windows: windows, layout: self, windowActivityCache: windowActivityCache)
    }
}
