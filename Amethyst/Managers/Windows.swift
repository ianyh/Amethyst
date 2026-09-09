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
            let attachedScreenIDs = Windows.attachedScreenIDs()
            return windows.filter { isWindow($0, on: screen, attachedScreenIDs: attachedScreenIDs) }
        }

        /// The identifiers of the screens currently attached, computed once per query.
        private static func attachedScreenIDs() -> Set<String> {
            return Set(Screen.availableScreens.compactMap { $0.screenID() })
        }

        /**
         A window being animated by a screen's reflow belongs to that screen even while it briefly straddles another display.

         A registration for a screen that is no longer attached is ignored, as the window's own screen lookup ignores it: the display was unplugged mid-animation and the windows now lie wherever macOS put them.
         */
        private func isWindow(_ window: Window, on screen: Screen, attachedScreenIDs: Set<String>) -> Bool {
            if let animatingScreenID = AnimatingWindows.shared.screenID(for: window.cgID(), ifAmong: attachedScreenIDs), let screenID = screen.screenID() {
                return animatingScreenID == screenID
            }
            return window.screen() == screen
        }

        func activeWindows(onScreen screen: Screen) -> [Window] {
            guard let screenID = screen.screenID() else {
                return []
            }

            guard let currentSpace = CGSpacesInfo<Window>.currentSpaceForScreen(screen) else {
                log.warning("Could not find a space for screen: \(screenID)")
                return []
            }

            let attachedScreenIDs = Windows.attachedScreenIDs()
            let screenWindows = windows.filter { window in
                let space = CGWindowsInfo.windowSpace(window)

                guard currentSpace.id == space, isWindow(window, on: screen, attachedScreenIDs: attachedScreenIDs) else {
                    return false
                }

                let isActive = self.isWindowActive(window)
                let isHidden = self.isWindowHidden(window)
                let isFloating = self.isWindowFloating(window)

                return isActive && !isHidden && !isFloating
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

        @discardableResult func replace(window: Window, withWindow otherWindow: Window) -> Bool {
            if let currentFocusedSpace = CGSpacesInfo<Window>.currentFocusedSpace(),
               let firstActiveWindow = activeWindowOnCurrentScreen(atIndex: 0) {
                if firstActiveWindow == window || firstActiveWindow == otherWindow {
                    lastMainWindows[currentFocusedSpace.id] = firstActiveWindow
                }
            }

            guard let otherWindowIndex = windows.firstIndex(of: otherWindow) else {
                windows.append(otherWindow)
                return false
            }

            let windowIndex = windows.firstIndex(of: window)
            windows[otherWindowIndex] = window

            if let windowIndex {
                windows.remove(at: windowIndex)
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
            let snapshotWindowsByID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id(), $0) })

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
