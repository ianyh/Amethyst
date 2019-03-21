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
    func activeWindowsForScreenManager<Window: WindowType>(_ screenManager: ScreenManager<Window>) -> [Window]
    func windowIsActive<Window: WindowType>(_ window: Window) -> Bool
}

final class ScreenManager<Window: WindowType>: NSObject {
    var screen: NSScreen
    let screenIdentifier: String
    /// The last window that has been focused on the screen. This value is updated by the notification observations in
    /// `ObserveApplicationNotifications`.
    public internal(set) var lastFocusedWindow: Window?
    fileprivate weak var delegate: ScreenManagerDelegate?
    private let userConfiguration: UserConfiguration
    public var onReflowInitiation: (() -> Void)?
    public var onReflowCompletion: (() -> Void)?

    var currentSpaceIdentifier: String? {
        willSet {
            guard let spaceIdentifier = currentSpaceIdentifier else {
                return
            }

            currentLayoutIndexBySpaceIdentifier[spaceIdentifier] = currentLayoutIndex
        }
        didSet {
            defer {
                setNeedsReflowWithWindowChange(.unknown)
            }

            guard let spaceIdentifier = currentSpaceIdentifier else {
                return
            }

            changingSpace = true
            currentLayoutIndex = currentLayoutIndexBySpaceIdentifier[spaceIdentifier] ?? 0

            if let layouts = layoutsBySpaceIdentifier[spaceIdentifier] {
                self.layouts = layouts
            } else {
                self.layouts = LayoutManager.layoutsWithConfiguration(userConfiguration, windowActivityCache: self)
                layoutsBySpaceIdentifier[spaceIdentifier] = layouts
            }
        }
    }
    var isFullscreen = false

    private var reflowTimer: Timer?
    private var reflowOperation: Operation?

    private var layouts: [Layout<Window>] = []
    private var currentLayoutIndexBySpaceIdentifier: [String: Int] = [:]
    private var layoutsBySpaceIdentifier: [String: [Layout<Window>]] = [:]
    private var currentLayoutIndex: Int {
        didSet {
            if !self.changingSpace || userConfiguration.enablesLayoutHUDOnSpaceChange() {
                self.displayLayoutHUD()
            }
        }
    }
    var currentLayout: Layout<Window>? {
        guard !layouts.isEmpty else {
            return nil
        }
        return layouts[currentLayoutIndex]
    }

    private let layoutNameWindowController: LayoutNameWindowController

    private var changingSpace: Bool = false

    init(screen: NSScreen, screenIdentifier: String, delegate: ScreenManagerDelegate, userConfiguration: UserConfiguration) {
        self.screen = screen
        self.screenIdentifier = screenIdentifier
        self.delegate = delegate
        self.userConfiguration = userConfiguration
        self.onReflowInitiation = nil
        self.onReflowCompletion = nil

        currentLayoutIndexBySpaceIdentifier = [:]
        layoutsBySpaceIdentifier = [:]
        currentLayoutIndex = 0

        layoutNameWindowController = LayoutNameWindowController(windowNibName: "LayoutNameWindow")

        super.init()

        layouts = LayoutManager.layoutsWithConfiguration(userConfiguration, windowActivityCache: self)
    }

    deinit {
        self.onReflowCompletion = nil
    }

    func setNeedsReflowWithWindowChange(_ windowChange: WindowChange<Window>) {
        reflowOperation?.cancel()

        log.debug("Screen: \(screenIdentifier) -- Window Change: \(windowChange)")

        if let statefulLayout = currentLayout as? StatefulLayout {
            statefulLayout.updateWithChange(windowChange)
        }

        if changingSpace {
            // The 0.4 is disgustingly tied to the space change animation time.
            // This should get burned to the ground when space changes don't rely on the mouse click trick.
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(UInt64(0.4) * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                self.reflow(windowChange)
            }
        } else {
            DispatchQueue.main.async {
                self.reflow(windowChange)
            }
        }
    }

    private func reflow(_ change: WindowChange<Window>) {
        guard currentSpaceIdentifier != nil &&
            currentLayoutIndex < layouts.count &&
            userConfiguration.tilingEnabled &&
            !isFullscreen
        else {
            return
        }

        let windows = (delegate?.activeWindowsForScreenManager(self) ?? [])
        changingSpace = false

        let reflowOperation = currentLayout?.reflow(windows, on: screen)
        reflowOperation?.completionBlock = { [weak self, weak reflowOperation] in
            guard let isCancelled = reflowOperation?.isCancelled, !isCancelled else {
                return
            }

            self?.onReflowCompletion?()
        }
        onReflowInitiation?()
        if let reflowOperation = reflowOperation {
            OperationQueue.main.addOperation(reflowOperation)
        }
    }

    func updateCurrentLayout(_ updater: (Layout<Window>) -> Void) {
        guard let layout = currentLayout else {
            return
        }
        updater(layout)
        setNeedsReflowWithWindowChange(.unknown)
    }

    func cycleLayoutForward() {
        currentLayoutIndex = (currentLayoutIndex + 1) % layouts.count
        setNeedsReflowWithWindowChange(.unknown)
    }

    func cycleLayoutBackward() {
        currentLayoutIndex = (currentLayoutIndex == 0 ? layouts.count : currentLayoutIndex) - 1
        setNeedsReflowWithWindowChange(.unknown)
    }

    func selectLayout(_ layoutString: String) {
        guard let layoutIndex = layouts.index(where: { type(of: $0).layoutKey == layoutString }) else {
            return
        }

        currentLayoutIndex = layoutIndex
        setNeedsReflowWithWindowChange(.unknown)
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

    func nextWindowIDCounterClockwise() -> CGWindowID? {
        guard let layout = currentLayout as? StatefulLayout else {
            return nil
        }

        return layout.nextWindowIDCounterClockwise()
    }

    func nextWindowIDClockwise() -> CGWindowID? {
        guard let statefulLayout = currentLayout as? StatefulLayout else {
            return nil
        }

        return statefulLayout.nextWindowIDClockwise()
    }

    func displayLayoutHUD() {
        guard userConfiguration.enablesLayoutHUD() else {
            return
        }

        defer {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideLayoutHUD(_:)), object: nil)
            perform(#selector(hideLayoutHUD(_:)), with: nil, afterDelay: 0.6)
        }

        guard let layoutNameWindow = layoutNameWindowController.window as? LayoutNameWindow else {
            return
        }

        let screenFrame = screen.frame
        let screenCenter = CGPoint(x: screenFrame.midX, y: screenFrame.midY)
        let windowOrigin = CGPoint(
            x: screenCenter.x - layoutNameWindow.frame.width / 2.0,
            y: screenCenter.y - layoutNameWindow.frame.height / 2.0
        )

        layoutNameWindow.layoutNameField?.stringValue = currentLayout.flatMap({ type(of: $0).layoutName }) ?? "None"
        layoutNameWindow.layoutDescriptionLabel?.stringValue = currentLayout?.layoutDescription ?? ""
        layoutNameWindow.setFrameOrigin(NSPointFromCGPoint(windowOrigin))

        layoutNameWindowController.showWindow(self)
    }

    @objc func hideLayoutHUD(_ sender: AnyObject) {
        layoutNameWindowController.close()
    }
}

extension ScreenManager: WindowActivityCache {
    func windowIsActive<Window: WindowType>(_ window: Window) -> Bool {
        return delegate?.windowIsActive(window) ?? false
    }
}

extension WindowManager: ScreenManagerDelegate {
    func activeWindowsForScreenManager<Window: WindowType>(_ screenManager: ScreenManager<Window>) -> [Window] {
        return activeWindows(on: screenManager.screen) as! [Window]
    }
}
