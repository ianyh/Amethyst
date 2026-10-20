//
//  WindowCapture.swift
//  Amethyst
//
//  Created by Don Patterson on 9/8/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import os.log

private let captureLog = OSLog(subsystem: "com.amethyst.Amethyst", category: "animation")

/// Writes a line about window capture to the system log, in the same category as the animation timings.
private func logCapture(_ message: String) {
    os_log("%{public}s", log: captureLog, type: .info, message)
}

/**
 Keeps a stalled window server from stalling reflows.

 A capture that the window server does not answer blocks its thread until the system gives up on it, thirty seconds later. The gate bounds the damage three ways: at most `maximumInFlight` captures run at once, so a stall cannot swallow the thread pool; a batch is given up after `deadline`, so the reflow falls back to moving the real windows instead of waiting; and after a batch has timed out, captures are refused for `pauseAfterTimeout`, so the reflows that follow fall back at once.
 */
final class WindowCaptureGate {
    static let shared = WindowCaptureGate()

    private let maximumInFlight: Int
    private let deadline: TimeInterval
    private let pauseAfterTimeout: TimeInterval
    private let now: () -> TimeInterval
    private let report: (String) -> Void
    private let slots: DispatchSemaphore
    private let queue = DispatchQueue(label: "Amethyst.WindowCaptureGate", qos: .userInitiated, attributes: .concurrent)
    private let lock = NSLock()
    private var pausedUntil: TimeInterval?

    /**
     - Parameters:
         - maximumInFlight: How many captures may run at the same time.
         - deadline: How long a batch may take before it is given up.
         - pauseAfterTimeout: How long captures are refused after a batch has timed out.
         - now: The current time, in seconds.
         - report: Receives one line when captures are paused and one when they resume.
     */
    init(
        maximumInFlight: Int = 16,
        deadline: TimeInterval = 1,
        pauseAfterTimeout: TimeInterval = 15,
        now: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate },
        report: @escaping (String) -> Void = logCapture
    ) {
        self.maximumInFlight = maximumInFlight
        self.deadline = deadline
        self.pauseAfterTimeout = pauseAfterTimeout
        self.now = now
        self.report = report
        self.slots = DispatchSemaphore(value: maximumInFlight)
    }

    /// Whether captures are being refused because a batch timed out recently.
    var isPaused: Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let pausedUntil = pausedUntil else {
            return false
        }
        guard now() < pausedUntil else {
            self.pausedUntil = nil
            report("Window capture resumed after the pause")
            return false
        }
        return true
    }

    /**
     Runs `capture` for every input at the same time and collects the results in order.

     - Returns: One result per input, or `nil` if captures are paused, a slot did not come free before the deadline, the batch did not finish before the deadline, or any capture returned `nil`. A capture still running when the batch is given up keeps its slot until it returns, and its result is dropped.
     */
    func perform<Input, Output>(_ inputs: [Input], _ capture: @escaping (Input) -> Output?) -> [Output]? {
        guard !inputs.isEmpty else {
            return []
        }
        guard !isPaused else {
            return nil
        }

        let limit = DispatchTime.now() + deadline
        let results = Results<Output>(count: inputs.count)
        let group = DispatchGroup()

        for (index, input) in inputs.enumerated() {
            guard slots.wait(timeout: limit) == .success else {
                pause("no capture slot came free within \(deadline)s")
                return nil
            }

            group.enter()
            queue.async { [slots] in
                let output = capture(input)
                slots.signal()
                results.store(output, at: index)
                group.leave()
            }
        }

        guard group.wait(timeout: limit) == .success else {
            pause("window capture did not finish within \(deadline)s")
            return nil
        }

        return results.all()
    }

    private func pause(_ reason: String) {
        lock.lock()
        defer { lock.unlock() }

        let alreadyPaused = pausedUntil.map { now() < $0 } ?? false
        pausedUntil = now() + pauseAfterTimeout
        if !alreadyPaused {
            report("Window capture paused for \(pauseAfterTimeout)s: \(reason)")
        }
    }

    /// The results of one batch, filled in from the capture threads.
    private final class Results<Output> {
        private let lock = NSLock()
        private var outputs: [Output?]

        init(count: Int) {
            outputs = [Output?](repeating: nil, count: count)
        }

        func store(_ output: Output?, at index: Int) {
            lock.lock()
            outputs[index] = output
            lock.unlock()
        }

        /// Every result, or `nil` if any is missing.
        func all() -> [Output]? {
            lock.lock()
            defer { lock.unlock() }

            let present = outputs.compactMap { $0 }
            return present.count == outputs.count ? present : nil
        }
    }
}

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

     Requires the Screen Recording permission; without it the window server returns nothing. Each window is captured separately because a single call with several IDs yields one composite image, not one per window. The captures run concurrently through `WindowCaptureGate`, since each is a synchronous round trip to the window server of roughly 15ms that can, when the window server stalls, block for thirty seconds.

     - Returns: One image per window ID, in the same order, or `nil` if any capture failed or the gate refused the batch.
     */
    static func captureImages(for windowIDs: [CGWindowID]) -> [CGImage]? {
        guard let functions = functions, !windowIDs.isEmpty else {
            return nil
        }

        let connection = functions.mainConnectionID()
        return WindowCaptureGate.shared.perform(windowIDs) { windowID in
            captureImage(of: windowID, connection: connection, functions: functions)
        }
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
