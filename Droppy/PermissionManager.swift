//
//  PermissionManager.swift
//  Droppy
//
//  Centralized permission checking with caching to prevent repeated prompts
//  when macOS TCC is slow to sync permission state
//
//  v7.0.5: Added logging for cache/TCC mismatches, improved reliability
//

import Foundation
import AppKit

/// Centralized permission manager with caching
/// Uses UserDefaults to remember when permissions were granted,
/// preventing false negatives when TCC hasn't synced yet
///
/// IMPORTANT: Cache is persisted across app updates because TCC permissions
/// are tied to bundle identifier, not code signature. The cache bridges
/// the timing gap while TCC syncs on launch.
final class PermissionManager {
    static let shared = PermissionManager()
    
    // MARK: - Cache Keys
    private let accessibilityGrantedKey = "accessibilityGranted"
    private let screenRecordingGrantedKey = "screenRecordingGranted"
    private let inputMonitoringGrantedKey = "inputMonitoringGranted"
    
    private init() {}
    
    // MARK: - App State
    private let appLaunchTimestamp = Date()
    private let cacheTrustDuration: TimeInterval = 15.0 // Seconds to trust cache after launch
    
    // MARK: - Accessibility
    
    /// Check if accessibility permission is granted (with time-limited cache)
    /// Logic: Always check source of truth (AXIsProcessTrusted).
    /// Only rely on cache during immediate app launch when TCC might be slow.
    /// After warm-up period, cache is ignored to detect runtime revocation.
    var isAccessibilityGranted: Bool {
        let trusted = AXIsProcessTrusted()
        
        if trusted {
            // TCC confirms permission - update cache
            if !UserDefaults.standard.bool(forKey: accessibilityGrantedKey) {
                UserDefaults.standard.set(true, forKey: accessibilityGrantedKey)
                print("🔐 PermissionManager: Accessibility granted, caching")
            }
            return true
        }
        
        // TCC says NOT trusted.
        // Only fall back to cache during the warm-up period.
        // This prevents the "freeze" scenario where user revokes permission
        // but we keep trying to use it because we trust the cache forever.
        if Date().timeIntervalSince(appLaunchTimestamp) < cacheTrustDuration {
            if UserDefaults.standard.bool(forKey: accessibilityGrantedKey) {
                print("🔐 PermissionManager: Trusting cache during warm-up (TCC slow sync)")
                return true
            }
        }
        
        return false
    }
    
    /// Request accessibility permission (shows system dialog)
    /// IMPORTANT: Only call this from user-initiated actions, never from background checks
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - Screen Recording
    
    /// Check if screen recording permission is granted (with cache fallback)
    var isScreenRecordingGranted: Bool {
        let granted = CGPreflightScreenCaptureAccess()
        let hasCachedGrant = UserDefaults.standard.bool(forKey: screenRecordingGrantedKey)
        
        if granted {
            if !hasCachedGrant {
                UserDefaults.standard.set(true, forKey: screenRecordingGrantedKey)
                print("🔐 PermissionManager: Screen Recording granted, caching")
            }
            return true
        }
        
        // Trust cache if we previously verified permission
        if hasCachedGrant {
            return true
        }
        
        return false
    }
    
    /// Request screen recording permission (shows system dialog)
    /// Returns true if granted (may require app restart)
    @discardableResult
    func requestScreenRecording() -> Bool {
        return CGRequestScreenCaptureAccess()
    }
    
    // MARK: - Input Monitoring
    
    /// Check if input monitoring permission is granted (with cache fallback)
    /// Note: This relies on IOHIDManager success which is tracked by GlobalHotKey
    func isInputMonitoringGranted(runtimeCheck: Bool) -> Bool {
        let hasCachedGrant = UserDefaults.standard.bool(forKey: inputMonitoringGrantedKey)
        return runtimeCheck || hasCachedGrant
    }
    
    /// Mark input monitoring as granted (called by GlobalHotKey on success)
    func markInputMonitoringGranted() {
        UserDefaults.standard.set(true, forKey: inputMonitoringGrantedKey)
    }
    
    // MARK: - Settings URLs
    
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
