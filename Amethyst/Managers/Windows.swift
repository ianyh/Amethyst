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
        private var activeIDCache: Set<CGWindowID> = Set()
        private var floatingMap: [CGWindowID: Bool] = [:]

        // MARK: Window Filters

        func window(withWindowID windowID: CGWindowID) -> Window? {
            return windows.first { $0.windowID() == windowID }
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
                let windowIDsArray = [NSNumber(value: window.windowID() as UInt32)] as NSArray

                guard let spaces = CGSCopySpacesForWindows(CGSMainConnectionID(), kCGSAllSpacesMask, windowIDsArray)?.takeRetainedValue() else {
                    return false
                }

                let space = (spaces as NSArray as? [NSNumber])?.first?.intValue

                guard let windowScreen = window.screen(), currentSpace.id == space else {
                    return false
                }

                return windowScreen.screenID() == screen.screenID() && self.isWindowActive(window)
            }

            return screenWindows
        }

        // MARK: Adding and Removing

        func add(window: Window, atFront shouldInsertAtFront: Bool) {
            if shouldInsertAtFront {
                windows.insert(window, at: 0)
            } else {
                windows.append(window)
            }
        }

        func remove(window: Window) {
            guard let windowIndex = windows.index(of: window) else {
                return
            }

            windows.remove(at: windowIndex)
        }

        @discardableResult func swap(window: Window, withWindow otherWindow: Window) -> Bool {
            guard let windowIndex = windows.index(of: window), let otherWindowIndex = windows.index(of: otherWindow) else {
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
            return windows.contains(window)
        }

        func isWindowActive(_ window: Window) -> Bool {
            return window.isActive() && activeIDCache.contains(window.windowID())
        }

        func isWindowFloating(_ window: Window) -> Bool {
            return floatingMap[window.windowID()] ?? false
        }

        func setFloating(_ floating: Bool, forWindow window: Window) {
            floatingMap[window.windowID()] = floating
        }

        func regenerateActiveIDCache() {
            let windowDescriptions = CGWindowsInfo(options: .optionOnScreenOnly, windowID: CGWindowID(0))
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
            let layoutWindows = windows.map { LayoutWindow(id: $0.windowID(), frame: $0.frame()) }

            return WindowSet<Window>(
                windows: layoutWindows,
                isWindowWithIDActive: { [weak self] windowID -> Bool in
                    guard let window = self?.window(withWindowID: windowID) else {
                        return false
                    }
                    return self?.isWindowActive(window) ?? false
                },
                isWindowWithIDFloating: { [weak self] windowID -> Bool in
                    guard let window = self?.window(withWindowID: windowID) else {
                        return false
                    }
                    return self?.isWindowFloating(window) ?? false
                },
                windowForID: { [weak self] windowID -> Window? in
                    return self?.window(withWindowID: windowID)
                }
            )
        }
    }
}
