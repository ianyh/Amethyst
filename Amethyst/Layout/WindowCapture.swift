//
//  WindowCapture.swift
//  Amethyst
//
//  Created by Don Patterson on 9/8/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa

/**
 Minimal bridge to the two private SkyLight (window server) functions the snapshot animation needs.

 Both are resolved at runtime with `dlsym`, so a macOS release that drops or renames them makes `isAvailable` false and the animation silently falls back to moving the real windows. Nothing else in the snapshot animation is private.
 */
enum SkyLight {
    private typealias MainConnectionIDFunction = @convention(c) () -> Int32
    private typealias CaptureWindowListFunction = @convention(c) (Int32, UnsafeMutablePointer<UInt32>, Int32, UInt32) -> Unmanaged<CFArray>?

    private struct Functions {
        let mainConnectionID: MainConnectionIDFunction
        let captureWindowList: CaptureWindowListFunction
    }

    private static let functions: Functions? = {
        guard
            let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW),
            let connectionSymbol = dlsym(handle, "SLSMainConnectionID"),
            let captureSymbol = dlsym(handle, "SLSHWCaptureWindowList")
        else {
            return nil
        }

        return Functions(
            mainConnectionID: unsafeBitCast(connectionSymbol, to: MainConnectionIDFunction.self),
            captureWindowList: unsafeBitCast(captureSymbol, to: CaptureWindowListFunction.self)
        )
    }()

    /// The option bits yabai passes to `SLSHWCaptureWindowList`; they yield a full-resolution image of just the window.
    private static let captureOptions: UInt32 = (1 << 11) | (1 << 8)

    /// Whether both private functions resolved on this system.
    static var isAvailable: Bool {
        return functions != nil
    }

    /**
     Captures the current contents of the given windows.

     Requires the Screen Recording permission; without it the window server returns nothing. Each window is captured separately because a single call with several IDs yields one composite image, not one per window. The captures run concurrently, since each is a synchronous round trip to the window server of roughly 15ms.

     - Returns: One image per window ID, in the same order, or `nil` if any capture failed.
     */
    static func captureImages(for windowIDs: [CGWindowID]) -> [CGImage]? {
        guard let functions = functions, !windowIDs.isEmpty else {
            return nil
        }

        let connection = functions.mainConnectionID()
        var images = [CGImage?](repeating: nil, count: windowIDs.count)
        let lock = NSLock()

        DispatchQueue.concurrentPerform(iterations: windowIDs.count) { index in
            let image = captureImage(of: windowIDs[index], connection: connection, functions: functions)
            lock.lock()
            images[index] = image
            lock.unlock()
        }

        let captured = images.compactMap { $0 }
        return captured.count == windowIDs.count ? captured : nil
    }

    private static func captureImage(of windowID: CGWindowID, connection: Int32, functions: Functions) -> CGImage? {
        var identifier = UInt32(windowID)

        guard let array = functions.captureWindowList(connection, &identifier, 1, captureOptions)?.takeRetainedValue(), CFArrayGetCount(array) == 1 else {
            return nil
        }

        // The array owns the image; keep it alive until Swift holds its own strong reference to the image.
        return withExtendedLifetime(array) { () -> CGImage? in
            guard let value = CFArrayGetValueAtIndex(array, 0) else {
                return nil
            }
            return Unmanaged<CGImage>.fromOpaque(value).takeUnretainedValue()
        }
    }
}

/// A window to capture and where it currently is, in the flipped coordinates Accessibility uses.
struct WindowCaptureRequest {
    let windowID: CGWindowID
    let frame: CGRect
}

/// The displays the window server currently drives, and the one rule for deciding which of them a rectangle belongs to.
enum ActiveDisplays {
    static func identifiers() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        return displays
    }

    /// The bounds of every active display, in the flipped coordinates Accessibility uses.
    static func bounds() -> [CGRect] {
        return identifiers().map { CGDisplayBounds($0) }
    }

    /// The candidate whose bounds overlap `rect` most, or `nil` if none overlaps it at all.
    static func mostOverlapping<Candidate>(_ rect: CGRect, among candidates: [Candidate], bounds: (Candidate) -> CGRect) -> Candidate? {
        func overlap(_ candidate: Candidate) -> CGFloat {
            let intersection = bounds(candidate).intersection(rect)
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        guard let best = candidates.max(by: { overlap($0) < overlap($1) }), overlap(best) > 0 else {
            return nil
        }
        return best
    }
}

/**
 Captures full images of windows, choosing the mechanism per window.

 The window server renders only the part of a window that lies on a display, and for a window straddling two displays it may hand back the part on either one. SkyLight's capture is fast but inherits that limit, so it is used for windows lying entirely within the display being animated, and ScreenCaptureKit's desktop-independent window capture, slower but complete, is used for windows that overhang a display edge, typically because their minimum size exceeds their tile.
 */
enum WindowImageCapture {
    /// The bounds of the display among `bounds` that overlaps `screenFrame` most, or `nil` if none does.
    static func displayBounds(containing screenFrame: CGRect, among bounds: [CGRect]) -> CGRect? {
        return ActiveDisplays.mostOverlapping(screenFrame, among: bounds) { $0 }
    }

    /// The bounds of the active display containing `screenFrame`.
    static func activeDisplayBounds(containing screenFrame: CGRect) -> CGRect? {
        return displayBounds(containing: screenFrame, among: ActiveDisplays.bounds())
    }

    /**
     Whether a capture of this window reports the window's real surface size, so that a capture taken before the application has
     redrawn can be told apart from a fresh one. SkyLight captures do; ScreenCaptureKit scales its output to the requested size
     and so never reveals a stale surface.
     */
    static func isCaptureVerifiable(_ request: WindowCaptureRequest, displayBounds: CGRect?) -> Bool {
        guard let displayBounds = displayBounds else {
            return true
        }
        return displayBounds.contains(request.frame)
    }

    /**
     Captures every requested window in full.

     - Parameters:
         - requests: The windows and their current frames.
         - displayBounds: The display being animated. Windows not entirely within it go through ScreenCaptureKit.
     - Returns: One image per request, in order, or `nil` if any capture failed.
     */
    static func captureImages(for requests: [WindowCaptureRequest], displayBounds: CGRect?) -> [CGImage]? {
        var images = [CGImage?](repeating: nil, count: requests.count)
        var overhanging: [Int] = []
        var contained: [Int] = []

        for (index, request) in requests.enumerated() {
            if let displayBounds = displayBounds, !displayBounds.contains(request.frame) {
                overhanging.append(index)
            } else {
                contained.append(index)
            }
        }

        if !contained.isEmpty {
            guard let captured = SkyLight.captureImages(for: contained.map { requests[$0].windowID }) else {
                return nil
            }
            for (position, index) in contained.enumerated() {
                images[index] = captured[position]
            }
        }

        if !overhanging.isEmpty {
            var captured: [CGImage]?
            if #available(macOS 14.0, *) {
                captured = BackdropCapturer.shared.captureWindows(overhanging.map { requests[$0] })
            }
            // Without ScreenCaptureKit the clipped image is still better than none.
            if captured == nil {
                captured = SkyLight.captureImages(for: overhanging.map { requests[$0].windowID })
            }
            guard let captured = captured else {
                return nil
            }
            for (position, index) in overhanging.enumerated() {
                images[index] = captured[position]
            }
        }

        let result = images.compactMap { $0 }
        return result.count == requests.count ? result : nil
    }
}

/// The Screen Recording permission that window capture depends on.
enum ScreenCapturePermission {
    private static var hasRequested = false

    static var isGranted: Bool {
        return CGPreflightScreenCaptureAccess()
    }

    /**
     Shows the system permission prompt at most once per launch. macOS applies a new grant on the next launch of the app.

     - Returns: `true` if the prompt was requested by this call.
     */
    @discardableResult
    static func requestOnce() -> Bool {
        guard !hasRequested else {
            return false
        }

        hasRequested = true
        CGRequestScreenCaptureAccess()
        return true
    }

    /// Remembers that Amethyst's own hint about the permission has been shown. macOS prompts only once ever, and the hint is shown once as well.
    static let hintShownKey = "screen-recording-hint-shown"

    /// How long the hint stays up, long enough to read a sentence.
    static let hintDuration: TimeInterval = 4

    /// Whether the hint should be shown now, recording that it was. `true` once per `defaults` store.
    static func takeHintOpportunity(defaults: UserDefaults = .standard) -> Bool {
        guard !defaults.bool(forKey: hintShownKey) else {
            return false
        }

        defaults.set(true, forKey: hintShownKey)
        return true
    }
}
