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
    var notchHeight: CGFloat = 0  // Pass through for layout calculations
    
    // Access CaffeineManager for timer display
    private var caffeineManager: CaffeineManager { CaffeineManager.shared }
    
    /// Centralized layout calculator - Single Source of Truth
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }
    
    /// Accent color based on High Alert state
    private var accentColor: Color {
        isActive ? .orange : .white.opacity(0.5)
    }
    
    /// Display text - shows timer when active, "Inactive" when not
    private var statusText: String {
        if isActive {
            return caffeineManager.formattedRemaining
        } else {
            return "Inactive"
        }
    }
    
    /// Icon size matching hover indicators
    private var iconSize: CGFloat {
        layout.isDynamicIslandMode ? 16 : 14
    }
    
    /// Text size - larger for ∞ symbol, matching hover indicators
    private var textSize: CGFloat {
        if isActive && caffeineManager.formattedRemaining == "∞" {
            return 20
        }
        return 12
    }
    
    var body: some View {
        if layout.isDynamicIslandMode {
            // DYNAMIC ISLAND MODE: Icon on left, timer on right with symmetric padding
            let symmetricPadding = layout.symmetricPadding(for: iconSize)
            
            HStack {
                // Left: Eyes Icon
                Image(systemName: "eyes")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(accentColor)
                    .symbolEffect(.bounce.up, value: isActive)
                
                Spacer()
                
                // Right: Timer/Status Text
                Text(statusText)
                    .font(.system(size: textSize, weight: .medium, design: isActive && statusText != "∞" ? .monospaced : .default))
                    .foregroundStyle(accentColor)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, symmetricPadding)
            .frame(height: layout.notchHeight)
        } else {
            // NOTCH MODE: Position in wings around the notch
            let wingWidth = (hudWidth - layout.notchWidth) / 2
            let symmetricPadding = layout.symmetricPadding(for: iconSize)
            
            HStack(spacing: 0) {
                // Left wing: Eyes Icon
                HStack {
                    Image(systemName: "eyes")
                        .font(.system(size: iconSize, weight: .medium))
                        .foregroundStyle(accentColor)
                        .symbolEffect(.bounce.up, value: isActive)
                    Spacer(minLength: 0)
                }
                .padding(.leading, symmetricPadding)
                .frame(width: wingWidth)
                
                // Notch spacer
                Spacer()
                    .frame(width: layout.notchWidth)
                
                // Right wing: Timer/Status Text
                HStack {
                    Spacer(minLength: 0)
                    Text(statusText)
                        .font(.system(size: textSize, weight: .medium, design: isActive && statusText != "∞" ? .monospaced : .default))
                        .foregroundStyle(accentColor)
                        .contentTransition(.numericText())
                }
                .padding(.trailing, symmetricPadding)
                .frame(width: wingWidth)
            }
            .frame(width: hudWidth, height: layout.notchHeight)
        }
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
