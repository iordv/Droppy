import AppKit
import QuartzCore

private final class MotionCompletionBox: @unchecked Sendable {
    let completion: (() -> Void)?

    init(_ completion: (() -> Void)?) {
        self.completion = completion
    }
}

@MainActor
enum AppKitMotion {
    private static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private static let openTiming = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
    private static let closeTiming = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)

    @discardableResult
    private static func ensureLayer(on view: NSView?) -> CALayer? {
        guard let view else { return nil }
        if !view.wantsLayer {
            view.wantsLayer = true
        }
        view.layerContentsRedrawPolicy = .onSetNeedsDisplay

        guard let layer = view.layer else { return nil }

        let noAction = NSNull()
        layer.actions = [
            "position": noAction,
            "bounds": noAction,
            "frame": noAction,
            "transform": noAction,
            "opacity": noAction,
            "contents": noAction
        ]
        return layer
    }

    static func prepareForPresent(_ window: NSWindow, initialScale: CGFloat = 0.9) {
        let startScale = reduceMotion ? 1.0 : initialScale
        window.alphaValue = 0

        guard let layer = ensureLayer(on: window.contentView) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = 0
        layer.transform = CATransform3DMakeScale(startScale, startScale, 1.0)
        CATransaction.commit()
    }

    static func animateIn(
        _ window: NSWindow,
        initialScale: CGFloat = 0.9,
        duration: TimeInterval = 0.24,
        completion: (() -> Void)? = nil
    ) {
        let startScale = reduceMotion ? 1.0 : initialScale
        let tunedDuration = reduceMotion ? min(duration, 0.16) : duration
        let completionBox = MotionCompletionBox(completion)

        if let layer = ensureLayer(on: window.contentView) {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = tunedDuration
            fade.timingFunction = openTiming
            layer.add(fade, forKey: "droppy.fadeIn")

            if !reduceMotion {
                let scale = CASpringAnimation(keyPath: "transform.scale")
                scale.fromValue = startScale
                scale.toValue = 1.0
                scale.mass = 1.0
                scale.stiffness = 260
                scale.damping = 24
                scale.initialVelocity = 0
                scale.duration = max(tunedDuration, min(scale.settlingDuration, tunedDuration + 0.12))
                scale.timingFunction = openTiming
                layer.add(scale, forKey: "droppy.scaleIn")
            }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.opacity = 1
            layer.transform = CATransform3DIdentity
            CATransaction.commit()
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = tunedDuration
            context.timingFunction = openTiming
            window.animator().alphaValue = 1
        }, completionHandler: {
            completionBox.completion?()
        })
    }

    static func animateOut(
        _ window: NSWindow,
        targetScale: CGFloat = 0.96,
        duration: TimeInterval = 0.18,
        completion: (() -> Void)? = nil
    ) {
        let endScale = reduceMotion ? 1.0 : targetScale
        let tunedDuration = reduceMotion ? min(duration, 0.14) : duration
        let completionBox = MotionCompletionBox(completion)

        if let layer = ensureLayer(on: window.contentView) {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = tunedDuration
            fade.timingFunction = closeTiming
            layer.add(fade, forKey: "droppy.fadeOut")

            if !reduceMotion {
                let scale = CABasicAnimation(keyPath: "transform.scale")
                scale.fromValue = 1.0
                scale.toValue = endScale
                scale.duration = tunedDuration
                scale.timingFunction = closeTiming
                layer.add(scale, forKey: "droppy.scaleOut")
            }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.opacity = 0
            layer.transform = CATransform3DMakeScale(endScale, endScale, 1.0)
            CATransaction.commit()
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = tunedDuration
            context.timingFunction = closeTiming
            window.animator().alphaValue = 0
        }, completionHandler: {
            completionBox.completion?()
        })
    }

    static func resetPresentationState(_ window: NSWindow) {
        window.alphaValue = 1
        guard let layer = ensureLayer(on: window.contentView) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = 1
        layer.transform = CATransform3DIdentity
        CATransaction.commit()
    }

    static func animateFrame(_ window: NSWindow, to frame: NSRect, duration: TimeInterval = 0.22) {
        if reduceMotion {
            window.setFrame(frame, display: true, animate: false)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = openTiming
            context.allowsImplicitAnimation = true
            window.animator().setFrame(frame, display: true)
        }
    }
}
