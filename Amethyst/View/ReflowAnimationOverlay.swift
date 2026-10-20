//
//  ReflowAnimationOverlay.swift
//  Amethyst
//
//  Created by Don Patterson on 9/8/26.
//  Copyright © 2026 Ian Ynda-Hummel. All rights reserved.
//

import Cocoa
import QuartzCore

/// A captured window image and where it should travel, in the flipped (Accessibility) coordinate space Amethyst uses for frames.
struct SnapshotProxy {
    let image: CGImage
    let start: CGRect
    let target: CGRect
}

/// Something that can show window snapshots on screen and slide them. All methods are called on the main thread.
protocol SnapshotAnimating: AnyObject {
    /// Shows the proxies at their start frames, covering the real windows. With a `backdrop`, an opaque image of the screen sits beneath them so the real windows can move behind it unseen.
    func show(proxies: [SnapshotProxy], screenFrame: CGRect, backdrop: CGImage?)

    /**
     Cross-dissolves proxies to fresh images of their windows over `duration`, so they land showing the real final rendering rather than a stretched old one.

     `images` is indexed like the proxies given to `show`; `nil` leaves a proxy alone. `completion` runs on the main thread when the dissolve has finished.
     */
    func crossfade(images: [CGImage?], duration: TimeInterval, completion: (() -> Void)?)

    /// Slides every proxy to its target frame. `completion` runs on the main thread when the motion has finished.
    func animate(duration: TimeInterval, completion: @escaping () -> Void)

    /**
     Steers proxies that are already moving to new frames, from wherever they currently are, over `duration`.

     `frames` is indexed like the proxies given to `show`; `nil` leaves a proxy alone. A non-nil `completion` replaces the pending one, which is called first; otherwise the completion given to `animate` still fires when the last motion ends.
     */
    func retarget(frames: [CGRect?], duration: TimeInterval, completion: (() -> Void)?)

    /// Where each proxy currently appears on screen, in flipped coordinates and in the order given to `show`.
    func presentationFrames() -> [CGRect]

    /**
     Fades the overlay out over the real windows and removes it. `completion` runs on the main thread afterwards.

     Proxies listed in `lingering` never received a fresh image of their window; they dissolve over the longer `lingerDuration` so the stretched image blends into the real window rather than cutting to it.
     */
    func finish(fadeDuration: TimeInterval, lingering: [Int], lingerDuration: TimeInterval, completion: @escaping () -> Void)

    /// Hides individual proxies at once, for windows Amethyst has moved elsewhere mid-animation.
    func hide(indices: [Int])

    /// Removes the proxies immediately.
    func cancel()
}

/// Conversions between AppKit's bottom-left coordinates and the top-left, primary-screen-relative coordinates used by Accessibility and Amethyst's layouts. Same flip Silica applies to screen frames.
enum FlippedCoordinates {
    static var primaryScreenHeight: CGFloat {
        return NSScreen.screens.first?.frame.height ?? 0
    }

    static func appKitRect(fromFlipped rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        return CGRect(x: rect.minX, y: primaryScreenHeight - rect.height - rect.minY, width: rect.width, height: rect.height)
    }

    static func flippedRect(fromAppKit rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        // The flip is its own inverse.
        return appKitRect(fromFlipped: rect, primaryScreenHeight: primaryScreenHeight)
    }
}

/**
 A click-through panel that shows captured window images and slides them with Core Animation.

 The panel is never managed by Amethyst because Amethyst's own process is not a regular application, and `sharingType = .none` keeps it out of any later capture.
 */
final class ReflowAnimationOverlay: SnapshotAnimating {
    /// Marks the overlay's panel so stray ones can be found, for example by tests.
    static let panelIdentifier = NSUserInterfaceItemIdentifier("AmethystReflowAnimationOverlay")

    /// How many overlay panels the application currently has on screen. A closed panel may stay allocated for a while, held by AppKit; only visible ones count.
    static var livePanelCount: Int {
        return NSApplication.shared.windows.filter { $0.identifier == panelIdentifier && $0.isVisible }.count
    }

    private var panel: NSPanel?
    private var backdropLayer: CALayer?
    private var layers: [CALayer] = []
    private var proxies: [SnapshotProxy] = []
    private var primaryScreenHeight: CGFloat = 0

    /// Completion of the most recent `animate` or `retarget`. Only the latest batch of animations may fire it.
    private var completion: (() -> Void)?
    private var generation = 0

    func show(proxies: [SnapshotProxy], screenFrame: CGRect, backdrop: CGImage?) {
        primaryScreenHeight = FlippedCoordinates.primaryScreenHeight
        let appKitScreenFrame = FlippedCoordinates.appKitRect(fromFlipped: screenFrame, primaryScreenHeight: primaryScreenHeight)
        let screen = NSScreen.screens.max { lhs, rhs in
            area(lhs.frame.intersection(appKitScreenFrame)) < area(rhs.frame.intersection(appKitScreenFrame))
        }
        let panelFrame = screen?.frame ?? appKitScreenFrame

        let panel = NSPanel(contentRect: panelFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // The panel belongs to the Space it was made on: a reflow only runs on the active Space, and a Space switch
        // carries the picture away with that Space.
        panel.collectionBehavior = [.ignoresCycle, .fullScreenAuxiliary]
        panel.sharingType = .none
        panel.animationBehavior = .none
        panel.identifier = ReflowAnimationOverlay.panelIdentifier

        let contentView = NSView(frame: NSRect(origin: .zero, size: panelFrame.size))
        contentView.wantsLayer = true
        panel.contentView = contentView

        let scale = screen?.backingScaleFactor ?? 2

        if let backdrop = backdrop {
            let backdropLayer = CALayer()
            backdropLayer.contents = backdrop
            backdropLayer.contentsGravity = .resize
            backdropLayer.contentsScale = scale
            backdropLayer.frame = contentView.bounds
            backdropLayer.actions = ["contents": NSNull(), "opacity": NSNull()]
            contentView.layer?.addSublayer(backdropLayer)
            self.backdropLayer = backdropLayer
        }

        var layers: [CALayer] = []
        for proxy in proxies {
            let layer = CALayer()
            layer.contents = proxy.image
            layer.contentsGravity = .resize
            layer.contentsScale = scale
            layer.frame = layerFrame(for: proxy.start, panelFrame: panelFrame)
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOpacity = 0.4
            layer.shadowRadius = 16
            layer.shadowOffset = CGSize(width: 0, height: -8)
            // Drive every change explicitly; implicit animations would fight the glide.
            layer.actions = ["position": NSNull(), "bounds": NSNull(), "opacity": NSNull(), "contents": NSNull()]
            contentView.layer?.addSublayer(layer)
            layers.append(layer)
        }

        self.panel = panel
        self.layers = layers
        self.proxies = proxies

        panel.orderFrontRegardless()
        CATransaction.flush()
    }

    func animate(duration: TimeInterval, completion: @escaping () -> Void) {
        guard let panel = panel else {
            completion()
            return
        }

        fireCompletion()
        self.completion = completion
        let frames = proxies.map { Optional($0.target) }
        glide(layerIndices: Array(layers.indices), to: frames, duration: duration, timing: CAMediaTimingFunction(name: .easeInEaseOut), panel: panel)
    }

    func retarget(frames: [CGRect?], duration: TimeInterval, completion: (() -> Void)?) {
        if let completion = completion {
            fireCompletion()
            self.completion = completion
        }

        let indices = layers.indices.filter { $0 < frames.count && frames[$0] != nil }

        guard let panel = panel, !indices.isEmpty else {
            if completion != nil {
                fireCompletion()
            }
            return
        }

        for index in indices {
            if let frame = frames[index] {
                proxies[index] = SnapshotProxy(image: proxies[index].image, start: proxies[index].start, target: frame)
            }
        }

        glide(layerIndices: indices, to: frames, duration: duration, timing: CAMediaTimingFunction(name: .easeOut), panel: panel)
    }

    /// Animates the given layers from wherever they currently appear to their new frames. Replacing a running animation is what makes retargeting seamless.
    private func glide(layerIndices: [Int], to frames: [CGRect?], duration: TimeInterval, timing: CAMediaTimingFunction, panel: NSPanel) {
        generation += 1
        let thisGeneration = generation

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self = self, self.generation == thisGeneration else {
                return
            }
            self.fireCompletion()
        }

        for index in layerIndices {
            guard let frame = frames[index] else {
                continue
            }

            let layer = layers[index]
            let current = layer.presentation() ?? layer
            let targetFrame = layerFrame(for: frame, panelFrame: panel.frame)
            let targetBounds = CGRect(origin: .zero, size: targetFrame.size)
            let targetPosition = CGPoint(x: targetFrame.midX, y: targetFrame.midY)

            let bounds = CABasicAnimation(keyPath: "bounds")
            bounds.fromValue = current.bounds
            bounds.toValue = targetBounds

            let position = CABasicAnimation(keyPath: "position")
            position.fromValue = current.position
            position.toValue = targetPosition

            let group = CAAnimationGroup()
            group.animations = [bounds, position]
            group.duration = duration
            group.timingFunction = timing

            layer.bounds = targetBounds
            layer.position = targetPosition
            layer.add(group, forKey: "glide")
        }

        CATransaction.commit()
    }

    private func fireCompletion() {
        guard let completion = completion else {
            return
        }
        self.completion = nil
        completion()
    }

    func crossfade(images: [CGImage?], duration: TimeInterval, completion: (() -> Void)?) {
        let indices = layers.indices.filter { $0 < images.count && images[$0] != nil }

        guard panel != nil, !indices.isEmpty else {
            completion?()
            return
        }

        CATransaction.begin()
        if let completion = completion {
            CATransaction.setCompletionBlock(completion)
        }

        for index in indices {
            guard let image = images[index] else {
                continue
            }

            let layer = layers[index]
            let dissolve = CABasicAnimation(keyPath: "contents")
            dissolve.fromValue = layer.presentation()?.contents ?? layer.contents
            dissolve.toValue = image
            dissolve.duration = duration
            // Ease out: bring the fresh rendering in quickly, then let the last of the old image linger briefly.
            dissolve.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.contents = image
            layer.add(dissolve, forKey: "dissolve")
        }

        CATransaction.commit()
    }

    func presentationFrames() -> [CGRect] {
        guard let panel = panel else {
            return proxies.map { $0.target }
        }

        return layers.map { layer in
            let frame = (layer.presentation() ?? layer).frame.offsetBy(dx: panel.frame.minX, dy: panel.frame.minY)
            return FlippedCoordinates.flippedRect(fromAppKit: frame, primaryScreenHeight: primaryScreenHeight)
        }
    }

    func finish(fadeDuration: TimeInterval, lingering: [Int], lingerDuration: TimeInterval, completion: @escaping () -> Void) {
        guard panel != nil, fadeDuration > 0 else {
            tearDown()
            completion()
            return
        }

        // Nothing else holds the overlay once the reflow operation returns, so the completion keeps it alive until the
        // panel has been taken down. A fallback timer takes the panel down even if the render server never reports the
        // fade complete.
        var finished = false
        let finishOnce = {
            guard !finished else {
                return
            }
            finished = true
            self.tearDown()
            completion()
        }
        let longestFade = max(fadeDuration, lingering.isEmpty ? 0 : lingerDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + longestFade + 0.5, execute: finishOnce)

        CATransaction.begin()
        CATransaction.setCompletionBlock(finishOnce)

        // The backdrop and refreshed proxies fade quickly over windows that already show what they show; proxies that never
        // got a fresh image dissolve slowly into the real window now revealed beneath them.
        let lingering = Set(lingering)
        let fading = [backdropLayer].compactMap { $0 }.map { ($0, fadeDuration) } + layers.enumerated().map { ($1, lingering.contains($0) ? lingerDuration : fadeDuration) }
        for (layer, duration) in fading {
            let fade = CABasicAnimation(keyPath: "opacity")
            // From the current opacity, so a picture hidden earlier does not reappear for the length of the fade.
            fade.fromValue = layer.opacity
            fade.toValue = 0
            fade.duration = duration
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.opacity = 0
            layer.add(fade, forKey: "fade")
        }

        CATransaction.commit()
    }

    func hide(indices: [Int]) {
        // Opacity carries no implicit animation here and leaves the picture's motion running unseen, so hiding one
        // picture neither snaps it nor ends the batch of motion the other pictures are still in.
        for index in indices where index < layers.count {
            layers[index].opacity = 0
        }
    }

    func cancel() {
        layers.forEach { $0.removeAllAnimations() }
        tearDown()
    }

    /// Takes the panel down and calls any completion still pending, so every completion the overlay accepted is called
    /// exactly once.
    private func tearDown() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        backdropLayer = nil
        layers = []
        proxies = []
        fireCompletion()
    }

    private func layerFrame(for flipped: CGRect, panelFrame: CGRect) -> CGRect {
        return FlippedCoordinates.appKitRect(fromFlipped: flipped, primaryScreenHeight: primaryScreenHeight)
            .offsetBy(dx: -panelFrame.minX, dy: -panelFrame.minY)
    }

    private func area(_ rect: CGRect) -> CGFloat {
        return rect.isNull ? 0 : rect.width * rect.height
    }
}
