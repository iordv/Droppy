//
//  MediaKeyInterceptor.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  Intercepts media keys (volume/brightness) to suppress system HUD
//

import AppKit
import CoreGraphics
import Foundation

/// Media key types from IOKit
private let NX_KEYTYPE_SOUND_UP: UInt32 = 0
private let NX_KEYTYPE_SOUND_DOWN: UInt32 = 1
private let NX_KEYTYPE_MUTE: UInt32 = 7
private let NX_KEYTYPE_BRIGHTNESS_UP: UInt32 = 2
private let NX_KEYTYPE_BRIGHTNESS_DOWN: UInt32 = 3
private let NX_KEYTYPE_ILLUMINATION_UP: UInt32 = 21
private let NX_KEYTYPE_ILLUMINATION_DOWN: UInt32 = 22

/// Intercepts volume and brightness keys to prevent system HUD from appearing
/// Requires Accessibility permissions to function
final class MediaKeyInterceptor {
    static let shared = MediaKeyInterceptor()
    
    // Made internal for callback access
    var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    
    // Dedicated background queue for event tap (prevents main thread contention on M4 Macs)
    private var eventTapQueue: DispatchQueue?
    private var eventTapRunLoop: CFRunLoop?
    
    /// Callbacks for key events
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?
    var onMute: (() -> Void)?
    var onBrightnessUp: (() -> Void)?
    var onBrightnessDown: (() -> Void)?
    
    // MARK: - Brightness Control App Detection
    
    /// Bundle identifiers for known external display brightness control apps
    private static let brightnessAppBundleIDs: Set<String> = [
        "me.guillaumeb.MonitorControl",           // MonitorControl
        "software.betterdisplay.BetterDisplay",   // BetterDisplay
        "fyi.lunar.Lunar",                        // Lunar
        "com.thnkdev.DisplayBuddy"                // DisplayBuddy
    ]
    
    /// Cached result of brightness app detection (refreshed every 30 seconds)
    private static var cachedBrightnessAppRunning: Bool?
    private static var cacheTimestamp: Date?
    private static let cacheDuration: TimeInterval = 30  // 30 seconds
    
    /// Checks if a brightness control app (MonitorControl, BetterDisplay, Lunar) is running
    /// Uses caching to avoid expensive process enumeration on every key press
    static func isBrightnessControlAppRunning() -> Bool {
        // Check cache validity
        if let cached = cachedBrightnessAppRunning,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheDuration {
            return cached
        }
        
        // Enumerate running apps and check for known brightness control apps
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return brightnessAppBundleIDs.contains(bundleID)
        }
        
        // Update cache
        cachedBrightnessAppRunning = isRunning
        cacheTimestamp = Date()
        
        return isRunning
    }
    
    private init() {}
    
    /// Start intercepting media keys
    /// Returns true if successfully started, false if permissions denied
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        
        // Check for Accessibility permissions using cached grant
        // Avoids false negatives when TCC hasn't synced yet
        guard PermissionManager.shared.isAccessibilityGranted else {
            print("MediaKeyInterceptor: Accessibility permissions not granted. Grant in System Settings > Privacy & Security > Accessibility")
            return false
        }
        
        // Create event tap for system-defined events (media keys)
        // CGEventType.systemDefined is raw value 14
        let systemDefinedType = CGEventType(rawValue: 14)!
        let eventMask: CGEventMask = (1 << systemDefinedType.rawValue)
        
        // BUG #84 FIX (macOS 26 Tahoe):
        // Use .cgAnnotatedSessionEventTap instead of .cgSessionEventTap for higher priority.
        // On Tahoe, OSDUIHelper registers earlier in the event chain, so we need to use
        // the annotated session tap which has higher priority and receives events first.
        // This ensures we can suppress the event before OSDUIHelper sees it.
        guard let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: mediaKeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // Fallback to regular session tap if annotated fails (older macOS)
            print("MediaKeyInterceptor: Annotated tap failed, trying standard session tap...")
            guard let fallbackTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: mediaKeyCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else {
                print("MediaKeyInterceptor: Failed to create event tap")
                return false
            }
            eventTap = fallbackTap
            print("MediaKeyInterceptor: Using fallback session tap")
            return setupEventTapRunLoop(tap: fallbackTap)
        }
        
        eventTap = tap
        print("MediaKeyInterceptor: Using annotated session tap (macOS Tahoe fix)")
        return setupEventTapRunLoop(tap: tap)
    }
    
    /// Sets up the run loop for the event tap on a dedicated background queue
    private func setupEventTapRunLoop(tap: CFMachPort) -> Bool {
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        guard let source = runLoopSource else {
            print("MediaKeyInterceptor: Failed to create run loop source")
            return false
        }
        
        // Run on dedicated background queue to avoid main thread contention
        // This fixes double HUD issue on M4 Macs where macOS Tahoe has stricter timing
        let queue = DispatchQueue(label: "com.droppy.MediaKeyTap", qos: .userInteractive)
        self.eventTapQueue = queue
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.eventTapRunLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(self.eventTapRunLoop, source, .commonModes)
            
            // Enable tap and verify it's running
            CGEvent.tapEnable(tap: tap, enable: true)
            
            // Verify tap is enabled (BUG #84 additional check)
            if CFMachPortIsValid(tap) {
                print("MediaKeyInterceptor: Event tap verified as valid and enabled")
            } else {
                print("⚠️ MediaKeyInterceptor: Event tap created but not valid!")
            }
            
            CFRunLoopRun()
        }
        
        isRunning = true
        print("MediaKeyInterceptor: Started successfully on dedicated queue")
        return true
    }
    
    /// Stop intercepting media keys
    func stop() {
        guard isRunning else { return }
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        // Stop the dedicated run loop
        if let runLoop = eventTapRunLoop {
            CFRunLoopStop(runLoop)
        }
        
        if let source = runLoopSource, let runLoop = eventTapRunLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        eventTapQueue = nil
        eventTapRunLoop = nil
        isRunning = false
        print("MediaKeyInterceptor: Stopped")
    }
    
    /// Handle a media key event
    /// Returns true if the event was handled (should be suppressed)
    /// Returns false if the event should pass through to the system
    fileprivate func handleMediaKey(keyCode: UInt32, keyDown: Bool) -> Bool {
        // Check if this is a volume key and device doesn't support software control
        let isVolumeKey = keyCode == NX_KEYTYPE_SOUND_UP ||
                          keyCode == NX_KEYTYPE_SOUND_DOWN ||
                          keyCode == NX_KEYTYPE_MUTE
        
        if isVolumeKey && !VolumeManager.shared.supportsVolumeControl {
            // Let the system handle volume for USB devices without software volume control
            return false
        }
        
        // MONITORCONTROL COMPATIBILITY (v9.2):
        // Check if this is a brightness key and mouse is on an external display
        // If so, AND a brightness control app (MonitorControl/BetterDisplay) is running,
        // let the event pass through so that app can control external display brightness via DDC
        let isBrightnessKey = keyCode == NX_KEYTYPE_BRIGHTNESS_UP ||
                              keyCode == NX_KEYTYPE_BRIGHTNESS_DOWN
        
        if isBrightnessKey {
            // Check which display the mouse cursor is currently on
            let mouseLocation = NSEvent.mouseLocation
            if let screenUnderMouse = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
                // If mouse is on an external display, check if a brightness control app is running
                if !screenUnderMouse.isBuiltIn {
                    // Only passthrough if MonitorControl or BetterDisplay is running
                    // Otherwise, Droppy handles brightness (even though it only works on built-in)
                    if Self.isBrightnessControlAppRunning() {
                        // Passthrough: Let MonitorControl/BetterDisplay handle external display brightness
                        return false
                    }
                }
            }
            
            // Check if brightness is supported on built-in display
            if !BrightnessManager.shared.isSupported {
                return false
            }
        }
        
        // Only act on key down events
        guard keyDown else { return true }
        
        DispatchQueue.main.async {
            switch keyCode {
            case NX_KEYTYPE_SOUND_UP:
                VolumeManager.shared.increase()
                self.onVolumeUp?()
                
            case NX_KEYTYPE_SOUND_DOWN:
                VolumeManager.shared.decrease()
                self.onVolumeDown?()
                
            case NX_KEYTYPE_MUTE:
                VolumeManager.shared.toggleMute()
                self.onMute?()
                
            case NX_KEYTYPE_BRIGHTNESS_UP:
                BrightnessManager.shared.increase()
                self.onBrightnessUp?()
                
            case NX_KEYTYPE_BRIGHTNESS_DOWN:
                BrightnessManager.shared.decrease()
                self.onBrightnessDown?()
                
            default:
                break
            }
        }
        
        return true
    }
}

/// C callback function for CGEventTap
/// Uses a safe pattern to extract NSEvent data without memory issues
private func mediaKeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    
    // Handle tap being disabled (system temporarily disables if we take too long)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        // CRITICAL CHECK: Before re-enabling, verify we still have permission.
        // If the user revoked permissions, the system disables the tap.
        // If we blindly re-enable it here without checking, we create a tight loop
        // fighting the system, which freezes the WindowServer/whole Mac.
        if !PermissionManager.shared.isAccessibilityGranted {
            print("❌ MediaKeyInterceptor: Tap disabled and permissions revoked. Stopping interceptor to prevent system freeze.")
            
            // We must stop the interceptor. Since we are in a C callback which might be on a background thread,
            // we should dispatch the stop call safely.
            DispatchQueue.main.async {
                MediaKeyInterceptor.shared.stop()
            }
            // Return event to system as is
            return Unmanaged.passUnretained(event)
        }
        
        // Tap temporarily disabled by system - this is normal, silently re-enable
        if let tap = MediaKeyInterceptor.shared.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }
    
    // Only process system-defined events (raw value 14)
    guard type.rawValue == 14 else {
        return Unmanaged.passUnretained(event)
    }
    
    // PERFORMANCE FIX: Extract NSEvent data inline WITHOUT main thread dispatch
    // The TSM assertion only affects caps lock handling, which we don't use
    // Media keys (volume/brightness) work fine off main thread
    guard let nsEvent = NSEvent(cgEvent: event),
          nsEvent.subtype.rawValue == 8 else { // NX_SUBTYPE_AUX_CONTROL_BUTTONS = 8
        return Unmanaged.passUnretained(event)
    }
    
    // Extract key data
    let data1 = nsEvent.data1
    let keyCode = UInt32((data1 & 0xFFFF0000) >> 16)
    let keyFlags = UInt32(data1 & 0x0000FFFF)
    let keyState = ((keyFlags & 0xFF00) >> 8)
    
    let keyDown = keyState == 0x0A || keyState == 0x08
    let keyUp = keyState == 0x0B
    let keyRepeat = (keyFlags & 0x1) != 0
    let shouldProcess = (keyDown || keyRepeat) && !keyUp
    
    // Check if this is a media key we handle
    let handledKeys: [UInt32] = [
        NX_KEYTYPE_SOUND_UP,
        NX_KEYTYPE_SOUND_DOWN,
        NX_KEYTYPE_MUTE,
        NX_KEYTYPE_BRIGHTNESS_UP,
        NX_KEYTYPE_BRIGHTNESS_DOWN
    ]
    
    guard handledKeys.contains(keyCode) else {
        return Unmanaged.passUnretained(event)
    }
    
    // Get the interceptor instance
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    
    let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
    
    // Handle the key event
    if interceptor.handleMediaKey(keyCode: keyCode, keyDown: shouldProcess) {
        // Return nil to suppress system HUD
        return nil
    }
    
    // Let event pass through
    return Unmanaged.passUnretained(event)
}
