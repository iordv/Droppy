//
//  HUDManager.swift
//  Droppy
//
//  Single Source of Truth for HUD display state and queue management
//  Prevents overlapping HUDs and provides smooth transitions
//

import SwiftUI
import Observation

/// Centralized HUD manager - Single Source of Truth for all HUD visibility
/// Handles queue, priority, and smooth transitions between HUDs
@Observable
final class HUDManager {
    static let shared = HUDManager()
    
    // MARK: - HUD Types with Priority
    
    /// All HUD types with their priority (higher number = higher priority)
    enum HUDType: Int, Comparable, CaseIterable {
        // Interactive HUDs (user-triggered) - highest priority
        case volumeBrightness = 100  // User is actively adjusting
        
        // System event HUDs - medium priority
        case airPods = 80            // Connection events
        case battery = 70            // Charge state changes
        case capsLock = 60           // Keyboard state
        case highAlert = 55          // High Alert (stay awake) state changes
        case lockScreen = 50         // Lock/unlock events
        case notification = 45       // Notification HUD (extension)
        case dnd = 40                // Focus mode changes
        case update = 35             // App update available
        
        static func < (lhs: HUDType, rhs: HUDType) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        var defaultDuration: TimeInterval {
            switch self {
            case .volumeBrightness: return 1.5  // Short, user knows what they did
            case .airPods: return 3.0           // Longer to show battery info
            case .battery: return 2.5           // Medium duration
            case .capsLock: return 1.0          // Very short, just confirmation
            case .highAlert: return 2.0         // Medium, shows active/inactive state
            case .lockScreen: return 2.0        // Medium
            case .notification: return 3.0      // Notification from external app
            case .dnd: return 2.0               // Medium
            case .update: return 4.0            // Longer for user to notice update
            }
        }
    }
    
    // MARK: - Active HUD State
    
    /// Currently displayed HUD (nil = no HUD visible)
    private(set) var activeHUD: ActiveHUD? = nil
    
    /// Queue of pending HUDs (lower priority waiting for higher to finish)
    private var hudQueue: [HUDRequest] = []
    
    /// Auto-dismiss timer
    private var dismissTimer: Timer?
    
    // MARK: - Active HUD Data
    
    struct ActiveHUD: Equatable {
        let type: HUDType
        let timestamp: Date
        let displayID: CGDirectDisplayID
        
        // Type-erased data - use associated methods to extract
        let volumeValue: CGFloat?
        let brightnessValue: CGFloat?
        let isMuted: Bool?
        
        static func == (lhs: ActiveHUD, rhs: ActiveHUD) -> Bool {
            lhs.type == rhs.type && lhs.timestamp == rhs.timestamp
        }
    }
    
    struct HUDRequest {
        let type: HUDType
        let duration: TimeInterval
        let displayID: CGDirectDisplayID
        let volumeValue: CGFloat?
        let brightnessValue: CGFloat?
        let isMuted: Bool?
    }
    
    // MARK: - Public API
    
    /// Show a HUD with automatic priority and queue handling
    /// - Parameters:
    ///   - type: The type of HUD to show
    ///   - displayID: Target display (defaults to main)
    ///   - duration: How long to show (defaults to type's default)
    ///   - volumeValue: Volume level (0-1) for volume HUD
    ///   - brightnessValue: Brightness level (0-1) for brightness HUD
    ///   - isMuted: Whether audio is muted
    func show(
        _ type: HUDType,
        on displayID: CGDirectDisplayID? = nil,
        duration: TimeInterval? = nil,
        volumeValue: CGFloat? = nil,
        brightnessValue: CGFloat? = nil,
        isMuted: Bool? = nil
    ) {
        let targetDisplay = displayID ?? CGMainDisplayID()
        let actualDuration = duration ?? type.defaultDuration
        
        let request = HUDRequest(
            type: type,
            duration: actualDuration,
            displayID: targetDisplay,
            volumeValue: volumeValue,
            brightnessValue: brightnessValue,
            isMuted: isMuted
        )
        
        // Handle priority
        if let current = activeHUD {
            if type > current.type {
                // Higher priority - interrupt current
                interruptAndShow(request)
            } else if type == current.type {
                // Same type - update in place (e.g., volume slider still moving)
                updateActiveHUD(with: request)
            } else {
                // Lower priority - queue it (or replace existing queued of same type)
                queueRequest(request)
            }
        } else {
            // No active HUD - show immediately
            showImmediately(request)
        }
    }
    
    /// Dismiss the current HUD immediately
    func dismiss() {
        let wasNotificationHUD = activeHUD?.type == .notification

        dismissTimer?.invalidate()
        dismissTimer = nil

        withAnimation(DroppyAnimation.easeOut) {
            activeHUD = nil
        }

        // Notify window controller to update mouse event handling
        if wasNotificationHUD {
            print("🔔 HUDManager: Notification HUD dismissed - posting state change notification")
            NotificationCenter.default.post(name: .hudStateDidChange, object: nil)
        }

        // Process queue after dismiss animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.processQueue()
        }
    }
    
    /// Extend the current HUD's display time (e.g., user still adjusting volume)
    func extendDuration(by seconds: TimeInterval = 1.0) {
        guard activeHUD != nil else { return }
        resetDismissTimer(duration: seconds)
    }
    
    // MARK: - Private Methods
    
    private func showImmediately(_ request: HUDRequest) {
        let hud = ActiveHUD(
            type: request.type,
            timestamp: Date(),
            displayID: request.displayID,
            volumeValue: request.volumeValue,
            brightnessValue: request.brightnessValue,
            isMuted: request.isMuted
        )

        withAnimation(DroppyAnimation.hover) {
            activeHUD = hud
        }

        resetDismissTimer(duration: request.duration)

        // Notify window controller to update mouse event handling for interactive HUDs
        if request.type == .notification {
            print("🔔 HUDManager: Notification HUD shown - posting state change notification")
            NotificationCenter.default.post(name: .hudStateDidChange, object: nil)
        }
    }
    
    private func interruptAndShow(_ request: HUDRequest) {
        // Quick fade out, then show new
        withAnimation(DroppyAnimation.hoverQuick) {
            activeHUD = nil
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showImmediately(request)
        }
    }
    
    private func updateActiveHUD(with request: HUDRequest) {
        // Same type - update values without full transition
        let hud = ActiveHUD(
            type: request.type,
            timestamp: activeHUD?.timestamp ?? Date(),
            displayID: request.displayID,
            volumeValue: request.volumeValue,
            brightnessValue: request.brightnessValue,
            isMuted: request.isMuted
        )
        
        activeHUD = hud
        resetDismissTimer(duration: request.duration)
    }
    
    private func queueRequest(_ request: HUDRequest) {
        // Remove any existing request of same type
        hudQueue.removeAll { $0.type == request.type }
        // Add to queue
        hudQueue.append(request)
        // Sort by priority (highest first)
        hudQueue.sort { $0.type > $1.type }
    }
    
    private func processQueue() {
        guard activeHUD == nil, let next = hudQueue.first else { return }
        hudQueue.removeFirst()
        showImmediately(next)
    }
    
    private func resetDismissTimer(duration: TimeInterval) {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }
    
    // MARK: - Convenience Computed Properties for Views
    
    /// Whether any HUD is currently visible
    var isVisible: Bool {
        activeHUD != nil
    }
    
    /// Current volume value (if volume HUD is active)
    var currentVolume: CGFloat? {
        activeHUD?.volumeValue
    }
    
    /// Current brightness value (if brightness HUD is active)
    var currentBrightness: CGFloat? {
        activeHUD?.brightnessValue
    }
    
    /// Whether currently muted (if volume HUD is active)
    var isCurrentlyMuted: Bool {
        activeHUD?.isMuted ?? false
    }
    
    // MARK: - Type-Specific Visibility (for view integration)
    
    /// Whether volume/brightness HUD is visible
    var isVolumeBrightnessHUDVisible: Bool {
        activeHUD?.type == .volumeBrightness
    }
    
    /// Whether battery HUD is visible
    var isBatteryHUDVisible: Bool {
        activeHUD?.type == .battery
    }
    
    /// Whether CapsLock HUD is visible
    var isCapsLockHUDVisible: Bool {
        activeHUD?.type == .capsLock
    }
    
    /// Whether High Alert HUD is visible
    var isHighAlertHUDVisible: Bool {
        activeHUD?.type == .highAlert
    }
    
    /// Whether AirPods HUD is visible
    var isAirPodsHUDVisible: Bool {
        activeHUD?.type == .airPods
    }
    
    /// Whether Lock Screen HUD is visible
    var isLockScreenHUDVisible: Bool {
        activeHUD?.type == .lockScreen
    }
    
    /// Whether DND/Focus HUD is visible
    var isDNDHUDVisible: Bool {
        activeHUD?.type == .dnd
    }
    
    /// Whether Update HUD is visible
    var isUpdateHUDVisible: Bool {
        activeHUD?.type == .update
    }
    
    /// Whether Notification HUD is visible
    var isNotificationHUDVisible: Bool {
        activeHUD?.type == .notification
    }
    
    /// Check if a specific HUD type is currently active
    func isHUDActive(_ type: HUDType) -> Bool {
        activeHUD?.type == type
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("HUD Manager Test")
            .font(.headline)
        
        Button("Show Volume HUD") {
            HUDManager.shared.show(.volumeBrightness, volumeValue: 0.7)
        }
        
        Button("Show Battery HUD") {
            HUDManager.shared.show(.battery)
        }
        
        Button("Show CapsLock HUD") {
            HUDManager.shared.show(.capsLock)
        }
        
        Button("Dismiss") {
            HUDManager.shared.dismiss()
        }
    }
    .padding()
}
