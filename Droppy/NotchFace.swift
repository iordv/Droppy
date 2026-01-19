//
//  NotchFace.swift
//  Droppy
//
//  Custom animated face for the shelf when empty.
//  Pure SwiftUI shapes for true 120fps buttery smooth animation.
//  CPU-efficient: Timer only runs when view is visible.
//

import SwiftUI

/// Custom NotchFace with 120fps smooth winking animation
struct NotchFace: View {
    var size: CGFloat = 30
    var isExcited: Bool = false
    
    @State private var eyeScale: CGFloat = 1.0
    @State private var smileScale: CGFloat = 1.0
    @State private var winkTimer: Timer?
    
    // Gradient for premium look
    private var faceGradient: LinearGradient {
        LinearGradient(
            colors: [.white, Color(red: 0.72, green: 0.86, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var body: some View {
        ZStack {
            // Left eye (goes wide on hover)
            Ellipse()
                .fill(faceGradient)
                .frame(
                    width: size * 0.22,
                    height: size * 0.22 * (isExcited ? 1.4 : 1.0)
                )
                .offset(x: -size * 0.18, y: -size * 0.12)
            
            // Right eye (winks normally, goes wide on hover)
            Ellipse()
                .fill(faceGradient)
                .frame(
                    width: size * 0.22,
                    height: size * 0.22 * (isExcited ? 1.4 : eyeScale)
                )
                .offset(x: size * 0.18, y: -size * 0.12)
            
            // Nose
            Circle()
                .fill(faceGradient)
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(y: size * 0.04)
            
            // Mouth - always smile curve (no change on hover)
            SmileCurve()
                .stroke(faceGradient, style: StrokeStyle(
                    lineWidth: size * 0.1,
                    lineCap: .round
                ))
                .frame(width: size * 0.42 * smileScale, height: size * 0.18 * smileScale)
                .offset(y: size * 0.26)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: size * 0.03, y: size * 0.03)
        .scaleEffect(isExcited ? 1.1 : 1.0, anchor: .center)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isExcited)
        .animation(.interpolatingSpring(stiffness: 180, damping: 14), value: eyeScale)
        .animation(.interpolatingSpring(stiffness: 180, damping: 14), value: smileScale)
        .onAppear { startWinking() }
        .onDisappear { stopWinking() }
    }
    
    private func startWinking() {
        winkTimer?.invalidate()
        winkTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            performWink()
        }
    }
    
    private func stopWinking() {
        winkTimer?.invalidate()
        winkTimer = nil
        eyeScale = 1.0
        smileScale = 1.0
    }
    
    private func performWink() {
        guard !isExcited else { return }
        
        // Ultra-smooth close with slight overshoot
        eyeScale = 0.04
        smileScale = 1.08
        
        // Smooth open with gentle bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            eyeScale = 1.0
            smileScale = 1.0
        }
    }
}

/// Smile curve shape
private struct SmileCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.height)
        )
        return path
    }
}

#Preview {
    HStack(spacing: 40) {
        ZStack {
            Color.black
            NotchFace(size: 60, isExcited: false)
        }
        .frame(width: 80, height: 80)
        
        ZStack {
            Color.black
            NotchFace(size: 60, isExcited: true)
        }
        .frame(width: 80, height: 80)
    }
}
