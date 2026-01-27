//
//  NotchShelfView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Notch Shelf View

/// The notch-based shelf view that shows a yellow glow during drag and expands to show items
struct NotchShelfView: View {
    @Bindable var state: DroppyState
    @ObservedObject var dragMonitor = DragMonitor.shared
    
    /// The target screen for this view instance (multi-monitor support)
    /// When nil, uses the built-in screen (backwards compatibility)
    var targetScreen: NSScreen?
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.enableNotchShelf) private var enableNotchShelf = PreferenceDefault.enableNotchShelf
    @AppStorage(AppPreferenceKey.hideNotchOnExternalDisplays) private var hideNotchOnExternalDisplays = PreferenceDefault.hideNotchOnExternalDisplays
    @AppStorage(AppPreferenceKey.externalDisplayUseDynamicIsland) private var externalDisplayUseDynamicIsland = PreferenceDefault.externalDisplayUseDynamicIsland
    @AppStorage(AppPreferenceKey.enableHUDReplacement) private var enableHUDReplacement = PreferenceDefault.enableHUDReplacement
    @AppStorage(AppPreferenceKey.enableBatteryHUD) private var enableBatteryHUD = PreferenceDefault.enableBatteryHUD
    @AppStorage(AppPreferenceKey.enableCapsLockHUD) private var enableCapsLockHUD = PreferenceDefault.enableCapsLockHUD
    @AppStorage(AppPreferenceKey.enableAirPodsHUD) private var enableAirPodsHUD = PreferenceDefault.enableAirPodsHUD
    @AppStorage(AppPreferenceKey.enableLockScreenHUD) private var enableLockScreenHUD = PreferenceDefault.enableLockScreenHUD
    @AppStorage(AppPreferenceKey.enableDNDHUD) private var enableDNDHUD = PreferenceDefault.enableDNDHUD
    @AppStorage(AppPreferenceKey.showMediaPlayer) private var showMediaPlayer = PreferenceDefault.showMediaPlayer
    @AppStorage(AppPreferenceKey.autoFadeMediaHUD) private var autoFadeMediaHUD = PreferenceDefault.autoFadeMediaHUD
    @AppStorage(AppPreferenceKey.debounceMediaChanges) private var debounceMediaChanges = PreferenceDefault.debounceMediaChanges
    @AppStorage(AppPreferenceKey.autoShrinkShelf) private var autoShrinkShelf = PreferenceDefault.autoShrinkShelf  // Legacy
    @AppStorage(AppPreferenceKey.autoShrinkDelay) private var autoShrinkDelay = PreferenceDefault.autoShrinkDelay  // Legacy
    @AppStorage(AppPreferenceKey.autoCollapseDelay) private var autoCollapseDelay = PreferenceDefault.autoCollapseDelay
    @AppStorage(AppPreferenceKey.autoCollapseShelf) private var autoCollapseShelf = PreferenceDefault.autoCollapseShelf
    @AppStorage(AppPreferenceKey.autoExpandDelay) private var autoExpandDelay = PreferenceDefault.autoExpandDelay
    @AppStorage(AppPreferenceKey.showClipboardButton) private var showClipboardButton = PreferenceDefault.showClipboardButton
    @AppStorage(AppPreferenceKey.showOpenShelfIndicator) private var showOpenShelfIndicator = PreferenceDefault.showOpenShelfIndicator
    @AppStorage(AppPreferenceKey.showDropIndicator) private var showDropIndicator = PreferenceDefault.showDropIndicator  // Legacy, not migrated
    @AppStorage(AppPreferenceKey.useDynamicIslandStyle) private var useDynamicIslandStyle = PreferenceDefault.useDynamicIslandStyle
    @AppStorage(AppPreferenceKey.useDynamicIslandTransparent) private var useDynamicIslandTransparent = PreferenceDefault.useDynamicIslandTransparent
    @AppStorage(AppPreferenceKey.enableAutoClean) private var enableAutoClean = PreferenceDefault.enableAutoClean
    @AppStorage(AppPreferenceKey.enableShelfAirDropZone) private var enableShelfAirDropZone = PreferenceDefault.enableShelfAirDropZone
    @AppStorage(AppPreferenceKey.enableRightClickHide) private var enableRightClickHide = PreferenceDefault.enableRightClickHide
    
    // HUD State - Use @ObservedObject for singletons (they manage their own lifecycle)
    @ObservedObject private var volumeManager = VolumeManager.shared
    @ObservedObject private var brightnessManager = BrightnessManager.shared
    @ObservedObject private var batteryManager = BatteryManager.shared
    @ObservedObject private var capsLockManager = CapsLockManager.shared
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var notchController = NotchWindowController.shared  // For hide/show animation
    var airPodsManager = AirPodsManager.shared  // @Observable - no wrapper needed
    @ObservedObject private var lockScreenManager = LockScreenManager.shared
    @ObservedObject private var dndManager = DNDManager.shared
    @ObservedObject private var terminalManager = TerminalNotchManager.shared
    @ObservedObject private var aiAgentMonitor = AIAgentMonitorManager.shared
    @State private var showVolumeHUD = false
    @State private var showBrightnessHUD = false
    @State private var hudWorkItem: DispatchWorkItem?
    @State private var hudType: HUDContentType = .volume
    @State private var hudValue: CGFloat = 0
    @State private var hudIsVisible = false
    // HUD visibility now managed by HUDManager (removed 10 @State variables)
    @State private var mediaHUDFadedOut = false  // Tracks if media HUD has auto-faded
    @State private var mediaFadeWorkItem: DispatchWorkItem?
    @State private var autoShrinkWorkItem: DispatchWorkItem?  // Timer for auto-shrinking shelf
    @State private var isHoveringExpandedContent = false  // Tracks if mouse is over the expanded shelf
    @State private var isSongTransitioning = false  // Temporarily hide media during song transitions
    @State private var mediaDebounceWorkItem: DispatchWorkItem?  // Debounce for media changes
    @State private var isMediaStable = false  // Only show media HUD after debounce delay
    
    // Idle face preference
    @AppStorage(AppPreferenceKey.enableIdleFace) private var enableIdleFace = PreferenceDefault.enableIdleFace
    
    
    /// Animation state for the border dash
    @State private var dashPhase: CGFloat = 0
    @State private var dropZoneDashPhase: CGFloat = 0
    
    /// Shared start time for title marquee scrolling - ensures smooth scroll continuity during HUD/expanded morph
    @State private var sharedMarqueeStartTime: Date = Date()
    
    // Marquee Selection State
    @State private var selectionRect: CGRect? = nil
    @State private var initialSelection: Set<UUID> = []
    @State private var itemFrames: [UUID: CGRect] = [:]
    
    // Global rename state
    @State private var renamingItemId: UUID?
    
    // Media HUD hover state - used to grow notch when showing song title
    @State private var mediaHUDIsHovered: Bool = false
    @State private var mediaHUDHoverWorkItem: DispatchWorkItem?  // Debounce for hover state
    
    // PREMIUM: Dedicated state for hover scale effect - ensures clean single-value animation
    @State private var hoverScaleActive: Bool = false
    
    // PREMIUM: Album art interaction states
    @State private var albumArtNudgeOffset: CGFloat = 0  // ±6pt nudge on prev/next tap
    @State private var albumArtParallaxOffset: CGSize = .zero  // Cursor-following parallax effect
    @State private var albumArtTapScale: CGFloat = 1.0  // Subtle grow effect when clicking to open source
    @State private var mediaOverlayAppeared: Bool = false  // Scale+opacity appear animation for morphing overlays
    
    // MORPH: Namespace for album art morphing between HUD and expanded player
    @Namespace private var albumArtNamespace
    
    // Removed isDropTargeted state as we use shared state now
    
    /// Dynamic Island background color - now pure black to match notch appearance
    private var dynamicIslandGray: Color {
        Color.black
    }
    
    /// Dynamic notch width based on screen's actual safe areas
    /// This properly handles all resolutions including "More Space" settings
    private var notchWidth: CGFloat {
        // Dynamic Island uses SSOT fixed size
        if isDynamicIslandMode { return NotchLayoutConstants.dynamicIslandWidth }

        // Use target screen or fallback to built-in
        guard let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return NotchLayoutConstants.physicalNotchWidth }
        
        // Use auxiliary areas to calculate true notch width
        // The notch is the gap between the right edge of the left safe area
        // and the left edge of the right safe area
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            // Correct calculation: the gap between the two auxiliary areas
            // This is more accurate than (screen.width - leftWidth - rightWidth)
            // which can have sub-pixel rounding errors on different display configurations
            let notchGap = rightArea.minX - leftArea.maxX
            return max(notchGap, NotchLayoutConstants.physicalNotchWidth)
        }
        
        // Fallback for screens without notch data
        return NotchLayoutConstants.physicalNotchWidth
    }
    
    /// Notch height - scales with resolution
    private var notchHeight: CGFloat {
        // Dynamic Island uses SSOT fixed size
        if isDynamicIslandMode { return NotchLayoutConstants.dynamicIslandHeight }

        // Use target screen or fallback to built-in
        guard let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return 32 }
        let topInset = screen.safeAreaInsets.top
        
        // For screens with a physical notch, use the actual inset
        if topInset > 0 {
            return topInset
        }
        
        // For external displays in notch mode: constrain to menu bar height
        // Menu bar height = difference between full frame and visible frame at the top
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        // Use 24pt as default if menu bar is auto-hidden, but never exceed actual menu bar
        let maxHeight = menuBarHeight > 0 ? menuBarHeight : 24
        return min(32, maxHeight)
    }
    
    /// Whether we're in Dynamic Island mode (no physical notch + setting enabled, or force test)
    private var isDynamicIslandMode: Bool {
        // Use target screen or fallback to built-in
        guard let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        
        // For external displays (non-built-in), use the external display setting
        if !screen.isBuiltIn {
            return externalDisplayUseDynamicIsland
        }
        
        // For built-in display, use the main Dynamic Island setting
        return (!hasNotch || forceTest) && useDynamicIslandStyle
    }
    
    /// Whether this view is on an external display (non-built-in)
    private var isExternalDisplay: Bool {
        guard let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return false }
        return !screen.isBuiltIn
    }
    
    /// Whether the Dynamic Island should use transparent glass effect
    /// DISABLED: Dynamic Island now always uses solid black, same as notch mode
    private var shouldUseDynamicIslandTransparent: Bool {
        false  // Always solid black to match notch appearance
    }
    
    /// Whether the external display notch should use transparent glass effect
    /// DISABLED: External notch now always uses solid black, same as built-in notch
    private var shouldUseExternalNotchTransparent: Bool {
        false  // Always solid black to match notch appearance
    }
    
    /// Whether the HUD should show a title in the center
    /// True for Dynamic Island mode OR external displays (no physical camera blocking the center)
    private var shouldShowTitleInHUD: Bool {
        isDynamicIslandMode || isExternalDisplay
    }
    
    /// SSOT: notchHeight to use for CONTENT layout calculations
    /// External displays and DI mode use 0 (symmetrical 20pt padding on all edges)
    /// Only built-in displays with physical notch use actual notchHeight (content starts below notch)
    private var contentLayoutNotchHeight: CGFloat {
        (isDynamicIslandMode || isExternalDisplay) ? 0 : notchHeight
    }
    
    /// Whether THIS specific screen has the shelf expanded
    /// This is screen-specific - only returns true for the screen that is actually expanded
    /// Fixes issue where BOTH screens would show as expanded when any screen was expanded
    private var isExpandedOnThisScreen: Bool {
        guard let displayID = targetScreen?.displayID ?? NSScreen.builtInWithNotch?.displayID else {
            return state.isExpanded  // Fallback to global check if no displayID
        }
        return state.isExpanded(for: displayID)
    }
    
    /// Whether THIS specific screen has hover state
    /// This is screen-specific - only returns true for the screen that is actually being hovered
    /// Fixes issue where BOTH screens would show hover animation when hovering any screen
    private var isHoveringOnThisScreen: Bool {
        guard let displayID = targetScreen?.displayID ?? NSScreen.builtInWithNotch?.displayID else {
            return state.isMouseHovering  // Fallback to global check if no displayID
        }
        return state.isHovering(for: displayID)
    }
    
    /// Top margin for Dynamic Island from SSOT - creates floating effect like iPhone
    private var dynamicIslandTopMargin: CGFloat { NotchLayoutConstants.dynamicIslandTopMargin }
    
    private let expandedWidth: CGFloat = 450
    
    /// Media player horizontal layout dimensions (v8.1.5 redesign)
    /// Wider but shorter for horizontal album art + controls layout
    private let mediaPlayerExpandedWidth: CGFloat = 480
    /// Content height matching shelf pattern exactly (SSOT: uses NotchLayoutConstants):
    /// DI/external mode: 100pt (album) + 20pt top + 20pt bottom = 140pt
    /// Built-in notch mode: 100pt + notchHeight (top) + 20pt (bottom) = totalHeight varies
    private let mediaPlayerContentHeight: CGFloat = 140
    
    /// Fixed wing sizes (area left/right of notch for content)  
    /// Using fixed sizes ensures consistent content positioning across all screen resolutions
    private let volumeWingWidth: CGFloat = 120  // For volume/brightness - wide for icon + label + slider
    private let batteryWingWidth: CGFloat = 55  // For battery icon + percentage  
    private let mediaWingWidth: CGFloat = 50    // For album art + visualizer
    
    /// HUD dimensions calculated as notchWidth + (2 * wingWidth)
    /// This ensures wings are FIXED size regardless of notch size
    /// Volume and Brightness use IDENTICAL widths for visual consistency
    private var volumeHudWidth: CGFloat {
        // External monitors (both island and notch mode): use compact 260pt
        // Built-in MacBook notch: use wide layout for proper fit around physical notch
        if isExternalDisplay || isDynamicIslandMode {
            return 260  // Compact width for external/island mode
        }
        return notchWidth + (volumeWingWidth * 2) + 20  // Wide for built-in notch
    }
    
    /// Brightness HUD - same width as Volume for visual consistency
    private var brightnessHudWidth: CGFloat {
        // External monitors (both island and notch mode): use compact 260pt
        // Built-in MacBook notch: use wide layout
        if isExternalDisplay || isDynamicIslandMode {
            return 260  // Compact width for external/island mode
        }
        return notchWidth + (volumeWingWidth * 2) + 20  // Wide for built-in notch
    }
    
    /// Returns appropriate HUD width based on current hudType
    /// Note: Both types now use same width for consistency
    private var currentHudTypeWidth: CGFloat {
        hudType == .brightness ? brightnessHudWidth : volumeHudWidth
    }
    
    /// Battery HUD - slightly narrower wings
    private var batteryHudWidth: CGFloat {
        if isDynamicIslandMode {
            return 100  // Compact for Dynamic Island
        }
        return notchWidth + (batteryWingWidth * 2)
    }
    
    /// Media HUD - compact wings for album art / visualizer
    private var hudWidth: CGFloat {
        if isDynamicIslandMode {
            return 260  // Smaller for Dynamic Island
        }
        return notchWidth + (mediaWingWidth * 2)
    }
    private let hudHeight: CGFloat = 73
    
    /// Whether media player HUD should be shown
    private var shouldShowMediaHUD: Bool {
        // Media features require macOS 15.0+
        guard musicManager.isMediaAvailable else { return false }
        
        // FORCED MODE: Show if user swiped to show media, regardless of playback state
        // (as long as there's a track to show)
        if musicManager.isMediaHUDForced && !musicManager.isPlayerIdle {
            // Don't show if other HUDs have priority
            if HUDManager.shared.isVisible || hudIsVisible { return false }
            if isExpandedOnThisScreen { return false }
            return showMediaPlayer
        }
        
        // Don't show during song transitions (collapse-expand effect)
        if isSongTransitioning { return false }
        // Don't show if auto-fade is enabled and it has faded out
        if autoFadeMediaHUD && mediaHUDFadedOut {
            return false
        }
        // Only apply debounce check when setting is enabled
        if debounceMediaChanges && !isMediaStable { return false }
        // Don't show when any HUD is visible (they take priority)
        if HUDManager.shared.isVisible { return false }
        return showMediaPlayer && musicManager.isPlaying && !hudIsVisible && !isExpandedOnThisScreen
    }
    
    /// Current notch width based on state
    private var currentNotchWidth: CGFloat {
        // When temporarily hidden, shrink to 0 (same animation as collapse)
        if notchController.isTemporarilyHidden {
            return 0
        }
        
        if isExpandedOnThisScreen && enableNotchShelf {
            return expandedWidth
        } else if hudIsVisible {
            return currentHudTypeWidth  // Content-based width (Brightness is wider than Volume)
        } else if HUDManager.shared.isLockScreenHUDVisible && enableLockScreenHUD {
            return batteryHudWidth  // Lock Screen HUD uses same width as battery HUD
        } else if HUDManager.shared.isAirPodsHUDVisible && enableAirPodsHUD {
            return hudWidth  // AirPods HUD uses same width as Media HUD
        } else if HUDManager.shared.isBatteryHUDVisible && enableBatteryHUD {
            return batteryHudWidth  // Battery HUD uses slightly narrower width than volume
        } else if HUDManager.shared.isCapsLockHUDVisible && enableCapsLockHUD {
            return batteryHudWidth  // Caps Lock HUD uses same width as battery HUD
        } else if HUDManager.shared.isDNDHUDVisible && enableDNDHUD {
            return batteryHudWidth  // Focus/DND HUD uses same width as battery HUD
        } else if aiAgentMonitor.isActive && aiAgentMonitor.isEnabled {
            return batteryHudWidth  // AI Agent HUD uses same width as battery HUD
        } else if shouldShowMediaHUD {
            return hudWidth  // Media HUD uses tighter wings
        } else if enableNotchShelf && isHoveringOnThisScreen {
            // Only expand on mouse hover, NOT when dragging files (prevents sliding animation)
            return notchWidth + 20
        } else {
            return notchWidth
        }
    }
    
    /// Current notch height based on state
    private var currentNotchHeight: CGFloat {
        // When temporarily hidden, shrink to 0 (same animation as collapse)
        if notchController.isTemporarilyHidden {
            return 0
        }
        
        if isExpandedOnThisScreen && enableNotchShelf {
            return currentExpandedHeight
        } else if hudIsVisible {
            // Volume/Brightness HUD: ONLY expand horizontally, never taller
            return notchHeight
        } else if HUDManager.shared.isLockScreenHUDVisible && enableLockScreenHUD {
            return notchHeight  // Lock Screen HUD just uses notch height
        } else if HUDManager.shared.isAirPodsHUDVisible && enableAirPodsHUD {
            // AirPods HUD stays at notch height like media player (horizontal expansion only)
            return notchHeight
        } else if HUDManager.shared.isBatteryHUDVisible && enableBatteryHUD {
            return notchHeight  // Battery HUD just uses notch height (no slider)
        } else if HUDManager.shared.isCapsLockHUDVisible && enableCapsLockHUD {
            return notchHeight  // Caps Lock HUD just uses notch height (no slider)
        } else if HUDManager.shared.isDNDHUDVisible && enableDNDHUD {
            return notchHeight  // Focus/DND HUD just uses notch height (no slider)
        } else if shouldShowMediaHUD {
            // No vertical expansion on media HUD hover - just stay at notch height
            return notchHeight
        } else if enableNotchShelf && (isHoveringOnThisScreen || dragMonitor.isDragging) {
            // No vertical expansion on hover - just stay at notch height
            return notchHeight
        } else {
            return notchHeight
        }
    }
    
    private var currentExpandedHeight: CGFloat {
        // TERMINAL: Expanded height when terminal has output
        if terminalManager.isInstalled && terminalManager.isVisible {
            // Base height for terminal (taller than media player to fit content)
            let baseTerminalHeight: CGFloat = 180
            // SSOT: Use contentLayoutNotchHeight for consistent sizing
            // Same logic as media player: delta = notchHeight - 20 for built-in notch mode
            let topPaddingDelta: CGFloat = contentLayoutNotchHeight == 0 ? 0 : (contentLayoutNotchHeight - 20)
            let terminalHeight = baseTerminalHeight + topPaddingDelta
            
            // Height stays constant - no expansion when output is present
            return terminalHeight
        }
        
        // Determine if we're showing media player or shelf
        let shouldShowMediaPlayer = musicManager.isMediaHUDForced || 
            ((musicManager.isPlaying || musicManager.wasRecentlyPlaying) && !musicManager.isMediaHUDHidden && state.shelfDisplaySlotCount == 0)
        
        // MEDIA PLAYER: Content height based on layout
        if showMediaPlayer && shouldShowMediaPlayer && !musicManager.isPlayerIdle {
            // SSOT: Use contentLayoutNotchHeight for consistent sizing
            // DI/external mode: 20 (top) + 100 (album) + 20 (bottom) = 140pt (no delta)
            // Built-in notch mode: notchHeight (top) + 100 (album) + 20 (bottom) = notchHeight + 120
            // Delta from base 140: notchHeight - 20
            let topPaddingDelta: CGFloat = contentLayoutNotchHeight == 0 ? 0 : (contentLayoutNotchHeight - 20)
            return mediaPlayerContentHeight + topPaddingDelta
        }
        
        // SHELF: DYNAMIC height (grows with files up to max 3 rows)
        // Beyond 3 rows, ScrollView handles the overflow
        // Use shelfDisplaySlotCount for correct row count (collapsed stacks = 1 slot)
        let rowCount = (Double(state.shelfDisplaySlotCount) / 5.0).rounded(.up)
        let cappedRowCount = min(rowCount, 3)  // Max 3 rows visible, scroll for rest
        let baseHeight = max(1, cappedRowCount) * 110 // 110 per row, no header
        
        // In built-in notch mode, add extra height to compensate for top padding that clears physical notch
        // Island mode and external displays don't need this as they use symmetrical layout
        // SSOT: Use contentLayoutNotchHeight for consistent sizing
        let notchCompensation: CGFloat = contentLayoutNotchHeight
        return baseHeight + notchCompensation
    }
    /// Helper to check if current screen is built-in (MacBook display)
    private var isBuiltInDisplay: Bool {
        // Use target screen or fallback to built-in
        guard let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return true }
        return screen.isBuiltIn
    }
    
    private var shouldShowVisualNotch: Bool {
        // Always show when HUD is active (volume/brightness) - works independently of shelf
        if hudIsVisible { return true }
        
        // DYNAMIC ISLAND MODE: Only show when there's something to display
        if isDynamicIslandMode {
            // Show when music is playing (but NOT if auto-fade is enabled and it has faded out)
            if musicManager.isPlaying && showMediaPlayer && musicManager.isMediaAvailable {
                // If auto-fade is enabled and HUD has faded out, hide the entire island
                if autoFadeMediaHUD && mediaHUDFadedOut {
                    // Don't show just for music - let user hover to reveal
                } else {
                    return true
                }
            }
            // Shelf-specific triggers only apply when shelf is enabled
            if enableNotchShelf {
                // Show when hovering (to access shelf) - SCREEN-SPECIFIC
                if isHoveringOnThisScreen || state.isDropTargeted { return true }
                // Show when dragging files
                if dragMonitor.isDragging { return true }
                // Show when expanded
                if isExpandedOnThisScreen { return true }
            }
            // Show when any HUD is visible (using centralized HUDManager)
            if HUDManager.shared.isVisible { return true }
            // Otherwise hide - Dynamic Island is invisible when idle
            return false
        }
        
        // NOTCH MODE: Legacy behavior - notch is always visible to cover camera
        // Always show when music is playing
        if shouldShowMediaHUD { return true }
        
        // Shelf-specific triggers only apply when shelf is enabled
        if enableNotchShelf {
            if isExpandedOnThisScreen { return true }
            if dragMonitor.isDragging || isHoveringOnThisScreen || state.isDropTargeted { return true }
        }
        
        // Hide on external displays when setting is enabled (static state only)
        if hideNotchOnExternalDisplays && !isBuiltInDisplay {
            return false
        }
        
        // Show idle notch only if shelf is enabled
        return enableNotchShelf
    }
    
    /// Returns appropriate shape for current mode
    @ViewBuilder
    private func shelfBackgroundShape(radius: CGFloat) -> some View {
        if isDynamicIslandMode {
            DynamicIslandShape(cornerRadius: 50) // Full capsule effect
                .fill(Color.black)
        } else {
            NotchShape(bottomRadius: radius)
                .fill(Color.black)
        }
    }
    
    // MARK: - Personality Views
    
    /// Idle face when shelf is empty
    @ViewBuilder
    private var idleFaceContent: some View {
        let shelfIsEmpty = state.items.isEmpty
        let isShowingMediaPlayer = musicManager.isMediaHUDForced && !musicManager.isMediaHUDHidden && !musicManager.isPlayerIdle
        let shouldShow = enableIdleFace && isExpandedOnThisScreen && shelfIsEmpty && !isShowingMediaPlayer
        
        if shouldShow {
            NotchFace(size: 40)
                .transition(.scale(scale: 0.5).combined(with: .opacity).animation(DroppyAnimation.hoverBouncy))
                .zIndex(1)
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            shelfContent
            
            // Floating buttons (Bottom Centered)
            // Terminal button: Shows when expanded AND terminal installed (regardless of sticky mode)
            // Close/Terminal-close button: In sticky mode OR when terminal is visible
            if enableNotchShelf && isExpandedOnThisScreen && (terminalManager.isInstalled || !autoCollapseShelf) {
                HStack(spacing: 12) {
                    // Terminal button (if extension installed)
                    if terminalManager.isInstalled {
                        // Open in Terminal.app button (only when terminal is visible)
                        if terminalManager.isVisible {
                            Button(action: {
                                terminalManager.openInTerminalApp()
                            }) {
                                Image(systemName: "arrow.up.forward.app")
                            }
                            .buttonStyle(DroppyCircleButtonStyle(size: 32, useTransparent: isDynamicIslandMode, solidFill: isDynamicIslandMode ? dynamicIslandGray : .black))
                            .help("Open in Terminal.app")
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                            
                            if !terminalManager.lastOutput.isEmpty {
                                Button(action: {
                                    terminalManager.clearOutput()
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                }
                                .buttonStyle(DroppyCircleButtonStyle(size: 32, useTransparent: isDynamicIslandMode, solidFill: isDynamicIslandMode ? dynamicIslandGray : .black))
                                .help("Clear terminal output")
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                            }
                        }
                        // Toggle terminal button (shows terminal icon when hidden, X when visible)
                        Button(action: {
                            withAnimation(DroppyAnimation.listChange) {
                                terminalManager.toggle()
                            }
                        }) {
                            Image(systemName: terminalManager.isVisible ? "xmark" : "terminal")
                        }
                        .buttonStyle(DroppyCircleButtonStyle(size: 32, useTransparent: isDynamicIslandMode, solidFill: isDynamicIslandMode ? dynamicIslandGray : .black))
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                    
                    // Close button (only in sticky mode AND when terminal is not visible)
                    if !autoCollapseShelf && !terminalManager.isVisible {
                        Button(action: {
                            withAnimation(DroppyAnimation.listChange) {
                                state.expandedDisplayID = nil
                                state.hoveringDisplayID = nil  // Clear hover on all screens when closing
                            }
                        }) {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(DroppyCircleButtonStyle(size: 32, useTransparent: isDynamicIslandMode, solidFill: isDynamicIslandMode ? dynamicIslandGray : .black))
                    }
                }
                // Position exactly below the expanded content using SSOT gap
                // NOTE: In notch mode, currentExpandedHeight includes top padding compensation which
                // naturally pushes buttons lower. Island mode needs extra offset from SSOT to match.
                .offset(y: currentExpandedHeight + NotchLayoutConstants.floatingButtonGap + (isDynamicIslandMode ? NotchLayoutConstants.floatingButtonIslandCompensation : 0))
                // CRITICAL: Track hover on floating buttons to prevent auto-collapse
                // when user moves from shelf content to floating button
                .onHover { isHovering in
                    isHoveringExpandedContent = isHovering
                    if isHovering {
                        cancelAutoShrinkTimer()
                    } else {
                        startAutoShrinkTimer()
                    }
                }
                .opacity(notchController.isTemporarilyHidden ? 0 : 1)
                .scaleEffect(notchController.isTemporarilyHidden ? 0.5 : 1)
                .animation(DroppyAnimation.notchState, value: notchController.isTemporarilyHidden)
                .zIndex(100)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

        }
    }

    var shelfContent: some View {
        shelfContentWithObservers
    }
    
    // MARK: - Shelf Content (Split to avoid type-checker timeout)
    
    private var shelfContentBase: some View {
        ZStack(alignment: .top) {
            morphingBackground
            contentOverlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // PREMIUM: compositingGroup() renders all content as a single composited image
        // This ensures background + content animate together as one unified object
        .compositingGroup()
        // PREMIUM: Asymmetric animation - bouncy open, critically damped close
        .animation(state.isExpanded ? DroppyAnimation.expandOpen : DroppyAnimation.expandClose, value: state.isExpanded)
        // PREMIUM: Fast notch state animation (.spring.speed(1.2))
        .animation(DroppyAnimation.notchState, value: notchController.isTemporarilyHidden)
        .animation(DroppyAnimation.notchState, value: showMediaPlayer)
        // PREMIUM: DroppyAnimation.viewChange for content view changes
        .animation(DroppyAnimation.viewChange, value: mediaHUDFadedOut)
    }
    
    private var shelfContentWithItemObservers: some View {
        shelfContentBase
            .onChange(of: state.shelfDisplaySlotCount) { oldCount, newCount in
                // NOTE: Auto-expand removed - drop handlers now explicitly expand the correct display
                // This prevents multiple screens from racing to expand when items are added
                
                // Auto-collapse when shelf becomes TRULY empty
                // Check both slot count AND actual arrays to avoid false positives during item moves
                let isTrulyEmpty = state.shelfStacks.isEmpty && state.shelfPowerFolders.isEmpty
                if newCount == 0 && state.isExpanded && isTrulyEmpty {
                    withAnimation(DroppyAnimation.expandClose) {
                        state.expandedDisplayID = nil
                    }
                }
            }
            .onChange(of: dragMonitor.isDragging) { _, isDragging in
                if showMediaPlayer && musicManager.isPlaying && !isExpandedOnThisScreen {
                    withAnimation(DroppyAnimation.state) {
                        mediaHUDIsHovered = isDragging
                    }
                }
            }
            // PREMIUM: Reset hover scale when expanding (smooth transition)
            .onChange(of: isExpandedOnThisScreen) { _, isExpanded in
                if isExpanded {
                    hoverScaleActive = false
                }
            }
    }
    
    private var shelfContentWithHUDObservers: some View {
        shelfContentWithItemObservers
            .onChange(of: volumeManager.lastChangeAt) { _, _ in
                guard enableHUDReplacement, !isExpandedOnThisScreen else { return }
                triggerVolumeHUD()
            }
            .onChange(of: brightnessManager.lastChangeAt) { _, _ in
                guard enableHUDReplacement, !isExpandedOnThisScreen else { return }
                triggerBrightnessHUD()
            }
            .onChange(of: batteryManager.lastChangeAt) { _, _ in
                guard enableBatteryHUD, !isExpandedOnThisScreen else { return }
                triggerBatteryHUD()
            }
            .onChange(of: capsLockManager.lastChangeAt) { _, _ in
                guard enableCapsLockHUD, !isExpandedOnThisScreen else { return }
                triggerCapsLockHUD()
            }
            .onChange(of: airPodsManager.lastConnectionAt) { _, _ in
                guard enableAirPodsHUD, !isExpandedOnThisScreen else { return }
                triggerAirPodsHUD()
            }
            .onChange(of: lockScreenManager.lastChangeAt) { _, _ in
                guard enableLockScreenHUD, !isExpandedOnThisScreen else { return }
                triggerLockScreenHUD()
            }
            .onChange(of: dndManager.lastChangeAt) { _, _ in
                guard enableDNDHUD, !isExpandedOnThisScreen else { return }
                triggerDNDHUD()
            }
    }
    
    private var shelfContentWithMediaObservers: some View {
        shelfContentWithHUDObservers
            .onChange(of: musicManager.songTitle) { oldTitle, newTitle in
                if !oldTitle.isEmpty && !newTitle.isEmpty && oldTitle != newTitle {
                    withAnimation(DroppyAnimation.hover) {
                        isSongTransitioning = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(DroppyAnimation.state) {
                            isSongTransitioning = false
                        }
                    }
                    // Reset marquee scroll for new song
                    sharedMarqueeStartTime = Date()
                }
                if !newTitle.isEmpty {
                    mediaHUDFadedOut = false
                    startMediaFadeTimer()
                }
            }
            .onChange(of: musicManager.isPlaying) { wasPlaying, isPlaying in
                if isPlaying && !wasPlaying {
                    mediaHUDFadedOut = false
                    musicManager.isMediaHUDForced = false
                    musicManager.isMediaHUDHidden = false
                    mediaDebounceWorkItem?.cancel()
                    isMediaStable = false
                    let workItem = DispatchWorkItem { [self] in
                        withAnimation(DroppyAnimation.listChange) {
                            isMediaStable = true
                        }
                    }
                    mediaDebounceWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
                    startMediaFadeTimer()
                }
                if !isPlaying && wasPlaying {
                    mediaDebounceWorkItem?.cancel()
                    isMediaStable = false
                }
            }
            .onChange(of: autoFadeMediaHUD) { wasEnabled, isEnabled in
                if isEnabled && !wasEnabled {
                    if musicManager.isPlaying && showMediaPlayer {
                        startMediaFadeTimer()
                    }
                } else if !isEnabled && wasEnabled {
                    mediaFadeWorkItem?.cancel()
                    withAnimation(DroppyAnimation.listChange) {
                        mediaHUDFadedOut = false
                    }
                }
            }
    }
    
    private var shelfContentWithObservers: some View {
        shelfContentWithMediaObservers
            .onChange(of: state.expandedDisplayID) { oldDisplayID, newDisplayID in
                let thisDisplayID = targetScreen?.displayID
                let wasExpandedOnThis = oldDisplayID == thisDisplayID
                let isExpandedOnThis = newDisplayID == thisDisplayID
                
                if isExpandedOnThis && !wasExpandedOnThis {
                    startAutoShrinkTimer()
                } else if wasExpandedOnThis && !isExpandedOnThis {
                    cancelAutoShrinkTimer()
                    isHoveringExpandedContent = false
                    mediaHUDIsHovered = false
                    musicManager.isMediaHUDForced = false
                    musicManager.isMediaHUDHidden = false
                }
            }
            .onChange(of: isHoveringOnThisScreen) { wasHovering, isHovering in
                if wasHovering && !isHovering && isExpandedOnThisScreen && !isHoveringExpandedContent {
                    startAutoShrinkTimer()
                }
            }
            .background {
                Button("") {
                    if state.isExpanded {
                        state.selectAll()
                        state.selectAllStacks()
                    }
                }
                .keyboardShortcut("a", modifiers: .command)
                .opacity(0)
            }
    }
    // MARK: - HUD Overlay Content (Legacy - now embedded in notch)
    // Kept for reference but no longer used
    
    // MARK: - HUD Helper Functions
    
    private func triggerVolumeHUD() {
        hudWorkItem?.cancel()
        hudType = .volume
        // Show 0% when muted to display muted icon, otherwise show actual volume
        hudValue = volumeManager.isMuted ? 0 : CGFloat(volumeManager.rawVolume)
        withAnimation(DroppyAnimation.state) {
            hudIsVisible = true
            // Reset hover states to prevent layout shift when HUD appears
            state.hoveringDisplayID = nil  // Clear hover on all screens
            mediaHUDIsHovered = false
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(DroppyAnimation.viewChange) {
                hudIsVisible = false
            }
        }
        hudWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + volumeManager.visibleDuration, execute: workItem)
    }
    
    private func triggerBrightnessHUD() {
        hudWorkItem?.cancel()
        hudType = .brightness
        hudValue = CGFloat(brightnessManager.rawBrightness)
        withAnimation(DroppyAnimation.state) {
            hudIsVisible = true
            // Reset hover states to prevent layout shift when HUD appears
            state.hoveringDisplayID = nil  // Clear hover on all screens
            mediaHUDIsHovered = false
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(DroppyAnimation.viewChange) {
                hudIsVisible = false
            }
        }
        hudWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + brightnessManager.visibleDuration, execute: workItem)
    }
    
    private func triggerBatteryHUD() {
        // Use centralized HUDManager for queue-based display
        HUDManager.shared.show(.battery, duration: batteryManager.visibleDuration)
    }
    
    private func triggerCapsLockHUD() {
        // Use centralized HUDManager for queue-based display
        HUDManager.shared.show(.capsLock, duration: capsLockManager.visibleDuration)
    }
    
    private func triggerAirPodsHUD() {
        // Use centralized HUDManager for queue-based display
        HUDManager.shared.show(.airPods, duration: airPodsManager.visibleDuration)
    }
    
    private func triggerLockScreenHUD() {
        // Use centralized HUDManager for queue-based display
        HUDManager.shared.show(.lockScreen, duration: lockScreenManager.visibleDuration)
    }
    
    private func triggerDNDHUD() {
        // Use centralized HUDManager for queue-based display
        HUDManager.shared.show(.dnd, duration: dndManager.visibleDuration)
    }
    
    private func startMediaFadeTimer() {
        // Only start timer if auto-fade is enabled
        guard autoFadeMediaHUD else { return }
        
        // Cancel any existing timer
        mediaFadeWorkItem?.cancel()
        
        // Start 5-second timer to fade out media HUD
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.4)) {
                mediaHUDFadedOut = true
            }
        }
        mediaFadeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }
    
    // MARK: - Auto-Shrink Timer
    
    /// Starts the auto-shrink timer when the shelf is expanded
    private func startAutoShrinkTimer() {
        // Check if auto-collapse is enabled (new toggle)
        guard autoCollapseShelf else { return }
        guard isExpandedOnThisScreen else { return }
        
        // Cancel any existing timer
        autoShrinkWorkItem?.cancel()
        
        // Start timer to auto-shrink shelf
        let workItem = DispatchWorkItem { [self] in
            // Only shrink if still expanded and not hovering over the content
            // Check both local hover state AND screen-specific mouse hover
            guard isExpandedOnThisScreen && !isHoveringExpandedContent && !isHoveringOnThisScreen && !state.isDropTargeted else { return }
            
            // CRITICAL: Don't auto-shrink if a context menu is open
            let hasActiveMenu = NSApp.windows.contains { $0.level.rawValue >= NSWindow.Level.popUpMenu.rawValue }
            guard !hasActiveMenu else { return }
            
            withAnimation(DroppyAnimation.listChange) {
                state.expandedDisplayID = nil  // Collapse shelf on all screens
                state.hoveringDisplayID = nil  // Reset hover state to go directly to regular notch
            }
        }
        autoShrinkWorkItem = workItem
        
        // Use 5 seconds when items are in shelf (more time to interact), otherwise use user's setting
        let delay: Double = state.items.isEmpty ? autoCollapseDelay : 5.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    /// Resets the auto-shrink timer (called when mouse enters the notch area)
    private func resetAutoShrinkTimer() {
        autoShrinkWorkItem?.cancel()
        startAutoShrinkTimer()
    }
    
    /// Cancels the auto-shrink timer (called when hovering over the notch)
    private func cancelAutoShrinkTimer() {
        autoShrinkWorkItem?.cancel()
    }
    
    // MARK: - Glow Effect
    
    // Old glowEffect removed


    // MARK: - Content Overlay
    
    /// Extracted from shelfContent to reduce type-checker complexity
    private var contentOverlay: some View {
        ZStack(alignment: .top) {
            // Always have the drop zone / interaction layer at the top
            // BUT disable hit testing when expanded so slider/buttons can receive gestures
            dropZone
                .zIndex(1)
                .allowsHitTesting(!isExpandedOnThisScreen)
            
            // MARK: - HUD Views
            hudContent
            
            // MARK: - Media Player HUD
            mediaPlayerHUD
            
            // MARK: - Expanded Shelf Content
            if isExpandedOnThisScreen && enableNotchShelf {
                expandedShelfContent
                    // PREMIUM: Scale(0.8, anchor: .top) + opacity transition - matches swipe feel
                    .notchTransition()
                    .frame(width: expandedWidth, height: currentExpandedHeight)
                    // PREMIUM: Unified .smooth(0.35) for ALL state changes
                    .animation(.smooth(duration: 0.35), value: currentExpandedHeight)
                    .animation(.smooth(duration: 0.35), value: musicManager.isMediaHUDForced)
                    .animation(.smooth(duration: 0.35), value: musicManager.isMediaHUDHidden)
                    .clipShape(isDynamicIslandMode ? AnyShape(DynamicIslandShape(cornerRadius: 40)) : AnyShape(NotchShape(bottomRadius: 40)))
                    .geometryGroup()
                    .zIndex(2)
            }
            
            // MARK: - Morphing Album Art Overlay (Droppy Proxy Pattern)
            // CRITICAL: This is the SINGLE album art that morphs between HUD and expanded states.
            // Both MediaHUDView and MediaPlayerView hide their internal album art (showAlbumArt: false)
            // and this overlay provides the smooth morphing animation.
            morphingAlbumArtOverlay
                .zIndex(10)  // Above all content for smooth morphing visibility
            
            // MARK: - Morphing Visualizer Overlay (Droppy Proxy Pattern)
            // Same approach as album art - single visualizer that morphs position
            morphingVisualizerOverlay
                .zIndex(11)  // Above album art for visibility
            
            // MARK: - Morphing Title Overlay (Droppy Proxy Pattern)
            // Same approach - single title that morphs from HUD to expanded position
            morphingTitleOverlay
                .zIndex(12)  // Above visualizer for visibility
        }
        .opacity(notchController.isTemporarilyHidden ? 0 : 1)
        .frame(width: currentNotchWidth, height: currentNotchHeight)
        .mask {
            Group {
                if isDynamicIslandMode {
                    DynamicIslandShape(cornerRadius: isExpandedOnThisScreen ? 40 : 50)
                } else {
                    NotchShape(bottomRadius: isExpandedOnThisScreen ? 40 : (hudIsVisible ? 18 : 16))
                }
            }
        }
        .padding(.top, isDynamicIslandMode ? dynamicIslandTopMargin : 0)
    }
    
    // MARK: - HUD Content
    
    /// All HUD views (volume, battery, caps lock, DND, AirPods, lock screen)
    @ViewBuilder
    private var hudContent: some View {
        // Volume/Brightness HUD
        if hudIsVisible && enableHUDReplacement && !isExpandedOnThisScreen {
            NotchHUDView(
                hudType: $hudType,
                value: $hudValue,
                isActive: true,
                isMuted: hudType == .volume && volumeManager.isMuted,
                notchWidth: notchWidth,
                notchHeight: notchHeight,
                hudWidth: currentHudTypeWidth,
                targetScreen: targetScreen,
                onValueChange: { newValue in
                    if hudType == .volume {
                        volumeManager.setAbsolute(Float32(newValue))
                    } else {
                        brightnessManager.setAbsolute(value: Float(newValue))
                    }
                }
            )
            .frame(width: currentHudTypeWidth, height: notchHeight)
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(DroppyAnimation.notchState))
            .zIndex(3)
        }
        
        // Battery HUD - uses centralized HUDManager
        if HUDManager.shared.isBatteryHUDVisible && enableBatteryHUD && !hudIsVisible && !isExpandedOnThisScreen {
            BatteryHUDView(
                batteryManager: batteryManager,
                hudWidth: batteryHudWidth,
                targetScreen: targetScreen
            )
            .frame(width: batteryHudWidth, height: notchHeight)
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(DroppyAnimation.notchState))
            .zIndex(4)
        }
        
        // Caps Lock HUD - uses centralized HUDManager
        if HUDManager.shared.isCapsLockHUDVisible && enableCapsLockHUD && !hudIsVisible && !isExpandedOnThisScreen {
            CapsLockHUDView(
                capsLockManager: capsLockManager,
                hudWidth: batteryHudWidth,
                targetScreen: targetScreen
            )
            .frame(width: batteryHudWidth, height: notchHeight)
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(DroppyAnimation.notchState))
            .zIndex(5)
        }
        
        // Focus/DND HUD - uses centralized HUDManager
        if HUDManager.shared.isDNDHUDVisible && enableDNDHUD && !hudIsVisible && !isExpandedOnThisScreen {
            DNDHUDView(
                dndManager: dndManager,
                hudWidth: batteryHudWidth,
                targetScreen: targetScreen
            )
            .frame(width: batteryHudWidth, height: notchHeight)
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(DroppyAnimation.notchState))
            .zIndex(5.5)
        }
        
        // AirPods HUD - uses centralized HUDManager
        if HUDManager.shared.isAirPodsHUDVisible && enableAirPodsHUD && !hudIsVisible && !isExpandedOnThisScreen, let airPods = airPodsManager.connectedAirPods {
            AirPodsHUDView(
                airPods: airPods,
                hudWidth: hudWidth,
                targetScreen: targetScreen
            )
            .frame(width: hudWidth, height: notchHeight)
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(DroppyAnimation.notchState))
            .zIndex(6)
        }
        
        // Lock Screen HUD - uses centralized HUDManager
        if HUDManager.shared.isLockScreenHUDVisible && enableLockScreenHUD && !hudIsVisible && !isExpandedOnThisScreen {
            LockScreenHUDView(
                lockScreenManager: lockScreenManager,
                hudWidth: batteryHudWidth,
                targetScreen: targetScreen
            )
            .frame(width: batteryHudWidth, height: notchHeight)
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(DroppyAnimation.notchState))
            .zIndex(7)
        }

        // AI Agent HUD - shows when an AI coding agent is active
        if aiAgentMonitor.isActive && aiAgentMonitor.isEnabled && !hudIsVisible && !isExpandedOnThisScreen {
            AIAgentHUDView(
                manager: aiAgentMonitor,
                hudWidth: batteryHudWidth,
                targetScreen: targetScreen
            )
            .frame(width: batteryHudWidth, height: notchHeight)
            // Instantly hide when expanding to prevent position artifacts during transition
            .opacity(isExpandedOnThisScreen ? 0 : 1)
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(DroppyAnimation.notchState))
            .zIndex(8)
        }
    }

    // MARK: - Media Player HUD
    
    /// Media player mini HUD
    @ViewBuilder
    private var mediaPlayerHUD: some View {
        // Break up complex expressions for type checker
        let noHUDsVisible = !hudIsVisible && !HUDManager.shared.isVisible
        let notExpanded = !isExpandedOnThisScreen
        
        // CRITICAL (Issue #101): Hide media HUD when fullscreen app is active ON THIS DISPLAY
        // Multi-monitor support: Each screen independently tracks its fullscreen state
        let targetDisplayID = targetScreen?.displayID ?? 0
        let notInFullscreen = !notchController.fullscreenDisplayIDs.contains(targetDisplayID)
        
        let shouldShowForced = musicManager.isMediaHUDForced && !musicManager.isPlayerIdle && showMediaPlayer && noHUDsVisible && notExpanded && notInFullscreen
        
        let mediaIsPlaying = musicManager.isPlaying && !musicManager.songTitle.isEmpty
        let notFadedOrTransitioning = !(autoFadeMediaHUD && mediaHUDFadedOut) && !isSongTransitioning
        let debounceOk = !debounceMediaChanges || isMediaStable
        
        // FIX #95: Bypass ALL safeguards when forcing source switch (Spotify fallback)
        // When isMediaSourceForced is true, we know the source is playing (verified via AppleScript)
        let bypassSafeguards = musicManager.isMediaSourceForced
        let hasContent = !musicManager.songTitle.isEmpty
        let shouldShowNormal = showMediaPlayer && noHUDsVisible && notExpanded && notInFullscreen && 
                              (bypassSafeguards ? hasContent : (mediaIsPlaying && notFadedOrTransitioning && debounceOk))
        
        if shouldShowForced || shouldShowNormal {
            // Title morphing is handled by overlay for both DI and notch modes
            MediaHUDView(musicManager: musicManager, isHovered: $mediaHUDIsHovered, notchWidth: notchWidth, notchHeight: notchHeight, hudWidth: hudWidth, targetScreen: targetScreen, albumArtNamespace: albumArtNamespace, showAlbumArt: false, showVisualizer: false, showTitle: false)
                .frame(width: hudWidth, alignment: .top)
                .clipShape(isDynamicIslandMode ? AnyShape(DynamicIslandShape(cornerRadius: 50)) : AnyShape(NotchShape(bottomRadius: 18)))
                // PREMIUM: Opacity transition with .smooth(0.35) for unified feel
                .transition(.opacity.animation(.smooth(duration: 0.35)))
                .zIndex(3)
        }
    }
    // MARK: - Morphing Background
    
    // MARK: - Morphing Album Art Overlay (Droppy Proxy Pattern)
    
    /// Single album art that morphs smoothly between HUD and expanded states.
    /// Uses position and size animation rather than matchedGeometryEffect for reliable morphing.
    @ViewBuilder
    private var morphingAlbumArtOverlay: some View {
        // Only show when media is visible
        let showInHUD = shouldShowMediaHUDForMorphing
        let showInExpanded = shouldShowExpandedMediaPlayerForMorphing
        
        if showInHUD || showInExpanded {
            // Calculate sizes
            let hudSize: CGFloat = isDynamicIslandMode ? 18 : 20
            let expandedSize: CGFloat = 100
            let currentSize = isExpandedOnThisScreen ? expandedSize : hudSize
            
            // Calculate corner radii
            let hudCornerRadius: CGFloat = isDynamicIslandMode ? hudSize / 2 : 5
            let expandedCornerRadius: CGFloat = 18
            let currentCornerRadius = isExpandedOnThisScreen ? expandedCornerRadius : hudCornerRadius
            
            // Calculate position offsets based on contentOverlay frame
            // contentOverlay is framed at currentNotchWidth x currentNotchHeight
            // For HUD mode we use FIXED dimensions to prevent jumping on hover
            
            // HUD X position: Album art at left edge with symmetricPadding inset
            // Use FIXED HUD container width to prevent jumping during transitions
            let hudSymmetricPadding: CGFloat = isDynamicIslandMode ? (notchHeight - hudSize) / 2 : max((notchHeight - hudSize) / 2, 6)
            // In DI mode, use notchHeight as the fixed HUD height. In notch mode, use actual notchHeight.
            let fixedHUDHeight: CGFloat = isDynamicIslandMode ? notchHeight : notchHeight
            let fixedHUDContainerWidth: CGFloat = isDynamicIslandMode ? 260 : (notchWidth + (mediaWingWidth * 2))
            let hudXOffset = -(fixedHUDContainerWidth / 2) + hudSymmetricPadding + (hudSize / 2)
            
            // Expanded X position: Album art at left side with content padding
            let expandedPadding: CGFloat = 20  // NotchLayoutConstants content padding
            let expandedXOffset = -(expandedWidth / 2) + expandedPadding + (expandedSize / 2)
            
            let currentXOffset = isExpandedOnThisScreen ? expandedXOffset : hudXOffset
            
            // Y position: ZStack is .top aligned, so offset moves the view's TOP edge down
            // HUD: Center icon vertically = offset by (containerHeight - iconHeight) / 2
            let hudYOffset = (fixedHUDHeight - hudSize) / 2
            // Expanded: Position album art top edge at content padding position
            // SSOT: Must match NotchLayoutConstants.contentEdgeInsets exactly
            // - DI/external mode: top padding = 20 (contentPadding)
            // - Built-in notch mode: top padding = notchHeight
            let expandedTopPadding: CGFloat = contentLayoutNotchHeight == 0 ? expandedPadding : contentLayoutNotchHeight
            let expandedYOffset = expandedTopPadding
            let currentYOffset = isExpandedOnThisScreen ? expandedYOffset : hudYOffset
            
            // Album art image with Droppy-style interactions
            Group {
                if musicManager.albumArt.size.width > 0 {
                    Image(nsImage: musicManager.albumArt)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: currentCornerRadius)
                        .fill(Color.white.opacity(isExpandedOnThisScreen ? 0.08 : 0.2))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: isExpandedOnThisScreen ? 36 : 10))
                                .foregroundStyle(.white.opacity(isExpandedOnThisScreen ? 0.3 : 0.5))
                        )
                }
            }
            .frame(width: currentSize, height: currentSize)
            .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
            // PREMIUM: Subtle darkening overlay when paused (expanded only)
            .overlay {
                if isExpandedOnThisScreen && !musicManager.isPlaying {
                    RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.25))
                }
            }
            // Spotify badge (bottom-right corner, expanded only) - fades in without sliding
            .overlay {
                ZStack(alignment: .bottomTrailing) {
                    Color.clear
                    SpotifyBadge(size: 24)
                        .offset(x: 5, y: 5)
                        .opacity(isExpandedOnThisScreen && musicManager.isSpotifySource ? 1 : 0)
                        .animation(DroppyAnimation.state, value: isExpandedOnThisScreen)
                        .animation(DroppyAnimation.state, value: musicManager.isSpotifySource)
                }
            }
            .shadow(color: isExpandedOnThisScreen ? .black.opacity(0.3) : .clear, radius: 8, y: 4)
            // PREMIUM: Cursor-following parallax - MUST be applied BEFORE offset to track correct position
            .onContinuousHover { phase in
                guard isExpandedOnThisScreen else {
                    albumArtParallaxOffset = .zero
                    return
                }
                switch phase {
                case .active(let location):
                    // Calculate offset from center (album art is currentSize x currentSize)
                    let centerX = currentSize / 2
                    let centerY = currentSize / 2
                    let deltaX = location.x - centerX
                    let deltaY = location.y - centerY
                    // Subtle parallax: max ±4pt shift
                    let maxOffset: CGFloat = 4
                    let parallaxX = (deltaX / centerX) * maxOffset
                    let parallaxY = (deltaY / centerY) * maxOffset
                    albumArtParallaxOffset = CGSize(width: parallaxX, height: parallaxY)
                case .ended:
                    albumArtParallaxOffset = .zero
                }
            }
            // PREMIUM: Subtle shrink when paused (0.95x scale), grow on tap (1.08x)
            // Tap scale is multiplied to combine with pause shrink
            .scaleEffect((isExpandedOnThisScreen && !musicManager.isPlaying ? 0.95 : 1.0) * albumArtTapScale)
            // PREMIUM: Nudge animation on prev/next/play (±6pt horizontal shift)
            // PREMIUM: Parallax offset follows cursor for magnetic 'pull' effect
            .offset(
                x: currentXOffset + albumArtNudgeOffset + (isExpandedOnThisScreen ? albumArtParallaxOffset.width : 0),
                y: currentYOffset + (isExpandedOnThisScreen ? albumArtParallaxOffset.height : 0)
            )
            // PREMIUM: Single unified animation for ALL expand/collapse morphing
            // This controls: size, position, cornerRadius, scaleEffect (pause shrink), shadow
            .animation(.smooth(duration: 0.35), value: isExpandedOnThisScreen)
            .animation(.smooth(duration: 0.35), value: musicManager.isPlaying)  // pause shrink matches expand timing
            // INTERACTIVE: User-triggered animations kept separate
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: albumArtNudgeOffset)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.7), value: albumArtParallaxOffset.width)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.7), value: albumArtParallaxOffset.height)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.5), value: albumArtTapScale)
            // PREMIUM: Scale+opacity appear animation (same as MediaPlayerView controls)
            .scaleEffect(mediaOverlayAppeared ? 1.0 : 0.8, anchor: .top)
            .opacity(mediaOverlayAppeared ? 1.0 : 0)
            .animation(.smooth(duration: 0.35), value: mediaOverlayAppeared)
            .onAppear {
                // UNIFIED: Immediate animation start - syncs with container notchTransition
                mediaOverlayAppeared = true
            }
            .onDisappear {
                mediaOverlayAppeared = false
            }
            // UNIFIED: Re-trigger animation when swiping between shelf and media
            .onChange(of: musicManager.isMediaHUDForced) { _, _ in
                // Animate out then in
                mediaOverlayAppeared = false
                withAnimation(.smooth(duration: 0.35)) {
                    mediaOverlayAppeared = true
                }
            }
            .onChange(of: musicManager.isMediaHUDHidden) { _, _ in
                mediaOverlayAppeared = false
                withAnimation(.smooth(duration: 0.35)) {
                    mediaOverlayAppeared = true
                }
            }
            // NOTE: No onChange for isExpandedOnThisScreen - overlays morph position, they don't hide/show
            // The morphing overlays stay visible and smoothly animate between HUD ↔ expanded positions
            .geometryGroup()  // Bundle as single element for smooth morphing
            // Click to open source app (expanded only) with subtle grow effect
            .onTapGesture {
                guard isExpandedOnThisScreen else { return }
                // Subtle grow effect on tap
                albumArtTapScale = 1.08
                // Open the source app
                musicManager.openMusicApp()
                // Spring back after grow
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    albumArtTapScale = 1.0
                }
            }
            // Nudge on track skip
            .onChange(of: musicManager.lastSkipDirection) { _, direction in
                guard direction != .none else { return }
                let nudgeAmount: CGFloat = direction == .forward ? 6 : -6
                albumArtNudgeOffset = nudgeAmount
                // Spring back after nudge
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    albumArtNudgeOffset = 0
                }
            }
        }
    }
    
    // MARK: - Morphing Visualizer Overlay (Droppy Proxy Pattern)
    
    /// Single visualizer that morphs smoothly between HUD and expanded states.
    @ViewBuilder
    private var morphingVisualizerOverlay: some View {
        let showInHUD = shouldShowMediaHUDForMorphing
        let showInExpanded = shouldShowExpandedMediaPlayerForMorphing
        
        if showInHUD || showInExpanded {
            // Calculate sizes
            // HUD: 5 bars * 2.5 width + 4 gaps * 2 spacing = 20.5 width, 18 height
            let hudWidth: CGFloat = 20.5  // 5 bars for both modes
            let hudHeight: CGFloat = 18
            // Expanded: MUST MATCH AudioVisualizerBars exactly: 5 * 3 + 4 * 2 = 23pt
            // (AudioVisualizerBars uses barWidth: 3, spacing: 2 in MediaPlayerComponents.swift)
            let expandedWidth: CGFloat = 23  // 5 bars * 3px + 4 gaps * 2px
            let expandedHeight: CGFloat = 20  // Matches AudioVisualizerBars height
            let currentWidth = isExpandedOnThisScreen ? expandedWidth : hudWidth
            let currentHeight = isExpandedOnThisScreen ? expandedHeight : hudHeight
            
            // Calculate position offsets
            // Use fixed dimensions for HUD to prevent jumping on hover
            let fixedHUDHeight: CGFloat = notchHeight
            let hudSymmetricPadding: CGFloat = isDynamicIslandMode ? (notchHeight - hudHeight) / 2 : max((notchHeight - hudHeight) / 2, 6)
            
            // HUD X: Right side of HUD (mirror of album art position)
            // Use FIXED HUD container width to prevent jumping during transitions
            let fixedHUDContainerWidth: CGFloat = isDynamicIslandMode ? 260 : (notchWidth + (mediaWingWidth * 2))
            let visualizerHudXOffset = (fixedHUDContainerWidth / 2) - hudSymmetricPadding - (hudWidth / 2)
            
            // Expanded X: Align visualizer RIGHT edge with timestamp RIGHT edge
            let expandedPadding: CGFloat = 20
            // Timestamp right edge is at container edge - padding = 450 - 20 = 430pt from left
            // The actual MediaPlayerView frames the visualizer at 28pt but content is only 23pt centered within
            // So visualizer content right edge = frame right edge - (28-23)/2 = frame right - 2.5pt
            // To align content precisely, we need to match where the ACTUAL bars end
            // MediaPlayerView visualizer frame right = 430pt, content right = 430 - 2.5 = 427.5pt
            // Our visualizer is 23pt, so center should be at 427.5 - 11.5 = 416pt from left = 191pt from center
            let frameToContentOffset: CGFloat = 2.5  // MediaPlayerView uses 28pt frame for 23pt content
            let expandedXOffset = (self.expandedWidth / 2) - expandedPadding - (expandedWidth / 2) - frameToContentOffset
            
            let currentXOffset = isExpandedOnThisScreen ? expandedXOffset : visualizerHudXOffset
            
            // Y position: centered in HUD, at top of expanded content (in title row)
            let hudYOffset = (fixedHUDHeight - hudHeight) / 2
            // Expanded: in the title row area, aligned with title text
            // SSOT: Must match NotchLayoutConstants.contentEdgeInsets exactly
            let expandedTopPadding: CGFloat = contentLayoutNotchHeight == 0 ? expandedPadding : contentLayoutNotchHeight
            let expandedYOffset = expandedTopPadding + 1  // +1 to vertically center visualizer with title row
            let currentYOffset = isExpandedOnThisScreen ? expandedYOffset : hudYOffset
            
            // PERFORMANCE: Use cached visualizer color (computed once per track change)
            
            // Use AudioSpectrumView which works for both states
            AudioSpectrumView(
                isPlaying: musicManager.isPlaying,
                barCount: 5,  // Always 5 bars
                barWidth: isExpandedOnThisScreen ? 3 : 2.5,  // Match AudioVisualizerBars (3pt)
                spacing: 2,
                height: currentHeight,
                color: musicManager.visualizerColor  // PERFORMANCE: Cached, not recomputed
            )
            .frame(width: currentWidth, height: currentHeight)
            .offset(x: currentXOffset, y: currentYOffset)
            .animation(.smooth(duration: 0.35), value: isExpandedOnThisScreen)
            // PREMIUM: Scale+opacity appear animation (same as album art)
            .scaleEffect(mediaOverlayAppeared ? 1.0 : 0.8, anchor: .top)
            .opacity(mediaOverlayAppeared ? 1.0 : 0)
            .animation(.smooth(duration: 0.35), value: mediaOverlayAppeared)
            .geometryGroup()  // Bundle as single element for smooth morphing
        }
    }
    
    // MARK: - Morphing Title Overlay (Droppy Proxy Pattern)
    
    /// Single title text that morphs smoothly between HUD and expanded states.
    /// Shows for Dynamic Island mode AND external displays (no physical camera blocking center)
    @ViewBuilder
    private var morphingTitleOverlay: some View {
        // Show title in HUD for DI mode or external displays (no physical notch camera)
        // Built-in notch mode has physical camera blocking center, so title fades in on expand
        if shouldShowTitleInHUD {
            let showInHUD = shouldShowMediaHUDForMorphing
            let showInExpanded = shouldShowExpandedMediaPlayerForMorphing
            
            if showInHUD || showInExpanded {
                // Calculate sizes
                let hudFontSize: CGFloat = 13
                let expandedFontSize: CGFloat = 15
                let currentFontSize = isExpandedOnThisScreen ? expandedFontSize : hudFontSize
                
                // Calculate title width constraints
                // HUD: centered with padding for album art (36pt each side)
                // Expanded: available width after album art + spacing + visualizer
                let hudTitleWidth: CGFloat = 180
                let expandedPadding: CGFloat = 20
                let albumArtSize: CGFloat = 100
                let contentSpacing: CGFloat = 16
                let visualizerWidth: CGFloat = 28
                let expandedTitleWidth: CGFloat = expandedWidth - (expandedPadding * 2) - albumArtSize - contentSpacing - visualizerWidth - 8
                let currentTitleWidth = isExpandedOnThisScreen ? expandedTitleWidth : hudTitleWidth
                
                // Calculate position offsets
                let fixedHUDHeight: CGFloat = notchHeight
                
                // HUD X: Centered in pill container
                let hudXOffset: CGFloat = 0
                
                // Expanded X: After album art + spacing, centered in remaining title area
                let titleLeftEdge = -(expandedWidth / 2) + expandedPadding + albumArtSize + contentSpacing
                let expandedXOffset = titleLeftEdge + (expandedTitleWidth / 2)
                let currentXOffset = isExpandedOnThisScreen ? expandedXOffset : hudXOffset
                
                // Y position
                // HUD: Centered vertically inside pill (+2pt to compensate for text baseline)
                let hudYOffset: CGFloat = ((fixedHUDHeight - 20) / 2) + 2
                
                // SSOT: Must match NotchLayoutConstants.contentEdgeInsets exactly
                // - DI/external mode: top padding = 20 (contentPadding)
                // - Built-in notch mode: top padding = notchHeight
                // Title TOP must align with album art TOP
                let expandedTopPadding: CGFloat = contentLayoutNotchHeight == 0 ? expandedPadding : contentLayoutNotchHeight
                let expandedYOffset: CGFloat = expandedTopPadding  // No offset - title top = album art top
                let currentYOffset = isExpandedOnThisScreen ? expandedYOffset : hudYOffset
                
                // Title text
                let songTitle = musicManager.songTitle.isEmpty ? "Not Playing" : musicManager.songTitle
                
                // Alignment: Centered in HUD, left-aligned in expanded
                let currentAlignment: Alignment = isExpandedOnThisScreen ? .leading : .center
                
                // SMOOTH MORPH: Use shared start time so scroll position is continuous during expand/collapse
                MarqueeText(text: songTitle, speed: 30, externalStartTime: sharedMarqueeStartTime, alignment: currentAlignment)
                    .font(.system(size: currentFontSize, weight: isExpandedOnThisScreen ? .semibold : .medium))
                    .foregroundStyle(.white.opacity(isExpandedOnThisScreen ? 1.0 : 0.9))
                    .frame(width: currentTitleWidth, height: 20, alignment: currentAlignment)
                    .offset(x: currentXOffset, y: currentYOffset)
                    .geometryGroup()  // Bundle as single element for smooth morphing
                    // PREMIUM: Smooth spring animation for morphing (matches album art)
                    .animation(.smooth(duration: 0.35), value: isExpandedOnThisScreen)
                    // PREMIUM: Scale+opacity appear animation (same as album art)
                    .scaleEffect(mediaOverlayAppeared ? 1.0 : 0.8, anchor: .top)
                    .opacity(mediaOverlayAppeared ? 1.0 : 0)
                    .animation(.smooth(duration: 0.35), value: mediaOverlayAppeared)
            }
        }
    }
    
    /// Whether the media HUD should be visible (for morphing calculation)
    private var shouldShowMediaHUDForMorphing: Bool {
        let noHUDsVisible = !hudIsVisible && !HUDManager.shared.isVisible
        let notExpanded = !isExpandedOnThisScreen
        let targetDisplayID = targetScreen?.displayID ?? 0
        let notInFullscreen = !notchController.fullscreenDisplayIDs.contains(targetDisplayID)
        let shouldShowForced = musicManager.isMediaHUDForced && !musicManager.isPlayerIdle && showMediaPlayer && noHUDsVisible && notExpanded && notInFullscreen
        let mediaIsPlaying = musicManager.isPlaying && !musicManager.songTitle.isEmpty
        let notFadedOrTransitioning = !(autoFadeMediaHUD && mediaHUDFadedOut) && !isSongTransitioning
        let debounceOk = !debounceMediaChanges || isMediaStable
        let bypassSafeguards = musicManager.isMediaSourceForced
        let hasContent = !musicManager.songTitle.isEmpty
        let shouldShowNormal = showMediaPlayer && noHUDsVisible && notExpanded && notInFullscreen &&
                              (bypassSafeguards ? hasContent : (mediaIsPlaying && notFadedOrTransitioning && debounceOk))
        return shouldShowForced || shouldShowNormal
    }
    
    /// Whether the expanded media player should be visible (for morphing calculation)
    private var shouldShowExpandedMediaPlayerForMorphing: Bool {
        guard isExpandedOnThisScreen && enableNotchShelf else { return false }
        // TERMINOTCH: Don't show morphing overlays when terminal is visible
        guard !(terminalManager.isInstalled && terminalManager.isVisible) else { return false }
        let dragMonitor = DragMonitor.shared
        return showMediaPlayer && !musicManager.isPlayerIdle && !state.isDropTargeted && !state.isShelfAirDropZoneTargeted && !dragMonitor.isDragging &&
               (musicManager.isMediaHUDForced || 
                ((musicManager.isPlaying || musicManager.wasRecentlyPlaying) && !musicManager.isMediaHUDHidden && state.items.isEmpty))
    }

    // MARK: - Morphing Background
    
    /// Extracted from shelfContent to reduce type-checker complexity
    private var morphingBackground: some View {
        // This is the persistent black shape that grows/shrinks
        // NOTE: The shelf/notch always uses solid black background.
        // The "Transparent Background" setting only applies to other UI elements
        // (Settings, Clipboard, etc.) - not the shelf, as that would look weird.
        // MORPH: Both shapes exist, crossfade with opacity for smooth transition
        ZStack {
            // Dynamic Island shape (pill)
            // When transparent DI is enabled, use glass material instead of gray
            DynamicIslandShape(cornerRadius: isExpandedOnThisScreen ? 40 : 50)
                .fill(shouldUseDynamicIslandTransparent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(dynamicIslandGray))
                .opacity(isDynamicIslandMode ? 1 : 0)
                .scaleEffect(isDynamicIslandMode ? 1 : 0.85)
            
            // Notch shape (U-shaped)
            // Built-in: always black (physical notch is black)
            // External: can be transparent when transparency setting is enabled
            NotchShape(bottomRadius: isExpandedOnThisScreen ? 40 : (hudIsVisible ? 18 : 16))
                .fill(shouldUseExternalNotchTransparent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
                .opacity(isDynamicIslandMode ? 0 : 1)
                .scaleEffect(isDynamicIslandMode ? 0.85 : 1)
        }
        // NOTE: .compositingGroup() removed here - also breaks NSViewRepresentable overlays
        // PREMIUM shadow applied OUTSIDE the ZStack so it follows the clipped shape
        // This ensures proper rounded shadow that respects the shape, not a square
        // NOTE: Shadow is disabled in transparent mode (glass effect doesn't need shadow)
        .background {
            if isDynamicIslandMode && !shouldUseDynamicIslandTransparent {
                // Premium pill shadow for Dynamic Island (only when NOT transparent)
                // Shadow visible when expanded OR hovering (premium depth effect)
                let showShadow = isExpandedOnThisScreen || isHoveringOnThisScreen
                DynamicIslandShape(cornerRadius: isExpandedOnThisScreen ? 40 : 50)
                    .fill(dynamicIslandGray)
                    .shadow(
                        // PREMIUM EXACT: .black.opacity(0.7) radius 6
                        color: showShadow ? Color.black.opacity(0.7) : .clear,
                        radius: 6,
                        x: 0,
                        y: isExpandedOnThisScreen ? 4 : 2
                    )
            } else if !isDynamicIslandMode {
                // PREMIUM: Shadow for notch mode as well
                // Shadow visible when expanded OR hovering (premium depth effect)
                let showShadow = isExpandedOnThisScreen || isHoveringOnThisScreen
                NotchShape(bottomRadius: isExpandedOnThisScreen ? 40 : (hudIsVisible ? 18 : 16))
                    .fill(shouldUseExternalNotchTransparent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
                    .shadow(
                        // PREMIUM EXACT: .black.opacity(0.7) radius 6
                        color: showShadow ? Color.black.opacity(0.7) : .clear,
                        radius: 6,
                        x: 0,
                        y: isExpandedOnThisScreen ? 4 : 2
                    )
            }
        }
        // Add bottom padding to prevent shadow clipping when expanded
        // Shadow extends: radius (12) + y-offset (6) = 18px downward
        .padding(.bottom, isDynamicIslandMode && isExpandedOnThisScreen ? 18 : 0)
        .frame(
            width: currentNotchWidth,
            height: currentNotchHeight + (isDynamicIslandMode && isExpandedOnThisScreen ? 18 : 0)
        )
        .opacity(shouldShowVisualNotch ? 1.0 : 0.0)
        // PREMIUM: Subtle scale feedback on hover - "I'm ready to expand!"
        // Uses dedicated state for clean single-value animation (no two-value dependency)
        .scaleEffect(hoverScaleActive ? 1.02 : 1.0, anchor: .center)
        // PREMIUM: Buttery smooth animation for hover scale (matches Droppy: .bouncy.speed(1.2))
        .animation(DroppyAnimation.hoverBouncy, value: hoverScaleActive)
        // Note: Idle indicator removed - island is now completely invisible when idle
        // Only appears on hover, drag, or when HUDs/media are active
        .overlay(morphingOutline)
        .overlay(aiAgentBorderOverlay)
        // PREMIUM: Single unified .smooth(duration: 0.35) for ALL expand/collapse transitions
        .animation(.smooth(duration: 0.35), value: state.isExpanded)
        .animation(.smooth(duration: 0.35), value: mediaHUDIsHovered)
        .animation(.smooth(duration: 0.35), value: musicManager.isPlaying)
        .animation(.smooth(duration: 0.35), value: isSongTransitioning)
        .animation(.smooth(duration: 0.35), value: state.shelfDisplaySlotCount)
        .animation(.smooth(duration: 0.35), value: useDynamicIslandStyle)
        // INTERACTIVE: Keep bouncy for user-triggered actions
        .animation(DroppyAnimation.hoverBouncy, value: dragMonitor.isDragging)
        .animation(DroppyAnimation.hoverBouncy, value: hudIsVisible)
        .padding(.top, isDynamicIslandMode ? dynamicIslandTopMargin : 0)
        .contextMenu {
            if showClipboardButton {
                Button {
                    ClipboardWindowController.shared.toggle()
                } label: {
                    Label("Open Clipboard", systemImage: "clipboard")
                }
                Divider()
            }
            
            Button {
                SettingsWindowController.shared.showSettings()
            } label: {
                Label("Open Settings", systemImage: "gear")
            }
        }
    }
    
    // MARK: - Morphing Outline (Disabled)
    
    /// Hover indicator removed - clean design without outline
    /// Hover feedback is provided by scale/parallax effects instead
    private var morphingOutline: some View {
        EmptyView()
    }

    // MARK: - AI Agent Border Overlay

    /// Glowing border when AI coding agent is active
    @State private var aiAgentGlowIntensity: CGFloat = 0.4

    private var aiAgentBorderOverlay: some View {
        ZStack {
            // Dynamic Island: Fully rounded glow border
            DynamicIslandOutlineShape(cornerRadius: isExpandedOnThisScreen ? 40 : 50)
                .stroke(aiAgentMonitor.currentSource.borderColor, lineWidth: aiAgentMonitor.glowEnhanced ? 3 : 2.5)
                .padding(1.5)
                .shadow(color: aiAgentMonitor.currentSource.borderColor.opacity(aiAgentGlowIntensity), radius: aiAgentMonitor.glowEnhanced ? 12 : 8)
                .shadow(color: aiAgentMonitor.glowEnhanced ? aiAgentMonitor.currentSource.borderColor.opacity(aiAgentGlowIntensity * 0.5) : .clear, radius: 20)
                .opacity(isDynamicIslandMode ? 1 : 0)

            // Notch mode: U-shaped glow border
            NotchOutlineShape(bottomRadius: isExpandedOnThisScreen ? 40 : 16)
                .stroke(aiAgentMonitor.currentSource.borderColor, lineWidth: aiAgentMonitor.glowEnhanced ? 3 : 2.5)
                .padding(1.5)
                .shadow(color: aiAgentMonitor.currentSource.borderColor.opacity(aiAgentGlowIntensity), radius: aiAgentMonitor.glowEnhanced ? 12 : 8)
                .shadow(color: aiAgentMonitor.glowEnhanced ? aiAgentMonitor.currentSource.borderColor.opacity(aiAgentGlowIntensity * 0.5) : .clear, radius: 20)
                .opacity(isDynamicIslandMode ? 0 : 1)
        }
        .opacity((aiAgentMonitor.isActive || aiAgentMonitor.isTestMode) && aiAgentMonitor.borderEnabled ? 1 : 0)
        .animation(DroppyAnimation.state, value: aiAgentMonitor.isActive)
        .onAppear {
            if aiAgentMonitor.borderPulsing {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    aiAgentGlowIntensity = 0.9
                }
            }
        }
        .onChange(of: aiAgentMonitor.isActive) { _, isActive in
            if isActive && aiAgentMonitor.borderPulsing {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    aiAgentGlowIntensity = 0.9
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    aiAgentGlowIntensity = 0.4
                }
            }
        }
        .onChange(of: aiAgentMonitor.isTestMode) { _, isTesting in
            if isTesting && aiAgentMonitor.borderPulsing {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    aiAgentGlowIntensity = 0.9
                }
            } else if !aiAgentMonitor.isActive {
                withAnimation(.easeOut(duration: 0.3)) {
                    aiAgentGlowIntensity = 0.4
                }
            }
        }
    }

    // MARK: - Drop Zone
    
    private var dropZone: some View {
        // MILLIMETER-PRECISE DETECTION (v5.3)
        // The drop zone NEVER extends below the visible notch/island.
        // - Horizontal: ±20px expansion for fast cursor movements (both modes)
        // - Vertical: EXACT height matching the visual - NO downward expansion
        // This ensures we don't block Safari URL bars, Outlook search fields, etc.
        // CRITICAL: Never expand when volume/brightness HUD is visible (prevents position shift)
        let isActive = enableNotchShelf && !hudIsVisible && (isExpandedOnThisScreen || isHoveringOnThisScreen || dragMonitor.isDragging || state.isDropTargeted)
        
        // Both modes: Horizontal expansion when active, but height is ALWAYS exact
        let dropAreaWidth: CGFloat = isActive ? (currentNotchWidth + 40) : currentNotchWidth
        // Height is ALWAYS exactly the current visual height - NEVER expand downward
        let dropAreaHeight: CGFloat = currentNotchHeight
        
        return ZStack(alignment: .top) {
            // Invisible hit area for hovering/clicking - SIZE CHANGES based on state
            RoundedRectangle(cornerRadius: isDynamicIslandMode ? 50 : 16, style: .continuous)
                .fill(Color.clear)
                .frame(width: dropAreaWidth, height: dropAreaHeight)
                .contentShape(RoundedRectangle(cornerRadius: isDynamicIslandMode ? 50 : 16, style: .continuous)) // Match the shape exactly
            
            // Drop indicator removed - shelf now auto-expands when dragging starts
        }
        .onTapGesture {
            // Only allow expanding shelf when shelf is enabled
            guard enableNotchShelf else { return }
            // CRITICAL: Only OPEN the shelf when collapsed - when expanded, clicks should go to items
            // This prevents the tap gesture from swallowing X button clicks in Dynamic Island mode
            guard !isExpandedOnThisScreen else { return }
            // Expand on this specific screen
            if let displayID = targetScreen?.displayID {
                withAnimation(DroppyAnimation.transition) {
                    state.expandShelf(for: displayID)
                }
            }
        }
        .onHover { isHovering in
            // STABLE HOVER: No withAnimation inside onHover - use view-level .animation() instead
            // This prevents animation stacking when cursor moves in/out rapidly
            
            // Only update hover state if not dragging (drag state handles its own)
            // AND not when volume/brightness HUD is visible (prevents layout shift)
            if !dragMonitor.isDragging && !hudIsVisible {
                // Get the displayID for this specific screen
                if let displayID = targetScreen?.displayID ?? NSScreen.builtInWithNotch?.displayID {
                    // Direct state update - animation handled by view-level .animation() modifier
                    if enableNotchShelf {
                        // PREMIUM: Subtle haptic on hover enter (not when expanded)
                        if isHovering && !isExpandedOnThisScreen && !state.isHovering(for: displayID) {
                            HapticFeedback.hover()
                        }
                        state.setHovering(for: displayID, isHovering: isHovering)
                        
                        // PREMIUM: Update hover scale state - only active when hovering AND not expanded
                        hoverScaleActive = isHovering && !isExpandedOnThisScreen
                    }
                    // Propagate hover to media HUD when music is playing (works independently)
                    // DEBOUNCED: Prevents animation stacking from rapid hover toggles
                    if showMediaPlayer && musicManager.isPlaying && !isExpandedOnThisScreen {
                        mediaHUDHoverWorkItem?.cancel()
                        let workItem = DispatchWorkItem { [self] in
                            // Only update if state actually changed (prevents redundant animations)
                            if mediaHUDIsHovered != isHovering {
                                mediaHUDIsHovered = isHovering
                            }
                        }
                        mediaHUDHoverWorkItem = workItem
                        // 50ms debounce - fast enough to feel responsive, slow enough to filter jitter
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
                    }
                }
            } else if hudIsVisible {
                // CRITICAL: Force reset hover states when HUD is visible to prevent any layout shift
                // This handles edge case where cursor was already over area when HUD appeared
                if let displayID = targetScreen?.displayID ?? NSScreen.builtInWithNotch?.displayID {
                    if state.isHovering(for: displayID) || mediaHUDIsHovered {
                        state.setHovering(for: displayID, isHovering: false)
                        mediaHUDHoverWorkItem?.cancel()  // Cancel pending debounced update
                        mediaHUDIsHovered = false
                    }
                }
            }
        }
        // STABLE ANIMATIONS: Applied at view level, not inside onHover
        // Use expandOpen for buttery smooth hover animation matching shelf expansion
        .animation(DroppyAnimation.expandOpen, value: isHoveringOnThisScreen)
        // STRUCTURAL: mediaHUDIsHovered drives currentNotchHeight, so use notchState animation
        .animation(DroppyAnimation.notchState, value: mediaHUDIsHovered)
    }
    
    // MARK: - Indicators
    
    private var dropIndicatorContent: some View {
        // PREMIUM: Shelf icon in compact indicator
        DropZoneIcon(type: .shelf, size: 28, isActive: state.isDropTargeted)
            .padding(8) // Compact padding
            .background(indicatorBackground)
    }
    
    private var openIndicatorContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white, .blue)
                .symbolEffect(.bounce, value: isHoveringOnThisScreen)
            
            Text("Open Shelf")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(indicatorBackground)
    }
    
    // NOTE: In regular notch mode, indicators are solid black.
    // In transparent DI mode OR external notch transparent mode, indicators use glass material.
    private var indicatorBackground: some View {
        let useTransparent = shouldUseDynamicIslandTransparent || shouldUseExternalNotchTransparent
        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(useTransparent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
    }

    // MARK: - Expanded Content
    
    private var expandedShelfContent: some View {
        // Grid Items or Media Player or Drop Zone or Terminal
        // No header row - auto-collapse handles hiding, right-click for settings/clipboard
        ZStack {
            // TERMINAL VIEW: Highest priority - takes over the shelf when active
            if terminalManager.isInstalled && terminalManager.isVisible {
                // SSOT: contentLayoutNotchHeight for consistent terminal content layout
                TerminalNotchView(manager: terminalManager, notchHeight: contentLayoutNotchHeight)
                    .frame(height: currentExpandedHeight, alignment: .top)
                    .id("terminal-view")
                    // PREMIUM: Exact scale(0.8, anchor: .top) + opacity transition
                    .notchTransition()
            }
            // Show drop zone when dragging over (takes priority)
            // ALSO show when hovering over AirDrop zone (isShelfAirDropZoneTargeted) to prevent snap-back to media
            else if (state.isDropTargeted || state.isShelfAirDropZoneTargeted) && state.items.isEmpty {
                emptyShelfContent
                    .frame(height: currentExpandedHeight)
                    .notchTransition()
                }
                // MEDIA PLAYER VIEW: Show if:
                // 1. User forced it via swipe (isMediaHUDForced) - shows even when paused
                // 2. Music is playing AND user hasn't hidden it (isMediaHUDHidden)
                // Both require: not idle, not drop targeted, not AirDrop zone targeted, media enabled
                // CRITICAL: Don't show during file drag - prevents flash when dropping files
                else if showMediaPlayer && !musicManager.isPlayerIdle && !state.isDropTargeted && !state.isShelfAirDropZoneTargeted && !dragMonitor.isDragging &&
                        (musicManager.isMediaHUDForced || 
                         ((musicManager.isPlaying || musicManager.wasRecentlyPlaying) && !musicManager.isMediaHUDHidden && state.items.isEmpty)) {
                    // SSOT: contentLayoutNotchHeight ensures MediaPlayerView and morphing overlays use identical positioning
                    // showTitle: false when morphing overlay handles it (DI mode OR external displays)
                    // UNIFIED ANIMATION: MediaPlayerView has its own contentAppeared state that triggers on appear
                    // Uses same scale(0.8)+opacity with .smooth(0.35) timing as morphing overlays
                    MediaPlayerView(musicManager: musicManager, notchHeight: contentLayoutNotchHeight, albumArtNamespace: albumArtNamespace, showAlbumArt: false, showVisualizer: false, showTitle: !shouldShowTitleInHUD)
                        .frame(height: currentExpandedHeight)
                        // Capture all clicks within the media player area
                        .contentShape(Rectangle())
                        // Stable identity for animation - prevents jitter on state changes
                        .id("media-player-view")
                }
                // Show empty shelf when no items and no music (or user swiped to hide music)
                else if state.items.isEmpty {
                    emptyShelfContent
                                            .frame(height: currentExpandedHeight)
                        // Stable identity for animation
                        .id("empty-shelf-view")
                        // Scale transition matching basket pattern for polished appearance
                        .notchTransition()
                }
                // Show items grid when items exist
                else {
                    itemsGridView
                                            .frame(height: currentExpandedHeight)
                        // Stable identity for animation
                        .id("items-grid-view")
                        // Scale transition matching basket pattern for polished appearance
                        .notchTransition()
            }

            // AI Agent Status overlay - shows at top when agent is active
            // Hide when media player is visible to avoid overlap
            let isMediaPlayerVisible = showMediaPlayer && !musicManager.isPlayerIdle && !state.isDropTargeted && !state.isShelfAirDropZoneTargeted &&
                (musicManager.isMediaHUDForced || ((musicManager.isPlaying || musicManager.wasRecentlyPlaying) && !musicManager.isMediaHUDHidden && state.items.isEmpty))

            if aiAgentMonitor.isActive && aiAgentMonitor.isEnabled && !isMediaPlayerVisible && state.items.isEmpty {
                VStack {
                    AIAgentShelfStatusView(manager: aiAgentMonitor)
                        .padding(.horizontal, 16)
                        .padding(.top, isDynamicIslandMode ? 16 : notchHeight + 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

        }
        // NOTE: .drawingGroup() removed - breaks NSViewRepresentable views like AudioSpectrumView
        // which cannot be rasterized into Metal textures (Issue #81 partial rollback)
        // PREMIUM: Smooth animation for view switching (swipe between shelf/media)
        .animation(.smooth(duration: 0.35), value: aiAgentMonitor.isActive)
        .animation(.smooth(duration: 0.35), value: musicManager.isMediaHUDForced)
        .animation(.smooth(duration: 0.35), value: musicManager.isMediaHUDHidden)
        .onHover { isHovering in
            
            // Track hover state for the auto-shrink timer
            isHoveringExpandedContent = isHovering
            
            // Reset auto-shrink timer when hovering over expanded content (including media player)
            if isHovering {
                cancelAutoShrinkTimer()
            } else {
                startAutoShrinkTimer()
            }
        }
        // Right-click context menu for entire expanded shelf
        .contextMenu {
            // Clipboard button (when enabled in settings)
            if showClipboardButton {
                Button {
                    ClipboardWindowController.shared.toggle()
                } label: {
                    Label("Open Clipboard", systemImage: "clipboard")
                }
            }
            
            // Clear shelf (when items exist)
            if !state.items.isEmpty {
                Button {
                    withAnimation(DroppyAnimation.state) {
                        state.clearAll()
                    }
                } label: {
                    Label("Clear Shelf", systemImage: "trash")
                }
            }
            
            if showClipboardButton || !state.items.isEmpty {
                Divider()
            }
            
            if enableRightClickHide {
                Button {
                    NotchWindowController.shared.setTemporarilyHidden(true)
                } label: {
                    Label("Hide \(isDynamicIslandMode ? "Dynamic Island" : "Notch")", systemImage: "eye.slash")
                }
                Divider()
            }
            Button {
                SettingsWindowController.shared.showSettings()
            } label: {
                Label("Open Settings", systemImage: "gear")
            }
        }
    }
    
    private var itemsGridView: some View {
        return ScrollView(.vertical, showsIndicators: false) {
            ZStack {
                // Background tap handler - acts as a "canvas" to catch clicks
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        state.deselectAll()
                        if renamingItemId != nil {
                            state.isRenaming = false
                        }
                        renamingItemId = nil
                    }
                    // Moved Marquee Drag Gesture HERE so it doesn't conflict with dragging items
                    .gesture(
                         DragGesture(minimumDistance: 1, coordinateSpace: .named("shelfGrid"))
                             .onChanged { value in
                                 // Start selection
                                 if selectionRect == nil {
                                     initialSelection = state.selectedItems
                                     
                                     if !NSEvent.modifierFlags.contains(.command) && !NSEvent.modifierFlags.contains(.shift) {
                                         state.deselectAll()
                                         initialSelection = []
                                     }
                                 }
                                 
                                 let rect = CGRect(
                                     x: min(value.startLocation.x, value.location.x),
                                     y: min(value.startLocation.y, value.location.y),
                                     width: abs(value.location.x - value.startLocation.x),
                                     height: abs(value.location.y - value.startLocation.y)
                                 )
                                 selectionRect = rect
                                 
                                 // Update Selection
                                 var newSelection = initialSelection
                                 for (id, frame) in itemFrames {
                                     if rect.intersects(frame) {
                                         newSelection.insert(id)
                                     }
                                 }
                                 state.selectedItems = newSelection
                             }
                             .onEnded { _ in
                                 selectionRect = nil
                                 initialSelection = []
                             }
                    )
                
                // Items grid using LazyVGrid for efficient rendering
                let columns = Array(repeating: GridItem(.fixed(64), spacing: 8), count: 5)
                
                LazyVGrid(columns: columns, spacing: 8) {
                    // Power Folders first (always distinct, never stacked)
                    ForEach(state.shelfPowerFolders) { folder in
                        NotchItemView(
                            item: folder,
                            state: state,
                            renamingItemId: $renamingItemId,
                            onRemove: {
                                withAnimation(DroppyAnimation.state) {
                                    state.shelfPowerFolders.removeAll { $0.id == folder.id }
                                }
                            }
                        )
                        .transition(.stackDrop)
                    }
                    
                    // Stacks - render based on expansion state
                    ForEach(state.shelfStacks) { stack in
                        if stack.isExpanded {
                            // Collapse button as first item in expanded stack
                            StackCollapseButton(itemCount: stack.count) {
                                withAnimation(ItemStack.collapseAnimation) {
                                    state.collapseStack(stack.id)
                                }
                            }
                            .transition(.stackExpand(index: 0))
                            
                            // Expanded: show all items individually
                            ForEach(stack.items) { item in
                                NotchItemView(
                                    item: item,
                                    state: state,
                                    renamingItemId: $renamingItemId,
                                    onRemove: {
                                        withAnimation(DroppyAnimation.state) {
                                            state.removeItem(item)
                                        }
                                    }
                                )
                                .transition(.stackExpand(index: (stack.items.firstIndex(where: { $0.id == item.id }) ?? 0) + 1))
                            }
                        } else if stack.isSingleItem, let item = stack.coverItem {
                            // Single item - render as normal
                            NotchItemView(
                                item: item,
                                state: state,
                                renamingItemId: $renamingItemId,
                                onRemove: {
                                    withAnimation(DroppyAnimation.state) {
                                        state.removeItem(item)
                                    }
                                }
                            )
                            .transition(.stackDrop)
                        } else {
                            // Multi-item collapsed stack
                            StackedItemView(
                                stack: stack,
                                state: state,
                                onExpand: {
                                    withAnimation(ItemStack.expandAnimation) {
                                        state.expandStack(stack.id)
                                    }
                                },
                                onRemove: {
                                    withAnimation(DroppyAnimation.state) {
                                        state.removeStack(stack.id)
                                    }
                                }
                            )
                            .transition(.stackDrop)
                        }
                    }
                }
                .padding(.horizontal, 8)
                // SSOT: Top padding clears physical notch in built-in notch mode
                // External displays and DI mode use smaller symmetrical padding
                .padding(.top, contentLayoutNotchHeight == 0 ? 8 : contentLayoutNotchHeight + 4)
                .padding(.bottom, 6)
            }
        }
        // Enable scrolling when more than 3 rows, disable otherwise
        .scrollDisabled(state.shelfDisplaySlotCount <= 15)  // 5 items per row * 3 rows = 15
        .clipped() // Prevent hover effects from bleeding past shelf edges
        .contentShape(Rectangle())
        // Removed .onTapGesture from here to prevent swallowing touches on children
        .overlay(alignment: .topLeading) {
            if let rect = selectionRect {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.blue.opacity(0.2))
                    .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "shelfGrid")
        .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
            self.itemFrames = frames
        }
    }
}

// MARK: - Custom Notch Shape
struct NotchShape: Shape {
    var bottomRadius: CGFloat
    
    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start top left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Top edge (straight)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        
        // Bottom Right Corner
        path.addArc(
            center: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        
        // Bottom Left Corner
        path.addArc(
            center: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Dynamic Island Shape (Pill/Capsule for non-notch screens)
/// A fully rounded pill shape for Dynamic Island mode
struct DynamicIslandShape: Shape {
    var cornerRadius: CGFloat
    
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        // Use RoundedRectangle with maximum corner radius for pill effect
        let effectiveRadius = min(cornerRadius, min(rect.width, rect.height) / 2)
        return RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous).path(in: rect)
    }
}

// MARK: - Notch Outline Shape
/// Defines the U-shape outline of the notch (without the top edge)
struct NotchOutlineShape: Shape {
    var bottomRadius: CGFloat
    
    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start Top Right
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        
        // Bottom Right Corner
        path.addArc(
            center: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        
        // Bottom Left Corner
        path.addArc(
            center: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        return path
    }
}

// MARK: - Dynamic Island Outline Shape
/// Defines a fully rounded outline for Dynamic Island mode (closed path, not U-shaped)
struct DynamicIslandOutlineShape: Shape {
    var cornerRadius: CGFloat
    
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let effectiveRadius = min(cornerRadius, min(rect.width, rect.height) / 2)
        return RoundedRectangle(cornerRadius: effectiveRadius, style: .continuous).path(in: rect)
    }
}

// Extension to split up complex view code
extension NotchShelfView {

    private var emptyShelfContent: some View {
        HStack(spacing: 20) {
            // Main drop zone (left side or full width when AirDrop zone disabled)
            ZStack {
                DropZoneIcon(type: .shelf, size: 44, isActive: state.isDropTargeted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                // PREMIUM PRESSED EFFECT: Layered inner glow for 3D depth
                Group {
                    if state.isDropTargeted {
                        ZStack {
                            // Layer 1: Soft inner border glow - premium edge highlight
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.25),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 2
                                )
                            // Layer 2: Subtle vignette for depth
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.clear,
                                            Color.white.opacity(0.08)
                                        ],
                                        center: .center,
                                        startRadius: 30,
                                        endRadius: 120
                                    )
                                )
                        }
                        .allowsHitTesting(false)
                    } else {
                        // Subtle dashed outline when not targeted
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(0.2),
                                style: StrokeStyle(
                                    lineWidth: 1.5,
                                    lineCap: .round,
                                    dash: [6, 8],
                                    dashPhase: dropZoneDashPhase
                                )
                            )
                    }
                }
                .animation(DroppyAnimation.expandOpen, value: state.isDropTargeted)
            )
            
            // AirDrop zone (right side, only when enabled)
            if enableShelfAirDropZone {
                ZStack {
                    DropZoneIcon(type: .airDrop, size: 44, isActive: state.isShelfAirDropZoneTargeted)
                }
                .frame(maxWidth: 90, maxHeight: .infinity)
                .overlay(
                    // PREMIUM PRESSED EFFECT: Layered inner glow for AirDrop zone
                    Group {
                        if state.isShelfAirDropZoneTargeted {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 2
                                    )
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        RadialGradient(
                                            colors: [Color.clear, Color.white.opacity(0.08)],
                                            center: .center,
                                            startRadius: 15,
                                            endRadius: 60
                                        )
                                    )
                            }
                            .allowsHitTesting(false)
                        } else {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    Color.white.opacity(0.2),
                                    style: StrokeStyle(
                                        lineWidth: 1.5,
                                        lineCap: .round,
                                        dash: [6, 8],
                                        dashPhase: dropZoneDashPhase
                                    )
                                )
                        }
                    }
                    .animation(DroppyAnimation.expandOpen, value: state.isShelfAirDropZoneTargeted)
                )
            }
        }
        // 3D PRESSED EFFECT: Scale down when targeted (like button being pushed)
        .scaleEffect((state.isDropTargeted || state.isShelfAirDropZoneTargeted) ? 0.97 : 1.0)
        .animation(DroppyAnimation.hoverBouncy, value: state.isDropTargeted)
        .animation(DroppyAnimation.hoverBouncy, value: state.isShelfAirDropZoneTargeted)
        // Use SSOT for consistent padding across all expanded views
        // Island mode: 20pt uniform on ALL sides
        // Notch mode: top = notchHeight (just below physical notch), 20pt on left/right/bottom
        // SSOT: contentLayoutNotchHeight for consistent shelf content layout
        .padding(NotchLayoutConstants.contentEdgeInsets(notchHeight: contentLayoutNotchHeight))
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                dropZoneDashPhase -= 280 // Multiple of 14 (6+8) for smooth loop
            }
        }
        .onDisappear {
            // PERFORMANCE: Stop the repeatForever animation when shelf collapses
            // Without this, the animation continues running and causes CPU drain
            withAnimation(.linear(duration: 0)) {
                dropZoneDashPhase = 0  // Reset to stop animation
            }
        }
    }
}

