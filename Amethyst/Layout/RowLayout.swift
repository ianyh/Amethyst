//
//  RowLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

private class RowReflowOperation: ReflowOperation {
    private let layout: RowLayout

    private init(screen: NSScreen, windows: [SIWindow], layout: RowLayout, windowActivityCache: WindowActivityCache) {
        self.layout = layout
        super.init(screen: screen, windows: windows, windowActivityCache: windowActivityCache)
    }

    private override func main() {
        if windows.count == 0 {
            return
        }

        let screenFrame = adjustedFrameForLayout(screen)
        let windowHeight = screenFrame.height / CGFloat(windows.count)

        let focusedWindow = SIWindow.focusedWindow()

        let frameAssignments = windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            let originY = screenFrame.origin.y + CGFloat(frameAssignments.count) * windowHeight
            let windowFrame = CGRect(x: screenFrame.origin.x, y: originY, width: screenFrame.width, height: windowHeight)

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

@objc public class RowLayout: Layout {
    override public class var layoutName: String { return "Row" }
    override public class var layoutKey: String { return "row" }

    override public func reflowOperationForScreen(screen: NSScreen, withWindows windows: [SIWindow]) -> ReflowOperation {
        return RowReflowOperation(screen: screen, windows: windows, layout: self, windowActivityCache: windowActivityCache)
    }
}
