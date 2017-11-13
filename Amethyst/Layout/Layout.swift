//
//  Layout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/3/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

protocol WindowActivityCache {
    func windowIsActive(_ window: SIWindow) -> Bool
}

enum UnconstrainedDimension: Int {
    case horizontal
    case vertical
}

struct ResizeRules {
    let isMain: Bool
    let unconstrainedDimension: UnconstrainedDimension
    let scaleFactor: CGFloat    // the scale factor for the unconstrained dimension

    // given a new frame, decide which dimension will be honored and return its size
    func scaledDimension(_ frame: CGRect, negatePadding: Bool) -> CGFloat {
        let dimension: CGFloat = {
            switch unconstrainedDimension {
            case .horizontal: return frame.width
            case .vertical: return frame.height
            }
        }()

        let padding = UserConfiguration.shared.windowMargins() ? UserConfiguration.shared.windowMarginSize() : 0
        return negatePadding ? dimension + padding : dimension
    }
}

struct FrameAssignment {
    let frame: CGRect
    let window: SIWindow
    let focused: Bool
    let screenFrame: CGRect
    let resizeRules: ResizeRules

    var finalFrame: CGRect {
        guard UserConfiguration.shared.windowMargins() else {
            return frame
        }

        var ret = frame
        let padding = floor(UserConfiguration.shared.windowMarginSize() / 2)

        ret.origin.x += padding
        ret.origin.y += padding
        ret.size.width -= 2 * padding
        ret.size.height -= 2 * padding
        return ret
    }

    // Given a window frame and based on resizeRules, determine what the main pane ratio would be
    // this accounts for multiple main windows and primary vs non-primary being resized
    func impliedMainPaneRatio(windowFrame: CGRect) -> CGFloat {
        let oldDimension = resizeRules.scaledDimension(frame, negatePadding: false)
        let newDimension = resizeRules.scaledDimension(windowFrame, negatePadding: true)
        let implied =  (newDimension / oldDimension) / resizeRules.scaleFactor
        return resizeRules.isMain ? implied : 1 - implied
    }

    fileprivate func perform() {
        // Move the window to its final frame
        window.setFrame(finalFrame, withThreshold: CGSize(width: 1, height: 1))
    }
}

class ReflowOperation: Operation {
    let screen: NSScreen
    let windows: [SIWindow]
    let frameAssigner: FrameAssigner

    init(screen: NSScreen, windows: [SIWindow], frameAssigner: FrameAssigner) {
        self.screen = screen
        self.windows = windows
        self.frameAssigner = frameAssigner
        super.init()
    }
}

protocol FrameAssigner: WindowActivityCache {
    func performFrameAssignments(_ frameAssignments: [FrameAssignment])
}

extension FrameAssigner {
    func performFrameAssignments(_ frameAssignments: [FrameAssignment]) {
        for frameAssignment in frameAssignments {
            if !windowIsActive(frameAssignment.window) {
                return
            }
        }

        for frameAssignment in frameAssignments {
            LogManager.log?.debug("Frame Assignment: \(frameAssignment)")
            frameAssignment.perform()
        }
    }
}

extension FrameAssigner where Self: Layout {
    func windowIsActive(_ window: SIWindow) -> Bool {
        return windowActivityCache.windowIsActive(window)
    }
}

extension NSScreen {
    func adjustedFrame() -> CGRect {
        var frame = UserConfiguration.shared.ignoreMenuBar() ? frameIncludingDockAndMenu() : frameWithoutDockOrMenu()

        if UserConfiguration.shared.windowMargins() {
            /* Inset for producing half of the full padding around screen as collapse only adds half of it to all windows */
            let padding = floor(UserConfiguration.shared.windowMarginSize() / 2)

            frame.origin.x += padding
            frame.origin.y += padding
            frame.size.width -= 2 * padding
            frame.size.height -= 2 * padding
        }

        return frame
    }
}

protocol Layout {
    static var layoutName: String { get }
    static var layoutKey: String { get }

    var windowActivityCache: WindowActivityCache { get }

    func reflow(_ windows: [SIWindow], on screen: NSScreen) -> ReflowOperation
    func assignedFrame(_ window: SIWindow, of windows: [SIWindow], on screen: NSScreen) -> FrameAssignment?
}

protocol PanedLayout {
    var mainPaneRatio: CGFloat { get }
    func setMainPaneRawRatio(rawRatio: CGFloat)
    func shrinkMainPane()
    func expandMainPane()
    func increaseMainPaneCount()
    func decreaseMainPaneCount()
}

extension PanedLayout {
    func setMainPaneRatio(_ ratio: CGFloat) {
        guard 0 <= ratio && ratio <= 1 else {
            LogManager.log?.warning("tried to setMainPaneRatio out of range [0-1]:  \(ratio)")
            return setMainPaneRawRatio(rawRatio: max(min(ratio, 1), 0))
        }
        setMainPaneRawRatio(rawRatio: ratio)
    }

    func expandMainPane() {
        setMainPaneRatio(mainPaneRatio + UserConfiguration.shared.windowResizeStep())
    }

    func shrinkMainPane() {
        setMainPaneRatio(mainPaneRatio - UserConfiguration.shared.windowResizeStep())
    }
}

protocol StatefulLayout {
    func updateWithChange(_ windowChange: WindowChange)
    func nextWindowIDCounterClockwise() -> CGWindowID?
    func nextWindowIDClockwise() -> CGWindowID?
}
