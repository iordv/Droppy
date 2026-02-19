//
//  HighAlertHUDView.swift
//  Droppy
//
//  High Alert brief HUD - matches the Caffeine Hover Indicators style exactly
//  Shows eyes icon + timer/status text in a simple wing layout
//

import SwiftUI

/// Compact High Alert HUD that displays briefly when activating/deactivating
/// Uses same layout as Caffeine Hover Indicators for visual consistency
struct HighAlertHUDView: View {
    let isActive: Bool
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    var notchWidth: CGFloat = 180  // Actual notch width from caller (for proper spacer alignment)
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    
    // Access CaffeineManager for timer display
    private var caffeineManager: CaffeineManager { CaffeineManager.shared }
    
    /// Centralized layout calculator - Single Source of Truth
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }
    
    /// Accent color based on High Alert state
    private var accentColor: Color {
        isActive
            ? Color(red: 1.0, green: 0.62, blue: 0.26)
            : (useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.85) : .white.opacity(0.78))
    }

    private var hasPhysicalNotchOnDisplay: Bool {
        guard let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first else { return false }
        return screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
    }

    private var useAdaptiveForegrounds: Bool {
        useTransparentBackground && !hasPhysicalNotchOnDisplay
    }
    
    /// Display text - shows timer when active, "Inactive" when not
    private var statusText: String {
        if isActive {
            return caffeineManager.formattedRemaining
        } else {
            return "Inactive"
        }
    }
    
    /// Icon size matching other HUDs
    private var iconSize: CGFloat {
        layout.iconSize
    }
    
    /// Text size - larger for ∞ symbol
    private var textSize: CGFloat {
        if isActive && caffeineManager.formattedRemaining == "∞" {
            return 20
        }
        return layout.labelFontSize
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if layout.isDynamicIslandMode {
                // DYNAMIC ISLAND: Icon on left edge, Timer on right edge
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                
                HStack {
                    // Eyes icon - .leading alignment within frame
                    Image(systemName: "eyes")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .symbolEffect(.bounce.up, value: isActive)
                        .frame(width: 20, height: iconSize, alignment: .leading)
                    
                    Spacer()
                    
                    statusIndicator()
                }
                .padding(.horizontal, symmetricPadding)
                .frame(height: layout.notchHeight)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                // Use the actual notchWidth passed by caller for correct spacer alignment
                let actualNotchWidth = layout.isDynamicIslandMode ? layout.notchWidth : self.notchWidth
                let wingWidth = (hudWidth - actualNotchWidth) / 2
                
                HStack(spacing: 0) {
                    // Left wing: Eyes icon near left edge
                    HStack {
                        Image(systemName: "eyes")
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .symbolEffect(.bounce.up, value: isActive)
                            .frame(width: iconSize, height: iconSize, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, symmetricPadding)
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer) - use actual notch width for alignment
                    Spacer()
                        .frame(width: actualNotchWidth)
                    
                    // Right wing: Timer near right edge
                    HStack {
                        Spacer(minLength: 0)
                        statusIndicator()
                    }
                    .padding(.trailing, symmetricPadding)
                    .frame(width: wingWidth)
                }
                .frame(height: layout.notchHeight)
            }
        }
        .animation(DroppyAnimation.notchState, value: isActive)
        .animation(DroppyAnimation.notchState, value: statusText)
    }
    
    @ViewBuilder
    private func statusIndicator() -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accentColor.opacity(isActive ? 1 : 0.6))
                .frame(width: 4, height: 4)
            Text(statusText)
                .font(.system(size: textSize, weight: .semibold, design: isActive && statusText != "∞" ? .monospaced : .default))
                .foregroundStyle(accentColor)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .fixedSize()
    }
}

#Preview {
    ZStack {
        Color.black
        HighAlertHUDView(
            isActive: true,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
