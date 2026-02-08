//
//  CapsLockHUDView.swift
//  Droppy
//
//  Created by Droppy on 09/01/2026.
//  Beautiful Caps Lock HUD matching BatteryHUDView style exactly
//

import SwiftUI

/// Compact Caps Lock HUD that sits inside the notch
/// Matches BatteryHUDView layout exactly: icon on left wing, ON/OFF on right wing
struct CapsLockHUDView: View {
    @ObservedObject var capsLockManager: CapsLockManager
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    /// Centralized layout calculator - Single Source of Truth
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }
    
    /// Accent color based on Caps Lock state
    private var accentColor: Color {
        capsLockManager.isCapsLockOn
            ? Color(red: 0.34, green: 0.92, blue: 0.60)
            : .white.opacity(0.86)
    }
    
    /// Caps Lock icon - use filled variant when ON
    private var capsLockIcon: String {
        capsLockManager.isCapsLockOn ? "capslock.fill" : "capslock"
    }
    
    private var statusText: String {
        capsLockManager.isCapsLockOn ? "ON" : "OFF"
    }
    
    private var statusBadgeFill: Color {
        AdaptiveColors.overlayAuto(capsLockManager.isCapsLockOn ? 0.15 : 0.08)
    }
    
    private var statusBadgeStroke: Color {
        AdaptiveColors.overlayAuto(capsLockManager.isCapsLockOn ? 0.28 : 0.16)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if layout.isDynamicIslandMode {
                // DYNAMIC ISLAND: Icon on left edge, On/Off on right edge
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                
                HStack {
                    // Caps Lock icon - .leading alignment within frame
                    Image(systemName: capsLockIcon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(layout.adjustedColor(accentColor))
                        .symbolEffect(.bounce.up, value: capsLockManager.isCapsLockOn)
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                        .frame(width: 20, height: iconSize, alignment: .leading)
                    
                    Spacer()
                    
                    statusBadge(useAdjustedColor: true)
                }
                .padding(.horizontal, symmetricPadding)
                .frame(height: layout.notchHeight)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                let wingWidth = layout.wingWidth(for: hudWidth)
                
                HStack(spacing: 0) {
                    // Left wing: Caps Lock icon near left edge
                    HStack {
                        Image(systemName: capsLockIcon)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .symbolEffect(.bounce.up, value: capsLockManager.isCapsLockOn)
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
                        statusBadge(useAdjustedColor: false)
                    }
                    .padding(.trailing, symmetricPadding)
                    .frame(width: wingWidth)
                }
                .frame(height: layout.notchHeight)
            }
        }
        .animation(DroppyAnimation.notchState, value: capsLockManager.isCapsLockOn)
    }
    
    @ViewBuilder
    private func statusBadge(useAdjustedColor: Bool) -> some View {
        let foregroundColor = useAdjustedColor
            ? layout.adjustedColor(accentColor)
            : accentColor
        let badgeFontSize = max(layout.labelFontSize - 2, 10)
        
        HStack(spacing: 5) {
            Circle()
                .fill(foregroundColor.opacity(capsLockManager.isCapsLockOn ? 1 : 0.55))
                .frame(width: 4, height: 4)
            
            Text(statusText)
                .font(.system(size: badgeFontSize, weight: .semibold))
                .foregroundStyle(foregroundColor)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(
            Capsule(style: .continuous)
                .fill(statusBadgeFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(statusBadgeStroke, lineWidth: 0.6)
        )
        .fixedSize()
    }
}

#Preview {
    ZStack {
        Color.black
        CapsLockHUDView(
            capsLockManager: CapsLockManager.shared,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
