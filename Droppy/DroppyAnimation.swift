//
//  DroppyAnimation.swift
//  Droppy
//
//  Single Source of Truth for all animations.
//  Ultra-smooth animations matching Apple's buttery feel.
//

import SwiftUI

// MARK: - Animation Constants (SSOT)

/// Single Source of Truth for Droppy's animation system.
/// v9.2.1: Matches Apple's animation patterns for buttery smoothness.
enum DroppyAnimation {
    
    // MARK: - Asymmetric Expand/Collapse (Apple-Style Animation)
    
    /// Asymmetric expand animation - bouncy, alive feel.
    /// APPLE-STYLE: spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    /// Use for: shelf opening, notch expanding, panels appearing.
    static let expandOpen = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    
    /// Asymmetric collapse animation - critically damped, buttery smooth.
    /// APPLE-STYLE: spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
    /// Use for: shelf closing, notch collapsing, panels disappearing.
    static let expandClose = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
    
    // MARK: - Interactive Spring (Apple-Style Animation)
    
    /// Interactive spring for user actions - immediate, responsive.
    /// APPLE-STYLE: interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
    /// Use for: hover states, open/close triggers, gesture feedback.
    static let interactive = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
    
    // MARK: - Apple Smooth Preset (Apple-Style Animation)
    
    /// Apple's .smooth preset - buttery content transitions.
    /// APPLE-STYLE uses .smooth throughout for gesture and content animations.
    /// Use for: content appearing/disappearing, gesture feedback.
    static var smooth: Animation {
        if #available(macOS 14.0, *) {
            return Animation.smooth
        } else {
            return Animation.easeInOut(duration: 0.35)
        }
    }
    
    /// Apple's .smooth with custom duration for content transitions.
    /// APPLE-STYLE: .smooth(duration: 0.35) for content transitions.
    static var smoothContent: Animation {
        if #available(macOS 14.0, *) {
            return Animation.smooth(duration: 0.35)
        } else {
            return Animation.easeInOut(duration: 0.35)
        }
    }
    
    // MARK: - Apple Optimized Presets (macOS 14+)
    
    /// Apple's hardware-optimized bouncy preset.
    /// Tuned for 120Hz ProMotion displays, falls back to custom curve on older systems.
    static var bouncy: Animation {
        if #available(macOS 14.0, *) {
            return Animation.spring(.bouncy(duration: 0.4))
        } else {
            // Fallback: Custom smooth curve for older systems
            return Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }
    
    /// Apple's smooth preset for hover states.
    /// Provides buttery hover feedback on ProMotion displays.
    static var hoverSmooth: Animation {
        if #available(macOS 14.0, *) {
            return Animation.smooth(duration: 0.3)
        } else {
            return hover
        }
    }
    
    // MARK: - Premium Animation Patterns
    
    /// PREMIUM: .bouncy.speed(1.2) - fast, snappy hover animation.
    /// Use for: hover states, button feedback, interactive elements.
    static var hoverBouncy: Animation {
        if #available(macOS 14.0, *) {
            return Animation.bouncy.speed(1.2)
        } else {
            return Animation.spring(response: 0.3, dampingFraction: 0.7)
        }
    }
    
    /// PREMIUM: .spring.speed(1.2) - fast notch state animation.
    /// Use for: notch open/close state changes.
    static var notchState: Animation {
        if #available(macOS 14.0, *) {
            return Animation.spring.speed(1.2)
        } else {
            return Animation.spring(response: 0.35, dampingFraction: 0.75)
        }
    }
    
    /// PREMIUM: DroppyAnimation.viewChange - view transitions.
    /// Use for: switching between different views/content.
    static let viewChange = Animation.easeInOut(duration: 0.4)
    
    /// PREMIUM: .interactiveSpring(dampingFraction: 1.2) - overdamped blur replace.
    /// Use for: content replacements with blurReplace transition.
    static let blurReplace = Animation.interactiveSpring(dampingFraction: 1.2)
    
    // MARK: - Hover Animations
    
    /// Standard hover animation - smooth, responsive, slight bounce.
    /// Use for: buttons, cards, list items, interactive elements.
    static let hover = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Quick hover animation - instant feedback, no bounce.
    /// Use for: small indicators, icons, subtle state changes.
    static let hoverQuick = Animation.easeOut(duration: 0.12)
    
    /// Buttery smooth hover scale animation - premium feel.
    /// Use for: notch/island hover feedback, "ready to expand" preview.
    /// Parameters tuned for subtle, damped response matching Apple's feel.
    static let hoverScale = Animation.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0)
    
    // MARK: - State Transitions
    
    /// Standard state change - natural, fluid.
    /// Use for: toggle states, selection changes, mode switches.
    static let state = Animation.spring(response: 0.3, dampingFraction: 0.75)
    
    /// Emphasized state change - bouncy, noticeable.
    /// Use for: favorites, flags, important state changes.
    static let stateEmphasis = Animation.spring(response: 0.35, dampingFraction: 0.6)
    
    // MARK: - Layout Animations
    
    /// List reordering animation - smooth, avoids jank.
    /// Use for: sorting, filtering, item insertion/removal.
    static let listChange = Animation.spring(response: 0.35, dampingFraction: 0.75)
    
    /// View transitions - elegant entrance/exit.
    /// Use for: sheets, popovers, panels appearing/disappearing.
    static let transition = Animation.spring(response: 0.4, dampingFraction: 0.75)
    
    /// Overdamped view transition - buttery cross-fades with no wobble.
    /// Use for: view swaps, content replacements, HUD transitions.
    static let viewTransition = Animation.interactiveSpring(dampingFraction: 1.2)
    
    // MARK: - Interactive Animations
    
    /// Press feedback - immediate response.
    /// Use for: button press down state.
    static let press = Animation.interactiveSpring(response: 0.15, dampingFraction: 0.8)
    
    /// Release feedback - natural bounce back.
    /// Use for: button release, drag end.
    static let release = Animation.spring(response: 0.3, dampingFraction: 0.65)
    
    /// Drag tracking - follows finger precisely.
    /// Use for: active dragging, live updates.
    static let drag = Animation.interactiveSpring(response: 0.1, dampingFraction: 0.9)
    
    /// Real-time tracking - Apple's .smooth preset for gesture following.
    /// Use for: slider drags, scroll tracking, gesture progress.
    /// Apple pattern: `.animation(.smooth, value: gestureProgress)`
    static var tracking: Animation {
        if #available(macOS 14.0, *) {
            return Animation.smooth
        } else {
            return Animation.easeOut(duration: 0.12)
        }
    }
    
    // MARK: - Two-Phase Press Effects
    
    /// Phase 1: Quick snap on press down.
    /// Fast response (0.2s) with lower damping (0.55) for snappy feel.
    static let pressSnap = Animation.spring(response: 0.2, dampingFraction: 0.55)
    
    /// Phase 2: Slower settle on release.
    /// Slightly slower (0.28s) with higher damping (0.72) for smooth recovery.
    static let pressSettle = Animation.spring(response: 0.28, dampingFraction: 0.72)
    
    // MARK: - Scale Animations
    
    /// Hover scale animation (small).
    /// Use for: subtle hover feedback on cards.
    static let scaleHover = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Pop scale animation.
    /// Use for: attention-grabbing effects, notifications.
    static let scalePop = Animation.spring(response: 0.3, dampingFraction: 0.5)
    
    // MARK: - Timing Curves (for non-spring animations)
    
    /// Smooth ease-out curve.
    static let easeOut = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Smooth ease-in-out curve.
    static let easeInOut = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    
    /// Quick linear (for progress indicators).
    static let linear = Animation.linear(duration: 0.1)
    
    // MARK: - Notch View Transition
    
    /// Premium view transition: scale(0.8, anchor: .top) + opacity with smooth duration.
    static var notchViewTransition: AnyTransition {
        AnyTransition.asymmetric(
            insertion: AnyTransition.scale(scale: 0.8, anchor: .top).combined(with: .opacity),
            removal: AnyTransition.scale(scale: 0.8, anchor: .top).combined(with: .opacity)
        ).animation(.smooth(duration: 0.35))
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
    
    /// Applies premium view transition: scale(0.8, anchor: .top) + opacity with .smooth(0.35).
    func notchTransition() -> some View {
        self.transition(DroppyAnimation.notchViewTransition)
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
