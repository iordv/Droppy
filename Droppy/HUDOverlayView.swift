//
//  HUDOverlayView.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  System HUD replacement that expands inside the notch
//

import SwiftUI

// HUDContentType is defined in LiquidSlider.swift

/// Helper to format HUD percentage - shows "MAX" instead of "100%"
private func hudPercentageText(_ value: CGFloat) -> String {
    let percent = Int(value * 100)
    return percent >= 100 ? "MAX" : "\(percent)%"
}

/// Embedded HUD view that appears inside the expanded notch
/// Icon on left wing, percentage on right wing, slider at bottom (full width)
/// Layout matches MediaHUDView for consistent positioning
struct NotchHUDView: View {
    @Binding var hudType: HUDContentType
    @Binding var value: CGFloat
    var isActive: Bool = true // Whether value is currently changing (for slider thickening)
    var isMuted: Bool = false // Whether volume is muted (shows red color)
    let notchWidth: CGFloat   // Physical notch width (passed from parent)
    let notchHeight: CGFloat  // Physical notch height (passed from parent)
    let hudWidth: CGFloat     // Total HUD width (passed from parent)
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    var onValueChange: ((CGFloat) -> Void)?
    @ObservedObject private var volumeManager = VolumeManager.shared
    
    /// SSOT: Use HUDLayoutCalculator for consistent padding across all HUDs
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }
    
    /// Whether we're in Dynamic Island mode (screen-aware for multi-monitor)
    /// For HUD LAYOUT purposes: external displays always use compact layout (no physical notch)
    private var isDynamicIslandMode: Bool {
        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first
        // CRITICAL: Return false (notch mode) when screen is unavailable to prevent layout jumps
        guard let screen = screen else { return false }
        // Use auxiliary areas to detect notch (stable on lock screen)
        let hasNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        
        // External displays never have physical notches, so always use compact HUD layout
        // The externalDisplayUseDynamicIsland setting only affects the visual shape, not HUD content layout
        if !screen.isBuiltIn {
            return true
        }
        
        // For built-in display, use main Dynamic Island setting
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    /// Whether this is an external display using notch visual style (curved corners)
    private var isExternalWithNotchStyle: Bool {
        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return false }
        if screen.isBuiltIn { return false }
        // External display with notch style = user chose NOT to use DI style
        let externalUseDI = UserDefaults.standard.object(forKey: "externalDisplayUseDynamicIsland") as? Bool ?? true
        return !externalUseDI
    }
    
    /// Width of each "wing" (area left/right of physical notch) - only used in notch mode
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }

    private func iconSymbol(for value: CGFloat) -> String {
        switch hudType {
        case .volume, .mute:
            return volumeManager.volumeHUDIcon(for: value, isMuted: isMuted || hudType == .mute)
        case .brightness, .backlight:
            return hudType.icon(for: value)
        }
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if isDynamicIslandMode {
                // DYNAMIC ISLAND: Compact horizontal layout - icon + slider only (no text label)
                // SSOT: Use HUDLayoutCalculator for consistent padding across all modes/displays
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                
                HStack(spacing: 12) {
                    // Left side: Icon with BUTTERY SMOOTH SCALING
                    // Icon scales from 0.85x (0%) to 1.15x (100%) for premium feel
                    let iconScale = 0.85 + (value * 0.30)
                    
                    // Volume: White icon | Brightness: Yellow icon
                    Image(systemName: iconSymbol(for: value))
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(hudType == .brightness ? Color(red: 1.0, green: 0.85, blue: 0.0) : .white)
                        .contentTransition(.symbolEffect(.replace.byLayer))
                        .scaleEffect(iconScale)
                        .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: value)
                        .frame(width: 28, height: iconSize, alignment: .center)  // Fixed width - fits max scale
                    
                    // Right side: Slider takes remaining width
                    HUDSlider(
                        value: $value,
                        hudType: hudType,
                        isMuted: isMuted,
                        isActive: isActive,
                        onChange: onValueChange
                    )
                    .frame(height: 16)
                }
                .padding(.horizontal, symmetricPadding)
                .frame(height: notchHeight)
            } else {
                // NOTCH MODE: Wide layout - icon + label on left wing, slider on right wing
                // SSOT: Use HUDLayoutCalculator for consistent padding across all modes/displays
                let iconSize = layout.iconSize
                let labelSize = layout.labelFontSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                
                HStack(spacing: 0) {
                    // Left wing: Icon + Label
                    HStack(spacing: 12) {  // Matches slider-to-percentage spacing
                        // Icon with BUTTERY SMOOTH SCALING
                        // Icon scales from 0.85x (0%) to 1.15x (100%) for premium feel
                        let iconScale = 0.85 + (value * 0.30)
                        
                        // Volume: White icon | Brightness: Yellow icon
                        Image(systemName: iconSymbol(for: value))
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(hudType == .brightness ? Color(red: 1.0, green: 0.85, blue: 0.0) : .white)
                            .contentTransition(.symbolEffect(.replace.byLayer))
                            .scaleEffect(iconScale)
                            .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: value)
                            .frame(width: iconSize + 10, alignment: .center)  // Fixed width - fits max scale
                        
                        Text(hudType == .brightness ? "Brightness" : "Volume")
                            .font(.system(size: labelSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize()
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, symmetricPadding)
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: notchWidth)
                    
                    // Right wing: Slider (aligned to outer edge)
                    HStack {
                        HUDSlider(
                            value: $value,
                            hudType: hudType,
                            isMuted: isMuted,
                            isActive: isActive,
                            onChange: onValueChange
                        )
                    }
                    .padding(.trailing, symmetricPadding)
                    .frame(width: wingWidth)
                }
                .frame(height: notchHeight)
            }
        }
        // Only animate hudType changes, NOT value changes (value animation handled by slider)
        .animation(DroppyAnimation.notchState, value: hudType)
    }
}

// MARK: - Legacy HUD (kept for reference)

/// HUD overlay view that appears below the notch for volume/brightness control
/// Styled with Liquid Glass aesthetics to match Droppy's design system
struct HUDOverlayView: View {
    @Binding var isVisible: Bool
    @Binding var hudType: HUDContentType
    @Binding var value: CGFloat
    
    var onValueChange: ((CGFloat) -> Void)?
    
    @State private var animatedValue: CGFloat = 0
    @ObservedObject private var volumeManager = VolumeManager.shared
    
    private func iconSymbol(for value: CGFloat) -> String {
        switch hudType {
        case .volume, .mute:
            return volumeManager.volumeHUDIcon(for: value, isMuted: hudType == .mute || value <= 0.0001)
        case .brightness, .backlight:
            return hudType.icon(for: value)
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon with dynamic symbol
            Image(systemName: iconSymbol(for: value))
                .font(.system(size: HUDLayoutCalculator.dynamicIslandIconSize, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.interpolate)
                .symbolVariant(.fill)
                .frame(width: 22, height: HUDLayoutCalculator.dynamicIslandIconSize)
            
            // Slider
            LiquidSlider(
                value: $value,
                accentColor: hudType == .brightness ? .yellow : .white,
                onChange: { newValue in
                    onValueChange?(newValue)
                },
                onDragChange: { newValue in
                    onValueChange?(newValue)
                }
            )
            .frame(width: 160)
            
            // Percentage
            Text(hudPercentageText(value))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(hudBackground)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
        .offset(y: isVisible ? 0 : -10)
        .animation(DroppyAnimation.notchState, value: isVisible)
        .onChange(of: value) { _, newValue in
            withAnimation(.smooth(duration: 0.1)) {
                animatedValue = newValue
            }
        }
    }
    
    private var hudBackground: some View {
        RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous)
                    .fill(Color.black.opacity(0.6))
            )
            // Specular rim lighting
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.4), location: 0),
                                .init(color: .white.opacity(0.1), location: 0.3),
                                .init(color: .black.opacity(0.2), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }
}

// MARK: - HUD State Manager

/// Manages the HUD overlay state and auto-hide timing
@Observable
class HUDStateManager {
    static let shared = HUDStateManager()
    
    var isVisible: Bool = false
    var hudType: HUDContentType = .volume
    var value: CGFloat = 0
    
    private var hideTask: Task<Void, Never>?
    private let visibleDuration: TimeInterval = 1.5
    
    private init() {}
    
    /// Show the HUD with the given type and value
    func show(type: HUDContentType, value: CGFloat) {
        hideTask?.cancel()
        
        self.hudType = type
        self.value = value
        
        withAnimation(DroppyAnimation.state) {
            self.isVisible = true
        }
        
        // Schedule auto-hide
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(visibleDuration))
            guard !Task.isCancelled else { return }
            withAnimation(DroppyAnimation.state) {
                self.isVisible = false
            }
        }
    }
    
    /// Hide the HUD immediately
    func hide() {
        hideTask?.cancel()
        withAnimation(DroppyAnimation.state) {
            isVisible = false
        }
    }
    
    /// Update value while HUD is visible (resets auto-hide timer)
    func updateValue(_ newValue: CGFloat) {
        value = newValue
        // Reset auto-hide timer
        show(type: hudType, value: newValue)
    }
}

// MARK: - Preview

#Preview("Notch HUD") {
    ZStack {
        Color.gray.opacity(0.3)
        
        VStack {
            // Simulate notch background
            RoundedRectangle(cornerRadius: DroppyRadius.xl)
                .fill(Color.black)
                .frame(width: 280, height: 90)
                .overlay {
                    NotchHUDView(
                        hudType: .constant(.volume),
                        value: .constant(0.65),
                        notchWidth: 180,
                        notchHeight: 37,
                        hudWidth: 280
                    )
                }
            
            Spacer().frame(height: 40)
            
            RoundedRectangle(cornerRadius: DroppyRadius.xl)
                .fill(Color.black)
                .frame(width: 280, height: 90)
                .overlay {
                    NotchHUDView(
                        hudType: .constant(.brightness),
                        value: .constant(0.4),
                        notchWidth: 180,
                        notchHeight: 37,
                        hudWidth: 280
                    )
                }
        }
    }
    .frame(width: 400, height: 300)
}
