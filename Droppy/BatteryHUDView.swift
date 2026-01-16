//
//  BatteryHUDView.swift
//  Droppy
//
//  Created by Droppy on 07/01/2026.
//  Beautiful battery HUD matching MediaHUDView style
//

import SwiftUI

/// Compact battery HUD that sits inside the notch
/// Matches MediaHUDView layout: icon on left wing, percentage on right wing
struct BatteryHUDView: View {
    @ObservedObject var batteryManager: BatteryManager
    let notchWidth: CGFloat   // Physical notch width
    let notchHeight: CGFloat  // Physical notch height
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    /// Width of each "wing" (area left/right of physical notch)
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    /// Accent color based on battery state
    private var accentColor: Color {
        if batteryManager.isCharging || batteryManager.isPluggedIn {
            return .green
        } else if batteryManager.isLowBattery {
            return .orange
        } else {
            return .white
        }
    }
    
    /// Dynamic battery icon based on level and charging state
    private var batteryIcon: String {
        if batteryManager.isCharging || batteryManager.isPluggedIn {
            return "battery.100.bolt"
        }
        let level = batteryManager.batteryLevel
        if level >= 75 {
            return "battery.100"
        } else if level >= 50 {
            return "battery.75"
        } else if level >= 25 {
            return "battery.50"
        } else {
            return "battery.25"
        }
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
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if isDynamicIslandMode {
                // DYNAMIC ISLAND: Compact horizontal layout
                // Standardized sizing: 18px icons, 13pt text, 14px horizontal padding
                HStack(spacing: 12) {
                    // Battery icon
                    Image(systemName: batteryIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .symbolEffect(.pulse, options: .repeating, value: batteryManager.isCharging)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolVariant(.fill)
                        .frame(width: 20, height: 20)
                    
                    // Percentage
                    Text("\(batteryManager.batteryLevel)%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(batteryManager.batteryLevel)))
                }
                .padding(.horizontal, 14)
                .frame(height: notchHeight)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                // Icon and percentage positioned near outer edges with 8px padding
                HStack(spacing: 0) {
                    // Left wing: Battery icon near left edge
                    HStack {
                        Image(systemName: batteryIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .symbolEffect(.pulse, options: .repeating, value: batteryManager.isCharging)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolVariant(.fill)
                            .frame(width: 26, height: 26)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 8)  // Balanced with vertical padding
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: notchWidth)
                    
                    // Right wing: Percentage near right edge
                    HStack {
                        Spacer(minLength: 0)
                        Text("\(batteryManager.batteryLevel)%")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(batteryManager.batteryLevel)))
                            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: batteryManager.batteryLevel)
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
        BatteryHUDView(
            batteryManager: BatteryManager.shared,
            notchWidth: 180,
            notchHeight: 32,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
