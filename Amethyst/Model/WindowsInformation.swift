//
//  WindowsInformation.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

import ApplicationServices
import Foundation
import Silica

extension CGRect {
    func approximatelyEqual(to otherRect: CGRect, within tolerance: CGRect) -> Bool {
        return abs(origin.x - otherRect.origin.x) < tolerance.origin.x &&
        abs(origin.y - otherRect.origin.y) < tolerance.origin.y &&
        abs(width - otherRect.width) < tolerance.width &&
        abs(height - otherRect.height) < tolerance.height
    }
}

extension WindowActivityCache {
    func windows<Window: WindowType>(_ windows: [Window], on screen: NSScreen) -> [Window] {
        guard let screenIdentifier = screen.screenIdentifier() else {
            return []
        }

        guard let currentSpace = SpacesInformation<Window>.currentSpaceForScreen(screen) else {
            log.warning("Could not find a space for screen: \(screenIdentifier)")
            return []
        }

        let screenWindows = windows.filter { window in
            let windowIDsArray = [NSNumber(value: window.windowID() as UInt32)] as NSArray

            guard let spaces = CGSCopySpacesForWindows(CGSMainConnectionID(), kCGSAllSpacesMask, windowIDsArray)?.takeRetainedValue() else {
                return false
            }

            let space = (spaces as NSArray as? [NSNumber])?.first?.intValue

            guard let windowScreen = window.screen(), space == currentSpace else {
                return false
            }

            return windowScreen.screenIdentifier() == screen.screenIdentifier() && self.windowIsActive(window)
        }

        return screenWindows
    }
}

struct WindowsInformation<Window: WindowType> {
    let ids: Set<CGWindowID>
    let descriptions: WindowDescriptions?

    init?(windows: [Window]) {
        guard let descriptions = WindowDescriptions(options: .optionOnScreenOnly, windowID: CGWindowID(0)) else {
            return nil
        }

        self.ids = Set(windows.map { $0.windowID() })
        self.descriptions = descriptions
    }
}

extension WindowsInformation {
    // convert Window objects to CGWindowIDs.
    // additionally, return the full set of window descriptions (which is unsorted and may contain extra windows)
    fileprivate static func windowInformation(_ windows: [Window]) -> (IDs: Set<CGWindowID>, descriptions: [[String: AnyObject]]?) {
        let ids = Set(windows.map { $0.windowID() })
        return (IDs: ids, descriptions: WindowDescriptions(options: .optionOnScreenOnly, windowID: CGWindowID(0))?.descriptions)
    }

    fileprivate static func onScreenWindowsAtPoint(_ point: CGPoint,
                                                   withIDs windowIDs: Set<CGWindowID>,
                                                   withDescriptions windowDescriptions: [[String: AnyObject]]) -> [[String: AnyObject]] {
        var ret: [[String: AnyObject]] = []

        // build a list of windows at this point
        for windowDescription in windowDescriptions {
            guard let windowID = (windowDescription[kCGWindowNumber as String] as? NSNumber).flatMap({ CGWindowID($0.intValue) }),
                windowIDs.contains(windowID) else {
                continue
            }

            // only consider windows with bounds
            guard let windowFrameDictionary = windowDescription[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            // only consider window bounds that contain the given point
            let windowFrame = CGRect(dictionaryRepresentation: windowFrameDictionary as CFDictionary)!
            guard windowFrame.contains(point) else {
                continue
            }
            ret.append(windowDescription)
        }

        return ret
    }

    // if there are several windows at a given screen point, take the top one
    static func topWindowForScreenAtPoint(_ point: CGPoint, withWindows windows: [Window]) -> Window? {
        let (ids, maybeWindowDescriptions) = windowInformation(windows)
        guard let windowDescriptions = maybeWindowDescriptions, !windowDescriptions.isEmpty else {
            return nil
        }

        let windowsAtPoint = onScreenWindowsAtPoint(point, withIDs: ids, withDescriptions: windowDescriptions)

        guard !windowsAtPoint.isEmpty else {
            return nil
        }

        guard windowsAtPoint.count > 1 else {
            return windowInWindows(windows, withCGWindowDescription: windowsAtPoint[0])
        }

        var windowToFocus: [String: AnyObject]?
        var minCount = windowDescriptions.count
        for windowDescription in windowsAtPoint {
            guard let windowID = windowDescription[kCGWindowNumber as String] as? NSNumber else {
                continue
            }

            guard let windowsAboveWindow = WindowDescriptions(options: .optionOnScreenAboveWindow, windowID: windowID.uint32Value) else {
                continue
            }

            if windowsAboveWindow.descriptions.count < minCount {
                windowToFocus = windowDescription
                minCount = windowsAboveWindow.descriptions.count
            }
        }

        guard let windowDictionaryToFocus = windowToFocus else {
            return nil
        }

        return windowInWindows(windows, withCGWindowDescription: windowDictionaryToFocus)
    }

    // get the first window at a certain point, excluding one specific window from consideration
    static func alternateWindowForScreenAtPoint(_ point: CGPoint, withWindows windows: [Window], butNot ignoreWindow: Window?) -> Window? {
        // only consider windows on this screen
        let (ids, maybeWindowDescriptions) = windowInformation(windows)
        guard let windowDescriptions = maybeWindowDescriptions, !windowDescriptions.isEmpty else {
            return nil
        }

        let windowsAtPoint = onScreenWindowsAtPoint(point, withIDs: ids, withDescriptions: windowDescriptions)

        for windowDescription in windowsAtPoint {
            if let window = windowInWindows(windows, withCGWindowDescription: windowDescription) {
                if let ignored = ignoreWindow, window != ignored {
                    return window
                }
            }
        }

        return nil
    }

    // find a window based on its window description within an array of Window objects
    static func windowInWindows(_ windows: [Window], withCGWindowDescription windowDescription: [String: AnyObject]) -> Window? {
        let potentialWindows = windows.filter {
            guard let windowOwnerProcessIdentifier = windowDescription[kCGWindowOwnerPID as String] as? NSNumber else {
                return false
            }

            guard windowOwnerProcessIdentifier.int32Value == $0.pid() else {
                return false
            }

            guard let boundsDictionary = windowDescription[kCGWindowBounds as String] as? [String: Any] else {
                return false
            }

            let windowFrame = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)!

            guard windowFrame.equalTo($0.frame()) else {
                return false
            }

            return true
        }

        guard potentialWindows.count > 1 else {
            return potentialWindows.first
        }

        return potentialWindows.first {
            guard let describedTitle = windowDescription[kCGWindowName as String] as? String else {
                return false
            }

            let describedOwner = windowDescription[kCGWindowOwnerName as String] as? String
            let describedOwnedTitle = describedOwner.flatMap { "\(describedTitle) - \($0)" }

            return describedTitle == $0.title() || describedOwnedTitle == $0.title()
        }
    }
}
