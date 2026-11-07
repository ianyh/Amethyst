//
//  Windows.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 9/15/19.
//  Copyright © 2019 Ian Ynda-Hummel. All rights reserved.
//

import Foundation
import Silica

extension WindowManager {
    class Windows {
        private(set) var windows: [Window] = []
        private(set) var lastMainWindows: [CGSSpaceID: Window?] = [:]
        private var activeIDCache: Set<CGWindowID> = Set()
        private var deactivatedPIDs: Set<pid_t> = Set()
        private var floatingMap: [Window.WindowID: Bool] = [:]

        // MARK: Window Filters

        func window(withID id: Window.WindowID) -> Window? {
            return windows.first { $0.id() == id }
        }

        func windows(forApplicationWithPID applicationPID: pid_t) -> [Window] {
            return windows.filter { $0.pid() == applicationPID }
        }

        func windows(onScreen screen: Screen) -> [Window] {
            return windows.filter { $0.screen() == screen }
        }

        func activeWindows(onScreen screen: Screen) -> [Window] {
            guard let screenID = screen.screenID() else {
                return []
            }

            guard let currentSpace = CGSpacesInfo<Window>.currentSpaceForScreen(screen) else {
                log.warning("Could not find a space for screen: \(screenID)")
                return []
            }

            let screenWindows = windows.filter { window in
                let space = CGWindowsInfo.windowSpace(window)

                guard let windowScreen = window.screen(), currentSpace.id == space else {
                    return false
                }

                let isActive = self.isWindowActive(window)
                let isHidden = self.isWindowHidden(window)
                let isFloating = self.isWindowFloating(window)

                return windowScreen.screenID() == screen.screenID() && isActive && !isHidden && !isFloating
            }

            return screenWindows
        }

        func activeWindowOnCurrentScreen(atIndex: Int) -> Window? {
            guard let focusedWindow = Window.currentlyFocused(),
                  let currentScreen = focusedWindow.screen() else {
                return nil
            }
            let activeWindows = activeWindows(onScreen: currentScreen)

            return activeWindows.indices.contains(atIndex) ? activeWindows[atIndex] : nil
        }

        // MARK: Adding and Removing

        func add(window: Window, atFront shouldInsertAtFront: Bool) {
            if shouldInsertAtFront {
                if let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(),
                   let firstActiveWindow = activeWindowOnCurrentScreen(atIndex: 0) {
                    lastMainWindows[currentFocusedSpace.id] = firstActiveWindow
                }

                windows.insert(window, at: 0)
            } else {
                windows.append(window)
            }
        }

        func add(window: Window, afterWindow otherWindow: Window) -> Bool {
            guard let otherWindowIndex = windows.firstIndex(of: otherWindow) else {
                return false
            }

            windows.insert(window, at: otherWindowIndex)

            return true
        }

        func remove(window: Window) {
            for (_, lastMainWindow) in lastMainWindows where lastMainWindow?.id() == window.id() {
                if let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace() {
                    let secondWindow = activeWindowOnCurrentScreen(atIndex: 1)
                    lastMainWindows[currentFocusedSpace.id] = secondWindow
                }
            }

            guard let windowIndex = windows.firstIndex(where: { $0.id() == window.id() }) else {
                return
            }

            windows.remove(at: windowIndex)
        }

        /**
         Swaps the stored instance of an already-tracked window for `window`, which has
         the same identity but a fresh AX element. Order and floating state are untouched.
         See `WindowManager.refreshTrackedWindow` for why elements go stale.

         - Returns: The replaced instance, or `nil` if the window is untracked or already
         stored as this exact element.
         */
        func refreshWindow(_ window: Window) -> Window? {
            guard let index = windows.firstIndex(where: { $0.id() == window.id() }),
                  windows[index] != window else {
                return nil
            }

            let staleWindow = windows[index]
            windows[index] = window
            return staleWindow
        }

        /// Replaces `window` in the tracking order with `otherWindow`, dropping `window`.
        @discardableResult func replace(window: Window, withWindow otherWindow: Window) -> Bool {
            if let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(),
               let firstActiveWindow = activeWindowOnCurrentScreen(atIndex: 0) {
                if firstActiveWindow == window || firstActiveWindow == otherWindow {
                    lastMainWindows[currentFocusedSpace.id] = firstActiveWindow
                }
            }

            guard let windowIndex = windows.firstIndex(of: window) else {
                windows.append(otherWindow)
                return false
            }

            let otherWindowIndex = windows.firstIndex(of: otherWindow)
            windows[windowIndex] = otherWindow

            if let otherWindowIndex {
                windows.remove(at: otherWindowIndex)
            }

            return true
        }

        @discardableResult func swap(window: Window, withWindow otherWindow: Window) -> Bool {
            if let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(),
               let firstActiveWindow = activeWindowOnCurrentScreen(atIndex: 0) {
                if firstActiveWindow.id() == window.id() || firstActiveWindow.id() == otherWindow.id() {
                    lastMainWindows[currentFocusedSpace.id] = firstActiveWindow
                }
            }

            if windows.firstIndex(of: window) == nil {
                windows.append(window)
            }

            guard let windowIndex = windows.firstIndex(of: window), let otherWindowIndex = windows.firstIndex(of: otherWindow) else {
                return false
            }

            guard windowIndex != otherWindowIndex else {
                return false
            }

            windows[windowIndex] = otherWindow
            windows[otherWindowIndex] = window

            return true
        }

        // MARK: Window States

        func isWindowTracked(_ window: Window) -> Bool {
            return windows.contains(where: { $0.id() == window.id() })
        }

        func isWindowActive(_ window: Window) -> Bool {
            return window.isActive() && activeIDCache.contains(window.cgID())
        }

        func isWindowHidden(_ window: Window) -> Bool {
            return deactivatedPIDs.contains(window.pid())
        }

        func isWindowFloating(_ window: Window) -> Bool {
            return floatingMap[window.id()] ?? false
        }

        func setFloating(_ floating: Bool, forWindow window: Window) {
            floatingMap[window.id()] = floating
        }

        func activateApplication(withPID pid: pid_t) {
            deactivatedPIDs.remove(pid)
        }

        func deactivateApplication(withPID pid: pid_t) {
            deactivatedPIDs.insert(pid)
        }

        func regenerateActiveIDCache() {
            let windowDescriptions = CGWindowsInfo<Window>(options: .optionOnScreenOnly, windowID: CGWindowID(0))
            activeIDCache = windowDescriptions?.activeIDs() ?? Set()
        }

        // MARK: Window Sets

        func windowSet(forWindowsOnScreen screen: Screen) -> WindowSet<Window> {
            return windowSet(forWindows: windows(onScreen: screen))
        }

        func windowSet(forActiveWindowsOnScreen screen: Screen) -> WindowSet<Window> {
            return windowSet(forWindows: activeWindows(onScreen: screen))
        }

        func windowSet(forWindows windows: [Window]) -> WindowSet<Window> {
            let layoutWindows: [LayoutWindow<Window>] = windows.map {
                LayoutWindow(id: $0.id(), frame: $0.frame(), isFocused: $0.isFocused())
            }

            let snapshotFloatingMap = floatingMap
            let snapshotActiveIDCache = activeIDCache
            // Use a uniquing initializer rather than `uniqueKeysWithValues:`, which traps on
            // duplicate keys. Distinct windows can momentarily report the same id() (e.g. windows
            // that expose a 0 CGWindowID), and a duplicate must not crash a reflow.
            let snapshotWindowsByID = Dictionary(windows.map { ($0.id(), $0) }, uniquingKeysWith: { first, _ in first })

            return WindowSet<Window>(
                windows: layoutWindows,
                isWindowWithIDActive: { id -> Bool in
                    guard let window = snapshotWindowsByID[id] else {
                        return false
                    }
                    return window.isActive() && snapshotActiveIDCache.contains(window.cgID())
                },
                isWindowWithIDFloating: { windowID -> Bool in
                    return snapshotFloatingMap[windowID] ?? false
                },
                windowForID: { windowID -> Window? in
                    return snapshotWindowsByID[windowID]
                }
            )
        }
    }
}
