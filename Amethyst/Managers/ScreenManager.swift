//
//  ScreenManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/23/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

protocol ScreenManagerDelegate: class {
    associatedtype Window: WindowType
    func activeWindowSet(forScreenManager screenManager: ScreenManager<Self>) -> WindowSet<Window>
    func onReflowInitiation()
    func onReflowCompletion()
}

final class ScreenManager<Delegate: ScreenManagerDelegate>: NSObject, Codable {
    typealias Window = Delegate.Window
    typealias Screen = Window.Screen

    enum CodingKeys: String, CodingKey {
        case layoutsBySpaceUUID
    }

    weak var delegate: Delegate?

    private(set) var screen: Screen?
    private(set) var space: Space?

    /// The last window that has been focused on the screen. This value is updated by the notification observations in
    /// `ObserveApplicationNotifications`.
    private(set) var lastFocusedWindow: Window?
    private let userConfiguration: UserConfiguration

    private let reflowOperationDispatchQueue = DispatchQueue(
        label: "ScreenManager.reflowOperationQueue",
        qos: .utility,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: nil
    )
    private let reflowOperationQueue = OperationQueue()

    private var layouts: [Layout<Window>] = []
    private var currentLayoutIndexBySpaceUUID: [String: Int] = [:]
    private var layoutsBySpaceUUID: [String: [Layout<Window>]] = [:]
    private var currentLayoutIndex: Int = 0
    var currentLayout: Layout<Window>? {
        guard !layouts.isEmpty else {
            return nil
        }
        return layouts[currentLayoutIndex]
    }

    private let layoutNameWindowController: LayoutNameWindowController

    init(screen: Screen, delegate: Delegate, userConfiguration: UserConfiguration) {
        self.screen = screen
        self.delegate = delegate
        self.userConfiguration = userConfiguration

        layoutNameWindowController = LayoutNameWindowController(windowNibName: "LayoutNameWindow")

        super.init()

        layouts = LayoutType.layoutsWithConfiguration(userConfiguration)

        reflowOperationQueue.underlyingQueue = reflowOperationDispatchQueue
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let layoutsBySpaceUUID = try values.decode([String: [[String: Data]]].self, forKey: .layoutsBySpaceUUID)

        self.userConfiguration = UserConfiguration.shared
        self.layoutsBySpaceUUID = try layoutsBySpaceUUID.mapValues { keyedLayouts -> [Layout<Window>] in
            return try ScreenManager<Delegate>.decodedLayouts(from: keyedLayouts, userConfiguration: UserConfiguration.shared)
        }

        layoutNameWindowController = LayoutNameWindowController(windowNibName: "LayoutNameWindow")
    }

    /**
     Takes the list of layouts and inserts decoded layouts where appropriate.

     - Parameters:
        - encodedLayouts: A list of encoded layouts to be restored.
        - userConfiguration: User configuration defining the list of layouts.
     */
    static func decodedLayouts(from encodedLayouts: [[String: Data]], userConfiguration: UserConfiguration) throws -> [Layout<Window>] {
        let layouts: [Layout<Window>] = LayoutType.layoutsWithConfiguration(userConfiguration)
        var decodedLayouts: [Layout<Window>] = encodedLayouts.compactMap { layout in
            guard let keyData = layout["key"], let key = String(data: keyData, encoding: .utf8) else {
                return nil
            }

            guard let data = layout["data"] else {
                return nil
            }

            do {
                return try LayoutType<Window>.decoded(data: data, key: key)
            } catch {
                log.error("Failed to to decode layout: \(key)")
            }

            return nil
        }

        // Yes this is quadratic, but if your layout list is long enough for that to be significant what are you even doing?
        return layouts.map { layout -> Layout<Window> in
            guard let decodedLayoutIndex = decodedLayouts.firstIndex(where: { $0.layoutKey == layout.layoutKey }) else {
                return layout
            }

            return decodedLayouts.remove(at: decodedLayoutIndex)
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        let layoutsBySpaceUUID = try self.layoutsBySpaceUUID.mapValues { layouts in
            return try layouts.map { layout -> [String: Data] in
                let layoutKey = layout.layoutKey.data(using: .utf8)!
                let encodedLayout = try LayoutType.encoded(layout: layout)
                return ["key": layoutKey, "data": encodedLayout]
            }
        }
        try values.encode(layoutsBySpaceUUID, forKey: .layoutsBySpaceUUID)
    }

    func updateScreen(to screen: Screen) {
        self.screen = screen
    }

    func updateSpace(to space: Space) {
        if let currentSpace = self.space {
            currentLayoutIndexBySpaceUUID[currentSpace.uuid] = currentLayoutIndex
        }

        defer {
            setNeedsReflow(withWindowChange: .spaceChange)
        }

        self.space = space

        setCurrentLayoutIndex(currentLayoutIndexBySpaceUUID[space.uuid] ?? 0, changingSpace: true)

        if let layouts = layoutsBySpaceUUID[space.uuid] {
            self.layouts = layouts
        } else {
            self.layouts = LayoutType.layoutsWithConfiguration(userConfiguration)
            layoutsBySpaceUUID[space.uuid] = layouts
        }
    }

    func setNeedsReflow(withWindowChange windowChange: Change<Window>) {
        switch windowChange {
        case let .add(window: window):
            lastFocusedWindow = window
        case let .focusChanged(window):
            lastFocusedWindow = window
        case let .remove(window):
            if lastFocusedWindow == window {
                lastFocusedWindow = nil
            }
        case .windowSwap, .applicationActivate, .applicationDeactivate, .spaceChange, .layoutChange, .unknown:
            break
        }

        reflowOperationQueue.cancelAllOperations()

        log.debug("Screen: \(screen?.screenID() ?? "unknown") -- Window Change: \(windowChange)")

        if let statefulLayout = currentLayout as? StatefulLayout {
            statefulLayout.updateWithChange(windowChange)
        }

        DispatchQueue.main.async {
            self.reflow(windowChange)
        }
    }

    private func reflow(_ event: Change<Window>) {
        guard let screen = screen else {
            return
        }

        guard userConfiguration.tilingEnabled, space?.type == CGSSpaceTypeUser else {
            return
        }

        guard let windows = delegate?.activeWindowSet(forScreenManager: self) else {
            return
        }

        guard let layout = currentLayout, let frameAssignments = layout.frameAssignments(windows, on: screen) else {
            return
        }

        let completeOperation = BlockOperation()

        // The complete operation should execute the completion delegate call
        completeOperation.addExecutionBlock { [unowned completeOperation, weak self] in
            if completeOperation.isCancelled {
                return
            }

            DispatchQueue.main.async {
                self?.delegate?.onReflowCompletion()
            }
        }

        // The completion should be dependent on all assignments finishing
        frameAssignments.forEach { completeOperation.addDependency($0) }

        // Start the operation
        delegate?.onReflowInitiation()
        reflowOperationQueue.addOperations(frameAssignments, waitUntilFinished: false)
        reflowOperationQueue.addOperation(completeOperation)
    }

    func updateCurrentLayout(_ updater: (Layout<Window>) -> Void) {
        guard let layout = currentLayout else {
            return
        }
        updater(layout)
        setNeedsReflow(withWindowChange: .layoutChange)
    }

    func cycleLayoutForward() {
        setCurrentLayoutIndex((currentLayoutIndex + 1) % layouts.count)
        setNeedsReflow(withWindowChange: .layoutChange)
    }

    func cycleLayoutBackward() {
        setCurrentLayoutIndex((currentLayoutIndex == 0 ? layouts.count : currentLayoutIndex) - 1)
        setNeedsReflow(withWindowChange: .layoutChange)
    }

    func selectLayout(_ layoutString: String) {
        guard let layoutIndex = layouts.index(where: { $0.layoutKey == layoutString }) else {
            return
        }

        setCurrentLayoutIndex(layoutIndex)
        setNeedsReflow(withWindowChange: .layoutChange)
    }

    private func setCurrentLayoutIndex(_ index: Int, changingSpace: Bool = false) {
        guard (0..<layouts.count).contains(index) else {
            return
        }

        currentLayoutIndex = index

        guard !changingSpace || userConfiguration.enablesLayoutHUDOnSpaceChange() else {
            return
        }

        DispatchQueue.main.async {
            self.displayLayoutHUD()
        }
    }

    func shrinkMainPane() {
        guard let panedLayout = currentLayout as? PanedLayout else {
            return
        }
        panedLayout.shrinkMainPane()
    }

    func expandMainPane() {
        guard let panedLayout = currentLayout as? PanedLayout else {
            return
        }
        panedLayout.expandMainPane()
    }

    func nextWindowIDCounterClockwise() -> Window.WindowID? {
        guard let layout = currentLayout as? StatefulLayout else {
            return nil
        }

        return layout.nextWindowIDCounterClockwise()
    }

    func nextWindowIDClockwise() -> Window.WindowID? {
        guard let statefulLayout = currentLayout as? StatefulLayout else {
            return nil
        }

        return statefulLayout.nextWindowIDClockwise()
    }

    func displayLayoutHUD() {
        guard let screen = screen else {
            return
        }

        guard userConfiguration.enablesLayoutHUD(), space?.type == CGSSpaceTypeUser else {
            return
        }

        defer {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideLayoutHUD(_:)), object: nil)
            perform(#selector(hideLayoutHUD(_:)), with: nil, afterDelay: 0.6)
        }

        guard let layoutNameWindow = layoutNameWindowController.window as? LayoutNameWindow else {
            return
        }

        let screenFrame = screen.frame()
        let screenCenter = CGPoint(x: screenFrame.midX, y: screenFrame.midY)
        let windowOrigin = CGPoint(
            x: screenCenter.x - layoutNameWindow.frame.width / 2.0,
            y: screenCenter.y - layoutNameWindow.frame.height / 2.0
        )

        layoutNameWindow.layoutNameField?.stringValue = currentLayout.flatMap({ $0.layoutName }) ?? "None"
        layoutNameWindow.layoutDescriptionLabel?.stringValue = currentLayout?.layoutDescription ?? ""
        layoutNameWindow.setFrameOrigin(NSPointFromCGPoint(windowOrigin))

        layoutNameWindowController.showWindow(self)
    }

    @objc func hideLayoutHUD(_ sender: AnyObject) {
        layoutNameWindowController.close()
    }
}

extension ScreenManager: Comparable {
    static func < (lhs: ScreenManager<Delegate>, rhs: ScreenManager<Delegate>) -> Bool {
        guard let lhsScreen = lhs.screen, let rhsScreen = rhs.screen else {
            return false
        }

        let originX1 = lhsScreen.frameWithoutDockOrMenu().origin.x
        let originX2 = rhsScreen.frameWithoutDockOrMenu().origin.x

        return originX1 < originX2
    }
}

extension WindowManager: ScreenManagerDelegate {
    func activeWindowSet(forScreenManager screenManager: ScreenManager<WindowManager<Application>>) -> WindowSet<Window> {
        return windows.windowSet(forActiveWindowsOnScreen: screenManager.screen!)
    }
}
