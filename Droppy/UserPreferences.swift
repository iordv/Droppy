//
//  UserPreferences.swift
//  Droppy
//
//  Single Source of Truth for all user preferences
//  All @AppStorage keys and defaults are defined here
//

import SwiftUI
import AppKit

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
    static let notchWidthOffset = "notchWidthOffset"  // Width adjustment for physical notch rendering (-40 to +80)
    
    // MARK: - Media Player
    static let showMediaPlayer = "showMediaPlayer"
    static let enableMouseSwipeMediaSwitch = "enableMouseSwipeMediaSwitch"  // Allow mouse wheel gesture for media/shelf switch
    static let mouseSwipeMediaSwitchModifier = "mouseSwipeMediaSwitchModifier"  // "option", "shift", "control"
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
    static let autoExpandOnMainMac = "autoExpandOnMainMac"  // Allow hover auto-expand on the built-in Mac display
    static let autoExpandOnExternalDisplays = "autoExpandOnExternalDisplays"  // Allow hover auto-expand on external displays
    static let autoExpandDelay = "autoExpandDelay"
    static let autoOpenMediaHUDOnShelfExpand = "autoOpenMediaHUDOnShelfExpand"  // Auto-show media HUD when shelf expands
    static let showMediaShelfSwitchBadge = "showMediaShelfSwitchBadge"  // Show top-left switch badge in shelf/media views
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
    static let quickActionsMailApp = "quickActionsMailApp"  // "systemDefault", "appleMail", "outlook"
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
    static let showDropIndicator = "showDropIndicator"  // Legacy
    static let enableIdleFace = "enableIdleFace"
    static let enableHapticFeedback = "enableHapticFeedback"
    static let reorderLongPressDuration = "reorderLongPressDuration"  // Duration in seconds to hold before reorder mode activates
    
    // MARK: - System
    static let showInMenuBar = "showInMenuBar"
    static let showQuickshareInMenuBar = "showQuickshareInMenuBar"
    static let showQuickshareInSidebar = "showQuickshareInSidebar"
    static let quickshareRequireUploadConfirmation = "quickshareRequireUploadConfirmation"
    static let startAtLogin = "startAtLogin"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let didMigrateShelfAirDropDefault = "didMigrateShelfAirDropDefault"
    static let enableFinderServices = "enableFinderServices"
    static let gumroadLicenseActive = "gumroadLicenseActive"
    static let gumroadLicenseEmail = "gumroadLicenseEmail"
    static let gumroadLicenseKeyHint = "gumroadLicenseKeyHint"
    static let gumroadLicenseDeviceName = "gumroadLicenseDeviceName"
    static let gumroadLicenseLastValidatedAt = "gumroadLicenseLastValidatedAt"
    static let licenseTrialConsumed = "licenseTrialConsumed"
    static let licenseTrialStartedAt = "licenseTrialStartedAt"
    static let licenseTrialExpiresAt = "licenseTrialExpiresAt"
    static let licenseTrialLastRemoteSyncAt = "licenseTrialLastRemoteSyncAt"
    static let licenseTrialAccountHash = "licenseTrialAccountHash"
    static let disableAnalytics = "disableAnalytics"
    
    // MARK: - Extension: Element Capture
    static let editorBlurStrength = "elementCapture_blurStrength"  // Blur intensity (5-30, lower = stronger pixelation)
    static let ocrAutoCopyExtractedText = "ocr_autoCopyExtractedText"  // Auto-copy OCR results and skip result window

    // MARK: - Extension: Window Snap
    static let windowSnapPointerModeEnabled = "windowSnap_pointerModeEnabled"
    static let windowSnapMoveModifierMask = "windowSnap_moveModifierMask"
    static let windowSnapResizeModifierMask = "windowSnap_resizeModifierMask"
    static let windowSnapBringToFrontWhenHandling = "windowSnap_bringToFrontWhenHandling"
    static let windowSnapResizeMode = "windowSnap_resizeMode"
    
    // MARK: - Extension: Terminal Notch
    static let terminalNotchInstalled = "terminalNotch_installed"
    static let terminalNotchEnabled = "terminalNotch_enabled"  // Whether to show in HUD section
    static let terminalNotchExternalApp = "terminalNotch_externalApp"  // Which app opens for full terminal

    // MARK: - Extension: Camera
    static let cameraInstalled = "camera_installed"
    static let cameraEnabled = "camera_enabled"  // Whether to show camera preview in expanded shelf
    static let cameraPreferredDeviceID = "camera_preferredDeviceID"  // Empty = auto-pick best available camera
    
    // MARK: - Extension: Notification HUD
    static let notificationHUDInstalled = "notificationHUD_installed"
    static let notificationHUDEnabled = "notificationHUD_enabled"
    static let notificationHUDShowPreview = "notificationHUD_showPreview"
    
    // MARK: - Extension: Caffeine
    static let caffeineInstalled = "caffeine_installed"
    static let caffeineEnabled = "caffeine_enabled"  // Whether to show in HUD section
    static let caffeineMode = "caffeine_mode"  // CaffeineMode rawValue
    static let caffeineInstantlyExpandShelfOnHover = "caffeine_instantlyExpandShelfOnHover"  // Skip hover timer HUD and keep normal shelf auto-expand

    // MARK: - Extension: Todo
    static let todoInstalled = "todo_installed"
    static let todoEnabled = "todo_enabled"  // Whether to show in shelf
    static let todoAutoCleanupHours = "todo_autoCleanupHours"  // Hours before completed items are removed
    static let todoSyncCalendarEnabled = "todo_syncCalendarEnabled"
    static let todoSyncRemindersEnabled = "todo_syncRemindersEnabled"
    static let todoSyncRemindersListIDs = "todo_syncRemindersListIDs"  // JSON array of selected reminder list identifiers
    static let todoSyncCalendarListIDs = "todo_syncCalendarListIDs"  // JSON array of selected calendar identifiers
    static let todoShelfSplitViewEnabled = "todo_shelfSplitViewEnabled"
    static let todoDueSoonNotificationsEnabled = "todo_dueSoonNotificationsEnabled"
    static let todoDueSoonNotificationsChimeEnabled = "todo_dueSoonNotificationsChimeEnabled"
    static let todoShowTaskViewTimezone = "todo_showTaskViewTimezone"
    static let todoShowTaskWeekNumber = "todo_showTaskWeekNumber"
    
    // MARK: - Extension: Voice Transcribe
    static let voiceTranscribeAutoCopyResult = "voiceTranscribe_autoCopyResult"  // Auto-copy transcription and skip result window
    
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
    static let notchWidthOffset: Double = 0  // No width adjustment by default
    
    // MARK: - Media Player
    static let showMediaPlayer = true
    static let enableMouseSwipeMediaSwitch = false
    static let mouseSwipeMediaSwitchModifier = "option"
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
    static let enableLockScreenHUD = true  // Safe: uses separate-window architecture, main notch never delegated to SkyLight
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
    static let autoExpandOnMainMac = true  // Preserve current behavior: hover auto-expand enabled on built-in display
    static let autoExpandOnExternalDisplays = true  // Keep legacy behavior by default; users can disable if it conflicts with menu bar usage
    static let autoExpandDelay: Double = 0.25
    static let autoOpenMediaHUDOnShelfExpand = false  // Auto-open media HUD when shelf expands (opt-in)
    static let showMediaShelfSwitchBadge = true  // Keep media/shelf switch badge visible by default
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
    static let quickActionsMailApp = "systemDefault"
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
    static let showDropIndicator = true  // Legacy
    static let enableIdleFace = true
    static let reorderLongPressDuration: Double = 1.0  // 1 second hold to activate reorder mode
    
    // MARK: - System
    static let showInMenuBar = true
    static let showQuickshareInMenuBar = true
    static let showQuickshareInSidebar = true  // On by default, can be turned off
    static let quickshareRequireUploadConfirmation = false  // Off by default to preserve current flow
    static let startAtLogin = false
    static let hasCompletedOnboarding = false
    static let enableFinderServices = true
    static let gumroadLicenseActive = false
    static let gumroadLicenseEmail = ""
    static let gumroadLicenseKeyHint = ""
    static let gumroadLicenseDeviceName = ""
    static let gumroadLicenseLastValidatedAt: Double = 0
    static let licenseTrialConsumed = false
    static let licenseTrialStartedAt: Double = 0
    static let licenseTrialExpiresAt: Double = 0
    static let licenseTrialLastRemoteSyncAt: Double = 0
    static let licenseTrialAccountHash = ""
    static let disableAnalytics = false
    
    // MARK: - Extension: Element Capture
    static let editorBlurStrength: Double = 10  // 10x10 pixelation (lower = stronger blur)
    static let ocrAutoCopyExtractedText = false

    // MARK: - Extension: Window Snap
    static let windowSnapPointerModeEnabled = false
    static let windowSnapMoveModifierMask = NSEvent.ModifierFlags.control.rawValue
    static let windowSnapResizeModifierMask = NSEvent.ModifierFlags.option.rawValue
    static let windowSnapBringToFrontWhenHandling = true
    static let windowSnapResizeMode = "closestCorner"
    
    // MARK: - Extension: Terminal Notch
    static let terminalNotchInstalled = false
    static let terminalNotchEnabled = true  // Enabled by default when installed
    static let terminalNotchExternalApp = "appleTerminal"

    // MARK: - Extension: Camera
    static let cameraInstalled = false
    static let cameraEnabled = true  // Enabled by default when installed
    static let cameraPreferredDeviceID = ""
    
    // MARK: - Extension: Notification HUD
    static let notificationHUDInstalled = false
    static let notificationHUDEnabled = true  // Enabled by default when installed
    static let notificationHUDShowPreview = true
    
    // MARK: - Extension: Caffeine
    static let caffeineInstalled = false  // Disabled by default, user installs from Extension Store
    static let caffeineEnabled = true  // Enabled by default when installed
    static let caffeineMode = "Both"  // CaffeineMode.both.rawValue
    static let caffeineInstantlyExpandShelfOnHover = false  // Keep current behavior by default: show High Alert timer on hover

    // MARK: - Extension: Todo
    static let todoInstalled = false  // Disabled by default, user installs from Extension Store
    static let todoEnabled = true  // Enabled by default when installed
    static let todoAutoCleanupHours = 5  // Completed items removed after 5 hours
    static let todoSyncCalendarEnabled = false
    static let todoSyncRemindersEnabled = false
    static let todoSyncRemindersListIDs = "[]"
    static let todoSyncCalendarListIDs = "[]"
    static let todoShelfSplitViewEnabled = true
    static let todoDueSoonNotificationsEnabled = true
    static let todoDueSoonNotificationsChimeEnabled = true
    static let todoShowTaskViewTimezone = false
    static let todoShowTaskWeekNumber = true
    
    // MARK: - Extension: Voice Transcribe
    static let voiceTranscribeAutoCopyResult = false
    
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
