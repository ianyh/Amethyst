//
//  StageManagerLayout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/14/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Silica

class StageManagerLayout<Window: WindowType>: Layout<Window> {
    override static var layoutName: String { return "Stage Manager" }
    override static var layoutKey: String { return "stage-manager" }

    override var layoutDescription: String { return "" }

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let screenFrame = screen.adjustedFrame(disableWindowMargins: UserConfiguration.shared.smartWindowMargins())
        let gridGuides = (
            horizontal: self.gridGuides(in: screenFrame.width, from: screenFrame.minX),
            vertical: self.gridGuides(in: screenFrame.height, from: screenFrame.minY)
        )
        return windowSet.windows.map { window in
            let resizeRules = ResizeRules(isMain: true, unconstrainedDimension: .horizontal, scaleFactor: 1)
            let frameInset: CGFloat = 8
            var frame = window.frame.insetBy(dx: -frameInset, dy: -frameInset)
            // Limit windows to screen bounds
            if frame.minX < screenFrame.minX {
                frame.origin.x = screenFrame.minX
            }
            if frame.minY < screenFrame.minY {
                frame.origin.y = screenFrame.minY
            }
            if frame.maxX > screenFrame.maxX {
                frame.origin.x += screenFrame.maxX - frame.maxX
            }
            if frame.maxY > screenFrame.maxY {
                frame.origin.y += screenFrame.maxY - frame.maxY
            }
            // Align to grid
            let oldX = frame.minX
            let oldY = frame.minY
            frame.origin.x = match(frame.minX, to: gridGuides.horizontal, leadingEdge: true)
            frame.origin.y = match(frame.minY, to: gridGuides.vertical, leadingEdge: true)
            frame.size.width += oldX - frame.origin.x
            frame.size.height += oldY - frame.origin.y
            frame.size.width = match(frame.maxX, to: gridGuides.horizontal, leadingEdge: false) - frame.minX
            frame.size.height = match(frame.maxY, to: gridGuides.vertical, leadingEdge: false) - frame.minY
            frame = frame.insetBy(dx: frameInset, dy: frameInset)
            let frameAssignment = FrameAssignment<Window>(
                frame: frame,
                window: window,
                screenFrame: screenFrame,
                resizeRules: resizeRules,
                disableWindowMargins: UserConfiguration.shared.smartWindowMargins()
            )
            return FrameAssignmentOperation(frameAssignment: frameAssignment, windowSet: windowSet)
        }
    }
    
    func gridGuides(in dimension: CGFloat, from origin: CGFloat) -> [CGFloat] {
        let baseGridSize: CGFloat = 64
        let points = Int(dimension / baseGridSize)
        let gridItemSize = dimension / CGFloat(points)
        return (0...points).map { CGFloat($0) * gridItemSize + origin }
    }
    
    func match(_ value: CGFloat, to guides: [CGFloat], leadingEdge: Bool) -> CGFloat {
        var guides = guides
        // Prevent offscreen snapping
        if leadingEdge {
            guides.removeLast()
        } else {
            guides.removeFirst()
        }
        // Make it easier to snap to screen edges and avoid stage manager sidebar
        if guides.indices.count > 2 {
            guides.remove(at: 1)
            guides.remove(at: guides.endIndex-2)
        }
        // Find closest snap guide
        let index = guides.firstIndex(where: { $0 >= value }) ?? guides.indices.last!
        let previous = guides.indices.contains(index-1) ? guides[index-1] : guides.first!
        let next = guides.indices.contains(index) ? guides[index] : guides.last!
        if (value - previous) > (next - value) {
            return next
        } else {
            return previous
        }
    }
}

// To ensure updates when resizing
extension StageManagerLayout: PanedLayout {
    var mainPaneRatio: CGFloat { 0.5 }
    var mainPaneCount: Int { 1 }
    func recommendMainPaneRawRatio(rawRatio: CGFloat) {}
    func increaseMainPaneCount() {}
    func decreaseMainPaneCount() {}
    
}
