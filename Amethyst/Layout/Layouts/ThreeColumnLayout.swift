//
//  ThreeColumnLayout.swift
//  Amethyst
//
//  Originally created by Ian Ynda-Hummel on 12/15/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//
//  Modifications by Craig Disselkoen on 09/03/18.
//

import Silica

// we'd like to hide these structures and enums behind fileprivate, but
// https://bugs.swift.org/browse/SR-47

enum Column {
    case left
    case middle
    case right
}

enum Pane {
    case main
    case secondary
    case tertiary
}

enum Stack {
    case tall
    case wide
}

struct TriplePaneArrangement {
    /// number of windows in pane
    private let paneCount: [Pane: UInt]

    /// height of windows in pane
    private let paneWindowHeight: [Pane: CGFloat]

    /// width of windows in pane
    private let paneWindowWidth: [Pane: CGFloat]

    /// width of main pane (different than window in pane when using Stack.tall)
    private let mainPaneWidth: CGFloat

    // how panes relate to columns
    private let panePosition: [Pane: Column]

    /// how columns relate to panes
    private let columnDesignation: [Column: Pane]

    private let mainPaneStack: Stack
    private let mainPane: Column

    /**
     - Parameters:
        - mainPane: which Column is the main Pane
        - mainPaneStack: which Stack configuration is used for the main Pane
        - numWindows: how many windows total
        - numMainPane: how many windows in the main Pane
        - screenSize: total size of the screen
        - mainPaneRatio: ratio of the screen taken by main pane
     */
    init(mainPane: Column, mainPaneStack: Stack, numWindows: UInt, numMainPane: UInt, screenSize: CGSize, mainPaneRatio: CGFloat) {

        self.mainPane = mainPane
        self.mainPaneStack = mainPaneStack

        // forward and reverse mapping of columns to their designations
        self.panePosition = {
            switch mainPane {
            case .left:   return [.main: .left, .secondary: .middle, .tertiary: .right]
            case .middle: return [.main: .middle, .secondary: .left, .tertiary: .right]
            case .right:  return [.main: .right, .secondary: .left, .tertiary: .middle]
            }
        }()
        // swap keys and values for reverse lookup
        self.columnDesignation = Dictionary(uniqueKeysWithValues: panePosition.map({ ($1, $0) }))

        // calculate how many are in each type
        let mainPaneCount = min(numWindows, numMainPane)
        let nonMainCount: UInt = numWindows - mainPaneCount
        // we do tertiary first because a single window produces a zero in integer division by 2
        let tertiaryPaneCount = nonMainCount >> 1
        let secondaryPaneCount = nonMainCount - tertiaryPaneCount
        self.paneCount = [.main: mainPaneCount, .secondary: secondaryPaneCount, .tertiary: tertiaryPaneCount]

        // calculate heights
        let screenHeight = screenSize.height
        self.paneWindowHeight = [
            .main: mainPaneStack == Stack.tall
                ? screenHeight
                : round(screenHeight / CGFloat(mainPaneCount)),
            .secondary: secondaryPaneCount == 0 ? 0.0 : round(screenHeight / CGFloat(secondaryPaneCount)),
            .tertiary: tertiaryPaneCount == 0 ? 0.0 : round(screenHeight / CGFloat(tertiaryPaneCount))
        ]

        // calculate widths
        let screenWidth = screenSize.width
        let mainPaneWidth = secondaryPaneCount == 0
            ? screenWidth
            : round(screenWidth * mainPaneRatio)
        let mainWindowWidth = mainPaneStack == Stack.tall
            ? round(mainPaneWidth/CGFloat(mainPaneCount))
            : mainPaneWidth
        let nonMainWindowWidth = round((screenWidth - mainPaneWidth) / 2)
        self.paneWindowWidth = [
            .main: mainWindowWidth,
            .secondary: nonMainWindowWidth,
            .tertiary: nonMainWindowWidth
        ]
        self.mainPaneWidth = mainPaneWidth
   }

    func count(_ pane: Pane) -> UInt {
        return paneCount[pane]!
    }

    func height(_ pane: Pane) -> CGFloat {
        return paneWindowHeight[pane]!
    }

    func width(_ pane: Pane) -> CGFloat {
        return paneWindowWidth[pane]!
    }

    func firstIndex(_ pane: Pane) -> UInt {
        switch pane {
        case .main: return 0
        case .secondary: return count(.main)
        case .tertiary: return count(.main) + count(.secondary)
        }
    }

    func pane(ofIndex windowIndex: UInt) -> Pane {
        if windowIndex >= firstIndex(.tertiary) {
            return .tertiary
        }
        if windowIndex >= firstIndex(.secondary) {
            return .secondary
        }
        return .main
    }

    /// Given a window index, which Pane does it belong to, and which index within that Pane
    func coordinates(at windowIndex: UInt) -> (Pane, UInt) {
        let pane = self.pane(ofIndex: windowIndex)
        return (pane, windowIndex - firstIndex(pane))
    }

    /// Get the (height, width) dimensions for a window in the given Pane
    func windowDimensions(inPane pane: Pane) -> (CGFloat, CGFloat) {
        return (height(pane), width(pane))
    }

    /// Get the Column assignment for the given Pane
    func column(ofPane pane: Pane) -> Column {
        return panePosition[pane]!
    }

    func pane(ofColumn column: Column) -> Pane {
        return columnDesignation[column]!
    }

    /// Get the column widths in the order (left, middle, right)
    func widthsLeftToRight() -> (CGFloat, CGFloat, CGFloat) {
        if self.mainPaneStack == Stack.wide {
            return (width(pane(ofColumn: .left)), width(pane(ofColumn: .middle)), width(pane(ofColumn: .right)))
        }
        switch self.mainPane {
        case Column.left:
            return (self.mainPaneWidth, width(pane(ofColumn: .middle)), width(pane(ofColumn: .right)))
        case Column.middle:
            return (width(pane(ofColumn: .left)), self.mainPaneWidth, width(pane(ofColumn: .right)))
        case Column.right:
            return (width(pane(ofColumn: .left)), width(pane(ofColumn: .middle)), self.mainPaneWidth)
        }
    }
}

// not an actual Layout, just a base class for the three actual Layouts below
class ThreeColumnLayout<Window: WindowType>: Layout<Window> {
    class var mainColumn: Column { fatalError("Must be implemented by subclass") }
    class var mainColumnStack: Stack { fatalError("Must be implemented by subclass") }

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

    override func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        let windows = windowSet.windows

        guard !windows.isEmpty else {
            return []
        }

        let screenFrame = screen.adjustedFrame()
        let paneArrangement = TriplePaneArrangement(
            mainPane: type(of: self).mainColumn,
            mainPaneStack: type(of: self).mainColumnStack,
            numWindows: UInt(windows.count),
            numMainPane: UInt(mainPaneCount),
            screenSize: screenFrame.size,
            mainPaneRatio: mainPaneRatio
        )

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignmentOperation<Window>] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let windowIndex: UInt = UInt(frameAssignments.count)

            let (pane, paneIndex) = paneArrangement.coordinates(at: windowIndex)

            let (windowHeight, windowWidth): (CGFloat, CGFloat) = paneArrangement.windowDimensions(inPane: pane)
            let column: Column = paneArrangement.column(ofPane: pane)

            let (leftPaneWidth, middlePaneWidth, rightPaneWidth): (CGFloat, CGFloat, CGFloat) = paneArrangement.widthsLeftToRight()

            let xorigin: CGFloat = screenFrame.origin.x + {
                let isInTallMainPane = (column == type(of: self).mainColumn) && type(of: self).mainColumnStack == .tall

                if isInTallMainPane {
                    let widthOffset = CGFloat(paneIndex)/CGFloat(mainPaneCount)

                    switch column {
                    case .left: return 0.0 + (leftPaneWidth * widthOffset)
                    case .middle: return leftPaneWidth + (middlePaneWidth * widthOffset)
                    case .right: return leftPaneWidth + middlePaneWidth + rightPaneWidth * widthOffset
                    }
                } else {
                    switch column {
                    case .left: return 0.0
                    case .middle: return leftPaneWidth
                    case .right: return leftPaneWidth + middlePaneWidth
                    }
                }
            }()

            let yorigin: CGFloat = screenFrame.origin.y + {
                let isInTallMainPane = (column == type(of: self).mainColumn) && type(of: self).mainColumnStack == .tall

                if isInTallMainPane {
                    return 0

                } else {
                    return windowHeight * CGFloat(paneIndex)
                }

            }()

            let scaleFactor: CGFloat = screenFrame.width / {
                if pane == .main {
                    return paneArrangement.width(.main)
                }
                return paneArrangement.width(.secondary) + paneArrangement.width(.tertiary)
            }()

            windowFrame.origin.x = xorigin
            windowFrame.origin.y = yorigin
            windowFrame.size.width = windowWidth
            windowFrame.size.height = windowHeight

            let isMain = windowIndex < paneArrangement.firstIndex(.secondary)

            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: .horizontal, scaleFactor: scaleFactor)
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

extension ThreeColumnLayout {
    func recommendMainPaneRawRatio(rawRatio: CGFloat) {
        mainPaneRatio = rawRatio
    }

    func increaseMainPaneCount() {
        mainPaneCount += 1
    }

    func decreaseMainPaneCount() {
        mainPaneCount = max(1, mainPaneCount - 1)
    }
}

// implement the three + tall variants
class ThreeColumnLeftLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Left" }
    override static var layoutKey: String { return "3column-left" }
    override static var mainColumn: Column { return .left }
    override static var mainColumnStack: Stack { return .wide }
}

class ThreeColumnMiddleLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Middle" }
    // for backwards compatibility with users who still have 'middle-wide' in their active layouts
    override static var layoutKey: String { return "middle-wide" }
    override static var mainColumn: Column { return .middle }
    override static var mainColumnStack: Stack { return .wide }
}

class ThreeColumnRightLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Right" }
    override static var layoutKey: String { return "3column-right" }
    override static var mainColumn: Column { return .right }
    override static var mainColumnStack: Stack { return .wide }

}

class ThreeColumnTallLeftLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Tall Left" }
    override static var layoutKey: String { return "3column-tall-left" }
    override static var mainColumn: Column { return .left }
    override static var mainColumnStack: Stack { return .tall }
}

class ThreeColumnTallMiddleLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Tall Middle" }
    override static var layoutKey: String { return "3column-tall-middle" }
    override static var mainColumn: Column { return .middle }
    override static var mainColumnStack: Stack { return .tall }
}

class ThreeColumnTallRightLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Tall Right" }
    override static var layoutKey: String { return "3column-tall-right" }
    override static var mainColumn: Column { return .right }
    override static var mainColumnStack: Stack { return .tall }
}
