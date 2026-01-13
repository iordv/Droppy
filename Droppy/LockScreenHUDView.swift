//
//  LockScreenHUDView.swift
//  Droppy
//
//  Created by Droppy on 13/01/2026.
//  Lock/Unlock HUD - iPhone-style unlock animation
//

import SwiftUI

/// Compact Lock Screen HUD that sits inside the notch
/// Shows just the lock icon with smooth unlock animation like iPhone
struct LockScreenHUDView: View {
    @ObservedObject var lockScreenManager: LockScreenManager
    let notchWidth: CGFloat   // Physical notch width
    let notchHeight: CGFloat  // Physical notch height
    let hudWidth: CGFloat     // Total HUD width
    
    // Animation states
    @State private var showUnlockAnim = false
    @State private var lockScale: CGFloat = 1.0
    @State private var lockOpacity: Double = 1.0
    
    /// Width of each "wing" (area left/right of physical notch)
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    /// Whether we're unlocked
    private var isUnlocked: Bool {
        lockScreenManager.lastEvent == .unlocked
    }
    
    /// Whether we're in Dynamic Island mode
    private var isDynamicIslandMode: Bool {
        guard let screen = NSScreen.main else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if isDynamicIslandMode {
                // DYNAMIC ISLAND: Centered icon with animation
                lockIconView
                    .frame(maxWidth: .infinity)
                    .frame(height: notchHeight)
            } else {
                // NOTCH MODE: Icon on left wing only
                HStack(spacing: 0) {
                    // Left wing: Lock icon near left edge
                    HStack {
                        lockIconView
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 8)
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: notchWidth)
                    
                    // Right wing: Empty
                    Spacer()
                        .frame(width: wingWidth)
                }
                .frame(height: notchHeight)
            }
        }
        .onAppear {
            if isUnlocked {
                triggerUnlockAnimation()
            }
        }
        .onChange(of: lockScreenManager.lastEvent) { _, _ in
            if isUnlocked {
                triggerUnlockAnimation()
            }
        }
    }
    
    /// The animated lock icon view
    private var lockIconView: some View {
        ZStack {
            // Unlocked state (lock.open.fill) - fades in
            Image(systemName: "lock.open.fill")
                .font(.system(size: isDynamicIslandMode ? 18 : 18, weight: .semibold))
                .foregroundStyle(.white)
                .opacity(showUnlockAnim ? 1 : 0)
                .scaleEffect(showUnlockAnim ? 1.0 : 0.8)
            
            // Locked state (lock.fill) - fades out
            Image(systemName: "lock.fill")
                .font(.system(size: isDynamicIslandMode ? 18 : 18, weight: .semibold))
                .foregroundStyle(.white)
                .opacity(showUnlockAnim ? 0 : 1)
                .scaleEffect(showUnlockAnim ? 1.2 : 1.0)
        }
        .frame(width: isDynamicIslandMode ? 20 : 26, height: isDynamicIslandMode ? 20 : 26)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
    
    /// Trigger the smooth unlock animation
    private func triggerUnlockAnimation() {
        // Reset state
        showUnlockAnim = false
        
        // Short delay then animate unlock
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showUnlockAnim = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        LockScreenHUDView(
            lockScreenManager: LockScreenManager.shared,
            notchWidth: 180,
            notchHeight: 32,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
