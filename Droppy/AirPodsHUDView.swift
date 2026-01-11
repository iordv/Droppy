//
//  AirPodsHUDView.swift
//  Droppy
//
//  Created by Droppy on 11/01/2026.
//  Animated AirPods connection HUD for the notch/Dynamic Island
//

import SwiftUI

/// Animated AirPods HUD that appears when AirPods connect
/// Uses smooth SwiftUI animations mimicking iOS-style popup
struct AirPodsHUDView: View {
    let airpods: ConnectedAirPods
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let hudWidth: CGFloat
    
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: CGFloat = 0
    @State private var textOpacity: CGFloat = 0
    @State private var glowOpacity: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    /// Whether we're in Dynamic Island mode
    private var isDynamicIslandMode: Bool {
        guard let screen = NSScreen.main else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    /// Width of each "wing" (area left/right of physical notch)
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isDynamicIslandMode {
                // DYNAMIC ISLAND: Compact horizontal layout
                dynamicIslandLayout
            } else {
                // NOTCH MODE: Wider layout with wings
                notchLayout
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - Dynamic Island Layout
    
    private var dynamicIslandLayout: some View {
        HStack(spacing: 12) {
            // Animated AirPods icon
            airpodsIconView
                .frame(width: 28, height: 28)
            
            // Device name + Connected
            VStack(alignment: .leading, spacing: 2) {
                Text(airpods.deviceType.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("Connected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .opacity(textOpacity)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: notchHeight)
    }
    
    // MARK: - Notch Layout
    
    private var notchLayout: some View {
        HStack(spacing: 0) {
            // Left wing: AirPods icon with animation
            HStack {
                airpodsIconView
                    .frame(width: 32, height: 32)
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .frame(width: wingWidth)
            
            // Camera notch area (spacer)
            Spacer()
                .frame(width: notchWidth)
            
            // Right wing: Device name + Connected
            HStack {
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(airpods.deviceType.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text("Connected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .opacity(textOpacity)
            }
            .padding(.trailing, 12)
            .frame(width: wingWidth)
        }
        .frame(height: notchHeight)
    }
    
    // MARK: - Animated AirPods Icon
    
    private var airpodsIconView: some View {
        ZStack {
            // Pulsing glow background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.4),
                            Color.blue.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .scaleEffect(pulseScale)
                .opacity(glowOpacity)
            
            // AirPods SF Symbol with bounce animation
            Image(systemName: airpods.deviceType.sfSymbol)
                .font(.system(size: isDynamicIslandMode ? 22 : 26, weight: .medium))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
        }
    }
    
    // MARK: - Animation Sequence
    
    private func startAnimation() {
        // Phase 1: Icon appears with spring bounce
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        // Phase 2: Glow pulses in
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            glowOpacity = 0.8
        }
        
        // Phase 3: Text fades in
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            textOpacity = 1.0
        }
        
        // Phase 4: Continuous subtle pulse
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
            pulseScale = 1.2
        }
    }
}

// MARK: - Preview

#Preview("AirPods HUD - Dynamic Island") {
    ZStack {
        Color.black
        
        AirPodsHUDView(
            airpods: ConnectedAirPods(name: "Jordy's AirPods Pro", deviceType: .airpodsPro),
            notchWidth: 120,
            notchHeight: 37,
            hudWidth: 280
        )
        .background(
            Capsule()
                .fill(Color.black)
        )
    }
    .frame(width: 350, height: 100)
}

#Preview("AirPods HUD - Notch") {
    ZStack {
        Color.gray.opacity(0.3)
        
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.black)
            .frame(width: 320, height: 50)
            .overlay {
                AirPodsHUDView(
                    airpods: ConnectedAirPods(name: "Jordy's AirPods Max", deviceType: .airpodsMax),
                    notchWidth: 180,
                    notchHeight: 37,
                    hudWidth: 320
                )
            }
    }
    .frame(width: 400, height: 150)
}
