//
//  CapsLockManager.swift
//  Droppy
//
//  Created by Droppy on 09/01/2026.
//  Monitors Caps Lock state changes for HUD display
//

import AppKit
import Combine
import Foundation
import Carbon.HIToolbox

/// Manages Caps Lock state monitoring for HUD display
/// Uses IOHIDManager to detect keyboard modifier changes
final class CapsLockManager: ObservableObject {
    static let shared = CapsLockManager()
    
    // MARK: - Published Properties
    @Published private(set) var isCapsLockOn: Bool = false
    @Published private(set) var lastChangeAt: Date = .distantPast
    
    /// Duration to show the HUD (seconds)
    let visibleDuration: TimeInterval = 2.0
    
    /// Whether the HUD should currently be visible based on lastChangeAt
    var isHUDVisible: Bool {
        Date().timeIntervalSince(lastChangeAt) < visibleDuration
    }
    
    // MARK: - Private State
    private var eventMonitor: Any?
    private var hasInitialized: Bool = false
    
    // MARK: - Initialization
    private init() {
        // Read initial state without triggering HUD
        updateCapsLockState(triggerHUD: false)
        hasInitialized = true
        
        // Start monitoring for changes
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        // Monitor flagsChanged events globally to detect Caps Lock
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        
        // Also add local monitor for when Droppy is frontmost
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        
        print("CapsLockManager: Started monitoring Caps Lock state")
    }
    
    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            print("CapsLockManager: Stopped monitoring")
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let newCapsLockState = event.modifierFlags.contains(.capsLock)
        
        // Only trigger if state actually changed
        if newCapsLockState != isCapsLockOn {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.isCapsLockOn = newCapsLockState
                
                if self.hasInitialized {
                    self.lastChangeAt = Date()
                    print("CapsLockManager: HUD triggered - Caps Lock is now \(newCapsLockState ? "ON" : "OFF")")
                }
            }
        }
    }
    
    private func updateCapsLockState(triggerHUD: Bool) {
        // Check current Caps Lock state using Carbon
        let flags = CGEventSource.flagsState(.combinedSessionState)
        isCapsLockOn = flags.contains(.maskAlphaShift)
        
        if triggerHUD && hasInitialized {
            lastChangeAt = Date()
        }
    }
    
    // MARK: - Public API
    
    /// Force refresh Caps Lock state (useful for testing)
    func refresh() {
        updateCapsLockState(triggerHUD: false)
    }
}
