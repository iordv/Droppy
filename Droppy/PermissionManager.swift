//
//  PermissionManager.swift
//  Droppy
//
//  Centralized permission checking with persistent caching & polling
//
//  Strategy:
//  1. Trust TCC API if it says YES - always update cache
//  2. If TCC says NO, trust persistent cache (user granted before, TCC is slow)
//  3. Poll aggressively on activation to detect new grants immediately
//
//  Note: The cache persists across app updates because TCC permissions are
//  tied to bundle identifier. This prevents "Permission Needed" errors
//  when TCC is slow to sync on app launch or after updates.
//

import Foundation
import AppKit
import Combine

/// Centralized permission manager with persistent caching
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    enum AccessibilityPromptContext {
        case automatic
        case userInitiated
    }
    
    // MARK: - Cache Keys
    private let accessibilityGrantedKey = "accessibilityGranted"
    private let screenRecordingGrantedKey = "screenRecordingGranted"
    private let inputMonitoringGrantedKey = "inputMonitoringGranted"
    
    // Polling timer for detecting permission changes
    private var pollingTimer: Timer?
    
    // Track if we've already prompted this session (prevent duplicate prompts)
    private var hasPromptedAccessibility = false
    private var hasPromptedScreenRecording = false
    
    // MARK: - TCC Race Condition Fix (Issue: prompts on every reboot)
    // After macOS reboots, TCC can take 10-15s to report correct permission status
    // During this grace period, we trust the cached permission value unconditionally
    private let launchTime = Date()
    private let tccGracePeriod: TimeInterval = 15.0
    
    // Track last prompt time to avoid prompting twice in same boot cycle
    private let lastAccessibilityPromptBootTimeKey = "lastAccessibilityPromptBootTime"
    private let lastScreenRecordingPromptBootTimeKey = "lastScreenRecordingPromptBootTime"
    private let lastAccessibilityPromptDateKey = "lastAccessibilityPromptDate"
    private let accessibilityAutoPromptCooldown: TimeInterval = 60 * 60 * 24 // 24h
    private let earlyBootPromptSuppression: TimeInterval = 90 // seconds
    
    private init() {
        print("🔐 PermissionManager: Initialized")
        printFullStatus()
    }
    
    // MARK: - Debug Logging
    
    /// Print comprehensive permission status
    func printFullStatus() {
        print("🔐 ========== PERMISSION STATUS ==========")
        
        // Accessibility
        let axTrusted = AXIsProcessTrusted()
        let axCache = UserDefaults.standard.bool(forKey: accessibilityGrantedKey)
        print("🔐 ACCESSIBILITY:")
        print("🔐   AXIsProcessTrusted() = \(axTrusted)")
        print("🔐   Cache = \(axCache)")
        print("🔐   isAccessibilityGranted = \(isAccessibilityGranted)")
        
        // Screen Recording
        let srGranted = CGPreflightScreenCaptureAccess()
        let srCache = UserDefaults.standard.bool(forKey: screenRecordingGrantedKey)
        print("🔐 SCREEN RECORDING:")
        print("🔐   CGPreflightScreenCaptureAccess() = \(srGranted)")
        print("🔐   Cache = \(srCache)")
        print("🔐   isScreenRecordingGranted = \(isScreenRecordingGranted)")
        
        // Input Monitoring
        let imCache = UserDefaults.standard.bool(forKey: inputMonitoringGrantedKey)
        print("🔐 INPUT MONITORING:")
        print("🔐   Cache = \(imCache)")
        print("🔐   (Runtime check done via GlobalHotKey)")
        
        print("🔐 =========================================")
    }
    
    // MARK: - Accessibility
    
    /// Check if accessibility permission is granted
    /// Uses TCC as source of truth, with persistent cache fallback
    var isAccessibilityGranted: Bool {
        let trusted = AXIsProcessTrusted()
        
        if trusted {
            // TCC confirms permission - update cache and notify observers
            if !UserDefaults.standard.bool(forKey: accessibilityGrantedKey) {
                UserDefaults.standard.set(true, forKey: accessibilityGrantedKey)
                DispatchQueue.main.async { self.objectWillChange.send() }
                print("🔐 PermissionManager: Accessibility granted! (TCC confirmed, cache updated)")
            }
            return true
        }
        
        // TCC says NOT trusted - check cache with grace period logic
        let cacheValue = UserDefaults.standard.bool(forKey: accessibilityGrantedKey)
        
        // During grace period after launch, trust cache unconditionally
        // This handles macOS TCC delay after reboot (can take 10-15s to sync)
        let timeSinceLaunch = Date().timeIntervalSince(launchTime)
        if timeSinceLaunch < tccGracePeriod && cacheValue {
            print("🔐 PermissionManager: In TCC grace period (\(String(format: "%.1f", timeSinceLaunch))s), trusting cache")
            return true
        }
        
        // After grace period, still trust cache but log normally
        if cacheValue {
            print("🔐 PermissionManager: Accessibility - TCC=false but cache=true (trusting cache)")
        }
        return cacheValue
    }
    
    /// Request accessibility permission and start polling
    func requestAccessibility(context: AccessibilityPromptContext = .automatic) {
        // Fast path: if trust is now available, persist and skip prompting.
        if AXIsProcessTrusted() {
            if !UserDefaults.standard.bool(forKey: accessibilityGrantedKey) {
                UserDefaults.standard.set(true, forKey: accessibilityGrantedKey)
            }
            print("🔐 PermissionManager: Accessibility already trusted, skipping prompt")
            return
        }
        
        if context == .automatic {
            let hasPromptHistory = UserDefaults.standard.object(forKey: lastAccessibilityPromptDateKey) as? Date != nil
            
            // Avoid showing the system prompt repeatedly from startup flows.
            if let lastPromptDate = UserDefaults.standard.object(forKey: lastAccessibilityPromptDateKey) as? Date,
               Date().timeIntervalSince(lastPromptDate) < accessibilityAutoPromptCooldown {
                print("🔐 PermissionManager: Skipping automatic accessibility prompt (cooldown active)")
                startPollingForAccessibility()
                return
            }
            
            // After reboot, TCC can lag. Suppress auto-prompts briefly to avoid false prompts.
            if let bootTime = getSystemBootTime(),
               Date().timeIntervalSince(bootTime) < earlyBootPromptSuppression,
               hasPromptHistory {
                print("🔐 PermissionManager: Skipping automatic accessibility prompt (early boot TCC suppression)")
                startPollingForAccessibility()
                return
            }
        }
        
        // Prevent duplicate prompts in same session
        if hasPromptedAccessibility {
            print("🔐 PermissionManager: Skipping accessibility prompt (already prompted this session)")
            return
        }
        
        // Prevent duplicate prompts in same boot cycle
        // This handles the case where app quits and relaunches quickly after reboot
        if let lastPromptTime = UserDefaults.standard.object(forKey: lastAccessibilityPromptBootTimeKey) as? Date,
           let bootTime = getSystemBootTime(),
           lastPromptTime > bootTime {
            print("🔐 PermissionManager: Skipping accessibility prompt (already prompted this boot cycle)")
            hasPromptedAccessibility = true // Prevent further prompts this session
            return
        }
        
        hasPromptedAccessibility = true
        let now = Date()
        UserDefaults.standard.set(now, forKey: lastAccessibilityPromptBootTimeKey)
        UserDefaults.standard.set(now, forKey: lastAccessibilityPromptDateKey)
        
        print("🔐 PermissionManager: Requesting accessibility permission (showing macOS dialog)…")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        // Start polling immediately in case user grants it quickly
        startPollingForAccessibility()
    }
    
    /// Get the system boot time for boot-cycle tracking
    private func getSystemBootTime() -> Date? {
        var tv = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &tv, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: Double(tv.tv_sec))
    }
    
    /// Poll for accessibility permission (e.g. when app becomes active)
    /// Checks every 0.5s for 20 seconds to detect new grants ASAP
    func startPollingForAccessibility() {
        pollingTimer?.invalidate()
        var attempts = 0
        
        print("🔐 PermissionManager: Starting accessibility polling (0.5s interval, max 20s)…")
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            attempts += 1
            
            if AXIsProcessTrusted() {
                // Grant detected!
                if !UserDefaults.standard.bool(forKey: self.accessibilityGrantedKey) {
                    UserDefaults.standard.set(true, forKey: self.accessibilityGrantedKey)
                    DispatchQueue.main.async { self.objectWillChange.send() }
                    print("🔐 PermissionManager: ✅ Polling detected accessibility grant! (attempt \(attempts))")
                } else {
                    print("🔐 PermissionManager: ✅ Accessibility confirmed (attempt \(attempts))")
                }
                timer.invalidate()
            }
            
            if attempts >= 40 { // Stop after 20 seconds
                print("🔐 PermissionManager: Polling timeout - accessibility still not granted after 20s")
                timer.invalidate()
            }
        }
    }
    
    // MARK: - Screen Recording
    
    /// Check if screen recording permission is granted
    var isScreenRecordingGranted: Bool {
        let granted = CGPreflightScreenCaptureAccess()
        
        if granted {
            if !UserDefaults.standard.bool(forKey: screenRecordingGrantedKey) {
                UserDefaults.standard.set(true, forKey: screenRecordingGrantedKey)
                DispatchQueue.main.async { self.objectWillChange.send() }
                print("🔐 PermissionManager: Screen Recording granted! (TCC confirmed, cache updated)")
            }
            return true
        }
        
        // TCC says NOT granted - check cache with grace period logic
        let cacheValue = UserDefaults.standard.bool(forKey: screenRecordingGrantedKey)
        
        // During grace period after launch, trust cache unconditionally
        let timeSinceLaunch = Date().timeIntervalSince(launchTime)
        if timeSinceLaunch < tccGracePeriod && cacheValue {
            print("🔐 PermissionManager: Screen Recording in TCC grace period (\(String(format: "%.1f", timeSinceLaunch))s), trusting cache")
            return true
        }
        
        // After grace period, still trust cache but log normally
        if cacheValue {
            print("🔐 PermissionManager: Screen Recording - TCC=false but cache=true (trusting cache)")
        }
        return cacheValue
    }
    
    /// Request screen recording permission (shows system dialog)
    @discardableResult
    func requestScreenRecording() -> Bool {
        // Prevent duplicate prompts in same session
        if hasPromptedScreenRecording {
            print("🔐 PermissionManager: Skipping screen recording prompt (already prompted this session)")
            return isScreenRecordingGranted
        }
        
        // Prevent duplicate prompts in same boot cycle
        if let lastPromptTime = UserDefaults.standard.object(forKey: lastScreenRecordingPromptBootTimeKey) as? Date,
           let bootTime = getSystemBootTime(),
           lastPromptTime > bootTime {
            print("🔐 PermissionManager: Skipping screen recording prompt (already prompted this boot cycle)")
            hasPromptedScreenRecording = true
            return isScreenRecordingGranted
        }
        
        hasPromptedScreenRecording = true
        UserDefaults.standard.set(Date(), forKey: lastScreenRecordingPromptBootTimeKey)
        
        print("🔐 PermissionManager: Requesting screen recording permission (showing macOS dialog)…")
        return CGRequestScreenCaptureAccess()
    }
    
    // MARK: - Input Monitoring
    
    /// Check if input monitoring permission is granted
    /// runtimeCheck is the live result from IOHIDManager (from GlobalHotKey)
    func isInputMonitoringGranted(runtimeCheck: Bool) -> Bool {
        if runtimeCheck {
            // IOHIDManager confirms permission - update cache
            if !UserDefaults.standard.bool(forKey: inputMonitoringGrantedKey) {
                UserDefaults.standard.set(true, forKey: inputMonitoringGrantedKey)
                DispatchQueue.main.async { self.objectWillChange.send() }
                print("🔐 PermissionManager: Input Monitoring granted! (runtime confirmed, cache updated)")
            }
            return true
        }
        // Fall back to persistent cache
        return UserDefaults.standard.bool(forKey: inputMonitoringGrantedKey)
    }
    
    /// Mark input monitoring as granted (called by GlobalHotKey on success)
    func markInputMonitoringGranted() {
        if !UserDefaults.standard.bool(forKey: inputMonitoringGrantedKey) {
            UserDefaults.standard.set(true, forKey: inputMonitoringGrantedKey)
            DispatchQueue.main.async { self.objectWillChange.send() }
            print("🔐 PermissionManager: Input Monitoring marked as granted")
        }
    }
    
    // MARK: - Settings URLs
    
    func openAccessibilitySettings() {
        print("🔐 PermissionManager: Opening Accessibility settings…")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openScreenRecordingSettings() {
        print("🔐 PermissionManager: Opening Screen Recording settings…")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openInputMonitoringSettings() {
        print("🔐 PermissionManager: Opening Input Monitoring settings…")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Session Reset
    
    /// Reset prompt tracking (called when user explicitly wants to re-prompt)
    func resetPromptTracking() {
        hasPromptedAccessibility = false
        hasPromptedScreenRecording = false
        print("🔐 PermissionManager: Prompt tracking reset")
    }
}
