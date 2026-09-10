//
//  AnimatedReflowOperationTests.swift
//  AmethystTests
//
//  Created by Don Patterson on 9/8/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import CoreGraphics
import Nimble
import Quick
import XCTest
import Silica

class AnimatedReflowOperationTests: QuickSpec {
    /// A deterministic clock: every sleep advances time by exactly the requested amount.
    private final class FakeClock {
        private(set) var time: TimeInterval = 0
        private(set) var sleepCount = 0
        var onSleep: ((Int) -> Void)?

        func now() -> TimeInterval {
            return time
        }

        func sleep(_ interval: TimeInterval) {
            time += interval
            sleepCount += 1
            onSleep?(sleepCount)
        }
    }

    private struct Fixture {
        let windows: [TestWindow]
        let operations: [FrameAssignmentOperation<TestWindow>]

        /// The window a capture request is about, whichever windows the operation asks about and in whatever order.
        func window(for request: WindowCaptureRequest) -> TestWindow {
            return windows.first { $0.cgID() == request.windowID }!
        }
    }

    /// Records the overlay calls the operation makes and completes the glide immediately unless told otherwise.
    private final class FakeSnapshotAnimator: SnapshotAnimating {
        var shownProxies: [SnapshotProxy] = []
        var shownScreenFrame: CGRect?
        var animateDuration: TimeInterval?
        var completesImmediately = true
        /// Whether a mid-glide refinement stands in for the overlay reaching its target; `false` keeps the glide pending until `endGlide()` or a stall, as when a display is asleep.
        var endsGlideOnRefinement = true
        var onAnimate: (() -> Void)?
        /// Called after each dissolve, so a test can end the glide at a moment of its choosing.
        var onCrossfade: (() -> Void)?
        var framesToPresent: [CGRect] = []
        var finishCalled = false
        var lingering: [Int] = []
        var cancelCalled = false
        var retargetedFrames: [[CGRect?]] = []
        var retargetDurations: [TimeInterval] = []
        var shownBackdrop: CGImage?
        var hiddenIndices: [Int] = []
        var crossfadeImages: [[CGImage?]] = []
        var crossfadeDurations: [TimeInterval] = []
        /// Keeps late-correction completions instead of calling them, like an overlay whose animations never report back.
        var swallowsCorrectionCompletions = false
        private var swallowedCompletions: [() -> Void] = []
        private var pendingCompletion: (() -> Void)?

        func show(proxies: [SnapshotProxy], screenFrame: CGRect, backdrop: CGImage?) {
            shownProxies = proxies
            shownScreenFrame = screenFrame
            shownBackdrop = backdrop
        }

        /// Stands in for the real overlay reaching its target and ends the pending glide.
        func endGlide() {
            let pending = pendingCompletion
            pendingCompletion = nil
            pending?()
        }

        private func endPendingGlide() {
            endGlide()
        }

        func crossfade(images: [CGImage?], duration: TimeInterval, completion: (() -> Void)?) {
            crossfadeImages.append(images)
            crossfadeDurations.append(duration)
            completion?()
            if endsGlideOnRefinement {
                endPendingGlide()
            }
            onCrossfade?()
        }

        func animate(duration: TimeInterval, completion: @escaping () -> Void) {
            animateDuration = duration
            onAnimate?()
            if completesImmediately {
                completion()
            } else {
                pendingCompletion = completion
            }
        }

        /// A late correction completes at once; a mid-glide retarget ends the pending glide.
        func retarget(frames: [CGRect?], duration: TimeInterval, completion: (() -> Void)?) {
            retargetedFrames.append(frames)
            retargetDurations.append(duration)
            if let completion = completion {
                if swallowsCorrectionCompletions {
                    swallowedCompletions.append(completion)
                } else {
                    completion()
                }
            } else if endsGlideOnRefinement {
                endPendingGlide()
            }
        }

        func presentationFrames() -> [CGRect] {
            return framesToPresent
        }

        func finish(fadeDuration: TimeInterval, lingering: [Int], lingerDuration: TimeInterval, completion: @escaping () -> Void) {
            finishCalled = true
            self.lingering = lingering
            completion()
        }

        func hide(indices: [Int]) {
            hiddenIndices += indices
        }

        func cancel() {
            cancelCalled = true
        }
    }

    /// Runs `work` on the main thread and returns its result; the overlay's panel and animations live there.
    private func onMain<Value>(_ work: () -> Value) -> Value {
        var value: Value?
        runOnMainSync { value = work() }
        return value!
    }

    /// Gives the main thread time to deliver its queued work and animation completions, without occupying it, until `done` holds or `attempts` run out.
    private func letMainThreadRun(attempts: Int, until done: () -> Bool) {
        for _ in 0..<attempts where !done() {
            if Thread.isMainThread {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            } else {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }

    /// The primary screen's frame in the flipped coordinates the overlay takes, or a skip: the overlay needs a display to put its panel on.
    private func primaryScreenFrameOrSkip() throws -> CGRect {
        guard let screen = NSScreen.screens.first else {
            throw XCTSkip("needs an attached display")
        }
        return FlippedCoordinates.flippedRect(fromAppKit: screen.frame, primaryScreenHeight: FlippedCoordinates.primaryScreenHeight)
    }

    private static func makeImage(width: Int = 1, height: Int = 1) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    private let parkingOrigin = CGPoint(x: 5000, y: 0)

    private func makeSnapshotOperation(
        _ fixture: Fixture,
        clock: FakeClock,
        animator: FakeSnapshotAnimator,
        capture: @escaping ([WindowCaptureRequest]) -> [CGImage]?,
        backdrop: ((CGRect, [CGWindowID]) -> CGImage?)? = nil,
        screenID: String? = nil,
        writesInline: Bool = true,
        verifiable: @escaping (WindowCaptureRequest) -> Bool = { _ in true }
    ) -> AnimatedReflowOperation<TestWindow> {
        return AnimatedReflowOperation(
            frameAssignmentOperations: fixture.operations,
            duration: duration,
            frameInterval: frameInterval,
            writesInline: writesInline,
            captureImages: capture,
            captureIsVerifiable: verifiable,
            captureBackdrop: backdrop,
            makeSnapshotAnimator: { animator },
            parkingOrigin: { self.parkingOrigin },
            screenID: screenID,
            now: clock.now,
            sleep: clock.sleep
        )
    }

    // Exactly representable in binary so the tick count is deterministic: 8 ticks at 0, 1/32 ... 7/32.
    private let duration: TimeInterval = 0.25
    private let frameInterval: TimeInterval = 1.0 / 32.0
    private let expectedTicks = 8

    private func makeFixture(startFrames: [CGRect], targetFrames: [CGRect], focusedIndex: Int? = nil) -> Fixture {
        let screenFrame = CGRect(x: 0, y: 0, width: 2000, height: 1000)
        let windows: [TestWindow] = startFrames.enumerated().map { index, frame in
            let window = TestWindow(element: nil)!
            window.setFrame(frame, withThreshold: .zero)
            window.isFocusedValue = index == focusedIndex
            window.clearFrameHistory()
            return window
        }
        let layoutWindows = windows.map {
            LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: $0.isFocused())
        }
        let windowSet = WindowSet<TestWindow>(
            windows: layoutWindows,
            isWindowWithIDActive: { _ in return true },
            isWindowWithIDFloating: { _ in return false },
            windowForID: { id in return windows.first { $0.id() == id } }
        )
        let resizeRules = ResizeRules(isMain: true, unconstrainedDimension: .horizontal, scaleFactor: 1)
        // A blank configuration: the frames these tests assert on must not pick up the margins or minimum sizes set in the
        // preferences of whoever runs them.
        let configuration = UserConfiguration(storage: TestConfigurationStorage())
        let operations = zip(layoutWindows, targetFrames).map { layoutWindow, target in
            FrameAssignmentOperation(
                frameAssignment: FrameAssignment(frame: target, window: layoutWindow, screenFrame: screenFrame, resizeRules: resizeRules, configuration: configuration),
                windowSet: windowSet
            )
        }
        return Fixture(windows: windows, operations: operations)
    }

    private func makeOperation(_ fixture: Fixture, clock: FakeClock, writesInline: Bool = true, drainTimeout: TimeInterval = 1.0) -> AnimatedReflowOperation<TestWindow> {
        return AnimatedReflowOperation(
            frameAssignmentOperations: fixture.operations,
            duration: duration,
            frameInterval: frameInterval,
            writesInline: writesInline,
            writerDrainTimeout: drainTimeout,
            now: clock.now,
            sleep: clock.sleep
        )
    }

    /// Whether `values` never reverses direction on its way from the first element to the last.
    private func isMonotonic(_ values: [CGFloat]) -> Bool {
        guard let first = values.first, let last = values.last else {
            return true
        }
        let increasing = last >= first
        return zip(values, values.dropFirst()).allSatisfy { increasing ? $1 >= $0 : $1 <= $0 }
    }

    override func spec() {
        describe("easing") {
            it("starts at zero and ends at one") {
                expect(FrameInterpolation.easeInOutSine(0)) == 0
                expect(FrameInterpolation.easeInOutSine(1)).to(beCloseTo(1))
            }

            it("is monotonic, symmetric, and gentle at both ends") {
                let samples = (0...100).map { FrameInterpolation.easeInOutSine(CGFloat($0) / 100) }
                expect(self.isMonotonic(samples)).to(beTrue())
                expect(FrameInterpolation.easeInOutSine(0.5)).to(beCloseTo(0.5))
                expect(FrameInterpolation.easeInOutSine(0.1)) < 0.1
                expect(FrameInterpolation.easeInOutSine(0.9)) > 0.9
            }

            it("clamps out-of-range progress") {
                expect(FrameInterpolation.easeInOutSine(-1)) == 0
                expect(FrameInterpolation.easeInOutSine(2)).to(beCloseTo(1))
            }
        }

        describe("interpolation") {
            let start = CGRect(x: 0, y: 0, width: 100, height: 100)
            let end = CGRect(x: 200, y: 100, width: 300, height: 50)

            it("returns the endpoints at zero and one") {
                expect(FrameInterpolation.interpolate(from: start, to: end, progress: 0)) == start
                expect(FrameInterpolation.interpolate(from: start, to: end, progress: 1)) == end
            }

            it("rejects frames that could not be read") {
                expect(FrameInterpolation.readable(.null)).to(beNil())
                expect(FrameInterpolation.readable(.infinite)).to(beNil())
                expect(FrameInterpolation.readable(CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10))).to(beNil())
                expect(FrameInterpolation.readable(CGRect(x: 0.4, y: 0, width: 10.6, height: 10))) == CGRect(x: 0, y: 0, width: 11, height: 10)
            }

            it("produces integral intermediate frames") {
                let odd = CGRect(x: 1, y: 1, width: 101, height: 101)
                let mid = FrameInterpolation.interpolate(from: start, to: odd, progress: 0.5)
                for value in [mid.minX, mid.minY, mid.width, mid.height] {
                    expect(value) == value.rounded()
                }
            }
        }

        describe("application frame writer") {
            func makeWrite(_ window: TestWindow, xPosition: CGFloat) -> ApplicationFrameWriter<TestWindow>.Write {
                return .init(window: window, frame: CGRect(x: xPosition, y: 0, width: 100, height: 100), includingSize: false)
            }

            /// A writer whose every frame signals `started` and then waits for `release` before it is applied, so a test can
            /// queue frames behind one in flight without guessing how soon the writer's thread picks it up.
            func makeGatedWriter(group: DispatchGroup, started: DispatchSemaphore, release: DispatchSemaphore) -> ApplicationFrameWriter<TestWindow> {
                return ApplicationFrameWriter<TestWindow>(pid: 1, group: group, inline: false, now: { ProcessInfo.processInfo.systemUptime }, beginWrite: { _ in
                    started.signal()
                    release.wait()
                    return true
                })
            }

            it("drops a queued frame once its window may no longer be touched") {
                let window = TestWindow(element: nil)!
                let group = DispatchGroup()
                let checked = DispatchSemaphore(value: 0)
                let proceed = DispatchSemaphore(value: 0)
                var allowed = true
                let holdUntilHandedOff: (TestWindow) -> Bool = { _ in
                    // Decide from the state on entry, then hold the frame until the test has queued the next one behind it
                    // and handed the window off.
                    let decision = allowed
                    checked.signal()
                    proceed.wait()
                    return decision
                }
                let writer = ApplicationFrameWriter<TestWindow>(pid: 1, group: group, inline: false, now: { 0 }, beginWrite: holdUntilHandedOff)

                writer.write([0: makeWrite(window, xPosition: 1)])
                expect(checked.wait(timeout: .now() + 2)) == .success
                writer.write([0: makeWrite(window, xPosition: 2)])
                allowed = false
                // Release the first frame, and let the second be checked at once.
                proceed.signal()
                proceed.signal()

                expect(group.wait(timeout: .now() + 2)) == .success
                expect(window.frameHistory.map { $0.minX }) == [1]
            }

            it("applies every frame when writing inline") {
                let window = TestWindow(element: nil)!
                let group = DispatchGroup()
                let writer = ApplicationFrameWriter<TestWindow>(pid: 1, group: group, inline: true, now: { 0 })

                for step in 1...5 {
                    writer.write([0: makeWrite(window, xPosition: CGFloat(step))])
                }

                expect(window.frameHistory.map { $0.minX }) == [1, 2, 3, 4, 5]
                expect(writer.statisticsSnapshot().applied) == 5
                expect(writer.statisticsSnapshot().requested) == 5
                expect(group.wait(timeout: .now())) == .success
            }

            it("drops frames a slow application cannot keep up with but always lands on the newest") {
                let window = TestWindow(element: nil)!
                window.animationFrameDelay = 0.03
                let group = DispatchGroup()
                let writer = ApplicationFrameWriter<TestWindow>(pid: 1, group: group, inline: false, now: { ProcessInfo.processInfo.systemUptime })

                // Ten frames arrive faster than the window can apply them.
                for step in 1...10 {
                    writer.write([0: makeWrite(window, xPosition: CGFloat(step))])
                    Thread.sleep(forTimeInterval: 0.002)
                }

                expect(group.wait(timeout: .now() + 2)) == .success
                let statistics = writer.statisticsSnapshot()
                expect(statistics.requested) == 10
                expect(statistics.applied) < 10
                expect(window.frame().minX) == 10
                expect(self.isMonotonic(window.frameHistory.map { $0.minX })).to(beTrue())
            }

            it("keeps a queued resize when a later move replaces it") {
                let window = TestWindow(element: nil)!
                let group = DispatchGroup()
                let started = DispatchSemaphore(value: 0)
                let release = DispatchSemaphore(value: 0)
                let writer = makeGatedWriter(group: group, started: started, release: release)

                // A move is in flight; a resize queues behind it; then another move for the same window arrives.
                writer.write([0: makeWrite(window, xPosition: 1)])
                expect(started.wait(timeout: .now() + 2)) == .success
                writer.write([0: .init(window: window, frame: CGRect(x: 2, y: 0, width: 300, height: 200), includingSize: true)])
                writer.write([0: .init(window: window, frame: CGRect(x: 3, y: 0, width: 300, height: 200), includingSize: false)])
                // Let the move through, then the frame merged behind it.
                release.signal()
                release.signal()

                expect(group.wait(timeout: .now() + 2)) == .success
                expect(window.frame()) == CGRect(x: 3, y: 0, width: 300, height: 200)
            }

            it("forgets discarded frames") {
                let window = TestWindow(element: nil)!
                let group = DispatchGroup()
                let started = DispatchSemaphore(value: 0)
                let release = DispatchSemaphore(value: 0)
                let writer = makeGatedWriter(group: group, started: started, release: release)

                writer.write([0: makeWrite(window, xPosition: 1)])
                expect(started.wait(timeout: .now() + 2)) == .success
                writer.write([0: makeWrite(window, xPosition: 2)])
                writer.discardPending()
                release.signal()

                expect(group.wait(timeout: .now() + 2)) == .success
                expect(window.frameHistory.map { $0.minX }) == [1]
            }
        }

        describe("coordinates and parking") {
            it("flips between AppKit and Accessibility coordinates and back") {
                let flipped = CGRect(x: 10, y: 20, width: 100, height: 50)
                let appKit = FlippedCoordinates.appKitRect(fromFlipped: flipped, primaryScreenHeight: 1000)
                expect(appKit) == CGRect(x: 10, y: 930, width: 100, height: 50)
                expect(FlippedCoordinates.flippedRect(fromAppKit: appKit, primaryScreenHeight: 1000)) == flipped
            }

            it("parks windows to the right of every display") {
                let displays = [CGRect(x: 0, y: 0, width: 1728, height: 1117), CGRect(x: -962, y: -1600, width: 3840, height: 1600)]
                let origin = AnimatedReflowOperation<TestWindow>.parkingOrigin(forDisplayBounds: displays)
                expect(origin.x) == 2878 + 200
            }

            it("finds an attached screen by its identifier") {
                expect(AMScreen.screen(withID: "not-a-screen")).to(beNil())

                guard let screen = AMScreen.availableScreens.last, let screenID = screen.screenID() else {
                    throw XCTSkip("needs an attached display")
                }
                expect(AMScreen.screen(withID: screenID)?.screenID()) == screenID
            }

            it("finds the display a screen frame lies on") {
                let displays = [CGRect(x: 0, y: 0, width: 1728, height: 1117), CGRect(x: -962, y: -1600, width: 3840, height: 1600)]
                let external = CGRect(x: -962, y: -1570, width: 3840, height: 1570)
                expect(WindowImageCapture.displayBounds(containing: external, among: displays)) == displays[1]
                expect(WindowImageCapture.displayBounds(containing: CGRect(x: 5000, y: 0, width: 10, height: 10), among: displays)).to(beNil())
            }

            it("picks the candidate whose bounds overlap a rectangle most") {
                let displays = [CGRect(x: 0, y: 0, width: 1000, height: 800), CGRect(x: 1000, y: 0, width: 1000, height: 800)]
                let names = ["left", "right"]
                let mostlyRight = CGRect(x: 900, y: 100, width: 400, height: 100)
                let mostlyLeft = CGRect(x: 700, y: 100, width: 400, height: 100)
                let offEveryDisplay = CGRect(x: 3000, y: 100, width: 10, height: 10)
                expect(ActiveDisplays.mostOverlapping(mostlyRight, among: [0, 1], bounds: { displays[$0] }).map { names[$0] }) == "right"
                expect(ActiveDisplays.mostOverlapping(mostlyLeft, among: [0, 1], bounds: { displays[$0] }).map { names[$0] }) == "left"
                expect(ActiveDisplays.mostOverlapping(offEveryDisplay, among: [0, 1], bounds: { displays[$0] })).to(beNil())
            }
        }

        describe("screen capture permission hint") {
            it("is offered once per preferences store") {
                let suiteName = "AmethystTests.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suiteName)!
                defer { defaults.removePersistentDomain(forName: suiteName) }

                expect(ScreenCapturePermission.takeHintOpportunity(defaults: defaults)).to(beTrue())
                expect(ScreenCapturePermission.takeHintOpportunity(defaults: defaults)).to(beFalse())

                defaults.removeObject(forKey: ScreenCapturePermission.hintShownKey)
                expect(ScreenCapturePermission.takeHintOpportunity(defaults: defaults)).to(beTrue())
            }
        }

        describe("overlay panel") {
            it("calls a pending completion when it is replaced or the overlay is cancelled") {
                let image = AnimatedReflowOperationTests.makeImage(width: 10, height: 10)
                let proxy = SnapshotProxy(image: image, start: CGRect(x: 10, y: 60, width: 40, height: 40), target: CGRect(x: 80, y: 60, width: 40, height: 40))
                var glideCompletions = 0
                var correctionCompletions = 0
                let screenFrame = try self.primaryScreenFrameOrSkip()
                let overlay: ReflowAnimationOverlay = self.onMain {
                    let overlay = ReflowAnimationOverlay()
                    overlay.show(proxies: [proxy], screenFrame: screenFrame, backdrop: nil)
                    overlay.animate(duration: 5) { glideCompletions += 1 }
                    return overlay
                }

                self.onMain { overlay.retarget(frames: [CGRect(x: 90, y: 60, width: 40, height: 40)], duration: 5) { correctionCompletions += 1 } }
                expect(glideCompletions) == 1
                expect(correctionCompletions) == 0

                self.onMain { overlay.cancel() }
                expect(correctionCompletions) == 1

                // Late Core Animation callbacks for the removed animations must not call anything a second time.
                self.letMainThreadRun(attempts: 6) { false }
                expect(glideCompletions) == 1
                expect(correctionCompletions) == 1
            }

            it("hides a proxy without ending the glide of the others") {
                let image = AnimatedReflowOperationTests.makeImage(width: 10, height: 10)
                let proxies = [
                    SnapshotProxy(image: image, start: CGRect(x: 10, y: 60, width: 40, height: 40), target: CGRect(x: 80, y: 60, width: 40, height: 40)),
                    SnapshotProxy(image: image, start: CGRect(x: 10, y: 160, width: 40, height: 40), target: CGRect(x: 80, y: 160, width: 40, height: 40))
                ]
                var glideCompletions = 0
                let screenFrame = try self.primaryScreenFrameOrSkip()
                let overlay: ReflowAnimationOverlay = self.onMain {
                    let overlay = ReflowAnimationOverlay()
                    overlay.show(proxies: proxies, screenFrame: screenFrame, backdrop: nil)
                    overlay.animate(duration: 5) { glideCompletions += 1 }
                    // Correcting the first picture alone starts a newer batch of motion that holds only it.
                    overlay.retarget(frames: [CGRect(x: 90, y: 60, width: 40, height: 40), nil], duration: 5, completion: nil)
                    return overlay
                }

                // Hiding that picture, as happens when its window is thrown elsewhere, must not end the glide for the other.
                self.onMain { overlay.hide(indices: [0]) }
                self.letMainThreadRun(attempts: 6) { false }
                expect(glideCompletions) == 0

                self.onMain { overlay.cancel() }
                expect(glideCompletions) == 1
            }

            it("keeps its panel on the Space it was made on") {
                let image = AnimatedReflowOperationTests.makeImage(width: 10, height: 10)
                let proxy = SnapshotProxy(image: image, start: CGRect(x: 10, y: 60, width: 40, height: 40), target: CGRect(x: 80, y: 60, width: 40, height: 40))
                let screenFrame = try self.primaryScreenFrameOrSkip()
                let overlay: ReflowAnimationOverlay = self.onMain {
                    let overlay = ReflowAnimationOverlay()
                    overlay.show(proxies: [proxy], screenFrame: screenFrame, backdrop: nil)
                    return overlay
                }
                let behavior: NSWindow.CollectionBehavior? = self.onMain {
                    NSApplication.shared.windows.first { $0.identifier == ReflowAnimationOverlay.panelIdentifier }?.collectionBehavior
                }

                // The panel stays with the Space it was made on; a Space switch carries it away.
                expect(behavior).toNot(beNil())
                expect(behavior?.contains(.canJoinAllSpaces)) == false
                expect(behavior?.contains(.stationary)) == false
                expect(behavior?.contains(.fullScreenAuxiliary)) == true

                self.onMain { overlay.cancel() }
            }

            it("calls a pending completion when the overlay finishes") {
                let image = AnimatedReflowOperationTests.makeImage(width: 10, height: 10)
                let proxy = SnapshotProxy(image: image, start: CGRect(x: 10, y: 60, width: 40, height: 40), target: CGRect(x: 80, y: 60, width: 40, height: 40))
                var glideCompletions = 0
                var finishCompletions = 0
                let screenFrame = try self.primaryScreenFrameOrSkip()
                let overlay: ReflowAnimationOverlay = self.onMain {
                    let overlay = ReflowAnimationOverlay()
                    overlay.show(proxies: [proxy], screenFrame: screenFrame, backdrop: nil)
                    overlay.animate(duration: 5) { glideCompletions += 1 }
                    return overlay
                }

                self.onMain { overlay.finish(fadeDuration: 0.02, lingering: [], lingerDuration: 0.02) { finishCompletions += 1 } }
                self.letMainThreadRun(attempts: 40) { glideCompletions == 1 && finishCompletions == 1 }
                expect(glideCompletions) == 1
                expect(finishCompletions) == 1
            }

            it("takes its panel down after the fade even when nothing else retains the overlay") {
                let livePanels = { self.onMain { ReflowAnimationOverlay.livePanelCount } }
                let image = AnimatedReflowOperationTests.makeImage(width: 10, height: 10)
                let proxy = SnapshotProxy(image: image, start: CGRect(x: 10, y: 60, width: 40, height: 40), target: CGRect(x: 80, y: 60, width: 40, height: 40))

                let screenFrame = try self.primaryScreenFrameOrSkip()
                var overlay: ReflowAnimationOverlay? = self.onMain {
                    let overlay = ReflowAnimationOverlay()
                    overlay.show(proxies: [proxy], screenFrame: screenFrame, backdrop: nil)
                    return overlay
                }
                expect(livePanels()) == 1

                // The reflow operation drops its reference as soon as it has asked for the fade.
                weak var stillAlive = overlay
                self.onMain { overlay?.finish(fadeDuration: 0.02, lingering: [], lingerDuration: 0.02) {} }
                overlay = nil

                // The pending fade keeps the overlay alive by itself.
                expect(stillAlive).toNot(beNil())

                // Then the fade, or its fallback timer, takes the panel down, and once the fallback has fired nothing holds
                // the overlay any more. The main thread must be left free to deliver both.
                self.letMainThreadRun(attempts: 100) { livePanels() == 0 && stillAlive == nil }
                expect(livePanels()) == 0
                expect(stillAlive).to(beNil())
            }
        }

        describe("frame assignment") {
            it("applies window margins from the configuration it is given") {
                let window = LayoutWindow<TestWindow>(id: "window", frame: .zero, isFocused: false)
                let rules = ResizeRules(isMain: true, unconstrainedDimension: .horizontal, scaleFactor: 1)
                let tile = CGRect(x: 0, y: 0, width: 1000, height: 1000)
                let storage = TestConfigurationStorage()
                storage.set(true, forKey: .windowMargins)
                storage.set(Float(20), forKey: .windowMarginSize)
                let withMargins = FrameAssignment(frame: tile, window: window, screenFrame: tile, resizeRules: rules, configuration: UserConfiguration(storage: storage))
                let withoutMargins = FrameAssignment(frame: tile, window: window, screenFrame: tile, resizeRules: rules, configuration: UserConfiguration(storage: TestConfigurationStorage()))

                expect(withMargins.finalFrame) == CGRect(x: 10, y: 10, width: 980, height: 980)
                expect(withoutMargins.finalFrame) == tile
            }
        }

        describe("fake windows") {
            it("never share a window identifier") {
                let windows = (0..<50).map { _ in TestWindow(element: nil)! }
                expect(Set(windows.map { $0.cgID() }).count) == windows.count
            }
        }

        describe("animating windows registry") {
            it("keeps a window with the screen animating it until that screen releases it") {
                let registry = AnimatingWindows()
                registry.claim([1, 2], for: "external")
                expect(registry.screenID(for: 1)) == "external"
                expect(registry.screenID(for: 3)).to(beNil())

                // Another screen's release must not disturb the claim.
                registry.release([1], for: "builtin")
                expect(registry.screenID(for: 1)) == "external"

                registry.release([1, 2], for: "external")
                expect(registry.screenID(for: 1)).to(beNil())
                expect(registry.screenID(for: 2)).to(beNil())
            }

            it("remembers a picture's last position for a second and hands it out once") {
                let registry = AnimatingWindows()
                let frame = CGRect(x: 10, y: 20, width: 300, height: 400)
                registry.recordLastSeenFrames([1: frame], at: 0)
                expect(registry.takeLastSeenFrame(for: 1, at: 1.5)).to(beNil())

                registry.recordLastSeenFrames([1: frame], at: 0)
                expect(registry.takeLastSeenFrame(for: 1, at: 0.5)) == frame
                expect(registry.takeLastSeenFrame(for: 1, at: 0.5)).to(beNil())
            }

            it("ignores a claim by a screen that is no longer attached") {
                let registry = AnimatingWindows()
                registry.claim([1], for: "external")
                expect(registry.screenID(for: 1, ifAmong: ["builtin", "external"])) == "external"
                expect(registry.screenID(for: 1, ifAmong: ["builtin"])).to(beNil())
                expect(registry.screenID(for: 2, ifAmong: ["builtin", "external"])).to(beNil())
            }

            it("refuses a write to a window that was handed off and reports where it was headed") {
                let registry = AnimatingWindows()
                let target = CGRect(x: 10, y: 20, width: 300, height: 400)
                registry.claim([1], for: "external", targets: [1: target])
                expect(registry.beginWrite(1, for: "external")).to(beTrue())
                registry.endWrite(1)
                expect(registry.beginWrite(1, for: "builtin")).to(beFalse())

                expect(registry.handOff([1])) == [1: target]
                expect(registry.beginWrite(1, for: "external")).to(beFalse())
                expect(registry.screenID(for: 1)).to(beNil())
                expect(registry.handOff([1])).to(beEmpty())
            }

            it("waits for a write in flight before handing a window off, but not forever") {
                let registry = AnimatingWindows()
                let target = CGRect(x: 10, y: 20, width: 300, height: 400)
                registry.claim([1], for: "external", targets: [1: target])
                expect(registry.beginWrite(1, for: "external")).to(beTrue())
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { registry.endWrite(1) }

                var start = Date()
                expect(registry.handOff([1])) == [1: target]
                expect(Date().timeIntervalSince(start)) >= 0.09
                expect(Date().timeIntervalSince(start)) < 0.9

                // A write that never ends must not hold the throw hostage.
                registry.claim([2], for: "external")
                expect(registry.beginWrite(2, for: "external")).to(beTrue())
                start = Date()
                registry.handOff([2], timeout: 0.05)
                expect(Date().timeIntervalSince(start)) >= 0.04
                expect(Date().timeIntervalSince(start)) < 0.9
                expect(registry.screenID(for: 2)).to(beNil())
            }

            it("forgets a window's destination when its screen releases it") {
                let registry = AnimatingWindows()
                registry.claim([1], for: "external", targets: [1: CGRect(x: 1, y: 2, width: 3, height: 4)])
                registry.release([1], for: "external")
                expect(registry.handOff([1])).to(beEmpty())
            }

            it("reports only the windows an animation is moving, so other windows' move notifications count as gestures") {
                let registry = AnimatingWindows()
                registry.claim([7], for: "external")
                expect(registry.isAnimating(7)).to(beTrue())
                expect(registry.isAnimating(8)).to(beFalse())

                registry.release([7], for: "external")
                expect(registry.isAnimating(7)).to(beFalse())
            }
        }

        describe("snapshot animation") {
            let startFrames = [
                CGRect(x: 0, y: 0, width: 1000, height: 1000),
                CGRect(x: 1000, y: 0, width: 1000, height: 1000)
            ]
            let targetFrames = [
                CGRect(x: 0, y: 0, width: 500, height: 1000),
                CGRect(x: 500, y: 0, width: 1500, height: 1000)
            ]
            let captureAll: ([WindowCaptureRequest]) -> [CGImage]? = { requests in requests.map { _ in AnimatedReflowOperationTests.makeImage() } }

            it("parks, resizes out of sight, places, and settles each window") {
                // Windows at distinct, non-zero heights: a window parks at the parking spot's x but keeps its own y.
                let starts = [
                    CGRect(x: 0, y: 40, width: 1000, height: 800),
                    CGRect(x: 1000, y: 120, width: 1000, height: 800)
                ]
                let targets = [
                    CGRect(x: 0, y: 40, width: 500, height: 800),
                    CGRect(x: 500, y: 40, width: 1500, height: 800)
                ]
                let fixture = self.makeFixture(startFrames: starts, targetFrames: targets)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll)

                operation.main()

                for (index, window) in fixture.windows.enumerated() {
                    let start = starts[index]
                    let target = fixture.operations[index].frameAssignment.finalFrame
                    let parked = CGPoint(x: self.parkingOrigin.x, y: start.minY)

                    expect(window.frameHistory) == [
                        CGRect(origin: parked, size: start.size),
                        CGRect(origin: parked, size: target.size),
                        CGRect(origin: target.origin, size: target.size),
                        target
                    ]
                }

                expect(operation.tickCount) == 0
                expect(clock.sleepCount) == 1
                expect(animator.finishCalled).to(beTrue())
                expect(animator.cancelCalled).to(beFalse())
            }

            it("hands the overlay the start and target frames and the duration") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll)

                operation.main()

                expect(animator.shownProxies.map { $0.start }) == startFrames
                expect(animator.shownProxies.map { $0.target }) == fixture.operations.map { FrameInterpolation.integral($0.frameAssignment.finalFrame) }
                expect(animator.shownScreenFrame) == fixture.operations[0].frameAssignment.screenFrame
                expect(animator.animateDuration) == self.duration
            }

            it("falls back to moving the real windows when capture fails") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: { _ in nil })

                operation.main()

                expect(animator.shownProxies).to(beEmpty())
                expect(operation.tickCount) == self.expectedTicks
                // The accessibility strategy starts with the in-place resize.
                expect(fixture.windows[1].frameHistory.first) == CGRect(origin: startFrames[1].origin, size: fixture.operations[1].frameAssignment.finalFrame.size)
            }

            it("falls back when capture returns the wrong number of images") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: { _ in [AnimatedReflowOperationTests.makeImage()] })

                operation.main()

                expect(animator.shownProxies).to(beEmpty())
                expect(operation.tickCount) == self.expectedTicks
            }

            it("re-lays out windows in place behind a backdrop and dissolves proxies into fresh captures") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                var glideStartedAt: TimeInterval = 0
                var dissolvedAt: TimeInterval = 0
                animator.onAnimate = { glideStartedAt = clock.now() }
                animator.onCrossfade = { dissolvedAt = clock.now() }
                // Captures are sized like the windows they picture, one pixel per point, so a fresh capture matches the accepted size.
                let captureCurrent: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    requests.map { request in
                        let size = fixture.window(for: request).frame().size
                        return AnimatedReflowOperationTests.makeImage(width: Int(size.width), height: Int(size.height))
                    }
                }
                var excludedFromBackdrop: [CGWindowID] = []
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureCurrent, backdrop: { _, ids in
                    excludedFromBackdrop = ids
                    return AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                expect(animator.shownBackdrop).toNot(beNil())
                expect(excludedFromBackdrop) == fixture.windows.map { $0.cgID() }

                // No parking: each window goes straight to its destination at its final size, then settles.
                for (index, window) in fixture.windows.enumerated() {
                    let target = fixture.operations[index].frameAssignment.finalFrame
                    expect(window.frameHistory) == [target, target]
                }

                expect(animator.retargetedFrames).to(beEmpty())
                expect(animator.crossfadeImages.count) == 1
                expect(animator.crossfadeImages[0].compactMap { $0 }.count) == 2
                // A mid-glide dissolve gets the time the glide has left, never less than the minimum dissolve.
                expect(animator.crossfadeDurations[0]) == max(self.duration - (dissolvedAt - glideStartedAt), 0.15)
                expect(animator.finishCalled).to(beTrue())
            }

            it("corrects the size and still dissolves when an application constrains its window in place") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let constrained = fixture.windows[1]
                constrained.maximumSize = CGSize(width: 1200, height: 1000)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                let captureCurrent: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    requests.map { request in
                        let size = fixture.window(for: request).frame().size
                        return AnimatedReflowOperationTests.makeImage(width: Int(size.width), height: Int(size.height))
                    }
                }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureCurrent, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                let target = fixture.operations[1].frameAssignment.finalFrame
                let accepted = CGRect(origin: target.origin, size: CGSize(width: 1200, height: 1000))
                expect(animator.retargetedFrames.count) == 1
                expect(animator.retargetedFrames[0][1]) == accepted
                expect(animator.crossfadeImages.count) == 1
                expect(animator.crossfadeImages[0][1]?.width) == 1200
                expect(constrained.frame()) == accepted
            }

            it("refines one application's windows without waiting for a slower application") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let quick = fixture.windows[0]
                quick.maximumSize = CGSize(width: 400, height: 1000)
                let slow = fixture.windows[1]
                // Window 1 belongs to another application, one that takes 0.4 s over every frame.
                slow.pidValue = 5678
                slow.animationFrameDelay = 0.4
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                let captureCurrent: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    requests.map { request in
                        let size = fixture.window(for: request).frame().size
                        return AnimatedReflowOperationTests.makeImage(width: Int(size.width), height: Int(size.height))
                    }
                }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureCurrent, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                }, writesInline: false)

                operation.main()

                // Window 0 is corrected on the first tick, while window 1's application is still busy: each application has a
                // writer of its own.
                let accepted = CGRect(origin: fixture.operations[0].frameAssignment.finalFrame.origin, size: CGSize(width: 400, height: 1000))
                expect(animator.retargetedFrames.count) == 1
                expect(animator.retargetedFrames[0][0]) == accepted
                expect(animator.retargetedFrames[0][1]).to(beNil())
                expect(clock.sleepCount) < 10
                expect(animator.finishCalled).to(beTrue())
            }

            it("lets a window's picture linger when its recapture fails") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                var captureCalls = 0
                // The first capture works; every later one comes back empty, as when the window server is busy.
                let captureOnce: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    captureCalls += 1
                    return captureCalls == 1 ? requests.map { _ in AnimatedReflowOperationTests.makeImage() } : nil
                }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureOnce, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                expect(captureCalls) > 1
                expect(animator.crossfadeImages).to(beEmpty())
                expect(animator.lingering) == [0, 1]
                expect(animator.finishCalled).to(beTrue())
            }

            it("judges a recapture's freshness at the display's pixel density") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                var captureCalls = 0
                // A Retina display: two pixels per point. Window 1's recapture comes back at one pixel per point, the size a
                // stale surface would have, while window 0's comes back at the display's density.
                let captureRetina: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    captureCalls += 1
                    return requests.map { request in
                        let size = fixture.window(for: request).frame().size
                        let scale = captureCalls > 1 && request.windowID == fixture.windows[1].cgID() ? 1 : 2
                        return AnimatedReflowOperationTests.makeImage(width: Int(size.width) * scale, height: Int(size.height) * scale)
                    }
                }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureRetina, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                expect(animator.crossfadeImages.count) == 1
                expect(animator.crossfadeImages[0][0]?.width) == Int(fixture.operations[0].frameAssignment.finalFrame.width) * 2
                expect(animator.crossfadeImages[0][1]).to(beNil())
                expect(animator.lingering) == [1]
            }

            it("dissolves a corrected window to a fresh picture within the glide") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let constrained = fixture.windows[1]
                constrained.maximumSize = CGSize(width: 1200, height: 1000)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                // The glide keeps going through the correction and ends only once the fresh picture is in.
                animator.endsGlideOnRefinement = false
                animator.onCrossfade = { animator.endGlide() }
                let captureCurrent: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    requests.map { request in
                        let window = fixture.window(for: request)
                        return AnimatedReflowOperationTests.makeImage(width: Int(window.frame().width), height: Int(window.frame().height))
                    }
                }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureCurrent, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                // Corrected in the loop, then dissolved in the loop with the time remaining, well before a stall.
                expect(animator.retargetedFrames.count) == 1
                expect(animator.crossfadeImages.count) == 1
                expect(animator.crossfadeImages[0][1]?.width) == 1200
                expect(animator.crossfadeDurations[0]) > 0.15
                expect(clock.sleepCount) < 20
                expect(animator.finishCalled).to(beTrue())
            }

            it("retries a stale recapture within the glide") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                animator.endsGlideOnRefinement = false
                // The glide ends on the second dissolve, the one that brings the retried picture in.
                animator.onCrossfade = { animator.onCrossfade = { animator.endGlide() } }
                var captureCalls = 0
                let captureLagging: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    captureCalls += 1
                    return requests.map { request in
                        let window = fixture.window(for: request)
                        // The second window's first recapture still shows its old surface, the way a slow renderer does.
                        let stale = captureCalls == 2 && request.windowID == fixture.windows[1].cgID()
                        let size = stale ? startFrames[1].size : window.frame().size
                        return AnimatedReflowOperationTests.makeImage(width: Int(size.width), height: Int(size.height))
                    }
                }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureLagging, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                expect(captureCalls) == 3
                expect(animator.crossfadeImages.count) == 2
                expect(animator.crossfadeImages[0][1]).to(beNil())
                expect(animator.crossfadeImages[1][1]?.width) == Int(fixture.operations[1].frameAssignment.finalFrame.width)
                // The glide could only end through the second dissolve, so a short glide proves the retry came within it
                // rather than at a stall's final attempt, which takes over forty sleeps to reach.
                expect(clock.sleepCount) < 20
                expect(animator.lingering).to(beEmpty())
            }

            it("retries a recapture until the window has redrawn at its accepted size") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                var captureCalls = 0
                // The second window's first recapture still shows its old surface, the way a slow renderer does.
                let captureLagging: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    captureCalls += 1
                    return requests.map { request in
                        let stale = captureCalls == 2 && request.windowID == fixture.windows[1].cgID()
                        let size = stale ? startFrames[1].size : fixture.window(for: request).frame().size
                        return AnimatedReflowOperationTests.makeImage(width: Int(size.width), height: Int(size.height))
                    }
                }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureLagging, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                expect(captureCalls) == 3
                expect(animator.crossfadeImages.count) == 2
                expect(animator.crossfadeImages[0][0]).toNot(beNil())
                expect(animator.crossfadeImages[0][1]).to(beNil())
                expect(animator.crossfadeImages[1][1]?.width) == Int(fixture.operations[1].frameAssignment.finalFrame.width)
                expect(animator.finishCalled).to(beTrue())
                expect(animator.lingering).to(beEmpty())
            }

            it("does not dissolve a window whose capture cannot be verified and lets its proxy linger instead") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                let captureCurrent: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    requests.map { request in
                        let window = fixture.window(for: request)
                        return AnimatedReflowOperationTests.makeImage(width: Int(window.frame().width), height: Int(window.frame().height))
                    }
                }
                // Window 1 overhangs the display, so its recapture would come back scaled to size whether or not it has redrawn.
                let overhanging = fixture.windows[1].cgID()
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureCurrent, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                }, verifiable: { $0.windowID != overhanging })

                operation.main()

                expect(animator.crossfadeImages.count) == 1
                expect(animator.crossfadeImages[0][0]).toNot(beNil())
                expect(animator.crossfadeImages[0][1]).to(beNil())
                expect(animator.lingering) == [1]
            }

            it("lets a proxy linger at the handoff when its window never redraws") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                var captureCalls = 0
                // The second window's surface never changes, the way an app that does not repaint while covered behaves.
                let captureStuck: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    captureCalls += 1
                    return requests.map { request in
                        let stuck = captureCalls > 1 && request.windowID == fixture.windows[1].cgID()
                        let size = stuck ? startFrames[1].size : fixture.window(for: request).frame().size
                        return AnimatedReflowOperationTests.makeImage(width: Int(size.width), height: Int(size.height))
                    }
                }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureStuck, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                expect(animator.crossfadeImages.count) == 1
                expect(animator.crossfadeImages[0][1]).to(beNil())
                expect(animator.lingering) == [1]
                expect(animator.finishCalled).to(beTrue())
            }

            it("captures a window that overhangs the display edge whole and asks for it at its current frame") {
                // A window too wide for its tile, like Mail, ends up 100 points past the right edge of the display.
                let fixture = self.makeFixture(startFrames: [CGRect(x: 0, y: 0, width: 1100, height: 1000)], targetFrames: [CGRect(x: 1000, y: 0, width: 1000, height: 1000)])
                let window = fixture.windows[0]
                window.minimumSize = CGSize(width: 1100, height: 1000)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                var requestedFrames: [CGRect] = []
                let captureWhole: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    requests.map { request in
                        requestedFrames.append(request.frame)
                        let size = window.frame().size
                        return AnimatedReflowOperationTests.makeImage(width: Int(size.width), height: Int(size.height))
                    }
                }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureWhole, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                let landed = CGRect(x: 1000, y: 0, width: 1100, height: 1000)
                expect(window.frame()) == landed
                expect(requestedFrames.first) == CGRect(x: 0, y: 0, width: 1100, height: 1000)
                expect(requestedFrames.last) == landed
                expect(animator.retargetedFrames.count) == 1
                expect(animator.retargetedFrames[0][0]) == landed
                expect(animator.crossfadeImages.count) == 1
                expect(animator.crossfadeImages[0][0]?.width) == 1100
                expect(animator.lingering).to(beEmpty())
            }

            it("keeps the focused window's proxy on screen in place when the application keeps a larger size") {
                // A focused window with a 1100-point minimum width assigned a 500-point tile at the right edge of a 2000-point screen.
                let fixture = self.makeFixture(startFrames: [CGRect(x: 0, y: 0, width: 1100, height: 1000)], targetFrames: [CGRect(x: 1500, y: 0, width: 500, height: 1000)], focusedIndex: 0)
                let window = fixture.windows[0]
                window.minimumSize = CGSize(width: 1100, height: 1000)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                let captureWhole: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    requests.map { _ in AnimatedReflowOperationTests.makeImage(width: Int(window.frame().width), height: Int(window.frame().height)) }
                }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureWhole, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                // The settle keeps the window on screen; the proxy must be steered to that same frame, not to the overhanging one.
                let onScreen = CGRect(x: 900, y: 0, width: 1100, height: 1000)
                expect(window.frame()) == onScreen
                expect(animator.retargetedFrames.count) == 1
                expect(animator.retargetedFrames[0][0]) == onScreen
            }

            it("does not correct a window whose application has still not applied its frame when the glide ends") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                // Window 1's application takes longer than the whole animation to apply the in-place frame.
                fixture.windows[1].animationFrameDelay = 0.6
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                }, writesInline: false)

                operation.main()

                // Reading it back now would return its old frame; no correction may be issued for it.
                expect(animator.retargetedFrames.flatMap { $0 }.compactMap { $0 }).to(beEmpty())
                expect(animator.finishCalled).to(beTrue())
            }

            it("aims a non-resizable window's proxy at the tile position with the window's own size, in parked mode too") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let fixed = fixture.windows[1]
                fixed.isResizableValue = false
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll)

                operation.main()

                // The window only ever moves, so both its picture and its final frame use its original size.
                let expected = CGRect(origin: fixture.operations[1].frameAssignment.finalFrame.origin, size: startFrames[1].size)
                expect(animator.shownProxies[1].target) == expected
                expect(fixed.frame()) == expected
            }

            it("steers a proxy to where its window actually lands when the application refuses a position") {
                let fixture = self.makeFixture(startFrames: [CGRect(x: 0, y: 500, width: 1000, height: 500)], targetFrames: [CGRect(x: 0, y: 0, width: 1000, height: 500)])
                let window = fixture.windows[0]
                window.minimumY = 30
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                let captureFixed: ([WindowCaptureRequest]) -> [CGImage]? = { requests in
                    requests.map { _ in AnimatedReflowOperationTests.makeImage(width: 1000, height: 500) }
                }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureFixed, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                let landed = CGRect(x: 0, y: 30, width: 1000, height: 500)
                expect(animator.retargetedFrames.count) == 1
                expect(animator.retargetedFrames[0][0]) == landed
                expect(window.frame()) == landed
            }

            it("survives a late correction whose completion never arrives") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                fixture.windows[1].maximumSize = CGSize(width: 1200, height: 1000)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.swallowsCorrectionCompletions = true
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll)

                operation.main()

                // The correction was requested and its completion never came; the operation still finishes.
                expect(animator.retargetedFrames.count) == 1
                expect(animator.finishCalled).to(beTrue())
            }

            it("steers a proxy to the size its application actually accepts") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let constrained = fixture.windows[1]
                constrained.maximumSize = CGSize(width: 1200, height: 1000)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll)

                operation.main()

                let target = fixture.operations[1].frameAssignment.finalFrame
                let accepted = CGRect(origin: target.origin, size: CGSize(width: 1200, height: 1000))

                // Only the constrained window is corrected, to its accepted size at the assigned position.
                expect(animator.retargetedFrames.count) == 1
                expect(animator.retargetedFrames[0][0]).to(beNil())
                expect(animator.retargetedFrames[0][1]) == accepted
                expect(constrained.frame()) == accepted
                expect(animator.finishCalled).to(beTrue())
                // Parked windows cannot be captured, so no dissolve happens in this mode.
                expect(animator.crossfadeImages).to(beEmpty())
            }

            it("leaves out a window whose frame cannot be read and still settles it") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                fixture.windows[0].frameIsUnreadable = true
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                // A real screen identifier, as the screen manager always supplies one: the settle must not mistake a window
                // that was never claimed for one that was handed off.
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll, screenID: "screen-a")

                operation.main()

                // Only the readable window animates; the other gets the settle pass alone, as in a non-animated reflow.
                expect(animator.shownProxies.count) == 1
                expect(fixture.windows[0].frameHistory.count) == 1
                expect(fixture.windows[1].frame()) == fixture.operations[1].frameAssignment.finalFrame
            }

            it("keeps a window's target when its frame becomes unreadable mid-animation") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                // The app stops answering right after it accepts its new frame.
                fixture.windows[1].onAnimationFrame = { _ in fixture.windows[1].frameIsUnreadable = true }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                })

                operation.main()

                // No correction: the proxy keeps its original target and the handoff still happens.
                expect(animator.retargetedFrames.flatMap { $0 }.compactMap { $0 }).to(beEmpty())
                expect(animator.finishCalled).to(beTrue())
            }

            it("drops frames still queued for a window handed off while its application was busy") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                let thrown = fixture.windows[1]
                // The application takes 0.4 s over the park write, so the resize queued behind it is still waiting when the
                // throw comes 0.2 s in.
                thrown.animationFrameDelay = 0.4
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll, screenID: "source", writesInline: false)

                // The wait below is polled, and polling a group does not consume its signal.
                let finished = DispatchGroup()
                finished.enter()
                Thread.detachNewThread {
                    operation.main()
                    finished.leave()
                }
                self.letMainThreadRun(attempts: 4) { false }
                let handedOff = AnimatingWindows.shared.handOff([thrown.cgID()])

                // The hand-off waited for the park write to land and reported where the window was headed, so the throw can
                // put it back on screen first.
                expect(thrown.frameHistory.count) == 1
                expect(handedOff[thrown.cgID()]) == fixture.operations[1].frameAssignment.finalFrame
                self.letMainThreadRun(attempts: 100) { finished.wait(timeout: .now()) == .success }

                // The resize queued behind the park must not land, nor anything after it.
                expect(thrown.frameHistory.count) == 1
                expect(fixture.windows[0].frame()) == fixture.operations[0].frameAssignment.finalFrame
                expect(animator.finishCalled).to(beTrue())
            }

            it("forgets where a handed-off window's picture was when cancelled") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                animator.framesToPresent = [
                    CGRect(x: 0, y: 0, width: 500, height: 1000),
                    CGRect(x: 750, y: 0, width: 1500, height: 1000)
                ]
                let thrown = fixture.windows[1]
                var operation: AnimatedReflowOperation<TestWindow>!
                // The user throws window 1 elsewhere as the glide starts, and a new reflow cancels right after.
                animator.onAnimate = {
                    AnimatingWindows.shared.handOff([thrown.cgID()])
                    operation.cancel()
                }
                operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll, screenID: "source")

                operation.main()

                // The window still ours starts its next picture where it was; the thrown one must not be remembered here.
                expect(AnimatingWindows.shared.takeLastSeenFrame(for: fixture.windows[0].cgID(), at: clock.now())) == animator.framesToPresent[0]
                expect(AnimatingWindows.shared.takeLastSeenFrame(for: thrown.cgID(), at: clock.now())).to(beNil())
            }

            it("lets go of a window Amethyst moves elsewhere mid-glide") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                let thrown = fixture.windows[1]
                // The user throws window 1 to another screen just as the glide starts.
                animator.onAnimate = { AnimatingWindows.shared.handOff([thrown.cgID()]) }
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                }, screenID: "source")

                operation.main()

                // Its proxy is hidden, and it receives nothing beyond the write that had already been issued: no correction,
                // no placement, no settle to its old tile. The other window completes normally.
                expect(animator.hiddenIndices) == [1]
                expect(thrown.frameHistory.count) == 1
                expect(fixture.windows[0].frame()) == fixture.operations[0].frameAssignment.finalFrame
                expect(animator.finishCalled).to(beTrue())
                expect(AnimatingWindows.shared.screenID(for: fixture.windows[0].cgID())).to(beNil())
            }

            it("settles and fades even when the glide never reports completion") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                // Nothing ever completes the glide, as when a display is asleep.
                animator.completesImmediately = false
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll)

                operation.main()

                expect(animator.cancelCalled).to(beFalse())
                expect(animator.finishCalled).to(beTrue())
                expect(fixture.windows.map { $0.frame() }) == fixture.operations.map { $0.frameAssignment.finalFrame }
            }

            it("skips late corrections and dissolves once the glide has stalled") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                // The render server never reports anything back, as when a display is asleep.
                animator.completesImmediately = false
                animator.endsGlideOnRefinement = false
                let constrained = fixture.windows[1]
                constrained.maximumSize = CGSize(width: 1200, height: 1000)
                // Its application is busy for the whole glide, which passes in an instant on the fake clock, so its correction
                // would only be possible afterwards, when nothing can be seen or reported any more.
                constrained.animationFrameDelay = 0.1
                let operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll, backdrop: { _, _ in
                    AnimatedReflowOperationTests.makeImage(width: 4, height: 4)
                }, writesInline: false)

                operation.main()

                expect(animator.finishCalled).to(beTrue())
                expect(animator.retargetedFrames).to(beEmpty())
                expect(animator.crossfadeImages).to(beEmpty())
            }

            it("takes the overlay down when cancelled after the glide but before the handoff") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                var operation: AnimatedReflowOperation<TestWindow>!
                // Parked mode places the real windows only after the glide; a new reflow cancels right then.
                let target = fixture.operations[1].frameAssignment.finalFrame
                fixture.windows[1].onAnimationFrame = { frame in
                    if frame.origin == target.origin {
                        operation.cancel()
                    }
                }
                operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll)

                operation.main()

                expect(operation.isCancelled).to(beTrue())
                expect(animator.finishCalled).to(beFalse())
                expect(animator.cancelCalled).to(beTrue())
            }

            it("leaves windows at their tiles when cancelled mid-glide and lets the next animation start from where the pictures were") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let animator = FakeSnapshotAnimator()
                animator.completesImmediately = false
                let midway = [
                    CGRect(x: 0, y: 0, width: 500, height: 1000),
                    CGRect(x: 750, y: 0, width: 1500, height: 1000)
                ]
                animator.framesToPresent = midway
                var operation: AnimatedReflowOperation<TestWindow>!
                animator.onAnimate = { operation.cancel() }
                operation = self.makeSnapshotOperation(fixture, clock: clock, animator: animator, capture: captureAll)

                operation.main()

                expect(animator.cancelCalled).to(beTrue())
                expect(animator.finishCalled).to(beFalse())
                // The reflow that cancelled us may do nothing, so the real windows must already be at valid tiles.
                let moved = fixture.windows[1]
                expect(moved.frame().origin) == fixture.operations[1].frameAssignment.finalFrame.origin

                // A follow-up animation moving the same windows back starts its pictures where the user last saw them.
                let followUpAnimator = FakeSnapshotAnimator()
                let followUpOperations = fixture.operations.enumerated().map { index, original -> FrameAssignmentOperation<TestWindow> in
                    let assignment = original.frameAssignment
                    let reversed = FrameAssignment(
                        frame: startFrames[index], window: assignment.window, screenFrame: assignment.screenFrame,
                        resizeRules: assignment.resizeRules, configuration: assignment.configuration
                    )
                    return FrameAssignmentOperation(frameAssignment: reversed, windowSet: original.windowSet)
                }
                let followUpOperation = AnimatedReflowOperation(
                    frameAssignmentOperations: followUpOperations,
                    duration: self.duration,
                    frameInterval: self.frameInterval,
                    writesInline: true,
                    captureImages: captureAll,
                    makeSnapshotAnimator: { followUpAnimator },
                    parkingOrigin: { self.parkingOrigin },
                    now: clock.now,
                    sleep: clock.sleep
                )
                followUpOperation.main()

                expect(followUpAnimator.shownProxies.map { $0.start }) == midway
            }
        }

        describe("animated reflow") {
            let startFrames = [
                CGRect(x: 0, y: 0, width: 1000, height: 1000),
                CGRect(x: 1000, y: 0, width: 1000, height: 1000)
            ]
            let targetFrames = [
                CGRect(x: 0, y: 0, width: 500, height: 1000),
                CGRect(x: 500, y: 0, width: 1500, height: 1000)
            ]

            it("moves every window together to its final frame") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let operation = self.makeOperation(fixture, clock: clock)

                operation.main()

                expect(operation.tickCount) == self.expectedTicks

                for (index, window) in fixture.windows.enumerated() {
                    let target = fixture.operations[index].frameAssignment.finalFrame
                    // Windows first take their final size in place, then glide: every frame lies within that envelope.
                    let resizedInPlace = CGRect(origin: startFrames[index].origin, size: target.size)
                    let bounds = startFrames[index].union(target).union(resizedInPlace)

                    expect(window.frame()) == target
                    // Window 0 only changes size, so it is done after the in-place resize plus the settle; window 1 also glides.
                    if startFrames[index].origin == target.origin {
                        expect(window.frameHistory.count) == 2
                    } else {
                        expect(window.frameHistory.count) > 2
                    }

                    for frame in window.frameHistory {
                        expect(bounds.contains(frame)).to(beTrue())
                    }

                    let history = [startFrames[index]] + window.frameHistory
                    expect(self.isMonotonic(history.map { $0.minX })).to(beTrue())
                    expect(self.isMonotonic(history.map { $0.minY })).to(beTrue())
                    expect(self.isMonotonic(history.map { $0.width })).to(beTrue())
                    expect(self.isMonotonic(history.map { $0.height })).to(beTrue())
                }
            }

            it("starts gently") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let operation = self.makeOperation(fixture, clock: clock)

                operation.main()

                let window = fixture.windows[1]
                let target = fixture.operations[1].frameAssignment.finalFrame
                let totalTravel = abs(target.minX - startFrames[1].minX)
                // frameHistory[0] is the in-place resize; frameHistory[1] is the first glide frame.
                let firstStep = abs(window.frameHistory[1].minX - startFrames[1].minX)

                expect(firstStep) < totalTravel / 10
            }

            it("resizes each window once in place, then only moves it") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let operation = self.makeOperation(fixture, clock: clock)

                operation.main()

                let window = fixture.windows[1]
                let target = fixture.operations[1].frameAssignment.finalFrame
                let history = window.frameHistory

                // First write: final size at the original position, issued before the clock started.
                expect(history.first) == CGRect(origin: startFrames[1].origin, size: target.size)
                expect(clock.sleepCount) == operation.tickCount

                // Every glide frame keeps that size; only the settle pass at the very end may differ by rounding.
                for frame in history.dropFirst().dropLast() {
                    expect(frame.size) == target.size
                }
                expect(Set(history.map { "\($0.minX),\($0.minY)" }).count) > 4
            }

            it("skips windows that are already in place") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: [startFrames[0], targetFrames[1]])
                let clock = FakeClock()
                let operation = self.makeOperation(fixture, clock: clock)

                operation.main()

                // The unchanged window only receives the settle pass; the moving window animates.
                expect(fixture.windows[0].frameHistory.count) == 1
                expect(fixture.windows[1].frameHistory.count) > 2
            }

            it("does nothing but settle when no window needs to move") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: startFrames)
                let clock = FakeClock()
                let operation = self.makeOperation(fixture, clock: clock)

                operation.main()

                expect(operation.tickCount) == 0
                expect(clock.sleepCount) == 0
                expect(fixture.windows.map { $0.frameHistory.count }) == [1, 1]
            }

            it("stops without settling when cancelled") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                let operation = self.makeOperation(fixture, clock: clock)
                clock.onSleep = { count in
                    if count == 3 {
                        operation.cancel()
                    }
                }

                operation.main()

                expect(operation.tickCount) == 3
                // The glide stops, but the window is left at its tile rather than mid-way, since no reflow may follow.
                expect(fixture.windows[1].frame()) == fixture.operations[1].frameAssignment.finalFrame
            }

            it("clamps the focused window with the size it asked for while a slow application is still resizing") {
                // The focused window shrinks to 400pt and moves to the right edge of the 2000pt screen. Its application takes
                // longer over the resize than the operation waits before reading sizes back, so the on-screen clamp must use
                // the 400pt size asked for.
                let edgeTarget = CGRect(x: 1600, y: 0, width: 400, height: 1000)
                let fixture = self.makeFixture(startFrames: [startFrames[0]], targetFrames: [edgeTarget], focusedIndex: 0)
                let clock = FakeClock()
                let slow = fixture.windows[0]
                slow.animationFrameDelay = 0.65
                let operation = self.makeOperation(fixture, clock: clock, writesInline: false, drainTimeout: 0.5)

                operation.main()

                // The resize lands first, then the last glide frame, then the settle's writes. Clamped with the 400pt size
                // asked for, the glide nearly reaches the tile.
                expect(slow.frameHistory.count) >= 3
                expect(slow.frameHistory[0].size) == edgeTarget.size
                expect(slow.frameHistory[1].origin.x) > 1500
                expect(slow.frame()) == edgeTarget
            }

            it("leaves windows at their tiles when cancelled right after the in-place resize") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                var operation: AnimatedReflowOperation<TestWindow>!
                // The first frame any window receives is its in-place resize; a new reflow cancels the moment it lands.
                fixture.windows[0].onAnimationFrame = { _ in operation.cancel() }
                operation = self.makeOperation(fixture, clock: clock)

                operation.main()

                expect(operation.tickCount) == 0
                expect(fixture.windows.map { $0.frame() }) == fixture.operations.map { $0.frameAssignment.finalFrame }
            }

            it("leaves windows at their tiles when cancelled while waiting for a slow application after the glide") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let clock = FakeClock()
                var operation: AnimatedReflowOperation<TestWindow>!
                let slow = fixture.windows[1]
                // The glide runs on the fake clock in an instant, so the second frame the slow window receives, its first
                // glide frame, lands while the operation is already waiting for the application after the glide.
                slow.animationFrameDelay = 0.1
                slow.onAnimationFrame = { _ in
                    slow.onAnimationFrame = { _ in operation.cancel() }
                }
                operation = self.makeOperation(fixture, clock: clock, writesInline: false)

                operation.main()

                expect(operation.isCancelled).to(beTrue())
                expect(slow.frame().origin) == fixture.operations[1].frameAssignment.finalFrame.origin
                expect(fixture.windows[0].frame()) == fixture.operations[0].frameAssignment.finalFrame
            }

            it("keeps the focused window on screen") {
                // The target hangs off the right edge of the 2000pt screen; the focused window must be clamped every tick.
                let offscreenTarget = CGRect(x: 1600, y: 0, width: 800, height: 1000)
                let fixture = self.makeFixture(startFrames: [startFrames[0]], targetFrames: [offscreenTarget], focusedIndex: 0)
                let clock = FakeClock()
                let operation = self.makeOperation(fixture, clock: clock)

                operation.main()

                // Every animated frame (all but the settle pass at the end) stays within the screen.
                for frame in fixture.windows[0].frameHistory.dropLast() {
                    expect(frame.maxX) <= 2000
                }
            }

            it("keeps a window that took focus after the layout was planned on screen when settling") {
                // The layout was planned with nothing focused; focus then moved to the window, whose application refuses to
                // shrink below 800pt, so the settle must shift it left to stay within the 2000pt screen.
                let offscreenTarget = CGRect(x: 1600, y: 0, width: 400, height: 1000)
                let fixture = self.makeFixture(startFrames: [startFrames[0]], targetFrames: [offscreenTarget])
                let window = fixture.windows[0]
                window.minimumSize = CGSize(width: 800, height: 1000)
                window.isFocusedValue = true

                fixture.operations[0].frameAssignment.perform(withWindow: window)

                expect(window.frame()) == CGRect(x: 1200, y: 0, width: 800, height: 1000)
            }

            it("keeps the focused window on screen with the size its application kept") {
                // The tile fits the screen, but the app keeps the window 1100 wide, so the glide must clamp with that width.
                let fixture = self.makeFixture(startFrames: [CGRect(x: 0, y: 0, width: 1100, height: 1000)], targetFrames: [CGRect(x: 1500, y: 0, width: 500, height: 1000)], focusedIndex: 0)
                fixture.windows[0].minimumSize = CGSize(width: 1100, height: 1000)
                let clock = FakeClock()
                let operation = self.makeOperation(fixture, clock: clock)

                operation.main()

                for frame in fixture.windows[0].frameHistory {
                    expect(frame.maxX) <= 2000
                }
                expect(fixture.windows[0].frame()) == CGRect(x: 900, y: 0, width: 1100, height: 1000)
            }

            it("lets no queued frame land after the settle when an application outlasts the wait") {
                let fixture = self.makeFixture(startFrames: startFrames, targetFrames: targetFrames)
                let slow = fixture.windows[1]
                slow.animationFrameDelay = 0.6
                let clock = FakeClock()
                let operation = AnimatedReflowOperation(
                    frameAssignmentOperations: fixture.operations,
                    duration: self.duration,
                    frameInterval: self.frameInterval,
                    writesInline: false,
                    now: clock.now,
                    sleep: clock.sleep
                )

                operation.main()

                // The operation waits for its writers before settling and before returning, so nothing is in flight now and
                // the settle's write must be the last thing the window received.
                expect(slow.frameHistory.last) == fixture.operations[1].frameAssignment.finalFrame
                expect(slow.frame()) == fixture.operations[1].frameAssignment.finalFrame
            }

            it("finishes immediately with no assignments") {
                let clock = FakeClock()
                let operation = AnimatedReflowOperation<TestWindow>(
                    frameAssignmentOperations: [],
                    duration: self.duration,
                    frameInterval: self.frameInterval,
                    writesInline: true,
                    now: clock.now,
                    sleep: clock.sleep
                )

                operation.main()

                expect(operation.tickCount) == 0
            }
        }
    }
}
