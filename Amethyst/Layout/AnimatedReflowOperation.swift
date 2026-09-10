//
//  AnimatedReflowOperation.swift
//  Amethyst
//
//  Created by Don Patterson on 9/8/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

import CoreGraphics
import Foundation
import os.log

/// Unified-log channel for animation timing, readable with `log stream --info --predicate 'subsystem == "com.amethyst.Amethyst"'` even in release builds.
private let animationLog = OSLog(subsystem: "com.amethyst.Amethyst", category: "animation")

/// Records an animation event on both channels: the app's logger, which only prints in debug builds, and the unified log, which is all a release build has.
private func logAnimation(_ message: String) {
    log.debug(message)
    os_log("%{public}s", log: animationLog, type: .info, message)
}

/// How long to wait for slow applications to apply their last frame before moving on.
private let defaultWriterDrainTimeout: TimeInterval = 1.0

/// How long a proxy takes to correct itself when an application only reports its real size after the glide has ended.
private let lateCorrectionDuration: TimeInterval = 0.1

/// The least time a proxy takes to dissolve into a fresh capture, even when the glide is about to end; shorter reads as a snap.
private let minimumDissolveDuration: TimeInterval = 0.15

/// How long after an application accepts its new frame to wait before capturing it again. The accessibility call returns before many applications have redrawn, and a capture taken too early shows stale or empty content.
private let redrawSettleDelay: TimeInterval = 0.06

/// Pure interpolation helpers for animated reflows.
enum FrameInterpolation {
    /// Sinusoidal ease-in-out: gentle start and finish, with peak velocity only about 1.6x linear so no single frame jumps far even at low tick rates.
    static func easeInOutSine(_ progress: CGFloat) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        return (1 - cos(clamped * .pi)) / 2
    }

    /**
     Linearly interpolates between two rects.

     Each edge is interpolated and rounded independently, so every edge of the result lies between the corresponding edges of `start` and `end`, and consecutive ticks either produce a visibly different frame or an identical one that can be skipped.
     */
    static func interpolate(from start: CGRect, to end: CGRect, progress: CGFloat) -> CGRect {
        func lerp(_ startValue: CGFloat, _ endValue: CGFloat) -> CGFloat {
            return (startValue + (endValue - startValue) * progress).rounded()
        }

        let minX = lerp(start.minX, end.minX)
        let minY = lerp(start.minY, end.minY)
        let maxX = lerp(start.maxX, end.maxX)
        let maxY = lerp(start.maxY, end.maxY)

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Rounds a rect to integral points.
    static func integral(_ rect: CGRect) -> CGRect {
        return interpolate(from: rect, to: rect, progress: 0)
    }

    /**
     A live window frame rounded to integral points, or `nil` if it could not be read.

     An accessibility frame read fails when the application is hung or the window has gone, and Silica reports that as the null rect, whose coordinates are infinite. Doing arithmetic on it yields NaN, which traps when converted to an integer and is rejected by Core Animation, so every read goes through here.
     */
    static func readable(_ rect: CGRect) -> CGRect? {
        guard !rect.isNull, !rect.isInfinite, [rect.minX, rect.minY, rect.width, rect.height].allSatisfy({ $0.isFinite }) else {
            return nil
        }
        return integral(rect)
    }
}

/**
 Applies frame writes for one application on a serial queue of its own.

 Accessibility writes block until the target application has processed them, and applications differ wildly in how quickly they do so. Each writer always applies the newest frame requested for each of its windows and drops any frames it could not keep up with, so a slow application only lowers its own frame rate instead of holding every other window back.
 */
final class ApplicationFrameWriter<Window: WindowType> {
    struct Write {
        let window: Window
        let frame: CGRect
        let includingSize: Bool
    }

    struct Statistics {
        var requested = 0
        var applied = 0
        var totalWriteTime: TimeInterval = 0

        var averageWriteTime: TimeInterval {
            return applied == 0 ? 0 : totalWriteTime / TimeInterval(applied)
        }
    }

    let pid: pid_t

    /// `nil` applies writes inline on the caller's thread, which keeps tests deterministic.
    private let queue: DispatchQueue?
    private let group: DispatchGroup
    private let now: () -> TimeInterval
    private let beginWrite: (Window) -> Bool
    private let endWrite: (Window) -> Void
    private let lock = NSLock()
    private var pending: [Int: Write] = [:]
    private var isDraining = false
    private var statistics = Statistics()

    /**
     - Parameters:
         - beginWrite: Asked immediately before each frame is written; answering `false` leaves the window alone, because it was handed to another screen while its frame waited its turn.
         - endWrite: Told once the frame has been written, so whoever is waiting to take the window over knows it is free.
     */
    init(
        pid: pid_t,
        group: DispatchGroup,
        inline: Bool,
        now: @escaping () -> TimeInterval,
        beginWrite: @escaping (Window) -> Bool = { _ in true },
        endWrite: @escaping (Window) -> Void = { _ in }
    ) {
        self.pid = pid
        self.group = group
        self.now = now
        self.beginWrite = beginWrite
        self.endWrite = endWrite
        self.queue = inline ? nil : DispatchQueue(label: "Amethyst.ApplicationFrameWriter.\(pid)", qos: .userInteractive)
    }

    /// Requests writes keyed by window. A later request for the same window supersedes an earlier one that has not been applied yet, except that a size the earlier one carried is kept.
    func write(_ writes: [Int: Write]) {
        lock.lock()
        for (key, write) in writes {
            // A position-only write always carries the size the earlier resize intended, so folding the resize into it loses nothing.
            if let earlier = pending[key], earlier.includingSize, !write.includingSize {
                pending[key] = Write(window: write.window, frame: write.frame, includingSize: true)
            } else {
                pending[key] = write
            }
            statistics.requested += 1
        }
        let shouldStartDraining = !isDraining && !pending.isEmpty
        if shouldStartDraining {
            isDraining = true
        }
        lock.unlock()

        guard shouldStartDraining else {
            return
        }

        group.enter()
        if let queue = queue {
            queue.async { self.drain() }
        } else {
            drain()
        }
    }

    /// Whether every requested write has been applied.
    var isIdle: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pending.isEmpty && !isDraining
    }

    /// Drops frames that have not been applied yet, for cancellation.
    func discardPending() {
        lock.lock()
        pending.removeAll()
        lock.unlock()
    }

    func statisticsSnapshot() -> Statistics {
        lock.lock()
        defer { lock.unlock() }
        return statistics
    }

    func resetStatistics() {
        lock.lock()
        statistics = Statistics()
        lock.unlock()
    }

    private func drain() {
        while true {
            lock.lock()
            let batch = pending
            pending.removeAll()
            if batch.isEmpty {
                isDraining = false
                lock.unlock()
                group.leave()
                return
            }
            lock.unlock()

            for write in batch.values {
                // The window may have been handed to another screen while this frame waited behind a slow application, so
                // ownership is checked again here, immediately before the write.
                guard beginWrite(write.window) else {
                    continue
                }

                let start = now()
                write.window.setAnimationFrame(write.frame, includingSize: write.includingSize)
                let elapsed = now() - start
                endWrite(write.window)

                lock.lock()
                statistics.applied += 1
                statistics.totalWriteTime += elapsed
                lock.unlock()
            }
        }
    }
}

/**
 Which screen each animating window currently belongs to.

 While a window is being moved and resized behind the backdrop it can briefly have most of its area on another display, and a reflow on that display, triggered for example by an application activating, would otherwise claim it and tile it there. Registering in-flight windows lets the screen filters keep them with the screen that is animating them.
 */
final class AnimatingWindows {
    static let shared = AnimatingWindows()

    /// Guards every table below and lets a hand-off wait for writes in flight to end.
    private let lock = NSCondition()
    private var screenIDsByWindow: [CGWindowID: String] = [:]
    /// Where the animation is taking each claimed window, so a hand-off can put a window still parked off-screen somewhere sane.
    private var targetsByWindow: [CGWindowID: CGRect] = [:]
    /// How many frame writes are being applied to each window right now.
    private var writesInFlight: [CGWindowID: Int] = [:]
    private var lastSeenFrames: [CGWindowID: (frame: CGRect, time: TimeInterval)] = [:]

    /// How long a cancelled animation's last picture positions stay relevant to a follow-up animation.
    static let lastSeenFrameLifetime: TimeInterval = 1.0

    /// How long a hand-off waits for a slow application to finish applying a frame already being written.
    static let handOffTimeout: TimeInterval = 1.0

    /**
     Remembers where a cancelled animation last showed each window, so the animation that replaces it can start its pictures
     there rather than from the windows' real frames. The real windows are left at valid tiles regardless.
     */
    func recordLastSeenFrames(_ frames: [CGWindowID: CGRect], at time: TimeInterval) {
        lock.lock()
        for (windowID, frame) in frames {
            lastSeenFrames[windowID] = (frame, time)
        }
        lock.unlock()
    }

    /// Where the window's picture was last seen, if a cancelled animation recorded it recently. Consumed on read.
    func takeLastSeenFrame(for windowID: CGWindowID, at time: TimeInterval) -> CGRect? {
        lock.lock()
        defer { lock.unlock() }
        lastSeenFrames = lastSeenFrames.filter { time - $0.value.time <= AnimatingWindows.lastSeenFrameLifetime }
        return lastSeenFrames.removeValue(forKey: windowID)?.frame
    }

    /// Claims the windows for `screenID`, recording where its animation is taking each one.
    func claim(_ windowIDs: [CGWindowID], for screenID: String, targets: [CGWindowID: CGRect] = [:]) {
        lock.lock()
        for windowID in windowIDs {
            screenIDsByWindow[windowID] = screenID
            targetsByWindow[windowID] = targets[windowID]
        }
        lock.unlock()
    }

    /**
     Registers a frame write about to be applied to the window on behalf of `screenID`.

     - Returns: `false`, registering nothing, if the window is no longer that screen's to move; the write must then be skipped.
     */
    func beginWrite(_ windowID: CGWindowID, for screenID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard screenIDsByWindow[windowID] == screenID else {
            return false
        }
        writesInFlight[windowID, default: 0] += 1
        return true
    }

    /// Records that a write registered with `beginWrite` has been applied, releasing any hand-off waiting for it.
    func endWrite(_ windowID: CGWindowID) {
        lock.lock()
        if let count = writesInFlight[windowID] {
            writesInFlight[windowID] = count > 1 ? count - 1 : nil
        }
        lock.broadcast()
        lock.unlock()
    }

    /**
     Drops any claim on the windows, whichever screen holds it, and waits for writes already being applied to them to finish.

     Called when Amethyst itself relocates a window to another screen or Space: the animation that was moving it must stop touching it, and the destination screen must be free to adopt it at once. Once this returns, no frame the animation queued can land on the window any more.

     - Returns: Where the animation was taking each window it had claimed, so a window still parked beyond every display can be put back on its screen before it is moved.
     */
    @discardableResult
    func handOff(_ windowIDs: [CGWindowID], timeout: TimeInterval = AnimatingWindows.handOffTimeout) -> [CGWindowID: CGRect] {
        lock.lock()
        defer { lock.unlock() }

        var targets: [CGWindowID: CGRect] = [:]
        for windowID in windowIDs {
            screenIDsByWindow[windowID] = nil
            targets[windowID] = targetsByWindow.removeValue(forKey: windowID)
        }

        let deadline = Date(timeIntervalSinceNow: timeout)
        while windowIDs.contains(where: { writesInFlight[$0] != nil }) && lock.wait(until: deadline) {}
        return targets
    }

    /// Releases windows claimed for `screenID`; claims made since by another screen are left alone.
    func release(_ windowIDs: [CGWindowID], for screenID: String) {
        lock.lock()
        for windowID in windowIDs where screenIDsByWindow[windowID] == screenID {
            screenIDsByWindow[windowID] = nil
            targetsByWindow[windowID] = nil
        }
        lock.unlock()
    }

    /// The screen animating the window, if any.
    func screenID(for windowID: CGWindowID) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return screenIDsByWindow[windowID]
    }

    /// The screen animating the window, provided it is one of `screenIDs`, the screens currently attached. A display unplugged mid-animation keeps its claims until its operation ends, but the windows are no longer its to keep.
    func screenID(for windowID: CGWindowID, ifAmong screenIDs: Set<String>) -> String? {
        return screenID(for: windowID).flatMap { screenIDs.contains($0) ? $0 : nil }
    }

    /// Whether an animation is currently moving the window, so a move or resize notification about it is Amethyst's own doing rather than a user gesture.
    func isAnimating(_ windowID: CGWindowID) -> Bool {
        return screenID(for: windowID) != nil
    }
}

/**
 Applies every frame assignment of a reflow together over a fixed duration.

 Regular reflows enqueue one `FrameAssignmentOperation` per window on a serial queue. Wrapping them all in a single operation lets every window move at the same time, keeps the completion operation's dependency structure intact, and makes cancellation via `cancelAllOperations()` take effect between steps.

 Two strategies are available, chosen per reflow:

 **Snapshot** (preferred, needs Screen Recording permission and the private SkyLight capture): an image of each window is captured and shown in an overlay exactly where the window is; the real window is parked off-screen, given its final size there (the one expensive relayout happens out of sight), and the images slide to their targets with Core Animation. Then the real windows are placed at their targets and the images fade out. The user only ever sees the compositor moving pixels, so the motion is smooth regardless of how slow the applications are.

 **Accessibility** (fallback): windows are resized in place, then their positions glide through repeated Accessibility writes, handed to a writer per application. Moving a window is cheap for the application; resizing is not, which is why the resize happens once up front.

 In both cases the final frame goes through the normal `FrameAssignment.perform(withWindow:)`, so the end state is identical to a non-animated reflow.
 */
final class AnimatedReflowOperation<Window: WindowType>: Operation, @unchecked Sendable {
    private struct Participant {
        let assignment: FrameAssignment<Window>
        let window: Window
        let pid: pid_t
        let start: CGRect
        /// Where the window's picture starts: where a cancelled animation last showed it, if that was a moment ago, else its real frame.
        let visualStart: CGRect
        /// Where the window should end up. Corrected mid-animation if the application refuses the assigned size.
        var target: CGRect
        let resizable: Bool
        var lastIssued: CGRect
        /// Pixels per point of the window's first capture, for validating later captures.
        var pixelsPerPoint: CGFloat = 1

        /// Whether the window's size has to change to reach its target.
        var needsResize: Bool {
            return resizable && start.size != target.size
        }

        /// The frame this window should show at `progress` of the accessibility glide: interpolated position, already-final size, kept on screen if focused.
        func frame(at progress: CGFloat) -> CGRect {
            let interpolated = FrameInterpolation.interpolate(from: start, to: target, progress: progress)
            return assignment.keepingFocusedWindowOnScreen(CGRect(origin: interpolated.origin, size: lastIssued.size))
        }
    }

    private typealias Writes = [pid_t: [Int: ApplicationFrameWriter<Window>.Write]]

    private struct SnapshotTimings {
        var inPlace = false
        var captureDuration: TimeInterval = 0
        var parkDuration: TimeInterval = 0
        var placeDuration: TimeInterval = 0
        var corrected = 0
        var recaptured = 0
        /// When, relative to the start of the glide, the first application finished re-laying out and its proxy could be refined.
        var firstRefinement: TimeInterval?
        /// Resized windows whose proxy never received a fresh image; they get a slow dissolve at the handoff instead.
        var unrefreshed: [Int] = []
    }

    private enum SnapshotOutcome {
        case completed(animator: SnapshotAnimating, timings: SnapshotTimings)
        case cancelled
        case unavailable(reason: String)
    }

    /// How long the proxies take to fade once the real windows are back in place.
    private static var handoffFadeDuration: TimeInterval { return 0.08 }

    /// How long a proxy that never received a fresh image takes to dissolve into the real window at the handoff.
    private static var lingeringFadeDuration: TimeInterval { return 0.25 }

    private let frameAssignments: [FrameAssignment<Window>]
    private let windowSet: WindowSet<Window>?
    private let duration: TimeInterval
    private let frameInterval: TimeInterval
    private let writesInline: Bool
    private let writerDrainTimeout: TimeInterval
    private let captureImages: (([WindowCaptureRequest]) -> [CGImage]?)?
    private let captureIsVerifiable: (WindowCaptureRequest) -> Bool
    private let captureBackdrop: ((CGRect, [CGWindowID]) -> CGImage?)?
    private let makeSnapshotAnimator: (() -> SnapshotAnimating)?
    private let parkingOrigin: () -> CGPoint
    private let screenID: String?
    private let now: () -> TimeInterval
    private let sleep: (TimeInterval) -> Void

    private let writerGroup = DispatchGroup()
    private var writers: [pid_t: ApplicationFrameWriter<Window>] = [:]

    /// Participants whose size is being changed by the current snapshot animation; only these need a fresh capture.
    private var resizedIndexSet: Set<Int> = []

    /// Whether the current snapshot animation keeps the real windows on screen behind a backdrop rather than parking them.
    private var refinesInPlace = false

    /// Number of accessibility glide ticks performed. Exposed for tests.
    private(set) var tickCount = 0

    /**
     - Parameters:
         - frameAssignmentOperations: The per-window operations a layout produced. Their assignments are animated together and their shared window set resolves live windows.
         - duration: Total glide time in seconds. Capture and the up-front resize are not counted against it.
         - frameInterval: Target time between accessibility glide ticks, and the pause that lets the overlay draw before windows are parked.
         - writesInline: Apply writes synchronously on the operation's thread instead of on per-application queues. For tests.
         - captureImages: Captures full images of the given windows; `nil` disables the snapshot strategy.
         - captureIsVerifiable: Whether a fresh capture of the window would reveal a not-yet-redrawn surface by its size. Windows whose captures cannot be verified are not dissolved mid-glide; their proxies linger at the handoff instead.
         - captureBackdrop: Captures a screen without the given windows. With it, real windows are re-laid out in place behind the backdrop and their proxies cross-dissolve to fresh captures; without it they are parked off-screen.
         - makeSnapshotAnimator: Creates the overlay that shows and slides the snapshots; `nil` disables the snapshot strategy.
         - parkingOrigin: A point beyond every display where real windows are hidden during a snapshot animation.
         - screenID: The screen this reflow belongs to; its windows are registered as in flight so other screens leave them alone.
         - now: Monotonic clock, injectable for tests.
         - sleep: Blocking sleep, injectable for tests.
         - writerDrainTimeout: How long to wait for slow applications to apply their last frame before moving on.
     */
    init(
        frameAssignmentOperations: [FrameAssignmentOperation<Window>],
        duration: TimeInterval,
        frameInterval: TimeInterval = 1.0 / 60.0,
        writesInline: Bool = false,
        writerDrainTimeout: TimeInterval = defaultWriterDrainTimeout,
        captureImages: (([WindowCaptureRequest]) -> [CGImage]?)? = nil,
        captureIsVerifiable: @escaping (WindowCaptureRequest) -> Bool = { _ in true },
        captureBackdrop: ((CGRect, [CGWindowID]) -> CGImage?)? = nil,
        makeSnapshotAnimator: (() -> SnapshotAnimating)? = nil,
        parkingOrigin: @escaping () -> CGPoint = AnimatedReflowOperation.defaultParkingOrigin,
        screenID: String? = nil,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        sleep: @escaping (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }
    ) {
        self.frameAssignments = frameAssignmentOperations.map { $0.frameAssignment }
        self.windowSet = frameAssignmentOperations.first?.windowSet
        self.duration = duration
        self.frameInterval = frameInterval
        self.writesInline = writesInline
        self.writerDrainTimeout = writerDrainTimeout
        self.captureImages = captureImages
        self.captureIsVerifiable = captureIsVerifiable
        self.captureBackdrop = captureBackdrop
        self.makeSnapshotAnimator = makeSnapshotAnimator
        self.parkingOrigin = parkingOrigin
        self.screenID = screenID
        self.now = now
        self.sleep = sleep
        super.init()
    }

    // MARK: - Parking

    /// A point to the right of every active display, in the flipped coordinates Accessibility uses.
    static func defaultParkingOrigin() -> CGPoint {
        return parkingOrigin(forDisplayBounds: ActiveDisplays.bounds())
    }

    static func parkingOrigin(forDisplayBounds bounds: [CGRect]) -> CGPoint {
        let union = bounds.reduce(CGRect.null) { $0.union($1) }
        return CGPoint(x: (union.isNull ? 0 : union.maxX) + 200, y: 0)
    }

    // MARK: - Operation

    override func main() {
        guard !isCancelled, let windowSet = windowSet else {
            return
        }

        var participants = prepareParticipants(in: windowSet)
        let windowIDs = participants.map { $0.window.cgID() }
        if let screenID = screenID {
            let targets = Dictionary(participants.map { ($0.window.cgID(), $0.target) }, uniquingKeysWith: { first, _ in first })
            AnimatingWindows.shared.claim(windowIDs, for: screenID, targets: targets)
        }

        var snapshotAnimator: SnapshotAnimating?
        var lingeringProxies: [Int] = []
        var overlayHandedOff = false

        defer {
            // The overlay never outlives the operation. On a cancellation after the glide the real windows are already in
            // place, so the panel comes down at once; only the normal path fades it out.
            if let animator = snapshotAnimator, !overlayHandedOff {
                runOnMainSync { animator.cancel() }
            }
            if let screenID = screenID {
                AnimatingWindows.shared.release(windowIDs, for: screenID)
            }
            participants.forEach { $0.window.endAnimatedMovement() }
        }

        if !participants.isEmpty {
            switch attemptSnapshotAnimation(&participants) {
            case let .completed(animator, timings):
                snapshotAnimator = animator
                lingeringProxies = timings.unrefreshed
                logSnapshotTiming(windowCount: participants.count, timings: timings)
            case .cancelled:
                return
            case let .unavailable(reason):
                logAnimation("Animated reflow: snapshot animation unavailable (\(reason)); moving the real windows instead")

                let resizeStart = now()
                resizeInPlace(&participants)
                let resizeDuration = now() - resizeStart

                // A cancel now, with every window resized but still at its old position, must leave the windows at their
                // tiles just as a cancel mid-glide does: the reflow that cancelled may not move them.
                guard !isCancelled else {
                    abandonPendingWrites(&participants)
                    return
                }
                guard animate(&participants, resizeDuration: resizeDuration) else {
                    return
                }
            }
        }

        // The same holds for a cancel that arrived while waiting for a slow application after the glide.
        guard !isCancelled else {
            abandonPendingWrites(&participants)
            return
        }

        // Nothing the writers still hold may land after the settle: drop what is queued, and wait for what is in flight.
        writers.values.forEach { $0.discardPending() }
        waitForWriters()

        // Settle: apply the exact final frames through the regular path, including focused-window peeking, except for windows
        // Amethyst has since moved elsewhere. Only participants were claimed, so a window that never took part, because its
        // frame could not be read, is settled just as a non-animated reflow would settle it.
        let claimedWindowIDs = Set(windowIDs)
        for frameAssignment in frameAssignments {
            guard let window = windowSet.window(for: frameAssignment), owns(window) || !claimedWindowIDs.contains(window.cgID()) else {
                continue
            }
            windowSet.perform(frameAssignment: frameAssignment)
        }

        // Only now hand the picture back to the real windows.
        if let animator = snapshotAnimator {
            runOnMainSync {
                animator.finish(
                    fadeDuration: AnimatedReflowOperation.handoffFadeDuration,
                    lingering: lingeringProxies,
                    lingerDuration: AnimatedReflowOperation.lingeringFadeDuration
                ) {}
            }
            overlayHandedOff = true
            logFinalFrameMismatches(participants)
        }
    }

    /// Reports any window whose settled frame differs from where its proxy landed; a non-empty list means the handoff shows a jump.
    private func logFinalFrameMismatches(_ participants: [Participant]) {
        let mismatches = participants.compactMap { participant -> String? in
            guard let actual = FrameInterpolation.readable(participant.window.frame()), actual != participant.target else {
                return nil
            }
            return "pid \(participant.pid) proxy \(Int(participant.target.minX)),\(Int(participant.target.minY)) \(Int(participant.target.width))x\(Int(participant.target.height))"
                + " window \(Int(actual.minX)),\(Int(actual.minY)) \(Int(actual.width))x\(Int(actual.height))"
        }

        guard !mismatches.isEmpty else {
            return
        }

        logAnimation("Animated reflow: proxy/window mismatch after settle: \(mismatches.joined(separator: "; "))")
    }

    /// Resolves live windows and captures start frames in a single main-thread hop.
    private func prepareParticipants(in windowSet: WindowSet<Window>) -> [Participant] {
        var participants: [Participant] = []

        runOnMainSync {
            guard !isCancelled else {
                return
            }

            for assignment in frameAssignments {
                guard let window = windowSet.window(for: assignment) else {
                    continue
                }

                // A window whose frame cannot be read is left to the settle pass, exactly as a non-animated reflow treats it.
                guard let start = FrameInterpolation.readable(window.frame()), let assigned = FrameInterpolation.readable(assignment.finalFrame) else {
                    continue
                }

                // A window that cannot be resized will only ever be moved, so its picture is aimed at the tile's position with
                // the window's own size, where the settle pass will actually leave it.
                let resizable = window.isResizable()
                let target = resizable
                    ? assigned
                    : FrameInterpolation.integral(assignment.keepingFocusedWindowOnScreen(CGRect(origin: assigned.origin, size: start.size)))

                guard start != target else {
                    continue
                }

                window.beginAnimatedMovement()
                participants.append(Participant(
                    assignment: assignment,
                    window: window,
                    pid: window.pid(),
                    start: start,
                    visualStart: AnimatingWindows.shared.takeLastSeenFrame(for: window.cgID(), at: now()) ?? start,
                    target: target,
                    resizable: resizable,
                    lastIssued: start
                ))
            }
        }

        return participants
    }

    // MARK: - Snapshot strategy

    private func attemptSnapshotAnimation(_ participants: inout [Participant]) -> SnapshotOutcome {
        guard let captureImages = captureImages, let makeSnapshotAnimator = makeSnapshotAnimator else {
            return .unavailable(reason: "disabled")
        }

        let windowIDs = participants.map { $0.window.cgID() }
        let requests = participants.map { WindowCaptureRequest(windowID: $0.window.cgID(), frame: $0.start) }
        let screenFrame = participants[0].assignment.screenFrame
        var timings = SnapshotTimings()

        // Window images and the backdrop are independent round trips; take them at the same time.
        let captureStart = now()
        var images: [CGImage]?
        var backdrop: CGImage?
        let captureBackdrop = self.captureBackdrop
        DispatchQueue.concurrentPerform(iterations: captureBackdrop == nil ? 1 : 2) { task in
            if task == 0 {
                images = captureImages(requests)
            } else {
                backdrop = captureBackdrop?(screenFrame, windowIDs)
            }
        }
        timings.captureDuration = now() - captureStart

        guard let images = images, images.count == participants.count else {
            return .unavailable(reason: "window capture failed")
        }
        timings.inPlace = backdrop != nil

        for (index, image) in images.enumerated() where participants[index].start.width > 0 {
            participants[index].pixelsPerPoint = CGFloat(image.width) / participants[index].start.width
        }

        let proxies = zip(participants, images).map { participant, image in
            SnapshotProxy(image: image, start: participant.visualStart, target: participant.target)
        }

        var animator: SnapshotAnimating?
        runOnMainSync {
            let created = makeSnapshotAnimator()
            created.show(proxies: proxies, screenFrame: screenFrame, backdrop: backdrop)
            animator = created
        }

        guard let animator = animator else {
            return .unavailable(reason: "overlay unavailable")
        }

        // Give the compositor one frame to draw the overlay over the real windows before those move.
        sleep(frameInterval)

        let resizedIndices = hideRealWindows(&participants, inPlace: timings.inPlace, timings: &timings)
        resizedIndexSet = Set(resizedIndices)
        refinesInPlace = timings.inPlace

        guard !isCancelled else {
            return abandonSnapshotAnimation(animator, &participants)
        }

        let finished = DispatchSemaphore(value: 0)
        runOnMainSync {
            animator.animate(duration: duration) {
                finished.signal()
            }
        }

        guard glide(&participants, animator: animator, finished: finished, timings: &timings) else {
            return abandonSnapshotAnimation(animator, &participants)
        }

        timings.placeDuration = placeRealWindows(&participants)
        return .completed(animator: animator, timings: timings)
    }

    /**
     Waits for the proxies' motion to end while refining them, checking for cancellation every frame and never waiting forever.

     As each application applies its new frame, its proxies are steered to the frame it accepted. Behind a backdrop the resized
     windows are then captured again, once they have had time to redraw, and their proxies dissolve into the fresh image. A
     capture whose surface does not yet match the accepted size is retried, since many applications redraw well after the
     accessibility call returns.

     - Returns: `false` if the operation was cancelled.
     */
    private func glide(_ participants: inout [Participant], animator: SnapshotAnimating, finished: DispatchSemaphore, timings: inout SnapshotTimings) -> Bool {
        let glideStart = now()
        var pendingSteer = refinesInPlace ? Set(participants.indices) : resizedIndexSet
        var pendingRecapture: [Int: TimeInterval] = [:]
        var retiredProxies = Set<Int>()
        var refinements: [DispatchSemaphore] = []
        var stalled = false
        var remainingWaits = Int(((duration + 1.0) / frameInterval).rounded(.up))

        while finished.wait(timeout: .now()) == .timedOut {
            // Pace the checks with the injectable sleep so the injected clock advances in tests.
            sleep(frameInterval)
            remainingWaits -= 1
            if isCancelled {
                return false
            }

            // The render server pauses animations, and their completions, while a display sleeps or the main thread stalls.
            // That is not a cancellation: the motion is over as far as anyone can see, so carry on to the exact placement.
            if remainingWaits <= 0 {
                logAnimation("Animated reflow: the glide never reported completion; settling anyway")
                stalled = true
                break
            }

            // A window thrown to another screen or Space mid-glide is no longer ours: stop refining it and hide its proxy.
            let retired = retireHandedOffProxies(participants, alreadyRetired: &retiredProxies, animator: animator)
            pendingSteer.subtract(retired)
            for index in retired {
                pendingRecapture[index] = nil
            }

            let current = now()
            let elapsed = current - glideStart

            let steerable = pendingSteer.filter { writer(for: participants[$0].pid).isIdle }
            if !steerable.isEmpty {
                pendingSteer.subtract(steerable)
                if timings.firstRefinement == nil {
                    timings.firstRefinement = elapsed
                }
                timings.corrected += steerToAcceptedFrames(animator, &participants, indices: steerable.sorted(), duration: max(duration - elapsed, 0.05), completion: nil)
                for index in steerable where refinesInPlace && resizedIndexSet.contains(index) {
                    pendingRecapture[index] = current + redrawSettleDelay
                }
            }

            let due = pendingRecapture.filter { $0.value <= current }.map { $0.key }
            if !due.isEmpty {
                let remaining = max(duration - elapsed, minimumDissolveDuration)
                let (dissolveDone, dissolved, unverifiable) = dissolveToFreshCaptures(animator, participants, indices: due.sorted(), duration: remaining, isFinalAttempt: false)
                refinements.append(contentsOf: [dissolveDone].compactMap { $0 })
                timings.recaptured += dissolved.count
                timings.unrefreshed = Array(Set(timings.unrefreshed).union(unverifiable)).sorted()
                for index in due {
                    pendingRecapture[index] = dissolved.contains(index) || unverifiable.contains(index) ? nil : current + redrawSettleDelay
                }
            }
        }

        // Nothing on screen moves again until the render server resumes, so late corrections and dissolves could neither be
        // seen nor report back; none are requested.
        guard !stalled else {
            return true
        }

        refinements += finishRefinement(&participants, animator: animator, pendingSteer: pendingSteer, pendingRecapture: Set(pendingRecapture.keys), timings: &timings)

        for refinement in refinements {
            _ = refinement.wait(timeout: .now() + minimumDissolveDuration + 0.5)
        }
        return true
    }

    /// Gives whatever the glide left unrefined one last, short correction before the handoff. Returns the animations to wait for.
    private func finishRefinement(
        _ participants: inout [Participant],
        animator: SnapshotAnimating,
        pendingSteer: Set<Int>,
        pendingRecapture: Set<Int>,
        timings: inout SnapshotTimings
    ) -> [DispatchSemaphore] {
        var refinements: [DispatchSemaphore] = []
        var recapture = pendingRecapture

        if !pendingSteer.isEmpty {
            waitForWriters(timeout: 0.2)
            // As during the glide, only a window whose application has applied its frame can be read back truthfully; one still
            // waiting on its application would report its old frame and be steered back to where it started. Those are left
            // to placement and the settle.
            let steerable = pendingSteer.filter { writer(for: participants[$0].pid).isIdle }
            if !steerable.isEmpty {
                // The wait below is bounded; a semaphore that was never signalled is simply dropped afterwards.
                let correctionDone = DispatchSemaphore(value: 0)
                let corrected = steerToAcceptedFrames(animator, &participants, indices: steerable.sorted(), duration: lateCorrectionDuration) { correctionDone.signal() }
                timings.corrected += corrected
                if corrected == 0 {
                    correctionDone.signal()
                }
                refinements.append(correctionDone)
                recapture.formUnion(steerable.filter { refinesInPlace && resizedIndexSet.contains($0) })
            }
        }

        guard !recapture.isEmpty else {
            return refinements
        }

        // Slow renderers get one more moment before the final attempt; whatever still has not redrawn lingers at the handoff.
        sleep(redrawSettleDelay)
        let (dissolveDone, dissolved, _) = dissolveToFreshCaptures(animator, participants, indices: recapture.sorted(), duration: minimumDissolveDuration, isFinalAttempt: true)
        refinements.append(contentsOf: [dissolveDone].compactMap { $0 })
        timings.recaptured += dissolved.count
        timings.unrefreshed = Array(Set(timings.unrefreshed).union(recapture.subtracting(dissolved))).sorted()
        return refinements
    }

    /**
     Gets the real windows out of sight and gives them their final size: at their destinations behind the backdrop, or parked beyond the displays.

     - Returns: The indices of windows whose size changes.
     */
    private func hideRealWindows(_ participants: inout [Participant], inPlace: Bool, timings: inout SnapshotTimings) -> [Int] {
        let resizedIndices = participants.indices.filter { participants[$0].needsResize }

        if inPlace {
            issue(&participants) { participant in
                let size = participant.needsResize ? participant.target.size : participant.lastIssued.size
                return (CGRect(origin: participant.target.origin, size: size), participant.needsResize)
            }
            return resizedIndices
        }

        // Park at the current size first so every window vanishes together, then take the final size out of sight.
        let parking = parkingOrigin()
        issue(&participants) { participant in
            (CGRect(origin: CGPoint(x: parking.x, y: participant.start.minY), size: participant.start.size), false)
        }
        let parkStart = now()
        waitForWriters(timeout: 0.1)
        timings.parkDuration = now() - parkStart

        issue(&participants) { participant in
            participant.needsResize ? (CGRect(origin: participant.lastIssued.origin, size: participant.target.size), true) : nil
        }
        return resizedIndices
    }

    /// Brings the real windows to their targets; only the position changes now. Windows re-laid out in place are already there unless their target was corrected.
    private func placeRealWindows(_ participants: inout [Participant]) -> TimeInterval {
        issueTargetPositions(&participants)

        let start = now()
        waitForWriters(timeout: 0.2)
        return now() - start
    }

    /**
     Reads back the frame each window actually took and, for any that differ from the assigned frame, corrects the participant's
     target and steers its proxy there. Applications with minimum or fixed sizes, or ones that refuse to sit under the menu bar,
     would otherwise pop at the handoff.

     Behind a backdrop the window is already at its destination, so its whole frame is authoritative. A parked window's position
     means nothing, so only its size is taken, and the focused window's origin is clamped the way the settle pass will clamp it.

     - Returns: How many proxies were corrected. `completion` is forwarded to the animator only when at least one was.
     */
    private func steerToAcceptedFrames(
        _ animator: SnapshotAnimating,
        _ participants: inout [Participant],
        indices: [Int],
        duration: TimeInterval,
        completion: (() -> Void)?
    ) -> Int {
        var acceptedFrames = [Int: CGRect]()
        let lock = NSLock()
        let windows = indices.map { participants[$0].window }

        DispatchQueue.concurrentPerform(iterations: windows.count) { position in
            // A window whose frame cannot be read keeps the target it has.
            guard let frame = FrameInterpolation.readable(windows[position].frame()) else {
                return
            }
            lock.lock()
            acceptedFrames[indices[position]] = frame
            lock.unlock()
        }

        var corrections = [CGRect?](repeating: nil, count: participants.count)
        for index in indices {
            guard let accepted = acceptedFrames[index] else {
                continue
            }

            // Where the settle pass will leave the window: its accepted frame, kept on screen if it is the focused window.
            let assignment = participants[index].assignment
            let corrected = assignment.keepingFocusedWindowOnScreen(
                refinesInPlace ? accepted : CGRect(origin: participants[index].target.origin, size: accepted.size)
            )

            guard corrected != participants[index].target else {
                continue
            }

            participants[index].target = corrected
            corrections[index] = corrected
        }

        let count = corrections.compactMap { $0 }.count
        guard count > 0 else {
            return 0
        }

        runOnMainSync {
            animator.retarget(frames: corrections, duration: duration, completion: completion)
        }
        return count
    }

    /**
     Captures the given windows again, now that they show their real final rendering, and dissolves their proxies into those images.

     Only an image whose pixel size matches the size the application accepted is used; a window whose application has not
     finished redrawing keeps its old image and is reported back so the caller can try again.

     - Returns: A semaphore signalled when the dissolve has finished, or `nil` if nothing was dissolved; the indices that received
       a fresh image; and the indices whose captures cannot be verified and so are never dissolved mid-glide.
     */
    private func dissolveToFreshCaptures(
        _ animator: SnapshotAnimating,
        _ participants: [Participant],
        indices: [Int],
        duration: TimeInterval,
        isFinalAttempt: Bool
    ) -> (DispatchSemaphore?, Set<Int>, Set<Int>) {
        // A capture that cannot reveal a stale surface could dissolve the proxy into old content; such windows blend into the
        // real window at the handoff instead.
        let allRequests = indices.map { WindowCaptureRequest(windowID: participants[$0].window.cgID(), frame: participants[$0].target) }
        let unverifiable = Set(zip(indices, allRequests).filter { !captureIsVerifiable($0.1) }.map { $0.0 })
        let indices = indices.filter { !unverifiable.contains($0) }
        let requests = allRequests.filter { captureIsVerifiable($0) }

        guard !indices.isEmpty else {
            return (nil, [], unverifiable)
        }

        guard let captureImages = captureImages, let fresh = captureImages(requests), fresh.count == indices.count else {
            if isFinalAttempt {
                let pids = indices.map { String(participants[$0].pid) }.joined(separator: ", ")
                logAnimation("Animated reflow: recapture failed for pids \(pids)")
            }
            return (nil, [], unverifiable)
        }

        var images = [CGImage?](repeating: nil, count: participants.count)
        var dissolved = Set<Int>()
        var stale: [String] = []
        for (position, index) in indices.enumerated() {
            let participant = participants[index]
            let image = fresh[position]
            let expectedWidth = participant.target.width * participant.pixelsPerPoint
            let expectedHeight = participant.target.height * participant.pixelsPerPoint

            // A few pixels either way is a border or rounding difference, not a stale surface.
            let tolerance = max(4, 0.005 * max(expectedWidth, expectedHeight))
            guard abs(CGFloat(image.width) - expectedWidth) <= tolerance, abs(CGFloat(image.height) - expectedHeight) <= tolerance else {
                stale.append("pid \(participant.pid) got \(image.width)x\(image.height) expected \(Int(expectedWidth))x\(Int(expectedHeight))")
                continue
            }

            images[index] = image
            dissolved.insert(index)
        }

        if isFinalAttempt, !stale.isEmpty {
            logAnimation("Animated reflow: window still not redrawn at handoff, keeping old image: \(stale.joined(separator: "; "))")
        }

        guard !dissolved.isEmpty else {
            return (nil, [], unverifiable)
        }

        let dissolveDone = DispatchSemaphore(value: 0)
        runOnMainSync {
            animator.crossfade(images: images, duration: duration) {
                dissolveDone.signal()
            }
        }
        return (dissolveDone, dissolved, unverifiable)
    }

    /**
     Leaves every real window at a valid tile, remembers where its proxy was last seen so a follow-up animation can start there,
     and removes the overlay.

     The reflow that cancelled this operation may return without doing anything, for instance when tiling was just turned off,
     so the windows must not be left at mid-animation positions. Windows re-laid out in place are already at their tiles.
     */
    private func abandonSnapshotAnimation(_ animator: SnapshotAnimating, _ participants: inout [Participant]) -> SnapshotOutcome {
        var currentFrames: [CGRect] = []
        runOnMainSync {
            currentFrames = animator.presentationFrames()
        }

        // Only windows still ours: a window thrown elsewhere mid-glide had its picture hidden where it was, and the screen
        // that adopted it must not start that picture from a stale spot on this one.
        var lastSeen: [CGWindowID: CGRect] = [:]
        for index in participants.indices where index < currentFrames.count && owns(participants[index].window) {
            if let frame = FrameInterpolation.readable(currentFrames[index]) {
                lastSeen[participants[index].window.cgID()] = frame
            }
        }
        AnimatingWindows.shared.recordLastSeenFrames(lastSeen, at: now())

        writers.values.forEach { $0.discardPending() }
        placeAtTargets(&participants)

        runOnMainSync {
            animator.cancel()
        }

        return .cancelled
    }

    /// Puts every window at its target's position, keeping whatever size it has; skips windows already there.
    private func placeAtTargets(_ participants: inout [Participant]) {
        issueTargetPositions(&participants)
        waitForWriters(timeout: 0.3)
    }

    /// Moves every window whose position is not yet its target's; sizes stay whatever was last issued.
    private func issueTargetPositions(_ participants: inout [Participant]) {
        issue(&participants) { participant in
            let frame = CGRect(origin: participant.target.origin, size: participant.lastIssued.size)
            return frame == participant.lastIssued ? nil : (frame, false)
        }
    }

    // MARK: - Accessibility strategy

    /// Phase one: give every window its final size at its current position, so the glide only has to move it. Waits for every application so all windows start gliding together.
    private func resizeInPlace(_ participants: inout [Participant]) {
        issue(&participants) { participant in
            participant.needsResize ? (CGRect(origin: participant.start.origin, size: participant.target.size), true) : nil
        }
        waitForWriters()
        writers.values.forEach { $0.resetStatistics() }

        // Applications may keep a different size than assigned; the glide must clamp and land with the size they kept. A
        // window whose application has not applied the resize yet still reports its old size, so the size asked for
        // stays in force until the resize lands.
        for index in participants.indices where participants[index].resizable && writer(for: participants[index].pid).isIdle {
            guard let accepted = FrameInterpolation.readable(participants[index].window.frame()) else {
                continue
            }
            participants[index].lastIssued.size = accepted.size
            participants[index].target.size = accepted.size
        }
    }

    /// Phase two: drive the positions. Returns `false` if the operation was cancelled before the glide finished.
    private func animate(_ participants: inout [Participant], resizeDuration: TimeInterval) -> Bool {
        let animationStart = now()

        while true {
            let tickStart = now()
            let elapsed = tickStart - animationStart

            guard elapsed < duration else {
                break
            }

            guard !isCancelled else {
                abandonPendingWrites(&participants)
                return false
            }

            let progress = FrameInterpolation.easeInOutSine(CGFloat(elapsed / duration))
            issue(&participants) { participant in
                let frame = participant.frame(at: progress)
                return frame == participant.lastIssued ? nil : (frame, false)
            }
            tickCount += 1

            let nextTick = tickStart + frameInterval
            let tickEnd = now()
            if nextTick > tickEnd {
                sleep(nextTick - tickEnd)
            }

            if isCancelled {
                abandonPendingWrites(&participants)
                return false
            }
        }

        let drained = waitForWriters()
        logAccessibilityTiming(resizeDuration: resizeDuration, drained: drained)
        return true
    }

    /// Drops frames not yet applied and leaves every window at its tile, since the reflow that cancelled this glide may not move it.
    private func abandonPendingWrites(_ participants: inout [Participant]) {
        writers.values.forEach { $0.discardPending() }
        waitForWriters()
        placeAtTargets(&participants)
    }

    // MARK: - Ownership

    /**
     Whether this operation may still move the window.

     A window Amethyst has since relocated to another screen or Space, or that another screen's animation has claimed, was handed off: writing its old tile back would undo the move. Operations without a screen have no claims and own everything.
     */
    private func owns(_ window: Window) -> Bool {
        guard let screenID = screenID else {
            return true
        }
        return AnimatingWindows.shared.screenID(for: window.cgID()) == screenID
    }

    /// Finds participants handed off since the last check and hides their proxies so they do not glide on as ghosts.
    private func retireHandedOffProxies(_ participants: [Participant], alreadyRetired: inout Set<Int>, animator: SnapshotAnimating) -> Set<Int> {
        let retired = Set(participants.indices.filter { !alreadyRetired.contains($0) && !owns(participants[$0].window) })
        guard !retired.isEmpty else {
            return []
        }
        alreadyRetired.formUnion(retired)
        runOnMainSync {
            animator.hide(indices: retired.sorted())
        }
        return retired
    }

    // MARK: - Writers

    /**
     Sends every window the frame `frame` chooses for it, batched per application, and records it as the window's last issued frame.

     - Parameter frame: The frame to issue and whether it includes the size, or `nil` to leave the window alone.
     - Returns: The indices of the windows that were sent a frame.
     */
    @discardableResult
    private func issue(_ participants: inout [Participant], frame: (Participant) -> (frame: CGRect, includingSize: Bool)?) -> [Int] {
        var writes: Writes = [:]
        var issued: [Int] = []

        for index in participants.indices {
            guard let write = frame(participants[index]) else {
                continue
            }

            writes[participants[index].pid, default: [:]][index] = .init(window: participants[index].window, frame: write.frame, includingSize: write.includingSize)
            participants[index].lastIssued = write.frame
            issued.append(index)
        }

        dispatch(writes)
        return issued
    }

    /// Issues the writes, leaving out windows this operation no longer owns.
    private func dispatch(_ writes: Writes) {
        for (pid, applicationWrites) in writes {
            let owned = applicationWrites.filter { owns($0.value.window) }
            guard !owned.isEmpty else {
                continue
            }
            writer(for: pid).write(owned)
        }
    }

    private func writer(for pid: pid_t) -> ApplicationFrameWriter<Window> {
        if let writer = writers[pid] {
            return writer
        }

        let writer = ApplicationFrameWriter<Window>(
            pid: pid,
            group: writerGroup,
            inline: writesInline,
            now: now,
            beginWrite: { [weak self] window in self?.beginWrite(to: window) ?? false },
            endWrite: { [weak self] window in self?.endWrite(to: window) }
        )
        writers[pid] = writer
        return writer
    }

    /// Registers a frame about to land on the window, unless the window is no longer this operation's to move.
    private func beginWrite(to window: Window) -> Bool {
        guard let screenID = screenID else {
            return true
        }
        return AnimatingWindows.shared.beginWrite(window.cgID(), for: screenID)
    }

    private func endWrite(to window: Window) {
        guard screenID != nil else {
            return
        }
        AnimatingWindows.shared.endWrite(window.cgID())
    }

    /// Waits for every application to apply its newest frame. Returns `false` if a slow application timed out.
    @discardableResult
    private func waitForWriters(timeout: TimeInterval? = nil) -> Bool {
        let timeout = timeout ?? writerDrainTimeout
        return writerGroup.wait(timeout: .now() + timeout) == .success
    }

    // MARK: - Logging

    private func logSnapshotTiming(windowCount: Int, timings: SnapshotTimings) {
        let mode = timings.inPlace ? "in place" : "parked"
        let capture = Int(timings.captureDuration * 1000)
        let park = Int(timings.parkDuration * 1000)
        let place = Int(timings.placeDuration * 1000)
        let firstRefinement = Int((timings.firstRefinement ?? -0.001) * 1000)
        let glide = String(format: "%.2f", duration)
        logAnimation(
            "Animated reflow (snapshot, \(mode)): \(windowCount) windows, capture \(capture)ms, park \(park)ms, glide \(glide)s, place \(place)ms, "
                + "\(timings.corrected) size-corrected, \(timings.recaptured) recaptured, first refinement at \(firstRefinement)ms"
        )
    }

    private func logAccessibilityTiming(resizeDuration: TimeInterval, drained: Bool) {
        guard tickCount > 0 else {
            return
        }

        let framesPerSecond = Int((Double(tickCount) / duration).rounded())
        let resizeMilliseconds = Int(resizeDuration * 1000)
        let slowest = writers.values
            .map { (pid: $0.pid, statistics: $0.statisticsSnapshot()) }
            .max { $0.statistics.averageWriteTime < $1.statistics.averageWriteTime }
        let slowestPid = slowest?.pid ?? 0
        let slowestAverageMilliseconds = Int((slowest?.statistics.averageWriteTime ?? 0) * 1000)
        let slowestApplied = slowest?.statistics.applied ?? 0
        let slowestRequested = slowest?.statistics.requested ?? 0
        let timeoutNote = drained ? "" : "; timed out waiting for it"
        let glide = String(format: "%.2f", duration)

        logAnimation(
            "Animated reflow (accessibility): resize \(resizeMilliseconds)ms, then \(tickCount) ticks over \(glide)s (\(framesPerSecond) fps); "
                + "slowest app pid \(slowestPid) averaged \(slowestAverageMilliseconds)ms per write and showed \(slowestApplied) of \(slowestRequested) frames\(timeoutNote)"
        )
    }
}
