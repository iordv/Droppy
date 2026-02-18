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
import IOKit
import IOKit.graphics
import IOKit.i2c

private typealias IOAVServiceRef = CFTypeRef

@_silgen_name("IOAVServiceCreateWithService")
private func IOAVServiceCreateWithService(
    _ allocator: CFAllocator?,
    _ service: io_service_t
) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOAVServiceReadI2C")
private func IOAVServiceReadI2C(
    _ service: IOAVServiceRef,
    _ chipAddress: UInt32,
    _ offset: UInt32,
    _ outputBuffer: UnsafeMutableRawPointer?,
    _ outputBufferSize: UInt32
) -> IOReturn

@_silgen_name("IOAVServiceWriteI2C")
private func IOAVServiceWriteI2C(
    _ service: IOAVServiceRef,
    _ chipAddress: UInt32,
    _ dataAddress: UInt32,
    _ inputBuffer: UnsafeMutableRawPointer?,
    _ inputBufferSize: UInt32
) -> IOReturn

@_silgen_name("CGSServiceForDisplayNumber")
private func CGSServiceForDisplayNumber(
    _ display: CGDirectDisplayID,
    _ service: UnsafeMutablePointer<io_service_t>
)

private enum DisplayIOServiceResolver {
    static func servicePort(for displayID: CGDirectDisplayID) -> io_service_t? {
        guard displayID != 0 else { return nil }
        
        var cgsService: io_service_t = 0
        CGSServiceForDisplayNumber(displayID, &cgsService)
        if cgsService != 0 {
            return cgsService
        }
        
        return servicePortUsingDisplayPropertiesMatching(displayID: displayID)
    }
    
    private static func servicePortUsingDisplayPropertiesMatching(displayID: CGDirectDisplayID) -> io_service_t? {
        let vendorID = CGDisplayVendorNumber(displayID)
        let productID = CGDisplayModelNumber(displayID)
        let serialNumber = CGDisplaySerialNumber(displayID)
        let unitNumber = CGDisplayUnitNumber(displayID)
        
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator) == kIOReturnSuccess else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            
            if matches(
                service: service,
                vendorID: vendorID,
                productID: productID,
                serialNumber: serialNumber,
                unitNumber: unitNumber
            ) {
                return service
            }
            
            IOObjectRelease(service)
        }
        
        return nil
    }
    
    private static func matches(
        service: io_service_t,
        vendorID: UInt32,
        productID: UInt32,
        serialNumber: UInt32,
        unitNumber: UInt32
    ) -> Bool {
        let dict = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary
        
        let readUInt32: (CFString) -> UInt32 = { key in
            if let value = dict[key] as? NSNumber {
                return value.uint32Value
            }
            if let value = dict[key as String] as? NSNumber {
                return value.uint32Value
            }
            return 0
        }
        
        guard readUInt32(kDisplayVendorID as CFString) == vendorID else { return false }
        guard readUInt32(kDisplayProductID as CFString) == productID else { return false }
        
        let serviceSerial = readUInt32(kDisplaySerialNumber as CFString)
        if serialNumber != 0 && serviceSerial != 0 && serviceSerial != serialNumber {
            return false
        }
        
        if let location = dict[kIODisplayLocationKey] as? NSString ?? dict[kIODisplayLocationKey as String] as? NSString {
            let regex = try? NSRegularExpression(pattern: "@([0-9]+)[^@]+$", options: [])
            if let regex,
               let match = regex.firstMatch(in: location as String, options: [], range: NSRange(location: 0, length: location.length)),
               let range = Range(match.range(at: 1), in: location as String) {
                let locationUnit = UInt32((location as String)[range]) ?? 0
                if locationUnit != unitNumber {
                    return false
                }
            }
        }
        
        return true
    }
}

/// Manages screen brightness using dynamically loaded DisplayServices APIs
/// Uses DisplayServices framework which works on Apple Silicon Macs
final class BrightnessManager: ObservableObject {
    static let shared = BrightnessManager()
    
    private enum MediaControlTargetMode: String {
        case mainMacBook
        case activeDisplay
    }
    
    private struct BrightnessTarget {
        let displayID: CGDirectDisplayID
        let isBuiltIn: Bool
    }
    
    // MARK: - Published Properties
    @Published private(set) var rawBrightness: Float = 0.5
    @Published private(set) var lastChangeAt: Date = .distantPast
    @Published private(set) var lastChangeDisplayID: CGDirectDisplayID?
    @Published private(set) var isSupported: Bool = false
    
    // MARK: - Configuration
    let visibleDuration: TimeInterval = 1.5
    private let step: Float = 1.0 / 16.0
    
    // MARK: - DisplayServices Dynamic Loading
    private var displayServicesBundle: CFBundle?
    private var isFrameworkLoaded = false
    
    // Cached built-in display ID for brightness control
    private var mainDisplayID: CGDirectDisplayID?
    
    // External-display brightness fallback (software dimming overlay)
    private let externalHardwareController = ExternalDisplayDDCController.shared
    private let externalOverlayController = ExternalDisplayBrightnessOverlayManager.shared
    
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
    private var isPollingInProgress = false // Mutex to prevent overlapping XPC calls
    
    // Compatibility bridges:
    // when companion display apps own brightness keys, we observe changes via polling
    // and re-surface them to Droppy's HUD.
    private var cachedLunarRunning = false
    private var lastLunarRunningCheckAt: Date = .distantPast
    private let lunarRunningCheckInterval: TimeInterval = 2.0
    private var cachedBetterDisplayRunning = false
    private var lastBetterDisplayRunningCheckAt: Date = .distantPast
    private let betterDisplayRunningCheckInterval: TimeInterval = 2.0
    private let compatibilityPollingHUDDeltaThreshold: Float = 0.01
    
    // MARK: - Lazy Re-initialization (Bug #125)
    // After reboot, display detection may fail initially due to timing
    // Allow retry within a grace period after launch
    private let launchTime = Date()
    private let reInitGracePeriod: TimeInterval = 30  // 30 seconds after launch
    private var hasAttemptedReInit = false
    
    // MARK: - Initialization
    private init() {
        loadFrameworks()
        // Only target the built-in display for native brightness control.
        // In external-only mode (clamshell/desktops), brightness keys should passthrough.
        mainDisplayID = findBuiltInDisplayID()
        
        if let brightness = getCurrentBrightness() {
            rawBrightness = brightness
            lastPolledBrightness = brightness
            isSupported = true
            print("BrightnessManager: Initialized with brightness \(rawBrightness), isSupported: true")
            startBrightnessPolling()
        } else {
            print("BrightnessManager: Could not read brightness, isSupported: false (will retry within \(Int(reInitGracePeriod))s)")
            isSupported = false
        }
    }
    
    // MARK: - Lazy Re-initialization (Bug #125 Fix)
    
    /// Attempt to re-initialize brightness support if initial detection failed
    /// Called when brightness keys are pressed and isSupported is false
    func attemptReInitIfNeeded() {
        // Already supported, nothing to do
        guard !isSupported else { return }
        
        // Don't retry if we already tried once
        guard !hasAttemptedReInit else { return }
        
        // Only retry within grace period after launch (display detection timing issues)
        let timeSinceLaunch = Date().timeIntervalSince(launchTime)
        guard timeSinceLaunch < reInitGracePeriod else {
            print("BrightnessManager: Grace period expired (\(Int(timeSinceLaunch))s), not retrying")
            hasAttemptedReInit = true
            return
        }
        
        print("BrightnessManager: Attempting re-initialization (\(Int(timeSinceLaunch))s since launch)")
        hasAttemptedReInit = true
        
        // Try to find built-in display again
        mainDisplayID = findBuiltInDisplayID()
        
        // Try reading brightness
        if let brightness = getCurrentBrightness() {
            rawBrightness = brightness
            lastPolledBrightness = brightness
            isSupported = true
            print("BrightnessManager: Re-initialization SUCCESS - brightness \(rawBrightness)")
            startBrightnessPolling()
        } else {
            print("BrightnessManager: Re-initialization failed")
        }
    }
    
    /// Find the built-in (laptop) display ID for brightness control
    private func findBuiltInDisplayID() -> CGDirectDisplayID? {
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success else { return nil }
        guard displayCount > 0 else { return nil }
        
        var displayIDs = Array(repeating: CGDirectDisplayID(), count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displayIDs, &displayCount) == .success else { return nil }
        
        if let builtInID = displayIDs.prefix(Int(displayCount)).first(where: { CGDisplayIsBuiltin($0) != 0 }) {
            print("BrightnessManager: Found built-in display ID: \(builtInID)")
            return builtInID
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
    
    private var mediaControlTargetMode: MediaControlTargetMode {
        let raw = UserDefaults.standard.string(forKey: AppPreferenceKey.mediaControlTargetMode)
            ?? PreferenceDefault.mediaControlTargetMode
        return MediaControlTargetMode(rawValue: raw) ?? .mainMacBook
    }
    
    /// Returns true when a built-in display is currently online.
    /// In clamshell/external-only mode this becomes false.
    var hasOnlineBuiltInDisplay: Bool {
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success else { return false }
        guard displayCount > 0 else { return false }
        
        var displayIDs = Array(repeating: CGDirectDisplayID(), count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displayIDs, &displayCount) == .success else { return false }
        
        return displayIDs.prefix(Int(displayCount)).contains { CGDisplayIsBuiltin($0) != 0 }
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
    
    /// Returns whether Droppy can control brightness for the requested target screen.
    /// External displays are supported via native hardware backends first,
    /// with software dimming as a final fallback.
    func canHandleBrightness(on screenHint: NSScreen? = nil) -> Bool {
        guard let target = resolveBrightnessTarget(screenHint: screenHint) else { return false }
        
        if target.isBuiltIn {
            attemptReInitIfNeeded()
            return getBuiltInBrightness(displayID: target.displayID) != nil
        }
        
        if externalHardwareController.canControl(displayID: target.displayID) {
            return true
        }
        
        return true
    }
    
    /// When BetterDisplay compatibility is active, let BetterDisplay/system handle
    /// brightness-key input and rely on polling to mirror values into Droppy's HUD.
    func shouldPassthroughBrightnessKeyToSystem(on screenHint: NSScreen? = nil) -> Bool {
        guard isBetterDisplayCompatibilityEnabled else { return false }
        guard isBetterDisplayRunning() else { return false }
        
        // If Droppy can't resolve this target at all, passthrough is still safest.
        // This avoids intercepting keys Droppy may not be able to apply reliably.
        guard resolveBrightnessTarget(screenHint: screenHint) != nil else { return true }
        return true
    }
    
    /// Increase brightness by one step
    func increase(stepDivisor: Float = 1.0, screenHint: NSScreen? = nil) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / divisor
        guard let targetDisplay = resolveBrightnessTarget(screenHint: screenHint) else { return }
        let current = getCurrentBrightness(for: targetDisplay) ?? rawBrightness
        let target = max(0, min(1, current + delta))
        setAbsolute(value: target, screenHint: screenHint)
    }
    
    /// Decrease brightness by one step
    func decrease(stepDivisor: Float = 1.0, screenHint: NSScreen? = nil) {
        let divisor = max(stepDivisor, 0.25)
        let delta = step / divisor
        guard let targetDisplay = resolveBrightnessTarget(screenHint: screenHint) else { return }
        let current = getCurrentBrightness(for: targetDisplay) ?? rawBrightness
        let target = max(0, min(1, current - delta))
        setAbsolute(value: target, screenHint: screenHint)
    }
    
    /// Refresh brightness from system
    func refresh(screenHint: NSScreen? = nil) {
        guard let targetDisplay = resolveBrightnessTarget(screenHint: screenHint) else { return }
        if let brightness = getCurrentBrightness(for: targetDisplay) {
            publish(brightness: brightness, touchDate: false, displayID: targetDisplay.displayID)
        }
    }
    
    /// Set brightness to absolute value (0.0 - 1.0)
    func setAbsolute(value: Float, screenHint: NSScreen? = nil) {
        let clamped = max(0, min(1, value))
        guard let targetDisplay = resolveBrightnessTarget(screenHint: screenHint) else { return }
        if setBrightness(clamped, for: targetDisplay) {
            // Read back after write so HUD reflects actual applied brightness,
            // not just the requested value.
            let effective = getCurrentBrightness(for: targetDisplay) ?? clamped
            lastPolledBrightness = effective
            publish(brightness: effective, touchDate: true, displayID: targetDisplay.displayID)
        } else {
            refresh(screenHint: screenHint)
        }
    }
    
    // MARK: - Private Brightness Helpers
    
    private func getCurrentBrightness() -> Float? {
        guard let displayID = mainDisplayID else { return nil }
        return getBuiltInBrightness(displayID: displayID)
    }
    
    private func getCurrentBrightness(for target: BrightnessTarget) -> Float? {
        if target.isBuiltIn {
            return getBuiltInBrightness(displayID: target.displayID)
        }
        if let hardwareBrightness = externalHardwareController.brightness(displayID: target.displayID) {
            return hardwareBrightness
        }
        return externalOverlayController.brightness(for: target.displayID)
    }
    
    private func getBuiltInBrightness(displayID: CGDirectDisplayID) -> Float? {
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
        return setBuiltInBrightness(value, displayID: displayID)
    }
    
    private func setBrightness(_ value: Float, for target: BrightnessTarget) -> Bool {
        if target.isBuiltIn {
            return setBuiltInBrightness(value, displayID: target.displayID)
        }
        
        if externalHardwareController.setBrightness(value, displayID: target.displayID) {
            externalOverlayController.clearOverride(for: target.displayID)
            return true
        }
        
        externalOverlayController.setBrightness(value, for: target.displayID)
        return true
    }
    
    private func setBuiltInBrightness(_ value: Float, displayID: CGDirectDisplayID) -> Bool {
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
    
    private func resolveBrightnessTarget(screenHint: NSScreen? = nil) -> BrightnessTarget? {
        switch mediaControlTargetMode {
        case .mainMacBook:
            if mainDisplayID == nil || (mainDisplayID != nil && CGDisplayIsBuiltin(mainDisplayID!) == 0) {
                mainDisplayID = findBuiltInDisplayID()
            }
            guard let builtInID = mainDisplayID else { return nil }
            return BrightnessTarget(displayID: builtInID, isBuiltIn: true)
            
        case .activeDisplay:
            let resolvedScreen = screenHint
                ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.main
                ?? NSScreen.screens.first
            
            guard let resolvedScreen else { return nil }
            let isBuiltInTarget = resolvedScreen.isBuiltIn
            
            if isBuiltInTarget {
                mainDisplayID = resolvedScreen.displayID
            }
            
            return BrightnessTarget(displayID: resolvedScreen.displayID, isBuiltIn: isBuiltInTarget)
        }
    }
    
    private func publish(brightness: Float, touchDate: Bool, displayID: CGDirectDisplayID?) {
        DispatchQueue.main.async {
            if self.rawBrightness != brightness || touchDate {
                if touchDate {
                    self.lastChangeAt = Date()
                    self.lastChangeDisplayID = displayID
                }
                self.rawBrightness = brightness
            }
        }
    }
    
    private func isLunarRunning() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastLunarRunningCheckAt) < lunarRunningCheckInterval {
            return cachedLunarRunning
        }
        
        let knownBundleIDs: Set<String> = [
            "fyi.lunar.Lunar",
            "fyi.lunar"
        ]
        
        cachedLunarRunning = NSWorkspace.shared.runningApplications.contains { app in
            if app.isTerminated { return false }
            
            if let bundleID = app.bundleIdentifier, knownBundleIDs.contains(bundleID) {
                return true
            }
            
            if let localizedName = app.localizedName?.lowercased(), localizedName.contains("lunar") {
                return true
            }
            
            return false
        }
        lastLunarRunningCheckAt = now
        return cachedLunarRunning
    }
    
    private var isBetterDisplayCompatibilityEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.enableBetterDisplayCompatibility,
            default: PreferenceDefault.enableBetterDisplayCompatibility
        )
    }
    
    private func isBetterDisplayRunning() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastBetterDisplayRunningCheckAt) < betterDisplayRunningCheckInterval {
            return cachedBetterDisplayRunning
        }
        
        // BetterDisplay bundle identifiers can vary by release lineage,
        // so we support exact IDs and resilient partial matching.
        let knownBundleIDs: Set<String> = [
            "com.betterdisplay.BetterDisplay",
            "pro.betterdisplay.BetterDisplay",
            "org.BetterDisplay.BetterDisplay"
        ]
        
        cachedBetterDisplayRunning = NSWorkspace.shared.runningApplications.contains { app in
            if app.isTerminated { return false }
            
            if let bundleID = app.bundleIdentifier {
                let normalized = bundleID.lowercased()
                if knownBundleIDs.contains(bundleID) || normalized.contains("betterdisplay") {
                    return true
                }
            }
            
            if let localizedName = app.localizedName?.lowercased(),
               localizedName.contains("betterdisplay") {
                return true
            }
            
            return false
        }
        lastBetterDisplayRunningCheckAt = now
        return cachedBetterDisplayRunning
    }
    
    private func resolvePolledBrightnessSample() -> (brightness: Float, displayID: CGDirectDisplayID?)? {
        if isBetterDisplayCompatibilityEnabled,
           isBetterDisplayRunning(),
           let target = resolveBrightnessTarget() {
            if target.isBuiltIn {
                if let builtInBrightness = getBuiltInBrightness(displayID: target.displayID) {
                    return (brightness: builtInBrightness, displayID: target.displayID)
                }
            } else if externalHardwareController.canControl(displayID: target.displayID),
                      let externalBrightness = externalHardwareController.brightness(displayID: target.displayID) {
                return (brightness: externalBrightness, displayID: target.displayID)
            }
        }
        
        if let current = getCurrentBrightness() {
            return (brightness: current, displayID: mainDisplayID)
        }
        
        return nil
    }
    
    private func shouldBridgePolledDeltaToHUD(delta: Float) -> Bool {
        guard delta >= compatibilityPollingHUDDeltaThreshold else { return false }
        
        if isLunarRunning() {
            return true
        }
        
        if isBetterDisplayCompatibilityEnabled && isBetterDisplayRunning() {
            return true
        }
        
        return false
    }
    
    // MARK: - Brightness Polling
    
    private func startBrightnessPolling() {
        guard isSupported else { return }
        
        print("BrightnessManager: Starting brightness polling (silent by default, compatibility bridge enabled)")
        // CRITICAL: Poll on main thread to avoid XPC/DisplayServices thread safety crashes
        // DisplayServicesGetBrightness makes XPC calls that are not thread-safe
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.5, repeating: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            autoreleasepool {
                guard let self = self else { return }
                
                // Mutex: skip if previous poll still in progress (XPC safety)
                guard !self.isPollingInProgress else { return }
                self.isPollingInProgress = true
                defer { self.isPollingInProgress = false }
                
                if let sample = self.resolvePolledBrightnessSample() {
                    let current = sample.brightness
                    self.pollFailCount = 0
                    let delta = abs(current - self.lastPolledBrightness)
                    if delta > 0.001 {
                        // Keep polling silent in normal mode to avoid ambient auto-brightness noise.
                        // Companion apps can own brightness keys, so we bridge polled deltas
                        // back into Droppy's HUD updates.
                        if self.shouldBridgePolledDeltaToHUD(delta: delta) {
                            self.publish(brightness: current, touchDate: true, displayID: sample.displayID)
                        } else {
                            self.rawBrightness = current
                        }
                        self.lastPolledBrightness = current
                    }
                } else {
                    // Stop polling if we get too many failures
                    self.pollFailCount += 1
                    if self.pollFailCount > 10 {
                        print("BrightnessManager: Too many poll failures, stopping")
                        self.pollTimer?.cancel()
                        self.isSupported = false
                    }
                }
            }
        }
        timer.resume()
        pollTimer = timer
    }
}

private protocol ExternalBrightnessTransport: AnyObject {
    func isSupported() -> Bool
    func readNormalizedBrightness() -> Float?
    func writeNormalizedBrightness(_ value: Float) -> Bool
}

/// Hardware brightness controller for external displays.
/// Priority order:
/// 1) IODisplay float parameter (native API, some displays expose it)
/// 2) Classic IOI2C DDC/CI transaction path
/// 3) Apple Silicon IOAVService DDC/CI path
private final class ExternalDisplayDDCController: NSObject {
    static let shared = ExternalDisplayDDCController()
    
    private var transports: [CGDirectDisplayID: ExternalBrightnessTransport] = [:]
    private let lock = NSLock()
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func canControl(displayID: CGDirectDisplayID) -> Bool {
        guard let transport = transport(for: displayID) else { return false }
        return transport.isSupported()
    }
    
    func brightness(displayID: CGDirectDisplayID) -> Float? {
        guard let transport = transport(for: displayID) else { return nil }
        return transport.readNormalizedBrightness()
    }
    
    func setBrightness(_ value: Float, displayID: CGDirectDisplayID) -> Bool {
        guard let transport = transport(for: displayID) else { return false }
        return transport.writeNormalizedBrightness(value)
    }
    
    @objc private func handleScreenParametersChanged() {
        let activeDisplayIDs = Set(NSScreen.screens.map { $0.displayID })
        lock.lock()
        transports = transports.filter { activeDisplayIDs.contains($0.key) }
        lock.unlock()
    }
    
    private func transport(for displayID: CGDirectDisplayID) -> ExternalBrightnessTransport? {
        guard displayID != 0 else { return nil }
        guard CGDisplayIsBuiltin(displayID) == 0 else { return nil }
        
        lock.lock()
        if let existing = transports[displayID] {
            lock.unlock()
            return existing
        }
        lock.unlock()
        
        guard let discovered = discoverTransport(for: displayID) else {
            return nil
        }
        
        lock.lock()
        transports[displayID] = discovered
        lock.unlock()
        return discovered
    }
    
    private func discoverTransport(for displayID: CGDirectDisplayID) -> ExternalBrightnessTransport? {
        let framebuffer = DisplayIOServiceResolver.servicePort(for: displayID) ?? 0
        
        if framebuffer != 0 {
            let ioDisplayTransport = IODisplayBrightnessTransport(service: framebuffer)
            if ioDisplayTransport.isSupported() {
                return ioDisplayTransport
            }
            
            let i2cTransport = IntelI2CDDCCBrightnessTransport(framebuffer: framebuffer)
            if i2cTransport.isSupported() {
                return i2cTransport
            }
        }
        
        if let avTransport = Arm64AVDDCCBrightnessTransport(displayID: displayID),
           avTransport.isSupported() {
            return avTransport
        }
        
        return nil
    }
}

private final class IODisplayBrightnessTransport: ExternalBrightnessTransport {
    private let service: io_service_t
    private let brightnessKey: CFString = "brightness" as CFString
    
    init(service: io_service_t) {
        self.service = service
    }
    
    func isSupported() -> Bool {
        readNormalizedBrightness() != nil
    }
    
    func readNormalizedBrightness() -> Float? {
        var value: Float = 0
        guard IODisplayGetFloatParameter(service, 0, brightnessKey, &value) == kIOReturnSuccess else {
            return nil
        }
        return max(0, min(1, value))
    }
    
    func writeNormalizedBrightness(_ value: Float) -> Bool {
        let clamped = max(0, min(1, value))
        guard IODisplaySetFloatParameter(service, 0, brightnessKey, clamped) == kIOReturnSuccess else {
            return false
        }
        _ = IODisplayCommitParameters(service, 0)
        return true
    }
}

private final class IntelI2CDDCCBrightnessTransport: ExternalBrightnessTransport {
    private static let vcpBrightness: UInt8 = 0x10
    private static let writeAddress: UInt32 = 0x6E
    private static let readAddress: UInt32 = 0x6F
    private static let replySubAddress: UInt8 = 0x51
    private static let readRetries = 3
    private static let writeCycles = 2
    private static let writeSleep: useconds_t = 10000
    
    private let framebuffer: io_service_t
    private var cachedMaxValue: UInt16 = 100
    private var lastKnownCurrentValue: UInt16 = 100
    
    init(framebuffer: io_service_t) {
        self.framebuffer = framebuffer
    }
    
    func isSupported() -> Bool {
        readBrightnessRaw() != nil
    }
    
    func readNormalizedBrightness() -> Float? {
        if let values = readBrightnessRaw() {
            cachedMaxValue = max(1, values.max)
            lastKnownCurrentValue = min(values.current, cachedMaxValue)
            return normalize(lastKnownCurrentValue, maximum: cachedMaxValue)
        }

        // Returning stale cached brightness here can desync HUD from actual display state.
        // Prefer a temporary nil sample and wait for the next successful hardware read.
        return nil
    }
    
    func writeNormalizedBrightness(_ value: Float) -> Bool {
        let clamped = max(0, min(1, value))
        
        if let values = readBrightnessRaw() {
            cachedMaxValue = max(1, values.max)
            lastKnownCurrentValue = min(values.current, cachedMaxValue)
        }
        
        let target = UInt16(round(Float(cachedMaxValue) * clamped))
        let didWrite = writeBrightnessRaw(target, maxValue: cachedMaxValue)
        if didWrite {
            lastKnownCurrentValue = target
        }
        return didWrite
    }
    
    private func normalize(_ current: UInt16, maximum: UInt16) -> Float {
        guard maximum > 0 else { return 0 }
        return Swift.max(0, Swift.min(1, Float(current) / Float(maximum)))
    }
    
    private func readBrightnessRaw() -> (current: UInt16, max: UInt16)? {
        var requestData: [UInt8] = [0x51, 0x82, 0x01, Self.vcpBrightness, 0]
        requestData[4] = checksum(seed: UInt8(Self.writeAddress), data: requestData, upTo: 3)
        
        for transactionType in [IOOptionBits(kIOI2CDDCciReplyTransactionType), IOOptionBits(kIOI2CSimpleTransactionType)] {
            for _ in 0..<Self.readRetries {
                usleep(Self.writeSleep)
                
                var replyData = Array<UInt8>(repeating: 0, count: 11)
                var request = IOI2CRequest()
                request.commFlags = 0
                request.sendAddress = Self.writeAddress
                request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
                request.sendBuffer = withUnsafeMutablePointer(to: &requestData[0]) { vm_address_t(bitPattern: $0) }
                request.sendBytes = UInt32(requestData.count)
                request.minReplyDelay = 10
                request.replyAddress = Self.readAddress
                request.replySubAddress = Self.replySubAddress
                request.replyTransactionType = transactionType
                request.replyBytes = UInt32(replyData.count)
                request.replyBuffer = withUnsafeMutablePointer(to: &replyData[0]) { vm_address_t(bitPattern: $0) }
                
                guard Self.send(request: &request, framebuffer: framebuffer) else { continue }
                guard validate(reply: replyData) else { continue }
                
                let maxValue = (UInt16(replyData[6]) << 8) | UInt16(replyData[7])
                let currentValue = (UInt16(replyData[8]) << 8) | UInt16(replyData[9])
                guard maxValue > 0 else { continue }
                return (current: currentValue, max: maxValue)
            }
        }
        
        return nil
    }
    
    private func writeBrightnessRaw(_ current: UInt16, maxValue: UInt16) -> Bool {
        let value = min(current, maxValue)
        var data: [UInt8] = [
            0x51,
            0x84,
            0x03,
            Self.vcpBrightness,
            UInt8(value >> 8),
            UInt8(value & 0xFF),
            0
        ]
        data[6] = checksum(seed: UInt8(Self.writeAddress), data: data, upTo: 5)
        
        var wroteOnce = false
        for _ in 0..<Self.writeCycles {
            usleep(Self.writeSleep)
            
            var request = IOI2CRequest()
            request.commFlags = 0
            request.sendAddress = Self.writeAddress
            request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
            request.sendBuffer = withUnsafeMutablePointer(to: &data[0]) { vm_address_t(bitPattern: $0) }
            request.sendBytes = UInt32(data.count)
            request.replyTransactionType = IOOptionBits(kIOI2CNoTransactionType)
            request.replyBytes = 0
            
            if Self.send(request: &request, framebuffer: framebuffer) {
                wroteOnce = true
            }
        }
        
        return wroteOnce
    }
    
    private func validate(reply: [UInt8]) -> Bool {
        guard reply.count >= 11 else { return false }
        guard reply[2] == 0x02 else { return false }
        guard reply[3] == 0x00 else { return false }
        
        var calculatedChecksum: UInt8 = 0x50
        for i in 0..<10 {
            calculatedChecksum ^= reply[i]
        }
        return calculatedChecksum == reply[10]
    }
    
    private func checksum(seed: UInt8, data: [UInt8], upTo: Int) -> UInt8 {
        guard !data.isEmpty else { return seed }
        var value = seed
        for index in 0...upTo {
            value ^= data[index]
        }
        return value
    }
    
    private static func send(request: inout IOI2CRequest, framebuffer: io_service_t) -> Bool {
        var busCount: IOItemCount = 0
        guard IOFBGetI2CInterfaceCount(framebuffer, &busCount) == kIOReturnSuccess else { return false }
        
        for bus in 0..<busCount {
            var interface: io_service_t = 0
            guard IOFBCopyI2CInterfaceForBus(framebuffer, IOOptionBits(bus), &interface) == kIOReturnSuccess else {
                continue
            }
            defer { IOObjectRelease(interface) }
            
            var connect: IOI2CConnectRef?
            guard IOI2CInterfaceOpen(interface, 0, &connect) == kIOReturnSuccess,
                  let openedConnect = connect else {
                continue
            }
            defer { _ = IOI2CInterfaceClose(openedConnect, 0) }
            
            guard IOI2CSendRequest(openedConnect, 0, &request) == kIOReturnSuccess else { continue }
            guard request.result == kIOReturnSuccess else { continue }
            return true
        }
        
        return false
    }
}

private final class Arm64AVDDCCBrightnessTransport: ExternalBrightnessTransport {
    private static let ddcChipAddress: UInt8 = 0x37
    private static let ddcDataAddress: UInt8 = 0x51
    private static let brightnessVCP: UInt8 = 0x10
    private static let readReplyLength = 11
    private static let writeSleep: useconds_t = 10000
    private static let readSleep: useconds_t = 50000
    private static let retrySleep: useconds_t = 20000
    private static let retries = 4
    private static let writeCycles = 2
    
    private let service: IOAVServiceRef
    private var cachedMaxValue: UInt16 = 100
    private var lastKnownCurrentValue: UInt16 = 100
    
    init?(displayID: CGDirectDisplayID) {
        guard let service = Self.createService(displayID: displayID) else { return nil }
        self.service = service
    }
    
    func isSupported() -> Bool {
        readBrightnessRaw() != nil
    }
    
    func readNormalizedBrightness() -> Float? {
        if let values = readBrightnessRaw() {
            cachedMaxValue = max(1, values.max)
            lastKnownCurrentValue = min(values.current, cachedMaxValue)
            return normalize(lastKnownCurrentValue, maximum: cachedMaxValue)
        }

        // Returning stale cached brightness here can desync HUD from actual display state.
        // Prefer a temporary nil sample and wait for the next successful hardware read.
        return nil
    }
    
    func writeNormalizedBrightness(_ value: Float) -> Bool {
        let clamped = max(0, min(1, value))
        
        if let values = readBrightnessRaw() {
            cachedMaxValue = max(1, values.max)
            lastKnownCurrentValue = min(values.current, cachedMaxValue)
        }
        
        let target = UInt16(round(Float(cachedMaxValue) * clamped))
        let didWrite = writeBrightnessRaw(target, maxValue: cachedMaxValue)
        if didWrite {
            lastKnownCurrentValue = target
        }
        return didWrite
    }
    
    private func normalize(_ current: UInt16, maximum: UInt16) -> Float {
        guard maximum > 0 else { return 0 }
        return Swift.max(0, Swift.min(1, Float(current) / Float(maximum)))
    }
    
    private func readBrightnessRaw() -> (current: UInt16, max: UInt16)? {
        var reply = Array<UInt8>(repeating: 0, count: Self.readReplyLength)
        
        for _ in 0..<Self.retries {
            var readCommandPacket = Self.makePacket(sendData: [Self.brightnessVCP])
            let writeResult = readCommandPacket.withUnsafeMutableBytes { bytes -> IOReturn in
                IOAVServiceWriteI2C(
                    service,
                    UInt32(Self.ddcChipAddress),
                    UInt32(Self.ddcDataAddress),
                    bytes.baseAddress,
                    UInt32(bytes.count)
                )
            }
            guard writeResult == kIOReturnSuccess else {
                usleep(Self.retrySleep)
                continue
            }
            
            usleep(Self.readSleep)
            let readResult = reply.withUnsafeMutableBytes { bytes -> IOReturn in
                IOAVServiceReadI2C(
                    service,
                    UInt32(Self.ddcChipAddress),
                    0,
                    bytes.baseAddress,
                    UInt32(bytes.count)
                )
            }
            guard readResult == kIOReturnSuccess else {
                usleep(Self.retrySleep)
                continue
            }
            guard validate(reply: reply) else {
                usleep(Self.retrySleep)
                continue
            }
            
            let maxValue = (UInt16(reply[6]) << 8) | UInt16(reply[7])
            let currentValue = (UInt16(reply[8]) << 8) | UInt16(reply[9])
            guard maxValue > 0 else {
                usleep(Self.retrySleep)
                continue
            }
            
            return (current: currentValue, max: maxValue)
        }
        
        return nil
    }
    
    private func writeBrightnessRaw(_ current: UInt16, maxValue: UInt16) -> Bool {
        let value = min(current, maxValue)
        let payload: [UInt8] = [Self.brightnessVCP, UInt8(value >> 8), UInt8(value & 0xFF)]
        
        for _ in 0..<Self.retries {
            var wroteAny = false
            for _ in 0..<Self.writeCycles {
                usleep(Self.writeSleep)
                var packet = Self.makePacket(sendData: payload)
                let result = packet.withUnsafeMutableBytes { bytes -> IOReturn in
                    IOAVServiceWriteI2C(
                        service,
                        UInt32(Self.ddcChipAddress),
                        UInt32(Self.ddcDataAddress),
                        bytes.baseAddress,
                        UInt32(bytes.count)
                    )
                }
                if result == kIOReturnSuccess {
                    wroteAny = true
                }
            }
            
            if wroteAny {
                return true
            }
            
            usleep(Self.retrySleep)
        }
        
        return false
    }
    
    private static func makePacket(sendData: [UInt8]) -> [UInt8] {
        var packet: [UInt8] = [UInt8(0x80 | (sendData.count + 1)), UInt8(sendData.count)]
        packet.append(contentsOf: sendData)
        packet.append(0)
        
        let seed: UInt8 = sendData.count == 1
            ? (ddcChipAddress << 1)
            : ((ddcChipAddress << 1) ^ ddcDataAddress)
        packet[packet.count - 1] = checksum(seed: seed, data: packet, upTo: packet.count - 2)
        return packet
    }
    
    private static func checksum(seed: UInt8, data: [UInt8], upTo: Int) -> UInt8 {
        guard !data.isEmpty else { return seed }
        var value = seed
        for i in 0...upTo {
            value ^= data[i]
        }
        return value
    }
    
    private func validate(reply: [UInt8]) -> Bool {
        guard reply.count >= Self.readReplyLength else { return false }
        guard reply[2] == 0x02 else { return false }
        guard reply[3] == 0x00 else { return false }
        
        let expected = Self.checksum(seed: 0x50, data: reply, upTo: reply.count - 2)
        return expected == reply[reply.count - 1]
    }
    
    private static func createService(displayID: CGDirectDisplayID) -> IOAVServiceRef? {
        var cgsService: io_service_t = 0
        CGSServiceForDisplayNumber(displayID, &cgsService)
        
        if cgsService != 0,
           let avService = IOAVServiceCreateWithService(kCFAllocatorDefault, cgsService)?.takeRetainedValue() {
            return avService
        }
        
        guard let framebuffer = DisplayIOServiceResolver.servicePort(for: displayID),
              framebuffer != 0,
              let avService = IOAVServiceCreateWithService(kCFAllocatorDefault, framebuffer)?.takeRetainedValue() else {
            return nil
        }
        
        return avService
    }
}

/// Software-dimming fallback for external displays.
/// This gives Droppy native external brightness behavior even when hardware DDC is unavailable.
private final class ExternalDisplayBrightnessOverlayManager: NSObject {
    static let shared = ExternalDisplayBrightnessOverlayManager()
    
    private var overlayWindows: [CGDirectDisplayID: NSWindow] = [:]
    private var brightnessValues: [CGDirectDisplayID: Float] = [:]
    private let maxDimAlpha: CGFloat = 0.88
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        for (_, window) in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
    }
    
    func brightness(for displayID: CGDirectDisplayID) -> Float {
        brightnessValues[displayID] ?? 1.0
    }
    
    func setBrightness(_ value: Float, for displayID: CGDirectDisplayID) {
        let clamped = max(0, min(1, value))
        brightnessValues[displayID] = clamped
        DispatchQueue.main.async { [weak self] in
            self?.applyBrightness(clamped, to: displayID)
        }
    }
    
    func clearOverride(for displayID: CGDirectDisplayID) {
        brightnessValues.removeValue(forKey: displayID)
        DispatchQueue.main.async { [weak self] in
            self?.removeOverlay(for: displayID)
        }
    }
    
    @objc private func handleScreenParametersChanged() {
        reconcileConnectedDisplays()
    }
    
    private func reconcileConnectedDisplays() {
        DispatchQueue.main.async {
            let connectedDisplayIDs = Set(NSScreen.screens.map { $0.displayID })
            
            for displayID in self.overlayWindows.keys where !connectedDisplayIDs.contains(displayID) {
                self.removeOverlay(for: displayID)
            }
            
            for displayID in self.brightnessValues.keys where !connectedDisplayIDs.contains(displayID) {
                self.brightnessValues.removeValue(forKey: displayID)
            }
            
            for (displayID, brightness) in self.brightnessValues {
                self.applyBrightness(brightness, to: displayID)
            }
        }
    }
    
    private func applyBrightness(_ brightness: Float, to displayID: CGDirectDisplayID) {
        guard let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else {
            removeOverlay(for: displayID)
            return
        }
        
        let alpha = overlayAlpha(for: brightness)
        if alpha <= 0.001 {
            removeOverlay(for: displayID)
            return
        }
        
        let window = ensureOverlayWindow(for: displayID, screen: screen)
        window.setFrame(screen.frame, display: true)
        window.backgroundColor = NSColor.black.withAlphaComponent(alpha)
        window.orderFrontRegardless()
    }
    
    private func ensureOverlayWindow(for displayID: CGDirectDisplayID, screen: NSScreen) -> NSWindow {
        if let existing = overlayWindows[displayID] {
            return existing
        }
        
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.orderOut(nil)
        
        overlayWindows[displayID] = window
        return window
    }
    
    private func removeOverlay(for displayID: CGDirectDisplayID) {
        guard let window = overlayWindows.removeValue(forKey: displayID) else { return }
        window.orderOut(nil)
        window.close()
    }
    
    private func overlayAlpha(for brightness: Float) -> CGFloat {
        let clamped = max(0, min(1, brightness))
        let inverse = 1.0 - CGFloat(clamped)
        return pow(inverse, 0.8) * maxDimAlpha
    }
}
