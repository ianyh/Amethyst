//
//  BackdropCapture.swift
//  Amethyst
//
//  Created by Don Patterson on 9/8/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

/**
 Captures a display with the animating windows removed.

 The snapshot animation shows this frozen backdrop underneath the sliding window images, which lets the real windows be moved to their destinations and re-laid out behind it, out of sight but still on a display where the window server keeps rendering them. That is what makes it possible to capture each window again at its true final size mid-animation.
 */
@available(macOS 14.0, *)
final class BackdropCapturer: @unchecked Sendable {
    static let shared = BackdropCapturer()

    /// Guards `content` and `fetch`; the fetch task updates them without blocking.
    private let stateQueue = DispatchQueue(label: "Amethyst.BackdropCapturer.state")
    private var content: SCShareableContent?
    private var fetch: Task<SCShareableContent?, Never>?

    /// Fetches the current window list in the background. Exclusion needs ScreenCaptureKit's own window objects, which take tens of milliseconds to enumerate.
    func refresh() {
        _ = beginFetch()
    }

    /// The fetch already under way, or a new one. There is never more than one at a time, and whichever it is caches its result when it completes, whether or not anyone is still waiting for it.
    private func beginFetch() -> Task<SCShareableContent?, Never> {
        return stateQueue.sync {
            if let fetch = fetch {
                return fetch
            }

            let fetch = Task { [weak self] () -> SCShareableContent? in
                let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                self?.stateQueue.async {
                    if let content = content {
                        self?.content = content
                    }
                    self?.fetch = nil
                }
                return content
            }
            self.fetch = fetch
            return fetch
        }
    }

    /**
     The window list, fetched now if the cached one is missing any of the given windows, so that a newly opened window or the first reflow after launch never has to do without a backdrop. Blocks for at most `timeout`.
     */
    private func shareableContent(including windowIDs: [CGWindowID], timeout: TimeInterval) -> SCShareableContent? {
        if let cached = stateQueue.sync(execute: { self.content }), contains(cached, windowIDs) {
            return cached
        }

        let fetch = beginFetch()
        let finished = DispatchSemaphore(value: 0)
        let result = Box<SCShareableContent>()

        Task {
            result.value = await fetch.value
            finished.signal()
        }

        guard finished.wait(timeout: .now() + timeout) == .success else {
            return nil
        }

        return result.value
    }

    private func contains(_ content: SCShareableContent, _ windowIDs: [CGWindowID]) -> Bool {
        let known = Set(content.windows.map { $0.windowID })
        return windowIDs.allSatisfy { known.contains($0) }
    }

    /**
     Captures the display containing `screenFrame` without the given windows, blocking the calling thread for at most twice `timeout` (window list, then capture).

     - Parameters:
         - screenFrame: The screen's frame in the flipped coordinates Amethyst uses.
         - windowIDs: Windows to leave out.
     - Returns: The backdrop image at the display's native pixel size, or `nil` if it could not be produced.
     */
    func captureBackdrop(screenFrame: CGRect, excluding windowIDs: [CGWindowID], timeout: TimeInterval = 0.5) -> CGImage? {
        guard let content = shareableContent(including: windowIDs, timeout: timeout) else {
            return nil
        }

        guard let display = ActiveDisplays.mostOverlapping(screenFrame, among: content.displays, bounds: { CGDisplayBounds($0.displayID) }) else {
            return nil
        }

        let excluded = content.windows.filter { windowIDs.contains($0.windowID) }
        guard excluded.count == windowIDs.count else {
            return nil
        }

        let pixelWidth = CGDisplayCopyDisplayMode(display.displayID)?.pixelWidth ?? display.width
        let scale = display.width > 0 ? CGFloat(pixelWidth) / CGFloat(display.width) : 1

        let configuration = SCStreamConfiguration()
        configuration.width = Int(CGFloat(display.width) * scale)
        configuration.height = Int(CGFloat(display.height) * scale)
        configuration.showsCursor = false
        configuration.captureResolution = .best

        let filter = SCContentFilter(display: display, excludingWindows: excluded)
        let finished = DispatchSemaphore(value: 0)
        let result = Box<CGImage>()

        Task {
            result.value = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            finished.signal()
        }

        guard finished.wait(timeout: .now() + timeout) == .success else {
            return nil
        }

        return result.value
    }

    /**
     Captures whole windows regardless of which displays they lie on, at the pixel density of the display each is mostly on.

     - Returns: One image per request, in order, or `nil` if any window is unknown or fails to capture within `timeout`.
     */
    func captureWindows(_ requests: [WindowCaptureRequest], timeout: TimeInterval = 0.5) -> [CGImage]? {
        guard !requests.isEmpty, let content = shareableContent(including: requests.map { $0.windowID }, timeout: timeout) else {
            return nil
        }

        let windowsByID = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })

        let finished = DispatchSemaphore(value: 0)
        let results = Box<[Int: CGImage]>()
        results.value = [:]

        for (index, request) in requests.enumerated() {
            guard let window = windowsByID[request.windowID] else {
                return nil
            }

            let scale = pixelScale(forWindowFrame: request.frame, among: content.displays)
            let width = request.frame.width * scale
            let height = request.frame.height * scale
            guard width.isFinite, height.isFinite, width >= 1, height >= 1 else {
                return nil
            }

            let configuration = SCStreamConfiguration()
            configuration.width = Int(width)
            configuration.height = Int(height)
            configuration.showsCursor = false
            configuration.captureResolution = .best
            let filter = SCContentFilter(desktopIndependentWindow: window)

            Task { [stateQueue] in
                let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                // Record on the state queue and signal from there, so the waiting thread sees the write once it wakes.
                stateQueue.async {
                    if let image = image {
                        results.value?[index] = image
                    }
                    finished.signal()
                }
            }
        }

        let deadline = DispatchTime.now() + timeout
        for _ in requests where finished.wait(timeout: deadline) != .success {
            return nil
        }

        let images: [CGImage] = stateQueue.sync { requests.indices.compactMap { results.value?[$0] } }
        return images.count == requests.count ? images : nil
    }

    /// Pixels per point of the display a window is mostly on.
    private func pixelScale(forWindowFrame frame: CGRect, among displays: [SCDisplay]) -> CGFloat {
        guard let display = ActiveDisplays.mostOverlapping(frame, among: displays, bounds: { CGDisplayBounds($0.displayID) }),
              let mode = CGDisplayCopyDisplayMode(display.displayID) else {
            return 1
        }
        let width = CGDisplayBounds(display.displayID).width
        return width > 0 ? CGFloat(mode.pixelWidth) / width : 1
    }

    /// Hands a value from an async task back to the waiting thread; the semaphore orders the accesses.
    private final class Box<Value>: @unchecked Sendable {
        var value: Value?
    }
}
