//
//  BatteryManager.swift
//  Droppy
//
//  Created by Droppy on 07/01/2026.
//  Manages battery state monitoring for HUD replacement
//

import Combine
import Foundation
import IOKit.ps

/// Manages battery state monitoring using IOPowerSources APIs
/// Provides real-time charging state changes and low battery alerts
final class BatteryManager: ObservableObject {
    static let shared = BatteryManager()
    
    // MARK: - Published Properties
    @Published private(set) var batteryLevel: Int = 100
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isPluggedIn: Bool = false
    @Published private(set) var lastChangeAt: Date = .distantPast
    
    /// Duration to show the HUD (seconds)
    let visibleDuration: TimeInterval = 3.0
    
    /// Low battery threshold (percentage)
    let lowBatteryThreshold: Int = 20
    
    /// Whether battery level is considered low
    var isLowBattery: Bool {
        batteryLevel <= lowBatteryThreshold && !isCharging
    }
    
    /// Whether the HUD should currently be visible based on lastChangeAt
    var isHUDVisible: Bool {
        Date().timeIntervalSince(lastChangeAt) < visibleDuration
    }
    
    // MARK: - Private State
    private var runLoopSource: CFRunLoopSource?
    private var previousIsCharging: Bool = false
    private var previousIsPluggedIn: Bool = false
    private var previousBatteryLevel: Int = 100
    private var hasInitialized: Bool = false
    
    // MARK: - Initialization
    private init() {
        // Read initial state without triggering HUD
        fetchBatteryState(triggerHUD: false)
        previousIsCharging = isCharging
        previousIsPluggedIn = isPluggedIn
        previousBatteryLevel = batteryLevel
        hasInitialized = true
        
        // Start monitoring for changes
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        // Create a run loop source that fires when power source info changes
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let manager = Unmanaged<BatteryManager>.fromOpaque(context).takeUnretainedValue()
            manager.handlePowerSourceChange()
        }, context).takeRetainedValue()
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            print("BatteryManager: Started monitoring power source changes")
        }
    }
    
    private func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
            print("BatteryManager: Stopped monitoring")
        }
    }
    
    private func handlePowerSourceChange() {
        // Dispatch to main thread for UI safety
        DispatchQueue.main.async { [weak self] in
            self?.fetchBatteryState(triggerHUD: true)
        }
    }
    
    // MARK: - Battery State
    
    private func fetchBatteryState(triggerHUD: Bool) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            print("BatteryManager: No power sources found (likely desktop Mac)")
            return
        }
        
        // Find internal battery
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            // Check if this is an internal battery
            guard let type = info[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType else {
                continue
            }
            
            // Extract battery info
            let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCapacity = info[kIOPSMaxCapacityKey] as? Int ?? 100
            let charging = info[kIOPSIsChargingKey] as? Bool ?? false
            let powerSource = info[kIOPSPowerSourceStateKey] as? String ?? ""
            let pluggedIn = powerSource == kIOPSACPowerValue
            
            // Calculate percentage
            let percentage = maxCapacity > 0 ? (currentCapacity * 100) / maxCapacity : 0
            
            // Update state
            let oldCharging = isCharging
            let oldPluggedIn = isPluggedIn
            let oldLevel = batteryLevel
            
            batteryLevel = percentage
            isCharging = charging
            isPluggedIn = pluggedIn
            
            // Determine if we should show HUD
            if triggerHUD && hasInitialized {
                let shouldTrigger = shouldTriggerHUD(
                    oldCharging: oldCharging,
                    newCharging: charging,
                    oldPluggedIn: oldPluggedIn,
                    newPluggedIn: pluggedIn,
                    oldLevel: oldLevel,
                    newLevel: percentage
                )
                
                if shouldTrigger {
                    lastChangeAt = Date()
                    print("BatteryManager: HUD triggered - charging: \(charging), pluggedIn: \(pluggedIn), level: \(percentage)%")
                }
            }
            
            // Store previous values
            previousIsCharging = charging
            previousIsPluggedIn = pluggedIn
            previousBatteryLevel = percentage
            
            break // Only process first internal battery
        }
    }
    
    private func shouldTriggerHUD(
        oldCharging: Bool,
        newCharging: Bool,
        oldPluggedIn: Bool,
        newPluggedIn: Bool,
        oldLevel: Int,
        newLevel: Int
    ) -> Bool {
        // Trigger on plug in/out
        if oldPluggedIn != newPluggedIn {
            return true
        }
        
        // Trigger on charging state change
        if oldCharging != newCharging {
            return true
        }
        
        // Trigger when crossing low battery threshold (going down)
        if oldLevel > lowBatteryThreshold && newLevel <= lowBatteryThreshold && !newCharging {
            return true
        }
        
        return false
    }
    
    // MARK: - Public API
    
    /// Force refresh battery state (useful for testing)
    func refresh() {
        fetchBatteryState(triggerHUD: false)
    }
}
