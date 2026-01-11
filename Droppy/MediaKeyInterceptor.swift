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
        
        // Check for Accessibility permissions WITHOUT prompting
        // Prompting via kAXTrustedCheckOptionPrompt causes TCC crash on macOS 14+
        // The user must manually grant permission in System Settings > Privacy & Security > Accessibility
        guard AXIsProcessTrusted() else {
            print("MediaKeyInterceptor: Accessibility permissions not granted. Grant in System Settings > Privacy & Security > Accessibility")
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
/// Uses a safe pattern to extract NSEvent data without memory issues
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
    
    // Safely extract data from NSEvent - capture all needed values immediately
    // This struct holds the extracted data as pure value types
    struct MediaKeyData {
        var isValid: Bool = false
        var keyCode: UInt32 = 0
        var shouldProcess: Bool = false
    }
    
    // Extract data in a controlled scope - the NSEvent is released when scope ends
    let keyData: MediaKeyData = {
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return MediaKeyData()
        }
        
        // NX_SUBTYPE_AUX_CONTROL_BUTTONS = 8
        guard nsEvent.subtype.rawValue == 8 else {
            return MediaKeyData()
        }
        
        // Capture data1 immediately as a value type
        let data1 = nsEvent.data1
        let keyCode = UInt32((data1 & 0xFFFF0000) >> 16)
        let keyFlags = UInt32(data1 & 0x0000FFFF)
        let keyState = ((keyFlags & 0xFF00) >> 8)
        
        // Key state interpretation
        let keyDown = keyState == 0x0A || keyState == 0x08
        let keyUp = keyState == 0x0B
        let keyRepeat = (keyFlags & 0x1) != 0
        let shouldProcess = (keyDown || keyRepeat) && !keyUp
        
        return MediaKeyData(isValid: true, keyCode: keyCode, shouldProcess: shouldProcess)
    }()
    
    // If extraction failed, pass through
    guard keyData.isValid else {
        return Unmanaged.passUnretained(event)
    }
    
    // Check if this is a media key we handle
    let handledKeys: [UInt32] = [
        NX_KEYTYPE_SOUND_UP,
        NX_KEYTYPE_SOUND_DOWN,
        NX_KEYTYPE_MUTE,
        NX_KEYTYPE_BRIGHTNESS_UP,
        NX_KEYTYPE_BRIGHTNESS_DOWN
    ]
    
    guard handledKeys.contains(keyData.keyCode) else {
        return Unmanaged.passUnretained(event)
    }
    
    // Get the interceptor instance
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }
    
    let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
    
    // Handle the key event
    if interceptor.handleMediaKey(keyCode: keyData.keyCode, keyDown: keyData.shouldProcess) {
        // Return nil to suppress system HUD
        return nil
    }
    
    // Let event pass through
    return Unmanaged.passUnretained(event)
}
