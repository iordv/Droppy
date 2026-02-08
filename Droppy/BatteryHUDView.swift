//
//  BatteryHUDView.swift
//  Droppy
//
//  Created by Droppy on 07/01/2026.
//  Beautiful battery HUD matching MediaHUDView style
//

import SwiftUI

/// iOS-style battery glyph (body + right cap), without embedded percentage text.
struct IOSBatteryGlyph: View {
    let level: CGFloat          // 0...1
    let outerColor: Color
    let innerColor: Color
    let terminalColor: Color
    let chargingSegmentColor: Color
    let isCharging: Bool
    var bodyWidth: CGFloat = 22
    var bodyHeight: CGFloat = 12

    private var clampedLevel: CGFloat {
        max(0, min(1, level))
    }

    private var fillWidth: CGFloat {
        // Keep a tiny minimum fill so empty battery is still visually present.
        max(1.5, (bodyWidth - 4) * clampedLevel)
    }

    private var remainingWidth: CGFloat {
        max(0, (bodyWidth - 4) - fillWidth)
    }

    private var bodyCornerRadius: CGFloat {
        bodyHeight * 0.46
    }

    private var innerCornerRadius: CGFloat {
        max(1, (bodyHeight - 4) * 0.48)
    }

    var body: some View {
        HStack(spacing: 1.8) {
            ZStack(alignment: .leading) {
                // iOS-style shell
                RoundedRectangle(cornerRadius: bodyCornerRadius, style: .continuous)
                    .fill(outerColor)

                // Capacity fill: iOS-style bright inner pill
                RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
                    .fill(innerColor)
                    .frame(width: fillWidth, height: max(1, bodyHeight - 4))
                    .padding(2)

                if isCharging && remainingWidth > 0.8 {
                    // Charging style: neutral segment reflects the actual remaining percentage.
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: bodyCornerRadius * 0.84, style: .continuous)
                            .fill(chargingSegmentColor)
                            .frame(width: remainingWidth, height: max(1, bodyHeight - 4))
                    }
                    .padding(2)
                }

                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: bodyHeight * 0.52, weight: .black))
                        .foregroundStyle(.white.opacity(0.98))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, max(1.0, min(bodyWidth * 0.15, remainingWidth * 0.5 + 1.0)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: bodyWidth, height: bodyHeight)

            Capsule(style: .continuous)
                .fill(terminalColor)
                .frame(width: max(1.8, bodyHeight * 0.14), height: max(2, bodyHeight * 0.42))
        }
        .compositingGroup()
    }
}

/// Compact battery HUD that sits inside the notch
/// Matches MediaHUDView layout: icon on left wing, percentage on right wing
struct BatteryHUDView: View {
    @ObservedObject var batteryManager: BatteryManager
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    /// Centralized layout calculator - Single Source of Truth
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }
    
    /// Accent color based on battery state
    private var accentColor: Color {
        batteryInnerColor
    }

    private var batteryOuterColor: Color {
        if batteryManager.isCharging || batteryManager.isPluggedIn {
            return Color(white: 0.62)
        }
        if batteryManager.isLowBattery {
            return Color(red: 0.62, green: 0.12, blue: 0.18)
        }
        return Color(red: 0.16, green: 0.48, blue: 0.24)
    }

    private var batteryInnerColor: Color {
        if batteryManager.isCharging || batteryManager.isPluggedIn {
            return Color(red: 0.46, green: 0.96, blue: 0.56)
        }
        if batteryManager.isLowBattery {
            return Color(red: 1.0, green: 0.33, blue: 0.40)
        }
        return Color(red: 0.46, green: 0.93, blue: 0.52)
    }

    private var batteryTerminalColor: Color {
        if batteryManager.isCharging || batteryManager.isPluggedIn {
            return Color(white: 0.62)
        }
        if batteryManager.isLowBattery {
            return Color(red: 0.68, green: 0.14, blue: 0.20)
        }
        return Color(red: 0.20, green: 0.56, blue: 0.28)
    }

    private var batteryChargingSegmentColor: Color {
        Color(white: 0.58)
    }

    private func glyphBodyWidth(for iconSize: CGFloat) -> CGFloat {
        if layout.isDynamicIslandMode {
            return max(20, iconSize * 1.22)
        }
        return max(24, iconSize * 1.38)
    }

    private func glyphBodyHeight(for iconSize: CGFloat) -> CGFloat {
        if layout.isDynamicIslandMode {
            return max(10.5, iconSize * 0.68)
        }
        return max(13, iconSize * 0.78)
    }

    private func glyphFrameWidth(for iconSize: CGFloat) -> CGFloat {
        glyphBodyWidth(for: iconSize) + 6
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if layout.isDynamicIslandMode {
                // DYNAMIC ISLAND: Icon on left edge, percentage on right edge
                let iconSize = layout.iconSize
                let bodyWidth = glyphBodyWidth(for: iconSize)
                let bodyHeight = glyphBodyHeight(for: iconSize)
                let iconFrameWidth = glyphFrameWidth(for: iconSize)
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                
                HStack {
                    // Battery icon - .leading alignment within frame for edge alignment
                    IOSBatteryGlyph(
                        level: CGFloat(batteryManager.batteryLevel) / 100.0,
                        outerColor: batteryOuterColor,
                        innerColor: batteryInnerColor,
                        terminalColor: batteryTerminalColor,
                        chargingSegmentColor: batteryChargingSegmentColor,
                        isCharging: batteryManager.isCharging || batteryManager.isPluggedIn,
                        bodyWidth: bodyWidth,
                        bodyHeight: bodyHeight
                    )
                        .frame(width: iconFrameWidth, height: iconSize, alignment: .leading)
                    
                    Spacer()
                    
                    // Percentage
                    Text("\(batteryManager.batteryLevel)%")
                        .font(.system(size: layout.labelFontSize, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(batteryManager.batteryLevel)))
                }
                .padding(.horizontal, symmetricPadding)
                .frame(height: layout.notchHeight)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                let iconSize = layout.iconSize
                let bodyWidth = glyphBodyWidth(for: iconSize)
                let bodyHeight = glyphBodyHeight(for: iconSize)
                let iconFrameWidth = glyphFrameWidth(for: iconSize)
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                let wingWidth = layout.wingWidth(for: hudWidth)
                
                HStack(spacing: 0) {
                    // Left wing: Battery icon near left edge
                    HStack {
                        IOSBatteryGlyph(
                            level: CGFloat(batteryManager.batteryLevel) / 100.0,
                            outerColor: batteryOuterColor,
                            innerColor: batteryInnerColor,
                            terminalColor: batteryTerminalColor,
                            chargingSegmentColor: batteryChargingSegmentColor,
                            isCharging: batteryManager.isCharging || batteryManager.isPluggedIn,
                            bodyWidth: bodyWidth,
                            bodyHeight: bodyHeight
                        )
                            .frame(width: iconFrameWidth, height: iconSize, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, symmetricPadding)
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: layout.notchWidth)
                    
                    // Right wing: Percentage near right edge
                    HStack {
                        Spacer(minLength: 0)
                        Text("\(batteryManager.batteryLevel)%")
                            .font(.system(size: layout.labelFontSize, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(batteryManager.batteryLevel)))
                            .animation(DroppyAnimation.notchState, value: batteryManager.batteryLevel)
                    }
                    .padding(.trailing, symmetricPadding)
                    .frame(width: wingWidth)
                }
                .frame(height: layout.notchHeight)
            }
        }
        .animation(DroppyAnimation.notchState, value: batteryManager.batteryLevel)
        .animation(DroppyAnimation.notchState, value: batteryManager.isCharging)
    }
}

#Preview {
    ZStack {
        Color.black
        BatteryHUDView(
            batteryManager: BatteryManager.shared,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
