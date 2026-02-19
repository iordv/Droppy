//
//  MediaKeyInterceptor.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  Intercepts media keys (volume/brightness) to suppress system HUD
//

import AppKit
import CoreFoundation
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

// Transport control keys - MUST be passed through to system, never intercepted
private let NX_KEYTYPE_PLAY: UInt32 = 16
private let NX_KEYTYPE_FAST: UInt32 = 17       // Next track
private let NX_KEYTYPE_REWIND: UInt32 = 18     // Previous track (some keyboards)
private let NX_KEYTYPE_PREVIOUS: UInt32 = 19   // Previous track (other keyboards)

/// Intercepts volume and brightness keys to prevent system HUD from appearing
/// Requires Accessibility permissions to function
final class MediaKeyInterceptor {
    static let shared = MediaKeyInterceptor()
    private static let systemVolumeFeedbackKey = "com.apple.sound.beep.feedback" as CFString
    
    static func shouldRunForCurrentPreferences() -> Bool {
        let defaults = UserDefaults.standard
        let hudEnabled = defaults.preference(
            AppPreferenceKey.enableHUDReplacement,
            default: PreferenceDefault.enableHUDReplacement
        )
        let volumeEnabled = defaults.preference(
            AppPreferenceKey.enableVolumeHUDReplacement,
            default: PreferenceDefault.enableVolumeHUDReplacement
        )
        let brightnessEnabled = defaults.preference(
            AppPreferenceKey.enableBrightnessHUDReplacement,
            default: PreferenceDefault.enableBrightnessHUDReplacement
        )
        return hudEnabled && (volumeEnabled || brightnessEnabled)
    }
    
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
        
        // NOTE: Using cgSessionEventTap (not cgAnnotatedSessionEventTap)
        // The annotated tap breaks transport controls (play/pause/next/previous) on macOS Tahoe
        // by intercepting events before they reach the media subsystem, even when we passthrough.
        // cgSessionEventTap works correctly for all keys in v9.2 and earlier.
        guard let tap = CGEvent.tapCreate(
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
        
        eventTap = tap
        print("MediaKeyInterceptor: Using session event tap")
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
    
    func refreshForCurrentPreferences() {
        if Self.shouldRunForCurrentPreferences() {
            _ = start()
        } else {
            stop()
        }
    }

    private func shouldPlayVolumeFeedbackSound() -> Bool {
        let appFeedbackEnabled = UserDefaults.standard.preference(
            AppPreferenceKey.enableVolumeKeyFeedbackSound,
            default: PreferenceDefault.enableVolumeKeyFeedbackSound
        )
        guard appFeedbackEnabled else { return false }

        if let hostValue = CFPreferencesCopyValue(
            Self.systemVolumeFeedbackKey,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        ) as? NSNumber {
            return hostValue.boolValue
        }

        if let globalValue = CFPreferencesCopyValue(
            Self.systemVolumeFeedbackKey,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? NSNumber {
            return globalValue.boolValue
        }

        return true
    }

    private func playVolumeFeedbackIfNeeded(previousVolume: Float32, previousMuted: Bool) {
        guard shouldPlayVolumeFeedbackSound() else { return }

        let volumeChanged = abs(VolumeManager.shared.rawVolume - previousVolume) > 0.0005
        let muteChanged = VolumeManager.shared.isMuted != previousMuted
        guard volumeChanged || muteChanged else { return }

        NSSound.beep()
    }

    private func stepDivisor(for modifierFlags: NSEvent.ModifierFlags) -> Float {
        let normalized = modifierFlags.intersection(.deviceIndependentFlagsMask)
        let usesFineControl = normalized.contains(.option) && normalized.contains(.shift)
        return usesFineControl ? 4.0 : 1.0
    }
    
    /// Handle a media key event
    /// Returns true if the event was handled (should be suppressed)
    /// Returns false if the event should pass through to the system
    fileprivate func handleMediaKey(
        keyCode: UInt32,
        keyDown: Bool,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        let mouseLocation = NSEvent.mouseLocation
        let screenUnderMouse = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
        let stepDivisor = self.stepDivisor(for: modifierFlags)
        
        let hudEnabled = UserDefaults.standard.preference(
            AppPreferenceKey.enableHUDReplacement,
            default: PreferenceDefault.enableHUDReplacement
        )
        let volumeReplacementEnabled = UserDefaults.standard.preference(
            AppPreferenceKey.enableVolumeHUDReplacement,
            default: PreferenceDefault.enableVolumeHUDReplacement
        )
        let brightnessReplacementEnabled = UserDefaults.standard.preference(
            AppPreferenceKey.enableBrightnessHUDReplacement,
            default: PreferenceDefault.enableBrightnessHUDReplacement
        )
        
        // Check if this is a volume key and device doesn't support software control
        let isVolumeKey = keyCode == NX_KEYTYPE_SOUND_UP ||
                          keyCode == NX_KEYTYPE_SOUND_DOWN ||
                          keyCode == NX_KEYTYPE_MUTE
        
        if isVolumeKey && (!hudEnabled || !volumeReplacementEnabled) {
            return false
        }
        
        if isVolumeKey && !VolumeManager.shared.supportsVolumeControl {
            // Let the system handle volume for USB devices without software volume control
            return false
        }

        let isBrightnessKey = keyCode == NX_KEYTYPE_BRIGHTNESS_UP ||
                              keyCode == NX_KEYTYPE_BRIGHTNESS_DOWN
        
        if isBrightnessKey && (!hudEnabled || !brightnessReplacementEnabled) {
            return false
        }
        
        if isBrightnessKey {
            // BetterDisplay compatibility path:
            // let BetterDisplay/system process brightness keys, then Droppy mirrors the
            // resulting brightness via polling-based HUD bridge in BrightnessManager.
            if BrightnessManager.shared.shouldPassthroughBrightnessKeyToSystem(on: screenUnderMouse) {
                return false
            }
            
            // Let system handle brightness when Droppy cannot control the selected target.
            if !BrightnessManager.shared.canHandleBrightness(on: screenUnderMouse) {
                return false
            }
        }
        
        // Only act on key down events
        guard keyDown else { return true }
        
        DispatchQueue.main.async {
            switch keyCode {
            case NX_KEYTYPE_SOUND_UP:
                let previousVolume = VolumeManager.shared.rawVolume
                let previousMuted = VolumeManager.shared.isMuted
                VolumeManager.shared.increase(stepDivisor: stepDivisor, screenHint: screenUnderMouse)
                self.playVolumeFeedbackIfNeeded(previousVolume: previousVolume, previousMuted: previousMuted)
                self.onVolumeUp?()
                
            case NX_KEYTYPE_SOUND_DOWN:
                let previousVolume = VolumeManager.shared.rawVolume
                let previousMuted = VolumeManager.shared.isMuted
                VolumeManager.shared.decrease(stepDivisor: stepDivisor, screenHint: screenUnderMouse)
                self.playVolumeFeedbackIfNeeded(previousVolume: previousVolume, previousMuted: previousMuted)
                self.onVolumeDown?()
                
            case NX_KEYTYPE_MUTE:
                VolumeManager.shared.toggleMute(screenHint: screenUnderMouse)
                self.onMute?()
                
            case NX_KEYTYPE_BRIGHTNESS_UP:
                BrightnessManager.shared.increase(stepDivisor: stepDivisor, screenHint: screenUnderMouse)
                self.onBrightnessUp?()
                
            case NX_KEYTYPE_BRIGHTNESS_DOWN:
                BrightnessManager.shared.decrease(stepDivisor: stepDivisor, screenHint: screenUnderMouse)
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
    
    // CRASH FIX: NSEvent(cgEvent:) on background thread crashes when Caps Lock is involved!
    // When Caps Lock is pressed, NSEvent init triggers TSM (Text Services Manager)
    // Caps Lock handling which REQUIRES the main thread. This causes:
    // _dispatch_assert_queue_fail in TISIsDesignatedRomanModeCapsLockSwitchAllowed
    //
    // Solution: Create NSEvent on main thread synchronously. Media key events are
    // infrequent (user key presses), so the sync dispatch latency is acceptable.
    
    // Only process system-defined events (raw value 14)
    guard type.rawValue == 14 else {
        return Unmanaged.passUnretained(event)
    }
    
    // Extract NSEvent data on main thread to avoid TSM Caps Lock crash
    var nsEventData1: Int = 0
    var nsEventSubtype: Int16 = 0
    var nsEventModifierFlags: NSEvent.ModifierFlags = []
    
    DispatchQueue.main.sync {
        if let nsEvent = NSEvent(cgEvent: event) {
            nsEventData1 = nsEvent.data1
            nsEventSubtype = nsEvent.subtype.rawValue
            nsEventModifierFlags = nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        }
    }
    
    // Check subtype - we only handle NX_SUBTYPE_AUX_CONTROL_BUTTONS (8)
    guard nsEventSubtype == 8 else {
        return Unmanaged.passUnretained(event)
    }
    
    // Extract key data from data1
    let keyCode = UInt32((nsEventData1 & 0xFFFF0000) >> 16)
    let keyFlags = UInt32(nsEventData1 & 0x0000FFFF)
    let keyState = ((keyFlags & 0xFF00) >> 8)
    
    let keyDown = keyState == 0x0A || keyState == 0x08
    let keyUp = keyState == 0x0B
    let keyRepeat = (keyFlags & 0x1) != 0
    let shouldProcess = (keyDown || keyRepeat) && !keyUp
    
    // CRITICAL: Transport control keys MUST pass through to system immediately
    // These are: PLAY (16), NEXT/FAST (17), PREVIOUS/REWIND (18, 19)
    // On macOS Tahoe, cgAnnotatedSessionEventTap intercepts these before the media system
    // We MUST NOT touch them at all - return immediately without any processing
    let transportKeys: [UInt32] = [
        NX_KEYTYPE_PLAY,
        NX_KEYTYPE_FAST,
        NX_KEYTYPE_REWIND,
        NX_KEYTYPE_PREVIOUS
    ]
    
    if transportKeys.contains(keyCode) {
        // Pass through transport controls to system media handlers
        return Unmanaged.passUnretained(event)
    }
    
    // Check if this is a media key we handle (volume/brightness)
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
    if interceptor.handleMediaKey(
        keyCode: keyCode,
        keyDown: shouldProcess,
        modifierFlags: nsEventModifierFlags
    ) {
        // Return nil to suppress system HUD
        return nil
    }
    
    // Let event pass through
    return Unmanaged.passUnretained(event)
}
