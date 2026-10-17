//
//  TertiarySplitPartitionLayout.swift
//  Amethyst
//
//  Created by Don Patterson on 9/29/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

import Silica

/// The direction a pane is divided in.
enum TertiarySplitAxis {
    /// Panes sit side by side, left to right.
    case columns

    /// Panes stack top to bottom.
    case rows

    /// A pane wider than it is tall divides into columns; a tall or square pane divides into rows.
    init(dividing rect: CGRect) {
        self = rect.width > rect.height ? .columns : .rows
    }

    /// The axis at right angles to this one.
    var perpendicular: TertiarySplitAxis {
        switch self {
        case .columns: return .rows
        case .rows: return .columns
        }
    }

    /// The window dimension that changes when a pane on this axis is resized.
    var unconstrainedDimension: UnconstrainedDimension {
        switch self {
        case .columns: return .horizontal
        case .rows: return .vertical
        }
    }

    /// The extent of `rect` along this axis.
    func length(of rect: CGRect) -> CGFloat {
        switch self {
        case .columns: return rect.width
        case .rows: return rect.height
        }
    }

    /// The part of `rect` that starts `offset` in along this axis and extends `length`, spanning the other dimension.
    func slice(of rect: CGRect, from offset: CGFloat, length: CGFloat) -> CGRect {
        switch self {
        case .columns: return CGRect(x: rect.minX + offset, y: rect.minY, width: length, height: rect.height)
        case .rows: return CGRect(x: rect.minX, y: rect.minY + offset, width: rect.width, height: length)
        }
    }

    /// `count` equal parts of `rect` along this axis, rounded to whole points so that they tile it exactly.
    func divide(_ rect: CGRect, into count: Int) -> [CGRect] {
        let length = self.length(of: rect)
        return (0..<count).map { index in
            let start = round(length * CGFloat(index) / CGFloat(count))
            let end = round(length * CGFloat(index + 1) / CGFloat(count))
            return slice(of: rect, from: start, length: end - start)
        }
    }
}

/**
 A pane in the tree of splits, numbered in the order windows fill the panes.

 Node 0 is the root and holds the main pane. Every other node holds one window in its middle and can be divided
 again on either side. Numbers run level by level: the root's left or top side is node 1 and its right or bottom
 side is node 2; each later level numbers the left or top sides of the previous level's nodes in order, then
 their right or bottom sides. Side window `k`, counting from zero, occupies node `k + 1`.
 */
struct TertiarySplitNode {
    static let root = TertiarySplitNode(number: 0)

    let number: Int

    /// The depth of the node. The root is at level 0 and level `n` holds `2^n` nodes.
    var level: Int {
        return Int.bitWidth - (number + 1).leadingZeroBitCount - 1
    }

    /// The node dividing this node's left or top side.
    var firstSide: TertiarySplitNode {
        let positionInLevel = number - ((1 << level) - 1)
        return TertiarySplitNode(number: (1 << (level + 1)) - 1 + positionInLevel)
    }

    /// The node dividing this node's right or bottom side.
    var secondSide: TertiarySplitNode {
        return TertiarySplitNode(number: firstSide.number + (1 << level))
    }
}

/// One pane divided three ways: a middle with a side before it (left or top) and a side after it (right or bottom).
struct TertiarySplitPanes {
    let axis: TertiarySplitAxis
    let middle: CGRect
    let first: CGRect?
    let second: CGRect?

    /**
     Divides the pane of `node` between its own window and the nodes on its sides that hold a window.

     - Parameters:
        - rect: The pane's frame.
        - node: The node the pane belongs to.
        - sideWindowCount: The number of windows outside the main pane. Nodes numbered above it hold no window.
        - middleRatio: The share of the pane the middle keeps when both sides hold a window. Each occupied side gets
          half of the rest, and the middle keeps the share of an empty side.
     */
    init(dividing rect: CGRect, at node: TertiarySplitNode, sideWindowCount: Int, middleRatio: CGFloat) {
        axis = TertiarySplitAxis(dividing: rect)

        let hasFirst = node.firstSide.number <= sideWindowCount
        let hasSecond = node.secondSide.number <= sideWindowCount
        let length = axis.length(of: rect)
        let sideLength = round(length * (1 - middleRatio) / 2)
        let firstLength = hasFirst ? sideLength : 0
        let secondLength = hasSecond ? sideLength : 0
        let middleLength = length - firstLength - secondLength

        first = hasFirst ? axis.slice(of: rect, from: 0, length: firstLength) : nil
        middle = axis.slice(of: rect, from: firstLength, length: middleLength)
        second = hasSecond ? axis.slice(of: rect, from: firstLength + middleLength, length: secondLength) : nil
    }

    /// How many sides hold a window.
    var sideCount: Int {
        return [first, second].compactMap { $0 }.count
    }

    /// The combined extent of the occupied sides along the axis.
    var sideLength: CGFloat {
        return [first, second].compactMap { $0 }.map { axis.length(of: $0) }.reduce(0, +)
    }
}

/**
 Tiles windows by dividing the screen three ways: a main pane in the middle with a side pane on each side, where each
 side pane is divided three ways again as windows arrive.

 A pane wider than it is tall divides into columns; a tall or square pane divides into rows. The first window fills
 the screen. The second takes the left or top side and the third takes the right or bottom side, a third each at the
 default ratio. Later windows divide the side panes into thirds the same way, level by level: the fourth divides the
 second window's pane and the fifth the third window's, then the sixth and seventh take the remaining sides of those
 two panes, and so on, always filling the left or top sides of a level before its right or bottom sides.
 */
class TertiarySplitPartitionLayout<Window: WindowType>: Layout<Window>, PanedLayout {
    override static var layoutName: String { return "Tertiary Split Partition" }
    override static var layoutKey: String { return "tsp" }

    enum CodingKeys: String, CodingKey {
        case mainPaneCount
        case mainPaneRatio
    }

    /// The share of a divided side pane its own window keeps once both of its sides hold a window.
    private static var sidePaneMiddleRatio: CGFloat { return 1.0 / 3.0 }

    private(set) var mainPaneCount: Int = 1

    /// The share of the screen the main pane takes when both of its sides hold a window. With one side occupied the
    /// main pane also takes the empty side's share.
    private(set) var mainPaneRatio: CGFloat = 1.0 / 3.0

    /// How many sides of the main pane held windows the last time frames were assigned.
    private var mainPaneSideCount = 0

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

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        let screenFrame = screen.adjustedFrame()
        let mainWindowCount = min(mainPaneCount, windows.count)
        let sideWindowCount = windows.count - mainWindowCount

        let root = TertiarySplitPanes(
            dividing: screenFrame,
            at: .root,
            sideWindowCount: sideWindowCount,
            middleRatio: mainPaneRatio
        )
        mainPaneSideCount = root.sideCount

        // Main windows share the main pane, stacked across the direction of the split.
        var frames = root.axis.perpendicular.divide(root.middle, into: mainWindowCount)

        var sideFrames = [CGRect](repeating: .zero, count: sideWindowCount)
        if let first = root.first {
            assignFrames(under: TertiarySplitNode.root.firstSide, in: first, sideWindowCount: sideWindowCount, to: &sideFrames)
        }
        if let second = root.second {
            assignFrames(under: TertiarySplitNode.root.secondSide, in: second, sideWindowCount: sideWindowCount, to: &sideFrames)
        }
        frames += sideFrames

        // Resizing any window is read as a change to the main pane's share of the screen along the root's axis.
        let screenLength = root.axis.length(of: screenFrame)
        let mainResizeRules = ResizeRules(
            isMain: true,
            unconstrainedDimension: root.axis.unconstrainedDimension,
            scaleFactor: screenLength / max(root.axis.length(of: root.middle), 1)
        )
        let sideResizeRules = ResizeRules(
            isMain: false,
            unconstrainedDimension: root.axis.unconstrainedDimension,
            scaleFactor: screenLength / max(root.sideLength, 1)
        )

        return zip(windows, frames).enumerated().map { index, pair -> FrameAssignmentOperation<Window> in
            let (window, frame) = pair
            let frameAssignment = FrameAssignment<Window>(
                frame: frame,
                window: window,
                screenFrame: screenFrame,
                resizeRules: index < mainWindowCount ? mainResizeRules : sideResizeRules
            )
            return FrameAssignmentOperation(frameAssignment: frameAssignment, windowSet: windowSet)
        }
    }

    /// Stores the frame of the window at `node` and of every window dividing it, indexed by side window.
    private func assignFrames(under node: TertiarySplitNode, in rect: CGRect, sideWindowCount: Int, to frames: inout [CGRect]) {
        let panes = TertiarySplitPanes(
            dividing: rect,
            at: node,
            sideWindowCount: sideWindowCount,
            middleRatio: TertiarySplitPartitionLayout.sidePaneMiddleRatio
        )
        frames[node.number - 1] = panes.middle

        if let first = panes.first {
            assignFrames(under: node.firstSide, in: first, sideWindowCount: sideWindowCount, to: &frames)
        }
        if let second = panes.second {
            assignFrames(under: node.secondSide, in: second, sideWindowCount: sideWindowCount, to: &frames)
        }
    }
}

extension TertiarySplitPartitionLayout {
    /// Takes the share of the screen the main pane should have and stores the ratio that produces it.
    func recommendMainPaneRawRatio(rawRatio: CGFloat) {
        // With one side occupied the main pane shows the ratio plus half of what the ratio leaves over.
        let ratio = mainPaneSideCount == 1 ? 2 * rawRatio - 1 : rawRatio
        mainPaneRatio = max(0, min(1, ratio))
    }

    func expandMainPane() {
        mainPaneRatio = min(1, mainPaneRatio + UserConfiguration.shared.windowResizeStep())
    }

    func shrinkMainPane() {
        mainPaneRatio = max(0, mainPaneRatio - UserConfiguration.shared.windowResizeStep())
    }

    func increaseMainPaneCount() {
        mainPaneCount += 1
    }

    func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }
}
