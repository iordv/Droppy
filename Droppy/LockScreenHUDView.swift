//
//  LockScreenHUDView.swift
//  Droppy
//
//  Created by Droppy on 13/01/2026.
//  Lock/Unlock HUD - iPhone-style unlock animation
//

import SwiftUI
import Combine

/// Shared lock HUD animator so lock-screen and regular notch surfaces
/// stay in the same visual state during handoff.
@MainActor
final class LockScreenHUDAnimator: ObservableObject {
    static let shared = LockScreenHUDAnimator()

    @Published private(set) var showUnlockIcon = false
    @Published private(set) var lockScale: CGFloat = 1.0
    @Published private(set) var lockOpacity: Double = 1.0

    private var sequenceTask: Task<Void, Never>?
    private(set) var visualEvent: LockScreenManager.LockEvent = .unlocked

    private init() {
        applyUnlockedStatic()
    }

    func transition(to event: LockScreenManager.LockEvent, animated: Bool = true) {
        sequenceTask?.cancel()

        switch event {
        case .none:
            applyLockedStatic(event: .none)
        case .locked:
            if animated && visualEvent == .unlocked {
                runLockSequence()
            } else {
                applyLockedStatic(event: .locked)
            }
        case .unlocked:
            if animated && visualEvent == .locked {
                runUnlockSequence()
            } else {
                applyUnlockedStatic()
            }
        }
    }

    private func runUnlockSequence() {
        applyLockedStatic(event: .locked)
        visualEvent = .unlocked

        sequenceTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Flip to unlock icon early with a gentle, premium settle.
            try? await Task.sleep(nanoseconds: 35_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0)) {
                self.showUnlockIcon = true
                self.lockScale = 1.015
            }

            try? await Task.sleep(nanoseconds: 110_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                self.lockScale = 0.99
            }

            try? await Task.sleep(nanoseconds: 85_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0)) {
                self.lockScale = 1.0
            }
        }
    }

    private func runLockSequence() {
        applyUnlockedStatic()
        visualEvent = .locked

        sequenceTask = Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: 90_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82, blendDuration: 0)) {
                self.showUnlockIcon = false
            }

            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                self.lockScale = 1.04
            }

            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                self.lockScale = 1.0
            }
        }
    }

    private func applyLockedStatic(event: LockScreenManager.LockEvent) {
        showUnlockIcon = false
        lockScale = 1.0
        lockOpacity = 1.0
        visualEvent = event
    }

    private func applyUnlockedStatic() {
        showUnlockIcon = true
        lockScale = 1.0
        lockOpacity = 1.0
        visualEvent = .unlocked
    }
}

/// Compact Lock Screen HUD that sits inside the notch
/// Shows just the lock icon with smooth unlock animation like iPhone
struct LockScreenHUDView: View {
    @ObservedObject private var animator = LockScreenHUDAnimator.shared
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    var symbolOverride: String? = nil  // Optional fixed symbol for transition snapshots
    
    /// Centralized layout calculator - Single Source of Truth
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if layout.isDynamicIslandMode {
                // DYNAMIC ISLAND: Centered icon with animation
                lockIconView
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.notchHeight)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                let wingWidth = layout.wingWidth(for: hudWidth)
                
                HStack(spacing: 0) {
                    // Left wing: Lock icon near left edge
                    HStack {
                        lockIconView
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, symmetricPadding)
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: layout.notchWidth)
                    
                    // Right wing: Empty (icon only HUD)
                    Spacer()
                        .frame(width: wingWidth)
                }
                .frame(height: layout.notchHeight)
            }
        }
    }
    
    /// The animated lock icon view with realistic unlock physics
    @ViewBuilder
    private var lockIconView: some View {
        let iconSize = layout.iconSize
        let symbolName = symbolOverride ?? (animator.showUnlockIcon ? "lock.open.fill" : "lock.fill")
        let showsUnlockedVisual = symbolOverride == "lock.open.fill" || (symbolOverride == nil && animator.showUnlockIcon)
        let baseIcon = Image(systemName: symbolName)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(.white)
        
        if symbolOverride == nil {
            baseIcon
                .contentTransition(.symbolEffect(.replace.byLayer))
                .animation(.spring(response: 0.32, dampingFraction: 0.75), value: symbolName)
                .opacity(animator.lockOpacity)
                .scaleEffect(animator.lockScale)
                .offset(y: showsUnlockedVisual ? -0.8 : 0)
                .rotationEffect(.degrees(showsUnlockedVisual ? -3 : 0))
                .frame(width: iconSize + 2, height: iconSize + 2)
        } else {
            baseIcon
                .opacity(animator.lockOpacity)
                .scaleEffect(animator.lockScale)
                .offset(y: showsUnlockedVisual ? -0.8 : 0)
                .rotationEffect(.degrees(showsUnlockedVisual ? -3 : 0))
                .frame(width: iconSize + 2, height: iconSize + 2)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        LockScreenHUDView(
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
