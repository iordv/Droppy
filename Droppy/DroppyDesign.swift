//
//  DroppyDesign.swift
//  Droppy
//
//  Single Source of Truth for design tokens and animations
//  All visual constants are defined here for consistency
//

import SwiftUI

// MARK: - Animation Presets (LEGACY - Use DroppyAnimation from DroppyAnimation.swift)

/// Legacy animation presets - prefer DroppyAnimation SSOT instead
@available(*, deprecated, message: "Use DroppyAnimation from DroppyAnimation.swift instead")
enum DroppyAnimationLegacy {
    // MARK: - Standard Springs
    
    /// Default spring for most UI interactions (0.3s, 0.8 damping)
    static let standard = DroppyAnimation.state
    
    /// Quick spring for snappy interactions (0.25s, 0.7 damping)
    static let quick = DroppyAnimation.hoverBouncy
    
    /// Slow spring for dramatic transitions (0.4s, 0.75 damping)
    static let gentle = Animation.spring(response: 0.4, dampingFraction: 0.75)
    
    /// Bouncy spring for playful interactions (0.35s, 0.6 damping)
    static let bouncy = Animation.spring(response: 0.35, dampingFraction: 0.6)
    
    /// Extra bouncy for attention-grabbing moments (0.3s, 0.5 damping)
    static let springy = Animation.spring(response: 0.3, dampingFraction: 0.5)
    
    // MARK: - Specialized Springs
    
    /// Shelf expand/collapse animation
    static let shelfTransition = Animation.spring(response: 0.35, dampingFraction: 0.75)
    
    /// HUD show/hide animation
    static let hudTransition = DroppyAnimation.transition
    
    /// Category pill selection animation
    static let categorySelection = DroppyAnimation.notchState
    
    /// Hover scale animation
    static let hover = DroppyAnimation.hoverBouncy
    
    /// Icon pulse animation
    static let pulse = Animation.spring(response: 0.3, dampingFraction: 0.6)
    
    // MARK: - Eased Animations
    
    /// Smooth fade animation
    static let fade = DroppyAnimation.hoverQuick
    
    /// Quick fade animation
    static let quickFade = DroppyAnimation.hoverQuick
    
    /// Slow reveal animation
    static let slowReveal = Animation.easeInOut(duration: 0.35)
}

// MARK: - Spacing Constants

/// Standardized spacing values based on 4pt grid
enum DroppySpacing {
    /// 4pt spacing
    static let xs: CGFloat = 4
    /// 6pt spacing - compact elements
    static let xsm: CGFloat = 6
    /// 8pt spacing
    static let sm: CGFloat = 8
    /// 10pt spacing - button padding
    static let smd: CGFloat = 10
    /// 12pt spacing
    static let md: CGFloat = 12
    /// 14pt spacing - card content
    static let mdl: CGFloat = 14
    /// 16pt spacing
    static let lg: CGFloat = 16
    /// 20pt spacing
    static let xl: CGFloat = 20
    /// 24pt spacing
    static let xxl: CGFloat = 24
    /// 32pt spacing
    static let xxxl: CGFloat = 32
    /// 40pt spacing - large drop zones
    static let huge: CGFloat = 40
    
    // MARK: - Drag & Drop
    /// Base offset for drag images to position bottom-right of cursor (8pt)
    static let dragCursorOffset: CGFloat = 8
    /// Stacking offset for multiple dragged items (3pt per item)
    static let dragStackOffset: CGFloat = 3
}

// MARK: - Corner Radius Constants

/// Standardized corner radius values - Tiered Radii Standard v25.1
enum DroppyRadius {
    /// Micro radius (2pt) - tiny UI elements, indicators
    static let micro: CGFloat = 2
    /// Extra small radius (4pt) - small badges, mini pills
    static let xs: CGFloat = 4
    /// Small radius (6pt) - compact buttons, tags
    static let sm: CGFloat = 6
    /// Small radius (8pt) - buttons, pills
    static let small: CGFloat = 8
    /// Medium-small radius (10pt) - compact cards
    static let ms: CGFloat = 10
    /// Medium radius (12pt) - cards, small panels
    static let medium: CGFloat = 12
    /// Medium-large radius (14pt) - buttons, input fields
    static let ml: CGFloat = 14
    /// Large radius (16pt) - panels, sheets
    static let large: CGFloat = 16
    /// Large-extra radius (18pt) - prominent cards
    static let lx: CGFloat = 18
    /// Extra large radius (20pt) - major containers
    static let xl: CGFloat = 20
    /// Extra-extra large radius (22pt) - featured panels
    static let xxl: CGFloat = 22
    /// Jumbo radius (28pt) - hero elements
    static let jumbo: CGFloat = 28
    /// Giant radius (40pt) - circular overlays
    static let giant: CGFloat = 40
    /// Circular/capsule
    static let full: CGFloat = 9999
}

// MARK: - Color Tokens

/// Standardized opacity values for consistent layering
enum DroppyOpacity {
    /// Barely visible (0.03) - subtle backgrounds
    static let subtle: Double = 0.03
    /// Light overlay (0.08) - borders, dividers
    static let light: Double = 0.08
    /// Medium overlay (0.1) - hover states
    static let medium: Double = 0.1
    /// Visible overlay (0.15) - active states
    static let visible: Double = 0.15
    /// Strong overlay (0.2) - emphasized elements
    static let strong: Double = 0.2
    /// Heavy overlay (0.4) - prominent elements
    static let heavy: Double = 0.4
    /// Secondary text (0.6-0.7)
    static let secondary: Double = 0.6
    /// Primary text (0.8-0.9)
    static let primary: Double = 0.8
}

// MARK: - Icon Sizes

/// Standardized icon sizes
enum DroppyIconSize {
    /// Tiny icon (10pt)
    static let tiny: CGFloat = 10
    /// Small icon (14pt)
    static let small: CGFloat = 14
    /// Medium icon (18pt)
    static let medium: CGFloat = 18
    /// Large icon (24pt)
    static let large: CGFloat = 24
    /// Extra large icon (32pt)
    static let xl: CGFloat = 32
    /// Hero icon (48pt)
    static let hero: CGFloat = 48
}

// MARK: - Line Widths

/// Standardized stroke widths
enum DroppyStroke {
    /// Subtle border (0.5pt)
    static let subtle: CGFloat = 0.5
    /// Standard border (1pt)
    static let standard: CGFloat = 1
    /// Medium border (1.5pt)
    static let medium: CGFloat = 1.5
    /// Thick border (2pt)
    static let thick: CGFloat = 2
}

// MARK: - Timing Constants

/// Standardized timing values (in seconds)
enum DroppyTiming {
    /// Instant feedback (0.1s)
    static let instant: Double = 0.1
    /// Quick interaction (0.2s)
    static let quick: Double = 0.2
    /// Standard transition (0.3s)
    static let standard: Double = 0.3
    /// Comfortable transition (0.5s)
    static let comfortable: Double = 0.5
    /// Deliberate transition (0.7s)
    static let deliberate: Double = 0.7
}

// MARK: - Shadow Presets

/// Standardized shadow styles
enum DroppyShadow {
    /// Subtle shadow for floating elements
    static func subtle(_ color: Color = .black) -> some View {
        EmptyView()
            .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    /// Medium shadow for cards
    static let mediumRadius: CGFloat = 8
    static let mediumY: CGFloat = 4
    static let mediumOpacity: Double = 0.3
    
    /// Strong shadow for prominent elements
    static let strongRadius: CGFloat = 16
    static let strongY: CGFloat = 8
    static let strongOpacity: Double = 0.4
}

// MARK: - Scale Effects

/// Standardized scale values for interactions
enum DroppyScale {
    /// Subtle press effect (0.98)
    static let pressed: CGFloat = 0.98
    /// Hover effect (1.01-1.02)
    static let hover: CGFloat = 1.02
    /// Emphasized hover (1.03)
    static let hoverEmphasis: CGFloat = 1.03
    /// Pulse effect (1.05)
    static let pulse: CGFloat = 1.05
    /// Bounce effect (1.1)
    static let bounce: CGFloat = 1.1
    /// Large emphasis (1.15)
    static let emphasis: CGFloat = 1.15
}

// MARK: - Premium HUD Transition

/// Premium blur transition for HUD animations
/// Combines scale, opacity, and blur for ultra-smooth, Apple-like transitions
/// Only applies blur during transition phase - no continuous CPU impact
extension AnyTransition {
    /// Premium HUD transition with blur effect
    /// - Parameters:
    ///   - scale: Scale factor when hidden (default 0.85)
    ///   - blur: Blur radius when hidden (default 8)
    /// - Returns: A combined transition with scale, opacity, and blur
    static func premiumHUD(scale: CGFloat = 0.85, blur: CGFloat = 8) -> AnyTransition {
        .modifier(
            active: PremiumBlurModifier(scale: scale, blur: blur, opacity: 0),
            identity: PremiumBlurModifier(scale: 1, blur: 0, opacity: 1)
        )
    }
    
    /// Standard premium HUD transition with default values
    static var premiumHUD: AnyTransition {
        .premiumHUD(scale: 0.85, blur: 8)
    }
}

/// Modifier for premium blur transition
private struct PremiumBlurModifier: ViewModifier {
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

// MARK: - Shadow View Modifiers

extension View {
    /// Text emboss shadow - subtle depth for text labels
    /// Usage: `.droppyTextShadow()`
    func droppyTextShadow(opacity: Double = DroppyOpacity.strong) -> some View {
        shadow(color: .black.opacity(opacity), radius: 0.5, x: 0, y: 0.5)
    }
    
    /// Card shadow - standard elevation for cards and panels
    /// Usage: `.droppyCardShadow()` or `.droppyCardShadow(opacity: 0.3)`
    func droppyCardShadow(opacity: Double = 0.25) -> some View {
        shadow(color: .black.opacity(opacity), radius: DroppyShadow.mediumRadius, x: 0, y: DroppyShadow.mediumY)
    }
    
    /// Floating element shadow - prominent elevation for floating UI
    /// Usage: `.droppyFloatingShadow()`
    func droppyFloatingShadow(opacity: Double = 0.3) -> some View {
        shadow(color: .black.opacity(opacity), radius: 12, x: 0, y: 6)
    }
    
    /// Strong shadow - high prominence for major elements
    /// Usage: `.droppyStrongShadow()`
    func droppyStrongShadow(opacity: Double = DroppyShadow.strongOpacity) -> some View {
        shadow(color: .black.opacity(opacity), radius: DroppyShadow.strongRadius, x: 0, y: DroppyShadow.strongY)
    }

    /// Applies the app's shared window background treatment.
    func droppyTransparentBackground(_ useTransparentBackground: Bool) -> some View {
        self.background(
            useTransparentBackground
                ? AnyShapeStyle(.ultraThinMaterial)
                : AdaptiveColors.panelBackgroundOpaqueStyle
        )
    }
}

extension Shape {
    /// Fills the shape with Droppy's shared glass material.
    func droppyGlassFill() -> some View {
        self.fill(.ultraThinMaterial)
    }

    /// Fills with glass when transparency is enabled, otherwise a solid fallback.
    @ViewBuilder
    func droppyTransparentFill(_ useTransparentBackground: Bool, fallback: Color = AdaptiveColors.panelBackgroundAuto) -> some View {
        if useTransparentBackground {
            self.droppyGlassFill()
        } else {
            self.fill(fallback)
        }
    }
}
