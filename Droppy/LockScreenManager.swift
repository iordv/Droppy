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
    
    /// Duration the HUD should stay visible
    let visibleDuration: TimeInterval = 2.5
    
    /// Lock event types
    enum LockEvent {
        case none
        case locked    // Screen went to sleep / lid closed
        case unlocked  // Screen woke up / lid opened
    }
    
    private init() {
        // DISABLED: Lock screen features (Skylight API, window recreation) causing serious issues.
        // All observers that trigger lock screen behavior are disabled until issues are resolved.
        // The code is preserved for future debugging - just uncomment to re-enable.
        // setupObservers()
    }
    
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
    
    @objc private func handleScreenSleep() {
        // Update internal state IMMEDIATELY - the notch is visible on lock screen via SkyLight
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Always show the panel when screen locks/dims (even if already locked)
            // This handles: initial lock, screen dim, and re-lock after partial wake
            LockScreenMediaPanelManager.shared.showPanel()
            
            // Only update state if transitioning from unlocked
            if self.isUnlocked {
                self.isUnlocked = false
                self.lastEvent = .locked
                self.lastChangeAt = Date()
                
                // CRITICAL: Trigger Lock Screen HUD via HUDManager
                // Use a very long duration effectively "indefinite" while locked
                // It will be dismissed/replaced upon unlock
                HUDManager.shared.show(.lockScreen, on: NSScreen.builtInWithNotch?.displayID, duration: 3600)
                
                // CRITICAL: Delegate window to lock screen space and elevate level
                NotchWindowController.shared.delegateToLockScreen()
            }
        }
    }
    
    @objc private func handleScreenWake() {
        // Screen wake can happen on lock screen (just screen brightening)
        // Don't hide panel here - only hide on actual unlock
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Re-show panel on screen wake (in case it was hidden during dim)
            // This ensures panel stays visible when screen dims and wakes while still locked
            if !self.isUnlocked {
                LockScreenMediaPanelManager.shared.showPanel()
                // CRITICAL: Ensure Lock Screen HUD is visible on wake
                HUDManager.shared.show(.lockScreen, on: NSScreen.builtInWithNotch?.displayID, duration: 3600)
                
                // CRITICAL: Ensure window is properly delegated and visible (re-apply in case of state loss)
                NotchWindowController.shared.delegateToLockScreen()
            }
        }
    }
    
    /// Called when user actually unlocks (not just screen wake)
    @objc private func handleActualUnlock() {
        // Hide lock screen media panel (user is actually unlocking)
        LockScreenMediaPanelManager.shared.hidePanel()
        
        // Trigger unlock HUD
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard !self.isUnlocked else { return }
            self.isUnlocked = true
            self.lastEvent = .unlocked
            self.lastChangeAt = Date()
            self.lastChangeAt = Date()
            // CRITICAL: Trigger Unlock HUD (2.0s)
            HUDManager.shared.show(.lockScreen, on: NSScreen.builtInWithNotch?.displayID, duration: 2.0)
            
            // PREMIUM: Play subtle unlock sound
            self.playUnlockSound()
            
            // CRITICAL: Restore window to standard desktop state (recycle mechanism)
            // Delay to allow unlock animation to play out (2.0s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                 NotchWindowController.shared.returnFromLockScreen()
            }
        }
    }
    
    /// Plays a premium, subtle unlock sound
    private func playUnlockSound() {
        // Use the system "Pop" sound - satisfying clack effect
        if let sound = NSSound(named: "Pop") {
            sound.volume = 0.4 // Subtle but audible
            sound.play()
        }
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
