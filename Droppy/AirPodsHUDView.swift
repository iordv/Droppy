//
//  AirPodsHUDView.swift
//  Droppy
//
//  Created by Droppy on 11/01/2026.
//  AirPods connection animation HUD - mimics iPhone's AirPods popup
//  Layout matches MediaHUDView for consistent positioning
//

import SwiftUI

/// Model representing connected Bluetooth audio device (AirPods or headphones)
struct ConnectedAirPods: Equatable {
    let name: String
    let type: DeviceType
    let batteryLevel: Int // Combined battery percentage (0-100)
    let leftBattery: Int?
    let rightBattery: Int?
    let caseBattery: Int?
    
    /// Device type - supports AirPods variants and generic headphones
    enum DeviceType: String, CaseIterable {
        // AirPods family
        case airpods = "airpods"
        case airpodsPro = "airpodspro"
        case airpodsMax = "airpodsmax"
        case airpodsGen3 = "airpods.gen3"
        
        // Generic headphones
        case headphones = "headphones"
        case beats = "beats.headphones"
        case earbuds = "earbuds"
        
        /// SF Symbol name for this device type
        var symbolName: String {
            switch self {
            case .airpods: return "airpods"
            case .airpodsPro: return "airpodspro"
            case .airpodsMax: return "airpodsmax"
            case .airpodsGen3: return "airpods.gen3"
            case .headphones: return "headphones"
            case .beats: return "beats.headphones"
            case .earbuds: return "earbuds"
            }
        }
        
        /// Display name for this device type
        var displayName: String {
            switch self {
            case .airpods: return "AirPods"
            case .airpodsPro: return "AirPods Pro"
            case .airpodsMax: return "AirPods Max"
            case .airpodsGen3: return "AirPods 3"
            case .headphones: return "Headphones"
            case .beats: return "Beats"
            case .earbuds: return "Earbuds"
            }
        }
        
        /// Whether this is an AirPods type (vs generic headphones)
        var isAirPods: Bool {
            switch self {
            case .airpods, .airpodsPro, .airpodsMax, .airpodsGen3:
                return true
            case .headphones, .beats, .earbuds:
                return false
            }
        }
    }
    
    // Legacy alias for backwards compatibility
    typealias AirPodsType = DeviceType
}

/// AirPods connection HUD with premium, stable motion
/// - No icon spinning (avoids flat/paper look on SF Symbols)
/// - Depth from layered lighting + shadow
/// - Smooth spring entrance with subtle breathing
struct AirPodsHUDView: View {
    let airPods: ConnectedAirPods
    let hudWidth: CGFloat
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    /// Centralized layout calculator - Single Source of Truth
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }
    
    // Animation states
    @State private var iconScale: CGFloat = 0.4
    @State private var iconOpacity: CGFloat = 0
    @State private var iconLift: CGFloat = 5
    @State private var iconBreathingScale: CGFloat = 0.98
    @State private var iconSheenOpacity: CGFloat = 0.2
    @State private var batteryOpacity: CGFloat = 0
    @State private var batteryScale: CGFloat = 0.8
    @State private var ringProgress: CGFloat = 0
    
    /// Battery ring color based on level
    private var batteryColor: Color {
        if airPods.batteryLevel >= 50 {
            return .green
        } else if airPods.batteryLevel >= 20 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if layout.isDynamicIslandMode {
                dynamicIslandContent
            } else {
                notchModeContent
            }
        }
        .onAppear {
            startPremiumConnectionAnimation()
        }
    }
    
    // MARK: - Dynamic Island Layout
    
    private var dynamicIslandContent: some View {
        let iconSize = layout.iconSize
        let symmetricPadding = layout.symmetricPadding(for: iconSize)
        
        return ZStack {
            // Device name - centered
            VStack {
                Spacer(minLength: 0)
                Text("Connected")
                    .font(.system(size: layout.labelFontSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(height: 16)
                    .opacity(batteryOpacity)
                    .scaleEffect(batteryScale)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 40)
            
            // Icon (left edge) and Battery ring (right edge)
            HStack {
                airPodsIconView(size: iconSize)
                Spacer()
                batteryRingView(size: 20)
            }
            .padding(.horizontal, symmetricPadding)
        }
        .frame(height: layout.notchHeight)
    }
    
    // MARK: - Notch Mode Layout
    
    private var notchModeContent: some View {
        let iconSize = layout.iconSize
        let symmetricPadding = layout.symmetricPadding(for: iconSize)
        let wingWidth = layout.wingWidth(for: hudWidth)
        
        return HStack(spacing: 0) {
            // Left wing: AirPods icon near left edge
            HStack {
                airPodsIconView(size: iconSize)
                    .frame(width: iconSize, height: iconSize, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(.leading, symmetricPadding)
            .frame(width: wingWidth)
            
            // Camera notch area (spacer)
            Spacer()
                .frame(width: layout.notchWidth)
            
            // Right wing: Battery ring near right edge
            HStack {
                Spacer(minLength: 0)
                batteryRingView(size: iconSize)
            }
            .padding(.trailing, symmetricPadding)
            .frame(width: wingWidth)
        }
        .frame(height: layout.notchHeight)
    }
    
    // MARK: - AirPods Icon (premium depth, no rotation)
    
    @ViewBuilder
    private func airPodsIconView(size: CGFloat) -> some View {
        ZStack {
            // Soft depth pass behind the main glyph
            Image(systemName: airPods.type.symbolName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.black.opacity(0.28))
                .offset(x: 1.1, y: 1.6)
                .blur(radius: 0.2)

            // Main glyph
            Image(systemName: airPods.type.symbolName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.98),
                            .white.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Specular highlight pass to fake depth on SF symbol
            Image(systemName: airPods.type.symbolName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.9), .white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .opacity(iconSheenOpacity)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.28), radius: 3, y: 2)
        .scaleEffect(iconScale * iconBreathingScale)
        .offset(y: iconLift)
        .opacity(iconOpacity)
    }
    
    // MARK: - Battery Ring
    
    @ViewBuilder
    private func batteryRingView(size: CGFloat) -> some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(AdaptiveColors.overlayAuto(0.15), lineWidth: 3)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    batteryColor,
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
            
            // Battery percentage text
            Text("\(airPods.batteryLevel)")
                .font(.system(size: size > 24 ? 11 : 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(width: size, height: size)
        .opacity(batteryOpacity)
        .scaleEffect(batteryScale)
    }
    
    // MARK: - Premium Connection Animation (BUTTERY SMOOTH)
    
    private func startPremiumConnectionAnimation() {
        // Phase 1: icon settles in with spring and slight lift
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
            iconScale = 1.0
            iconOpacity = 1.0
            iconLift = 0
        }
        
        // Phase 2: subtle breathing + sheen pulse (no spinning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                iconBreathingScale = 1.02
                iconSheenOpacity = 0.45
            }
        }
        
        // Phase 3: battery info fades in with bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.65, blendDuration: 0)) {
                batteryOpacity = 1.0
                batteryScale = 1.0
            }
        }
        
        // Phase 4: ring fills smoothly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.interactiveSpring(response: 0.8, dampingFraction: 0.85, blendDuration: 0)) {
                ringProgress = CGFloat(airPods.batteryLevel) / 100
            }
        }
    }
}

// MARK: - Preview

#Preview("AirPods HUD - Dynamic Island") {
    ZStack {
        Color.black
        AirPodsHUDView(
            airPods: ConnectedAirPods(
                name: "Jordy's AirPods Pro",
                type: .airpodsPro,
                batteryLevel: 85,
                leftBattery: 85,
                rightBattery: 90,
                caseBattery: 75
            ),
            hudWidth: 260
        )
    }
    .frame(width: 300, height: 60)
}

#Preview("AirPods HUD - Notch Mode") {
    ZStack {
        Color.black
        AirPodsHUDView(
            airPods: ConnectedAirPods(
                name: "Jordy's AirPods Pro",
                type: .airpodsPro,
                batteryLevel: 45,
                leftBattery: 45,
                rightBattery: 50,
                caseBattery: nil
            ),
            hudWidth: 280
        )
    }
    .frame(width: 320, height: 60)
}

#Preview("Generic Headphones") {
    ZStack {
        Color.black
        AirPodsHUDView(
            airPods: ConnectedAirPods(
                name: "Sony WH-1000XM5",
                type: .headphones,
                batteryLevel: 72,
                leftBattery: nil,
                rightBattery: nil,
                caseBattery: nil
            ),
            hudWidth: 280
        )
    }
    .frame(width: 320, height: 60)
}

#Preview("Beats Headphones") {
    ZStack {
        Color.black
        AirPodsHUDView(
            airPods: ConnectedAirPods(
                name: "Beats Studio Pro",
                type: .beats,
                batteryLevel: 60,
                leftBattery: nil,
                rightBattery: nil,
                caseBattery: nil
            ),
            hudWidth: 280
        )
    }
    .frame(width: 320, height: 60)
}

#Preview("Low Battery AirPods") {
    ZStack {
        Color.black
        AirPodsHUDView(
            airPods: ConnectedAirPods(
                name: "AirPods",
                type: .airpods,
                batteryLevel: 15,
                leftBattery: 10,
                rightBattery: 20,
                caseBattery: nil
            ),
            hudWidth: 280
        )
    }
    .frame(width: 320, height: 60)
}
