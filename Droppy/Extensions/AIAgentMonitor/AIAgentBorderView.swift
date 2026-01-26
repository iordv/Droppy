//
//  AIAgentBorderView.swift
//  Droppy
//
//  Animated pulsing border when coding agent is active
//

import SwiftUI

struct AIAgentBorderView: View {
    @ObservedObject private var manager = AIAgentMonitorManager.shared

    // Animation state
    @State private var pulsePhase: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0.4

    // Border configuration
    let lineWidth: CGFloat = 2.5

    var body: some View {
        if manager.isActive && manager.borderEnabled {
            GeometryReader { geometry in
                ZStack {
                    // Outer glow layer
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            manager.currentSource.borderColor.opacity(glowIntensity * 0.6),
                            lineWidth: lineWidth + 6
                        )
                        .blur(radius: 8)

                    // Middle glow layer
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            manager.currentSource.borderColor.opacity(glowIntensity * 0.8),
                            lineWidth: lineWidth + 3
                        )
                        .blur(radius: 4)

                    // Main border
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            manager.currentSource.borderColor,
                            lineWidth: lineWidth
                        )
                        .shadow(
                            color: manager.currentSource.borderColor.opacity(glowIntensity),
                            radius: 12
                        )
                }
            }
            .onAppear {
                startPulseAnimation()
            }
            .onDisappear {
                stopPulseAnimation()
            }
            .onChange(of: manager.isActive) { _, isActive in
                if isActive {
                    startPulseAnimation()
                } else {
                    stopPulseAnimation()
                }
            }
        }
    }

    private func startPulseAnimation() {
        guard manager.borderPulsing else {
            glowIntensity = 0.6
            return
        }

        // Continuous pulse animation
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.9
        }
    }

    private func stopPulseAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            glowIntensity = 0.4
        }
    }
}

// MARK: - Simplified glow for closed notch

struct AIAgentBorderGlow: View {
    @ObservedObject private var manager = AIAgentMonitorManager.shared
    @State private var glowIntensity: CGFloat = 0.5

    var body: some View {
        if manager.isActive && manager.borderEnabled {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            manager.currentSource.borderColor.opacity(glowIntensity * 0.8),
                            manager.currentSource.borderColor.opacity(0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 3)
                .blur(radius: 2)
                .onAppear {
                    if manager.borderPulsing {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            glowIntensity = 1.0
                        }
                    }
                }
        }
    }
}

// MARK: - Notch-shaped border

struct AIAgentNotchBorderView: View {
    @ObservedObject private var manager = AIAgentMonitorManager.shared

    @State private var glowIntensity: CGFloat = 0.4
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    var body: some View {
        if manager.isActive && manager.borderEnabled {
            NotchBorderShape(notchWidth: notchWidth, notchHeight: notchHeight)
                .stroke(
                    manager.currentSource.borderColor,
                    lineWidth: 2.5
                )
                .shadow(color: manager.currentSource.borderColor.opacity(glowIntensity), radius: 8)
                .onAppear {
                    if manager.borderPulsing {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            glowIntensity = 0.9
                        }
                    }
                }
        }
    }
}

// MARK: - Custom shape for notch border

struct NotchBorderShape: Shape {
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let cornerRadius: CGFloat = 12
        let notchCornerRadius: CGFloat = 8

        // Start from bottom left
        path.move(to: CGPoint(x: 0, y: rect.height))

        // Left side up to notch
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )

        // Top left to notch start
        let notchStartX = (rect.width - notchWidth) / 2
        path.addLine(to: CGPoint(x: notchStartX - notchCornerRadius, y: 0))

        // Notch left curve down
        path.addQuadCurve(
            to: CGPoint(x: notchStartX, y: notchCornerRadius),
            control: CGPoint(x: notchStartX, y: 0)
        )

        // Notch left side
        path.addLine(to: CGPoint(x: notchStartX, y: notchHeight - notchCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: notchStartX + notchCornerRadius, y: notchHeight),
            control: CGPoint(x: notchStartX, y: notchHeight)
        )

        // Notch bottom
        let notchEndX = notchStartX + notchWidth
        path.addLine(to: CGPoint(x: notchEndX - notchCornerRadius, y: notchHeight))
        path.addQuadCurve(
            to: CGPoint(x: notchEndX, y: notchHeight - notchCornerRadius),
            control: CGPoint(x: notchEndX, y: notchHeight)
        )

        // Notch right side
        path.addLine(to: CGPoint(x: notchEndX, y: notchCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: notchEndX + notchCornerRadius, y: 0),
            control: CGPoint(x: notchEndX, y: 0)
        )

        // Top right
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: cornerRadius),
            control: CGPoint(x: rect.width, y: 0)
        )

        // Right side
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))

        return path
    }
}

#Preview("AI Agent Border") {
    ZStack {
        Color.gray.opacity(0.3)

        RoundedRectangle(cornerRadius: 20)
            .fill(.black)
            .frame(width: 400, height: 180)

        AIAgentBorderView()
            .frame(width: 400, height: 180)
    }
    .frame(width: 500, height: 300)
}
