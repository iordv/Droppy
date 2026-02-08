//
//  DNDHUDView.swift
//  Droppy
//
//  Created by Droppy on 17/01/2026.
//  Focus/DND HUD matching CapsLockHUDView style exactly
//

import SwiftUI

/// Compact Focus/DND HUD that sits inside the notch
/// Matches CapsLockHUDView layout exactly: icon on left wing, ON/OFF on right wing
struct DNDHUDView: View {
    @ObservedObject var dndManager: DNDManager
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    /// Centralized layout calculator - Single Source of Truth
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }
    
    /// Accent color: violet when Focus ON, softened white when OFF
    private var accentColor: Color {
        dndManager.isDNDActive
            ? Color(red: 0.58, green: 0.40, blue: 0.96)
            : .white.opacity(0.86)
    }
    
    /// Focus icon - use filled variant when ON
    private var focusIcon: String {
        dndManager.isDNDActive ? "moon.fill" : "moon"
    }
    
    private var statusText: String {
        dndManager.isDNDActive ? "On" : "Off"
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if layout.isDynamicIslandMode {
                // DYNAMIC ISLAND: Icon on left edge, On/Off on right edge
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                
                HStack {
                    // Focus icon - .leading alignment within frame
                    Image(systemName: focusIcon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(layout.adjustedColor(accentColor))
                        .symbolEffect(.bounce.up, value: dndManager.isDNDActive)
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                        .frame(width: 20, height: iconSize, alignment: .leading)
                    
                    Spacer()
                    
                    statusIndicator(useAdjustedColor: true)
                }
                .padding(.horizontal, symmetricPadding)
                .frame(height: layout.notchHeight)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                let wingWidth = layout.wingWidth(for: hudWidth)
                
                HStack(spacing: 0) {
                    // Left wing: Focus icon near left edge
                    HStack {
                        Image(systemName: focusIcon)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .symbolEffect(.bounce.up, value: dndManager.isDNDActive)
                            .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                            .frame(width: iconSize, height: iconSize, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, symmetricPadding)
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: layout.notchWidth)
                    
                    // Right wing: ON/OFF near right edge
                    HStack {
                        Spacer(minLength: 0)
                        statusIndicator(useAdjustedColor: false)
                    }
                    .padding(.trailing, symmetricPadding)
                    .frame(width: wingWidth)
                }
                .frame(height: layout.notchHeight)
            }
        }
        .animation(DroppyAnimation.notchState, value: dndManager.isDNDActive)
    }
    
    @ViewBuilder
    private func statusIndicator(useAdjustedColor: Bool) -> some View {
        let foregroundColor = useAdjustedColor
            ? layout.adjustedColor(accentColor)
            : accentColor
        let badgeFontSize = max(layout.labelFontSize - 1, 10)
        
        HStack(spacing: 5) {
            Circle()
                .fill(foregroundColor.opacity(dndManager.isDNDActive ? 1 : 0.6))
                .frame(width: 4, height: 4)
            Text(statusText)
                .font(.system(size: badgeFontSize, weight: .semibold))
                .foregroundStyle(foregroundColor)
        }
        .fixedSize()
    }
}

#Preview {
    ZStack {
        Color.black
        DNDHUDView(
            dndManager: DNDManager.shared,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
