//
//  PomodoroHUDView.swift
//  Droppy
//
//  Created by Droppy on 18/01/2026.
//  Beautiful Pomodoro HUD matching Volume/Brightness style
//

import SwiftUI

/// Compact Pomodoro HUD that sits inside the notch
/// Matches MediaHUDView layout: icon on left wing, time on right wing
struct PomodoroHUDView: View {
    @ObservedObject var pomodoroManager: PomodoroManager
    let notchWidth: CGFloat   // Physical notch width
    let notchHeight: CGFloat  // Physical notch height
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    @State private var pulseAnimation: Bool = false
    
    /// Width of each "wing" (area left/right of physical notch)
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    /// Accent color based on timer state
    private var accentColor: Color {
        if pomodoroManager.remainingSeconds == 0 && pomodoroManager.totalSeconds > 0 {
            return .green // Completed
        } else if pomodoroManager.isPaused {
            return .orange
        } else {
            return .red.opacity(0.9) // Active - tomato red for Pomodoro
        }
    }
    
    /// Dynamic timer icon based on state
    private var timerIcon: String {
        if pomodoroManager.remainingSeconds == 0 && pomodoroManager.totalSeconds > 0 {
            return "checkmark.circle.fill"
        } else if pomodoroManager.isPaused {
            return "pause.circle.fill"
        } else {
            return "timer"
        }
    }
    
    /// Whether we're in Dynamic Island mode (screen-aware for multi-monitor)
    private var isDynamicIslandMode: Bool {
        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        
        if !screen.isBuiltIn {
            return true
        }
        
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if isDynamicIslandMode {
                dynamicIslandLayout
            } else {
                notchLayout
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                pomodoroManager.togglePause()
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                pomodoroManager.stop()
            }
        }
    }
    
    // MARK: - Dynamic Island Layout
    
    private var dynamicIslandLayout: some View {
        let iconSize: CGFloat = 18
        let symmetricPadding = (notchHeight - iconSize) / 2
        
        return HStack {
            // Timer icon with progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: iconSize + 4, height: iconSize + 4)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: pomodoroManager.remainingProgress)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: iconSize + 4, height: iconSize + 4)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: pomodoroManager.remainingSeconds)
                
                // Icon
                Image(systemName: timerIcon)
                    .font(.system(size: iconSize - 4, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .symbolEffect(.bounce, value: pomodoroManager.isPaused)
                    .contentTransition(.symbolEffect(.replace.byLayer))
            }
            .frame(width: iconSize + 6, height: iconSize + 6, alignment: .leading)
            
            Spacer()
            
            // Time remaining
            Text(pomodoroManager.shortFormattedTime)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(accentColor)
                .contentTransition(.numericText(value: Double(pomodoroManager.remainingSeconds)))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: pomodoroManager.remainingSeconds)
        }
        .padding(.horizontal, symmetricPadding)
        .frame(height: notchHeight)
    }
    
    // MARK: - Notch Layout
    
    private var notchLayout: some View {
        let iconSize: CGFloat = 20
        let symmetricPadding = max((notchHeight - iconSize) / 2, 6)
        
        return HStack(spacing: 0) {
            // Left wing: Timer icon with progress ring
            HStack {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
                        .frame(width: iconSize + 4, height: iconSize + 4)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: pomodoroManager.remainingProgress)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: iconSize + 4, height: iconSize + 4)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: pomodoroManager.remainingSeconds)
                    
                    // Icon
                    Image(systemName: timerIcon)
                        .font(.system(size: iconSize - 6, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .symbolEffect(.bounce, value: pomodoroManager.isPaused)
                        .contentTransition(.symbolEffect(.replace.byLayer))
                }
                .frame(width: iconSize + 6, height: iconSize + 6, alignment: .leading)
                
                Spacer(minLength: 0)
            }
            .padding(.leading, symmetricPadding)
            .frame(width: wingWidth)
            
            // Camera notch area (spacer)
            Spacer()
                .frame(width: notchWidth)
            
            // Right wing: Time near right edge
            HStack {
                Spacer(minLength: 0)
                
                Text(pomodoroManager.shortFormattedTime)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .contentTransition(.numericText(value: Double(pomodoroManager.remainingSeconds)))
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: pomodoroManager.remainingSeconds)
            }
            .padding(.trailing, symmetricPadding)
            .frame(width: wingWidth)
        }
        .frame(height: notchHeight)
    }
}

// MARK: - Timer Reveal View

/// The draggable timer icon that follows the cursor during reveal gesture
struct PomodoroRevealView: View {
    let offset: CGFloat
    let isRevealing: Bool
    
    var body: some View {
        ZStack {
            // Background pill
            Capsule()
                .fill(Color.red.opacity(0.9))
                .frame(width: 44, height: 28)
            
            // Timer icon
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .symbolEffect(.bounce, value: isRevealing)
        }
        .offset(x: offset)
        .opacity(isRevealing ? 1 : 0)
        .scaleEffect(isRevealing ? 1 : 0.5)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRevealing)
    }
}

#Preview {
    ZStack {
        Color.black
        PomodoroHUDView(
            pomodoroManager: PomodoroManager.shared,
            notchWidth: 180,
            notchHeight: 32,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
