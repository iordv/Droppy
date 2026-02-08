//
//  LockScreenHUDWindowManager.swift
//  Droppy
//
//  Created by Droppy on 07/02/2026.
//  Manages a dedicated, disposable window for the lock screen HUD.
//  This window is delegated to SkyLight for lock screen visibility.
//  The main notch window is NEVER touched — this prevents the "Delegation Stain".
//

import Foundation
import AppKit
import SwiftUI
import QuartzCore
import SkyLightWindow

/// Manages a separate, throwaway window that shows the lock icon on the macOS lock screen.
///
/// Architecture:
/// - Created fresh on each lock event
/// - Delegated to SkyLight space (level 400) for lock screen visibility
/// - Destroyed on unlock — no recovery needed, no interactivity corruption
/// - Main notch window is NEVER delegated, preserving full hover/drag/click
///
/// Follows the same pattern as `LockScreenMediaPanelManager`.
@MainActor
final class LockScreenHUDWindowManager {
    static let shared = LockScreenHUDWindowManager()
    
    // MARK: - Window State
    private var hudWindow: NSWindow?
    private var hasDelegated = false
    private var hideTask: Task<Void, Never>?
    private var configuredContentSize: NSSize = .zero
    
    // MARK: - Dimensions
    /// Wing width for battery/lock HUD — must match NotchShelfView.batteryWingWidth exactly
    private let batteryWingWidth: CGFloat = 65
    
    /// Dynamically calculate HUD width to match NotchShelfView.batteryHudWidth exactly
    /// This ensures the lock screen HUD and main notch have identical dimensions
    private func hudWidth(for screen: NSScreen) -> CGFloat {
        // Calculate notchWidth the same way as NotchShelfView
        let notchWidth: CGFloat
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            notchWidth = max(rightArea.minX - leftArea.maxX, NotchLayoutConstants.physicalNotchWidth)
        } else {
            notchWidth = NotchLayoutConstants.physicalNotchWidth
        }
        
        // batteryHudWidth = notchWidth + (batteryWingWidth * 2)
        return notchWidth + (batteryWingWidth * 2)
    }

    private init() {
        print("LockScreenHUDWindowManager: 🔒 Initialized")
    }
    
    // MARK: - Public API
    
    /// Create and show the lock HUD window on the lock screen.
    /// Called by `LockScreenManager` when the screen locks.
    @discardableResult
    func showOnLockScreen() -> Bool {
        // Get the built-in display (lock screen only appears here)
        guard let screen = NSScreen.builtInWithNotch ?? NSScreen.main else {
            print("LockScreenHUDWindowManager: ⚠️ No built-in screen available")
            return false
        }
        
        print("LockScreenHUDWindowManager: 🔒 Showing lock icon on lock screen")

        // If a delayed hide is pending from a prior unlock, cancel it.
        hideTask?.cancel()
        hideTask = nil
        
        // Calculate width dynamically to match main notch
        let currentHudWidth = hudWidth(for: screen)
        
        // Calculate frame with new width
        let targetFrame = calculateWindowFrame(for: screen, width: currentHudWidth)
        
        let window: NSWindow

        if let existingWindow = hudWindow {
            // Reuse existing window (e.g., re-lock without full unlock)
            window = existingWindow
        } else {
            // Create fresh window
            window = createHUDWindow(frame: targetFrame)
            hudWindow = window
            hasDelegated = false
        }
        
        // Ensure lock-screen visibility semantics for this phase.
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Update frame for current screen geometry
        window.setFrame(targetFrame, display: true)
        
        // Only rebuild the SwiftUI host when needed to avoid visual resets/flicker.
        let needsContentRebuild =
            window.contentView == nil ||
            abs(configuredContentSize.width - targetFrame.width) > 0.5 ||
            abs(configuredContentSize.height - targetFrame.height) > 0.5

        if needsContentRebuild {
            let layout = HUDLayoutCalculator(screen: screen)
            let notchHeight = layout.notchHeight

            let lockHUDContent = LockScreenHUDWindowContent(
                lockWidth: currentHudWidth,
                notchHeight: notchHeight,
                targetScreen: screen
            )

            let hostingView = NSHostingView(rootView: lockHUDContent)
            hostingView.frame = NSRect(origin: .zero, size: targetFrame.size)
            hostingView.autoresizingMask = [.width, .height]
            window.contentView = hostingView
            configuredContentSize = targetFrame.size
        }
        
        // Make content background transparent
        if let content = window.contentView {
            content.wantsLayer = true
            content.layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        // Delegate to SkyLight for lock screen visibility (ONLY this throwaway window)
        if !hasDelegated {
            SkyLightOperator.shared.delegateWindow(window)
            hasDelegated = true
            print("LockScreenHUDWindowManager: ✅ Window delegated to SkyLight space")
        }
        
        // Show window
        window.orderFrontRegardless()

        print("LockScreenHUDWindowManager: ✅ Lock icon visible on lock screen")
        return true
    }

    /// Keep the same HUD window visible while transitioning back to desktop, then hide it.
    /// This preserves a single visual surface from lock screen to unlocked desktop.
    func transitionToDesktopAndHide(
        after delay: TimeInterval,
        completion: (() -> Void)? = nil
    ) {
        guard let window = hudWindow else {
            completion?()
            return
        }

        hideTask?.cancel()
        // Keep the exact same delegated surface alive through the unlock morph.
        // Avoid level/behavior mutations here to prevent cross-space visual artifacts.
        window.orderFrontRegardless()

        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            // Hold just long enough for the shared unlock icon sequence to settle.
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }

            self?.hideAndDestroy()
            completion?()
        }
    }
    
    /// Destroy the lock HUD window.
    /// Called by `LockScreenManager` when the user actually unlocks.
    func hideAndDestroy() {
        print("LockScreenHUDWindowManager: 🔓 Destroying lock screen HUD window")

        hideTask?.cancel()
        hideTask = nil
        
        guard let window = hudWindow else {
            print("LockScreenHUDWindowManager: No window to destroy")
            return
        }
        
        // Remove from screen
        window.orderOut(nil)
        window.contentView = nil
        
        // Fully destroy — the next lock event will create a fresh window
        // This ensures no SkyLight delegation stain persists
        hudWindow = nil
        hasDelegated = false
        configuredContentSize = .zero
        
        print("LockScreenHUDWindowManager: ✅ Window destroyed")
    }
    
    // MARK: - Private Helpers
    
    private func createHUDWindow(frame: NSRect) -> NSWindow {
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isMovable = false
        window.hasShadow = false  // No shadow for lock screen icon
        window.ignoresMouseEvents = true  // Lock screen — no interaction needed
        window.animationBehavior = .none
        
        return window
    }
    
    /// Calculate the window frame to align with the physical notch area on the built-in display.
    private func calculateWindowFrame(for screen: NSScreen, width: CGFloat) -> NSRect {
        let layout = HUDLayoutCalculator(screen: screen)
        let notchHeight = layout.notchHeight
        
        // Center horizontally on the notch
        let notchCenterX = screen.notchAlignedCenterX
        let originX = notchCenterX - (width / 2)
        
        // Position at the very top of the screen (notch area)
        let originY = screen.frame.origin.y + screen.frame.height - notchHeight
        
        return NSRect(x: originX, y: originY, width: width, height: notchHeight)
    }
}

private struct LockScreenHUDWindowContent: View {
    @ObservedObject private var lockScreenManager = LockScreenManager.shared

    let lockWidth: CGFloat
    let notchHeight: CGFloat
    let targetScreen: NSScreen

    @State private var visualWidth: CGFloat
    @State private var transitionPhase = false
    @State private var transitionResetWorkItem: DispatchWorkItem?

    init(
        lockWidth: CGFloat,
        notchHeight: CGFloat,
        targetScreen: NSScreen
    ) {
        self.lockWidth = lockWidth
        self.notchHeight = notchHeight
        self.targetScreen = targetScreen
        _visualWidth = State(initialValue: lockWidth)
    }

    var body: some View {
        ZStack {
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: visualWidth, height: notchHeight)

            LockScreenHUDView(
                hudWidth: visualWidth,
                targetScreen: targetScreen
            )
            .frame(width: visualWidth, height: notchHeight)
            .scaleEffect(transitionPhase ? 0.97 : 1.0, anchor: .top)
            .blur(radius: transitionPhase ? 1.8 : 0)
            .opacity(transitionPhase ? 0.96 : 1.0)
        }
        .frame(maxWidth: .infinity, maxHeight: notchHeight, alignment: .top)
        .animation(.easeOut(duration: 0.16), value: transitionPhase)
        .onAppear {
            // Keep a single stable lock surface size to avoid the tiny bridge-notch ghost
            // during lock/unlock handoff.
            visualWidth = lockWidth
            triggerPremiumPulse()
        }
        .onChange(of: lockScreenManager.isUnlocked) { _, isUnlocked in
            withAnimation(DroppyAnimation.notchState) {
                visualWidth = lockWidth
            }
            if !isUnlocked {
                triggerPremiumPulse()
            }
        }
        .onChange(of: lockWidth) { _, newLockWidth in
            if !lockScreenManager.isUnlocked {
                withAnimation(DroppyAnimation.notchState) {
                    visualWidth = newLockWidth
                }
            }
        }
        .onDisappear {
            transitionResetWorkItem?.cancel()
            transitionResetWorkItem = nil
        }
    }

    private func triggerPremiumPulse() {
        transitionResetWorkItem?.cancel()
        transitionPhase = true

        let workItem = DispatchWorkItem {
            withAnimation(DroppyAnimation.notchState) {
                transitionPhase = false
            }
        }
        transitionResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11, execute: workItem)
    }
}
