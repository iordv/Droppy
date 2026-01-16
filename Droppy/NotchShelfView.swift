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
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @AppStorage("enableNotchShelf") private var enableNotchShelf = true
    @AppStorage("hideNotchOnExternalDisplays") private var hideNotchOnExternalDisplays = false
    @AppStorage("externalDisplayUseDynamicIsland") private var externalDisplayUseDynamicIsland = true  // External display mode
    @AppStorage("enableHUDReplacement") private var enableHUDReplacement = true
    @AppStorage("enableBatteryHUD") private var enableBatteryHUD = true  // Battery charging/low battery HUD
    @AppStorage("enableCapsLockHUD") private var enableCapsLockHUD = true  // Caps Lock ON/OFF HUD
    @AppStorage("enableAirPodsHUD") private var enableAirPodsHUD = true  // AirPods connection HUD
    @AppStorage("enableLockScreenHUD") private var enableLockScreenHUD = true  // Lock/Unlock HUD
    @AppStorage("showMediaPlayer") private var showMediaPlayer = true
    @AppStorage("autoFadeMediaHUD") private var autoFadeMediaHUD = true
    @AppStorage("debounceMediaChanges") private var debounceMediaChanges = false  // Delay media HUD for rapid changes
    @AppStorage("autoShrinkShelf") private var autoShrinkShelf = true
    @AppStorage("autoShrinkDelay") private var autoShrinkDelay = 3  // Seconds (1-10)
    @AppStorage("showClipboardButton") private var showClipboardButton = false
    @AppStorage("showOpenShelfIndicator") private var showOpenShelfIndicator = true
    @AppStorage("showDropIndicator") private var showDropIndicator = true
    @AppStorage("useDynamicIslandStyle") private var useDynamicIslandStyle = true  // For reactive mode changes
    @AppStorage("useDynamicIslandTransparent") private var useDynamicIslandTransparent = false  // Transparent DI (only when DI + transparent enabled)
    @AppStorage("enableAutoClean") private var enableAutoClean = false  // Auto-clear after drag-out
    
    // HUD State - Use @ObservedObject for singletons (they manage their own lifecycle)
    @ObservedObject private var volumeManager = VolumeManager.shared
    @ObservedObject private var brightnessManager = BrightnessManager.shared
    @ObservedObject private var batteryManager = BatteryManager.shared
    @ObservedObject private var capsLockManager = CapsLockManager.shared
    @ObservedObject private var musicManager = MusicManager.shared
    var airPodsManager = AirPodsManager.shared  // @Observable - no wrapper needed
    @ObservedObject private var lockScreenManager = LockScreenManager.shared
    @State private var showVolumeHUD = false
    @State private var showBrightnessHUD = false
    @State private var hudWorkItem: DispatchWorkItem?
    @State private var hudType: HUDContentType = .volume
    @State private var hudValue: CGFloat = 0
    @State private var hudIsVisible = false
    @State private var batteryHUDIsVisible = false  // Battery HUD visibility
    @State private var batteryHUDWorkItem: DispatchWorkItem?  // Timer for battery HUD auto-hide
    @State private var capsLockHUDIsVisible = false  // Caps Lock HUD visibility
    @State private var capsLockHUDWorkItem: DispatchWorkItem?  // Timer for Caps Lock HUD auto-hide
    @State private var airPodsHUDIsVisible = false  // AirPods connection HUD visibility
    @State private var airPodsHUDWorkItem: DispatchWorkItem?  // Timer for AirPods HUD auto-hide
    @State private var lockScreenHUDIsVisible = false  // Lock/Unlock HUD visibility
    @State private var lockScreenHUDWorkItem: DispatchWorkItem?  // Timer for Lock Screen HUD auto-hide
    @State private var mediaHUDFadedOut = false  // Tracks if media HUD has auto-faded
    @State private var mediaFadeWorkItem: DispatchWorkItem?
    @State private var autoShrinkWorkItem: DispatchWorkItem?  // Timer for auto-shrinking shelf
    @State private var isHoveringExpandedContent = false  // Tracks if mouse is over the expanded shelf
    @State private var isSongTransitioning = false  // Temporarily hide media during song transitions
    @State private var mediaDebounceWorkItem: DispatchWorkItem?  // Debounce for media changes
    @State private var isMediaStable = false  // Only show media HUD after debounce delay
    
    
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
        // Dynamic Island uses fixed size
        if isDynamicIslandMode { return 210 }

        // Use target screen or fallback to built-in
        guard let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return 180 }
        
        // Use auxiliary areas to calculate true notch width
        // The notch is the gap between the right edge of the left safe area
        // and the left edge of the right safe area
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            // Correct calculation: the gap between the two auxiliary areas
            // This is more accurate than (screen.width - leftWidth - rightWidth)
            // which can have sub-pixel rounding errors on different display configurations
            let notchGap = rightArea.minX - leftArea.maxX
            return max(notchGap, 180)
        }
        
        // Fallback for screens without notch data
        return 180
    }
    
    /// Notch height - scales with resolution
    private var notchHeight: CGFloat {
        // Dynamic Island uses fixed size
        if isDynamicIslandMode { return 37 }

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
    
    /// Whether the Dynamic Island should use transparent glass effect
    /// Only applies when in DI mode AND the transparent DI setting is enabled
    private var shouldUseDynamicIslandTransparent: Bool {
        isDynamicIslandMode && useDynamicIslandTransparent
    }
    
    /// Top margin for Dynamic Island - creates floating effect like iPhone
    private let dynamicIslandTopMargin: CGFloat = 4
    
    private let expandedWidth: CGFloat = 450
    
    /// Fixed wing sizes (area left/right of notch for content)  
    /// Using fixed sizes ensures consistent content positioning across all screen resolutions
    private let volumeWingWidth: CGFloat = 68   // For volume/brightness icons + percentage
    private let batteryWingWidth: CGFloat = 55  // For battery icon + percentage  
    private let mediaWingWidth: CGFloat = 50    // For album art + visualizer
    
    /// HUD dimensions calculated as notchWidth + (2 * wingWidth)
    /// This ensures wings are FIXED size regardless of notch size
    private var volumeHudWidth: CGFloat {
        if isDynamicIslandMode {
            return 280  // Smaller for Dynamic Island
        }
        return notchWidth + (volumeWingWidth * 2)
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
            if batteryHUDIsVisible || capsLockHUDIsVisible || hudIsVisible { return false }
            if state.isExpanded { return false }
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
        // Don't show when battery or caps lock HUD is visible (they take priority)
        if batteryHUDIsVisible || capsLockHUDIsVisible { return false }
        return showMediaPlayer && musicManager.isPlaying && !hudIsVisible && !state.isExpanded
    }
    
    /// Current notch width based on state
    private var currentNotchWidth: CGFloat {
        if state.isExpanded && enableNotchShelf {
            return expandedWidth
        } else if hudIsVisible {
            return volumeHudWidth  // Volume/Brightness HUD needs wider wings
        } else if lockScreenHUDIsVisible && enableLockScreenHUD {
            return batteryHudWidth  // Lock Screen HUD uses same width as battery HUD
        } else if airPodsHUDIsVisible && enableAirPodsHUD {
            return hudWidth  // AirPods HUD uses same width as Media HUD
        } else if batteryHUDIsVisible && enableBatteryHUD {
            return batteryHudWidth  // Battery HUD uses slightly narrower width than volume
        } else if capsLockHUDIsVisible && enableCapsLockHUD {
            return batteryHudWidth  // Caps Lock HUD uses same width as battery HUD
        } else if shouldShowMediaHUD {
            return hudWidth  // Media HUD uses tighter wings
        } else if enableNotchShelf && (dragMonitor.isDragging || state.isMouseHovering) {
            return notchWidth + 20
        } else {
            return notchWidth
        }
    }
    
    /// Current notch height based on state
    private var currentNotchHeight: CGFloat {
        if state.isExpanded && enableNotchShelf {
            return currentExpandedHeight
        } else if hudIsVisible {
            // Dynamic Island: keep compact height matching media HUD
            return isDynamicIslandMode ? notchHeight : hudHeight
        } else if lockScreenHUDIsVisible && enableLockScreenHUD {
            return notchHeight  // Lock Screen HUD just uses notch height
        } else if airPodsHUDIsVisible && enableAirPodsHUD {
            // AirPods HUD stays at notch height like media player (horizontal expansion only)
            return notchHeight
        } else if batteryHUDIsVisible && enableBatteryHUD {
            return notchHeight  // Battery HUD just uses notch height (no slider)
        } else if capsLockHUDIsVisible && enableCapsLockHUD {
            return notchHeight  // Caps Lock HUD just uses notch height (no slider)
        } else if shouldShowMediaHUD {
            // Dynamic Island stays fixed height - no vertical extension
            if isDynamicIslandMode {
                return notchHeight
            }
            // External displays: no vertical expansion since no title scrolls underneath
            if !isBuiltInDisplay {
                return notchHeight
            }
            // Built-in notch: Grow when hovered OR when dragging files (peek effect with title)
            // Title row: 4px top + 20px title + 4px bottom = 28px
            let shouldExpand = mediaHUDIsHovered || (enableNotchShelf && dragMonitor.isDragging)
            return shouldExpand ? notchHeight + 28 : notchHeight
        } else if enableNotchShelf && (dragMonitor.isDragging || state.isMouseHovering) {
            // Dynamic Island stays fixed height - no vertical extension on hover
            if isDynamicIslandMode {
                return notchHeight
            }
            // External displays: no vertical expansion (no title to peek)
            if !isBuiltInDisplay {
                return notchHeight
            }
            return notchHeight + 16  // Subtle expansion, not too tall
        } else {
            return notchHeight
        }
    }
    
    private var currentExpandedHeight: CGFloat {
        // Determine if we're showing media player or shelf
        let shouldShowMediaPlayer = musicManager.isMediaHUDForced || 
            ((musicManager.isPlaying || musicManager.wasRecentlyPlaying) && !musicManager.isMediaHUDHidden && state.items.isEmpty)
        
        // MEDIA PLAYER: FIXED height (doesn't grow with shelf items)
        // This is the height when showing media player via swipe or natural playback
        if showMediaPlayer && shouldShowMediaPlayer && !musicManager.isPlayerIdle {
            // Fixed media player height: 54 (header) + 210 (content area for album/controls)
            return 264
        }
        
        // SHELF: DYNAMIC height (grows with files, small when empty)
        let rowCount = (Double(state.items.count) / 5.0).rounded(.up)
        let baseHeight = max(1, rowCount) * 110 + 54 // 110 per row + 54 header
        return baseHeight
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
                // Show when hovering (to access shelf)
                if state.isMouseHovering || state.isDropTargeted { return true }
                // Show when dragging files
                if dragMonitor.isDragging { return true }
                // Show when expanded
                if state.isExpanded { return true }
            }
            // Show when battery HUD is visible
            if batteryHUDIsVisible && enableBatteryHUD { return true }
            // Show when caps lock HUD is visible
            if capsLockHUDIsVisible && enableCapsLockHUD { return true }
            // Show when lock screen HUD is visible
            if lockScreenHUDIsVisible && enableLockScreenHUD { return true }
            // Otherwise hide - Dynamic Island is invisible when idle
            return false
        }
        
        // NOTCH MODE: Legacy behavior - notch is always visible to cover camera
        // Always show when music is playing
        if shouldShowMediaHUD { return true }
        
        // Shelf-specific triggers only apply when shelf is enabled
        if enableNotchShelf {
            if state.isExpanded { return true }
            if dragMonitor.isDragging || state.isMouseHovering || state.isDropTargeted { return true }
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
    
    var body: some View {
        ZStack(alignment: .top) {
            // MARK: - Main Morphing Background
            // This is the persistent black shape that grows/shrinks
            // NOTE: The shelf/notch always uses solid black background.
            // The "Transparent Background" setting only applies to other UI elements
            // (Settings, Clipboard, etc.) - not the shelf, as that would look weird.
            // MORPH: Both shapes exist, crossfade with opacity for smooth transition
            ZStack {
                // Dynamic Island shape (pill)
                // When transparent DI is enabled, use glass material instead of black
                DynamicIslandShape(cornerRadius: state.isExpanded ? 40 : 50)
                    .fill(shouldUseDynamicIslandTransparent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
                    // Shadow scales with expanded state for proper depth perception
                    .shadow(
                        color: Color.black.opacity(isDynamicIslandMode ? (state.isExpanded ? 0.3 : 0.25) : 0),
                        radius: state.isExpanded ? 12 : 6,
                        x: 0,
                        y: state.isExpanded ? 6 : 3
                    )
                    .opacity(isDynamicIslandMode ? 1 : 0)
                    .scaleEffect(isDynamicIslandMode ? 1 : 0.85)
                
                // Notch shape (U-shaped) - always black (physical notch is black)
                NotchShape(bottomRadius: state.isExpanded ? 40 : (hudIsVisible ? 18 : 16))
                    .fill(Color.black)
                    .opacity(isDynamicIslandMode ? 0 : 1)
                    .scaleEffect(isDynamicIslandMode ? 0.85 : 1)
            }
            // Add bottom padding to prevent shadow clipping when expanded
            // Shadow extends: radius (12) + y-offset (6) = 18px downward
            .padding(.bottom, isDynamicIslandMode && state.isExpanded ? 18 : 0)
            .frame(
                width: currentNotchWidth,
                height: currentNotchHeight + (isDynamicIslandMode && state.isExpanded ? 18 : 0)
            )
            .opacity(shouldShowVisualNotch ? 1.0 : 0.0)
            // IDLE INDICATOR: Narrow version of Dynamic Island when shelf is not active
            // Shows users there's something available to interact with at the top of the screen
            // This is a slim, elegant version of the full island - same width, minimal height
            .overlay(alignment: .top) {
                // Show indicator only when shelf is enabled and DI mode is active but currently hidden
                if isDynamicIslandMode && enableNotchShelf && !shouldShowVisualNotch && !state.isExpanded && !state.isMouseHovering {
                    // Narrow island shape - same width as regular island, but very thin
                    DynamicIslandShape(cornerRadius: 8)
                        .fill(shouldUseDynamicIslandTransparent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
                        .frame(width: notchWidth, height: 10)
                        // Position at top with proper margin
                        .padding(.top, dynamicIslandTopMargin)
                        .shadow(color: Color.black.opacity(0.15), radius: 4, y: 1)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: shouldShowVisualNotch)
                }
            }
            .overlay(
                // MORPH: Both outline shapes exist, crossfade for smooth transition
                ZStack {
                    // Dynamic Island: Fully rounded outline
                    DynamicIslandOutlineShape(cornerRadius: state.isExpanded ? 40 : 50)
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
                    NotchOutlineShape(bottomRadius: state.isExpanded ? 40 : 16)
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
                .opacity((enableNotchShelf && shouldShowVisualNotch && !state.isExpanded && (dragMonitor.isDragging || state.isMouseHovering)) ? 1 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragMonitor.isDragging)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isMouseHovering)
            )
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.isExpanded)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragMonitor.isDragging)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hudIsVisible)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: musicManager.isPlaying)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSongTransitioning)  // Match song transition timing
                // Animate height changes when items are added/removed
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.items.count)
                // Smooth morph when switching between Notch and Dynamic Island modes
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: useDynamicIslandStyle)
                // DYNAMIC ISLAND: Add top margin for floating effect
                .padding(.top, isDynamicIslandMode ? dynamicIslandTopMargin : 0)
                // Right-click context menu to hide the notch/island
                .contextMenu {
                    Button("Hide \(isDynamicIslandMode ? "Dynamic Island" : "Notch")") {
                        NotchWindowController.shared.setTemporarilyHidden(true)
                    }
                    Divider()
                    Button("Settings...") {
                        SettingsWindowController.shared.showSettings()
                    }
                }
            
            // MARK: - Content Overlay
            ZStack(alignment: .top) {
                // Always have the drop zone / interaction layer at the top
                // BUT disable hit testing when expanded so slider/buttons can receive gestures
                dropZone
                    .zIndex(1)
                    .allowsHitTesting(!state.isExpanded)
                
                // MARK: - HUD Content (embedded in notch)
                if hudIsVisible && enableHUDReplacement && !state.isExpanded {
                    NotchHUDView(
                        hudType: $hudType,
                        value: $hudValue,
                        isActive: true, // Slider thickens while HUD is visible
                        notchWidth: notchWidth,
                        notchHeight: notchHeight,
                        hudWidth: volumeHudWidth,
                        targetScreen: targetScreen,
                        onValueChange: { newValue in
                            if hudType == .volume {
                                volumeManager.setAbsolute(Float32(newValue))
                            } else {
                                brightnessManager.setAbsolute(value: Float(newValue))
                            }
                        }
                    )
                    .frame(width: volumeHudWidth, height: isDynamicIslandMode ? notchHeight : hudHeight)
                    // Match media player transition - scale with notch
                    .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
                    .zIndex(3)
                }
                
                // MARK: - Battery HUD (charging/unplugging/low battery)
                // Takes priority over media HUD - briefly shows then returns to media
                // Uses WIDER width than media HUD so percentage isn't cut off by notch
                if batteryHUDIsVisible && enableBatteryHUD && !hudIsVisible && !state.isExpanded {
                    BatteryHUDView(
                        batteryManager: batteryManager,
                        notchWidth: notchWidth,
                        notchHeight: notchHeight,
                        hudWidth: batteryHudWidth,  // Slightly narrower than volume HUD
                        targetScreen: targetScreen
                    )
                    .frame(width: batteryHudWidth, height: notchHeight)
                    .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
                    .zIndex(4)  // Higher than media HUD
                }
                
                // MARK: - Caps Lock HUD (ON/OFF indicator)
                // Takes priority over media HUD - briefly shows then returns to media
                if capsLockHUDIsVisible && enableCapsLockHUD && !hudIsVisible && !batteryHUDIsVisible && !state.isExpanded {
                    CapsLockHUDView(
                        capsLockManager: capsLockManager,
                        notchWidth: notchWidth,
                        notchHeight: notchHeight,
                        hudWidth: batteryHudWidth,  // Same width as battery HUD
                        targetScreen: targetScreen
                    )
                    .frame(width: batteryHudWidth, height: notchHeight)
                    .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
                    .zIndex(5)  // Higher than battery HUD
                }
                
                // MARK: - AirPods HUD (connection animation)
                // Highest priority - shows spinning AirPods with battery ring on connection
                if airPodsHUDIsVisible && enableAirPodsHUD && !hudIsVisible && !state.isExpanded, let airPods = airPodsManager.connectedAirPods {
                    AirPodsHUDView(
                        airPods: airPods,
                        notchWidth: notchWidth,
                        notchHeight: notchHeight,  // Same height as media player mini HUD
                        hudWidth: hudWidth,  // Same as Media HUD for consistent sizing
                        targetScreen: targetScreen
                    )
                    .frame(width: hudWidth, height: notchHeight)
                    .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
                    .zIndex(6)  // Highest priority - connection events
                }
                
                // MARK: - Lock Screen HUD (lock/unlock animation)
                // Shows when MacBook lid opens/closes or screen locks/unlocks
                // Highest priority - hides all other HUDs
                if lockScreenHUDIsVisible && enableLockScreenHUD && !hudIsVisible && !state.isExpanded {
                    LockScreenHUDView(
                        lockScreenManager: lockScreenManager,
                        notchWidth: notchWidth,
                        notchHeight: notchHeight,
                        hudWidth: batteryHudWidth,  // Same width as battery/caps lock HUD
                        targetScreen: targetScreen
                    )
                    .frame(width: batteryHudWidth, height: notchHeight)
                    .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
                    .zIndex(7)  // Higher than AirPods HUD
                }
                
                // MARK: - Media Player HUD (when music is playing OR forced via swipe)
                // Show if: playing with valid song info OR forced by user swipe (with valid track)
                // Hide during song transitions for collapse-expand effect
                // Hide when battery/caps lock/airpods HUD is visible (they take priority briefly)
                // Debounce check only applies when setting is enabled
                // Note: shouldShowMediaHUD already handles forced mode, but inline check is needed for view visibility
                let shouldShowForced = musicManager.isMediaHUDForced && !musicManager.isPlayerIdle && showMediaPlayer && !hudIsVisible && !batteryHUDIsVisible && !capsLockHUDIsVisible && !airPodsHUDIsVisible && !lockScreenHUDIsVisible && !state.isExpanded
                let shouldShowNormal = showMediaPlayer && musicManager.isPlaying && !musicManager.songTitle.isEmpty && !hudIsVisible && !batteryHUDIsVisible && !capsLockHUDIsVisible && !airPodsHUDIsVisible && !lockScreenHUDIsVisible && !state.isExpanded && !(autoFadeMediaHUD && mediaHUDFadedOut) && !isSongTransitioning && (!debounceMediaChanges || isMediaStable)
                if shouldShowForced || shouldShowNormal {
                    MediaHUDView(musicManager: musicManager, isHovered: $mediaHUDIsHovered, notchWidth: notchWidth, notchHeight: notchHeight, hudWidth: hudWidth, targetScreen: targetScreen)
                        .frame(width: hudWidth, alignment: .top)
                        // Match other HUD transitions for consistent morphing
                        .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
                        .zIndex(3)
                }
                
                if state.isExpanded && enableNotchShelf {
                    expandedShelfContent
                        // Scale + opacity transition matches the HUD's smooth shrinking effect
                        .transition(.scale(scale: 0.85).combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.8)))
                        .frame(width: expandedWidth, height: currentExpandedHeight)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentExpandedHeight)
                        // Animate height changes on swipe state changes
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.isMediaHUDForced)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.isMediaHUDHidden)
                        .clipShape(isDynamicIslandMode ? AnyShape(DynamicIslandShape(cornerRadius: 40)) : AnyShape(NotchShape(bottomRadius: 40)))
                        // Synchronize child view animations with the parent
                        .geometryGroup()
                        .zIndex(2)
                }
            }
            // DYNAMIC ISLAND: Match top margin of the background shape
            .padding(.top, isDynamicIslandMode ? dynamicIslandTopMargin : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Animate all state changes smoothly
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showMediaPlayer)
        .animation(.easeOut(duration: 0.4), value: mediaHUDFadedOut)
        .onChange(of: state.items.count) { oldCount, newCount in
             if newCount > oldCount && !state.isExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    state.isExpanded = true
                }
            }
             if newCount == 0 && state.isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    state.isExpanded = false
                }
            }
        }
        // Show media HUD title when dragging files while music is playing
        .onChange(of: dragMonitor.isDragging) { _, isDragging in
            if showMediaPlayer && musicManager.isPlaying && !state.isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    mediaHUDIsHovered = isDragging
                }
            }
        }
        // MARK: - HUD Observers
        .onChange(of: volumeManager.lastChangeAt) { _, _ in
            guard enableHUDReplacement, !state.isExpanded else { return }
            triggerVolumeHUD()
        }
        .onChange(of: brightnessManager.lastChangeAt) { _, _ in
            guard enableHUDReplacement, !state.isExpanded else { return }
            triggerBrightnessHUD()
        }
        .onChange(of: batteryManager.lastChangeAt) { _, _ in
            guard enableBatteryHUD, !state.isExpanded else { return }
            triggerBatteryHUD()
        }
        .onChange(of: capsLockManager.lastChangeAt) { _, _ in
            guard enableCapsLockHUD, !state.isExpanded else { return }
            triggerCapsLockHUD()
        }
        .onChange(of: airPodsManager.lastConnectionAt) { _, _ in
            guard enableAirPodsHUD, !state.isExpanded else { return }
            triggerAirPodsHUD()
        }
        .onChange(of: lockScreenManager.lastChangeAt) { _, _ in
            guard enableLockScreenHUD, !state.isExpanded else { return }
            triggerLockScreenHUD()
        }
        // MARK: - Media HUD Auto-Fade
        .onChange(of: musicManager.songTitle) { oldTitle, newTitle in
            // Trigger collapse-expand animation on song change
            if !oldTitle.isEmpty && !newTitle.isEmpty && oldTitle != newTitle {
                // Start transition: collapse (hide media)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isSongTransitioning = true
                }
                // End transition after a delay: expand (show new song)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        isSongTransitioning = false
                    }
                }
            }
            // Reset fade state when song changes (new song = show HUD again)
            if !newTitle.isEmpty {
                mediaHUDFadedOut = false
                startMediaFadeTimer()
            }
        }
        .onChange(of: musicManager.isPlaying) { wasPlaying, isPlaying in
            // When playback starts, reset fade state and start debounce timer
            if isPlaying && !wasPlaying {
                mediaHUDFadedOut = false
                // Reset swipe states - natural playback takes over
                musicManager.isMediaHUDForced = false
                musicManager.isMediaHUDHidden = false
                // Start debounce timer - only show HUD after media is stable for 1 second
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
            // When playback stops, cancel debounce and hide immediately
            if !isPlaying && wasPlaying {
                mediaDebounceWorkItem?.cancel()
                isMediaStable = false
            }
        }
        // MARK: - Auto-Fade Setting Observer
        .onChange(of: autoFadeMediaHUD) { wasEnabled, isEnabled in
            if isEnabled && !wasEnabled {
                // Setting was just enabled - start fade timer if music is playing
                if musicManager.isPlaying && showMediaPlayer {
                    startMediaFadeTimer()
                }
            } else if !isEnabled && wasEnabled {
                // Setting was disabled - cancel any pending fade and reset state
                mediaFadeWorkItem?.cancel()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    mediaHUDFadedOut = false
                }
            }
        }
        // MARK: - Auto-Shrink Timer Observers
        .onChange(of: state.isExpanded) { wasExpanded, isExpanded in
            if isExpanded && !wasExpanded {
                // Shelf just expanded - start auto-shrink timer
                startAutoShrinkTimer()
            } else if !isExpanded {
                // Shelf collapsed - cancel any pending timer and reset states
                cancelAutoShrinkTimer()
                isHoveringExpandedContent = false
                mediaHUDIsHovered = false // Reset media HUD hover state
                // Reset swipe states to prevent stale forced media showing
                musicManager.isMediaHUDForced = false
                musicManager.isMediaHUDHidden = false
            }
        }
        // HUD is now embedded in the notch content (see ZStack above)
        // MARK: - Keyboard Shortcuts
        .background {
            // Hidden button for Cmd+A select all
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
        batteryHUDWorkItem?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            batteryHUDIsVisible = true
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.3)) {
                batteryHUDIsVisible = false
            }
        }
        batteryHUDWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + batteryManager.visibleDuration, execute: workItem)
    }
    
    private func triggerCapsLockHUD() {
        capsLockHUDWorkItem?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            capsLockHUDIsVisible = true
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.3)) {
                capsLockHUDIsVisible = false
            }
        }
        capsLockHUDWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + capsLockManager.visibleDuration, execute: workItem)
    }
    
    private func triggerAirPodsHUD() {
        airPodsHUDWorkItem?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            airPodsHUDIsVisible = true
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.3)) {
                airPodsHUDIsVisible = false
                airPodsManager.dismissHUD()
            }
        }
        airPodsHUDWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + airPodsManager.visibleDuration, execute: workItem)
    }
    
    private func triggerLockScreenHUD() {
        lockScreenHUDWorkItem?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            lockScreenHUDIsVisible = true
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.3)) {
                lockScreenHUDIsVisible = false
            }
        }
        lockScreenHUDWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + lockScreenManager.visibleDuration, execute: workItem)
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
        guard autoShrinkShelf && state.isExpanded else { return }
        
        // Cancel any existing timer
        autoShrinkWorkItem?.cancel()
        
        // Start timer to auto-shrink shelf
        let workItem = DispatchWorkItem { [self] in
            // Only shrink if still expanded and not hovering over the content
            // Check both local hover state AND global mouse hover (NotchWindowController tracking)
            guard state.isExpanded && !isHoveringExpandedContent && !state.isMouseHovering && !state.isDropTargeted else { return }
            
            // CRITICAL: Don't auto-shrink if a context menu is open
            let hasActiveMenu = NSApp.windows.contains { $0.level.rawValue >= NSWindow.Level.popUpMenu.rawValue }
            guard !hasActiveMenu else { return }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                state.isExpanded = false
                state.isMouseHovering = false  // Reset hover state to go directly to regular notch
            }
        }
        autoShrinkWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(autoShrinkDelay), execute: workItem)
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


    // MARK: - Drop Zone
    
    private var dropZone: some View {
        // MILLIMETER-PRECISE DETECTION (v5.3)
        // The drop zone NEVER extends below the visible notch/island.
        // - Horizontal: ±20px expansion for fast cursor movements (both modes)
        // - Vertical: EXACT height matching the visual - NO downward expansion
        // This ensures we don't block Safari URL bars, Outlook search fields, etc.
        let isActive = enableNotchShelf && (state.isExpanded || state.isMouseHovering || dragMonitor.isDragging || state.isDropTargeted)
        
        // Both modes: Horizontal expansion when active, but height is ALWAYS exact
        let dropAreaWidth: CGFloat = isActive ? (currentNotchWidth + 40) : currentNotchWidth
        // Height is ALWAYS exactly the current visual height - NEVER expand downward
        let dropAreaHeight: CGFloat = currentNotchHeight
        
        // Calculate indicator position: exactly below the current notch height with small gap
        let indicatorOffset = currentNotchHeight + 20
        
        return ZStack(alignment: .top) {
            // Invisible hit area for hovering/clicking - SIZE CHANGES based on state
            RoundedRectangle(cornerRadius: isDynamicIslandMode ? 50 : 16, style: .continuous)
                .fill(Color.clear)
                .frame(width: dropAreaWidth, height: dropAreaHeight)
                .contentShape(RoundedRectangle(cornerRadius: isDynamicIslandMode ? 50 : 16, style: .continuous)) // Match the shape exactly
            
            // Beautiful drop indicator when hovering with files (only when shelf is enabled)
            if enableNotchShelf && showDropIndicator && state.isDropTargeted && !state.isExpanded {
                dropIndicatorContent
                    .offset(y: indicatorOffset)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.7).combined(with: .opacity).combined(with: .offset(y: -10)),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .allowsHitTesting(false)
            }
            // "Open Shelf" indicator when hovering with mouse (no drag) - only when shelf is enabled
            else if enableNotchShelf && showOpenShelfIndicator && state.isMouseHovering && !dragMonitor.isDragging && !state.isExpanded {
                openIndicatorContent
                    .offset(y: indicatorOffset)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.7).combined(with: .opacity).combined(with: .offset(y: -10)),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .allowsHitTesting(false)
            }
        }
        .onTapGesture {
            // Only allow expanding shelf when shelf is enabled
            guard enableNotchShelf else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                state.isExpanded.toggle()
            }
        }
        .onHover { isHovering in
            
            // Only update hover state if not dragging (drag state handles its own)
            if !dragMonitor.isDragging {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    // Only set mouse hovering if shelf is enabled
                    if enableNotchShelf {
                        state.isMouseHovering = isHovering
                    }
                    // Propagate hover to media HUD when music is playing (works independently)
                    // Use simple check instead of shouldShowMediaHUD to avoid flickering
                    if showMediaPlayer && musicManager.isPlaying && !state.isExpanded {
                        mediaHUDIsHovered = isHovering
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isDropTargeted)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isMouseHovering)
    }
    
    // MARK: - Indicators
    
    private var dropIndicatorContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white, .green)
                .symbolEffect(.bounce, value: state.isDropTargeted)
            
            Text("Drop!")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(indicatorBackground)
    }
    
    private var openIndicatorContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white, .blue)
                .symbolEffect(.bounce, value: state.isMouseHovering)
            
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
    // In transparent DI mode, indicators use glass material to match the DI style.
    private var indicatorBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(shouldUseDynamicIslandTransparent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    // MARK: - Expanded Content
    
    private var expandedShelfContent: some View {
        VStack(spacing: 0) {
            // Header / Controls
            HStack(spacing: 0) {
                // Close button
                NotchControlButton(icon: "chevron.up") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.isExpanded = false
                        state.isMouseHovering = false // Reset to hide "Open Shelf" indicator
                    }
                }
                .padding(.leading, 16)
                
                Spacer()
                
                // Clipboard button (optional)
                if showClipboardButton {
                    NotchControlButton(icon: "doc.on.clipboard") {
                        ClipboardWindowController.shared.toggle()
                    }
                    .padding(.trailing, 8)
                }
                
                // Clear button OR Settings button (when empty)
                if !state.items.isEmpty {
                    NotchControlButton(icon: "eraser.fill") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            state.clearAll()
                            state.isExpanded = false
                            state.isMouseHovering = false // Reset to hide indicator
                        }
                    }
                    .padding(.trailing, 16)
                } else {
                    NotchControlButton(icon: "gearshape") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            state.isExpanded = false
                        }
                        SettingsWindowController.shared.showSettings()
                    }
                    .padding(.trailing, 16)
                }
            }
            .frame(height: 54)
            .frame(width: expandedWidth)
            .contentShape(Rectangle()) // Make header clickable to deselect if needed, or just let it pass
            .onTapGesture {
                state.deselectAll()
            }
            
            // Grid Items or Media Player or Drop Zone
            ZStack {
                // Show drop zone when dragging over (takes priority)
                if state.isDropTargeted && state.items.isEmpty {
                    emptyShelfContent
                        .frame(height: currentExpandedHeight - 54)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                }
                // MEDIA PLAYER VIEW: Show if:
                // 1. User forced it via swipe (isMediaHUDForced) - shows even when paused
                // 2. Music is playing AND user hasn't hidden it (isMediaHUDHidden)
                // Both require: not idle, not drop targeted, media enabled
                else if showMediaPlayer && !musicManager.isPlayerIdle && !state.isDropTargeted && 
                        (musicManager.isMediaHUDForced || 
                         ((musicManager.isPlaying || musicManager.wasRecentlyPlaying) && !musicManager.isMediaHUDHidden && state.items.isEmpty)) {
                    MediaPlayerView(musicManager: musicManager)
                        .frame(height: currentExpandedHeight - 54)
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
                        .frame(height: currentExpandedHeight - 54)
                        // Stable identity for animation
                        .id("empty-shelf-view")
                        // Shelf slides in from LEFT when appearing (user swiped right)
                        // Shelf slides out to LEFT when disappearing (user swiped left)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                // Show items grid when items exist
                else {
                    itemsGridView
                        .frame(height: currentExpandedHeight - 54)
                        // Stable identity for animation
                        .id("items-grid-view")
                        // Same as empty shelf - items come from LEFT
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            // Smoother, more premium animation
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state.isDropTargeted)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.isPlaying)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.wasRecentlyPlaying)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.isMediaHUDForced)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: musicManager.isMediaHUDHidden)
        }
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
            Button("Hide \(isDynamicIslandMode ? "Dynamic Island" : "Notch")") {
                NotchWindowController.shared.setTemporarilyHidden(true)
            }
            Divider()
            Button("Settings...") {
                SettingsWindowController.shared.showSettings()
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
                .padding(.top, 8)
                .padding(.bottom, 6)
            }
        }
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
        HStack(spacing: 12) {
            Image(systemName: state.isDropTargeted ? "tray.and.arrow.down.fill" : "tray")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(state.isDropTargeted ? .blue : .white.opacity(0.7))
                .symbolEffect(.bounce, value: state.isDropTargeted)
            
            Text(state.isDropTargeted ? "Drop!" : "Drop files here")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(state.isDropTargeted ? Color.white : Color.white.opacity(0.5))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    state.isDropTargeted ? Color.blue : Color.white.opacity(0.2),
                    style: StrokeStyle(
                        lineWidth: state.isDropTargeted ? 2 : 1.5,
                        lineCap: .round,
                        dash: [6, 8],
                        dashPhase: dropZoneDashPhase
                    )
                )
        )
        .padding(EdgeInsets(top: 10, leading: 20, bottom: 20, trailing: 20))
        .scaleEffect(state.isDropTargeted ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isDropTargeted)
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                dropZoneDashPhase -= 280 // Multiple of 14 (6+8) for smooth loop
            }
        }
    }
}

