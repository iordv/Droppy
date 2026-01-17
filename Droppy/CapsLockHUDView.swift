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
    let notchWidth: CGFloat   // Physical notch width
    let notchHeight: CGFloat  // Physical notch height
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    /// Width of each "wing" (area left/right of physical notch)
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    /// Accent color based on Caps Lock state (matches battery green/white scheme)
    /// In transparent DI mode, always use white for readability
    private var accentColor: Color {
        capsLockManager.isCapsLockOn ? .green : .white
    }
    
    /// Caps Lock icon - use filled variant when ON
    private var capsLockIcon: String {
        capsLockManager.isCapsLockOn ? "capslock.fill" : "capslock"
    }
    
    /// Whether we're in Dynamic Island mode (screen-aware for multi-monitor)
    /// For HUD LAYOUT purposes: external displays always use compact layout (no physical notch)
    private var isDynamicIslandMode: Bool {
        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
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
    
    /// Whether transparent Dynamic Island mode is enabled
    private var isTransparentDI: Bool {
        isDynamicIslandMode && UserDefaults.standard.bool(forKey: "useDynamicIslandTransparent")
    }
    
    /// Color for Dynamic Island mode - white for transparent, accent color otherwise
    private var dynamicIslandColor: Color {
        isTransparentDI ? .white : accentColor
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if isDynamicIslandMode {
                // DYNAMIC ISLAND: Icon on left edge, On/Off on right edge
                HStack {
                    // Caps Lock icon (left edge)
                    Image(systemName: capsLockIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(dynamicIslandColor)
                        .symbolEffect(.bounce.up, value: capsLockManager.isCapsLockOn)
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                        .frame(width: 22, height: 22)
                    
                    Spacer()
                    
                    // On/Off text (right edge)
                    Text(capsLockManager.isCapsLockOn ? "On" : "Off")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(dynamicIslandColor)
                        .contentTransition(.interpolate)
                }
                .padding(.horizontal, 14)
                .frame(height: notchHeight)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                // EXACT COPY of BatteryHUDView Notch Mode layout
                HStack(spacing: 0) {
                    // Left wing: Caps Lock icon near left edge
                    HStack {
                        Image(systemName: capsLockIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .symbolEffect(.bounce.up, value: capsLockManager.isCapsLockOn)
                            .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                            .frame(width: 26, height: 26)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 8)  // Balanced with vertical padding
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: notchWidth)
                    
                    // Right wing: ON/OFF near right edge
                    HStack {
                        Spacer(minLength: 0)
                        Text(capsLockManager.isCapsLockOn ? "On" : "Off")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .contentTransition(.interpolate)
                            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: capsLockManager.isCapsLockOn)
                    }
                    .padding(.trailing, 8)  // Balanced with vertical padding
                    .frame(width: wingWidth)
                }
                .frame(height: notchHeight)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        CapsLockHUDView(
            capsLockManager: CapsLockManager.shared,
            notchWidth: 180,
            notchHeight: 32,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
