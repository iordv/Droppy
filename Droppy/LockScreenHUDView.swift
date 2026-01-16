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
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
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
    
    /// Whether we're in Dynamic Island mode (screen-aware for multi-monitor)
    /// For HUD LAYOUT purposes: external displays always use compact layout (no physical notch)
    private var isDynamicIslandMode: Bool {
        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        
        // External displays never have physical notches, so always use compact HUD layout
        // The externalDisplayUseDynamicIsland setting only affects the visual shape, not HUD content layout
        if !screen.isBuiltIn {
            return true
        }
        
        // For built-in display, use main Dynamic Island setting
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
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
    
    /// The animated lock icon view with realistic unlock physics
    private var lockIconView: some View {
        ZStack {
            // Unlocked state (lock.open.fill) - swoops in from above
            Image(systemName: "lock.open.fill")
                .font(.system(size: isDynamicIslandMode ? 18 : 18, weight: .semibold))
                .foregroundStyle(.white)
                .opacity(showUnlockAnim ? 1 : 0)
                .scaleEffect(showUnlockAnim ? 1.0 : 0.6)
                .offset(y: showUnlockAnim ? 0 : -4)
                .rotationEffect(.degrees(showUnlockAnim ? 0 : -15))
            
            // Locked state (lock.fill) - shrinks and fades as it "unlocks"
            Image(systemName: "lock.fill")
                .font(.system(size: isDynamicIslandMode ? 18 : 18, weight: .semibold))
                .foregroundStyle(.white)
                .opacity(showUnlockAnim ? 0 : lockOpacity)
                .scaleEffect(showUnlockAnim ? 0.7 : lockScale)
                .rotationEffect(.degrees(showUnlockAnim ? 10 : 0))
        }
        .frame(width: isDynamicIslandMode ? 20 : 26, height: isDynamicIslandMode ? 20 : 26)
    }
    
    /// Trigger the smooth multi-phase unlock animation
    private func triggerUnlockAnimation() {
        // Reset all states
        showUnlockAnim = false
        lockScale = 1.0
        lockOpacity = 1.0
        
        // Phase 1: Quick "trying to unlock" shake (subtle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.08)) {
                lockScale = 1.05
            }
        }
        
        // Phase 2: Return and slight compress (like pressing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            withAnimation(.easeInOut(duration: 0.06)) {
                lockScale = 0.95
            }
        }
        
        // Phase 3: The unlock! Smooth spring transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65, blendDuration: 0)) {
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
