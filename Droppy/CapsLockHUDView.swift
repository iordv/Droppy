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
    
    /// Width of each "wing" (area left/right of physical notch)
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    /// Accent color based on Caps Lock state (matches battery green/white scheme)
    private var accentColor: Color {
        capsLockManager.isCapsLockOn ? .green : .white
    }
    
    /// Caps Lock icon - use filled variant when ON
    private var capsLockIcon: String {
        capsLockManager.isCapsLockOn ? "capslock.fill" : "capslock"
    }
    
    /// Whether we're in Dynamic Island mode
    private var isDynamicIslandMode: Bool {
        guard let screen = NSScreen.main else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if isDynamicIslandMode {
                // DYNAMIC ISLAND: Compact horizontal layout
                // Standardized sizing: 18px icons, 13pt text, 14px horizontal padding
                // EXACT COPY of BatteryHUDView Dynamic Island layout
                HStack(spacing: 12) {
                    // Caps Lock icon
                    Image(systemName: capsLockIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .symbolEffect(.pulse, options: .repeating, value: capsLockManager.isCapsLockOn)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolVariant(.fill)
                        .frame(width: 20, height: 20)
                        .shadow(color: accentColor.opacity(capsLockManager.isCapsLockOn ? 0.4 : 0), radius: 4)
                    
                    // ON/OFF text
                    Text(capsLockManager.isCapsLockOn ? "ON" : "OFF")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
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
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .symbolEffect(.pulse, options: .repeating, value: capsLockManager.isCapsLockOn)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolVariant(.fill)
                            .frame(width: 26, height: 26)
                            .shadow(color: accentColor.opacity(capsLockManager.isCapsLockOn ? 0.4 : 0), radius: 6)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
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
                        Text(capsLockManager.isCapsLockOn ? "ON" : "OFF")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .monospacedDigit()
                            .contentTransition(.interpolate)
                            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: capsLockManager.isCapsLockOn)
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
