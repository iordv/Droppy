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
    
    // Marquee Selection State
    @State private var selectionRect: CGRect? = nil
    @State private var initialSelection: Set<UUID> = []
    @State private var itemFrames: [UUID: CGRect] = [:]
    
    // Global rename state
    @State private var renamingItemId: UUID?
    
    // Media HUD hover state - used to grow notch when showing song title
    @State private var mediaHUDIsHovered: Bool = false
    
    // Removed isDropTargeted state as we use shared state now
    
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
        return topInset > 0 ? topInset : 32
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
    /// Uses the MAIN "Transparent Background" setting - one toggle controls all transparency
    private var shouldUseDynamicIslandTransparent: Bool {
        isDynamicIslandMode && useTransparentBackground
    }
    
    /// Whether the external display notch should use transparent glass effect
    /// Only applies to external displays in notch mode (not built-in, as physical notch is black)
    private var shouldUseExternalNotchTransparent: Bool {
        isExternalDisplay && !isDynamicIslandMode && useTransparentBackground
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
    /// Content height matching shelf pattern exactly:
    /// Island mode: 100pt (album) + 20pt top + 20pt bottom = 140pt
    /// Notch mode: 100pt + (notchHeight + 6) top + 20pt bottom
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
        if isDynamicIslandMode {
            return 260  // Compact width for island mode
        }
        return notchWidth + (volumeWingWidth * 2) + 20  // Same formula as brightness
    }
    
    /// Brightness HUD - same width as Volume for visual consistency
    private var brightnessHudWidth: CGFloat {
        if isDynamicIslandMode {
            return 260  // Compact width for island mode
        }
        return notchWidth + (volumeWingWidth * 2) + 20
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
            // Dynamic Island stays fixed height - no vertical extension
            if isDynamicIslandMode {
                return notchHeight
            }
            // External displays: no vertical expansion since no title scrolls underneath
            if !isBuiltInDisplay {
                return notchHeight
            }
            // Built-in notch: Grow when hovered AND media player is visible (not volume/brightness HUD)
            // Title row: 4px top + 20px title + 4px bottom = 28px
            let mediaHUDVisible = showMediaPlayer && !hudIsVisible
            // Only expand on media hover, NOT when dragging files (prevents sliding animation)
            let shouldExpand = mediaHUDIsHovered && mediaHUDVisible
            return shouldExpand ? notchHeight + 28 : notchHeight
        } else if enableNotchShelf && (isHoveringOnThisScreen || dragMonitor.isDragging) {
            // Dynamic Island stays fixed height - no vertical extension on hover
            if isDynamicIslandMode {
                return notchHeight
            }
            // External displays: no vertical expansion (no title to peek)
            if !isBuiltInDisplay {
                return notchHeight
            }
            // Peek down when hovering or dragging files - subtle expansion
            return notchHeight + 16
        } else {
            return notchHeight
        }
    }
    
    private var currentExpandedHeight: CGFloat {
        // TERMINAL: Expanded height when terminal has output
        if terminalManager.isInstalled && terminalManager.isVisible {
            // Base height for terminal (taller than media player to fit content + bottom padding)
            let baseTerminalHeight: CGFloat = 180
            let topPaddingDelta: CGFloat = isDynamicIslandMode ? 0 : (notchHeight - 14)
            let terminalHeight = baseTerminalHeight + topPaddingDelta
            
            // Height stays constant - no expansion when output is present
            return terminalHeight
        }
        
        // Determine if we're showing media player or shelf
        let shouldShowMediaPlayer = musicManager.isMediaHUDForced || 
            ((musicManager.isPlaying || musicManager.wasRecentlyPlaying) && !musicManager.isMediaHUDHidden && state.items.isEmpty)
        
        // MEDIA PLAYER: Content height + notch compensation (if applicable)
        if showMediaPlayer && shouldShowMediaPlayer && !musicManager.isPlayerIdle {
            // v8.1.5: Horizontal layout matching shelf pattern exactly
            // Island mode: 140pt (100pt album + 20pt top + 20pt bottom)
            // Notch mode: 140pt + (notchHeight + 6 - 20) = 140pt + notchHeight - 14
            let topPaddingDelta: CGFloat = isDynamicIslandMode ? 0 : (notchHeight - 14)
            return mediaPlayerContentHeight + topPaddingDelta
        }
        
        // SHELF: DYNAMIC height (grows with files, small when empty)
        // No header row anymore - auto-collapse handles hiding
        let rowCount = (Double(state.items.count) / 5.0).rounded(.up)
        let baseHeight = max(1, rowCount) * 110 // 110 per row, no header
        
        // In notch mode, add extra height to compensate for top padding that clears physical notch
        // Island mode doesn't need this as there's no physical obstruction
        let notchCompensation: CGFloat = isDynamicIslandMode ? 0 : notchHeight
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
                .transition(.scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.7)))
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
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .padding(10)
                                    .background(indicatorBackground)
                            }
                            .buttonStyle(.plain)
                            .help("Open in Terminal.app")
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                            
                            // Clear terminal button (only when there's output)
                            if !terminalManager.lastOutput.isEmpty {
                                Button(action: {
                                    terminalManager.clearOutput()
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 26, height: 26)
                                        .padding(10)
                                        .background(indicatorBackground)
                                }
                                .buttonStyle(.plain)
                                .help("Clear terminal output")
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                            }
                        }
                        
                        // Toggle terminal button (shows terminal icon when hidden, X when visible)
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                terminalManager.toggle()
                            }
                        }) {
                            Image(systemName: terminalManager.isVisible ? "xmark" : "terminal")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .padding(10)
                                .background(indicatorBackground)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                    
                    // Close button (only in sticky mode AND when terminal is not visible)
                    if !autoCollapseShelf && !terminalManager.isVisible {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                state.expandedDisplayID = nil
                                state.hoveringDisplayID = nil  // Clear hover on all screens when closing
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .padding(10)
                                .background(indicatorBackground)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Position exactly below the expanded content using SSOT gap
                // NOTE: In notch mode, currentExpandedHeight includes top padding compensation which
                // naturally pushes buttons lower. Island mode needs extra offset from SSOT to match.
                .offset(y: currentExpandedHeight + NotchLayoutConstants.floatingButtonGap + (isDynamicIslandMode ? NotchLayoutConstants.floatingButtonIslandCompensation : 0))
                .opacity(notchController.isTemporarilyHidden ? 0 : 1)
                .scaleEffect(notchController.isTemporarilyHidden ? 0.5 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: notchController.isTemporarilyHidden)
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
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: notchController.isTemporarilyHidden)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showMediaPlayer)
        .animation(.easeOut(duration: 0.4), value: mediaHUDFadedOut)
    }
    
    private var shelfContentWithItemObservers: some View {
        shelfContentBase
            .onChange(of: state.items.count) { oldCount, newCount in
                if newCount > oldCount && !isExpandedOnThisScreen {
                    if let displayID = targetScreen?.displayID {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            state.expandShelf(for: displayID)
                        }
                    }
                }
                if newCount == 0 && state.isExpanded {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.expandedDisplayID = nil
                    }
                }
            }
            .onChange(of: dragMonitor.isDragging) { _, isDragging in
                if showMediaPlayer && musicManager.isPlaying && !isExpandedOnThisScreen {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        mediaHUDIsHovered = isDragging
                    }
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
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isSongTransitioning = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isSongTransitioning = false
                        }
                    }
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            hudIsVisible = true
            // Reset hover states to prevent layout shift when HUD appears
            state.hoveringDisplayID = nil  // Clear hover on all screens
            mediaHUDIsHovered = false
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.3)) {
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            hudIsVisible = true
            // Reset hover states to prevent layout shift when HUD appears
            state.hoveringDisplayID = nil  // Clear hover on all screens
            mediaHUDIsHovered = false
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.3)) {
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
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
                    .transition(.scale(scale: 0.85).combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.8)))
                    .frame(width: expandedWidth, height: currentExpandedHeight)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentExpandedHeight)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.isMediaHUDForced)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.isMediaHUDHidden)
                    .clipShape(isDynamicIslandMode ? AnyShape(DynamicIslandShape(cornerRadius: 40)) : AnyShape(NotchShape(bottomRadius: 40)))
                    .geometryGroup()
                    .zIndex(2)
            }
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
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
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
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
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
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
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
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
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
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
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
            .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
            .zIndex(7)
        }
    }
    
    // MARK: - Media Player HUD
    
    /// Media player mini HUD
    @ViewBuilder
    private var mediaPlayerHUD: some View {
        // Break up complex expressions for type checker
        let noHUDsVisible = !hudIsVisible && !HUDManager.shared.isVisible
        let notExpanded = !isExpandedOnThisScreen
        
        let shouldShowForced = musicManager.isMediaHUDForced && !musicManager.isPlayerIdle && showMediaPlayer && noHUDsVisible && notExpanded
        
        let mediaIsPlaying = musicManager.isPlaying && !musicManager.songTitle.isEmpty
        let notFadedOrTransitioning = !(autoFadeMediaHUD && mediaHUDFadedOut) && !isSongTransitioning
        let debounceOk = !debounceMediaChanges || isMediaStable
        let shouldShowNormal = showMediaPlayer && mediaIsPlaying && noHUDsVisible && notExpanded && notFadedOrTransitioning && debounceOk
        
        if shouldShowForced || shouldShowNormal {
            MediaHUDView(musicManager: musicManager, isHovered: $mediaHUDIsHovered, notchWidth: notchWidth, notchHeight: notchHeight, hudWidth: hudWidth, targetScreen: targetScreen)
                .frame(width: hudWidth, alignment: .top)
                .clipShape(isDynamicIslandMode ? AnyShape(DynamicIslandShape(cornerRadius: 50)) : AnyShape(NotchShape(bottomRadius: 18)))
                .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
                .zIndex(3)
        }
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
            // When transparent DI is enabled, use glass material instead of black
            DynamicIslandShape(cornerRadius: isExpandedOnThisScreen ? 40 : 50)
                .fill(shouldUseDynamicIslandTransparent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
                // Shadow scales with expanded state for proper depth perception
                .shadow(
                    color: Color.black.opacity(isDynamicIslandMode ? (isExpandedOnThisScreen ? 0.3 : 0.25) : 0),
                    radius: isExpandedOnThisScreen ? 12 : 6,
                    x: 0,
                    y: isExpandedOnThisScreen ? 6 : 3
                )
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
        // Add bottom padding to prevent shadow clipping when expanded
        // Shadow extends: radius (12) + y-offset (6) = 18px downward
        .padding(.bottom, isDynamicIslandMode && isExpandedOnThisScreen ? 18 : 0)
        .frame(
            width: currentNotchWidth,
            height: currentNotchHeight + (isDynamicIslandMode && isExpandedOnThisScreen ? 18 : 0)
        )
        .opacity(shouldShowVisualNotch ? 1.0 : 0.0)
        // Note: Idle indicator removed - island is now completely invisible when idle
        // Only appears on hover, drag, or when HUDs/media are active
        .overlay(morphingOutline)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragMonitor.isDragging)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hudIsVisible)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: musicManager.isPlaying)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSongTransitioning)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.items.count)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: useDynamicIslandStyle)
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
                NotchWindowController.shared.setTemporarilyHidden(true)
            } label: {
                Label("Hide \(isDynamicIslandMode ? "Dynamic Island" : "Notch")", systemImage: "eye.slash")
            }
            Divider()
            Button {
                SettingsWindowController.shared.showSettings()
            } label: {
                Label("Open Settings", systemImage: "gear")
            }
        }
    }
    
    // MARK: - Morphing Outline
    
    /// Marching ants outline for drag/hover state
    private var morphingOutline: some View {
        ZStack {
            // Dynamic Island: Fully rounded outline
            DynamicIslandOutlineShape(cornerRadius: isExpandedOnThisScreen ? 40 : 50)
                .stroke(
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [3, 5],
                        dashPhase: dashPhase
                    )
                )
                .foregroundStyle(Color.blue)
                .opacity(isDynamicIslandMode ? 1 : 0)
            
            // Notch mode: U-shaped outline (no top edge)
            NotchOutlineShape(bottomRadius: isExpandedOnThisScreen ? 40 : 16)
                .trim(from: 0, to: 1)
                .stroke(
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [3, 5],
                        dashPhase: dashPhase
                    )
                )
                .foregroundStyle(Color.blue)
                .opacity(isDynamicIslandMode ? 0 : 1)
        }
        .opacity((enableNotchShelf && shouldShowVisualNotch && !isExpandedOnThisScreen && (dragMonitor.isDragging || isHoveringOnThisScreen)) ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragMonitor.isDragging)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringOnThisScreen)
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
            // Toggle expansion on this specific screen
            if let displayID = targetScreen?.displayID {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    state.toggleShelfExpansion(for: displayID)
                }
            }
        }
        .onHover { isHovering in
            
            // Only update hover state if not dragging (drag state handles its own)
            // AND not when volume/brightness HUD is visible (prevents layout shift)
            if !dragMonitor.isDragging && !hudIsVisible {
                // Get the displayID for this specific screen
                if let displayID = targetScreen?.displayID ?? NSScreen.builtInWithNotch?.displayID {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        // Only set mouse hovering if shelf is enabled
                        if enableNotchShelf {
                            state.setHovering(for: displayID, isHovering: isHovering)
                        }
                        // Propagate hover to media HUD when music is playing (works independently)
                        if showMediaPlayer && musicManager.isPlaying && !isExpandedOnThisScreen {
                            mediaHUDIsHovered = isHovering
                        }
                    }
                }
            } else if hudIsVisible {
                // CRITICAL: Force reset hover states when HUD is visible to prevent any layout shift
                // This handles edge case where cursor was already over area when HUD appeared
                if let displayID = targetScreen?.displayID ?? NSScreen.builtInWithNotch?.displayID {
                    if state.isHovering(for: displayID) || mediaHUDIsHovered {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            state.setHovering(for: displayID, isHovering: false)
                            mediaHUDIsHovered = false
                        }
                    }
                }
            }
        }
        // NOTE: isDropTargeted animation REMOVED to prevent sliding effect
        // Visual feedback handled by internal transitions in emptyShelfContent
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringOnThisScreen)
    }
    
    // MARK: - Indicators
    
    private var dropIndicatorContent: some View {
        // Show NotchFace in the indicator - excited when hovering on notch, idle otherwise
        NotchFace(size: 26, isExcited: state.isDropTargeted)
            .padding(10) // Compact padding
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
                TerminalNotchView(manager: terminalManager, notchHeight: isDynamicIslandMode ? 0 : notchHeight)
                    .frame(height: currentExpandedHeight, alignment: .top)
                    .id("terminal-view")
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
            // Show drop zone when dragging over (takes priority)
            // ALSO show when hovering over AirDrop zone (isShelfAirDropZoneTargeted) to prevent snap-back to media
            else if (state.isDropTargeted || state.isShelfAirDropZoneTargeted) && state.items.isEmpty {
                emptyShelfContent
                    .frame(height: currentExpandedHeight)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                }
                // MEDIA PLAYER VIEW: Show if:
                // 1. User forced it via swipe (isMediaHUDForced) - shows even when paused
                // 2. Music is playing AND user hasn't hidden it (isMediaHUDHidden)
                // Both require: not idle, not drop targeted, not AirDrop zone targeted, media enabled
                else if showMediaPlayer && !musicManager.isPlayerIdle && !state.isDropTargeted && !state.isShelfAirDropZoneTargeted &&
                        (musicManager.isMediaHUDForced || 
                         ((musicManager.isPlaying || musicManager.wasRecentlyPlaying) && !musicManager.isMediaHUDHidden && state.items.isEmpty)) {
                    MediaPlayerView(musicManager: musicManager, notchHeight: isDynamicIslandMode ? 0 : notchHeight)
                        .frame(height: currentExpandedHeight)
                        // Capture all clicks within the media player area
                        .contentShape(Rectangle())
                        // Stable identity for animation - prevents jitter on state changes
                        .id("media-player-view")
                        // Media slides in from RIGHT when appearing (user swiped left)
                        // Media slides out to RIGHT when disappearing (user swiped right)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
                // Show empty shelf when no items and no music (or user swiped to hide music)
                else if state.items.isEmpty {
                    emptyShelfContent
                                            .frame(height: currentExpandedHeight)
                        // Stable identity for animation
                        .id("empty-shelf-view")
                        // Carousel Symmetry Standard: Slides from LEFT (opposite to media which slides from RIGHT)
                        // This creates a seamless handoff without ghosting artifacts
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                // Show items grid when items exist
                else {
                    itemsGridView
                                            .frame(height: currentExpandedHeight)
                        // Stable identity for animation
                        .id("items-grid-view")
                        // Carousel Symmetry Standard: Slides from LEFT (opposite to media which slides from RIGHT)
                        // This creates a seamless handoff without ghosting artifacts
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
            }
            

        }
        // Smoother, more premium animation for media state changes
        // NOTE: isDropTargeted animation REMOVED to prevent sliding effect when files hover over shelf
        // Internal transitions handle content animations instead
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.isPlaying)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.wasRecentlyPlaying)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.isMediaHUDForced)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.isMediaHUDHidden)
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        state.clearAll()
                    }
                } label: {
                    Label("Clear Shelf", systemImage: "trash")
                }
            }
            
            if showClipboardButton || !state.items.isEmpty {
                Divider()
            }
            
            Button {
                NotchWindowController.shared.setTemporarilyHidden(true)
            } label: {
                Label("Hide \(isDynamicIslandMode ? "Dynamic Island" : "Notch")", systemImage: "eye.slash")
            }
            Divider()
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
                let columns = Array(repeating: GridItem(.fixed(80), spacing: 10), count: 5)
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(state.items) { item in
                        NotchItemView(
                            item: item,
                            state: state,
                            renamingItemId: $renamingItemId,
                            onRemove: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    state.removeItem(item)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                // More top padding in notch mode to clear physical notch
                // Top padding clears physical notch in notch mode (notchHeight + margin)
                .padding(.top, isDynamicIslandMode ? 8 : notchHeight + 4)
                .padding(.bottom, 6)
            }
        }
        .scrollDisabled(true)  // Disable scrolling - shelf doesn't scroll like basket
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
                // Face reacts to files being dragged - gets excited when drop targeted
                if enableIdleFace {
                    NotchFace(size: 50, isExcited: state.isDropTargeted)
                } else {
                    // Fallback if idle face is disabled
                    if state.isDropTargeted {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.blue)
                            .symbolEffect(.bounce, value: state.isDropTargeted)
                    } else {
                        Image(systemName: "tray")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(10) // Match basket padding for visual consistency
            .overlay(
                // NOTE: Using strokeBorder instead of stroke to draw INSIDE the shape bounds,
                // preventing the stroke from being clipped at content edges
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        state.isDropTargeted ? Color.blue : Color.white.opacity(0.2),
                        style: StrokeStyle(
                            lineWidth: state.isDropTargeted ? 2 : 1.5,
                            lineCap: .round,
                            dash: [6, 8],
                            dashPhase: dropZoneDashPhase
                        )
                    )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isDropTargeted)
            )
            
            // AirDrop zone (right side, only when enabled)
            if enableShelfAirDropZone {
                ZStack {
                    // AirDrop icon - same size as NotchFace
                    Image("AirDropIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .scaleEffect(state.isShelfAirDropZoneTargeted ? 1.1 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: state.isShelfAirDropZoneTargeted)
                }
                .frame(maxWidth: 90, maxHeight: .infinity)
                .padding(10) // Match main zone padding
                .overlay(
                    // NOTE: Using strokeBorder to draw INSIDE shape bounds
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            state.isShelfAirDropZoneTargeted ? Color.blue : Color.white.opacity(0.2),
                            style: StrokeStyle(
                                lineWidth: state.isShelfAirDropZoneTargeted ? 2 : 1.5,
                                lineCap: .round,
                                dash: [6, 8],
                                dashPhase: dropZoneDashPhase
                            )
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isShelfAirDropZoneTargeted)
                )
            }
        }
        // Whole shelf content zooms when either zone is targeted (matches basket behavior)
        .scaleEffect((state.isDropTargeted || state.isShelfAirDropZoneTargeted) ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isDropTargeted)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isShelfAirDropZoneTargeted)
        // Use SSOT for consistent padding across all expanded views
        // Island mode: 20pt uniform on ALL sides
        // Notch mode: top = notchHeight (just below physical notch), 20pt on left/right/bottom
        .padding(NotchLayoutConstants.contentEdgeInsets(notchHeight: isDynamicIslandMode ? 0 : notchHeight))
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                dropZoneDashPhase -= 280 // Multiple of 14 (6+8) for smooth loop
            }
        }
    }
}

