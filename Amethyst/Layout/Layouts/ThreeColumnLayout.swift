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

internal enum Column {
    case left
    case middle
    case right
}

internal enum Pane {
    case main
    case secondary
    case tertiary
}

internal struct TriplePaneArrangement {
    let paneCount: [Pane: UInt]            // number of windows in pane
    let paneWindowHeight: [Pane: CGFloat]  // height of windows in pane
    let paneWindowWidth: [Pane: CGFloat]   // width of windows in pane
    let panePosition: [Pane: Column]       // how panes relate to columns
    let columnDesignation: [Column: Pane]  // how columns relate to panes

    init(mainPane: Column,    // which Column is the main Pane
         numWindows: UInt,    // how many windows total
         numMainPane: UInt,   // how many windows in the main Pane
         screenSize: CGSize,  // total size of the screen
         mainPaneRatio: CGFloat
    ) {
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
            .main: round(screenHeight / CGFloat(mainPaneCount)),
            .secondary: secondaryPaneCount == 0 ? 0.0 : round(screenHeight / CGFloat(secondaryPaneCount)),
            .tertiary: tertiaryPaneCount == 0 ? 0.0 : round(screenHeight / CGFloat(tertiaryPaneCount))
        ]

        // calculate widths
        let screenWidth = screenSize.width
        let mainWindowWidth = secondaryPaneCount == 0 ? screenWidth : round(screenWidth * mainPaneRatio)
        let nonMainWindowWidth = round((screenWidth - mainWindowWidth) / 2)
        self.paneWindowWidth = [
            .main: mainWindowWidth,
            .secondary: nonMainWindowWidth,
            .tertiary: nonMainWindowWidth
        ]
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

    // Given a window index, which Pane does it belong to, and which index within that Pane
    func coordinates(at windowIndex: UInt) -> (Pane, UInt) {
        let pane = self.pane(ofIndex: windowIndex)
        return (pane, windowIndex - firstIndex(pane))
    }

    // Get the (height, width) dimensions for a window in the given Pane
    func windowDimensions(inPane pane: Pane) -> (CGFloat, CGFloat) {
        return (height(pane), width(pane))
    }

    // Get the Column assignment for the given Pane
    func column(ofPane pane: Pane) -> Column {
        return panePosition[pane]!
    }

    func pane(ofColumn column: Column) -> Pane {
        return columnDesignation[column]!
    }

    // Get the column widths in the order (left, middle, right)
    func widthsLeftToRight() -> (CGFloat, CGFloat, CGFloat) {
        return (width(pane(ofColumn: .left)), width(pane(ofColumn: .middle)), width(pane(ofColumn: .right)))
    }
}

final class ThreeColumnReflowOperation<Window: WindowType>: ReflowOperation<Window> {
    private let layout: ThreeColumnLayout<Window>

    fileprivate init(screen: NSScreen, windows: [Window], layout: ThreeColumnLayout<Window>, frameAssigner: FrameAssigner) {
        self.layout = layout
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    override func frameAssignments() -> [FrameAssignment<Window>]? {
        guard !windows.isEmpty else {
            return []
        }

        let screenFrame = screen.adjustedFrame()
        let paneArrangement = TriplePaneArrangement(mainPane: type(of: layout).mainColumn,
                                              numWindows: UInt(windows.count),
                                              numMainPane: UInt(layout.mainPaneCount),
                                              screenSize: screenFrame.size,
                                              mainPaneRatio: layout.mainPaneRatio)

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment<Window>] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let windowIndex: UInt = UInt(frameAssignments.count)

            let (pane, paneIndex) = paneArrangement.coordinates(at: windowIndex)

            let (windowHeight, windowWidth): (CGFloat, CGFloat) = paneArrangement.windowDimensions(inPane: pane)
            let column: Column = paneArrangement.column(ofPane: pane)

            let (leftPaneWidth, middlePaneWidth, _): (CGFloat, CGFloat, CGFloat) = paneArrangement.widthsLeftToRight()

            let xorigin: CGFloat = screenFrame.origin.x + {
                switch column {
                case .left: return 0.0
                case .middle: return leftPaneWidth
                case .right: return leftPaneWidth + middlePaneWidth
                }
            }()

            let scaleFactor: CGFloat = screenFrame.width / {
                if pane == .main {
                    return paneArrangement.width(.main)
                }
                return paneArrangement.width(.secondary) + paneArrangement.width(.tertiary)
            }()

            windowFrame.origin.x = xorigin
            windowFrame.origin.y = screenFrame.origin.y + (windowHeight * CGFloat(paneIndex))
            windowFrame.size.width = windowWidth
            windowFrame.size.height = windowHeight

            let isMain = windowIndex < paneArrangement.firstIndex(.secondary)

            let resizeRules = ResizeRules(isMain: isMain, unconstrainedDimension: .horizontal, scaleFactor: scaleFactor)
            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isFocused(), screenFrame: screenFrame, resizeRules: resizeRules)

            assignments.append(frameAssignment)

            return assignments
        }
    }
}

// not an actual Layout, just a base class for the three actual Layouts below
class ThreeColumnLayout<Window: WindowType>: Layout<Window> {
    class var mainColumn: Column { fatalError("Must be implemented by subclass") }

    private(set) var mainPaneCount: Int = 1
    private(set) var mainPaneRatio: CGFloat = 0.5

    override func reflow(_ windows: [Window], on screen: NSScreen) -> ReflowOperation<Window>? {
        let assigner = Assigner(windowActivityCache: windowActivityCache)
        return ThreeColumnReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: assigner)
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

// implement the three variants
final class ThreeColumnLeftLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Left" }
    override static var layoutKey: String { return "3column-left" }
    override static var mainColumn: Column { return .left }
}

final class ThreeColumnMiddleLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Middle" }
    override static var layoutKey: String { return "middle-wide" }  // for backwards compatibility with users who still have 'middle-wide' in their active layouts
    override static var mainColumn: Column { return .middle }
}

final class ThreeColumnRightLayout<Window: WindowType>: ThreeColumnLayout<Window>, PanedLayout {
    override static var layoutName: String { return "3Column Right" }
    override static var layoutKey: String { return "3column-right" }
    override static var mainColumn: Column { return .right }
}
