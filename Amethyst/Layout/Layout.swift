//
//  Layout.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/3/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

/**
 A base class for specific layout algorithms defining size and position of windows.
 
 - Requires:
 Specific layouts must subclass and override the following properties and methods:
 - `layoutName`
 - `layoutKey`
 
 Subclasses can optionally override `layoutDescription` to provide debugging information for the layout state.
 
 - Note:
 Usage of a layout object requires specifying a `WindowType` parameter.
 */
class Layout<Window: WindowType>: Codable {
    typealias Screen = Window.Screen

    private enum CodingKeys: String, CodingKey {
        case key
    }

    /// The display name of the layout.
    class var layoutName: String { fatalError("Must be implemented by subclass") }

    /// The configuration key of the layout.
    class var layoutKey: String { fatalError("Must be implemented by subclass") }

    /// The display name of the layout.
    var layoutName: String { return type(of: self).layoutName }

    /// The configuration key of the layout.
    var layoutKey: String { return type(of: self).layoutKey }

    /// The debug description of the layout.
    var layoutDescription: String { return "" }

    required init() {}

    required init(from decoder: Decoder) throws {}

    /// Base encoder for layouts; basically a noop.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(layoutKey, forKey: .key)
    }

    /**
     Takes a list of windows and a screen and returns the assignments that would be performed.
     
     - Parameters:
         - windows: The windows to apply the layout algorithm to.
         - screen: The screen on which those windows should reside.
     
     - Returns:
     The assignments that would be performed given those windows on that screen.
     */
    func frameAssignments(_ windowSet: WindowSet<Window>, on screen: Screen) -> [FrameAssignmentOperation<Window>]? {
        fatalError("Must be implemented by subclass")
    }
}

/// Errors occurring when decoding a layout
enum LayoutDecodingError: Error {
    /**
     Something about the layout was structurally unsound.
     
     Notable example: bsp layout cannot recover if some windows are no longer present, so if we fail to decode a node the layout is no longer sound.
     */
    case invalidLayout
}

// MARK: Window Querying

extension Layout {
    /**
     Determines what window the layout would put at a given point.
     
     - Parameters:
         - point: The point to test for location.
         - windows: The windows to apply the layout algorithm to.
         - screen: The screen on which those windows should reside.
     
     - Returns:
     The window that the layout would intend to put at `point`.
     
     - Note: This does not necessarily correspond to the final position of the window as windows do not necessarily take the exact frame the layout provides.
     */
    func windowAtPoint(_ point: CGPoint, of windowSet: WindowSet<Window>, on screen: Screen) -> LayoutWindow<Window>? {
        return frameAssignments(windowSet, on: screen)?
            .map { $0.frameAssignment }
            .first { $0.frame.contains(point) }?
            .window
    }

    /**
     Determines what frame the layout would apply to a given window.
     
     - Parameters:
         - window: The window to test for frame.
         - windows: The windows to apply the layout algorithm to.
         - screen: The screen on which those windows should reside.
     
     - Returns:
     The `FrameAssignment` object defining the size and location that the layout would assign to `window`.
     
     - Note: This does not necessarily correspond to the final frame of the window as windows do not necessarily take the exact frame the layout provides.
     */
    func assignedFrame(_ window: Window, of windowSet: WindowSet<Window>, on screen: Screen) -> FrameAssignment<Window>? {
        return frameAssignments(windowSet, on: screen)?
            .map { $0.frameAssignment }
            .first { $0.window.id == window.id() }
    }
}

/**
 A particular kind of layout that organizes windows into a main pane and any number of sub-panes.
 
 - Note:
 The definition is intentionally somewhat layout. This is more intended to demonstrate the expected interface for a fairly common paradigm in Amethyst layouts.
 */
protocol PanedLayout {
    /**
     The ratio of the size of the main pane to the size of the sub-panes.
     
     - Requires:
     The value must be between 0 and 1, inclusive.
     */
    var mainPaneRatio: CGFloat { get }

    /// The number of windows that make up the main pane.
    var mainPaneCount: Int { get }

    /**
     Takes a direct recommendation for a change in ratio.
     
     - Parameters:
        - rawRatio: The ratio recommended by the caller.
     
     - Requires:
     `rawRatio` must be a valid ratio.
     
     - Note: This method should generally be reserved for internal use by the layout.
     */
    func recommendMainPaneRawRatio(rawRatio: CGFloat)

    /// Reduces the visual footprint of the main pane relative to the sub-panes.
    func shrinkMainPane()

    /// Increases the visual footprint of the main pane relative to the sub-panes.
    func expandMainPane()

    /// Increases the number of windows that make up the main pane.
    func increaseMainPaneCount()

    /// Decreases the number of windows that make up the main pane.
    func decreaseMainPaneCount()
}

extension PanedLayout {
    /// The default debug layout description for paned layouts. It describes the ratio and number of main pane windows.
    var layoutDescription: String {
        return "(\(mainPaneRatio), \(mainPaneCount))"
    }

    /**
     Takes a recommendation for a change in ratio, but can modify the ratio to adjust for internal state.
     
     - Parameters:
        - ratio: The ratio recommended by the caller.
     */
    func recommendMainPaneRatio(_ ratio: CGFloat) {
        guard 0 <= ratio && ratio <= 1 else {
            log.warning("tried to setMainPaneRatio out of range [0-1]:  \(ratio)")
            return recommendMainPaneRawRatio(rawRatio: max(min(ratio, 1), 0))
        }
        recommendMainPaneRawRatio(rawRatio: ratio)
    }

    /// The default behavior of main pane expansion that simply recommends an increase in ratio by the configured resize step.
    func expandMainPane() {
        recommendMainPaneRatio(mainPaneRatio + UserConfiguration.shared.windowResizeStep())
    }

    /// The default behavior of main pane shrinking that simply recommends a decrease in ratio by the configured resize step.
    func shrinkMainPane() {
        recommendMainPaneRatio(mainPaneRatio - UserConfiguration.shared.windowResizeStep())
    }
}

/**
 A base class for specific layout algorithms that maintain internal state for defining size and position of windows.
 
 - Requires:
 Specific layouts must subclass and override the following properties and methods:
 - `updateWithChange(_ windowChange: WindowChange<Window>)`
 - `nextWindowIDCounterClockwise() -> CGWindowID?`
 - `nextWindowIDClockwise() -> CGWindowID?`
 
 Notably, the latter two are necessary for the window manager to determine flow of windows. By default layouts are a simple linear list, but more complex layouts may have different logic.
 */
class StatefulLayout<Window: WindowType>: Layout<Window> {
    /**
     Updates internal state of the layout based on a window change.
     
     - Parameters:
        - windowChange: A `WindowChange`.
     */
    func updateWithChange(_ windowChange: Change<Window>) {
        fatalError("Must be implemented by subclass")
    }

    /**
     Determines the window that is before the current window.
     
     - Returns:
     The ID of the window before the current window.
     */
    func nextWindowIDCounterClockwise() -> Window.WindowID? {
        fatalError("Must be implemented by subclass")
    }

    /**
     Determines the window that is after the current window.
     
     - Returns:
     The ID of the window after the current window.
     */
    func nextWindowIDClockwise() -> Window.WindowID? {
        fatalError("Must be implemented by subclass")
    }
}
