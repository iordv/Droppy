//
//  NotchShelfView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

private let notchShelfDebugLogs = false

@inline(__always)
private func notchShelfDebugLog(_ message: @autoclosure () -> String) {
    guard notchShelfDebugLogs else { return }
    print(message())
}

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
    @AppStorage(AppPreferenceKey.showIdleNotchOnExternalDisplays) private var showIdleNotchOnExternalDisplays = PreferenceDefault.showIdleNotchOnExternalDisplays
    @AppStorage(AppPreferenceKey.enableHUDReplacement) private var enableHUDReplacement = PreferenceDefault.enableHUDReplacement
    @AppStorage(AppPreferenceKey.enableVolumeHUDReplacement) private var enableVolumeHUDReplacement = PreferenceDefault.enableVolumeHUDReplacement
    @AppStorage(AppPreferenceKey.enableBrightnessHUDReplacement) private var enableBrightnessHUDReplacement = PreferenceDefault.enableBrightnessHUDReplacement
    @AppStorage(AppPreferenceKey.enableBatteryHUD) private var enableBatteryHUD = PreferenceDefault.enableBatteryHUD
    @AppStorage(AppPreferenceKey.enableCapsLockHUD) private var enableCapsLockHUD = PreferenceDefault.enableCapsLockHUD
    @AppStorage(AppPreferenceKey.enableAirPodsHUD) private var enableAirPodsHUD = PreferenceDefault.enableAirPodsHUD
    @AppStorage(AppPreferenceKey.enableLockScreenHUD) private var enableLockScreenHUD = PreferenceDefault.enableLockScreenHUD
    @AppStorage(AppPreferenceKey.enableDNDHUD) private var enableDNDHUD = PreferenceDefault.enableDNDHUD
    @AppStorage(AppPreferenceKey.enableUpdateHUD) private var enableUpdateHUD = PreferenceDefault.enableUpdateHUD
    @AppStorage(AppPreferenceKey.showMediaPlayer) private var showMediaPlayer = PreferenceDefault.showMediaPlayer
    @AppStorage(AppPreferenceKey.showExternalMouseSwitchButton) private var showExternalMouseSwitchButton = PreferenceDefault.showExternalMouseSwitchButton
    @AppStorage(AppPreferenceKey.autoFadeMediaHUD) private var autoFadeMediaHUD = PreferenceDefault.autoFadeMediaHUD
    @AppStorage(AppPreferenceKey.debounceMediaChanges) private var debounceMediaChanges = PreferenceDefault.debounceMediaChanges
    @AppStorage(AppPreferenceKey.autoShrinkShelf) private var autoShrinkShelf = PreferenceDefault.autoShrinkShelf  // Legacy
    @AppStorage(AppPreferenceKey.autoShrinkDelay) private var autoShrinkDelay = PreferenceDefault.autoShrinkDelay  // Legacy
    @AppStorage(AppPreferenceKey.autoCollapseDelay) private var autoCollapseDelay = PreferenceDefault.autoCollapseDelay
    @AppStorage(AppPreferenceKey.autoCollapseShelf) private var autoCollapseShelf = PreferenceDefault.autoCollapseShelf
    @AppStorage(AppPreferenceKey.autoExpandDelay) private var autoExpandDelay = PreferenceDefault.autoExpandDelay
    @AppStorage(AppPreferenceKey.autoOpenMediaHUDOnShelfExpand) private var autoOpenMediaHUDOnShelfExpand = PreferenceDefault.autoOpenMediaHUDOnShelfExpand
    @AppStorage(AppPreferenceKey.showClipboardButton) private var showClipboardButton = PreferenceDefault.showClipboardButton
    @AppStorage(AppPreferenceKey.showDropIndicator) private var showDropIndicator = PreferenceDefault.showDropIndicator  // Legacy, not migrated
    @AppStorage(AppPreferenceKey.useDynamicIslandStyle) private var useDynamicIslandStyle = PreferenceDefault.useDynamicIslandStyle
    @AppStorage(AppPreferenceKey.dynamicIslandHeightOffset) private var dynamicIslandHeightOffset = PreferenceDefault.dynamicIslandHeightOffset
    @AppStorage(AppPreferenceKey.notchWidthOffset) private var notchWidthOffset = PreferenceDefault.notchWidthOffset
    @AppStorage(AppPreferenceKey.useDynamicIslandTransparent) private var useDynamicIslandTransparent = PreferenceDefault.useDynamicIslandTransparent
    @AppStorage(AppPreferenceKey.enableAutoClean) private var enableAutoClean = PreferenceDefault.enableAutoClean
    @AppStorage(AppPreferenceKey.enableQuickActions) private var enableQuickActions = PreferenceDefault.enableQuickActions
    @AppStorage(AppPreferenceKey.enableRightClickHide) private var enableRightClickHide = PreferenceDefault.enableRightClickHide
    @AppStorage(AppPreferenceKey.enableLockScreenMediaWidget) private var enableLockScreenMediaWidget = PreferenceDefault.enableLockScreenMediaWidget
    @AppStorage(AppPreferenceKey.enableGradientVisualizer) private var enableGradientVisualizer = PreferenceDefault.enableGradientVisualizer
    @AppStorage(AppPreferenceKey.enableMediaAlbumArtGlow) private var enableMediaAlbumArtGlow = PreferenceDefault.enableMediaAlbumArtGlow
    @AppStorage(AppPreferenceKey.cameraInstalled) private var cameraInstalled = PreferenceDefault.cameraInstalled
    @AppStorage(AppPreferenceKey.cameraEnabled) private var cameraEnabled = PreferenceDefault.cameraEnabled
    @AppStorage(AppPreferenceKey.todoShelfSplitViewEnabled) private var todoShelfSplitViewEnabled = PreferenceDefault.todoShelfSplitViewEnabled

    
    // HUD State - Use @ObservedObject for singletons (they manage their own lifecycle)
    @ObservedObject private var volumeManager = VolumeManager.shared
    @ObservedObject private var brightnessManager = BrightnessManager.shared
    @ObservedObject private var batteryManager = BatteryManager.shared
    @ObservedObject private var capsLockManager = CapsLockManager.shared
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var externalMouseMonitor = ExternalMouseMonitor.shared
    @ObservedObject private var notchController = NotchWindowController.shared  // For hide/show animation
    var airPodsManager = AirPodsManager.shared  // @Observable - no wrapper needed
    @ObservedObject private var lockScreenManager = LockScreenManager.shared
    @ObservedObject private var dndManager = DNDManager.shared
    @ObservedObject private var terminalManager = TerminalNotchManager.shared
    @ObservedObject private var cameraManager = CameraManager.shared
    var caffeineManager = CaffeineManager.shared  // @Observable - no wrapper needed
    var todoManager = ToDoManager.shared  // @Observable - no wrapper needed
    var hudManager = HUDManager.shared  // @Observable - needed for notification HUD visibility tracking
    var notificationHUDManager = NotificationHUDManager.shared  // @Observable - needed for current notification tracking
    @AppStorage(AppPreferenceKey.caffeineEnabled) private var caffeineEnabled = PreferenceDefault.caffeineEnabled
    @AppStorage(AppPreferenceKey.caffeineInstantlyExpandShelfOnHover) private var caffeineInstantlyExpandShelfOnHover = PreferenceDefault.caffeineInstantlyExpandShelfOnHover
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
    @State private var browserTrackLoadingWorkItem: DispatchWorkItem?
    @State private var browserTrackLoadingUntil: Date = .distantPast
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
    @State private var shelfScrollView: NSScrollView?
    @State private var shelfScrollViewportFrame: CGRect = .zero
    @State private var shelfAutoScrollVelocity: CGFloat = 0
    private let shelfAutoScrollTicker = Timer.publish(every: 1.0 / 90.0, on: .main, in: .common).autoconnect()
    
    // Global rename state
    @State private var renamingItemId: UUID?
    
    // Media HUD hover state - used to grow notch when showing song title
    @State private var mediaHUDIsHovered: Bool = false
    @State private var mediaHUDHoverWorkItem: DispatchWorkItem?  // Debounce for hover state
    @State private var externalCollapseVisibilityHold = false
    @State private var externalCollapseVisibilityWorkItem: DispatchWorkItem?
    @State private var capsLockLayoutIsOn = CapsLockManager.shared.isCapsLockOn
    
    // PREMIUM: Dedicated state for hover scale effect - ensures clean single-value animation
    @State private var hoverScaleActive: Bool = false
    
    // FIX #126: Haptic debounce to prevent spam from rapid hover oscillation
    @State private var lastHoverHapticTime: Date = .distantPast
    
    // PREMIUM: Album art interaction states
    @State private var albumArtNudgeOffset: CGFloat = 0  // ±6pt nudge on prev/next tap
    @State private var albumArtParallaxOffset: CGSize = .zero  // Cursor-following parallax effect
    @State private var albumArtTapScale: CGFloat = 1.0  // Subtle grow effect when clicking to open source
    @State private var mediaOverlayAppeared: Bool = false  // Scale+opacity appear animation for morphing overlays
    
    // Caffeine extension view state
    @State private var showCaffeineView: Bool = false
    @State private var showCameraView: Bool = false

    // Todo extension state (for in-shelf input bar)
    @State private var isTodoListExpanded: Bool = false
    @State private var lastPopoverDismissedAt: Date = .distantPast

    // MORPH: Namespace for album art morphing between HUD and expanded player
    @Namespace private var albumArtNamespace
    
    // Removed isDropTargeted state as we use shared state now
    
    /// Dynamic Island background color - now pure black to match notch appearance
    private var dynamicIslandGray: Color {
        Color.black
    }

    private func resetTodoExpansionStateWithoutAnimation() {
        if isTodoListExpanded {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                isTodoListExpanded = false
            }
        }
        todoManager.isShelfListExpanded = false
    }
    
    /// Dynamic notch width based on screen's actual safe areas
    /// This properly handles all resolutions including "More Space" settings
    private var notchWidth: CGFloat {
        // Dynamic Island uses SSOT fixed size
        if isDynamicIslandMode { return NotchLayoutConstants.dynamicIslandWidth }

        // Use target screen or fallback to built-in
        let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main
        _ = notchWidthOffset // Keep @AppStorage reactive updates tied to width recomputation.
        return NotchLayoutConstants.notchWidth(for: screen)
    }
    
    /// Notch height - scales with resolution
    private var notchHeight: CGFloat {
        // Dynamic Island uses SSOT fixed size + user height offset
        // Reference dynamicIslandHeightOffset to trigger SwiftUI update when slider changes
        if isDynamicIslandMode { _ = dynamicIslandHeightOffset; return NotchLayoutConstants.dynamicIslandHeight }

        // Use target screen or fallback to built-in
        // CRITICAL: Return physical notch height when screen is unavailable for stable positioning
        guard let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return NotchLayoutConstants.physicalNotchHeight }
        
        // CRITICAL: For screens with a physical notch (detected via auxiliary areas),
        // use safeAreaInsets when available, otherwise fall back to fixed constant
        // This ensures stable positioning on lock screen when safeAreaInsets may be 0
        let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        
        if hasPhysicalNotch {
            let topInset = screen.safeAreaInsets.top
            return topInset > 0 ? topInset : NotchLayoutConstants.physicalNotchHeight
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
        // CRITICAL: Return false (notch mode) when screen is unavailable to prevent layout jumps
        // During lock screen transitions, NSScreen.screens can be momentarily empty/unavailable
        // Defaulting to notch mode is safer for built-in MacBooks and prevents DI mode flickering
        guard let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return false }
        // CRITICAL: Use auxiliary areas to detect physical notch, NOT safeAreaInsets
        // safeAreaInsets.top can be 0 on lock screen (no menu bar), but auxiliary areas
        // are hardware-based and always present for notch MacBooks
        let hasNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
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

    /// True when the current display has a physical camera notch.
    private var hasPhysicalNotchOnDisplay: Bool {
        guard let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return false }
        return screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
    }
    
    /// Whether the Dynamic Island should use transparent glass effect
    /// Uses the main "Transparent Background" setting
    private var shouldUseDynamicIslandTransparent: Bool {
        isDynamicIslandMode && useTransparentBackground
    }
    
    /// Whether the external display notch should use transparent glass effect
    /// Uses the main "Transparent Background" setting
    private var shouldUseExternalNotchTransparent: Bool {
        isExternalDisplay && useTransparentBackground
    }
    
    /// Whether floating buttons should use transparent glass effect
    /// Built-in physical notch displays always stay solid black.
    /// External and notchless displays may use transparent glass.
    private var shouldUseFloatingButtonTransparent: Bool {
        guard !hasPhysicalNotchOnDisplay else { return false }
        return useTransparentBackground
    }

    /// Adaptive foregrounds only for transparent non-physical notch content.
    /// Physical notch surfaces remain white-on-black.
    private func notchPrimaryText(_ opacity: Double = 1.0) -> Color {
        shouldUseExternalNotchTransparent
            ? AdaptiveColors.primaryTextAuto.opacity(opacity)
            : .white.opacity(opacity)
    }

    private func notchOverlayTone(_ opacity: Double) -> Color {
        shouldUseExternalNotchTransparent
            ? AdaptiveColors.overlayAuto(opacity)
            : .white.opacity(opacity)
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

    /// Keep ToDo host inset aligned with the active notch/island content inset
    /// so empty-state content stays perfectly centered across all display modes.
    private var todoHostHorizontalInset: CGFloat {
        NotchLayoutConstants.contentEdgeInsets(
            notchHeight: contentLayoutNotchHeight,
            isExternalWithNotchStyle: isExternalDisplay && !externalDisplayUseDynamicIsland
        ).leading
    }

    /// Keep hover-scale feedback strictly in collapsed mode so list expansion
    /// only grows downward and never nudges the top edge.
    private var notchHoverScale: CGFloat {
        guard hoverScaleActive && !isExpandedOnThisScreen && !isTodoListExpanded else { return 1.0 }

        // External Dynamic Island gets no hover scale to avoid side-to-side wobble feel.
        if isExternalDisplay && isDynamicIslandMode {
            return 1.0
        }

        return 1.02
    }

    private var displayHoverAnimation: Animation {
        if isExternalDisplay {
            return DroppyAnimation.smooth(duration: 0.28, for: targetScreen)
        }
        return DroppyAnimation.hoverBouncy(for: targetScreen)
    }

    private var displayNotchStateAnimation: Animation {
        DroppyAnimation.notchState(for: targetScreen)
    }

    /// Canonical open/close motion profile.
    /// Mirrors the temporary hide/re-show path so shelf, HUDs, and expanded views
    /// all animate on the same buttery curve.
    private var displayUnifiedOpenCloseAnimation: Animation {
        displayNotchStateAnimation
    }

    private var displayExpandOpenAnimation: Animation {
        displayUnifiedOpenCloseAnimation
    }

    private var displayExpandCloseAnimation: Animation {
        displayUnifiedOpenCloseAnimation
    }

    private var displayUnifiedSurfaceTransition: AnyTransition {
        DroppyAnimation.notchViewTransitionBlurOnly(for: targetScreen)
            .animation(displayUnifiedOpenCloseAnimation)
    }

    private var displayUnifiedButtonTransition: AnyTransition {
        DroppyAnimation.notchButtonTransition(for: targetScreen)
            .animation(displayUnifiedOpenCloseAnimation)
    }

    private var displayUnifiedElementTransition: AnyTransition {
        DroppyAnimation.notchElementTransition(for: targetScreen)
            .animation(displayUnifiedOpenCloseAnimation)
    }

    private var displayContentSwapTransition: AnyTransition {
        displayUnifiedSurfaceTransition
    }

    private var displayHUDTransition: AnyTransition {
        displayUnifiedSurfaceTransition
    }

    private var displayMediaHUDTransition: AnyTransition {
        displayUnifiedSurfaceTransition
    }

    private var displayButtonTransition: AnyTransition {
        displayUnifiedButtonTransition
    }

    private var displayElementTransition: AnyTransition {
        displayUnifiedElementTransition
    }

    private var expandedSurfaceTransition: AnyTransition {
        displayUnifiedSurfaceTransition
    }

    private enum NotchAnimationPhase: Int {
        case hidden
        case expanded
        case systemHUD
        case mediaHUD
        case dragging
        case hovering
        case idle
    }

    private var notchAnimationPhase: NotchAnimationPhase {
        if notchController.isTemporarilyHidden { return .hidden }
        if isExpandedOnThisScreen { return .expanded }
        if hudIsVisible || HUDManager.shared.isVisible { return .systemHUD }
        if isMediaHUDSurfaceActive { return .mediaHUD }
        if dragMonitor.isDragging || state.isDropTargeted { return .dragging }
        if isHoveringOnThisScreen { return .hovering }
        return .idle
    }

    private var displayContainerAnimation: Animation {
        displayUnifiedOpenCloseAnimation
    }

    /// Single animation token for media swipe state changes.
    /// Avoids duplicate subtree animations when forced/hidden toggle together.
    private var mediaHUDTransitionToken: Int {
        (musicManager.isMediaHUDForced ? 1 : 0) | (musicManager.isMediaHUDHidden ? 2 : 0)
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
    
    /// Display ID represented by this specific NotchShelfView instance.
    private var thisDisplayID: CGDirectDisplayID? {
        targetScreen?.displayID
            ?? NSScreen.builtIn?.displayID
            ?? NSScreen.builtInWithNotch?.displayID
            ?? NSScreen.main?.displayID
            ?? NSScreen.screens.first?.displayID
    }
    
    /// Gate media-key HUD updates so only the target display renders volume/brightness changes.
    private func shouldShowMediaKeyHUD(on changedDisplayID: CGDirectDisplayID?) -> Bool {
        guard let currentDisplayID = thisDisplayID else { return true }
        
        if let changedDisplayID {
            return currentDisplayID == changedDisplayID
        }
        
        // Legacy fallback for events that don't carry target display metadata.
        let fallbackDisplayID = NSScreen.builtIn?.displayID
            ?? NSScreen.builtInWithNotch?.displayID
            ?? NSScreen.main?.displayID
            ?? currentDisplayID
        
        return currentDisplayID == fallbackDisplayID
    }
    
    /// Top margin for Dynamic Island from SSOT - creates floating effect like iPhone
    private var dynamicIslandTopMargin: CGFloat { NotchLayoutConstants.dynamicIslandTopMargin }
    
    /// Width when showing files (matches media player width for visual consistency)
    private let shelfWidth: CGFloat = 450
    private let todoSplitViewShelfWidth: CGFloat = 920
    
    /// Width when showing media player (wider for album art + controls)
    private let mediaPlayerWidth: CGFloat = 450

    private var isTerminalViewVisible: Bool {
        let terminalEnabled = UserDefaults.standard.preference(AppPreferenceKey.terminalNotchEnabled, default: PreferenceDefault.terminalNotchEnabled)
        return terminalManager.isInstalled && terminalEnabled && terminalManager.isVisible
    }

    private var caffeineExtensionEnabled: Bool {
        UserDefaults.standard.preference(AppPreferenceKey.caffeineInstalled, default: PreferenceDefault.caffeineInstalled) &&
        UserDefaults.standard.preference(AppPreferenceKey.caffeineEnabled, default: PreferenceDefault.caffeineEnabled)
    }

    private var isCaffeineViewVisible: Bool {
        showCaffeineView && caffeineExtensionEnabled
    }

    private var isMediaPlayerVisibleInShelf: Bool {
        let isForced = musicManager.isMediaHUDForced
        let autoOrSongDriven = (autoOpenMediaHUDOnShelfExpand && !musicManager.isMediaHUDHidden) ||
            ((musicManager.isPlaying || musicManager.wasRecentlyPlaying) &&
             !musicManager.isMediaHUDHidden &&
             state.items.isEmpty)
        let shouldBlockAutoSwitch = shouldLockMediaForTodo

        return showMediaPlayer &&
        !isCameraViewVisible &&
        !state.isDropTargeted &&
        !dragMonitor.isDragging &&
        !musicManager.isPlayerIdle &&
        !shouldBlockAutoSwitch &&
        (isForced || autoOrSongDriven)
    }

    private var shouldShowExternalMouseSwitchFloatingButton: Bool {
        showExternalMouseSwitchButton &&
        externalMouseMonitor.hasExternalMouse &&
        showMediaPlayer &&
        !musicManager.isPlayerIdle &&
        !isTerminalViewVisible &&
        !isCaffeineViewVisible &&
        !isCameraViewVisible &&
        !shouldLockMediaForTodo
    }

    private var isShowingExpandedMediaSurface: Bool {
        isMediaPlayerVisibleInShelf
    }

    private var isTodoExtensionActive: Bool {
        let todoInstalled = UserDefaults.standard.preference(AppPreferenceKey.todoInstalled, default: PreferenceDefault.todoInstalled)
        return todoInstalled && !ExtensionType.todo.isRemoved
    }

    private var cameraExtensionEnabled: Bool {
        cameraInstalled &&
        cameraEnabled &&
        !ExtensionType.camera.isRemoved
    }

    private var canShowCameraFloatingButton: Bool {
        cameraExtensionEnabled &&
        state.shelfDisplaySlotCount == 0 &&
        !todoManager.isVisible &&
        !isTerminalViewVisible
    }

    private var isCameraViewVisible: Bool {
        showCameraView && canShowCameraFloatingButton
    }

    /// Keep To-do in focus only on the display where To-do is actively being used.
    /// Prevents cross-display media blocking.
    private var shouldLockMediaForTodo: Bool {
        let todoCanOwnShelfOnThisScreen = isExpandedOnThisScreen &&
            isTodoExtensionActive &&
            state.shelfDisplaySlotCount == 0 &&
            !isTerminalViewVisible &&
            !isCaffeineViewVisible

        let isActiveTodoListSession = todoCanOwnShelfOnThisScreen &&
            (isTodoListExpanded || todoManager.isEditingText || todoManager.isInteractingWithPopover)

        // Full To-do view editing should only lock media for the actively expanded display.
        let isFullTodoViewSession = isExpandedOnThisScreen && todoManager.isVisible

        return isActiveTodoListSession || isFullTodoViewSession
    }

    private var shouldShowTodoShelfBar: Bool {
        shouldAttachTodoShelfBar &&
        state.shelfDisplaySlotCount == 0
    }

    private var shouldUseTodoSplitShelfWidth: Bool {
        shouldShowTodoShelfBar &&
        isTodoListExpanded &&
        todoShelfSplitViewEnabled
    }

    private var shouldAttachTodoShelfBar: Bool {
        shouldAttachTodoShelfBarBase &&
        (!isMediaPlayerVisibleInShelf || isTodoListExpanded)
    }

    private var shouldAttachTodoShelfBarBase: Bool {
        isTodoExtensionActive &&
        !isTerminalViewVisible &&
        !isCaffeineViewVisible &&
        !isCameraViewVisible
    }

    /// Current expanded width based on what's shown
    /// Apple Music gets extra width for shuffle, repeat, and love controls
    private var expandedWidth: CGFloat {
        // Media player gets full width, shelf gets narrower width
        if isMediaPlayerVisibleInShelf {
            // Apple Music needs extra width for additional controls (shuffle, repeat, love)
            let appleMusicExtraWidth: CGFloat = musicManager.isAppleMusicSource ? 50 : 0
            return mediaPlayerWidth + appleMusicExtraWidth
        }
        if shouldUseTodoSplitShelfWidth {
            return max(shelfWidth, todoSplitViewShelfWidth)
        }
        return shelfWidth
    }
    
    /// Media player horizontal layout dimensions (v8.1.5 redesign)
    /// Wider but shorter for horizontal album art + controls layout
    private let mediaPlayerExpandedWidth: CGFloat = 480
    /// Content height matching shelf pattern exactly (SSOT: uses NotchLayoutConstants):
    /// DI/external mode (v21.68): 30pt top + 100pt album + 30pt bottom = 160pt (30pt symmetry)
    /// Built-in notch mode: notchHeight (top) + 100pt album + 20pt (bottom) = notchHeight + 120
    private let mediaPlayerContentHeight: CGFloat = 160
    
    /// Fixed wing sizes (area left/right of notch for content)  
    /// Using fixed sizes ensures consistent content positioning across all screen resolutions
    private let volumeWingWidth: CGFloat = 135  // For volume/brightness - wide for icon + label + slider
    private let batteryWingWidth: CGFloat = 65  // For battery icon + percentage (must fit "100%")
    /// For High Alert - use consistently wide wings for timer text
    /// 130pt ensures "H:MM:SS" format fits with monospaced font
    private var highAlertWingWidth: CGFloat {
        return 130  // Wide enough for all timer formats
    }
    private let mediaWingWidth: CGFloat = 50    // For album art + visualizer
    private let updateWingWidth: CGFloat = 110  // For Update HUD - icon + "Update" + "Droppy X.X.X"
    
    /// HUD dimensions calculated as notchWidth + (2 * wingWidth)
    /// This ensures wings are FIXED size regardless of notch size
    /// Volume and Brightness use IDENTICAL widths for visual consistency
    private var volumeHudWidth: CGFloat {
        // External monitors (both island and notch mode): use wider layout to fit content
        // Built-in MacBook notch: use wide layout for proper fit around physical notch
        if isExternalDisplay || isDynamicIslandMode {
            return 360  // Wide enough for icon + slider + percentage
        }
        return notchWidth + (volumeWingWidth * 2) + 20  // Wide for built-in notch
    }
    
    /// Brightness HUD - same width as Volume for visual consistency
    private var brightnessHudWidth: CGFloat {
        // External monitors (both island and notch mode): use wider layout to fit content
        // Built-in MacBook notch: use wide layout
        if isExternalDisplay || isDynamicIslandMode {
            return 360  // Wide enough for icon + slider + percentage
        }
        return notchWidth + (volumeWingWidth * 2) + 20  // Wide for built-in notch
    }
    
    /// Returns appropriate HUD width based on current hudType
    /// Note: Both types now use same width for consistency
    private var currentHudTypeWidth: CGFloat {
        hudType == .brightness ? brightnessHudWidth : volumeHudWidth
    }
    
    /// Battery HUD - slightly narrower wings (battery icon + percentage)
    private var batteryHudWidth: CGFloat {
        // Base content widths:
        // - DI built-in: 100pt (compact)
        // - External notch style: needs 160pt base (was 180pt with compensation)
        let diContentWidth: CGFloat = 100
        let externalNotchWidth: CGFloat = 180  // Matches original working width
        
        if isDynamicIslandMode {
            return diContentWidth
        }
        if isExternalDisplay {
            // External with notch style: use full width that was tested to work
            return externalNotchWidth
        }
        // Built-in notch: geometry-based
        return notchWidth + (batteryWingWidth * 2)
    }
    
    /// Caps Lock HUD - same as battery when ON, slightly wider when OFF
    /// so the status badge never clips into the physical notch area.
    private var capsLockHudWidth: CGFloat {
        if isDynamicIslandMode {
            return 100
        }
        if isExternalDisplay {
            return 180
        }
        let onWingWidth: CGFloat = batteryWingWidth
        let offWingWidth: CGFloat = batteryWingWidth + 10
        let targetWingWidth = capsLockLayoutIsOn ? onWingWidth : offWingWidth
        return notchWidth + (targetWingWidth * 2)
    }
    
    /// High Alert HUD - wider wings than Caps Lock for timer text
    private var highAlertHudWidth: CGFloat {
        // Fixed content widths - always wide enough for any timer format
        let diContentWidth: CGFloat = 240  // DI mode: icon + timer text (monospaced)
        let externalNotchWidth: CGFloat = 280  // External notch mode: wider for timer
        
        if isDynamicIslandMode {
            return diContentWidth
        }
        if isExternalDisplay {
            return externalNotchWidth
        }
        // Built-in notch: geometry-based - MUST match batteryHudWidth pattern
        return notchWidth + (highAlertWingWidth * 2)
    }
    
    /// Media HUD - compact wings for album art / visualizer
    private var hudWidth: CGFloat {
        // Base content width for Dynamic Island layout (album art + title + visualizer)
        let diContentWidth: CGFloat = 260
        // Curved corner compensation: 10pt each side when using notch visual style
        let curvedCornerCompensation: CGFloat = 20
        
        if isDynamicIslandMode {
            // Pure DI mode: no curved corners to compensate for
            return diContentWidth
        }
        if isExternalDisplay {
            // External with notch style: DI content + compensation for curved corners
            return diContentWidth + curvedCornerCompensation
        }
        // Built-in notch mode: use notch geometry
        return notchWidth + (mediaWingWidth * 2)
    }
    private let hudHeight: CGFloat = 73
    
    /// Update HUD - wider wings to fit "Update" + icon on left and "Droppy X.X.X" on right
    private var updateHudWidth: CGFloat {
        // Base content width for DI layout
        let diContentWidth: CGFloat = 240
        let curvedCornerCompensation: CGFloat = 20
        
        if isDynamicIslandMode {
            return diContentWidth
        }
        if isExternalDisplay {
            // External with notch style: DI content + curved corner compensation
            return diContentWidth + curvedCornerCompensation
        }
        // Built-in notch: geometry-based
        return notchWidth + (updateWingWidth * 2)
    }
    
    /// Whether media player HUD should be shown
    private var shouldShowMediaHUD: Bool {
        // Media features require macOS 15.0+
        guard musicManager.isMediaAvailable else { return false }
        let browserTrackLoading = isBrowserTrackLoading
        let mediaIsActive = (musicManager.isPlaying && !musicManager.songTitle.isEmpty) || browserTrackLoading
        
        // CAFFEINE HOVER TAKES PRIORITY: When hovering with caffeine active, suppress media
        if isCaffeineHoverActive { return false }
        
        // FORCED MODE: Show if user swiped to show media, regardless of playback state
        // (as long as there's a track to show)
        if musicManager.isMediaHUDForced && !musicManager.isPlayerIdle {
            // Don't show if other HUDs have priority
            if HUDManager.shared.isVisible || hudIsVisible { return false }
            if isExpandedOnThisScreen { return false }
            if let displayID = targetScreen?.displayID,
               notchController.fullscreenDisplayIDs.contains(displayID) {
                return false
            }
            return showMediaPlayer
        }
        
        // Don't show if auto-fade is enabled and it has faded out
        if autoFadeMediaHUD && mediaHUDFadedOut {
            return false
        }
        // Only apply debounce check when setting is enabled
        if debounceMediaChanges && !isMediaStable && !browserTrackLoading { return false }
        // Don't show when any HUD is visible (they take priority)
        if HUDManager.shared.isVisible { return false }
        if let displayID = targetScreen?.displayID,
           notchController.fullscreenDisplayIDs.contains(displayID) {
            return false
        }
        return showMediaPlayer &&
            mediaIsActive &&
            !hudIsVisible &&
            !isExpandedOnThisScreen
    }

    private var isBrowserTrackLoading: Bool {
        guard musicManager.isBrowserSource else { return false }
        return Date() < browserTrackLoadingUntil
    }

    private var isMediaHUDHoverEligible: Bool {
        guard musicManager.isMediaAvailable else { return false }
        guard showMediaPlayer else { return false }
        guard musicManager.isPlaying else { return false }
        guard !musicManager.songTitle.isEmpty else { return false }
        guard !musicManager.isPlayerIdle else { return false }
        guard !(autoFadeMediaHUD && mediaHUDFadedOut) else { return false }
        guard !debounceMediaChanges || isMediaStable else { return false }
        guard !hudIsVisible && !HUDManager.shared.isVisible else { return false }
        guard !isExpandedOnThisScreen else { return false }
        guard !isCaffeineHoverActive else { return false }
        guard !shouldLockMediaForTodo else { return false }

        if let displayID = targetScreen?.displayID {
            return !notchController.fullscreenDisplayIDs.contains(displayID)
        }
        return true
    }

    /// Unified media-surface state so hover-triggered and click-triggered
    /// media transitions follow the same geometry and animation path.
    private var isMediaHUDSurfaceActive: Bool {
        shouldShowMediaHUD || (mediaHUDIsHovered && isMediaHUDHoverEligible)
    }

    /// Files shown in collapsed peek mode while shelf is closed.
    private var collapsedShelfPeekItems: [DroppedItem] {
        state.shelfPowerFolders + state.shelfItems
    }

    /// Render compact stacked preview when shelf has files but is not expanded.
    private var shouldShowCollapsedShelfPeek: Bool {
        enableNotchShelf &&
        !isExpandedOnThisScreen &&
        !collapsedShelfPeekItems.isEmpty &&
        !state.isDropTargeted &&
        !hudIsVisible &&
        !HUDManager.shared.isVisible &&
        !isMediaHUDSurfaceActive &&
        !isCaffeineHoverActive
    }
    
    /// Whether caffeine hover indicator should show (takes priority over media HUD)
    /// Disabled when user prefers instant shelf expand on hover.
    /// CRITICAL: Uses isHoveringOnThisScreen for multi-monitor awareness
    private var isCaffeineHoverActive: Bool {
        isHoveringOnThisScreen &&
        caffeineExtensionEnabled &&
        CaffeineManager.shared.isActive &&
        !caffeineInstantlyExpandShelfOnHover &&
        !isExpandedOnThisScreen &&
        !HUDManager.shared.isVisible
    }

    /// Inline lock HUD should only render when there is no dedicated lock-screen surface active.
    /// This prevents duplicate lock icons and ghosting during lock/unlock handoff.
    private var shouldRenderInlineLockScreenHUD: Bool {
        HUDManager.shared.isLockScreenHUDVisible &&
        enableLockScreenHUD &&
        !lockScreenManager.isDedicatedHUDActive
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
        // CAFFEINE HOVER TAKES HIGHEST PRIORITY (after volume/brightness HUDs)
        } else if isCaffeineHoverActive {
            return highAlertHudWidth
        // Pre-arm inline geometry during dedicated lock-HUD handoff to prevent width jump.
        } else if HUDManager.shared.isLockScreenHUDVisible && enableLockScreenHUD {
            return batteryHudWidth
        } else if shouldRenderInlineLockScreenHUD && !isCaffeineHoverActive {
            return batteryHudWidth  // Lock Screen HUD uses same width as battery HUD
        } else if HUDManager.shared.isAirPodsHUDVisible && enableAirPodsHUD {
            return hudWidth  // AirPods HUD uses same width as Media HUD
        } else if HUDManager.shared.isBatteryHUDVisible && enableBatteryHUD {
            return batteryHudWidth  // Battery HUD uses slightly narrower width than volume
        } else if HUDManager.shared.isCapsLockHUDVisible && enableCapsLockHUD {
            return capsLockHudWidth  // OFF state needs a bit more width for the status badge
        } else if HUDManager.shared.isHighAlertHUDVisible && caffeineExtensionEnabled {
            return highAlertHudWidth  // High Alert HUD uses wider width for "Active/Inactive" text
        } else if HUDManager.shared.isDNDHUDVisible && enableDNDHUD {
            return batteryHudWidth  // Focus/DND HUD uses same width as battery HUD
        } else if HUDManager.shared.isUpdateHUDVisible && enableUpdateHUD {
            return updateHudWidth  // Update HUD uses wider width to fit "Update" + version text
        } else if hudManager.isNotificationHUDVisible && notificationHUDManager.canRenderNotificationHUD {
            // Notification HUD: mode-aware width
            return isDynamicIslandMode ? hudWidth : expandedWidth
        } else if isMediaHUDSurfaceActive {
            return hudWidth  // Media HUD uses tighter wings
        } else if enableNotchShelf && isHoveringOnThisScreen {
            // When High Alert is active, expand enough to show timer on hover
            if CaffeineManager.shared.isActive && caffeineExtensionEnabled && !caffeineInstantlyExpandShelfOnHover {
                return highAlertHudWidth
            }
            // Keep hover width stable so collapse/open always stays visually centered.
            return notchWidth
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
        } else if shouldRenderInlineLockScreenHUD {
            return notchHeight  // Lock Screen HUD just uses notch height
        } else if HUDManager.shared.isAirPodsHUDVisible && enableAirPodsHUD {
            // AirPods HUD stays at notch height like media player (horizontal expansion only)
            return notchHeight
        } else if HUDManager.shared.isBatteryHUDVisible && enableBatteryHUD {
            return notchHeight  // Battery HUD just uses notch height (no slider)
        } else if HUDManager.shared.isCapsLockHUDVisible && enableCapsLockHUD {
            return notchHeight  // Caps Lock HUD just uses notch height (no slider)
        } else if HUDManager.shared.isHighAlertHUDVisible && caffeineExtensionEnabled {
            return notchHeight  // High Alert HUD just uses notch height (no slider)
        } else if HUDManager.shared.isDNDHUDVisible && enableDNDHUD {
            return notchHeight  // Focus/DND HUD just uses notch height (no slider)
        } else if HUDManager.shared.isUpdateHUDVisible && enableUpdateHUD {
            return notchHeight  // Update HUD just uses notch height (no slider)
        } else if hudManager.isNotificationHUDVisible && notificationHUDManager.canRenderNotificationHUD {
            // Notification HUD: keep notch container height in sync with render height
            // to prevent bottom clipping/padding mismatch.
            return notificationHUDHeight
        } else if isMediaHUDSurfaceActive {
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
        if isTerminalViewVisible {
            // SSOT (v21.72): Different base heights for different modes:
            // - Pure Island mode: 30 (top) + 140 content + 30 (bottom) = 200pt
            // - External notch style: 20 (top) + 140 content + 20 (bottom) = 180pt
            // - Built-in notch mode: notchHeight (top) + 140 content + 20 (bottom)
            let isExternalNotchStyle = isExternalDisplay && !externalDisplayUseDynamicIsland
            if contentLayoutNotchHeight > 0 {
                // Built-in notch mode: notchHeight + 160
                return contentLayoutNotchHeight + 160
            } else if isExternalNotchStyle {
                // External notch style: 180pt (20 top + 140 content + 20 bottom)
                // Symmetric vertical padding for visual balance
                return 180
            } else {
                // Pure Island mode: 180pt (20+140+20)
                return 180
            }
        }
        
        // HIGH ALERT (CAFFEINE): Compact height for toggle + 2 rows of timer buttons
        // Timer buttons = 2 rows × 34pt + 8pt spacing = 76pt total content height
        if isCaffeineViewVisible {
            let isExternalNotchStyle = isExternalDisplay && !externalDisplayUseDynamicIsland
            if contentLayoutNotchHeight > 0 {
                // Built-in notch: notchHeight + 76 (content) + 20 (bottom) = notchHeight + 96
                return contentLayoutNotchHeight + 96
            } else if isExternalNotchStyle {
                // External notch style: 20 top + 76 content + 20 bottom = 116pt
                return 116
            } else {
                // Pure Island mode: 20 top + 76 content + 20 bottom = 116pt
                return 116
            }
        }

        if isCameraViewVisible {
            let isExternalNotchStyle = isExternalDisplay && !externalDisplayUseDynamicIsland
            if contentLayoutNotchHeight > 0 {
                return contentLayoutNotchHeight + 160
            } else if isExternalNotchStyle {
                return 180
            } else {
                return 180
            }
        }

        // MEDIA PLAYER: Content height based on layout
        if isMediaPlayerVisibleInShelf {
            // SSOT (v21.68): Different base heights for different modes:
            // - Pure Island mode: 30 (top) + 100 (album) + 30 (bottom) = 160pt
            // - External notch style: 20 (top) + 100 (album) + 20 (bottom) = 140pt
            // - Built-in notch mode: notchHeight (top) + 100 (album) + 20 (bottom)
            let isExternalNotchStyle = isExternalDisplay && !externalDisplayUseDynamicIsland
            if contentLayoutNotchHeight > 0 {
                // Built-in notch mode: use notchHeight + 120 formula
                return mediaPlayerContentHeight + (contentLayoutNotchHeight - 40)
            } else if isExternalNotchStyle {
                // External notch style: 140pt (20 top + 100 content + 20 bottom)
                // Symmetric vertical padding for visual balance
                return 140
            } else {
                // Pure Island mode: 140pt (20+100+20)
                return 140
            }
        }
        
        // SHELF: DYNAMIC height (grows with files up to max 3 rows)
        // Beyond 3 rows, ScrollView handles the overflow
        // Use shelfDisplaySlotCount for correct row count
        let rowCount = (Double(state.shelfDisplaySlotCount) / 5.0).rounded(.up)
        let cappedRowCount = min(rowCount, 3)  // Max 3 rows visible, scroll for rest
        
        // TODO BAR: Add height when Todo extension is active for this content state
        let todoBarHeight: CGFloat = shouldShowTodoShelfBar
            ? ToDoShelfBar.expandedHeight(
                isListExpanded: isTodoListExpanded,
                itemCount: todoManager.shelfTimelineItemCount,
                notchHeight: contentLayoutNotchHeight,
                showsUndoToast: todoManager.showUndoToast
            )
            : 0
        
        // FIX: When todo list is expanded and shelf is empty, don't add baseHeight
        // The todo bar provides its own height, no need for the 110px shelf base
        let shouldSkipBaseHeight = state.shelfDisplaySlotCount == 0 && isTodoListExpanded && todoBarHeight > 0
        let baseHeight = shouldSkipBaseHeight ? 0 : max(1, cappedRowCount) * 110

        // In built-in notch mode, add extra height to compensate for top padding that clears physical notch
        // Island mode and external displays don't need this as they use symmetrical layout
        // SSOT: Use contentLayoutNotchHeight for consistent sizing
        let notchCompensation: CGFloat = contentLayoutNotchHeight

        return baseHeight + notchCompensation + todoBarHeight
    }

    private var notificationHUDHeight: CGFloat {
        let isExternalNotchStyle = isExternalDisplay && !externalDisplayUseDynamicIsland
        let baseHeight: CGFloat
        if isDynamicIslandMode {
            baseHeight = 70
        } else if isExternalNotchStyle {
            let hasPreviewTextLine: Bool = {
                guard notificationHUDManager.showPreview,
                      let notification = notificationHUDManager.currentNotification else { return false }
                let previewText = [notification.displaySubtitle, notification.body]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return !previewText.isEmpty
            }()
            // External-notch style with SSOT 20/30/20/30 insets:
            // 38pt icon + 20 top + 20 bottom = 78 base, slightly taller with preview text.
            baseHeight = hasPreviewTextLine ? 84 : 78
        } else {
            baseHeight = 110
        }

        return baseHeight
    }
    /// Helper to check if current screen is built-in (MacBook display)
    private var isBuiltInDisplay: Bool {
        // Use target screen or fallback to built-in
        guard let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return true }
        return screen.isBuiltIn
    }
    
    private var shouldShowVisualNotch: Bool {
        // During lock/unlock, the dedicated SkyLight lock HUD should be the only visible
        // notch surface on built-in physical-notch displays. This prevents ghost/fade overlap.
        if lockScreenManager.isDedicatedHUDActive && hasPhysicalNotchOnDisplay && isBuiltInDisplay {
            return false
        }

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
            
            // Dynamic Island idle behavior: respect user setting for external/notchless displays
            // Fall through to shared idle logic below (don't return false here)
        }
        
        // NOTCH MODE: Legacy behavior - notch is always visible to cover camera
        // Always show while the media surface is active.
        if isMediaHUDSurfaceActive { return true }
        
        // Shelf-specific triggers only apply when shelf is enabled
        if enableNotchShelf {
            if isExpandedOnThisScreen { return true }
            if dragMonitor.isDragging || isHoveringOnThisScreen || state.isDropTargeted { return true }
        }
        
        // Show when any HUD is visible (using centralized HUDManager) - applies to notch mode too
        if HUDManager.shared.isVisible { return true }
        
        // Keep the collapsed shell visible briefly after close on external displays so
        // the user sees a smooth settle instead of an instant vanish.
        if externalCollapseVisibilityHold {
            return true
        }

        // External displays and notchless MacBooks: hide when idle (no physical camera to cover)
        // Only reaches here if there's nothing to show
        if !isBuiltInDisplay {
            // Allow user to keep notch/island visible when idle on external displays
            return showIdleNotchOnExternalDisplays
        }
        
        // Built-in display: check if it has a physical notch to cover
        if let screen = targetScreen ?? NSScreen.builtInWithNotch {
            // Built-in display WITH notch: show idle notch to cover camera
            if screen.safeAreaInsets.top > 0 {
                return enableNotchShelf || showIdleNotchOnExternalDisplays
            }
        }
        
        // Built-in display WITHOUT notch (old MacBook Air, etc.): same behavior as external
        // No physical camera to cover, so respect the idle visibility setting
        return showIdleNotchOnExternalDisplays
    }

    /// During lock-in we must hide the inline notch instantly (no opacity tween),
    /// otherwise it visibly ghosts underneath the dedicated lock HUD.
    private var shouldDisableInlineNotchVisibilityAnimation: Bool {
        lockScreenManager.isDedicatedHUDActive &&
        !lockScreenManager.isUnlocked &&
        hasPhysicalNotchOnDisplay &&
        isBuiltInDisplay
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
        let isShowingMediaPlayer = (musicManager.isMediaHUDForced || (autoOpenMediaHUDOnShelfExpand && !musicManager.isMediaHUDHidden)) && !musicManager.isPlayerIdle
        let shouldShow = enableIdleFace && isExpandedOnThisScreen && shelfIsEmpty && !isShowingMediaPlayer
        
        if shouldShow {
            NotchFace(size: 40)
                .transition(displayButtonTransition)
                .zIndex(1)
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            shelfContent
                .onChange(of: isExpandedOnThisScreen) { _, isExpanded in
                    // RESET RULE: When shelf collapses, reset extension views so next open shows default shelf
                    if !isExpanded {
                        showCaffeineView = false
                        showCameraView = false
                        resetTodoExpansionStateWithoutAnimation()
                    }
                }
                .onChange(of: shouldAttachTodoShelfBar) { _, shouldAttach in
                    // Prevent stale ToDo expanded state from leaking height/layout into
                    // Terminal/Camera/Caffeine/Media views on external displays.
                    if !shouldAttach {
                        resetTodoExpansionStateWithoutAnimation()
                    }
                }
                .onChange(of: enableQuickActions) { _, enabled in
                    if !enabled {
                        state.hoveredShelfQuickAction = nil
                        state.isShelfQuickActionsTargeted = false
                    }
                }
            
            // Floating buttons (Bottom Centered)
            // QUICK ACTIONS: Show when dragging files over expanded shelf (even if empty)
            // REGULAR BUTTONS: Show otherwise (terminal/caffeine/close buttons)
            // SMOOTH MORPH: Uses spring animation for seamless transition
            // Check both installed AND enabled for each extension
            let caffeineInstalled = UserDefaults.standard.preference(AppPreferenceKey.caffeineInstalled, default: PreferenceDefault.caffeineInstalled)
            let caffeineEnabled = UserDefaults.standard.preference(AppPreferenceKey.caffeineEnabled, default: PreferenceDefault.caffeineEnabled)
            let terminalEnabled = UserDefaults.standard.preference(AppPreferenceKey.terminalNotchEnabled, default: PreferenceDefault.terminalNotchEnabled)
            let caffeineShouldShow = caffeineInstalled && caffeineEnabled
            let terminalShouldShow = terminalManager.isInstalled && terminalEnabled
            let cameraShouldShow = canShowCameraFloatingButton
            if enableNotchShelf && isExpandedOnThisScreen {
                // FLOATING BUTTONS: ZStack enables smooth crossfade between button states
                // - Quick Actions: Shown when dragging files
                // - Regular Buttons: Terminal + Caffeine + Close when NOT dragging
                ZStack {
                    // Quick Actions Bar - appears when dragging files
                    if dragMonitor.isDragging && enableQuickActions {
                        ShelfQuickActionsBar(items: state.items, useTransparent: shouldUseFloatingButtonTransparent)
                            .onHover { isHovering in
                                isHoveringExpandedContent = isHovering
                                if isHovering {
                                    cancelAutoShrinkTimer()
                                } else {
                                    startAutoShrinkTimer()
                                }
                            }
                            .onDisappear {
                                state.hoveredShelfQuickAction = nil
                                state.isShelfQuickActionsTargeted = false
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.5).combined(with: .opacity).animation(DroppyAnimation.itemInsertion(for: targetScreen)),
                                removal: .scale(scale: 0.5).combined(with: .opacity).animation(displayNotchStateAnimation)
                            ))
                    }
                    
                    // Regular floating buttons (caffeine/terminal/close) - appear when NOT dragging
                    if !dragMonitor.isDragging && (shouldShowExternalMouseSwitchFloatingButton || caffeineShouldShow || terminalShouldShow || cameraShouldShow || !autoCollapseShelf) {
                        HStack(spacing: 12) {
                            if shouldShowExternalMouseSwitchFloatingButton {
                                Button(action: {
                                    toggleExpandedShelfMediaSurface()
                                }) {
                                    Image(systemName: isShowingExpandedMediaSurface ? "tray.fill" : "music.note")
                                }
                                .buttonStyle(DroppyCircleButtonStyle(
                                    size: 32,
                                    useTransparent: shouldUseFloatingButtonTransparent,
                                    solidFill: isDynamicIslandMode ? dynamicIslandGray : .black
                                ))
                                .help(isShowingExpandedMediaSurface ? "Show Shelf" : "Show Media")
                                .transition(displayElementTransition)
                            }

                            // Caffeine button (if extension installed AND enabled)
                            if caffeineShouldShow {
                                let isHighlight = showCaffeineView || CaffeineManager.shared.isActive
                                
                                Button(action: {
                                    HapticFeedback.tap()
                                    withAnimation(displayNotchStateAnimation) {
                                        showCaffeineView.toggle()
                                        // If activating caffeine view, close terminal if open
                                        if showCaffeineView {
                                            terminalManager.hide()
                                            showCameraView = false
                                            isTodoListExpanded = false
                                            todoManager.isShelfListExpanded = false
                                        }
                                    }
                                    notchController.forceRecalculateAllWindowSizes()
                                    DispatchQueue.main.async {
                                        notchController.forceRecalculateAllWindowSizes()
                                    }
                                }) {
                                    Image(systemName: "eyes")
                                }
                                .buttonStyle(DroppyCircleButtonStyle(
                                    size: 32,
                                    useTransparent: shouldUseFloatingButtonTransparent,
                                    solidFill: isHighlight ? .orange : (isDynamicIslandMode ? dynamicIslandGray : .black)
                                ))
                                .help(CaffeineManager.shared.isActive ? "High Alert: \(CaffeineManager.shared.formattedRemaining)" : "High Alert")
                                .transition(displayElementTransition)
                            }

                            if cameraShouldShow {
                                let isHighlight = isCameraViewVisible
                                Button(action: {
                                    HapticFeedback.tap()
                                    withAnimation(displayNotchStateAnimation) {
                                        showCameraView.toggle()
                                        if showCameraView {
                                            showCaffeineView = false
                                            terminalManager.hide()
                                            isTodoListExpanded = false
                                            todoManager.isShelfListExpanded = false
                                        }
                                    }
                                    notchController.forceRecalculateAllWindowSizes()
                                    DispatchQueue.main.async {
                                        notchController.forceRecalculateAllWindowSizes()
                                    }
                                }) {
                                    Image(systemName: "camera.fill")
                                }
                                .buttonStyle(DroppyCircleButtonStyle(
                                    size: 32,
                                    useTransparent: shouldUseFloatingButtonTransparent,
                                    solidFill: isHighlight ? .cyan : (isDynamicIslandMode ? dynamicIslandGray : .black)
                                ))
                                .help(showCameraView ? "Hide Notchface" : "Show Notchface")
                                .transition(displayElementTransition)
                            }

                            // Terminal button (if extension installed AND enabled)
                            if terminalShouldShow {
                                // Open in selected terminal app button (only when terminal is visible)
                                if terminalManager.isVisible {
                                    Button(action: {
                                        terminalManager.openInTerminalApp()
                                    }) {
                                        Image(systemName: "arrow.up.forward.app")
                                    }
                                    .buttonStyle(DroppyCircleButtonStyle(size: 32, useTransparent: shouldUseFloatingButtonTransparent, solidFill: isDynamicIslandMode ? dynamicIslandGray : .black))
                                    .help("Open in \(terminalManager.preferredExternalAppTitle)")
                                    .transition(displayElementTransition)
                                    
                                    if !terminalManager.lastOutput.isEmpty {
                                        Button(action: {
                                            terminalManager.clearOutput()
                                        }) {
                                            Image(systemName: "arrow.counterclockwise")
                                        }
                                        .buttonStyle(DroppyCircleButtonStyle(size: 32, useTransparent: shouldUseFloatingButtonTransparent, solidFill: isDynamicIslandMode ? dynamicIslandGray : .black))
                                        .help("Clear terminal output")
                                        .transition(displayElementTransition)
                                    }
                                }
                                // Toggle terminal button (shows terminal icon when hidden, X when visible)
                                Button(action: {
                                    withAnimation(displayUnifiedOpenCloseAnimation) {
                                        let openingTerminal = !terminalManager.isVisible
                                        terminalManager.toggle()
                                        if openingTerminal {
                                            showCaffeineView = false
                                            showCameraView = false
                                            isTodoListExpanded = false
                                            todoManager.isShelfListExpanded = false
                                        }
                                    }
                                    notchController.forceRecalculateAllWindowSizes()
                                    DispatchQueue.main.async {
                                        notchController.forceRecalculateAllWindowSizes()
                                    }
                                }) {
                                    Image(systemName: terminalManager.isVisible ? "xmark" : "terminal")
                                }
                                .buttonStyle(DroppyCircleButtonStyle(size: 32, useTransparent: shouldUseFloatingButtonTransparent, solidFill: isDynamicIslandMode ? dynamicIslandGray : .black))
                                .transition(displayElementTransition)
                            }
                            
                            // Close button (only in sticky mode AND when terminal is not visible)
                            if !autoCollapseShelf && !terminalManager.isVisible {
                                Button(action: {
                                    withAnimation(displayExpandCloseAnimation) {
                                        state.expandedDisplayID = nil
                                        state.hoveringDisplayID = nil
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                }
                                .buttonStyle(DroppyCircleButtonStyle(size: 32, useTransparent: shouldUseFloatingButtonTransparent, solidFill: isDynamicIslandMode ? dynamicIslandGray : .black))
                            }
                        }
                        .onHover { isHovering in
                            isHoveringExpandedContent = isHovering
                            if isHovering {
                                cancelAutoShrinkTimer()
                            } else {
                                startAutoShrinkTimer()
                            }
                        }
                        .transition(displayButtonTransition)
                    }
                }
                .offset(y: currentExpandedHeight + NotchLayoutConstants.floatingButtonGap + (isDynamicIslandMode ? NotchLayoutConstants.floatingButtonIslandCompensation : 0))
                .opacity(notchController.isTemporarilyHidden ? 0 : 1)
                .scaleEffect(notchController.isTemporarilyHidden ? 0.5 : 1)
                .animation(displayNotchStateAnimation, value: notchController.isTemporarilyHidden)
                .animation(displayHoverAnimation, value: dragMonitor.isDragging)
                .zIndex(100)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
    }
    
    private var shelfContentWithItemObservers: some View {
        shelfContentBase
            .onChange(of: state.shelfDisplaySlotCount) { oldCount, newCount in
                // NOTE: Auto-expand removed - drop handlers now explicitly expand the correct display
                // This prevents multiple screens from racing to expand when items are added
                
                // Auto-collapse when shelf becomes TRULY empty
                // Check both slot count AND actual array to avoid false positives during item moves
                let isTrulyEmpty = state.shelfItems.isEmpty && state.shelfPowerFolders.isEmpty
                if newCount == 0 && state.isExpanded && isTrulyEmpty {
                    withAnimation(displayExpandCloseAnimation) {
                        state.expandedDisplayID = nil
                    }
                }

                // Hide/collapse To-do shelf bar as soon as files/folders exist on shelf.
                if newCount > 0 {
                    if showCameraView {
                        showCameraView = false
                    }
                    if isTodoListExpanded {
                        isTodoListExpanded = false
                    }
                    if todoManager.isShelfListExpanded {
                        todoManager.isShelfListExpanded = false
                    }
                }

                // Keep the expanded shelf hard-pinned to the screen top while row count grows.
                // Defer to next runloop so SwiftUI settles its new height before frame sync.
                if oldCount != newCount {
                    DispatchQueue.main.async {
                        guard isExpandedOnThisScreen, !state.isDropTargeted, !dragMonitor.isDragging else { return }
                        notchController.forceRecalculateAllWindowSizes()
                        DispatchQueue.main.async {
                            guard isExpandedOnThisScreen, !state.isDropTargeted, !dragMonitor.isDragging else { return }
                            notchController.forceRecalculateAllWindowSizes()
                        }
                    }
                }
            }
            .onChange(of: dragMonitor.isDragging) { _, isDragging in
                if showMediaPlayer && musicManager.isPlaying && !isExpandedOnThisScreen {
                    withAnimation(displayNotchStateAnimation) {
                        mediaHUDIsHovered = isDragging
                    }
                }

                // Keep shelf auto-collapse deterministic when drag sessions reveal the basket.
                // Without this, the timer can fire during drag and never get re-armed.
                if isDragging {
                    cancelAutoShrinkTimer()
                } else if isExpandedOnThisScreen && !isHoveringExpandedContent {
                    startAutoShrinkTimer()
                    DispatchQueue.main.async {
                        guard isExpandedOnThisScreen, !state.isDropTargeted, !dragMonitor.isDragging else { return }
                        notchController.forceRecalculateAllWindowSizes()
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
            .onAppear {
                capsLockLayoutIsOn = capsLockManager.isCapsLockOn
            }
            .onChange(of: volumeManager.lastChangeAt) { _, _ in
                guard enableHUDReplacement, enableVolumeHUDReplacement, !isExpandedOnThisScreen else { return }
                guard shouldShowMediaKeyHUD(on: volumeManager.lastChangeDisplayID) else { return }
                triggerVolumeHUD()
            }
            .onChange(of: brightnessManager.lastChangeAt) { _, _ in
                guard enableHUDReplacement, enableBrightnessHUDReplacement, !isExpandedOnThisScreen else { return }
                guard shouldShowMediaKeyHUD(on: brightnessManager.lastChangeDisplayID) else { return }
                triggerBrightnessHUD()
            }
            .onChange(of: batteryManager.lastChangeAt) { _, _ in
                guard enableBatteryHUD, !isExpandedOnThisScreen else { return }
                triggerBatteryHUD()
            }
            .onChange(of: capsLockManager.lastChangeAt) { _, _ in
                guard enableCapsLockHUD, !isExpandedOnThisScreen else { return }
                withAnimation(displayContainerAnimation) {
                    capsLockLayoutIsOn = capsLockManager.isCapsLockOn
                }
                triggerCapsLockHUD()
            }
            .onChange(of: airPodsManager.lastConnectionAt) { _, _ in
                guard enableAirPodsHUD, !isExpandedOnThisScreen else { return }
                triggerAirPodsHUD()
            }
            .onChange(of: dndManager.lastChangeAt) { _, _ in
                guard enableDNDHUD, !isExpandedOnThisScreen else { return }
                triggerDNDHUD()
            }
    }
    
    private var shelfContentWithMediaObservers: some View {
        shelfContentWithHUDObservers
            .onChange(of: musicManager.songTitle) { oldTitle, newTitle in
                let trimmedOld = oldTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedNew = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let titleChanged = trimmedOld != trimmedNew

                if titleChanged {
                    if musicManager.isBrowserSource {
                        // Browser players can briefly drop metadata between tracks.
                        // Keep HUD pinned with loading placeholder during this handoff.
                        beginBrowserTrackLoadingHold()
                    }
                    // Reset marquee scroll for new song
                    sharedMarqueeStartTime = Date()
                }
                if !newTitle.isEmpty {
                    mediaHUDFadedOut = false
                    startMediaFadeTimer()
                    if musicManager.isBrowserSource && musicManager.isPlaying {
                        endBrowserTrackLoadingHold()
                    }
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
                        withAnimation(displayUnifiedOpenCloseAnimation) {
                            isMediaStable = true
                        }
                    }
                    mediaDebounceWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
                    startMediaFadeTimer()
                    if musicManager.isBrowserSource {
                        endBrowserTrackLoadingHold()
                    }
                }
                if !isPlaying && wasPlaying {
                    mediaDebounceWorkItem?.cancel()
                    isMediaStable = false
                    if musicManager.isBrowserSource {
                        beginBrowserTrackLoadingHold(duration: 2.6)
                    }
                }
            }
            .onChange(of: autoFadeMediaHUD) { wasEnabled, isEnabled in
                if isEnabled && !wasEnabled {
                    if musicManager.isPlaying && showMediaPlayer {
                        startMediaFadeTimer()
                    }
                } else if !isEnabled && wasEnabled {
                    mediaFadeWorkItem?.cancel()
                    withAnimation(displayUnifiedOpenCloseAnimation) {
                        mediaHUDFadedOut = false
                    }
                }
            }
            .onChange(of: musicManager.bundleIdentifier) { _, _ in
                if !musicManager.isBrowserSource {
                    endBrowserTrackLoadingHold()
                }
            }
    }
    
    private var shelfContentWithStateObservers: some View {
        shelfContentWithMediaObservers
            .onChange(of: state.expandedDisplayID) { oldDisplayID, newDisplayID in
                let thisDisplayID = targetScreen?.displayID
                let wasExpandedOnThis = oldDisplayID == thisDisplayID
                let isExpandedOnThis = newDisplayID == thisDisplayID
                
                if isExpandedOnThis && !wasExpandedOnThis {
                    startAutoShrinkTimer()
                    externalCollapseVisibilityWorkItem?.cancel()
                    externalCollapseVisibilityHold = false
                    // NOTE: Auto-open media HUD setting is handled directly in expandedContent conditions
                    // Do NOT set isMediaHUDForced here - that's global and affects all displays!
                } else if wasExpandedOnThis && !isExpandedOnThis {
                    cancelAutoShrinkTimer()
                    isHoveringExpandedContent = false
                    mediaHUDIsHovered = false
                    musicManager.isMediaHUDForced = false
                    musicManager.isMediaHUDHidden = false

                    if isExternalDisplay && !showIdleNotchOnExternalDisplays {
                        externalCollapseVisibilityWorkItem?.cancel()
                        externalCollapseVisibilityHold = true
                        let workItem = DispatchWorkItem { [self] in
                            withAnimation(displayExpandCloseAnimation) {
                                externalCollapseVisibilityHold = false
                            }
                        }
                        externalCollapseVisibilityWorkItem = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: workItem)
                    } else {
                        externalCollapseVisibilityWorkItem?.cancel()
                        externalCollapseVisibilityHold = false
                    }
                }
            }
            .onChange(of: isHoveringOnThisScreen) { wasHovering, isHovering in
                if wasHovering && !isHovering && isExpandedOnThisScreen {
                    startAutoShrinkTimer()
                }
            }
            .onChange(of: todoManager.isInteractingWithPopover) { wasInteracting, isInteracting in
                if isInteracting {
                    cancelAutoShrinkTimer()
                    return
                }
                if wasInteracting && !isInteracting {
                    // Popover teardown can briefly lag one frame behind interaction state.
                    // Record dismissal to defer collapse until geometry is stable.
                    lastPopoverDismissedAt = Date()
                    if !state.isDropTargeted && !dragMonitor.isDragging {
                        notchController.forceRecalculateAllWindowSizes()
                        DispatchQueue.main.async {
                            guard !state.isDropTargeted && !dragMonitor.isDragging else { return }
                            notchController.forceRecalculateAllWindowSizes()
                        }
                    }
                }
            }
            .onChange(of: isTodoListExpanded) { _, expanded in
                todoManager.isShelfListExpanded = expanded
                if expanded {
                    cancelAutoShrinkTimer()
                } else if isExpandedOnThisScreen && !state.isDropTargeted && !dragMonitor.isDragging {
                    startAutoShrinkTimer()
                }
                guard isExpandedOnThisScreen, !state.isDropTargeted, !dragMonitor.isDragging else { return }
                // Defer to next runloop so SwiftUI width/height settles before frame sync.
                // This avoids the brief off-position jump on close/open transitions.
                DispatchQueue.main.async {
                    guard isExpandedOnThisScreen, !state.isDropTargeted, !dragMonitor.isDragging else { return }
                    notchController.forceRecalculateAllWindowSizes()
                }
            }
            .onChange(of: shouldShowTodoShelfBar) { _, shouldShow in
                guard !shouldShow && isTodoListExpanded else { return }
                isTodoListExpanded = false
                todoManager.isShelfListExpanded = false
            }
    }

    private var shelfContentWithObservers: some View {
        shelfContentWithStateObservers
            .onReceive(NotificationCenter.default.publisher(for: .todoQuickOpenRequested)) { notification in
                guard let requestedIDValue = notification.userInfo?["displayID"] as? NSNumber else { return }
                let requestedDisplayID = CGDirectDisplayID(requestedIDValue.uint32Value)
                guard requestedDisplayID == thisDisplayID else { return }
                guard isTodoExtensionActive else { return }
                guard !isTerminalViewVisible && !isCaffeineViewVisible && !isCameraViewVisible else {
                    SettingsWindowController.shared.showSettings(openingExtension: .todo)
                    return
                }

                if isTodoListExpanded {
                    withAnimation(DroppyAnimation.smoothContent) {
                        isTodoListExpanded = false
                    }
                    todoManager.isShelfListExpanded = false
                    if state.shelfDisplaySlotCount == 0 {
                        withAnimation(displayExpandCloseAnimation) {
                            state.expandedDisplayID = nil
                        }
                    }
                    NotchWindowController.shared.forceRecalculateAllWindowSizes()
                    return
                }

                cancelAutoShrinkTimer()
                withAnimation(DroppyAnimation.smoothContent) {
                    isTodoListExpanded = true
                }
                todoManager.isShelfListExpanded = true
                NotchWindowController.shared.forceRecalculateAllWindowSizes()
            }
            .onChange(of: isTerminalViewVisible) { _, _ in
                notchController.forceRecalculateAllWindowSizes()
            }
            .onChange(of: isCameraViewVisible) { _, _ in
                notchController.forceRecalculateAllWindowSizes()
            }
            .onChange(of: isCaffeineViewVisible) { _, _ in
                notchController.forceRecalculateAllWindowSizes()
            }
            .onChange(of: canShowCameraFloatingButton) { _, canShow in
                guard !canShow && showCameraView else { return }
                showCameraView = false
            }
            .onAppear {
                todoManager.isShelfListExpanded = isTodoListExpanded
            }
            .onDisappear {
                externalCollapseVisibilityWorkItem?.cancel()
                browserTrackLoadingWorkItem?.cancel()
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
        withAnimation(displayNotchStateAnimation) {
            hudIsVisible = true
            // Reset hover states to prevent layout shift when HUD appears
            state.hoveringDisplayID = nil  // Clear hover on all screens
            mediaHUDIsHovered = false
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(displayUnifiedOpenCloseAnimation) {
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
        withAnimation(displayNotchStateAnimation) {
            hudIsVisible = true
            // Reset hover states to prevent layout shift when HUD appears
            state.hoveringDisplayID = nil  // Clear hover on all screens
            mediaHUDIsHovered = false
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(displayUnifiedOpenCloseAnimation) {
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

    private func triggerDNDHUD() {
        // Use centralized HUDManager for queue-based display
        HUDManager.shared.show(.dnd, duration: dndManager.visibleDuration)
    }
    
    private func startMediaFadeTimer() {
        // Only start timer if auto-fade is enabled globally
        guard autoFadeMediaHUD else { return }
        
        // Get display ID for this screen
        let displayID = targetScreen?.displayID ?? 0
        
        // Check display-specific rule
        guard AutofadeManager.shared.isDisplayEnabled(displayID) else { return }
        
        // Get effective delay (considers app rules + default)
        // Returns nil if autofade should be disabled (e.g., "never" rule)
        guard let delay = AutofadeManager.shared.effectiveDelay(for: displayID) else {
            return  // Autofade disabled for this context
        }
        
        // Cancel any existing timer
        mediaFadeWorkItem?.cancel()
        
        // Start timer with calculated delay
        let workItem = DispatchWorkItem { [self] in
            withAnimation(displayUnifiedOpenCloseAnimation) {
                mediaHUDFadedOut = true
            }
        }
        mediaFadeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func beginBrowserTrackLoadingHold(duration: TimeInterval = 2.2) {
        guard musicManager.isBrowserSource else { return }
        let holdUntil = Date().addingTimeInterval(duration)
        if holdUntil > browserTrackLoadingUntil {
            browserTrackLoadingUntil = holdUntil
        }

        browserTrackLoadingWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            browserTrackLoadingUntil = .distantPast
        }
        browserTrackLoadingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private func endBrowserTrackLoadingHold() {
        browserTrackLoadingWorkItem?.cancel()
        browserTrackLoadingUntil = .distantPast
    }

    private func toggleExpandedShelfMediaSurface() {
        guard showMediaPlayer else { return }
        let showMedia = !isMediaPlayerVisibleInShelf

        HapticFeedback.tap()
        withAnimation(displayUnifiedOpenCloseAnimation) {
            musicManager.isMediaHUDForced = showMedia
            musicManager.isMediaHUDHidden = !showMedia
        }

        notchController.forceRecalculateAllWindowSizes()
        DispatchQueue.main.async {
            notchController.forceRecalculateAllWindowSizes()
        }
    }
    
    // MARK: - Auto-Shrink Timer
    
    /// Starts the auto-shrink timer when the shelf is expanded
    private func startAutoShrinkTimer() {
        // Check if auto-collapse is enabled (new toggle)
        guard autoCollapseShelf else { return }
        guard isExpandedOnThisScreen else { return }
        // Keep the shelf open while Reminders panel is expanded (including quick-open).
        guard !isTodoListExpanded else { return }
        // Keep the shelf stable during active To-do interactions (popover/edit/split-toggle hold).
        guard !ToDoManager.shared.isInteractingWithPopover else { return }
        
        // Cancel any existing timer
        autoShrinkWorkItem?.cancel()
        
        // Start timer to auto-shrink shelf
        let workItem = DispatchWorkItem { [self] in
            // DEBUG: Log auto-shrink timer firing
            notchShelfDebugLog("⏳ AUTO-SHRINK TIMER FIRED: isExpandedOnThisScreen=\(isExpandedOnThisScreen), isHoveringExpandedContent=\(isHoveringExpandedContent), isHoveringOnThisScreen=\(isHoveringOnThisScreen), isDropTargeted=\(state.isDropTargeted)")
            
            // SKYLIGHT FIX: After lock/unlock with SkyLight-delegated windows, SwiftUI's .onHover
            // handlers stop working correctly. Use GEOMETRIC mouse position check as fallback.
            // Check if mouse is actually in the expanded shelf zone using NSEvent.mouseLocation
            var isMouseInExpandedZone = false
            if let screen = targetScreen {
                let mouseLocation = NSEvent.mouseLocation
                isMouseInExpandedZone = notchController.isMouseInsideExpandedShelfInteractionZone(on: screen, at: mouseLocation)
                notchShelfDebugLog("⏳ GEOMETRIC CHECK: mouse=\(mouseLocation), isInZone=\(isMouseInExpandedZone)")
            }
            
            // Only shrink if still expanded and not hovering over the content
            // Check BOTH SwiftUI hover state AND geometric fallback
            let isHoveringAnyMethod = isHoveringOnThisScreen || isMouseInExpandedZone
            let isTodoPopoverInteractionActive = ToDoManager.shared.isInteractingWithPopover
            guard isExpandedOnThisScreen && !isTodoListExpanded && !isHoveringAnyMethod && !state.isDropTargeted && !isTodoPopoverInteractionActive else {
                notchShelfDebugLog("⏳ AUTO-SHRINK SKIPPED: conditions not met (isHoveringAnyMethod=\(isHoveringAnyMethod))")
                return
            }
            
            // Don't auto-shrink while a real context menu is open.
            guard !notchController.hasActiveContextMenu() else { return }
            
            notchShelfDebugLog("⏳ AUTO-SHRINK COLLAPSING SHELF!")
            withAnimation(displayExpandCloseAnimation) {
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

            if shouldShowCollapsedShelfPeek {
                collapsedShelfPeekContent
                    .zIndex(2)
                    .transition(displayUnifiedSurfaceTransition)
            }
            
            // MARK: - HUD Views
            hudContent
            
            // MARK: - Media Player HUD
            mediaPlayerHUD
            
            // MARK: - Expanded Shelf Content
            if isExpandedOnThisScreen && enableNotchShelf {
                expandedShelfContent
                    .transition(expandedSurfaceTransition)
                    .frame(width: expandedWidth, height: currentExpandedHeight)
                    .clipShape(isDynamicIslandMode ? AnyShape(DynamicIslandShape(cornerRadius: 50)) : AnyShape(NotchShape(bottomRadius: 40)))
                    .geometryGroup()
                    .zIndex(2)
            }
            
            // MARK: - Morphing Album Art Overlay (Droppy Proxy Pattern)
            // CRITICAL: This is the SINGLE album art that morphs between HUD and expanded states.
            // Both MediaHUDView and MediaPlayerView hide their internal album art (showAlbumArt: false)
            // and this overlay provides the smooth morphing animation.
            morphingAlbumArtOverlay
                .zIndex(10)  // Above all content for smooth morphing visibility
                .allowsHitTesting(isExpandedOnThisScreen)  // FIX #126: Pass through hover when collapsed
            
            // MARK: - Morphing Visualizer Overlay (Droppy Proxy Pattern)
            // Same approach as album art - single visualizer that morphs position
            morphingVisualizerOverlay
                .zIndex(11)  // Above album art for visibility
                .allowsHitTesting(isExpandedOnThisScreen)  // FIX #126: Pass through hover when collapsed
            
            // MARK: - Morphing Title Overlay (Droppy Proxy Pattern)
            // Same approach - single title that morphs from HUD to expanded position
            morphingTitleOverlay
                .zIndex(12)  // Above visualizer for visibility
                .allowsHitTesting(isExpandedOnThisScreen)  // FIX #126: Pass through hover when collapsed

            // Toggle buttons removed per UX request.
        }
        .opacity(notchController.isTemporarilyHidden ? 0 : 1)
        .frame(width: currentNotchWidth, height: currentNotchHeight, alignment: .top)
        .mask {
            Group {
                if isDynamicIslandMode {
                    DynamicIslandShape(cornerRadius: 50)
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
                        volumeManager.setAbsolute(Float32(newValue), screenHint: targetScreen)
                    } else {
                        brightnessManager.setAbsolute(value: Float(newValue), screenHint: targetScreen)
                    }
                }
            )
            .frame(width: currentHudTypeWidth, height: notchHeight)
            .transition(displayHUDTransition)
            .zIndex(3)
        }
        
        // Battery HUD - uses centralized HUDManager
        if HUDManager.shared.isBatteryHUDVisible && enableBatteryHUD && !hudIsVisible && !isExpandedOnThisScreen && !isCaffeineHoverActive {
            BatteryHUDView(
                batteryManager: batteryManager,
                hudWidth: batteryHudWidth,
                targetScreen: targetScreen
            )
            .frame(width: batteryHudWidth, height: notchHeight)
            .transition(displayHUDTransition)
            .zIndex(4)
        }
        
        // Caps Lock HUD - uses centralized HUDManager
        if HUDManager.shared.isCapsLockHUDVisible && enableCapsLockHUD && !hudIsVisible && !isExpandedOnThisScreen && !isCaffeineHoverActive {
            CapsLockHUDView(
                capsLockManager: capsLockManager,
                hudWidth: capsLockHudWidth,
                targetScreen: targetScreen
            )
            .frame(width: capsLockHudWidth, height: notchHeight)
            .transition(displayHUDTransition)
            .zIndex(5)
        }
        
        // High Alert HUD - uses centralized HUDManager
        if HUDManager.shared.isHighAlertHUDVisible && caffeineExtensionEnabled && !hudIsVisible && !isExpandedOnThisScreen && !isCaffeineHoverActive {
            HighAlertHUDView(
                isActive: caffeineManager.isActive,
                hudWidth: highAlertHudWidth,
                targetScreen: targetScreen,
                notchWidth: notchWidth
            )
            .frame(width: highAlertHudWidth, height: notchHeight)
            .transition(displayHUDTransition)
            .zIndex(5.2)
        }
        
        // Focus/DND HUD - uses centralized HUDManager
        if HUDManager.shared.isDNDHUDVisible && enableDNDHUD && !hudIsVisible && !isExpandedOnThisScreen && !isCaffeineHoverActive {
            DNDHUDView(
                dndManager: dndManager,
                hudWidth: batteryHudWidth,
                targetScreen: targetScreen
            )
            .frame(width: batteryHudWidth, height: notchHeight)
            .transition(displayHUDTransition)
            .zIndex(5.5)
        }
        
        // Update HUD - uses centralized HUDManager
        if HUDManager.shared.isUpdateHUDVisible && enableUpdateHUD && !hudIsVisible && !isExpandedOnThisScreen && !isCaffeineHoverActive {
            UpdateHUDView(
                hudWidth: updateHudWidth,
                targetScreen: targetScreen
            )
            .frame(width: updateHudWidth, height: notchHeight)
            .transition(displayHUDTransition)
            .zIndex(5.6)
        }
        
        // AirPods HUD - uses centralized HUDManager
        if HUDManager.shared.isAirPodsHUDVisible && enableAirPodsHUD && !hudIsVisible && !isExpandedOnThisScreen && !isCaffeineHoverActive, let airPods = airPodsManager.connectedAirPods {
            AirPodsHUDView(
                airPods: airPods,
                hudWidth: hudWidth,
                targetScreen: targetScreen
            )
            .frame(width: hudWidth, height: notchHeight)
            .transition(displayHUDTransition)
            .zIndex(6)
        }

        // Lock Screen HUD - uses centralized HUDManager
        if shouldRenderInlineLockScreenHUD && !hudIsVisible && !isExpandedOnThisScreen && !isCaffeineHoverActive {
            LockScreenHUDView(
                hudWidth: batteryHudWidth,
                targetScreen: targetScreen
            )
            .frame(width: batteryHudWidth, height: notchHeight)
            .transition(displayHUDTransition)
            .zIndex(7)
        }

        // Notification HUD - uses centralized HUDManager
        // CRITICAL: Must never render while shelf is expanded on this display.
        // Keep observation explicit so SwiftUI updates when either state changes.
        let hasNotification = notificationHUDManager.currentNotification != nil
        let isNotificationHUDActive = hudManager.isNotificationHUDVisible
        let shouldRenderNotificationHUD = isNotificationHUDActive &&
            hasNotification &&
            !hudIsVisible &&
            !isCaffeineHoverActive &&
            !isExpandedOnThisScreen

        // DEBUG: Log render condition values (use let _ = for side effects in @ViewBuilder)
        let _ = {
            if hasNotification || isNotificationHUDActive {
                let screenName = targetScreen?.localizedName ?? "main"
                notchShelfDebugLog("🔔 NotchShelfView[\(screenName)]: Render check - isNotificationHUDActive=\(isNotificationHUDActive), hasNotification=\(hasNotification), isExpanded=\(isExpandedOnThisScreen), hudIsVisible=\(hudIsVisible), willRender=\(shouldRenderNotificationHUD)")
            }
        }()

        if shouldRenderNotificationHUD {
            let notifWidth = isDynamicIslandMode ? hudWidth : expandedWidth
            let notifHeight = notificationHUDHeight

            NotificationHUDView(
                manager: notificationHUDManager,
                hudWidth: notifWidth,
                targetScreen: targetScreen
            )
            .frame(width: notifWidth, height: notifHeight)
            .transition(displayHUDTransition)
            .zIndex(100) // High z-index to stay on top of shelf content
        }
        
        // Caffeine Hover Indicators (HIGHEST PRIORITY when hovering + caffeine active)
        // Shows only when:
        // 1. Hovering (state.isMouseHovering)
        // 2. Caffeine is ACTIVE
        // 3. Shelf is NOT expanded
        // 4. No centralized HUD visible (volume/brightness)
        // NOTE: This REPLACES ALL other HUDs when hovering - morphs into timer display
        // CRITICAL: Uses isCaffeineHoverActive computed property for consistent suppression
        if isCaffeineHoverActive {
            HighAlertHUDView(
                isActive: true,
                hudWidth: highAlertHudWidth,
                targetScreen: targetScreen,
                notchWidth: notchWidth
            )
            .frame(width: highAlertHudWidth, height: notchHeight)
            .transition(displayHUDTransition)
            .zIndex(200)  // Highest priority - always on top of other HUDs
        }
    }
    
    // MARK: - Media Player HUD
    
    /// Media player mini HUD
    @ViewBuilder
    private var mediaPlayerHUD: some View {
        // Break up complex expressions for type checker
        let noHUDsVisible = !hudIsVisible && !HUDManager.shared.isVisible
        let notExpanded = !isExpandedOnThisScreen
        let browserTrackLoading = isBrowserTrackLoading
        
        // CRITICAL (Issue #101): Hide media HUD when fullscreen app is active ON THIS DISPLAY
        // Multi-monitor support: Each screen independently tracks its fullscreen state
        let targetDisplayID = targetScreen?.displayID ?? 0
        let notInFullscreen = !notchController.fullscreenDisplayIDs.contains(targetDisplayID)
        
        let shouldShowForced = musicManager.isMediaHUDForced &&
            (musicManager.isPlaying || browserTrackLoading) &&
            (!musicManager.isPlayerIdle || browserTrackLoading) &&
            showMediaPlayer &&
            noHUDsVisible &&
            notExpanded &&
            notInFullscreen &&
            !shouldLockMediaForTodo
        
        let mediaIsPlaying = (musicManager.isPlaying && !musicManager.songTitle.isEmpty) || browserTrackLoading
        let notFadedOrTransitioning = !(autoFadeMediaHUD && mediaHUDFadedOut)
        let debounceOk = !debounceMediaChanges || isMediaStable || browserTrackLoading
        
        // FIX #95: Bypass ALL safeguards when forcing source switch (Spotify fallback)
        // When isMediaSourceForced is true, we know the source is playing (verified via AppleScript)
        let bypassSafeguards = musicManager.isMediaSourceForced
        let hasContent = !musicManager.songTitle.isEmpty || browserTrackLoading
        let shouldBlockAutoSwitch = shouldLockMediaForTodo
        let shouldShowNormal = showMediaPlayer && noHUDsVisible && notExpanded && notInFullscreen && !shouldBlockAutoSwitch &&
                              (bypassSafeguards ? hasContent : (mediaIsPlaying && notFadedOrTransitioning && debounceOk))
        let shouldShowHovered = mediaHUDIsHovered && isMediaHUDHoverEligible
        
        // MORPH BEHAVIOR: Hide media HUD when Caffeine Hover Indicators are showing
        // This allows the caffeine timer to temporarily replace the media HUD on hover
        let caffeineHoverIsActive = isCaffeineHoverActive
        
        if (shouldShowForced || shouldShowNormal || shouldShowHovered) && !caffeineHoverIsActive {
            // Title morphing is handled by overlay for both DI and notch modes
            MediaHUDView(musicManager: musicManager, isHovered: $mediaHUDIsHovered, notchWidth: notchWidth, notchHeight: notchHeight, hudWidth: hudWidth, targetScreen: targetScreen, albumArtNamespace: albumArtNamespace, showAlbumArt: false, showVisualizer: false, showTitle: false)
                .frame(width: hudWidth, alignment: .top)
                .clipShape(isDynamicIslandMode ? AnyShape(DynamicIslandShape(cornerRadius: 50)) : AnyShape(NotchShape(bottomRadius: 18)))
                .transition(displayMediaHUDTransition)
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
            let hudLayout = HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
            // Calculate sizes
            let hudSize: CGFloat = hudLayout.iconSize
            let expandedSize: CGFloat = 100
            let currentSize = isExpandedOnThisScreen ? expandedSize : hudSize
            
            // Calculate corner radii
            let hudCornerRadius: CGFloat = isDynamicIslandMode ? hudSize / 2 : 5
            let expandedCornerRadius: CGFloat = 24  // Complement outer edge curvature
            let currentCornerRadius = isExpandedOnThisScreen ? expandedCornerRadius : hudCornerRadius
            
            // Calculate position offsets based on contentOverlay frame
            // contentOverlay is framed at currentNotchWidth x currentNotchHeight
            // For HUD mode we use FIXED dimensions to prevent jumping on hover
            
            // HUD X position: Album art at left edge with symmetricPadding inset
            // Use FIXED HUD container width to prevent jumping during transitions
            // +wingCornerCompensation for curved wing corners (topCornerRadius)
            let hudSymmetricPadding: CGFloat = hudLayout.symmetricPadding(for: hudSize)
            let fixedHUDHeight: CGFloat = notchHeight
            let fixedHUDContainerWidth: CGFloat = hudWidth
            let hudXOffset = -(fixedHUDContainerWidth / 2) + hudSymmetricPadding + (hudSize / 2)
            
            // Expanded X position: Album art at left side with appropriate padding
            // - DI mode: 20pt (contentPadding)
            // - Notch modes: 30pt (contentPadding + wingCornerCompensation)
            let horizontalPadding: CGFloat = isDynamicIslandMode 
                ? NotchLayoutConstants.contentPadding 
                : NotchLayoutConstants.contentPadding + NotchLayoutConstants.wingCornerCompensation
            let expandedXOffset = -(expandedWidth / 2) + horizontalPadding + (expandedSize / 2)
            
            let currentXOffset = isExpandedOnThisScreen ? expandedXOffset : hudXOffset
            
            // Y position: ZStack is .top aligned, so offset moves the view's TOP edge down
            // HUD: Center icon vertically = offset by (containerHeight - iconHeight) / 2
            let hudYOffset = (fixedHUDHeight - hudSize) / 2
            // SSOT: Must match NotchLayoutConstants.contentEdgeInsets exactly
            // - DI mode: 20pt (contentPadding)
            // - External notch style: 20pt (contentPadding)  
            // - Built-in notch mode: notchHeight
            let expandedTopPadding: CGFloat = contentLayoutNotchHeight > 0 
                ? contentLayoutNotchHeight 
                : NotchLayoutConstants.contentPadding
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
                        .fill(notchOverlayTone(isExpandedOnThisScreen ? 0.08 : 0.2))
                        .overlay(
                            Group {
                                if isBrowserTrackLoading {
                                    LoadingSpinner(
                                        color: notchPrimaryText(isExpandedOnThisScreen ? 0.8 : 0.7),
                                        size: isExpandedOnThisScreen ? 34 : 12
                                    )
                                } else {
                                    Image(systemName: "music.note")
                                        .font(.system(size: isExpandedOnThisScreen ? 36 : 10))
                                        .foregroundStyle(notchPrimaryText(isExpandedOnThisScreen ? 0.3 : 0.5))
                                }
                            }
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
            // Source badge (bottom-right corner, expanded only) - fades in without sliding
            .overlay {
                ZStack(alignment: .bottomTrailing) {
                    Color.clear
                    SpotifyBadge(size: 24)
                        .offset(x: 5, y: 5)
                        .opacity(isExpandedOnThisScreen && musicManager.isSpotifySource ? 1 : 0)
                        .animation(displayNotchStateAnimation, value: isExpandedOnThisScreen)
                        .animation(displayNotchStateAnimation, value: musicManager.isSpotifySource)
                    TidalBadge(size: 24)
                        .offset(x: 5, y: 5)
                        .opacity(isExpandedOnThisScreen && musicManager.isTidalSource ? 1 : 0)
                        .animation(displayNotchStateAnimation, value: isExpandedOnThisScreen)
                        .animation(displayNotchStateAnimation, value: musicManager.isTidalSource)
                }
            }
            .shadow(
                color: (isExpandedOnThisScreen && enableMediaAlbumArtGlow) ? .black.opacity(0.3) : .clear,
                radius: 8,
                y: 4
            )
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
            .animation(displayUnifiedOpenCloseAnimation, value: isExpandedOnThisScreen)
            .animation(displayUnifiedOpenCloseAnimation, value: musicManager.isPlaying)  // pause shrink matches expand timing
            // INTERACTIVE: User-triggered animations kept separate
            .animation(DroppyAnimation.interactiveSpring(response: 0.3, dampingFraction: 0.6, for: targetScreen), value: albumArtNudgeOffset)
            .animation(DroppyAnimation.interactiveSpring(response: 0.25, dampingFraction: 0.7, for: targetScreen), value: albumArtParallaxOffset.width)
            .animation(DroppyAnimation.interactiveSpring(response: 0.25, dampingFraction: 0.7, for: targetScreen), value: albumArtParallaxOffset.height)
            .animation(DroppyAnimation.interactiveSpring(response: 0.2, dampingFraction: 0.5, for: targetScreen), value: albumArtTapScale)
            // PREMIUM: Scale+blur+opacity appear animation (matches notchTransition pattern)
            .scaleEffect(mediaOverlayAppeared ? 1.0 : 0.8, anchor: .top)
            .opacity(mediaOverlayAppeared ? 1.0 : 0)
            .animation(displayUnifiedOpenCloseAnimation, value: mediaOverlayAppeared)
            .onAppear {
                // UNIFIED: Immediate animation start - syncs with container notchTransition
                mediaOverlayAppeared = true
            }
            .onDisappear {
                mediaOverlayAppeared = false
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
            let collapsedBarCount = isDynamicIslandMode ? 3 : 5
            let collapsedBarWidth: CGFloat = isDynamicIslandMode ? 2.0 : 2.3
            let collapsedBarSpacing: CGFloat = 1.5
            let hudCollapsedWidth = CGFloat(collapsedBarCount) * collapsedBarWidth + CGFloat(collapsedBarCount - 1) * collapsedBarSpacing
            let hudCollapsedHeight: CGFloat = 16

            let expandedBarCount = 5
            let expandedBarWidth: CGFloat = 2.1
            let expandedBarSpacing: CGFloat = 1.7
            // MUST MATCH AudioVisualizerBars in MediaPlayerComponents
            let expandedWidth = CGFloat(expandedBarCount) * expandedBarWidth + CGFloat(expandedBarCount - 1) * expandedBarSpacing
            let expandedHeight: CGFloat = 18
            let currentWidth = isExpandedOnThisScreen ? expandedWidth : hudCollapsedWidth
            let currentHeight = isExpandedOnThisScreen ? expandedHeight : hudCollapsedHeight
            
            // Calculate position offsets
            // Use fixed dimensions for HUD to prevent jumping on hover
            let fixedHUDHeight: CGFloat = notchHeight
            let hudLayout = HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
            let hudAlbumSize: CGFloat = hudLayout.iconSize
            let hudSymmetricPadding: CGFloat = hudLayout.symmetricPadding(for: hudAlbumSize)
            
            // HUD X: Right side of HUD (mirror of album art position)
            // Use FIXED HUD container width to prevent jumping during transitions
            let fixedHUDContainerWidth: CGFloat = self.hudWidth
            let visualizerHudXOffset = (fixedHUDContainerWidth / 2) - hudSymmetricPadding - (hudCollapsedWidth / 2)
            
            // Expanded X: Align visualizer RIGHT edge with timestamp RIGHT edge
            // - DI mode: 20pt padding
            // - Notch modes: 30pt padding
            let horizontalPadding: CGFloat = isDynamicIslandMode 
                ? NotchLayoutConstants.contentPadding 
                : NotchLayoutConstants.contentPadding + NotchLayoutConstants.wingCornerCompensation
            // Timestamp right edge is at container edge - padding
            // The actual MediaPlayerView frames the visualizer at 24pt while content is centered inside it.
            // To align content precisely, we need to match where the ACTUAL bars end
            let expandedVisualizerFrameWidth: CGFloat = 24
            let frameToContentOffset: CGFloat = (expandedVisualizerFrameWidth - expandedWidth) / 2
            let expandedXOffset = (self.expandedWidth / 2) - horizontalPadding - (expandedWidth / 2) - frameToContentOffset
            
            let currentXOffset = isExpandedOnThisScreen ? expandedXOffset : visualizerHudXOffset
            
            // Y position: centered in HUD, at top of expanded content (in title row)
            let hudYOffset = (fixedHUDHeight - hudCollapsedHeight) / 2
            // SSOT: Must match NotchLayoutConstants.contentEdgeInsets exactly
            // - DI mode: 20pt (contentPadding)
            // - External notch style: 20pt (contentPadding)
            // - Built-in notch mode: notchHeight
            let expandedTopPadding: CGFloat = contentLayoutNotchHeight > 0 
                ? contentLayoutNotchHeight 
                : NotchLayoutConstants.contentPadding
            let expandedYOffset = expandedTopPadding + 1  // +1 to vertically center visualizer with title row
            let currentYOffset = isExpandedOnThisScreen ? expandedYOffset : hudYOffset
            
            // PERFORMANCE: Use cached visualizer color (computed once per track change)
            
            MiniAudioVisualizerBars(
                isPlaying: musicManager.isPlaying,
                color: musicManager.visualizerColor,  // PERFORMANCE: Cached, not recomputed
                secondaryColor: enableGradientVisualizer ? musicManager.visualizerSecondaryColor : nil,
                gradientMode: enableGradientVisualizer,
                barCount: isExpandedOnThisScreen ? expandedBarCount : collapsedBarCount,
                barWidth: isExpandedOnThisScreen ? expandedBarWidth : collapsedBarWidth,
                spacing: isExpandedOnThisScreen ? expandedBarSpacing : collapsedBarSpacing,
                height: currentHeight
            )
            .frame(width: currentWidth, height: currentHeight)
            .offset(x: currentXOffset, y: currentYOffset)
            .animation(displayUnifiedOpenCloseAnimation, value: isExpandedOnThisScreen)
            // PREMIUM: Scale+blur+opacity appear animation (matches notchTransition pattern)
            .scaleEffect(mediaOverlayAppeared ? 1.0 : 0.8, anchor: .top)
            .opacity(mediaOverlayAppeared ? 1.0 : 0)
            .animation(displayUnifiedOpenCloseAnimation, value: mediaOverlayAppeared)
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
                // - DI mode: 20pt padding
                // - Notch modes: 30pt padding
                let horizontalPadding: CGFloat = isDynamicIslandMode 
                    ? NotchLayoutConstants.contentPadding 
                    : NotchLayoutConstants.contentPadding + NotchLayoutConstants.wingCornerCompensation
                let albumArtSize: CGFloat = 100
                let contentSpacing: CGFloat = 16
                let visualizerWidth: CGFloat = 24
                let expandedTitleWidth: CGFloat = expandedWidth - (horizontalPadding * 2) - albumArtSize - contentSpacing - visualizerWidth - 8
                let currentTitleWidth = isExpandedOnThisScreen ? expandedTitleWidth : hudTitleWidth
                
                // Calculate position offsets
                let fixedHUDHeight: CGFloat = notchHeight
                
                // HUD X: Centered in pill container
                let hudXOffset: CGFloat = 0
                
                // Expanded X: After album art + spacing, centered in remaining title area
                let titleLeftEdge = -(expandedWidth / 2) + horizontalPadding + albumArtSize + contentSpacing
                let expandedXOffset = titleLeftEdge + (expandedTitleWidth / 2)
                let currentXOffset = isExpandedOnThisScreen ? expandedXOffset : hudXOffset
                
                // Y position
                // HUD: Center title frame vertically (same as album art)
                // Frame height MUST match album art size for perfect alignment
                let hudFrameHeight: CGFloat = isDynamicIslandMode ? 18 : 20
                let hudYOffset: CGFloat = (fixedHUDHeight - hudFrameHeight) / 2
                
                // SSOT: Must match NotchLayoutConstants.contentEdgeInsets exactly
                // - DI mode: 20pt (contentPadding)
                // - External notch style: 20pt (contentPadding)
                // - Built-in notch mode: notchHeight
                // Title TOP must align with album art TOP
                let expandedTopPadding: CGFloat = contentLayoutNotchHeight > 0 
                    ? contentLayoutNotchHeight 
                    : NotchLayoutConstants.contentPadding
                let expandedYOffset: CGFloat = expandedTopPadding  // No offset - title top = album art top
                let currentYOffset = isExpandedOnThisScreen ? expandedYOffset : hudYOffset
                
                // Title text
                let songTitle = isBrowserTrackLoading && musicManager.songTitle.isEmpty
                    ? "Loading..."
                    : (musicManager.songTitle.isEmpty ? "Not Playing" : musicManager.songTitle)
                
                // Alignment: Centered in HUD, left-aligned in expanded
                let currentAlignment: Alignment = isExpandedOnThisScreen ? .leading : .center
                
                // Frame height: match album art for HUD centering
                let currentFrameHeight: CGFloat = isExpandedOnThisScreen ? 20 : hudFrameHeight
                
                // SMOOTH MORPH: Use shared start time so scroll position is continuous during expand/collapse
                MarqueeText(text: songTitle, speed: 30, externalStartTime: sharedMarqueeStartTime, alignment: currentAlignment)
                    .font(.system(size: currentFontSize, weight: isExpandedOnThisScreen ? .semibold : .medium))
                    .foregroundStyle(notchPrimaryText(isExpandedOnThisScreen ? 1.0 : 0.9))
                    .frame(width: currentTitleWidth, height: currentFrameHeight, alignment: currentAlignment)
                    .offset(x: currentXOffset, y: currentYOffset)
                    .geometryGroup()  // Bundle as single element for smooth morphing
                    // PREMIUM: Smooth spring animation for morphing (matches album art)
                    .animation(displayUnifiedOpenCloseAnimation, value: isExpandedOnThisScreen)
                    // PREMIUM: Scale+blur+opacity appear animation (matches notchTransition pattern)
                    .scaleEffect(mediaOverlayAppeared ? 1.0 : 0.8, anchor: .top)
                    .opacity(mediaOverlayAppeared ? 1.0 : 0)
                    .animation(displayUnifiedOpenCloseAnimation, value: mediaOverlayAppeared)
            }
        }
    }
    
    /// Whether the media HUD should be visible (for morphing calculation)
    private var shouldShowMediaHUDForMorphing: Bool {
        // MORPH BEHAVIOR: Hide all media overlays when Caffeine Hover Indicators are showing
        // This allows the caffeine timer to temporarily replace the media HUD on hover
        let caffeineHoverIsActive = isCaffeineHoverActive
        guard !caffeineHoverIsActive else { return false }
        
        let noHUDsVisible = !hudIsVisible && !HUDManager.shared.isVisible
        let notExpanded = !isExpandedOnThisScreen
        let browserTrackLoading = isBrowserTrackLoading
        let targetDisplayID = targetScreen?.displayID ?? 0
        let notInFullscreen = !notchController.fullscreenDisplayIDs.contains(targetDisplayID)
        let shouldShowForced = musicManager.isMediaHUDForced &&
            (musicManager.isPlaying || browserTrackLoading) &&
            (!musicManager.isPlayerIdle || browserTrackLoading) &&
            showMediaPlayer &&
            noHUDsVisible &&
            notExpanded &&
            notInFullscreen &&
            !shouldLockMediaForTodo
        let mediaIsActive = (musicManager.isPlaying && !musicManager.songTitle.isEmpty) || browserTrackLoading
        let notFadedOrTransitioning = !(autoFadeMediaHUD && mediaHUDFadedOut)
        let debounceOk = !debounceMediaChanges || isMediaStable || browserTrackLoading
        let bypassSafeguards = musicManager.isMediaSourceForced
        let hasContent = !musicManager.songTitle.isEmpty || browserTrackLoading
        let shouldBlockAutoSwitch = shouldLockMediaForTodo
        let shouldShowNormal = showMediaPlayer && noHUDsVisible && notExpanded && notInFullscreen && !shouldBlockAutoSwitch &&
                              (bypassSafeguards ? hasContent : (mediaIsActive && notFadedOrTransitioning && debounceOk))
        let shouldShowHovered = mediaHUDIsHovered && isMediaHUDHoverEligible
        return shouldShowForced || shouldShowNormal || shouldShowHovered
    }
    
    /// Whether the expanded media player should be visible (for morphing calculation)
    private var shouldShowExpandedMediaPlayerForMorphing: Bool {
        guard isExpandedOnThisScreen && enableNotchShelf else { return false }
        // TERMINOTCH: Don't show morphing overlays when terminal is visible (and enabled)
        let terminalEnabled = UserDefaults.standard.preference(AppPreferenceKey.terminalNotchEnabled, default: PreferenceDefault.terminalNotchEnabled)
        guard !(terminalManager.isInstalled && terminalEnabled && terminalManager.isVisible) else { return false }
        // HIGH ALERT: Don't show morphing overlays when caffeine view is visible (and enabled)
        let caffeineEnabled = UserDefaults.standard.preference(AppPreferenceKey.caffeineEnabled, default: PreferenceDefault.caffeineEnabled)
        let caffeineShouldShow = UserDefaults.standard.preference(AppPreferenceKey.caffeineInstalled, default: PreferenceDefault.caffeineInstalled) && caffeineEnabled
        guard !(showCaffeineView && caffeineShouldShow) else { return false }
        guard !isCameraViewVisible else { return false }
        let dragMonitor = DragMonitor.shared
        let shouldBlockAutoSwitch = shouldLockMediaForTodo
        let forced = musicManager.isMediaHUDForced
        let autoOrSongDriven = (autoOpenMediaHUDOnShelfExpand && !musicManager.isMediaHUDHidden) ||
            ((musicManager.isPlaying || musicManager.wasRecentlyPlaying) && !musicManager.isMediaHUDHidden && state.items.isEmpty)
        return showMediaPlayer &&
               !musicManager.isPlayerIdle &&
               !state.isDropTargeted &&
               !dragMonitor.isDragging &&
               !shouldBlockAutoSwitch &&
               (forced || autoOrSongDriven)
    }

    // MARK: - Morphing Background
    
    /// Extracted from shelfContent to reduce type-checker complexity
    private var morphingBackground: some View {
        let expandedShadowPadding: CGFloat = isExpandedOnThisScreen ? 18 : 0

        // This is the persistent black shape that grows/shrinks
        // NOTE: The shelf/notch always uses solid black background.
        // The "Transparent Background" setting only applies to other UI elements
        // (Settings, Clipboard, etc.) - not the shelf, as that would look weird.
        // MORPH: Both shapes exist, crossfade with opacity for smooth transition
        return ZStack {
            // Dynamic Island shape (pill)
            // When transparent DI is enabled, use glass material instead of gray
            DynamicIslandShape(cornerRadius: 50)
                .droppyTransparentFill(shouldUseDynamicIslandTransparent, fallback: dynamicIslandGray)
                .opacity(isDynamicIslandMode ? 1 : 0)
                .scaleEffect(isDynamicIslandMode ? 1 : 0.85)
            
            // Notch shape (U-shaped)
            // Built-in: always black (physical notch is black)
            // External: can be transparent when transparency setting is enabled
            NotchShape(bottomRadius: isExpandedOnThisScreen ? 40 : (hudIsVisible ? 18 : 16))
                .droppyTransparentFill(shouldUseExternalNotchTransparent, fallback: Color.black)
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
                DynamicIslandShape(cornerRadius: 50)
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
                    .droppyTransparentFill(shouldUseExternalNotchTransparent, fallback: Color.black)
                    .shadow(
                        // PREMIUM EXACT: .black.opacity(0.7) radius 6
                        color: showShadow ? Color.black.opacity(0.7) : .clear,
                        radius: 6,
                        x: 0,
                        y: isExpandedOnThisScreen ? 4 : 2
                    )
            }
        }
        // Add bottom padding to prevent shadow clipping when expanded.
        // Apply in both notch and island modes so expanded shadow never gets cut.
        .padding(.bottom, expandedShadowPadding)
        .frame(
            width: currentNotchWidth,
            height: currentNotchHeight + expandedShadowPadding,
            alignment: .top
        )
        .opacity(shouldShowVisualNotch ? 1.0 : 0.0)
        // Keep regular transitions animated, but cut inline notch visibility instantly during lock handoff.
        .animation(
            shouldDisableInlineNotchVisibilityAnimation ? nil : displayNotchStateAnimation,
            value: shouldShowVisualNotch
        )
        // PREMIUM: Subtle scale feedback on hover - "I'm ready to expand!"
        // Uses dedicated state for clean single-value animation (no two-value dependency)
        .scaleEffect(notchHoverScale, anchor: .top)
        // PREMIUM: Buttery smooth animation for hover scale (matches Droppy: .bouncy.speed(1.2))
        .animation(displayHoverAnimation, value: notchHoverScale)
        // Note: Idle indicator removed - island is now completely invisible when idle
        // Only appears on hover, drag, or when HUDs/media are active
        .overlay(morphingOutline)
        // Keep container transitions on one curve to avoid stacked/conflicting motion.
        .animation(displayContainerAnimation, value: notchAnimationPhase)
        // Animate pure geometry deltas even when the phase remains identical
        // (for example Caps HUD ON/OFF width changes within .systemHUD).
        .animation(displayContainerAnimation, value: currentNotchWidth)
        .animation(displayContainerAnimation, value: currentNotchHeight)
        .padding(.top, isDynamicIslandMode ? dynamicIslandTopMargin : 0)
        .contextMenu {
            if showClipboardButton {
                Button {
                    ClipboardWindowController.shared.toggle()
                } label: {
                    Label("Open Clipboard", systemImage: "clipboard")
                }
            }
            
            if !state.shelfItems.isEmpty {
                Button {
                    // Calculate shelf anchor: top-center of main screen
                    if let screen = NSScreen.main {
                        let shelfAnchor = NSRect(
                            x: screen.frame.midX - 200,
                            y: screen.frame.maxY - 100,  // Near top of screen where shelf is
                            width: 400,
                            height: 80
                        )
                        ReorderWindowController.shared.show(state: state, target: .shelf, anchorFrame: shelfAnchor)
                    } else {
                        ReorderWindowController.shared.show(state: state, target: .shelf)
                    }
                } label: {
                    Label("Reorder Items", systemImage: "arrow.up.arrow.down")
                }
            }
            
            if showClipboardButton || !state.shelfItems.isEmpty {
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
    /// Note: Notch wings are now built into NotchShape via topCornerRadius
    private var morphingOutline: some View {
        EmptyView()
    }

    // MARK: - Drop Zone

    /// Prevents hover-state jitter in Dynamic Island mode when the cursor moves
    /// into the tiny top-edge gap above the island (Fitts's Law target area).
    private func shouldPreserveTopEdgeHoverIntent() -> Bool {
        guard isDynamicIslandMode else { return false }
        guard let screen = targetScreen ?? NSScreen.builtInWithNotch ?? NSScreen.main else { return false }

        let mouse = NSEvent.mouseLocation
        guard screen.frame.contains(mouse) else { return false }

        let isNearTopEdge = mouse.y >= screen.frame.maxY - 20
        let centerX = screen.notchAlignedCenterX
        let notchMinX = centerX - notchWidth / 2
        let notchMaxX = centerX + notchWidth / 2
        let isWithinNotchRange = mouse.x >= notchMinX - 30 && mouse.x <= notchMaxX + 30

        return isNearTopEdge && isWithinNotchRange
    }
    
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
                withAnimation(displayExpandOpenAnimation) {
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
                    // Keep hover state stable when cursor exits the island shape only because
                    // it moved into the top-edge gap (handled by global monitor hover zone).
                    if !isHovering && shouldPreserveTopEdgeHoverIntent() {
                        return
                    }

                    // Direct state update - animation handled by view-level .animation() modifier
                    if enableNotchShelf {
                        // NOTE: Hover haptic removed per user request - only expand gives feedback
                        state.setHovering(for: displayID, isHovering: isHovering)
                        
                        // PREMIUM: Update hover scale state - only active when hovering AND not expanded
                        hoverScaleActive = isHovering && !isExpandedOnThisScreen
                    }
                    // Propagate hover to media HUD when music is playing (works independently)
                    // DEBOUNCED: Prevents animation stacking from rapid hover toggles
                    if isMediaHUDHoverEligible {
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
                    } else if mediaHUDIsHovered {
                        mediaHUDHoverWorkItem?.cancel()
                        mediaHUDIsHovered = false
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
        .animation(displayHoverAnimation, value: isHoveringOnThisScreen)
        .animation(displayContainerAnimation, value: notchAnimationPhase)
    }

    private var collapsedShelfPeekContent: some View {
        let expandShelf = {
            let displayID = targetScreen?.displayID ?? NSScreen.builtInWithNotch?.displayID
            guard let displayID else { return }
            withAnimation(displayExpandOpenAnimation) {
                state.expandShelf(for: displayID)
            }
        }

        return VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: expandShelf) {
                    PeekFileCountHeader(items: collapsedShelfPeekItems, style: .plain)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .frame(height: 26)
            .padding(.top, 4)

            Spacer(minLength: 0)

            DraggableArea(
                items: {
                    collapsedShelfPeekItems.map { $0.url as NSURL }
                },
                onTap: { _ in
                    expandShelf()
                },
                onRightClick: {},
                onDragComplete: { _ in
                    let autoCleanEnabled = UserDefaults.standard.bool(forKey: AppPreferenceKey.enableAutoClean)
                    guard autoCleanEnabled else { return }
                    withAnimation(displayExpandCloseAnimation) {
                        state.clearAll()
                    }
                },
                selectionSignature: collapsedShelfPeekItems.map(\.id).hashValue
            ) {
                ShelfStackPeekView(items: collapsedShelfPeekItems)
            }
            .frame(width: 176, height: 98, alignment: .bottom)
            .contentShape(Rectangle())

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 0)
    }
    
    // MARK: - Indicators
    
    private var dropIndicatorContent: some View {
        // PREMIUM: Shelf icon in compact indicator
        DropZoneIcon(
            type: .shelf,
            size: 28,
            isActive: state.isDropTargeted,
            useAdaptiveForegrounds: shouldUseExternalNotchTransparent
        )
            .padding(DroppySpacing.sm) // Compact padding
            .background(indicatorBackground)
    }
    
    private var openIndicatorContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(shouldUseFloatingButtonTransparent ? AdaptiveColors.primaryTextAuto : .white, .blue)
                .symbolEffect(.bounce, value: isHoveringOnThisScreen)
            
            Text("Open Shelf")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(shouldUseFloatingButtonTransparent ? AdaptiveColors.primaryTextAuto : .white)
                .shadow(radius: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(indicatorBackground)
    }
    
    // NOTE: In regular notch mode, indicators are solid black.
    // In transparent DI mode OR external notch transparent mode, indicators use glass material.
    private var indicatorBackground: some View {
        RoundedRectangle(cornerRadius: DroppyRadius.lx, style: .continuous)
            .droppyTransparentFill(shouldUseFloatingButtonTransparent, fallback: Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.lx, style: .continuous)
                    .stroke(
                        shouldUseFloatingButtonTransparent
                            ? AdaptiveColors.overlayAuto(0.2)
                            : Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .droppyCardShadow()
    }

    // MARK: - Expanded Content
    
    private var expandedShelfContent: some View {
        // Grid Items or Media Player or Drop Zone or Terminal
        // No header row - auto-collapse handles hiding, right-click for settings/clipboard
        let isQuickActionOverlayVisible = state.hoveredShelfQuickAction != nil
        let shouldShowTodoBar = shouldShowTodoShelfBar && !isQuickActionOverlayVisible

        return ZStack {
            // TERMINAL VIEW: Highest priority - takes over the shelf when active
            if isTerminalViewVisible {
                // SSOT: contentLayoutNotchHeight for consistent terminal content layout
                TerminalNotchView(manager: terminalManager, notchHeight: contentLayoutNotchHeight, isExternalWithNotchStyle: isExternalDisplay && !externalDisplayUseDynamicIsland)
                    .frame(height: currentExpandedHeight, alignment: .top)
                    .id("terminal-view")
                    .transition(displayContentSwapTransition)
            }
            // CAFFEINE VIEW: Show when user clicks caffeine button in shelf
            else if isCaffeineViewVisible {
                CaffeineNotchView(manager: CaffeineManager.shared, isVisible: $showCaffeineView, notchHeight: contentLayoutNotchHeight, isExternalWithNotchStyle: isExternalDisplay && !externalDisplayUseDynamicIsland)
                    .frame(height: currentExpandedHeight, alignment: .top)
                    .id("caffeine-view")
                    .transition(displayContentSwapTransition)
            }
            else if isCameraViewVisible {
                SnapCameraNotchView(
                    manager: cameraManager,
                    notchHeight: contentLayoutNotchHeight,
                    isExternalWithNotchStyle: isExternalDisplay && !externalDisplayUseDynamicIsland
                )
                    .frame(height: currentExpandedHeight, alignment: .top)
                    .id("camera-view")
                    .transition(displayContentSwapTransition)
            }
            // Show drop zone when dragging over (takes priority) - but NOT when Todo bar is visible
            else if state.isDropTargeted && state.items.isEmpty && !shouldShowTodoBar {
                emptyShelfContent
                    .frame(height: currentExpandedHeight, alignment: .top)
                    .transition(displayContentSwapTransition)
            }
            // MEDIA PLAYER VIEW: Show if:
            // 1. User forced it via swipe (isMediaHUDForced) - shows even when paused/idle
            // 2. Auto-open setting enabled AND not hidden by swipe (autoOpenMediaHUDOnShelfExpand && !isMediaHUDHidden)
            // 3. Music is playing AND user hasn't hidden it (isMediaHUDHidden)
            // All paths require: not drop targeted, media enabled, not idle
            // CRITICAL: Don't show during file drag - prevents flash when dropping files
            else if isMediaPlayerVisibleInShelf {
                // SSOT: contentLayoutNotchHeight ensures MediaPlayerView and morphing overlays use identical positioning
                // showTitle: false when morphing overlay handles it (DI mode OR external displays)
                // UNIFIED ANIMATION: MediaPlayerView has its own contentAppeared state that triggers on appear
                // Uses same scale(0.8)+opacity with .smooth(0.35) timing as morphing overlays
                MediaPlayerView(musicManager: musicManager, notchHeight: contentLayoutNotchHeight, isExternalWithNotchStyle: isExternalDisplay && !externalDisplayUseDynamicIsland, albumArtNamespace: albumArtNamespace, showAlbumArt: false, showVisualizer: false, showTitle: !shouldShowTitleInHUD)
                    .frame(height: currentExpandedHeight, alignment: .top)
                    // Capture all clicks within the media player area
                    .contentShape(Rectangle())
                    // Stable identity for animation - prevents jitter on state changes
                    .id("media-player-view")
                    .transition(displayContentSwapTransition)
            }
            // Show empty shelf when no items and no music (or user swiped to hide music)
            // Show drop zone + todo input bar coexisting, but HIDE drop zone when task list is expanded
            else if state.items.isEmpty && !(shouldShowTodoBar && isTodoListExpanded) {
                // When todo bar is visible (but list collapsed), reduce the drop zone height to leave room at bottom
                let todoBarHeight = shouldShowTodoBar
                    ? ToDoShelfBar.expandedHeight(
                        isListExpanded: false,
                        itemCount: todoManager.shelfTimelineItemCount,
                        showsUndoToast: todoManager.showUndoToast
                    )
                    : 0
                emptyShelfContent
                    .frame(height: max(0, currentExpandedHeight - todoBarHeight), alignment: .top)
                    .frame(maxHeight: .infinity, alignment: .top)
                    // Stable identity for animation
                    .id("empty-shelf-view")
                    .transition(displayContentSwapTransition)
            }
            // Show items grid when items exist
            else if !state.items.isEmpty {
                // When todo bar is visible, add bottom content inset so items don't overlap with it
                let todoBarHeight = shouldShowTodoBar
                    ? ToDoShelfBar.expandedHeight(
                        isListExpanded: isTodoListExpanded,
                        itemCount: todoManager.shelfTimelineItemCount,
                        notchHeight: contentLayoutNotchHeight,
                        showsUndoToast: todoManager.showUndoToast
                    )
                    : 0
                Group {
                    if todoBarHeight > 0 {
                        itemsGridView
                            .padding(.bottom, todoBarHeight)
                    } else {
                        itemsGridView
                    }
                }
                    .frame(height: currentExpandedHeight, alignment: .top)
                    // Stable identity for animation
                    .id("items-grid-view")
                    // CONSTRAINT CASCADE SAFETY: Use opacity-only transition for the items grid.
                    // The grid contains ShelfScrollViewResolver (NSViewRepresentable) whose
                    // AppKitPlatformViewHost has Auto Layout constraints. Scale animations
                    // (.notchTransitionLight uses scaleEffect 0.85→1.0) cause geometry changes
                    // that trigger re-entrant _postWindowNeedsUpdateConstraints during
                    // NSDisplayCycleFlush → constraint cascade → crash.
                    .transition(.opacity.animation(displayUnifiedOpenCloseAnimation))
            }

            // QUICK ACTION EXPLANATION OVERLAY
            // Shows action description when hovering over quick action buttons during drag
            if let action = state.hoveredShelfQuickAction {
                shelfQuickActionExplanation(for: action)
                    .frame(height: currentExpandedHeight, alignment: .top)
                    .transition(.opacity.animation(displayNotchStateAnimation))
            }

            // TODO INPUT BAR: Persistent bar at bottom when Todo extension is installed
            // Only show when viewing shelf content (not Terminal, Caffeine, or Media player)
            if shouldAttachTodoShelfBar && shouldShowTodoBar {
                VStack(spacing: 0) {
                    Spacer()
                    ToDoShelfBar(
                        manager: todoManager,
                        isListExpanded: $isTodoListExpanded,
                        hostDisplayID: thisDisplayID,
                        notchHeight: contentLayoutNotchHeight,
                        useAdaptiveForegroundsForTransparentNotch: shouldUseExternalNotchTransparent
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, todoHostHorizontalInset)
                .padding(.bottom, ToDoShelfBar.hostBottomInset)
                .transition(displayContentSwapTransition)
            }

        }
        // NOTE: .drawingGroup() removed - breaks NSViewRepresentable views like AudioSpectrumView
        // which cannot be rasterized into Metal textures (Issue #81 partial rollback)
        // Unified open/close animation for shelf/media switching.
        .animation(displayUnifiedOpenCloseAnimation, value: mediaHUDTransitionToken)
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
            
            // Reorder shelf items
            if !state.shelfItems.isEmpty {
                Button {
                    // Calculate shelf anchor: top-center of main screen
                    if let screen = NSScreen.main {
                        let shelfAnchor = NSRect(
                            x: screen.frame.midX - 200,
                            y: screen.frame.maxY - 100,  // Near top of screen where shelf is
                            width: 400,
                            height: 80
                        )
                        ReorderWindowController.shared.show(state: state, target: .shelf, anchorFrame: shelfAnchor)
                    } else {
                        ReorderWindowController.shared.show(state: state, target: .shelf)
                    }
                } label: {
                    Label("Reorder Items", systemImage: "arrow.up.arrow.down")
                }
            }
            
            // Clear shelf (when items exist)
            if !state.items.isEmpty {
                Button {
                    withAnimation(displayNotchStateAnimation) {
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
    
    /// Explanation overlay shown when hovering over shelf quick action buttons
    @ViewBuilder
    private func shelfQuickActionExplanation(for action: QuickActionType) -> some View {
        ZStack {
            // Opaque background to hide content underneath
            // Must match shelf background style
            if shouldUseFloatingButtonTransparent {
                Rectangle().droppyGlassFill()
            } else {
                Rectangle().fill(Color.black)
            }
            
            // Centered description text - matches basket style
            Text(action.description)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    shouldUseFloatingButtonTransparent
                        ? AdaptiveColors.secondaryTextAuto.opacity(0.82)
                        : .white.opacity(0.5)
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func clearShelfSelectionInteraction() {
        if !state.selectedItems.isEmpty {
            state.deselectAll()
        }
        if renamingItemId != nil {
            renamingItemId = nil
        }
        if state.isRenaming {
            state.isRenaming = false
            state.endFileOperation()
        }
    }

    private func isPointOverShelfItem(_ point: CGPoint) -> Bool {
        itemFrames.values.contains { frame in
            frame.insetBy(dx: 4, dy: 4).contains(point)
        }
    }

    private var shelfSelectionGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("shelfGrid"))
            .onChanged { value in
                let dragDistance = hypot(
                    value.location.x - value.startLocation.x,
                    value.location.y - value.startLocation.y
                )
                guard dragDistance >= 6 else { return }

                if selectionRect == nil {
                    guard !isPointOverShelfItem(value.startLocation) else { return }

                    initialSelection = state.selectedItems
                    let sessionFlags = NSEvent.ModifierFlags(
                        rawValue: UInt(truncatingIfNeeded: CGEventSource.flagsState(.combinedSessionState).rawValue)
                    ).intersection(.deviceIndependentFlagsMask)
                    let modifiers = NSEvent.modifierFlags
                        .union(sessionFlags)
                        .intersection(.deviceIndependentFlagsMask)
                    if !modifiers.contains(.command) && !modifiers.contains(.shift) {
                        state.deselectAll()
                        initialSelection = []
                    }
                }

                guard selectionRect != nil || !isPointOverShelfItem(value.startLocation) else { return }

                let rect = CGRect(
                    x: min(value.startLocation.x, value.location.x),
                    y: min(value.startLocation.y, value.location.y),
                    width: abs(value.location.x - value.startLocation.x),
                    height: abs(value.location.y - value.startLocation.y)
                )
                selectionRect = rect
                updateShelfAutoScrollVelocity(at: value.location)
                updateShelfSelection(using: rect)
            }
            .onEnded { value in
                let dragDistance = hypot(
                    value.location.x - value.startLocation.x,
                    value.location.y - value.startLocation.y
                )

                if let rect = selectionRect {
                    updateShelfSelection(using: rect)
                    selectionRect = nil
                } else if dragDistance < 6 && !isPointOverShelfItem(value.startLocation) {
                    clearShelfSelectionInteraction()
                }

                initialSelection = []
                shelfAutoScrollVelocity = 0
            }
    }

    private func updateShelfAutoScrollVelocity(at location: CGPoint) {
        guard selectionRect != nil else {
            shelfAutoScrollVelocity = 0
            return
        }
        guard shelfScrollViewportFrame != .zero else {
            shelfAutoScrollVelocity = 0
            return
        }

        let threshold: CGFloat = 40
        let topEdge = shelfScrollViewportFrame.minY + threshold
        let bottomEdge = shelfScrollViewportFrame.maxY - threshold

        if location.y < topEdge {
            let distance = min(topEdge - location.y, threshold)
            shelfAutoScrollVelocity = -(distance / threshold)
        } else if location.y > bottomEdge {
            let distance = min(location.y - bottomEdge, threshold)
            shelfAutoScrollVelocity = distance / threshold
        } else {
            shelfAutoScrollVelocity = 0
        }
    }

    private func updateShelfSelection(using rect: CGRect) {
        var newSelection = initialSelection
        for (id, frame) in itemFrames where rect.intersects(frame) {
            newSelection.insert(id)
        }
        if newSelection != state.selectedItems {
            state.selectedItems = newSelection
        }
    }

    private func performShelfAutoScrollTick() {
        guard selectionRect != nil else { return }
        guard shelfAutoScrollVelocity != 0 else { return }
        guard shelfScrollViewportFrame != .zero, let scrollView = shelfScrollView else { return }
        guard let documentView = scrollView.documentView else { return }

        let minStep: CGFloat = 4
        let maxStep: CGFloat = 12
        let logicalDelta = shelfAutoScrollVelocity * (minStep + (maxStep - minStep) * abs(shelfAutoScrollVelocity))
        let deltaY = documentView.isFlipped ? logicalDelta : -logicalDelta

        let clipView = scrollView.contentView
        let currentY = clipView.bounds.origin.y
        let maxY = max(0, documentView.bounds.height - clipView.bounds.height)
        let newY = min(max(currentY + deltaY, 0), maxY)

        guard abs(newY - currentY) > 0.5 else {
            shelfAutoScrollVelocity = 0
            return
        }

        clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: newY))
        scrollView.reflectScrolledClipView(clipView)

        if let rect = selectionRect {
            updateShelfSelection(using: rect)
        }
    }

    private func viewportFrameDidChange(from oldFrame: CGRect, to newFrame: CGRect) -> Bool {
        abs(oldFrame.origin.x - newFrame.origin.x) > 0.5 ||
        abs(oldFrame.origin.y - newFrame.origin.y) > 0.5 ||
        abs(oldFrame.size.width - newFrame.size.width) > 0.5 ||
        abs(oldFrame.size.height - newFrame.size.height) > 0.5
    }
    
    private var itemsGridView: some View {
        return ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                // Background tap handler - acts as a "canvas" to catch clicks
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: max(shelfScrollViewportFrame.height, 1), alignment: .topLeading)
                    .contentShape(Rectangle())
                
                // Items grid using LazyVGrid with flexible layout to fill available space
                // Use flexible columns that expand to fill the container width evenly
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
                
                LazyVGrid(columns: columns, spacing: 12) {
                    // Power Folders first
                    ForEach(state.shelfPowerFolders) { folder in
                        NotchItemView(
                            item: folder,
                            state: state,
                            renamingItemId: $renamingItemId,
                            onRemove: {
                                withAnimation(displayNotchStateAnimation) {
                                    state.removeItem(folder)
                                }
                            },
                            useAdaptiveForegroundsForTransparentNotch: shouldUseExternalNotchTransparent
                        )
                        // PERFORMANCE: Skip transitions during bulk add
                        .transition(state.isBulkUpdating ? .identity : displayElementTransition)
                    }
                    
                    // Regular items - flat display with drag-to-rearrange
                    ForEach(state.shelfItems) { item in
                        NotchItemView(
                            item: item,
                            state: state,
                            renamingItemId: $renamingItemId,
                            onRemove: {
                                withAnimation(displayNotchStateAnimation) {
                                    state.removeItem(item)
                                }
                            },
                            useAdaptiveForegroundsForTransparentNotch: shouldUseExternalNotchTransparent
                        )
                        // PERFORMANCE: Skip transitions during bulk add
                        .transition(state.isBulkUpdating ? .identity : displayElementTransition)
                    }
                }
                .transaction { transaction in
                    if state.isBulkUpdating {
                        transaction.animation = nil
                    }
                }
                .background(ShelfScrollViewResolver { scrollView in
                    self.shelfScrollView = scrollView
                })
                // SSOT: Top padding clears physical notch in built-in notch mode
                // External displays and DI mode use smaller symmetrical padding
                .padding(.top, contentLayoutNotchHeight == 0 ? 8 : contentLayoutNotchHeight + 4)
                .padding(.bottom, 6)
                // Horizontal padding: 20pt for DI mode, 30pt for notch modes
                .padding(.horizontal, isDynamicIslandMode ? NotchLayoutConstants.contentPadding : NotchLayoutConstants.contentPadding + NotchLayoutConstants.wingCornerCompensation)

                if let rect = selectionRect {
                    RoundedRectangle(cornerRadius: DroppyRadius.xs, style: .continuous)
                        .fill(Color.blue.opacity(0.2))
                        .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, minHeight: max(shelfScrollViewportFrame.height, 1), alignment: .top)
        }
        // Enable scrolling when more than 3 rows, disable otherwise
        .scrollDisabled(state.shelfDisplaySlotCount <= 15)  // 5 items per row * 3 rows = 15
        .coordinateSpace(name: "shelfGrid")
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        let frame = proxy.frame(in: .named("shelfGrid"))
                        if viewportFrameDidChange(from: shelfScrollViewportFrame, to: frame) {
                            shelfScrollViewportFrame = frame
                        }
                    }
                    .onChange(of: proxy.frame(in: .named("shelfGrid"))) { _, newFrame in
                        if viewportFrameDidChange(from: shelfScrollViewportFrame, to: newFrame) {
                            shelfScrollViewportFrame = newFrame
                        }
                    }
            }
        )
        .onReceive(shelfAutoScrollTicker) { _ in
            performShelfAutoScrollTick()
        }
        // Listen for marquee drags without stealing child item drags.
        .simultaneousGesture(shelfSelectionGesture, including: .all)
        .clipped() // Prevent hover effects from bleeding past shelf edges
        .contentShape(Rectangle())
        // Removed .onTapGesture from here to prevent swallowing touches on children
        .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
            self.itemFrames = frames
        }
    }
}

private struct ShelfScrollViewResolver: NSViewRepresentable {
    let onResolve: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            resolveScrollView(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            resolveScrollView(from: nsView)
        }
    }

    private func resolveScrollView(from view: NSView) {
        var current: NSView? = view
        while let candidate = current {
            if let scroll = candidate.enclosingScrollView {
                onResolve(scroll)
                return
            }
            current = candidate.superview
        }
    }
}

// MARK: - Custom Notch Shape
/// U-shaped notch with elegant curved top corners (wings) extending outward
/// Creates visual transition to screen edges
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomRadius: CGFloat
    
    init(topCornerRadius: CGFloat = 10, bottomRadius: CGFloat = 16) {
        self.topCornerRadius = topCornerRadius
        self.bottomRadius = bottomRadius
    }
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomRadius) }
        set {
            topCornerRadius = newValue.first
            bottomRadius = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // === TOP LEFT WING ===
        // Start at top-left corner (screen edge)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Curve inward from screen edge to notch body
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )
        
        // === LEFT EDGE ===
        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomRadius))
        
        // === BOTTOM LEFT CORNER ===
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )
        
        // === BOTTOM EDGE ===
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomRadius, y: rect.maxY))
        
        // === BOTTOM RIGHT CORNER ===
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )
        
        // === RIGHT EDGE ===
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))
        
        // === TOP RIGHT WING ===
        // Curve outward from notch body to screen edge
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )
        
        // === TOP EDGE (closing) ===
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
                DropZoneIcon(
                    type: .shelf,
                    size: 44,
                    isActive: state.isDropTargeted,
                    useAdaptiveForegrounds: shouldUseExternalNotchTransparent
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                // PREMIUM PRESSED EFFECT: Layered inner glow for 3D depth
                Group {
                    if state.isDropTargeted {
                        ZStack {
                            // Layer 1: Soft inner border glow - premium edge highlight
                            RoundedRectangle(cornerRadius: DroppyRadius.jumbo + 2, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            notchOverlayTone(0.25),
                                            notchOverlayTone(0.1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 2
                                )
                            // Layer 2: Subtle vignette for depth
                            RoundedRectangle(cornerRadius: DroppyRadius.jumbo + 2, style: .continuous)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.clear,
                                            notchOverlayTone(0.08)
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
                        RoundedRectangle(cornerRadius: DroppyRadius.jumbo + 2, style: .continuous)
                            .strokeBorder(
                                notchOverlayTone(0.2),
                                style: StrokeStyle(
                                    lineWidth: 1.5,
                                    lineCap: .round,
                                    dash: [6, 8],
                                    dashPhase: dropZoneDashPhase
                                )
                            )
                    }
                }
            )
        }
        // Use SSOT for consistent padding across all expanded views (v21.68 VERIFIED)
        // - Built-in notch mode: top = notchHeight, left/right = 30pt, bottom = 20pt
        // - External notch style: top/bottom = 20pt, left/right = 30pt
        // - Island mode: 30pt on ALL 4 edges
        .padding(NotchLayoutConstants.contentEdgeInsets(notchHeight: contentLayoutNotchHeight, isExternalWithNotchStyle: isExternalDisplay && !externalDisplayUseDynamicIsland))
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
