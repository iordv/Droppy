//
//  UserPreferences.swift
//  Droppy
//
//  Single Source of Truth for all user preferences
//  All @AppStorage keys and defaults are defined here
//

import SwiftUI

// MARK: - Preference Keys (Single Source of Truth)

/// All UserDefaults keys used in the app
/// Use these constants instead of string literals to prevent typos
enum AppPreferenceKey {
    // MARK: - Core Features
    static let enableNotchShelf = "enableNotchShelf"
    static let enableFloatingBasket = "enableFloatingBasket"
    static let enableClipboard = "enableClipboardBeta"
    static let enableHUDReplacement = "enableHUDReplacement"
    
    // MARK: - Appearance
    static let useDynamicIslandStyle = "useDynamicIslandStyle"
    static let useDynamicIslandTransparent = "useDynamicIslandTransparent"
    static let useTransparentBackground = "useTransparentBackground"
    static let hideNotchOnExternalDisplays = "hideNotchOnExternalDisplays"
    static let hideNotchFromScreenshots = "hideNotchFromScreenshots"
    static let isNotchHidden = "isNotchHidden"
    static let externalDisplayUseDynamicIsland = "externalDisplayUseDynamicIsland"
    static let enableProgressiveBlur = "enableProgressiveBlur"
    static let autoHideOnFullscreen = "autoHideOnFullscreen"
    static let enableParallaxEffect = "enableParallaxEffect"
    static let enableRightClickHide = "enableRightClickHide"
    
    // MARK: - Media Player
    static let showMediaPlayer = "showMediaPlayer"
    static let autoFadeMediaHUD = "autoFadeMediaHUD"
    static let debounceMediaChanges = "debounceMediaChanges"
    static let enableRealAudioVisualizer = "enableRealAudioVisualizer"
    
    // MARK: - HUD Settings
    static let enableBatteryHUD = "enableBatteryHUD"
    static let enableCapsLockHUD = "enableCapsLockHUD"
    static let enableAirPodsHUD = "enableAirPodsHUD"
    static let enableLockScreenHUD = "enableLockScreenHUD"
    static let enableDNDHUD = "enableDNDHUD"
    
    // MARK: - Shelf Behavior
    static let autoCollapseShelf = "autoCollapseShelf"
    static let autoCollapseDelay = "autoCollapseDelay"
    static let autoExpandShelf = "autoExpandShelf"
    static let autoExpandDelay = "autoExpandDelay"
    static let autoShrinkShelf = "autoShrinkShelf"  // Legacy
    static let autoShrinkDelay = "autoShrinkDelay"  // Legacy
    
    // MARK: - Basket Behavior
    static let enableBasketAutoHide = "enableBasketAutoHide"
    static let basketAutoHideEdge = "basketAutoHideEdge"
    static let instantBasketOnDrag = "instantBasketOnDrag"
    static let instantBasketDelay = "instantBasketDelay"
    static let enableAutoClean = "enableAutoClean"
    static let alwaysCopyOnDrag = "alwaysCopyOnDrag"
    static let enableAirDropZone = "enableAirDropZone"
    static let enableShelfAirDropZone = "enableShelfAirDropZone"
    static let enablePowerFolders = "enablePowerFolders"
    static let enableQuickActions = "enableQuickActions"
    static let enableTrackedFolders = "enableTrackedFolders"
    
    // MARK: - Clipboard
    static let clipboardAutoFocusSearch = "clipboardAutoFocusSearch"
    static let clipboardHistoryLimit = "clipboardHistoryLimit"
    static let clipboardCopyFavoriteEnabled = "clipboardCopyFavoriteEnabled"
    
    // MARK: - UI Elements
    static let showClipboardButton = "showClipboardButton"
    static let showContextMenuOpenClipboard = "showContextMenuOpenClipboard"
    static let showOpenShelfIndicator = "showOpenShelfIndicator"
    static let showDropIndicator = "showDropIndicator"  // Legacy
    static let enableIdleFace = "enableIdleFace"
    static let enableHapticFeedback = "enableHapticFeedback"
    
    // MARK: - System
    static let showInMenuBar = "showInMenuBar"
    static let showQuickshareInMenuBar = "showQuickshareInMenuBar"
    static let startAtLogin = "startAtLogin"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let didMigrateShelfAirDropDefault = "didMigrateShelfAirDropDefault"
    static let enableFinderServices = "enableFinderServices"
    
    // MARK: - Extension: Terminal Notch
    static let terminalNotchInstalled = "terminalNotch_installed"
    
    // MARK: - Extension: Video Compression (Legacy - migrated to Smart Export)
    static let compressionAutoSaveToFolder = "compressionAutoSaveToFolder"
    static let compressionAutoSaveFolder = "compressionAutoSaveFolder"  // URL path string
    static let compressionRevealInFinder = "compressionRevealInFinder"
    
    // MARK: - Smart Export
    static let smartExportEnabled = "smartExportEnabled"
    // Compression
    static let smartExportCompressionEnabled = "smartExportCompressionEnabled"
    static let smartExportCompressionFolder = "smartExportCompressionFolder"
    static let smartExportCompressionReveal = "smartExportCompressionReveal"
    // Conversion
    static let smartExportConversionEnabled = "smartExportConversionEnabled"
    static let smartExportConversionFolder = "smartExportConversionFolder"
    static let smartExportConversionReveal = "smartExportConversionReveal"
}

// MARK: - Default Values (Single Source of Truth)

/// All default values for preferences
/// Use these when reading from UserDefaults directly (non-SwiftUI contexts)
enum PreferenceDefault {
    // MARK: - Core Features
    static let enableNotchShelf = true
    static let enableFloatingBasket = true
    static let enableClipboard = true
    static let enableHUDReplacement = true
    
    // MARK: - Appearance
    static let useDynamicIslandStyle = true
    static let useDynamicIslandTransparent = false
    static let useTransparentBackground = false
    static let hideNotchOnExternalDisplays = false
    static let hideNotchFromScreenshots = false
    static let isNotchHidden = false
    static let externalDisplayUseDynamicIsland = true
    static let enableProgressiveBlur = true  // iOS-style progressive blur around notch
    static let autoHideOnFullscreen = true   // Hide notch in fullscreen apps/games
    static let enableParallaxEffect = true   // 3D parallax tilt on hover (album art, etc.)
    static let enableRightClickHide = false  // Right-click to quickly hide notch/island
    static let enableHapticFeedback = true   // Haptic feedback for trackpad (on by default)
    
    // MARK: - Media Player
    static let showMediaPlayer = true
    static let autoFadeMediaHUD = true
    static let debounceMediaChanges = false
    static let enableRealAudioVisualizer = false  // Opt-in: requires Screen Recording
    
    // MARK: - HUD Settings
    static let enableBatteryHUD = true
    static let enableCapsLockHUD = true
    static let enableAirPodsHUD = true
    static let enableLockScreenHUD = true
    static let enableDNDHUD = false  // Requires Full Disk Access
    
    // MARK: - Shelf Behavior
    static let autoCollapseShelf = true
    // PREMIUM PARITY: 0.25s expand, 0.10s collapse (v1.3.109)
    static let autoCollapseDelay: Double = 0.10
    static let autoExpandShelf = true
    static let autoExpandDelay: Double = 0.25
    static let autoShrinkShelf = true  // Legacy
    static let autoShrinkDelay = 3  // Legacy
    
    // MARK: - Basket Behavior
    static let enableBasketAutoHide = false
    static let basketAutoHideEdge = "right"
    static let instantBasketOnDrag = false
    static let instantBasketDelay: Double = 0.15  // Seconds, minimum 0.15 to let drag settle
    static let enableAutoClean = false
    static let alwaysCopyOnDrag = false  // Off by default (standard macOS behavior), advanced users enable for protection
    static let enableAirDropZone = true
    static let enableShelfAirDropZone = true
    static let enablePowerFolders = true
    static let enableQuickActions = false  // Advanced feature, opt-in
    static let enableTrackedFolders = false  // Advanced feature, opt-in
    
    // MARK: - Clipboard
    static let clipboardAutoFocusSearch = false
    static let clipboardHistoryLimit = 50
    static let clipboardCopyFavoriteEnabled = false
    
    // MARK: - UI Elements
    static let showClipboardButton = false
    static let showContextMenuOpenClipboard = true
    static let showOpenShelfIndicator = true
    static let showDropIndicator = true  // Legacy
    static let enableIdleFace = true
    
    // MARK: - System
    static let showInMenuBar = true
    static let showQuickshareInMenuBar = true
    static let startAtLogin = false
    static let hasCompletedOnboarding = false
    static let enableFinderServices = true
    
    // MARK: - Extension: Terminal Notch
    static let terminalNotchInstalled = false
    
    // MARK: - Extension: Video Compression (Legacy)
    static let compressionAutoSaveToFolder = false
    static let compressionAutoSaveFolder = ""  // Empty = Downloads folder
    static let compressionRevealInFinder = true
    
    // MARK: - Smart Export
    static let smartExportEnabled = false
    // Compression
    static let smartExportCompressionEnabled = false
    static let smartExportCompressionFolder = ""  // Empty = Downloads folder
    static let smartExportCompressionReveal = true
    // Conversion
    static let smartExportConversionEnabled = false
    static let smartExportConversionFolder = ""  // Empty = Downloads folder
    static let smartExportConversionReveal = true
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    /// Get a boolean preference with its default value from PreferenceDefault
    /// Use this in non-SwiftUI contexts instead of @AppStorage
    func preference(_ key: String, default defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
    
    /// Get a double preference with its default value from PreferenceDefault
    func preference(_ key: String, default defaultValue: Double) -> Double {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return double(forKey: key)
    }
    
    /// Get an int preference with its default value from PreferenceDefault
    func preference(_ key: String, default defaultValue: Int) -> Int {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return integer(forKey: key)
    }
    
    /// Get a string preference with its default value from PreferenceDefault
    func preference(_ key: String, default defaultValue: String) -> String {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return string(forKey: key) ?? defaultValue
    }
}
