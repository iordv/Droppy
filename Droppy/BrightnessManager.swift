//
//  BrightnessManager.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  Screen brightness control using DisplayServices private APIs (for Apple Silicon)
//

import AppKit
import Combine
import Foundation

/// Manages screen brightness using dynamically loaded DisplayServices APIs
/// Uses DisplayServices framework which works on Apple Silicon Macs
final class BrightnessManager: ObservableObject {
    static let shared = BrightnessManager()
    
    // MARK: - Published Properties
    @Published private(set) var rawBrightness: Float = 0.5
    @Published private(set) var lastChangeAt: Date = .distantPast
    @Published private(set) var isSupported: Bool = false
    
    // MARK: - Configuration
    let visibleDuration: TimeInterval = 1.5
    private let step: Float = 1.0 / 16.0
    
    // MARK: - DisplayServices Dynamic Loading
    private var displayServicesBundle: CFBundle?
    private var isFrameworkLoaded = false
    
    // Cached display ID to avoid thread-unsafe NSScreen access from background threads
    private var mainDisplayID: CGDirectDisplayID?
    
    // Function pointers loaded at runtime (DisplayServices API for Apple Silicon)
    private var DisplayServicesGetBrightnessPtr: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32)?
    private var DisplayServicesSetBrightnessPtr: (@convention(c) (CGDirectDisplayID, Float) -> Int32)?
    
    // Fallback: CoreDisplay API (older Intel Macs)
    private var CoreDisplay_Display_GetUserBrightnessPtr: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32)?
    private var CoreDisplay_Display_SetUserBrightnessPtr: (@convention(c) (CGDirectDisplayID, Double) -> Int32)?
    
    // Polling for brightness changes
    private var pollTimer: DispatchSourceTimer?
    private var lastPolledBrightness: Float = 0.5
    private var pollFailCount: Int = 0
    
    // MARK: - Initialization
    private init() {
        loadFrameworks()
        // Cache the built-in display ID on main thread for brightness control
        // When docked, NSScreen.main may be the external display, so we specifically look for built-in
        mainDisplayID = findBuiltInDisplayID() ?? {
            // Fallback to main display if no built-in found
            if let screen = NSScreen.main,
               let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                return displayID
            }
            return nil
        }()
        
        if let brightness = getCurrentBrightness() {
            rawBrightness = brightness
            lastPolledBrightness = brightness
            isSupported = true
            print("BrightnessManager: Initialized with brightness \(rawBrightness), isSupported: true")
            startBrightnessPolling()
        } else {
            print("BrightnessManager: Could not read brightness, isSupported: false")
            isSupported = false
        }
    }
    
    /// Find the built-in (laptop) display ID for brightness control
    private func findBuiltInDisplayID() -> CGDirectDisplayID? {
        for screen in NSScreen.screens {
            let name = screen.localizedName
            // macOS reports built-in displays with "Built-in" or "Internal" in the name
            if name.contains("Built-in") || name.contains("Internal") {
                if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                    print("BrightnessManager: Found built-in display: \(name)")
                    return displayID
                }
            }
        }
        return nil
    }
    
    deinit {
        pollTimer?.cancel()
    }
    
    /// Whether the HUD overlay should be visible
    var shouldShowOverlay: Bool {
        Date().timeIntervalSince(lastChangeAt) < visibleDuration
    }
    
    // MARK: - Framework Loading
    
    private func loadFrameworks() {
        // Try DisplayServices first (Apple Silicon)
        if loadDisplayServices() {
            print("BrightnessManager: DisplayServices framework loaded")
            return
        }
        
        // Fallback to CoreDisplay (Intel)
        if loadCoreDisplay() {
            print("BrightnessManager: CoreDisplay framework loaded")
            return
        }
        
        print("BrightnessManager: No brightness framework available")
    }
    
    private func loadDisplayServices() -> Bool {
        let frameworkPath = "/System/Library/PrivateFrameworks/DisplayServices.framework"
        guard let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, frameworkPath as CFString, .cfurlposixPathStyle, true),
              let bundle = CFBundleCreate(kCFAllocatorDefault, url),
              CFBundleLoadExecutable(bundle) else {
            return false
        }
        
        displayServicesBundle = bundle
        
        // Load DisplayServices functions
        DisplayServicesGetBrightnessPtr = unsafeBitCast(
            CFBundleGetFunctionPointerForName(bundle, "DisplayServicesGetBrightness" as CFString),
            to: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32)?.self
        )
        
        DisplayServicesSetBrightnessPtr = unsafeBitCast(
            CFBundleGetFunctionPointerForName(bundle, "DisplayServicesSetBrightness" as CFString),
            to: (@convention(c) (CGDirectDisplayID, Float) -> Int32)?.self
        )
        
        isFrameworkLoaded = DisplayServicesGetBrightnessPtr != nil && DisplayServicesSetBrightnessPtr != nil
        return isFrameworkLoaded
    }
    
    private func loadCoreDisplay() -> Bool {
        let frameworkPath = "/System/Library/Frameworks/CoreDisplay.framework"
        guard let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, frameworkPath as CFString, .cfurlposixPathStyle, true),
              let bundle = CFBundleCreate(kCFAllocatorDefault, url),
              CFBundleLoadExecutable(bundle) else {
            return false
        }
        
        displayServicesBundle = bundle
        
        CoreDisplay_Display_GetUserBrightnessPtr = unsafeBitCast(
            CFBundleGetFunctionPointerForName(bundle, "CoreDisplay_Display_GetUserBrightness" as CFString),
            to: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32)?.self
        )
        
        CoreDisplay_Display_SetUserBrightnessPtr = unsafeBitCast(
            CFBundleGetFunctionPointerForName(bundle, "CoreDisplay_Display_SetUserBrightness" as CFString),
            to: (@convention(c) (CGDirectDisplayID, Double) -> Int32)?.self
        )
        
        isFrameworkLoaded = CoreDisplay_Display_GetUserBrightnessPtr != nil && CoreDisplay_Display_SetUserBrightnessPtr != nil
        return isFrameworkLoaded
    }
    
    // MARK: - Public Control API
    
    /// Increase brightness by one step
    func increase(stepDivisor: Float = 1.0) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / divisor
        let current = getCurrentBrightness() ?? rawBrightness
        let target = max(0, min(1, current + delta))
        setAbsolute(value: target)
    }
    
    /// Decrease brightness by one step
    func decrease(stepDivisor: Float = 1.0) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / divisor
        let current = getCurrentBrightness() ?? rawBrightness
        let target = max(0, min(1, current - delta))
        setAbsolute(value: target)
    }
    
    /// Refresh brightness from system
    func refresh() {
        if let brightness = getCurrentBrightness() {
            publish(brightness: brightness, touchDate: false)
        }
    }
    
    /// Set brightness to absolute value (0.0 - 1.0)
    func setAbsolute(value: Float) {
        let clamped = max(0, min(1, value))
        if setBrightness(clamped) {
            publish(brightness: clamped, touchDate: true)
        } else {
            refresh()
        }
    }
    
    // MARK: - Private Brightness Helpers
    
    private func getCurrentBrightness() -> Float? {
        guard let displayID = mainDisplayID else { return nil }
        
        var currentBrightness: Float = 0.5
        
        // Try DisplayServices first (Apple Silicon)
        if let getBrightness = DisplayServicesGetBrightnessPtr {
            let result = getBrightness(displayID, &currentBrightness)
            if result == 0 {
                return currentBrightness
            }
        }
        
        // Fallback to CoreDisplay (Intel)
        if let getBrightness = CoreDisplay_Display_GetUserBrightnessPtr {
            let result = getBrightness(displayID, &currentBrightness)
            if result == 0 {
                return currentBrightness
            }
        }
        
        return nil
    }
    
    private func setBrightness(_ value: Float) -> Bool {
        guard let displayID = mainDisplayID else { return false }
        
        // Try DisplayServices first (Apple Silicon)
        if let setBrightnessFunc = DisplayServicesSetBrightnessPtr {
            let result = setBrightnessFunc(displayID, value)
            if result == 0 {
                return true
            }
        }
        
        // Fallback to CoreDisplay (Intel)  
        if let setBrightnessFunc = CoreDisplay_Display_SetUserBrightnessPtr {
            let result = setBrightnessFunc(displayID, Double(value))
            if result == 0 {
                return true
            }
        }
        
        return false
    }
    
    private func publish(brightness: Float, touchDate: Bool) {
        DispatchQueue.main.async {
            if self.rawBrightness != brightness || touchDate {
                if touchDate { self.lastChangeAt = Date() }
                self.rawBrightness = brightness
            }
        }
    }
    
    // MARK: - Brightness Polling
    
    private func startBrightnessPolling() {
        guard isSupported else { return }
        
        print("BrightnessManager: Starting brightness polling")
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 0.5, repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                
                if let current = self.getCurrentBrightness() {
                    self.pollFailCount = 0
                    // Detect if brightness changed (with small threshold to avoid noise)
                    if abs(current - self.lastPolledBrightness) > 0.01 {
                        self.lastPolledBrightness = current
                        self.publish(brightness: current, touchDate: true)
                    }
                } else {
                    // Stop polling if we get too many failures
                    self.pollFailCount += 1
                    if self.pollFailCount > 10 {
                        print("BrightnessManager: Too many poll failures, stopping")
                        self.pollTimer?.cancel()
                        DispatchQueue.main.async {
                            self.isSupported = false
                        }
                    }
                }
            }
        }
        timer.resume()
        pollTimer = timer
    }
}
