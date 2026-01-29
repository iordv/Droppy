//
//  CaffeineNotchView.swift
//  Droppy
//

import SwiftUI

struct CaffeineNotchView: View {
    var manager: CaffeineManager
    @Binding var isVisible: Bool
    
    var notchHeight: CGFloat = 0
    var isExternalWithNotchStyle: Bool = false
    
    @AppStorage(AppPreferenceKey.caffeineMode) private var caffeineMode = PreferenceDefault.caffeineMode
    
    // Layout helpers
    private var contentPadding: EdgeInsets {
        NotchLayoutConstants.contentEdgeInsets(notchHeight: notchHeight, isExternalWithNotchStyle: isExternalWithNotchStyle)
    }
    
    private let minutePresets: [CaffeineDuration] = [.minutes(15), .minutes(30)]
    private let hourPresets: [CaffeineDuration] = [.hours(1), .hours(2), .hours(3), .hours(4), .hours(5)]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // Toggle Section
                VStack(spacing: 6) {
                    Button {
                        toggleCaffeine()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(manager.isActive ? .orange.opacity(0.2) : .white.opacity(0.05))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(manager.isActive ? .orange : .white.opacity(0.1), lineWidth: 2)
                                )
                            
                            Image(systemName: manager.isActive ? "eyes" : "eyes")
                                .font(.system(size: 20))
                                .foregroundStyle(manager.isActive ? .orange : .white.opacity(0.8))
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .buttonStyle(DroppyCircleButtonStyle(size: 44))
                    
                    Text(statusText)
                        .font(.system(size: statusText == "∞" ? 22 : 11, weight: .medium, design: .monospaced))
                        .offset(y: statusText == "∞" ? -3 : 0)
                        .foregroundStyle(manager.isActive ? .orange : .white.opacity(0.5))
                        .animation(.smooth, value: statusText)
                }
                .frame(width: 60)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                    .frame(height: 50)
                
                // Timer Controls - Perfectly Centered
                VStack(spacing: 8) {
                    // Top row: Minutes (wider buttons)
                    HStack(spacing: 8) {
                        ForEach(minutePresets, id: \.displayName) { duration in
                            CaffeineTimerButton(
                                duration: duration,
                                isActive: manager.isActive && manager.currentDuration == duration
                            ) {
                                selectDuration(duration)
                            }
                        }
                    }
                    
                    // Bottom row: Hours (compact grid)
                    HStack(spacing: 8) {
                        ForEach(hourPresets, id: \.displayName) { duration in
                            CaffeineTimerButton(
                                duration: duration,
                                isActive: manager.isActive && manager.currentDuration == duration
                            ) {
                                selectDuration(duration)
                            }
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(contentPadding)
    }
    
    private var statusText: String {
        guard manager.isActive else { return "SLEEP" }
        return manager.currentDuration == CaffeineDuration.indefinite ? "∞" : manager.formattedRemaining
    }
    
    private func toggleCaffeine() {
        HapticFeedback.drop()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if manager.isActive {
                manager.deactivate()
            } else {
                let mode = CaffeineMode(rawValue: caffeineMode) ?? .both
                manager.activate(duration: CaffeineDuration.indefinite, mode: mode)
            }
        }
    }
    
    private func selectDuration(_ duration: CaffeineDuration) {
        HapticFeedback.tap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let isActive = manager.isActive && manager.currentDuration == duration
            if isActive {
                manager.deactivate()
            } else {
                let mode = CaffeineMode(rawValue: caffeineMode) ?? .both
                manager.activate(duration: duration, mode: mode)
            }
        }
    }
}

// MARK: - Components

struct CaffeineTimerButton: View {
    let duration: CaffeineDuration
    let isActive: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Text(duration.shortLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(isActive ? Color.orange : Color.white.opacity(isHovering ? 0.18 : 0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(isActive ? 0 : 0.1), lineWidth: 1)
                )
                .scaleEffect(isHovering ? 1.02 : 1.0)
                .animation(DroppyAnimation.hoverQuick, value: isHovering)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            if hovering { HapticFeedback.hover() }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        CaffeineNotchView(
            manager: CaffeineManager.shared,
            isVisible: .constant(true),
            notchHeight: 32
        )
        .frame(width: 400, height: 180)
    }
}
