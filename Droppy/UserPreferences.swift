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
    static let showIdleNotchOnExternalDisplays = "showIdleNotchOnExternalDisplays"
    static let externalDisplayAdvancedVisibilityEnabled = "externalDisplayAdvancedVisibilityEnabled"
    static let externalDisplayVisibilityRules = "externalDisplayVisibilityRules"  // JSON dictionary [displayID: Bool]
    static let enableProgressiveBlur = "enableProgressiveBlur"
    static let autoHideOnFullscreen = "autoHideOnFullscreen"
    static let hideMediaOnlyOnFullscreen = "hideMediaOnlyOnFullscreen"  // Sub-option: only hide media, not HUDs
    static let enableParallaxEffect = "enableParallaxEffect"
    static let enableRightClickHide = "enableRightClickHide"
    static let hidePhysicalNotch = "hidePhysicalNotch"  // Draw black bar to hide the notch cutout
    static let hidePhysicalNotchOnExternals = "hidePhysicalNotchOnExternals"  // Sub-option: also apply to external displays
    static let dynamicIslandHeightOffset = "dynamicIslandHeightOffset"  // Height adjustment for Dynamic Island (-10 to +10)
    
    // MARK: - Media Player
    static let showMediaPlayer = "showMediaPlayer"
    static let autoFadeMediaHUD = "autoFadeMediaHUD"
    static let autofadeDefaultDelay = "autofadeDefaultDelay"  // Default delay in seconds
    static let autofadeAppRulesEnabled = "autofadeAppRulesEnabled"  // Enable app-specific rules
    static let autofadeDisplayRulesEnabled = "autofadeDisplayRulesEnabled"  // Enable display-specific rules
    static let debounceMediaChanges = "debounceMediaChanges"
    static let enableRealAudioVisualizer = "enableRealAudioVisualizer"
    static let enableGradientVisualizer = "enableGradientVisualizer"  // Gradient colors across visualizer bars

    // MARK: - Media Source Filter
    static let mediaSourceFilterEnabled = "mediaSourceFilterEnabled"
    static let mediaSourceAllowedBundles = "mediaSourceAllowedBundles"  // JSON array of bundle identifiers
    static let hideIncognitoBrowserMedia = "hideIncognitoBrowserMedia"  // Hide media from incognito/private browsing windows
    
    // MARK: - HUD Settings
    static let enableBatteryHUD = "enableBatteryHUD"
    static let enableCapsLockHUD = "enableCapsLockHUD"
    static let enableAirPodsHUD = "enableAirPodsHUD"
    static let enableLockScreenHUD = "enableLockScreenHUD"
    static let enableDNDHUD = "enableDNDHUD"
    static let enableUpdateHUD = "enableUpdateHUD"
    static let mediaControlTargetMode = "mediaControlTargetMode"  // "mainMacBook" or "activeDisplay"
    
    // MARK: - Lock Screen Media Widget
    static let enableLockScreenMediaWidget = "enableLockScreenMediaWidget"
    static let hideNotchMediaHUDWithLockScreen = "hideNotchMediaHUDWithLockScreen"  // Sub-option: hide small media HUD when lock screen media is active
    
    // MARK: - Shelf Behavior
    static let autoCollapseShelf = "autoCollapseShelf"
    static let autoCollapseDelay = "autoCollapseDelay"
    static let autoExpandShelf = "autoExpandShelf"
    static let autoExpandDelay = "autoExpandDelay"
    static let autoOpenMediaHUDOnShelfExpand = "autoOpenMediaHUDOnShelfExpand"  // Auto-show media HUD when shelf expands
    static let autoShrinkShelf = "autoShrinkShelf"  // Legacy
    static let autoShrinkDelay = "autoShrinkDelay"  // Legacy
    
    // MARK: - Basket Behavior
    static let enableBasketAutoHide = "enableBasketAutoHide"
    static let basketAutoHideDelay = "basketAutoHideDelay"  // Delay in seconds before basket hides after cursor leaves
    static let instantBasketOnDrag = "instantBasketOnDrag"
    static let instantBasketDelay = "instantBasketDelay"
    static let basketJiggleSensitivity = "basketJiggleSensitivity"  // 1...5 (higher = easier shake trigger)
    static let basketDragRevealShortcut = "basketDragRevealShortcut"  // JSON-encoded SavedShortcut data
    static let enableAutoClean = "enableAutoClean"
    static let alwaysCopyOnDrag = "alwaysCopyOnDrag"
    static let enablePowerFolders = "enablePowerFolders"
    static let enableQuickActions = "enableQuickActions"
    static let enableTrackedFolders = "enableTrackedFolders"
    static let enableMultiBasket = "enableMultiBasket"  // Allow spawning multiple baskets simultaneously
    static let basketSwitcherShortcut = "basketSwitcherShortcut"  // Custom shortcut to show basket switcher
    
    // MARK: - Clipboard
    static let clipboardAutoFocusSearch = "clipboardAutoFocusSearch"
    static let clipboardHistoryLimit = "clipboardHistoryLimit"
    static let clipboardCopyFavoriteEnabled = "clipboardCopyFavoriteEnabled"
    static let clipboardTagsEnabled = "clipboardTagsEnabled"
    static let showClipboardInMenuBar = "showClipboardInMenuBar"
    
    // MARK: - UI Elements
    static let showClipboardButton = "showClipboardButton"
    static let showContextMenuOpenClipboard = "showContextMenuOpenClipboard"
    static let showOpenShelfIndicator = "showOpenShelfIndicator"
    static let showDropIndicator = "showDropIndicator"  // Legacy
    static let enableIdleFace = "enableIdleFace"
    static let enableHapticFeedback = "enableHapticFeedback"
    static let reorderLongPressDuration = "reorderLongPressDuration"  // Duration in seconds to hold before reorder mode activates
    
    // MARK: - System
    static let showInMenuBar = "showInMenuBar"
    static let showQuickshareInMenuBar = "showQuickshareInMenuBar"
    static let showQuickshareInSidebar = "showQuickshareInSidebar"
    static let startAtLogin = "startAtLogin"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let didMigrateShelfAirDropDefault = "didMigrateShelfAirDropDefault"
    static let enableFinderServices = "enableFinderServices"
    
    // MARK: - Extension: Element Capture
    static let editorBlurStrength = "elementCapture_blurStrength"  // Blur intensity (5-30, lower = stronger pixelation)
    
    // MARK: - Extension: Terminal Notch
    static let terminalNotchInstalled = "terminalNotch_installed"
    static let terminalNotchEnabled = "terminalNotch_enabled"  // Whether to show in HUD section

    // MARK: - Extension: Camera
    static let cameraInstalled = "camera_installed"
    static let cameraEnabled = "camera_enabled"  // Whether to show camera when invoked
    static let cameraKeepShelfOpen = "camera_keepShelfOpen"  // Keep shelf open while camera is visible
    
    // MARK: - Extension: Notification HUD
    static let notificationHUDInstalled = "notificationHUD_installed"
    static let notificationHUDEnabled = "notificationHUD_enabled"
    static let notificationHUDShowPreview = "notificationHUD_showPreview"
    
    // MARK: - Extension: Caffeine
    static let caffeineInstalled = "caffeine_installed"
    static let caffeineEnabled = "caffeine_enabled"  // Whether to show in HUD section
    static let caffeineMode = "caffeine_mode"  // CaffeineMode rawValue
    
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
    static let showIdleNotchOnExternalDisplays = false  // Hide by default when idle (current behavior)
    static let externalDisplayAdvancedVisibilityEnabled = false
    static let externalDisplayVisibilityRules = "{}"
    static let enableProgressiveBlur = true  // iOS-style progressive blur around notch
    static let autoHideOnFullscreen = true   // Hide notch in fullscreen apps/games
    static let hideMediaOnlyOnFullscreen = false  // Sub-option: only hide media, keep volume/brightness HUDs
    static let enableParallaxEffect = true   // 3D parallax tilt on hover (album art, etc.)
    static let enableRightClickHide = false  // Right-click to quickly hide notch/island
    static let enableHapticFeedback = true   // Haptic feedback for trackpad (on by default)
    static let hidePhysicalNotch = false     // Draw black bar to hide the notch cutout
    static let hidePhysicalNotchOnExternals = false  // Sub-option: also apply to external displays
    static let dynamicIslandHeightOffset: Double = 0  // No height adjustment by default
    
    // MARK: - Media Player
    static let showMediaPlayer = true
    static let autoFadeMediaHUD = true
    static let autofadeDefaultDelay: Double = 5.0  // 5 seconds default
    static let autofadeAppRulesEnabled = false  // App-specific rules disabled by default
    static let autofadeDisplayRulesEnabled = false  // Display-specific rules disabled by default
    static let debounceMediaChanges = false
    static let enableRealAudioVisualizer = false  // Opt-in: requires Screen Recording
    static let enableGradientVisualizer = false   // Opt-in: gradient colors across visualizer bars

    // MARK: - Media Source Filter
    static let mediaSourceFilterEnabled = false  // Off by default: show all media sources
    static let mediaSourceAllowedBundles = "{}"  // Empty JSON dictionary: no filter applied
    static let hideIncognitoBrowserMedia = false  // Off by default: show media from incognito browsers
    
    // MARK: - HUD Settings
    static let enableBatteryHUD = true
    static let enableCapsLockHUD = true
    static let enableAirPodsHUD = true
    static let enableLockScreenHUD = false  // DISABLED: Lock screen features causing issues, will debug later
    static let enableDNDHUD = false  // Requires Full Disk Access
    static let enableUpdateHUD = true  // Show HUD when update is available
    static let mediaControlTargetMode = "mainMacBook"  // Keep behavior focused on built-in display by default
    
    // MARK: - Lock Screen Media Widget
    static let enableLockScreenMediaWidget = false  // Uses private APIs, opt-in
    static let hideNotchMediaHUDWithLockScreen = false  // When lock screen media is showing, hide small notch/island media HUD
    
    // MARK: - Shelf Behavior
    static let autoCollapseShelf = true
    // PREMIUM PARITY: 0.25s expand, 0.10s collapse (v1.3.109)
    static let autoCollapseDelay: Double = 0.10
    static let autoExpandShelf = true
    static let autoExpandDelay: Double = 0.25
    static let autoOpenMediaHUDOnShelfExpand = false  // Auto-open media HUD when shelf expands (opt-in)
    static let autoShrinkShelf = true  // Legacy
    static let autoShrinkDelay = 3  // Legacy
    
    // MARK: - Basket Behavior
    static let enableBasketAutoHide = false
    static let basketAutoHideDelay: Double = 2.0  // 2 seconds delay before hiding
    static let instantBasketOnDrag = false
    static let instantBasketDelay: Double = 0.15  // Seconds, minimum 0.15 to let drag settle
    static let basketJiggleSensitivity: Double = 3.0
    static let enableAutoClean = false
    static let alwaysCopyOnDrag = false  // Off by default (standard macOS behavior), advanced users enable for protection
    static let enablePowerFolders = true
    static let enableQuickActions = false  // Advanced feature, opt-in
    static let enableTrackedFolders = false  // Advanced feature, opt-in
    static let enableMultiBasket = true  // Multi-basket by default for spawning multiple simultaneous baskets
    
    // MARK: - Clipboard
    static let clipboardAutoFocusSearch = false
    static let clipboardHistoryLimit = 50
    static let clipboardCopyFavoriteEnabled = false
    static let clipboardTagsEnabled = true  // Tags enabled by default
    static let showClipboardInMenuBar = false
    
    // MARK: - UI Elements
    static let showClipboardButton = false
    static let showContextMenuOpenClipboard = true
    static let showOpenShelfIndicator = true
    static let showDropIndicator = true  // Legacy
    static let enableIdleFace = true
    static let reorderLongPressDuration: Double = 1.0  // 1 second hold to activate reorder mode
    
    // MARK: - System
    static let showInMenuBar = true
    static let showQuickshareInMenuBar = true
    static let showQuickshareInSidebar = true  // On by default, can be turned off
    static let startAtLogin = false
    static let hasCompletedOnboarding = false
    static let enableFinderServices = true
    
    // MARK: - Extension: Element Capture
    static let editorBlurStrength: Double = 10  // 10x10 pixelation (lower = stronger blur)
    
    // MARK: - Extension: Terminal Notch
    static let terminalNotchInstalled = false
    static let terminalNotchEnabled = true  // Enabled by default when installed

    // MARK: - Extension: Camera
    static let cameraInstalled = false
    static let cameraEnabled = true  // Enabled by default when installed
    static let cameraKeepShelfOpen = true  // Keep shelf open while camera is active by default
    
    // MARK: - Extension: Notification HUD
    static let notificationHUDInstalled = false
    static let notificationHUDEnabled = true  // Enabled by default when installed
    static let notificationHUDShowPreview = true
    
    // MARK: - Extension: Caffeine
    static let caffeineInstalled = false  // Disabled by default, user installs from Extension Store
    static let caffeineEnabled = true  // Enabled by default when installed
    static let caffeineMode = "Both"  // CaffeineMode.both.rawValue
    
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
