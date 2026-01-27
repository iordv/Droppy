//
//  SiriNotchView.swift
//  Droppy
//
//  Animated Siri HUD view that appears in the notch
//  Features: Animated gradient waveform, transcription display
//

import SwiftUI

/// Animated Siri HUD that displays in the notch when Siri is active
struct SiriNotchView: View {
    @ObservedObject var manager: SiriNotchManager
    let hudWidth: CGFloat
    var targetScreen: NSScreen? = nil
    
    /// Centralized layout calculator
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first!)
    }
    
    /// Whether we're in compact mode (Dynamic Island style)
    private var isCompact: Bool {
        layout.isDynamicIslandMode
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if isCompact {
                compactLayout
            } else {
                expandedNotchLayout
            }
        }
        .contentShape(Rectangle())
    }
    
    // MARK: - Compact Layout (Dynamic Island)
    
    private var compactLayout: some View {
        HStack(spacing: 12) {
            // Siri icon
            siriIconView(size: 26)
            
            // Waveform animation
            SiriWaveformView(isListening: manager.isListening)
                .frame(width: 80, height: 20)
            
            // Transcription text (if available)
            if !manager.transcription.isEmpty {
                Text(manager.transcription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: layout.notchHeight)
    }
    
    // MARK: - Expanded Notch Layout (Full Notch with Wings)
    
    private var expandedNotchLayout: some View {
        HStack(spacing: 0) {
            // Left wing: Siri icon
            leftWing
                .frame(width: wingWidth)
            
            // Notch spacer
            Spacer()
                .frame(width: layout.notchWidth)
            
            // Right wing: Waveform
            rightWing
                .frame(width: wingWidth)
        }
        .frame(height: layout.notchHeight)
    }
    
    private var wingWidth: CGFloat {
        (hudWidth - layout.notchWidth) / 2
    }
    
    // MARK: - Left Wing
    
    private var leftWing: some View {
        HStack(spacing: 8) {
            siriIconView(size: 22)
            
            Text("Siri")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
    }
    
    // MARK: - Right Wing
    
    private var rightWing: some View {
        HStack {
            Spacer(minLength: 0)
            
            SiriWaveformView(isListening: manager.isListening)
                .frame(width: 60, height: 18)
        }
        .padding(.trailing, 12)
    }
    
    // MARK: - Siri Icon
    
    @ViewBuilder
    private func siriIconView(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple, .pink, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Image(systemName: "waveform")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(.white)
        }
        .shadow(color: .purple.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Siri Waveform Animation

/// Animated waveform bars that pulse when Siri is listening
struct SiriWaveformView: View {
    let isListening: Bool
    
    @State private var animationPhase: CGFloat = 0
    
    private let barCount = 5
    private let barSpacing: CGFloat = 4
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                waveformBar(index: index)
            }
        }
        .onAppear {
            guard isListening else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                animationPhase = 1.0
            }
        }
        .onChange(of: isListening) { _, listening in
            if listening {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    animationPhase = 1.0
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    animationPhase = 0
                }
            }
        }
    }
    
    @ViewBuilder
    private func waveformBar(index: Int) -> some View {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 18
        let phase = CGFloat(index) * 0.2
        let heightMultiplier = isListening ? sin((animationPhase + phase) * .pi) : 0.3
        let barHeight = baseHeight + (maxHeight - baseHeight) * abs(heightMultiplier)
        
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [.purple, .pink, .blue],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 4, height: barHeight)
            .animation(
                .easeInOut(duration: 0.4)
                    .delay(Double(index) * 0.05),
                value: animationPhase
            )
    }
}

// MARK: - Preview

#Preview("Siri Notch HUD") {
    ZStack {
        Color.black.opacity(0.9)
        
        VStack(spacing: 40) {
            // Simulated notch area
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black)
                    .frame(width: 400, height: 80)
                
                SiriNotchView(
                    manager: SiriNotchManager.shared,
                    hudWidth: 400
                )
            }
            
            Text("Siri waveform animation")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .frame(width: 500, height: 200)
}
