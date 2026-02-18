//
//  DroppyButtonStyle.swift
//  Droppy
//
//  Beautiful pill-shaped button style used throughout Droppy
//  Inspired by the "X Images >" label design
//

import SwiftUI

// MARK: - Droppy Pill Button Style

/// The signature Droppy button style: pill-shaped with subtle glass effect
/// Use with .buttonStyle(DroppyPillButtonStyle()) or .droppyPillButton()
struct DroppyPillButtonStyle: ButtonStyle {
    var size: DroppyButtonSize = .medium
    var showChevron: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        DroppyPillButtonContent(
            configuration: configuration,
            size: size,
            showChevron: showChevron
        )
    }
}

private struct DroppyPillButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let size: DroppyButtonSize
    let showChevron: Bool
    
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .small: return 8
        case .medium: return 10
        case .large: return 12
        }
    }
    
    private var fontSize: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 13
        case .large: return 15
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            configuration.label
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(labelColor)
            
            if showChevron {
                Image(systemName: "chevron.forward")
                    .font(.system(size: fontSize - 3, weight: .semibold))
                    .foregroundStyle(chevronColor)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Capsule()
                .fill(AdaptiveColors.overlayAuto(backgroundOpacity))
        )
        .overlay(
            Capsule()
                .stroke(AdaptiveColors.overlayAuto(borderOpacity), lineWidth: 1)
        )
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
        .animation(DroppyAnimation.hoverQuick, value: configuration.isPressed)
        .onHover { hovering in
            withAnimation(DroppyAnimation.hover) {
                isHovering = hovering
            }
        }
        .contentShape(Capsule())
    }
    
    private var backgroundOpacity: Double {
        if !isEnabled {
            return 0.12
        }
        if configuration.isPressed {
            return 0.24
        } else if isHovering {
            return 0.18
        } else {
            return 0.14
        }
    }

    private var borderOpacity: Double {
        if !isEnabled {
            return 0.09
        }
        if configuration.isPressed {
            return 0.18
        } else if isHovering {
            return 0.14
        } else {
            return 0.10
        }
    }

    private var labelColor: Color {
        if !isEnabled {
            return AdaptiveColors.secondaryTextAuto.opacity(0.88)
        }
        if configuration.isPressed {
            return AdaptiveColors.primaryTextAuto
        } else if isHovering {
            return AdaptiveColors.primaryTextAuto.opacity(0.95)
        } else {
            return AdaptiveColors.primaryTextAuto.opacity(0.92)
        }
    }

    private var chevronColor: Color {
        if !isEnabled {
            return AdaptiveColors.secondaryTextAuto.opacity(0.78)
        }
        if isHovering {
            return AdaptiveColors.primaryTextAuto.opacity(0.85)
        } else {
            return AdaptiveColors.secondaryTextAuto.opacity(0.85)
        }
    }
}

// MARK: - Button Sizes

enum DroppyButtonSize {
    case small   // Compact, for toolbars
    case medium  // Standard size
    case large   // Prominent actions
}

// MARK: - Droppy Circle Button Style

/// Circle button style for icon-only buttons (close, back, etc.)
/// useTransparent: When true, uses gray bg with white border (matches basket quick action buttons)
///                 When false, uses semi-transparent white fill (matches notch mode)
/// solidFill: When provided, uses this exact color as background (for notch/island matching)
struct DroppyCircleButtonStyle: ButtonStyle {
    var size: CGFloat = 32
    var useTransparent: Bool = false  // When true, matches basket quick action button style
    var solidFill: Color? = nil  // When set, uses this exact color (for notch/island floating buttons)
    
    func makeBody(configuration: Configuration) -> some View {
        DroppyCircleButtonContent(
            configuration: configuration,
            size: size,
            useTransparent: useTransparent,
            solidFill: solidFill
        )
    }
}

private struct DroppyCircleButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let size: CGFloat
    let useTransparent: Bool
    let solidFill: Color?
    
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled
    
    // Use solid fill when provided, otherwise use semi-transparent white
    private var buttonFill: Color {
        if let solid = solidFill {
            // Solid fill mode: adjust opacity slightly for hover/press states
            return solid.opacity(configuration.isPressed ? 0.9 : (isHovering ? 0.95 : 1.0))
        }
        return AdaptiveColors.overlayAuto(backgroundOpacity)
    }
    
    private var borderOpacity: Double {
        if useTransparent {
            if configuration.isPressed {
                return 0.34
            } else if isHovering {
                return 0.24
            } else {
                return 0.16
            }
        }
        if configuration.isPressed {
            return 0.3
        } else if isHovering {
            return 0.15
        } else {
            return 0.08
        }
    }

    private var foregroundColor: Color {
        // Transparent mode should always adapt to the current appearance.
        if useTransparent {
            return isEnabled ? AdaptiveColors.primaryTextAuto.opacity(0.92) : AdaptiveColors.secondaryTextAuto.opacity(0.65)
        }
        // Notch/floating buttons pass a solid fill and should keep white glyphs.
        if solidFill != nil {
            return .white.opacity(0.85)
        }
        return isEnabled ? AdaptiveColors.primaryTextAuto.opacity(0.9) : AdaptiveColors.secondaryTextAuto.opacity(0.65)
    }
    
    var body: some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(foregroundColor)
            .frame(width: size, height: size)
            .background(
                Group {
                    // Transparent mode: use glass material (overrides solidFill)
                    if useTransparent {
                        Circle()
                            .droppyGlassFill()
                    } else {
                        Circle()
                            .fill(buttonFill)
                    }
                }
            )
            .overlay(
                // Border only in transparent mode (matches basket buttons)
                useTransparent ? Circle().stroke(AdaptiveColors.overlayAuto(borderOpacity), lineWidth: 1) : nil
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DroppyAnimation.hoverQuick, value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(DroppyAnimation.hover) {
                    isHovering = hovering
                }
            }
            .contentShape(Circle())
    }
    
    private var backgroundOpacity: Double {
        if !isEnabled {
            return 0.08
        }
        if configuration.isPressed {
            return 0.24
        } else if isHovering {
            return 0.18
        } else {
            return 0.14
        }
    }
}

// MARK: - Droppy Accent Button Style

/// Accent-colored pill button for primary actions (e.g., "To Shelf", "Select All")
struct DroppyAccentButtonStyle: ButtonStyle {
    var color: Color = .blue
    var size: DroppyButtonSize = .small
    
    func makeBody(configuration: Configuration) -> some View {
        DroppyAccentButtonContent(
            configuration: configuration,
            color: color,
            size: size
        )
    }
}

private struct DroppyAccentButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let color: Color
    let size: DroppyButtonSize
    
    @State private var isHovering = false
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .small: return 8
        case .medium: return 10
        case .large: return 12
        }
    }
    
    private var fontSize: CGFloat {
        switch size {
        case .small: return 12
        case .medium: return 13
        case .large: return 15
        }
    }
    
    var body: some View {
        configuration.label
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.9)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Capsule()
                    .fill(color.opacity(backgroundOpacity))
            )
            .overlay(
                Capsule()
                    .strokeBorder(AdaptiveColors.overlayAuto(0.15), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DroppyAnimation.hoverQuick, value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(DroppyAnimation.hover) {
                    isHovering = hovering
                }
            }
            .contentShape(Capsule())
    }
    
    private var backgroundOpacity: Double {
        if configuration.isPressed {
            return 1.0
        } else if isHovering {
            return 1.0
        } else {
            return 0.8
        }
    }
}

// MARK: - Droppy Toggle Button Style

/// Toggle button style for settings toggles with selection state and icon animation
/// Used for HUD toggles, onboarding toggles, and similar selectable options
struct DroppyToggleButtonStyle: ButtonStyle {
    var isOn: Bool
    var size: CGFloat = 50
    var cornerRadius: CGFloat = 16
    var accentColor: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        DroppyToggleButtonContent(
            configuration: configuration,
            isOn: isOn,
            size: size,
            cornerRadius: cornerRadius,
            accentColor: accentColor
        )
    }
}

private struct DroppyToggleButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let isOn: Bool
    let size: CGFloat
    let cornerRadius: CGFloat
    let accentColor: Color
    
    @State private var isHovering = false
    @State private var iconBounce = false
    
    var body: some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isOn ? 2 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : (isHovering ? 1.02 : 1.0))
            .animation(DroppyAnimation.hover, value: configuration.isPressed)
            .animation(DroppyAnimation.hover, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .onChange(of: isOn) { _, newValue in
                if newValue {
                    withAnimation(DroppyAnimation.transition) {
                        iconBounce = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        iconBounce = false
                    }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    private var backgroundColor: Color {
        if isOn {
            return accentColor.opacity(configuration.isPressed ? 0.35 : (isHovering ? 0.30 : 0.25))
        } else {
            return AdaptiveColors.overlayAuto(configuration.isPressed ? 0.18 : (isHovering ? 0.14 : 0.10))
        }
    }
    
    private var borderColor: Color {
        if isOn {
            return accentColor.opacity(0.6)
        } else {
            return AdaptiveColors.overlayAuto(isHovering ? 0.25 : 0.15)
        }
    }
}

// MARK: - Droppy Selectable Button Style

/// Selectable button style for mode selectors (e.g., Notch/Island toggle)
/// Supports selection state with matched geometry effect compatibility
struct DroppySelectableButtonStyle: ButtonStyle {
    var isSelected: Bool
    var accentColor: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        DroppySelectableButtonContent(
            configuration: configuration,
            isSelected: isSelected,
            accentColor: accentColor
        )
    }
}

private struct DroppySelectableButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    let accentColor: Color
    
    @State private var isHovering = false
    
    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(isSelected ? 1.0 : (isHovering ? 0.98 : 0.9))
            .animation(DroppyAnimation.hover, value: configuration.isPressed)
            .animation(DroppyAnimation.hover, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .contentShape(Rectangle())
    }
}

// MARK: - Droppy Card Button Style

/// Card-style button for extension cards and similar card-based interactive elements
struct DroppyCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 16
    
    func makeBody(configuration: Configuration) -> some View {
        DroppyCardButtonContent(
            configuration: configuration,
            cornerRadius: cornerRadius
        )
    }
}

private struct DroppyCardButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    
    @State private var isHovering = false
    
    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : (isHovering ? 1.01 : 1.0))
            .animation(DroppyAnimation.hover, value: configuration.isPressed)
            .animation(DroppyAnimation.state, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Droppy Sidebar Button Style

/// Sidebar navigation button style for settings and similar navigation contexts
/// Features blue filled background when selected, subtle glass effect when unselected
struct DroppySidebarButtonStyle: ButtonStyle {
    var isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        DroppySidebarButtonContent(
            configuration: configuration,
            isSelected: isSelected
        )
    }
}

private struct DroppySidebarButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .foregroundStyle(isSelected ? .white : AdaptiveColors.primaryTextAuto.opacity(0.9))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DroppyAnimation.hoverQuick, value: configuration.isPressed)
            .animation(DroppyAnimation.hover, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .contentShape(Capsule())
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return isHovering ? .blue : .blue.opacity(0.8)
        } else if configuration.isPressed {
            return AdaptiveColors.overlayAuto(0.22)
        } else if isHovering {
            return AdaptiveColors.overlayAuto(0.18)
        } else {
            return AdaptiveColors.overlayAuto(0.12)
        }
    }
}

// MARK: - Droppy Destructive Circle Button Style

/// Destructive action button style for remove/delete actions
struct DroppyDestructiveCircleButtonStyle: ButtonStyle {
    var size: CGFloat = 20
    
    func makeBody(configuration: Configuration) -> some View {
        DroppyDestructiveCircleButtonContent(
            configuration: configuration,
            size: size
        )
    }
}

private struct DroppyDestructiveCircleButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let size: CGFloat
    
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.7, style: .continuous)
                .fill(Color.red.opacity(backgroundOpacity))
                .frame(width: size, height: size)
            
            configuration.label
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(configuration.isPressed ? 0.9 : (isHovering ? 1.1 : 1.0))
        .animation(DroppyAnimation.hover, value: configuration.isPressed)
        .animation(DroppyAnimation.hover, value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .contentShape(Circle())
    }
    
    private var backgroundOpacity: Double {
        if configuration.isPressed {
            return 1.0
        } else if isHovering {
            return 1.0
        } else {
            return 0.9
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply the signature Droppy pill button style
    func droppyPillButton(size: DroppyButtonSize = .medium, showChevron: Bool = false) -> some View {
        self.buttonStyle(DroppyPillButtonStyle(size: size, showChevron: showChevron))
    }
    
    /// Apply the Droppy circle button style for icon buttons
    func droppyCircleButton(size: CGFloat = 32) -> some View {
        self.buttonStyle(DroppyCircleButtonStyle(size: size))
    }
    
    /// Apply an accent-colored Droppy pill button
    func droppyAccentButton(color: Color = .blue, size: DroppyButtonSize = .small) -> some View {
        self.buttonStyle(DroppyAccentButtonStyle(color: color, size: size))
    }
    
    /// Apply the Droppy toggle button style for selectable options
    func droppyToggleButton(isOn: Bool, size: CGFloat = 50, cornerRadius: CGFloat = 16, accentColor: Color = .blue) -> some View {
        self.buttonStyle(DroppyToggleButtonStyle(isOn: isOn, size: size, cornerRadius: cornerRadius, accentColor: accentColor))
    }
    
    /// Apply the Droppy selectable button style for mode selectors
    func droppySelectableButton(isSelected: Bool, accentColor: Color = .blue) -> some View {
        self.buttonStyle(DroppySelectableButtonStyle(isSelected: isSelected, accentColor: accentColor))
    }
    
    /// Apply the Droppy card button style
    func droppyCardButton(cornerRadius: CGFloat = 16) -> some View {
        self.buttonStyle(DroppyCardButtonStyle(cornerRadius: cornerRadius))
    }
    
    /// Apply the Droppy destructive circle button style
    func droppyDestructiveCircleButton(size: CGFloat = 20) -> some View {
        self.buttonStyle(DroppyDestructiveCircleButtonStyle(size: size))
    }
    
    /// Apply the Droppy sidebar button style for navigation
    func droppySidebarButton(isSelected: Bool) -> some View {
        self.buttonStyle(DroppySidebarButtonStyle(isSelected: isSelected))
    }
}

// MARK: - Pre-styled Button Components

/// A ready-to-use Droppy pill button with text
struct DroppyButton: View {
    let title: String
    var icon: String? = nil
    var size: DroppyButtonSize = .medium
    var showChevron: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
        }
        .buttonStyle(DroppyPillButtonStyle(size: size, showChevron: showChevron))
    }
}

/// A ready-to-use Droppy circle icon button
struct DroppyIconButton: View {
    let icon: String
    var size: CGFloat = 32
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(DroppyCircleButtonStyle(size: size))
    }
}

// MARK: - Preview

#Preview("Droppy Buttons") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
            // Pill buttons
            DroppyButton(title: "6 Images", showChevron: true) { }
            DroppyButton(title: "Save All", icon: "arrow.down.circle") { }
            DroppyButton(title: "Small", size: .small) { }
            DroppyButton(title: "Large Action", size: .large) { }
            
            // Icon buttons
            HStack(spacing: 12) {
                DroppyIconButton(icon: "xmark") { }
                DroppyIconButton(icon: "chevron.backward") { }
                DroppyIconButton(icon: "gear") { }
            }
        }
        .padding()
    }
}
