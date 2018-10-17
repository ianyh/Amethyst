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

final class ThreeColumnReflowOperation: ReflowOperation {
    private let layout: ThreeColumnLayout & MainColumnSpecifier

    fileprivate init(screen: NSScreen, windows: [SIWindow],
                     layout: ThreeColumnLayout & MainColumnSpecifier & FrameAssigner) {
        self.layout = layout
        super.init(screen: screen, windows: windows, frameAssigner: layout)
    }

    func frameAssignments() -> [FrameAssignment] {
        guard !windows.isEmpty else {
            return []
        }

        let screenFrame = screen.adjustedFrame()
        let paneArrangement = TriplePaneArrangement(mainPane: layout.mainColumn,
                                              numWindows: UInt(windows.count),
                                              numMainPane: UInt(layout.mainPaneCount),
                                              screenSize: screenFrame.size,
                                              mainPaneRatio: layout.mainPaneRatio)

        let focusedWindow = SIWindow.focused()

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
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
            let frameAssignment = FrameAssignment(frame: windowFrame, window: window, focused: window.isEqual(to: focusedWindow), screenFrame: screenFrame, resizeRules: resizeRules)

            assignments.append(frameAssignment)

            return assignments
        }
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        layout.performFrameAssignments(frameAssignments())
    }
}

// not an actual Layout, just a base class for the three actual Layouts below
internal class ThreeColumnLayout {
    let windowActivityCache: WindowActivityCache

    init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    fileprivate var mainPaneCount: Int = 1
    fileprivate(set) var mainPaneRatio: CGFloat = 0.5
}

// DRY up the layouts since they differ only in what counts as their "main" column
internal protocol MainColumnSpecifier {
    var mainColumn: Column { get }
}

extension MainColumnSpecifier where Self: ThreeColumnLayout & Layout {
    private func reflow3columns(_ windows: [SIWindow], on screen: NSScreen) -> ThreeColumnReflowOperation {
        return ThreeColumnReflowOperation(screen: screen, windows: windows, layout: self)
    }

    internal func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        return reflow3columns(windows, on: screen)
    }

    internal func assignedFrame(_ window: SIWindow, of windows: [SIWindow], on screen: NSScreen) -> FrameAssignment? {
        return reflow3columns(windows, on: screen).frameAssignments().first { $0.window == window }
    }
}

// implement the three variants
final class ThreeColumnLeftLayout: ThreeColumnLayout, MainColumnSpecifier, Layout {
    static var layoutName: String { return "3Column Left" }
    static var layoutKey: String { return "3column-left" }
    internal let mainColumn = Column.left
}

final class ThreeColumnMiddleLayout: ThreeColumnLayout, MainColumnSpecifier, Layout {
    static var layoutName: String { return "3Column Middle" }
    static var layoutKey: String { return "middle-wide" }  // for backwards compatibility with users who still have 'middle-wide' in their active layouts
    internal let mainColumn = Column.middle
}

final class ThreeColumnRightLayout: ThreeColumnLayout, MainColumnSpecifier, Layout {
    static var layoutName: String { return "3Column Right" }
    static var layoutKey: String { return "3column-right" }
    internal let mainColumn = Column.right
}

// extend all ThreeColumnLayouts with other necessary functionality: PanedLayout, WindowActivityCache, FrameAssigner
extension ThreeColumnLayout: FrameAssigner {}

extension ThreeColumnLayout: WindowActivityCache {
    func windowIsActive(_ window: SIWindow) -> Bool {
        return windowActivityCache.windowIsActive(window)
    }
}

extension ThreeColumnLayout: PanedLayout {
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
