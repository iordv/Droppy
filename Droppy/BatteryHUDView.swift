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
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Main HUD: Two wings separated by the notch space
            // Same layout pattern as MediaHUDView
            HStack(spacing: 0) {
                // Left wing: Battery icon aligned toward outer edge
                // Padding matches bottom spacing (~8px from edge)
                HStack {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 18, weight: .semibold))  // Same as volume/brightness
                        .foregroundStyle(accentColor)
                        .symbolEffect(.pulse, options: .repeating, value: batteryManager.isCharging)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolVariant(.fill)
                        .frame(width: 26, height: 26)  // Same frame as volume/brightness
                        .shadow(color: accentColor.opacity(0.4), radius: batteryManager.isCharging ? 6 : 0)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 8)  // Match bottom spacing
                .frame(width: wingWidth)
                
                // Camera notch area (spacer)
                Spacer()
                    .frame(width: notchWidth)
                
                // Right wing: Percentage aligned toward outer edge
                // Padding matches bottom spacing (~8px from edge)
                HStack {
                    Spacer(minLength: 0)
                    Text("\(batteryManager.batteryLevel)%")
                        .font(.system(size: 15, weight: .semibold))  // Same as volume/brightness
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(batteryManager.batteryLevel)))
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: batteryManager.batteryLevel)
                }
                .padding(.trailing, 8)  // Match bottom spacing
                .frame(width: wingWidth)
            }
            .frame(height: notchHeight) // Match physical notch for proper vertical centering
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
