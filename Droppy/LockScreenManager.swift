//
//  LockScreenManager.swift
//  Droppy
//
//  Created by Droppy on 13/01/2026.
//  Detects MacBook lid open/close (screen lock/unlock) events
//

import Foundation
import AppKit
import Combine

/// Manages screen lock/unlock detection for HUD display
/// Uses NSWorkspace notifications to detect when screens sleep/wake
class LockScreenManager: ObservableObject {
    static let shared = LockScreenManager()
    
    /// Current state: true = unlocked (awake), false = locked (asleep)
    @Published private(set) var isUnlocked: Bool = true
    
    /// Timestamp of last state change (triggers HUD)
    @Published private(set) var lastChangeAt: Date = .distantPast
    
    /// The event that triggered the last change
    @Published private(set) var lastEvent: LockEvent = .none

    /// True while the dedicated lock-screen HUD window is the active visual surface.
    /// Used to suppress duplicate inline notch lock HUD rendering during lock/unlock handoff.
    @Published private(set) var isDedicatedHUDActive: Bool = false
    
    /// Duration the HUD should stay visible
    let visibleDuration: TimeInterval = 2.5
    
    /// Lock event types
    enum LockEvent {
        case none
        case locked    // Screen went to sleep / lid closed
        case unlocked  // Screen woke up / lid opened
    }
    
    /// Whether observers are currently active
    private var isEnabled = false
    
    private init() {
        // Observers are NOT started here — call enable() after checking user preferences.
        // This avoids the historical issue of lock screen features activating unconditionally.
    }
    
    // MARK: - Public API
    
    /// Start observing lock/unlock events. Called from DroppyApp when the preference is enabled.
    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        setupObservers()
        print("LockScreenManager: ✅ Observers enabled")
    }
    
    /// Stop observing lock/unlock events.
    func disable() {
        guard isEnabled else { return }
        isEnabled = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        LockScreenMediaPanelManager.shared.hidePanel()
        LockScreenHUDWindowManager.shared.hideAndDestroy()
        isDedicatedHUDActive = false
        HUDManager.shared.dismiss()
        print("LockScreenManager: ⏹ Observers disabled")
    }
    
    // MARK: - Observer Setup
    
    private func setupObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        
        // Screen sleep = lock (lid closed or manual sleep)
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleScreenSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        
        // Screen wake = unlock (lid opened or manual wake)
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        
        // Session resign = screen locked (power button, hot corner, etc.)
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleScreenSleep),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        
        // Session become active = screen unlocked (after login) - ACTUAL unlock
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleActualUnlock),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        
        // Also listen to distributed notifications for screen lock (power button)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenSleep),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        
        // Actual unlock notification - ACTUAL unlock
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleActualUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }
    
    // MARK: - Event Handlers
    
    @objc private func handleScreenSleep() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            // Show media panel when screen locks (separate feature, already safe)
            LockScreenMediaPanelManager.shared.showPanel()
            
            // Only update state if transitioning from unlocked
            if self.isUnlocked {
                self.isUnlocked = false
                self.lastEvent = .locked
                self.lastChangeAt = Date()

                // Show dedicated lock screen window (SkyLight-delegated, separate from main notch)
                self.isDedicatedHUDActive = LockScreenHUDWindowManager.shared.showOnLockScreen()

                // Gate all other HUDs during lock transition to guarantee no overlap.
                HUDManager.shared.show(.lockScreen, on: NSScreen.builtInWithNotch?.displayID, duration: 3600)

                // Keep a single lock HUD animation timeline across lock/unlock events.
                LockScreenHUDAnimator.shared.transition(to: .locked)
            }
        }
    }
    
    @objc private func handleScreenWake() {
        // Screen wake can happen on lock screen (just screen brightening)
        // Don't hide panel here - only hide on actual unlock
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Re-show panel on screen wake (in case it was hidden during dim)
            if !self.isUnlocked {
                LockScreenMediaPanelManager.shared.showPanel()
                self.isDedicatedHUDActive = LockScreenHUDWindowManager.shared.showOnLockScreen()
                HUDManager.shared.show(.lockScreen, on: NSScreen.builtInWithNotch?.displayID, duration: 3600)
            }
        }
    }
    
    /// Called when user actually unlocks (not just screen wake)
    @objc private func handleActualUnlock() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            // 1. Update state and animate on the SAME lock HUD surface
            if !self.isUnlocked {
                self.isUnlocked = true
                self.lastEvent = .unlocked
                self.lastChangeAt = Date()

                // Continue on the same shared animation timeline (no handoff to main notch HUD).
                LockScreenHUDAnimator.shared.transition(to: .unlocked)
                HUDManager.shared.show(.lockScreen, on: NSScreen.builtInWithNotch?.displayID, duration: 2.0)

                // Play subtle unlock sound
                self.playUnlockSound()
            }
            
            // 2. Hide lock screen media panel
            LockScreenMediaPanelManager.shared.hidePanel()
            
            // 3. Keep the dedicated lock HUD as the sole visible surface through unlock.
            // It animates icon + width back toward desktop notch geometry before teardown.
            LockScreenHUDWindowManager.shared.transitionToDesktopAndHide(after: 0.2) {
                // 4. Release lock gate only after the lock HUD window is fully gone.
                HUDManager.shared.dismiss()
                self.isDedicatedHUDActive = false
            }
        }
    }
    
    /// Plays a premium, subtle unlock sound
    private func playUnlockSound() {
        if let sound = NSSound(named: "Pop") {
            sound.volume = 0.4
            sound.play()
        }
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
