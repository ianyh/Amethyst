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
    func windowIsActive<Window: WindowType>(_ window: AnyWindow<Window>) -> Bool
}

enum UnconstrainedDimension: Int {
    case horizontal
    case vertical
}

// Some window resizes reflect valid adjustments to the frame layout.
// Some window resizes would not be allowed due to hard constraints.
// This struct defines what adjustments to a particular window frame are allowed
//  and tracks its size as a proportion of available space (for use in resize calculations)
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

struct FrameAssignment<Window: WindowType> {
    let frame: CGRect
    let window: AnyWindow<Window>
    let focused: Bool
    let screenFrame: CGRect
    let resizeRules: ResizeRules

    // the final frame is the desired frame, but shrunk to provide desired padding
    var finalFrame: CGRect {
        var ret = frame
        let padding = floor(UserConfiguration.shared.windowMarginSize() / 2)

        if UserConfiguration.shared.windowMargins() {
            ret.origin.x += padding
            ret.origin.y += padding
            ret.size.width -= 2 * padding
            ret.size.height -= 2 * padding
        }

        let windowMinimumWidth = UserConfiguration.shared.windowMinimumWidth()
        let windowMinimumHeight = UserConfiguration.shared.windowMinimumHeight()

        if windowMinimumWidth > ret.size.width {
            ret.origin.x -= ((windowMinimumWidth - ret.size.width) / 2)
            ret.size.width = windowMinimumWidth
        }

        if windowMinimumHeight > ret.size.height {
            ret.origin.y -= ((windowMinimumHeight - ret.size.height) / 2)
            ret.size.height = windowMinimumHeight
        }

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
        var finalFrame = self.finalFrame
        var finalOrigin = finalFrame.origin

        // If this is the focused window then we need to shift it to be on screen regardless of size
        // We call this "window peeking" (this line here to aid in text search)
        if focused {
            // Just resize the window first to see what the dimensions end up being
            // Sometimes applications have internal window requirements that are not exposed to us directly
            finalFrame.origin = window.frame().origin
            window.setFrame(finalFrame, withThreshold: CGSize(width: 1, height: 1))

            // With the real height we can update the frame to account for the current size
            finalFrame.size = CGSize(
                width: max(window.frame().width, finalFrame.width),
                height: max(window.frame().height, finalFrame.height)
            )
            finalOrigin.x = max(screenFrame.minX, min(finalOrigin.x, screenFrame.maxX - finalFrame.size.width))
            finalOrigin.y = max(screenFrame.minY, min(finalOrigin.y, screenFrame.maxY - finalFrame.size.height))
        }

        // Move the window to its final frame
        finalFrame.origin = finalOrigin
        window.setFrame(finalFrame, withThreshold: CGSize(width: 1, height: 1))
    }
}

class ReflowOperation<Window: WindowType>: Operation {
    let screen: NSScreen
    let windows: [AnyWindow<Window>]
    let frameAssigner: FrameAssigner

    init(screen: NSScreen, windows: [AnyWindow<Window>], frameAssigner: FrameAssigner) {
        self.screen = screen
        self.windows = windows
        self.frameAssigner = frameAssigner
        super.init()
    }

    public func frameAssignments() -> [FrameAssignment<Window>]? {
        return nil
    }

    override func main() {
        guard !isCancelled else { return }
        guard let assignments = frameAssignments() else { return }
        frameAssigner.performFrameAssignments(assignments)
    }
}

protocol FrameAssigner {
    var windowActivityCache: WindowActivityCache { get }

    init(windowActivityCache: WindowActivityCache)

    func performFrameAssignments<Window: WindowType>(_ frameAssignments: [FrameAssignment<Window>])
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

        let windowMinimumWidth = UserConfiguration.shared.windowMinimumWidth()
        let windowMinimumHeight = UserConfiguration.shared.windowMinimumHeight()

        if windowMinimumWidth > frame.size.width {
            frame.origin.x -= (windowMinimumWidth - frame.size.width) / 2
            frame.size.width = windowMinimumWidth
        }

        if windowMinimumHeight > frame.size.height {
            frame.origin.y -= (windowMinimumHeight - frame.size.height) / 2
            frame.size.height = windowMinimumHeight
        }

        let paddingTop = UserConfiguration.shared.screenPaddingTop()
        let paddingBottom = UserConfiguration.shared.screenPaddingBottom()
        let paddingLeft = UserConfiguration.shared.screenPaddingLeft()
        let paddingRight = UserConfiguration.shared.screenPaddingRight()
        frame.origin.y += paddingTop
        frame.origin.x += paddingLeft
        // subtract the right padding, and also any amount that we pushed the frame to the left with the left padding
        frame.size.width -= (paddingRight + paddingLeft)
        // subtract the bottom padding, and also any amount that we pushed the frame down with the top padding
        frame.size.height -= (paddingBottom + paddingTop)

        return frame
    }
}

class Layout<Window: WindowType> {
    class var layoutName: String { fatalError("Must be implemented by subclass") }
    class var layoutKey: String { fatalError("Must be implemented by subclass") }

    var layoutDescription: String { return "" }

    let windowActivityCache: WindowActivityCache

    required init(windowActivityCache: WindowActivityCache) {
        self.windowActivityCache = windowActivityCache
    }

    func reflow(_ windows: [AnyWindow<Window>], on screen: NSScreen) -> Operation? {
        fatalError("Must be implemented by subclass")
    }
}

extension Layout {
    func frameAssignments(_ windows: [AnyWindow<Window>], on screen: NSScreen) -> [FrameAssignment<Window>]? {
        guard let reflowOperation = reflow(windows, on: screen) as? ReflowOperation<Window> else {
            return nil
        }

        return reflowOperation.frameAssignments()
    }

    func windowAtPoint(_ point: CGPoint, of windows: [AnyWindow<Window>], on screen: NSScreen) -> AnyWindow<Window>? {
        return frameAssignments(windows, on: screen)?.first(where: { $0.frame.contains(point) })?.window
    }

    func assignedFrame(_ window: AnyWindow<Window>, of windows: [AnyWindow<Window>], on screen: NSScreen) -> FrameAssignment<Window>? {
        return frameAssignments(windows, on: screen)?.first { $0.window == window }
    }
}

protocol PanedLayout {
    var mainPaneRatio: CGFloat { get }
    var mainPaneCount: Int { get }
    func recommendMainPaneRawRatio(rawRatio: CGFloat)
    func shrinkMainPane()
    func expandMainPane()
    func increaseMainPaneCount()
    func decreaseMainPaneCount()
}

extension PanedLayout {
    var layoutDescription: String {
        return "(\(mainPaneRatio), \(mainPaneCount))"
    }

    func recommendMainPaneRatio(_ ratio: CGFloat) {
        guard 0 <= ratio && ratio <= 1 else {
            log.warning("tried to setMainPaneRatio out of range [0-1]:  \(ratio)")
            return recommendMainPaneRawRatio(rawRatio: max(min(ratio, 1), 0))
        }
        recommendMainPaneRawRatio(rawRatio: ratio)
    }

    func expandMainPane() {
        recommendMainPaneRatio(mainPaneRatio + UserConfiguration.shared.windowResizeStep())
    }

    func shrinkMainPane() {
        recommendMainPaneRatio(mainPaneRatio - UserConfiguration.shared.windowResizeStep())
    }
}

class StatefulLayout<Window: WindowType>: Layout<Window> {
    func updateWithChange(_ windowChange: WindowChange<Window>) {
        fatalError("Must be implemented by subclass")
    }

    func nextWindowIDCounterClockwise() -> CGWindowID? {
        fatalError("Must be implemented by subclass")
    }

    func nextWindowIDClockwise() -> CGWindowID? {
        fatalError("Must be implemented by subclass")
    }
}

struct Assigner: FrameAssigner {
    let windowActivityCache: WindowActivityCache

    func performFrameAssignments<Window: WindowType>(_ frameAssignments: [FrameAssignment<Window>]) {
        for frameAssignment in frameAssignments {
            if !windowActivityCache.windowIsActive(frameAssignment.window) {
                return
            }
        }

        for frameAssignment in frameAssignments {
//            log.debug("Frame Assignment: \(frameAssignment)")
            frameAssignment.perform()
        }
    }
}
