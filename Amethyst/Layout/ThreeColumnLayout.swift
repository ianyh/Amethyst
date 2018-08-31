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

private enum Column {
    case left
    case middle
    case right
}

private enum Pane {
    case main
    case secondary
    case tertiary
}

private struct PaneArrangement {
    let mainPane: Column  // which Column is the main Pane

    let mainPaneCount: UInt  // how many windows in the main Pane
    let secondaryPaneCount: UInt  // how many windows in the secondary Pane
    let tertiaryPaneCount: UInt  // how many windows in the tertiary Pane

    let screenHeight: CGFloat  // total height of the screen
    let mainWindowHeight: CGFloat  // height of each window in the main Pane
    let secondaryWindowHeight: CGFloat  // height of each window in the secondary Pane
    let tertiaryWindowHeight: CGFloat  // height of each window in the tertiary Pane

    let screenWidth: CGFloat  // total width of the screen
    let mainWindowWidth: CGFloat  // width of each window in the main Pane
    let nonMainWindowWidth: CGFloat  // width of each window in the secondary or tertiary Pane

    init(mainPane: Column,  // which Column is the main Pane
         numWindows: UInt,  // how many windows total
         numMainPane: UInt,  // how many windows in the main Pane
         screenHeight: CGFloat,  // total height of the screen
         screenWidth: CGFloat,  // total width of the screen
         mainPaneRatio: CGFloat
    ) {
        self.mainPane = mainPane
        self.mainPaneCount = min(numWindows, numMainPane)
        let nonMainCount: UInt = numWindows - self.mainPaneCount
        self.secondaryPaneCount = nonMainCount >> 1
        self.tertiaryPaneCount = nonMainCount - self.secondaryPaneCount
        self.screenHeight = screenHeight
        self.screenWidth = screenWidth
        self.mainWindowHeight = round(screenHeight / CGFloat(self.mainPaneCount))
        self.secondaryWindowHeight = self.secondaryPaneCount > 0 ? round(screenHeight / CGFloat(self.secondaryPaneCount)) : 0.0
        self.tertiaryWindowHeight = self.tertiaryPaneCount > 0 ? round(screenHeight / CGFloat(self.tertiaryPaneCount)) : 0.0
        if self.tertiaryPaneCount > 0 {
            self.mainWindowWidth = round(self.screenWidth * mainPaneRatio)
            self.nonMainWindowWidth = round((self.screenWidth - self.mainWindowWidth) / 2)
        } else if self.secondaryPaneCount > 0 {
            // has a secondary pane, but no tertiary pane
            self.mainWindowWidth = round(self.screenWidth * mainPaneRatio)
            self.nonMainWindowWidth = self.screenWidth - self.mainWindowWidth
        } else {
            // has only a main pane
            self.mainWindowWidth = self.screenWidth
            self.nonMainWindowWidth = 0.0
        }
    }

    // Given a window index, which Pane does it belong to, and which index within that Pane
    func coordinates(at windowIndex: UInt) -> (Pane, UInt) {
        // main windows are indexes [0, mainPaneCount)
        // secondary windows are indexes [mainPaneCount, mainPaneCount + secondaryPaneCount)
        // tertiary windows are indexes [mainPaneCount + secondaryPaneCount, ...)
        if windowIndex < mainPaneCount {
            return (Pane.main, windowIndex)
        } else if windowIndex >= (mainPaneCount + secondaryPaneCount) {
            return (Pane.tertiary, windowIndex - mainPaneCount - secondaryPaneCount)
        } else {
            return (Pane.secondary, windowIndex - mainPaneCount)
        }
    }

    // Get the (height, width) dimensions for a window in the given Pane
    func windowDimensions(for pane: Pane) -> (CGFloat, CGFloat) {
        switch pane {
        case .main: return (mainWindowHeight, mainWindowWidth)
        case .secondary: return (secondaryWindowHeight, nonMainWindowWidth)
        case .tertiary: return (tertiaryWindowHeight, nonMainWindowWidth)
        }
    }

    // Get the Column assignment for the given Pane
    func column(for pane: Pane) -> Column {
        switch mainPane {
        case .left:
            switch pane {
            case .main: return Column.left
            case .secondary: return Column.middle
            case .tertiary: return Column.right
            }
        case .middle:
            switch pane {
            case .main: return Column.middle
            case .secondary: return Column.left
            case .tertiary: return Column.right
            }
        case .right:
            switch pane {
            case .main: return Column.right
            case .secondary: return Column.left
            case .tertiary: return Column.middle
            }
        }
    }

    // Get the column widths in the order (left, middle, right)
    func widthsLeftToRight() -> (CGFloat, CGFloat, CGFloat) {
        switch mainPane {
        case .left: return (mainWindowWidth, nonMainWindowWidth, nonMainWindowWidth)
        case .middle: return (nonMainWindowWidth, mainWindowWidth, nonMainWindowWidth)
        case .right: return (nonMainWindowWidth, nonMainWindowWidth, mainWindowWidth)
        }
    }
}

final class ThreeColumnReflowOperation: ReflowOperation {
    private let layout: ThreeColumnLayout
    private let mainIs: Column

    fileprivate init(screen: NSScreen, windows: [SIWindow], layout: ThreeColumnLayout, frameAssigner: FrameAssigner, mainIs: Column) {
        self.layout = layout
        self.mainIs = mainIs
        super.init(screen: screen, windows: windows, frameAssigner: frameAssigner)
    }

    func frameAssignments() -> [FrameAssignment] {
        guard !windows.isEmpty else {
            return []
        }

        let screenFrame = screen.adjustedFrame()
        let paneArrangement = PaneArrangement(mainPane: mainIs,
                                              numWindows: UInt(windows.count),
                                              numMainPane: UInt(layout.mainPaneCount),
                                              screenHeight: screenFrame.height,
                                              screenWidth: screenFrame.width,
                                              mainPaneRatio: layout.mainPaneRatio)

        let focusedWindow = SIWindow.focused()

        return windows.reduce([]) { frameAssignments, window -> [FrameAssignment] in
            var assignments = frameAssignments
            var windowFrame = CGRect.zero
            let windowIndex: UInt = UInt(frameAssignments.count)

            let (pane, paneIndex) = paneArrangement.coordinates(at: windowIndex)

            let (windowHeight, windowWidth): (CGFloat, CGFloat) = paneArrangement.windowDimensions(for: pane)
            let column: Column = paneArrangement.column(for: pane)

            let (leftPaneWidth, middlePaneWidth, _): (CGFloat, CGFloat, CGFloat) = paneArrangement.widthsLeftToRight()

            let xorigin: CGFloat = {
                switch column {
                case .left: return screenFrame.origin.x
                case .middle: return screenFrame.origin.x + leftPaneWidth
                case .right: return screenFrame.origin.x + leftPaneWidth + middlePaneWidth
                }
            }()

            let scaleFactor: CGFloat = (screenFrame.width / windowWidth)

            windowFrame.origin.x = xorigin
            windowFrame.origin.y = screenFrame.origin.y + (windowHeight * CGFloat(paneIndex))
            windowFrame.size.width = windowWidth
            windowFrame.size.height = windowHeight

            let isTertiaryMain = (paneArrangement.tertiaryPaneCount > 0 ? pane == Pane.main : pane != Pane.main)

            let resizeRules = ResizeRules(isMain: isTertiaryMain, unconstrainedDimension: .horizontal, scaleFactor: scaleFactor)
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
class ThreeColumnLayout: WindowActivityCache {
    let windowActivityCache: WindowActivityCache

    init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    func windowIsActive(_ window: SIWindow) -> Bool {
        return windowActivityCache.windowIsActive(window)
    }

    fileprivate var mainPaneCount: Int = 1
    fileprivate(set) var mainPaneRatio: CGFloat = 0.5
}

final class ThreeColumnLeftLayout: ThreeColumnLayout, Layout {
    static var layoutName: String { return "3Column Left" }
    static var layoutKey: String { return "3column-left" }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        return ThreeColumnReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self, mainIs: Column.left)
    }

    func assignedFrame(_ window: SIWindow, of windows: [SIWindow], on screen: NSScreen) -> FrameAssignment? {
        return ThreeColumnReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self, mainIs: Column.left).frameAssignments().first { $0.window == window }
    }
}

final class ThreeColumnMiddleLayout: ThreeColumnLayout, Layout {
    static var layoutName: String { return "3Column Middle" }
    static var layoutKey: String { return "middle-wide" }  // for backwards compatibility with users who still have 'middle-wide' in their active layouts

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        return ThreeColumnReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self, mainIs: Column.middle)
    }

    func assignedFrame(_ window: SIWindow, of windows: [SIWindow], on screen: NSScreen) -> FrameAssignment? {
        return ThreeColumnReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self, mainIs: Column.middle).frameAssignments().first { $0.window == window }
    }
}

final class ThreeColumnRightLayout: ThreeColumnLayout, Layout {
    static var layoutName: String { return "3Column Right" }
    static var layoutKey: String { return "3column-right" }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation {
        return ThreeColumnReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self, mainIs: Column.right)
    }

    func assignedFrame(_ window: SIWindow, of windows: [SIWindow], on screen: NSScreen) -> FrameAssignment? {
        return ThreeColumnReflowOperation(screen: screen, windows: windows, layout: self, frameAssigner: self, mainIs: Column.right).frameAssignments().first { $0.window == window }
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

extension ThreeColumnLayout: FrameAssigner {}
