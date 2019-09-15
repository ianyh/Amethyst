//
//  ReflowOperation.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/19/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

/// Possible dimensions without constraints.
enum UnconstrainedDimension: Int {
    /// The dimension along the x-axis.
    case horizontal

    /// The dimension along the y-axis.
    case vertical
}

/**
 This struct defines what adjustments to a particular window frame are allowed and tracks its size as a proportion of available space (for use in resize calculations).

 Some window resizes reflect valid adjustments to the frame layout.
 
 Some window resizes would not be allowed due to hard constraints.
 */
struct ResizeRules {
    /// Whether or not the resize rule is applying to the main frame.
    let isMain: Bool

    /// The dimension that is allowed to scale.
    let unconstrainedDimension: UnconstrainedDimension

    /// the scale factor for the unconstrained dimension.
    let scaleFactor: CGFloat

    /**
     Determines the new value of the dimension based on the scale factor.
     
     Given a new frame, decide which dimension will be honored and return its size.
     
     - Parameters:
        - frame: The frame to transform.
        - negatePadding: Whether or not to take padding into account.
     */
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

/// Encapsulation of an assignment of a frame to a window.
struct FrameAssignment<Window: WindowType> {
    /// The frame to apply to the window.
    let frame: CGRect

    /// The window that will be moved and sized.
    let window: Window

    /// Whether or not the window is currently taking focus.
    let focused: Bool

    /// The frame of the screen being occupied.
    let screenFrame: CGRect

    /// The rules governing constraints to frame transforms
    let resizeRules: ResizeRules

    /// The final frame is the desired frame, but transformed to provide desired padding
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

    /**
     Given a window frame and based on resizeRules, determine what the main pane ratio would be.
     
     This accounts for multiple main windows and primary vs non-primary being resized.
     
     - Parameters:
        - windowFrame: The frame of the window to test ratio against.
     
     - Returns:
     The estimate of the main pane ratio implied by how the frame would be transformed.
     */
    func impliedMainPaneRatio(windowFrame: CGRect) -> CGFloat {
        let oldDimension = resizeRules.scaledDimension(frame, negatePadding: false)
        let newDimension = resizeRules.scaledDimension(windowFrame, negatePadding: true)
        let implied =  (newDimension / oldDimension) / resizeRules.scaleFactor
        return resizeRules.isMain ? implied : 1 - implied
    }

    /// Perform the actual application of the frame to the window
    func perform() {
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

/// Protocol for entities that perform a set of frame assignments.
protocol FrameAssigner {
    /// The window activity cache to use when handling windows.
    var windowActivityCache: WindowActivityCache { get }

    /**
     - Parameters:
        - windowActivityCache: The cache to use when handling windows.
     */
    init(windowActivityCache: WindowActivityCache)

    /**
     Performs a set of frame assignments.
     
     - Parameters:
        - frameAssignments: The set of frame assignments to perform.
     */
    func performFrameAssignments<Window: WindowType>(_ frameAssignments: [FrameAssignment<Window>])
}

/// Simple `FrameAssigner` that performs assignments if all windows are active.
struct Assigner: FrameAssigner {
    /// The cache to use to check for activity
    let windowActivityCache: WindowActivityCache

    /**
     Performs a set of frame assignments.
     
     The assignments will be ignored if any of the windows are not active. This is to prevent race conditions between starting reflow operations and this method actually being called. If some windows have deactivated in that time then the assignments are no longer valid.
     
     - Parameters:
        - frameAssignments: The set of frame assignments to perform.
     */
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

/**
 A base class for specific layout operations that perform assignments according to their algorithm.
 
 - Requires:
 Specific operations should subclass and override the `frameAssignments()` method.
 
 - Note:
 Subclasses need not override `main()`, but if you do you _must_ call the `super` implementation.
 */
class ReflowOperation<Window: WindowType>: Operation {
    typealias Screen = Window.Screen

    /// The screen on which the windows are being laid out.
    let screen: Screen

    /// The screen on which the windows are being laid out.
    let windows: [Window]

    /// The `FrameAssigner` responsible for performing assignments.
    let frameAssigner: FrameAssigner

    /**
     - Parameters:
         - screen: The screen on which the windows are being laid out.
         - windows: The screen on which the windows are being laid out.
         - frameAssigner: The `FrameAssigner` responsible for performing assignments.
     */
    init(screen: Screen, windows: [Window], frameAssigner: FrameAssigner) {
        self.screen = screen
        self.windows = windows
        self.frameAssigner = frameAssigner
        super.init()
    }

    /**
     Determine the set of `FrameAssignment` objects that compose the operations satisfying the layout algorithm.
     
     - Returns:
     A complete list of `FrameAssignments`.
     
     - Note:
     This can return `nil` if there are no assignments to be made.
     */
    func frameAssignments() -> [FrameAssignment<Window>]? {
        return nil
    }

    /// The main method of the `Operation`.
    override func main() {
        guard !isCancelled else { return }
        guard let assignments = frameAssignments() else { return }
        frameAssigner.performFrameAssignments(assignments)
    }
}
