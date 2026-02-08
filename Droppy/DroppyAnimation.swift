//
//  DroppyAnimation.swift
//  Droppy
//
//  Single Source of Truth for all animations.
//  Ultra-smooth animations matching Apple's buttery feel.
//

import SwiftUI
import AppKit

// MARK: - Animation Constants (SSOT)

/// Single Source of Truth for Droppy's animation system.
/// v9.2.1: Matches Apple's animation patterns for buttery smoothness.
enum DroppyAnimation {
    // MARK: - Display-Aware Motion Tuning

    /// Respect system preference and lower-motion contexts.
    private static var prefersReducedMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Lower GPU pressure when battery/thermal budgets are constrained.
    private static var isLowPowerMode: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    /// Best available refresh rate for a specific screen (or all attached screens).
    private static func refreshRate(for screen: NSScreen?) -> Int {
        if let screen {
            return max(screen.maximumFramesPerSecond, 60)
        }

        // Prefer the screen currently under the cursor (best proxy for active interaction),
        // then fallback to main/first screen.
        let mouse = NSEvent.mouseLocation
        if let underMouse = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
            return max(underMouse.maximumFramesPerSecond, 60)
        }

        if let main = NSScreen.main {
            return max(main.maximumFramesPerSecond, 60)
        }

        if let first = NSScreen.screens.first {
            return max(first.maximumFramesPerSecond, 60)
        }

        return 60
    }

    /// Slightly lengthen motion on lower-refresh displays so frame stepping is less visible.
    private static func motionScale(for screen: NSScreen?) -> Double {
        let fps = refreshRate(for: screen)
        if fps >= 100 { return 1.0 }   // ProMotion / high-refresh
        if fps >= 75 { return 1.1 }    // 75-99Hz panels
        return 1.18                    // 60Hz panels
    }

    private static func tuned(_ base: Double, for screen: NSScreen? = nil) -> Double {
        base * motionScale(for: screen)
    }

    private static func shouldPreferLightweightEffects(for screen: NSScreen? = nil) -> Bool {
        prefersReducedMotion || isLowPowerMode || refreshRate(for: screen) <= 60
    }
    
    // MARK: - Asymmetric Expand/Collapse (Apple-Style Animation)
    
    /// Asymmetric expand animation - bouncy, alive feel.
    /// APPLE-STYLE: spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    /// Use for: shelf opening, notch expanding, panels appearing.
    static var expandOpen: Animation {
        expandOpen(for: nil)
    }

    static func expandOpen(for screen: NSScreen?) -> Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.26, for: screen))
        }
        return Animation.spring(response: tuned(0.4, for: screen), dampingFraction: 0.9, blendDuration: 0)
    }
    
    /// Asymmetric collapse animation - critically damped, buttery smooth.
    /// APPLE-STYLE: spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
    /// Use for: shelf closing, notch collapsing, panels disappearing.
    static var expandClose: Animation {
        expandClose(for: nil)
    }

    static func expandClose(for screen: NSScreen?) -> Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.24, for: screen))
        }
        return Animation.spring(response: tuned(0.36, for: screen), dampingFraction: 0.97, blendDuration: 0)
    }
    
    // MARK: - Interactive Spring (Apple-Style Animation)
    
    /// Interactive spring for user actions - immediate, responsive.
    /// APPLE-STYLE: interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
    /// Use for: hover states, open/close triggers, gesture feedback.
    static var interactive: Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.18))
        }
        return Animation.interactiveSpring(response: tuned(0.3), dampingFraction: 0.84, blendDuration: 0)
    }
    
    // MARK: - Apple Smooth Preset (Apple-Style Animation)
    
    /// Apple's .smooth preset - buttery content transitions.
    /// APPLE-STYLE uses .smooth throughout for gesture and content animations.
    /// Use for: content appearing/disappearing, gesture feedback.
    static var smooth: Animation {
        if #available(macOS 14.0, *) {
            return Animation.smooth
        } else {
            return Animation.easeInOut(duration: tuned(0.3))
        }
    }
    
    /// Apple's .smooth with custom duration for content transitions.
    /// APPLE-STYLE: .smooth(duration: 0.35) for content transitions.
    static var smoothContent: Animation {
        smoothContent(for: nil)
    }

    static func smoothContent(for screen: NSScreen?) -> Animation {
        let duration = tuned(0.36, for: screen)
        if #available(macOS 14.0, *) {
            return Animation.smooth(duration: duration)
        } else {
            return Animation.easeInOut(duration: duration)
        }
    }
    
    // MARK: - Apple Optimized Presets (macOS 14+)
    
    /// Apple's hardware-optimized bouncy preset.
    /// Tuned for 120Hz ProMotion displays, falls back to custom curve on older systems.
    static var bouncy: Animation {
        if #available(macOS 14.0, *) {
            return Animation.spring(.bouncy(duration: tuned(0.34)))
        } else {
            // Fallback: Custom smooth curve for older systems
            return Animation.timingCurve(0.16, 1, 0.3, 1, duration: tuned(0.5))
        }
    }
    
    /// Apple's smooth preset for hover states.
    /// Provides buttery hover feedback on ProMotion displays.
    static var hoverSmooth: Animation {
        if #available(macOS 14.0, *) {
            return Animation.smooth(duration: tuned(0.24))
        } else {
            return hover
        }
    }
    
    // MARK: - Premium Animation Patterns
    
    /// PREMIUM: .bouncy.speed(1.2) - fast, snappy hover animation.
    /// Use for: hover states, button feedback, interactive elements.
    static var hoverBouncy: Animation {
        hoverBouncy(for: nil)
    }

    static func hoverBouncy(for screen: NSScreen?) -> Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.18, for: screen))
        }
        if #available(macOS 14.0, *) {
            return Animation.spring(.bouncy(duration: tuned(0.3, for: screen)))
        } else {
            return Animation.spring(response: tuned(0.28, for: screen), dampingFraction: 0.82)
        }
    }
    
    /// PREMIUM: .spring.speed(1.2) - fast notch state animation.
    /// Use for: notch open/close state changes.
    static var notchState: Animation {
        notchState(for: nil)
    }

    static func notchState(for screen: NSScreen?) -> Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.2, for: screen))
        }
        if #available(macOS 14.0, *) {
            return Animation.spring(response: tuned(0.34, for: screen), dampingFraction: 0.9, blendDuration: 0)
        } else {
            return Animation.spring(response: tuned(0.34, for: screen), dampingFraction: 0.88)
        }
    }
    
    /// PREMIUM: DroppyAnimation.viewChange - view transitions.
    /// Use for: switching between different views/content.
    static var viewChange: Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.18))
        }
        return Animation.easeInOut(duration: tuned(0.28))
    }
    
    /// PREMIUM: .interactiveSpring(dampingFraction: 1.2) - overdamped blur replace.
    /// Use for: content replacements with blurReplace transition.
    static var blurReplace: Animation {
        prefersReducedMotion
            ? Animation.easeOut(duration: tuned(0.18))
            : Animation.interactiveSpring(dampingFraction: 1.1)
    }
    
    // MARK: - Hover Animations
    
    /// Standard hover animation - smooth, responsive, slight bounce.
    /// Use for: buttons, cards, list items, interactive elements.
    static var hover: Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.14))
        }
        return Animation.spring(response: tuned(0.24), dampingFraction: 0.8)
    }
    
    /// Quick hover animation - instant feedback, no bounce.
    /// Use for: small indicators, icons, subtle state changes.
    static var hoverQuick: Animation {
        Animation.easeOut(duration: tuned(0.1))
    }
    
    /// Buttery smooth hover scale animation - premium feel.
    /// Use for: notch/island hover feedback, "ready to expand" preview.
    /// Parameters tuned for subtle, damped response matching Apple's feel.
    static var hoverScale: Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.12))
        }
        return Animation.spring(response: tuned(0.36), dampingFraction: 0.9, blendDuration: 0)
    }
    
    // MARK: - State Transitions
    
    /// Standard state change - natural, fluid.
    /// Use for: toggle states, selection changes, mode switches.
    static var state: Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.18))
        }
        return Animation.spring(response: tuned(0.24), dampingFraction: 0.82)
    }
    
    /// Emphasized state change - bouncy, noticeable.
    /// Use for: favorites, flags, important state changes.
    static var stateEmphasis: Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.2))
        }
        return Animation.spring(response: tuned(0.28), dampingFraction: 0.72)
    }
    
    /// Icon bounce animation - playful, attention-grabbing.
    /// Use for: toggle icon animations, success feedback.
    static var bounce: Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.2))
        }
        return Animation.spring(response: tuned(0.18), dampingFraction: 0.56)
    }
    
    // MARK: - Layout Animations
    
    /// List reordering animation - smooth, avoids jank.
    /// Use for: sorting, filtering, item insertion/removal.
    static var listChange: Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.2))
        }
        return Animation.spring(response: tuned(0.26), dampingFraction: 0.84)
    }
    
    /// View transitions - elegant entrance/exit.
    /// Use for: sheets, popovers, panels appearing/disappearing.
    static var transition: Animation {
        transition(for: nil)
    }

    static func transition(for screen: NSScreen?) -> Animation {
        if prefersReducedMotion {
            return Animation.easeOut(duration: tuned(0.24, for: screen))
        }
        return Animation.spring(response: tuned(0.34, for: screen), dampingFraction: 0.88)
    }
    
    /// Overdamped view transition - buttery cross-fades with no wobble.
    /// Use for: view swaps, content replacements, HUD transitions.
    static var viewTransition: Animation {
        prefersReducedMotion
            ? Animation.easeOut(duration: tuned(0.2))
            : Animation.interactiveSpring(dampingFraction: 1.1)
    }
    
    // MARK: - Interactive Animations
    
    /// Press feedback - immediate response.
    /// Use for: button press down state.
    static var press: Animation {
        Animation.interactiveSpring(response: tuned(0.14), dampingFraction: 0.82)
    }
    
    /// Release feedback - natural bounce back.
    /// Use for: button release, drag end.
    static var release: Animation {
        Animation.spring(response: tuned(0.24), dampingFraction: 0.74)
    }
    
    /// Drag tracking - follows finger precisely.
    /// Use for: active dragging, live updates.
    static var drag: Animation {
        Animation.interactiveSpring(response: tuned(0.1), dampingFraction: 0.9)
    }
    
    /// Real-time tracking - Apple's .smooth preset for gesture following.
    /// Use for: slider drags, scroll tracking, gesture progress.
    /// Apple pattern: `.animation(.smooth, value: gestureProgress)`
    static var tracking: Animation {
        if #available(macOS 14.0, *) {
            return Animation.smooth
        } else {
            return Animation.easeOut(duration: tuned(0.12))
        }
    }
    
    // MARK: - Two-Phase Press Effects
    
    /// Phase 1: Quick snap on press down.
    /// Fast response (0.2s) with lower damping (0.55) for snappy feel.
    static var pressSnap: Animation {
        Animation.spring(response: tuned(0.18), dampingFraction: 0.62)
    }
    
    /// Phase 2: Slower settle on release.
    /// Slightly slower (0.28s) with higher damping (0.72) for smooth recovery.
    static var pressSettle: Animation {
        Animation.spring(response: tuned(0.24), dampingFraction: 0.78)
    }
    
    // MARK: - Scale Animations
    
    /// Hover scale animation (small).
    /// Use for: subtle hover feedback on cards.
    static var scaleHover: Animation {
        Animation.spring(response: tuned(0.24), dampingFraction: 0.8)
    }
    
    /// Pop scale animation.
    /// Use for: attention-grabbing effects, notifications.
    static var scalePop: Animation {
        Animation.spring(response: tuned(0.24), dampingFraction: 0.64)
    }
    
    // MARK: - Timing Curves (for non-spring animations)
    
    /// Smooth ease-out curve.
    static var easeOut: Animation {
        Animation.easeOut(duration: tuned(0.18))
    }

    /// Duration-based ease-out curve that still respects display tuning.
    static func easeOut(duration: Double, for screen: NSScreen? = nil) -> Animation {
        Animation.easeOut(duration: tuned(duration, for: screen))
    }
    
    /// Smooth ease-in-out curve.
    static var easeInOut: Animation {
        Animation.easeInOut(duration: tuned(0.2))
    }

    /// Duration-based ease-in-out curve that still respects display tuning.
    static func easeInOut(duration: Double, for screen: NSScreen? = nil) -> Animation {
        Animation.easeInOut(duration: tuned(duration, for: screen))
    }

    /// Duration-based smooth curve with display-aware tuning.
    static func smooth(duration: Double, for screen: NSScreen? = nil) -> Animation {
        let tunedDuration = tuned(duration, for: screen)
        if #available(macOS 14.0, *) {
            return Animation.smooth(duration: tunedDuration)
        } else {
            return Animation.easeInOut(duration: tunedDuration)
        }
    }

    /// Display-aware interactive spring helper for micro interactions.
    static func interactiveSpring(response: Double, dampingFraction: Double, for screen: NSScreen? = nil) -> Animation {
        Animation.interactiveSpring(response: tuned(response, for: screen), dampingFraction: dampingFraction, blendDuration: 0)
    }
    
    // MARK: - Media Player Animations
    
    /// Media button press - quick, snappy response for play/pause/skip.
    /// Exact match: response: 0.16, dampingFraction: 0.72
    static var mediaPress: Animation {
        Animation.spring(response: tuned(0.15), dampingFraction: 0.76)
    }
    
    /// Media button release - smooth settle after press.
    /// Exact match: response: 0.26, dampingFraction: 0.8
    static var mediaRelease: Animation {
        Animation.spring(response: tuned(0.22), dampingFraction: 0.84)
    }
    
    /// Media emphasis - bouncy attention-grabbing effect.
    /// Exact match: response: 0.18, dampingFraction: 0.52
    static var mediaEmphasis: Animation {
        Animation.spring(response: tuned(0.16), dampingFraction: 0.62)
    }
    
    /// Media settle - smooth recovery after emphasis.
    /// Exact match: response: 0.32, dampingFraction: 0.76
    static var mediaSettle: Animation {
        Animation.spring(response: tuned(0.26), dampingFraction: 0.82)
    }
    
    // MARK: - Onboarding Animations
    
    /// Onboarding bounce - playful, attention-grabbing.
    /// Exact match: response: 0.2, dampingFraction: 0.45
    static var onboardingBounce: Animation {
        Animation.spring(response: tuned(0.2), dampingFraction: 0.5)
    }
    
    /// Onboarding settle - comfortable recovery.
    /// Exact match: response: 0.35, dampingFraction: 0.55
    static var onboardingSettle: Animation {
        Animation.spring(response: tuned(0.3), dampingFraction: 0.62)
    }
    
    /// Onboarding pop - extra bouncy for emphasis.
    /// Exact match: response: 0.2, dampingFraction: 0.4
    static var onboardingPop: Animation {
        Animation.spring(response: tuned(0.18), dampingFraction: 0.48)
    }
    
    // MARK: - Basket/Shelf Animations
    
    /// Basket transition - smooth slot count and layout changes.
    /// Exact match: response: 0.4, dampingFraction: 0.8
    static var basketTransition: Animation {
        basketTransition(for: nil)
    }

    static func basketTransition(for screen: NSScreen?) -> Animation {
        Animation.spring(response: tuned(0.3, for: screen), dampingFraction: 0.86)
    }
    
    /// Item insertion - slightly quicker than transition.
    /// Exact match: response: 0.35, dampingFraction: 0.7
    static var itemInsertion: Animation {
        itemInsertion(for: nil)
    }

    static func itemInsertion(for screen: NSScreen?) -> Animation {
        Animation.spring(response: tuned(0.26, for: screen), dampingFraction: 0.8)
    }
    
    
    // MARK: - Notch View Transition
    
    /// Premium view transition: scale(0.8, anchor: .top) + blur + opacity with smooth duration.
    /// Matches the premiumHUD transition pattern for consistent visual language.
    static var notchViewTransition: AnyTransition {
        notchViewTransition(for: nil)
    }

    static func notchViewTransition(for screen: NSScreen?) -> AnyTransition {
        if shouldPreferLightweightEffects(for: screen) {
            return notchViewTransitionLight(for: screen)
        }

        return .modifier(
            active: NotchBlurModifier(scale: 0.86, blur: 6, opacity: 0),
            identity: NotchBlurModifier(scale: 1, blur: 0, opacity: 1)
        ).animation(smoothContent(for: screen))
    }
    
    /// PERFORMANCE: Lightweight transition for complex views (grids with many children).
    /// Uses scale + opacity only (no blur) to avoid expensive per-child blur calculations.
    /// Visual result is nearly identical at animation speeds, but much smoother.
    static var notchViewTransitionLight: AnyTransition {
        notchViewTransitionLight(for: nil)
    }

    static func notchViewTransitionLight(for screen: NSScreen?) -> AnyTransition {
        .modifier(
            active: NotchBlurModifier(scale: 0.85, blur: 0, opacity: 0),
            identity: NotchBlurModifier(scale: 1, blur: 0, opacity: 1)
        ).animation(smoothContent(for: screen))
    }

    /// Constraint-safe premium transition for AppKit-hosted views:
    /// blur + opacity only, without scale transforms.
    static var notchViewTransitionBlurOnly: AnyTransition {
        notchViewTransitionBlurOnly(for: nil)
    }

    static func notchViewTransitionBlurOnly(for screen: NSScreen?) -> AnyTransition {
        let blurRadius: CGFloat = shouldPreferLightweightEffects(for: screen) ? 0 : 6

        return .modifier(
            active: NotchBlurModifier(scale: 1, blur: blurRadius, opacity: 0),
            identity: NotchBlurModifier(scale: 1, blur: 0, opacity: 1)
        ).animation(smoothContent(for: screen))
    }
    
    /// Floating button transition: scale(0.5) + blur(4) + opacity for small circular buttons.
    static var notchButtonTransition: AnyTransition {
        notchButtonTransition(for: nil)
    }

    static func notchButtonTransition(for screen: NSScreen?) -> AnyTransition {
        let blurRadius: CGFloat = shouldPreferLightweightEffects(for: screen) ? 0 : 3

        return .modifier(
            active: NotchBlurModifier(scale: 0.55, blur: blurRadius, opacity: 0),
            identity: NotchBlurModifier(scale: 1, blur: 0, opacity: 1)
        ).animation(smoothContent(for: screen))
    }
    
    /// Shelf sub-element transition: scale(0.8) + blur(6) + opacity for inline elements.
    static var notchElementTransition: AnyTransition {
        notchElementTransition(for: nil)
    }

    static func notchElementTransition(for screen: NSScreen?) -> AnyTransition {
        let blurRadius: CGFloat = shouldPreferLightweightEffects(for: screen) ? 0 : 4

        return .modifier(
            active: NotchBlurModifier(scale: 0.84, blur: blurRadius, opacity: 0),
            identity: NotchBlurModifier(scale: 1, blur: 0, opacity: 1)
        ).animation(smoothContent(for: screen))
    }
}

// MARK: - Notch Blur Modifier

/// Modifier for premium notch view transitions with blur effect.
/// Combines scale, blur, and opacity for ultra-smooth, Apple-like transitions.
private struct NotchBlurModifier: ViewModifier {
    let scale: CGFloat
    let blur: CGFloat
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: .top)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

// MARK: - Asymmetric Expand/Collapse Extension

extension View {
    /// Applies asymmetric expand/collapse animation.
    /// - Parameter isExpanded: The expansion state to animate.
    /// - Returns: View with asymmetric animation applied.
    ///
    /// The secret to ultra-smooth feel:
    /// - Opening: bouncy spring (0.8 damping) feels alive
    /// - Closing: critically damped (1.0 damping) feels buttery, no wobble
    func smoothExpandAnimation(_ isExpanded: Bool) -> some View {
        self.animation(
            isExpanded ? DroppyAnimation.expandOpen : DroppyAnimation.expandClose,
            value: isExpanded
        )
    }
    
    /// Applies premium view transition: scale(0.8, anchor: .top) + blur + opacity with .smooth(0.35).
    func notchTransition(for screen: NSScreen? = nil) -> some View {
        self.transition(DroppyAnimation.notchViewTransition(for: screen))
    }
    
    /// PERFORMANCE: Lightweight transition (no blur) for complex views like grids with many items.
    func notchTransitionLight(for screen: NSScreen? = nil) -> some View {
        self.transition(DroppyAnimation.notchViewTransitionLight(for: screen))
    }

    /// Constraint-safe premium transition (blur + opacity, no scale).
    func notchTransitionBlurOnly(for screen: NSScreen? = nil) -> some View {
        self.transition(DroppyAnimation.notchViewTransitionBlurOnly(for: screen))
    }
    
    /// Premium floating button transition (scale 0.5 + blur 4 + opacity).
    func notchButtonTransition() -> some View {
        self.transition(DroppyAnimation.notchButtonTransition)
    }
    
    /// Premium shelf sub-element transition (scale 0.8 + blur 6 + opacity).
    func notchElementTransition() -> some View {
        self.transition(DroppyAnimation.notchElementTransition)
    }
}

// MARK: - View Extension for Animated Hover (DEPRECATED)

extension View {
    /// DEPRECATED: This pattern causes animation stacking when hovering rapidly.
    /// Use `.animation(.bouncy.speed(1.2), value: hoverState)` at view level instead.
    @available(*, deprecated, message: "Use view-level .animation() modifier instead of withAnimation inside onHover")
    func droppyHover(
        _ isHovering: Binding<Bool>,
        animation: Animation = DroppyAnimation.hoverSmooth
    ) -> some View {
        self.onHover { hovering in
            // Direct state update - no withAnimation to prevent stacking
            isHovering.wrappedValue = hovering
        }
        .animation(animation, value: isHovering.wrappedValue)
    }
    
    /// DEPRECATED: This pattern causes animation stacking when hovering rapidly.
    /// Use `.animation(.bouncy.speed(1.2), value: hoverState)` at view level instead.
    @available(*, deprecated, message: "Use view-level .animation() modifier instead of withAnimation inside onHover")
    func droppyHover(
        animation: Animation = DroppyAnimation.hoverSmooth,
        perform action: @escaping (Bool) -> Void
    ) -> some View {
        self.onHover { hovering in
            // Direct state update - no withAnimation to prevent stacking
            action(hovering)
        }
    }
}

// MARK: - Two-Phase Press Effect Extension

extension View {
    /// Applies two-phase press effect (snap + settle).
    /// Phase 1: Quick snap on press (0.2s, bouncy)
    /// Phase 2: Slower settle on release (0.28s, smooth)
    ///
    /// - Parameters:
    ///   - isPressed: The pressed state.
    ///   - offset: Binding to the offset value.
    ///   - amount: The offset amount (default 4pt).
    func twoPhasePress(
        isPressed: Bool,
        offset: Binding<CGFloat>,
        amount: CGFloat = 4
    ) -> some View {
        self
            .offset(x: offset.wrappedValue)
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    withAnimation(DroppyAnimation.pressSnap) {
                        offset.wrappedValue = amount
                    }
                } else {
                    // Delay before settle for mechanical feel
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        withAnimation(DroppyAnimation.pressSettle) {
                            offset.wrappedValue = 0
                        }
                    }
                }
            }
    }
}

// MARK: - Animated State Change Helper

extension View {
    /// Wraps a state change in the standard Droppy animation.
    func animateState<T: Equatable>(
        _ value: T,
        animation: Animation = DroppyAnimation.state
    ) -> some View {
        self.animation(animation, value: value)
    }
}
