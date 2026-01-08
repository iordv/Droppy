//
//  VolumeManager.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  Adapted from BoringNotch's VolumeManager
//

import AppKit
import AudioToolbox
import Combine
import CoreAudio
import Foundation

/// Manages system volume using CoreAudio APIs
/// Provides real-time volume monitoring and control with auto-hide HUD timing
final class VolumeManager: NSObject, ObservableObject {
    static let shared = VolumeManager()
    
    // MARK: - Published Properties
    @Published private(set) var rawVolume: Float = 0
    @Published private(set) var isMuted: Bool = false
    @Published private(set) var lastChangeAt: Date = .distantPast
    
    // MARK: - Configuration
    let visibleDuration: TimeInterval = 1.5
    private let step: Float32 = 1.0 / 16.0
    
    // MARK: - Private State
    private var didInitialFetch = false
    private var previousVolumeBeforeMute: Float32 = 0.2
    private var softwareMuted: Bool = false
    
    // osascript debouncing - coalesce rapid volume changes to avoid delay
    private var osascriptWorkItem: DispatchWorkItem?
    private let osascriptDebounceDelay: TimeInterval = 0.05 // 50ms debounce
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioListener()
        fetchCurrentVolume()
    }
    
    /// Whether the HUD overlay should be visible
    var shouldShowOverlay: Bool {
        Date().timeIntervalSince(lastChangeAt) < visibleDuration
    }
    
    /// Whether the current output device supports volume control via CoreAudio
    /// Checks both VirtualMainVolume (preferred, works with USB devices) and VolumeScalar
    var supportsVolumeControl: Bool {
        // AppleScript fallback always works, so we always support volume control
        return true
    }
    
    // MARK: - Public Control API
    
    /// Increase volume by one step
    @MainActor func increase(stepDivisor: Float = 1.0) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / Float32(divisor)
        let current = readVolumeInternal() ?? rawVolume
        let target = max(0, min(1, current + delta))
        setAbsolute(target)
    }
    
    /// Decrease volume by one step
    @MainActor func decrease(stepDivisor: Float = 1.0) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / Float32(divisor)
        let current = readVolumeInternal() ?? rawVolume
        let target = max(0, min(1, current - delta))
        setAbsolute(target)
    }
    
    /// Toggle mute state
    @MainActor func toggleMute() {
        let deviceID = systemOutputDeviceID()
        
        if deviceID == kAudioObjectUnknown {
            // Software mute fallback
        } else {
            // Hardware mute
        }
        
        toggleMuteInternal()
    }
    
    /// Refresh volume from system
    func refresh() {
        fetchCurrentVolume()
    }
    
    /// Set volume to absolute value (0.0 - 1.0)
    @MainActor func setAbsolute(_ value: Float32) {
        let clamped = max(0, min(1, value))
        let currentlyMuted = isMutedInternal()
        
        if currentlyMuted && clamped > 0 {
            toggleMuteInternal()
        }
        
        writeVolumeInternal(clamped)
        
        if clamped == 0 && !currentlyMuted {
            toggleMuteInternal()
        }
        
        publish(volume: clamped, muted: isMutedInternal(), touchDate: true)
    }
    
    // MARK: - CoreAudio Helpers
    
    private func systemOutputDeviceID() -> AudioObjectID {
        var defaultDeviceID = kAudioObjectUnknown
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultDeviceID
        )
        if status != noErr { return kAudioObjectUnknown }
        return defaultDeviceID
    }
    
    private func fetchCurrentVolume() {
        let deviceID = systemOutputDeviceID()
        
        var fetchedVolume: Float32? = nil
        
        if deviceID != kAudioObjectUnknown {
            // First try VirtualMainVolume (works with USB devices like Jabra)
            var virtualAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            if AudioObjectHasProperty(deviceID, &virtualAddr) {
                var vol = Float32(0)
                var size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectGetPropertyData(deviceID, &virtualAddr, 0, nil, &size, &vol) == noErr {
                    fetchedVolume = vol
                }
            }
            
            // Fall back to VolumeScalar
            if fetchedVolume == nil {
                var volumes: [Float32] = []
                let candidateElements: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2, 3, 4]
                
                for element in candidateElements {
                    if let v = readValidatedScalar(deviceID: deviceID, element: element) {
                        volumes.append(v)
                    }
                }
                
                if !volumes.isEmpty {
                    fetchedVolume = volumes.reduce(0, +) / Float32(volumes.count)
                }
            }
        }
        
        // Final fallback: osascript
        if fetchedVolume == nil {
            fetchedVolume = readVolumeViaOsascript()
        }
        
        if let avg = fetchedVolume {
            let clampedAvg = max(0, min(1, avg))
            DispatchQueue.main.async {
                if self.rawVolume != clampedAvg {
                    if self.didInitialFetch {
                        self.lastChangeAt = Date()
                    }
                }
                self.rawVolume = clampedAvg
                self.didInitialFetch = true
            }
        }

        
        // Check mute state
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            var sizeNeeded: UInt32 = 0
            if AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
               sizeNeeded == UInt32(MemoryLayout<UInt32>.size) {
                var muted: UInt32 = 0
                var mSize = sizeNeeded
                if AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mSize, &muted) == noErr {
                    let newMuted = muted != 0
                    DispatchQueue.main.async {
                        if self.isMuted != newMuted { self.lastChangeAt = Date() }
                        self.isMuted = newMuted
                    }
                }
            }
        }
    }
    
    private func setupAudioListener() {
        let deviceID = systemOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }
        
        // Listen for default device changes
        var defaultDevAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultDevAddr, nil
        ) { [weak self] _, _ in
            self?.fetchCurrentVolume()
        }
        
        // Listen for volume changes
        var masterAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectHasProperty(deviceID, &masterAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &masterAddr, nil) { [weak self] _, _ in
                self?.fetchCurrentVolume()
            }
        } else {
            for ch in [UInt32(1), UInt32(2)] {
                var chAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: ch
                )
                if AudioObjectHasProperty(deviceID, &chAddr) {
                    AudioObjectAddPropertyListenerBlock(deviceID, &chAddr, nil) { [weak self] _, _ in
                        self?.fetchCurrentVolume()
                    }
                }
            }
        }
        
        // Listen for mute changes
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, nil) { [weak self] _, _ in
                self?.fetchCurrentVolume()
            }
        }
    }
    
    private func readVolumeInternal() -> Float32? {
        let deviceID = systemOutputDeviceID()
        
        if deviceID != kAudioObjectUnknown {
            // First try VirtualMainVolume (works with USB devices like Jabra)
            var virtualAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            if AudioObjectHasProperty(deviceID, &virtualAddr) {
                var vol = Float32(0)
                var size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectGetPropertyData(deviceID, &virtualAddr, 0, nil, &size, &vol) == noErr {
                    return vol
                }
            }
            
            // Fall back to VolumeScalar (for devices that don't support VirtualMainVolume)
            var collected: [Float32] = []
            for el in [kAudioObjectPropertyElementMain, UInt32(1), UInt32(2), UInt32(3), UInt32(4)] {
                if let v = readValidatedScalar(deviceID: deviceID, element: el) {
                    collected.append(v)
                }
            }
            if !collected.isEmpty {
                return collected.reduce(0, +) / Float32(collected.count)
            }
        }
        
        // Final fallback: osascript (works for USB devices that CoreAudio can't read)
        return readVolumeViaOsascript()
    }
    
    /// Read volume using osascript - the same method macOS uses for system volume control
    private func readVolumeViaOsascript() -> Float32? {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "output volume of (get volume settings)"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let volumePercent = Int(output) {
                return Float32(volumePercent) / 100.0
            }
        } catch {
            print("[VolumeManager] osascript read failed: \(error)")
        }
        return nil
    }
    
    private func writeVolumeInternal(_ value: Float32) {
        let deviceID = systemOutputDeviceID()
        let newVal = max(0, min(1, value))
        
        // Skip CoreAudio attempts if no device found
        if deviceID != kAudioObjectUnknown {
            // First try VirtualMainVolume (works with USB devices like Jabra)
            var virtualAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            if AudioObjectHasProperty(deviceID, &virtualAddr) {
                var vol = newVal
                let size = UInt32(MemoryLayout<Float32>.size)
                if AudioObjectSetPropertyData(deviceID, &virtualAddr, 0, nil, size, &vol) == noErr {
                    // Verify the write actually worked (some USB devices return success but don't apply)
                    var readBack = Float32(0)
                    var readSize = size
                    if AudioObjectGetPropertyData(deviceID, &virtualAddr, 0, nil, &readSize, &readBack) == noErr {
                        // Check if the value is close to what we set (within 2%)
                        if abs(readBack - newVal) < 0.02 {
                            return
                        }
                    }
                }
            }
            
            // Fall back to VolumeScalar
            if writeValidatedScalar(deviceID: deviceID, element: kAudioObjectPropertyElementMain, value: newVal) {
                // Verify this one too
                let readBack = readValidatedScalar(deviceID: deviceID, element: kAudioObjectPropertyElementMain)
                if let rb = readBack, abs(rb - newVal) < 0.02 {
                    return
                }
            }
            
            // Try individual channels - skip verification for simplicity, just try
            var channelSuccess = false
            for el in [UInt32(1), UInt32(2), UInt32(3), UInt32(4)] {
                if writeValidatedScalar(deviceID: deviceID, element: el, value: newVal) {
                    channelSuccess = true
                }
            }
            if channelSuccess {
                // Verify at least one channel changed
                if let vol = readVolumeInternal(), abs(vol - newVal) < 0.05 {
                    return
                }
            }
        }
        
        // Final fallback: osascript (same as macOS system volume control)
        writeVolumeViaOsascript(newVal)
    }
    
    /// Write volume using osascript - the same method macOS uses for system volume control
    /// Uses debouncing to coalesce rapid key presses and avoid delay buildup
    private func writeVolumeViaOsascript(_ value: Float32) {
        let volumePercent = Int(value * 100)
        
        // Cancel any pending osascript execution
        osascriptWorkItem?.cancel()
        
        // Create new work item with the latest volume value
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, !(self.osascriptWorkItem?.isCancelled ?? true) else { return }
            
            // First unmute (some USB devices like Jabra get stuck in muted state)
            // Then set volume - both in one script call for efficiency
            let script = "set volume without output muted\nset volume output volume \(volumePercent)"
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("[VolumeManager] osascript failed: \(error)")
            }
        }
        
        osascriptWorkItem = workItem
        
        // Execute after debounce delay on background queue
        DispatchQueue.global(qos: .userInteractive).asyncAfter(
            deadline: .now() + osascriptDebounceDelay,
            execute: workItem
        )
    }
    
    private func isMutedInternal() -> Bool {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown { return softwareMuted }
        
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &muteAddr) else { return softwareMuted }
        
        var sizeNeeded: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
              sizeNeeded == UInt32(MemoryLayout<UInt32>.size) else { return softwareMuted }
        
        var muted: UInt32 = 0
        var size = sizeNeeded
        if AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &size, &muted) == noErr {
            return muted != 0
        }
        return softwareMuted
    }
    
    private func toggleMuteInternal() {
        let deviceID = systemOutputDeviceID()
        if deviceID == kAudioObjectUnknown {
            performSoftwareMuteToggle(currentVolume: rawVolume)
            return
        }
        
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if !AudioObjectHasProperty(deviceID, &muteAddr) {
            performSoftwareMuteToggle(currentVolume: readVolumeInternal() ?? rawVolume)
            return
        }
        
        var sizeNeeded: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &muteAddr, 0, nil, &sizeNeeded) == noErr,
              sizeNeeded == UInt32(MemoryLayout<UInt32>.size) else {
            performSoftwareMuteToggle(currentVolume: readVolumeInternal() ?? rawVolume)
            return
        }
        
        var muted: UInt32 = 0
        var size = sizeNeeded
        if AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &size, &muted) == noErr {
            var newVal: UInt32 = muted == 0 ? 1 : 0
            AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, size, &newVal)
            let vol = readVolumeInternal() ?? rawVolume
            publish(volume: vol, muted: newVal != 0, touchDate: true)
        } else {
            performSoftwareMuteToggle(currentVolume: readVolumeInternal() ?? rawVolume)
        }
    }
    
    private func performSoftwareMuteToggle(currentVolume: Float32) {
        if softwareMuted {
            let restore = max(0, min(1, previousVolumeBeforeMute))
            writeVolumeInternal(restore)
            softwareMuted = false
            publish(volume: restore, muted: false, touchDate: true)
        } else {
            if currentVolume > 0.001 { previousVolumeBeforeMute = currentVolume }
            writeVolumeInternal(0)
            softwareMuted = true
            publish(volume: 0, muted: true, touchDate: true)
        }
    }
    
    private func readValidatedScalar(deviceID: AudioObjectID, element: UInt32) -> Float32? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return nil }
        
        var sizeNeeded: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &sizeNeeded) == noErr,
              sizeNeeded == UInt32(MemoryLayout<Float32>.size) else { return nil }
        
        var vol = Float32(0)
        var size = sizeNeeded
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol)
        return status == noErr ? vol : nil
    }
    
    private func writeValidatedScalar(deviceID: AudioObjectID, element: UInt32, value: Float32) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return false }
        
        let size = UInt32(MemoryLayout<Float32>.size)
        var val = value
        let status = AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &val)
        return status == noErr
    }
    
    private func publish(volume: Float32, muted: Bool, touchDate: Bool) {
        DispatchQueue.main.async {
            if self.rawVolume != volume || self.isMuted != muted || touchDate {
                if touchDate { self.lastChangeAt = Date() }
                self.rawVolume = volume
                self.isMuted = muted
            }
        }
    }
}
