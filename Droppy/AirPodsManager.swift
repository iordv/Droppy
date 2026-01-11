//
//  AirPodsManager.swift
//  Droppy
//
//  Created by Droppy on 11/01/2026.
//  Monitors AirPods connection via IOBluetooth and triggers HUD
//

import Foundation
import IOBluetooth
import SwiftUI

/// AirPods device type for UI display
enum AirPodsDeviceType {
    case airpods       // Regular AirPods (any generation)
    case airpodsPro    // AirPods Pro (any generation)
    case airpodsMax    // AirPods Max
    
    /// SF Symbol name for this device type
    var sfSymbol: String {
        switch self {
        case .airpods: return "airpods"
        case .airpodsPro: return "airpodspro"
        case .airpodsMax: return "airpodsmax"
        }
    }
    
    /// Display name for this device type
    var displayName: String {
        switch self {
        case .airpods: return "AirPods"
        case .airpodsPro: return "AirPods Pro"
        case .airpodsMax: return "AirPods Max"
        }
    }
}

/// Connected AirPods info for HUD display
struct ConnectedAirPods {
    let name: String
    let deviceType: AirPodsDeviceType
}

/// Manages AirPods connection detection using IOBluetooth
@Observable
class AirPodsManager {
    static let shared = AirPodsManager()
    
    /// Whether to show AirPods connection HUD (user setting)
    @ObservationIgnored
    @AppStorage("showAirPodsHUD") var showAirPodsHUD: Bool = true
    
    /// Currently displayed AirPods connection (nil = no HUD)
    var connectedAirPods: ConnectedAirPods?
    
    /// Whether the HUD is currently visible
    var isHUDVisible: Bool = false
    
    private var hideTask: Task<Void, Never>?
    private var isMonitoring = false
    
    // Store notification references to prevent deallocation
    private var connectNotification: IOBluetoothUserNotification?
    
    private init() {}
    
    /// Start monitoring for AirPods connections
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Register for Bluetooth device connection notifications
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        
        print("[AirPodsManager] Started monitoring for AirPods connections")
    }
    
    /// Stop monitoring for AirPods connections
    func stopMonitoring() {
        isMonitoring = false
        connectNotification?.unregister()
        connectNotification = nil
        hideTask?.cancel()
        print("[AirPodsManager] Stopped monitoring")
    }
    
    /// Called when any Bluetooth device connects
    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard showAirPodsHUD else { return }
        
        let deviceName = device.name ?? "Unknown Device"
        
        // Check if this is an AirPods device
        guard let deviceType = detectAirPodsType(device: device, name: deviceName) else {
            return // Not AirPods, ignore
        }
        
        print("[AirPodsManager] AirPods connected: \(deviceName) (\(deviceType.displayName))")
        
        // Show HUD on main thread
        Task { @MainActor in
            self.showHUD(airpods: ConnectedAirPods(name: deviceName, deviceType: deviceType))
        }
    }
    
    /// Detect if device is AirPods and return type
    private func detectAirPodsType(device: IOBluetoothDevice, name: String) -> AirPodsDeviceType? {
        let lowercaseName = name.lowercased()
        
        // First try name matching (most reliable for user-renamed devices)
        if lowercaseName.contains("airpods max") {
            return .airpodsMax
        } else if lowercaseName.contains("airpods pro") {
            return .airpodsPro
        } else if lowercaseName.contains("airpods") {
            return .airpods
        }
        
        // Fallback: Check device class for audio devices
        // AirPods are typically class 0x240418 (audio device)
        let deviceClass = device.classOfDevice
        let majorClass = (deviceClass >> 8) & 0x1F
        
        // Major class 4 = Audio/Video
        if majorClass == 4 {
            // Could be AirPods but can't determine type, default to regular
            // Only trigger if name suggests it's Apple device
            if lowercaseName.contains("apple") || lowercaseName.isEmpty {
                return nil // Don't trigger for generic audio devices
            }
        }
        
        return nil
    }
    
    /// Show the AirPods HUD
    @MainActor
    private func showHUD(airpods: ConnectedAirPods) {
        hideTask?.cancel()
        
        connectedAirPods = airpods
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isHUDVisible = true
        }
        
        // Auto-hide after 3 seconds
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self.hideHUD()
        }
    }
    
    /// Hide the AirPods HUD
    @MainActor
    func hideHUD() {
        hideTask?.cancel()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isHUDVisible = false
        }
        
        // Clear data after animation
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            if !isHUDVisible {
                connectedAirPods = nil
            }
        }
    }
}
