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
        
        // Check for Accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("MediaKeyInterceptor: Accessibility permissions not granted")
            return false
        }
        
        // Create event tap for system-defined events (media keys)
        // CGEventType.systemDefined is raw value 14
        let systemDefinedType = CGEventType(rawValue: 14)!
        let eventMask: CGEventMask = (1 << systemDefinedType.rawValue)
        
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
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isRunning = true
            print("MediaKeyInterceptor: Started successfully")
            return true
        }
        
        return false
    }
    
    /// Stop intercepting media keys
    func stop() {
        guard isRunning else { return }
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
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
/// Uses autoreleasepool to properly manage NSEvent memory
private func mediaKeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    
    // Handle tap being disabled (system temporarily disables if we take too long)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = MediaKeyInterceptor.shared.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }
    
    // Only process system-defined events (raw value 14)
    guard type.rawValue == 14 else {
        return Unmanaged.passUnretained(event)
    }
    
    // SAFETY: Create a copy of the event to avoid race conditions with HID queue
    // The original event may be deallocated while we're processing
    guard let eventCopy = event.copy() else {
        return Unmanaged.passUnretained(event)
    }
    
    // Use autoreleasepool to properly manage NSEvent memory
    // This prevents objc_release crashes from CGEvent/NSEvent bridging
    var shouldSuppress = false
    
    autoreleasepool {
        // Convert to NSEvent to extract media key data
        // SAFETY: Use eventCopy instead of original event
        guard let nsEvent = NSEvent(cgEvent: eventCopy),
              nsEvent.subtype.rawValue == 8 else { // NX_SUBTYPE_AUX_CONTROL_BUTTONS
            return
        }
        
        // Extract key data immediately before nsEvent is released
        let data1 = nsEvent.data1
        let keyCode = UInt32((data1 & 0xFFFF0000) >> 16)
        let keyFlags = UInt32(data1 & 0x0000FFFF)
        let keyState = ((keyFlags & 0xFF00) >> 8)
        
        // Key state interpretation:
        // 0x0A = Key down
        // 0x0B = Key up
        // Some external keyboards may also send 0x08 or other values for key events
        // We process on key down (0x0A) OR if it's a key repeat (indicated by bit 0)
        let keyDown = keyState == 0x0A || keyState == 0x08 // Accept multiple keyDown states
        let keyUp = keyState == 0x0B
        let keyRepeat = (keyFlags & 0x1) != 0
        
        // Process on key down OR key repeat, ignore key up
        let shouldProcess = (keyDown || keyRepeat) && !keyUp
        
        // Check if this is a media key we handle
        let handledKeys: [UInt32] = [
            NX_KEYTYPE_SOUND_UP,
            NX_KEYTYPE_SOUND_DOWN,
            NX_KEYTYPE_MUTE,
            NX_KEYTYPE_BRIGHTNESS_UP,
            NX_KEYTYPE_BRIGHTNESS_DOWN
        ]
        
        if handledKeys.contains(keyCode) {
            // Get the interceptor instance
            if let userInfo = userInfo {
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
                
                // Handle the key event
                if interceptor.handleMediaKey(keyCode: keyCode, keyDown: shouldProcess) {
                    shouldSuppress = true
                }
            }
        }
    }
    
    // Return nil AFTER autoreleasepool to suppress system HUD
    if shouldSuppress {
        return nil
    }
    
    // Let other events pass through
    return Unmanaged.passUnretained(event)
}
