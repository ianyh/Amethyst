//
//  ScreenManager.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 12/23/15.
//  Copyright © 2015 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

public protocol ScreenManagerDelegate: class {
    func activeWindowsForScreenManager(_ screenManager: ScreenManager) -> [SIWindow]
    func windowIsActive(_ window: SIWindow) -> Bool
}

open class ScreenManager: NSObject {
    open var screen: NSScreen
    open let screenIdentifier: String
    fileprivate weak var delegate: ScreenManagerDelegate?
    fileprivate let userConfiguration: UserConfiguration

    open var currentSpaceIdentifier: String? {
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
    open var isFullscreen = false

    fileprivate var reflowTimer: Timer?
    fileprivate var reflowOperation: ReflowOperation?

    fileprivate var layouts: [Layout] = []
    fileprivate var currentLayoutIndexBySpaceIdentifier: [String: Int] = [:]
    fileprivate var layoutsBySpaceIdentifier: [String: [Layout]] = [:]
    fileprivate var currentLayoutIndex: Int {
        didSet {
            if !self.changingSpace || userConfiguration.enablesLayoutHUDOnSpaceChange() {
                self.displayLayoutHUD()
            }
        }
    }
    fileprivate var currentLayout: Layout {
        return layouts[currentLayoutIndex]
    }

    fileprivate let layoutNameWindowController: LayoutNameWindowController

    fileprivate var changingSpace: Bool = false

    init(screen: NSScreen, screenIdentifier: String, delegate: ScreenManagerDelegate, userConfiguration: UserConfiguration) {
        self.screen = screen
        self.screenIdentifier = screenIdentifier
        self.delegate = delegate
        self.userConfiguration = userConfiguration

        currentLayoutIndexBySpaceIdentifier = [:]
        layoutsBySpaceIdentifier = [:]
        currentLayoutIndex = 0

        layoutNameWindowController = LayoutNameWindowController(windowNibName: "LayoutNameWindow")

        super.init()

        layouts = LayoutManager.layoutsWithConfiguration(userConfiguration, windowActivityCache: self)
    }

    open func setNeedsReflowWithWindowChange(_ windowChange: WindowChange) {
        reflowOperation?.cancel()

        LogManager.log?.debug("Screen: \(screenIdentifier) -- Window Change: \(windowChange)")

        currentLayout.updateWithChange(windowChange)

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

    fileprivate func reflow(_ change: WindowChange) {
        guard currentSpaceIdentifier != nil &&
            currentLayoutIndex < layouts.count &&
            userConfiguration.tilingEnabled &&
            !isFullscreen &&
            !CGSManagedDisplayIsAnimating(_CGSDefaultConnection(), screenIdentifier as CGSManagedDisplay!)
        else {
            return
        }

        let windows = delegate?.activeWindowsForScreenManager(self) ?? []
        changingSpace = false
        reflowOperation = currentLayout.reflowOperationForScreen(screen, withWindows: windows)
        OperationQueue.main.addOperation(reflowOperation!)
    }

    open func updateCurrentLayout(_ updater: (Layout) -> Void) {
        updater(currentLayout)
        setNeedsReflowWithWindowChange(.unknown)
    }

    open func cycleLayoutForward() {
        currentLayoutIndex = (currentLayoutIndex + 1) % layouts.count
        setNeedsReflowWithWindowChange(.unknown)
    }

    open func cycleLayoutBackward() {
        currentLayoutIndex = (currentLayoutIndex == 0 ? layouts.count : currentLayoutIndex) - 1
        setNeedsReflowWithWindowChange(.unknown)
    }

    open func selectLayout(_ layoutType: AnyClass) {
        let index = layouts.index { $0.isKind(of: layoutType) }
        guard let layoutIndex = index else {
            return
        }

        currentLayoutIndex = layoutIndex
        setNeedsReflowWithWindowChange(.unknown)
    }

    open func shrinkMainPane() {
        currentLayout.shrinkMainPane()
    }

    open func expandMainPane() {
        currentLayout.expandMainPane()
    }

    open func nextWindowIDCounterClockwise() -> CGWindowID? {
        return currentLayout.nextWindowIDCounterClockwise()
    }

    open func nextWindowIDClockwise() -> CGWindowID? {
        return currentLayout.nextWindowIDClockwise()
    }

    open func displayLayoutHUD() {
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

        layoutNameWindow.layoutNameField?.stringValue = type(of: currentLayout).layoutName
        layoutNameWindow.setFrameOrigin(NSPointFromCGPoint(windowOrigin))

        layoutNameWindowController.showWindow(self)
    }

    open func hideLayoutHUD(_ sender: AnyObject) {
        layoutNameWindowController.close()
    }
}

extension ScreenManager: WindowActivityCache {
    public func windowIsActive(_ window: SIWindow) -> Bool {
        return delegate?.windowIsActive(window) ?? false
    }
}

extension WindowManager: ScreenManagerDelegate {
    public func activeWindowsForScreenManager(_ screenManager: ScreenManager) -> [SIWindow] {
        return activeWindowsForScreen(screenManager.screen)
    }

    public func windowIsActive(_ window: SIWindow) -> Bool {
        if !window.isActive() {
            return false
        }
        if activeIDCache[window.windowID()] == nil {
            return false
        }
        return true
    }
}
