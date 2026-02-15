//
//  NotchWindowController.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers
import Observation
import SkyLightWindow
import QuartzCore

private let notchMotionDebugLogs = false

@inline(__always)
private func notchDebugLog(_ message: @autoclosure () -> String) {
    guard notchMotionDebugLogs else { return }
    print(message())
}

private enum NotificationHUDHitZone {
    static let notchStyleWidth: CGFloat = 450
    static let dynamicIslandWidth: CGFloat = 260
    static let dynamicIslandHeight: CGFloat = 70
    static let builtInNotchHeight: CGFloat = 110
    static let externalNotchHeightCompact: CGFloat = 78
    static let externalNotchHeightWithPreview: CGFloat = 84
}

@inline(__always)
private func isNotificationHUDActive(on displayID: CGDirectDisplayID) -> Bool {
    guard let activeHUD = HUDManager.shared.activeHUD else { return false }
    return activeHUD.type == .notification && activeHUD.displayID == displayID
}

@inline(__always)
private func notificationHUDUsesDynamicIsland(on screen: NSScreen) -> Bool {
    let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
    let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")

    if !screen.isBuiltIn {
        return (UserDefaults.standard.object(forKey: AppPreferenceKey.externalDisplayUseDynamicIsland) as? Bool) ?? true
    }

    let useDynamicIsland = (UserDefaults.standard.object(forKey: AppPreferenceKey.useDynamicIslandStyle) as? Bool) ?? true
    return (!hasPhysicalNotch || forceTest) && useDynamicIsland
}

private func notificationHUDHeight(on screen: NSScreen, isDynamicIslandMode: Bool) -> CGFloat {
    if isDynamicIslandMode {
        return NotificationHUDHitZone.dynamicIslandHeight
    }

    let isExternalNotchStyle = !screen.isBuiltIn &&
        !((UserDefaults.standard.object(forKey: AppPreferenceKey.externalDisplayUseDynamicIsland) as? Bool) ?? true)
    guard isExternalNotchStyle else { return NotificationHUDHitZone.builtInNotchHeight }

    let hasPreviewTextLine: Bool = {
        let manager = NotificationHUDManager.shared
        guard manager.showPreview, let notification = manager.currentNotification else { return false }
        let previewText = [notification.displaySubtitle, notification.body]
            .compactMap { $0 }
            .joined(separator: " · ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !previewText.isEmpty
    }()

    return hasPreviewTextLine
        ? NotificationHUDHitZone.externalNotchHeightWithPreview
        : NotificationHUDHitZone.externalNotchHeightCompact
}

private func notificationHUDInteractionZone(on screen: NSScreen) -> NSRect? {
    guard NotificationHUDManager.shared.currentNotification != nil else { return nil }

    let isDynamicIslandMode = notificationHUDUsesDynamicIsland(on: screen)
    let width = isDynamicIslandMode ? NotificationHUDHitZone.dynamicIslandWidth : NotificationHUDHitZone.notchStyleWidth
    let height = notificationHUDHeight(on: screen, isDynamicIslandMode: isDynamicIslandMode)
    let topMargin = isDynamicIslandMode ? NotchLayoutConstants.dynamicIslandTopMargin : 0
    let centerX = screen.notchAlignedCenterX

    return NSRect(
        x: centerX - (width / 2),
        y: screen.frame.maxY - topMargin - height,
        width: width,
        height: height
    )
}

private final class NoAnimationCAAction: NSObject, CAAction {
    static let shared = NoAnimationCAAction()

    func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {}
}

/// Manages the transparent overlay window positioned at the MacBook notch
final class NotchWindowController: NSObject, ObservableObject {
    /// Dictionary of notch windows keyed by display ID (supports multi-monitor)
    private var notchWindows: [CGDirectDisplayID: NotchWindow] = [:]
    
    /// Flag to prevent SkyLight delegation during window recreation after unlock
    /// When true, createWindowForScreen skips SkyLight delegation even if setting is enabled
    private var isRecreatingWindowsAfterUnlock = false
    
    /// Backwards-compatible accessor for the primary notch window
    /// Returns the built-in screen window, or the first available window
    private var notchWindow: NotchWindow? {
        if let builtIn = NSScreen.builtInWithNotch, let window = notchWindows[builtIn.displayID] {
            return window
        }
        return notchWindows.values.first
    }
    
    /// Storage for Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Timer for slow environmental checks (fullscreen)
    private var isFullscreenMonitoring = false
    
    /// Monitor for mouse movement when window is not key or mouse is outside
    private var globalMouseMonitor: Any?
    
    /// Monitor for global click events (single-click shelf opening)
    private var globalClickMonitor: Any?
    
    /// Monitor for mouse movement when window is active
    private var localMonitor: Any?
    
    /// Monitor for keyboard events (spacebar for Quick Look)
    private var keyboardMonitor: Any?
    
    /// Global keyboard monitor (fallback when shelf isn't key window)
    private var globalKeyboardMonitor: Any?
    
    /// Timer for edge detection fallback (when mouse events stop at screen edge)
    private var edgeDetectionTimer: Timer?
    
    /// Timer for auto-expand on hover
    private var autoExpandTimer: Timer?
    
    /// Monitor for scroll wheel events (2-finger swipe for media HUD toggle)
    private var scrollMonitor: Any?
    
    /// Local monitor for scroll wheel events (over Droppy's window)
    private var localScrollMonitor: Any?
    
    /// Monitor for right-click events when notch is hidden (to re-show)
    private var hiddenRightClickMonitor: Any?
    
    /// Monitor for global right-click events (context menu access in idle state) - Issue #57 fix
    private var globalRightClickMonitor: Any?
    
    /// Watchdog timer for self-healing - validates window state periodically
    private var watchdogTimer: Timer?
    
    // MARK: - Size Stability System (Rock-Solid Protection)
    // Multi-layer defense against size reversion during rapid clicks
    
    /// Expected window sizes by display ID - the "source of truth" for correct size
    /// Updated BEFORE frame changes, validated by watchdog, enforced absolutely
    private var expectedWindowSizes: [CGDirectDisplayID: CGFloat] = [:]
    
    /// Last successful size update timestamp by display ID (for throttling)
    private var lastSizeUpdateTime: [CGDirectDisplayID: Date] = [:]
    
    /// Pending size update work items (for coalesced deferred updates)
    private var pendingSizeUpdates: [CGDirectDisplayID: DispatchWorkItem] = [:]
    
    /// Last click time for debounce (prevents rapid toggle storms)
    private var lastNotchClickTime: Date = .distantPast
    
    /// Minimum interval between size updates (coalesce rapid changes)
    private let sizeUpdateThrottle: TimeInterval = 0.05 // 50ms
    
    /// Maximum allowed deviation from expected size before forcing correction
    /// Set to 50pt to allow for animation transitions and bulk operations
    private let sizeDeviationTolerance: CGFloat = 50.0

    /// Keep horizontal corrections coarse to avoid visible side-to-side jitter during
    /// rapid SwiftUI state transitions (expanded -> collapsed -> expanded).
    private let horizontalRecenterTolerance: CGFloat = 16.0
    
    /// Minimum interval between click actions (prevent rapid toggle)
    private let clickDebounceInterval: TimeInterval = 0.1 // 100ms
    
    /// System observers for wake/display changes
    private var systemObservers: [NSObjectProtocol] = []
    
    /// Shared instance
    static let shared = NotchWindowController()
    
    /// Whether the notch is temporarily hidden by user action
    /// Published for menu bar UI to observe
    @Published private(set) var isTemporarilyHidden = false
    
    /// Whether a fullscreen app is active on ANY monitored screen (legacy compatibility)
    /// Published for SwiftUI views to hide media HUD when user has enabled "Hide in Fullscreen"
    @Published private(set) var isFullscreen = false
    
    /// Per-display fullscreen tracking (multi-monitor support)
    /// Each display can independently be in fullscreen mode
    /// Key = CGDirectDisplayID, Value = number of consecutive fullscreen detections (for hysteresis)
    @Published private(set) var fullscreenDisplayIDs: Set<CGDirectDisplayID> = []
    
    /// Debounce counters for fullscreen exit detection per display (hysteresis)
    /// Prevents media HUD flickering when fullscreen detection briefly fails
    private var fullscreenExitDebounceCounts: [CGDirectDisplayID: Int] = [:]
    private let fullscreenExitDebounceThreshold = 2  // Require 2 consecutive non-fullscreen (2 seconds at 1s interval)
    
    /// Per-display fullscreen hover-reveal tracking (Bug #133 fix)
    /// When user hovers at top edge in fullscreen, we temporarily reveal the notch
    var fullscreenHoverRevealedDisplays: Set<CGDirectDisplayID> = []
    
    private override init() {
        super.init()
        setupSystemObservers()
    }
    
    deinit {
        stopMonitors()
        stopWatchdog()
        removeSystemObservers()
    }
    
    /// Checks if a context menu is currently open (prevents shelf closure during menu interactions)
    func hasActiveContextMenu() -> Bool {
        // Restrict detection to menu-class windows only.
        // Generic high-level panels (basket/OCR/etc.) must NOT block shelf collapse logic.
        return NSApp.windows.contains { window in
            guard window.isVisible else { return false }
            guard window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue else { return false }
            let className = NSStringFromClass(type(of: window)).lowercased()
            return className.contains("menu")
        }
    }

    /// Checks if a transient popover/aux panel is currently open.
    func hasActivePopoverWindow() -> Bool {
        NSApp.windows.contains { window in
            guard window.isVisible else { return false }
            let className = String(describing: type(of: window))
            return className.contains("Popover")
        }
    }

    private let shelfBaseWidth: CGFloat = 450
    private let todoSplitShelfWidth: CGFloat = 920
    private let interactionWidthPadding: CGFloat = 80
    private let stableInteractionWindowWidth: CGFloat = 1000

    private func effectiveShelfCenterX(for screen: NSScreen) -> CGFloat {
        screen.notchAlignedCenterX
    }

    fileprivate func currentExpandedShelfWidth() -> CGFloat {
        if ToDoManager.shared.isShelfListExpanded &&
            ToDoManager.shared.isShelfSplitViewEnabled {
            return max(shelfBaseWidth, todoSplitShelfWidth)
        }
        return shelfBaseWidth
    }

    fileprivate func expandedShelfInteractionZone(
        for screen: NSScreen,
        horizontalPadding: CGFloat = 12,
        verticalPadding: CGFloat = 12
    ) -> NSRect {
        let usingMediaHeight = shouldUseMediaInteractionHeight(on: screen)
        let expandedWidth = currentExpandedShelfWidth()
        let centerX = effectiveShelfCenterX(for: screen)
        let expandedHeight = expandedShelfInteractionHeight(for: screen)
        let isTodoSplitExpanded = ToDoManager.shared.isShelfListExpanded &&
            ToDoManager.shared.isShelfSplitViewEnabled
        // ToDo split mode lifts top controls upward; extend the interaction zone upward
        // so those controls never count as "outside click" targets.
        // Keep this generous to cover notch + menu-bar-adjacent placements reliably.
        let topPadding = verticalPadding + (isTodoSplitExpanded ? 80 : 0)
        // Media mode uses a reduced base height for less "sticky" hover behavior.
        // Add back just the floating-controls lane so buttons below the card remain reachable.
        let mediaFloatingControlsPadding = usingMediaHeight ? expandedFloatingControlsReachPadding(for: screen) : 0
        let bottomPadding = verticalPadding + mediaFloatingControlsPadding

        return NSRect(
            x: centerX - expandedWidth / 2 - horizontalPadding,
            y: screen.frame.origin.y + screen.frame.height - expandedHeight - bottomPadding,
            width: expandedWidth + (horizontalPadding * 2),
            height: expandedHeight + bottomPadding + topPadding
        )
    }

    /// Expanded media surface is much shorter than the generic max shelf height.
    /// Using the true media height prevents sticky hover/collapse behavior.
    private func expandedMediaInteractionHeight(for screen: NSScreen) -> CGFloat {
        let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        if hasPhysicalNotch {
            let topInset = screen.safeAreaInsets.top
            let notchHeight = topInset > 0 ? topInset : NotchLayoutConstants.physicalNotchHeight
            return notchHeight + 120
        }
        return 140
    }

    private func shouldUseMediaInteractionHeight(on screen: NSScreen) -> Bool {
        let displayID = screen.displayID
        guard DroppyState.shared.isExpanded(for: displayID) else { return false }
        guard !DragMonitor.shared.isDragging, !DroppyState.shared.isDropTargeted else { return false }

        let showMediaPlayer = (UserDefaults.standard.object(forKey: AppPreferenceKey.showMediaPlayer) as? Bool) ?? PreferenceDefault.showMediaPlayer
        guard showMediaPlayer else { return false }
        guard DroppyState.shared.shelfDisplaySlotCount == 0 else { return false }
        guard MusicManager.shared.isMediaAvailable, !MusicManager.shared.isPlayerIdle else { return false }

        // Terminal takes over the expanded surface when active.
        if TerminalNotchManager.shared.isVisible {
            return false
        }

        // Obsidian takes over expanded shelf sizing/interaction while visible.
        if ObsidianManager.shared.isVisible {
            return false
        }

        // To-do editing/list sessions should keep their own interaction zone.
        let todoManager = ToDoManager.shared
        if todoManager.isVisible || todoManager.isShelfListExpanded || todoManager.isEditingText || todoManager.isInteractingWithPopover {
            return false
        }

        let autoOpenMediaHUD = (UserDefaults.standard.object(forKey: AppPreferenceKey.autoOpenMediaHUDOnShelfExpand) as? Bool) ?? PreferenceDefault.autoOpenMediaHUDOnShelfExpand
        let mediaHidden = MusicManager.shared.isMediaHUDHidden
        let forcedMedia = MusicManager.shared.isMediaHUDForced
        let autoOrSongDriven = (autoOpenMediaHUD && !mediaHidden) ||
            ((MusicManager.shared.isPlaying || MusicManager.shared.wasRecentlyPlaying) && !mediaHidden)

        return forcedMedia || autoOrSongDriven
    }

    private func expandedShelfInteractionHeight(for screen: NSScreen) -> CGFloat {
        let fallbackHeight = DroppyState.expandedShelfHeight(for: screen)
        guard shouldUseMediaInteractionHeight(on: screen) else { return fallbackHeight }
        return min(fallbackHeight, expandedMediaInteractionHeight(for: screen))
    }

    /// Additional downward interaction reach required for floating controls beneath
    /// the expanded media card (close/terminal/camera/caffeine/obsidian + quick actions).
    private func expandedFloatingControlsReachPadding(for screen: NSScreen) -> CGFloat {
        let displayID = screen.displayID
        guard DroppyState.shared.isExpanded(for: displayID) else { return 0 }

        let enableNotchShelf = (UserDefaults.standard.object(forKey: AppPreferenceKey.enableNotchShelf) as? Bool) ?? true
        guard enableNotchShelf else { return 0 }

        let dragging = DragMonitor.shared.isDragging
        let autoCollapseEnabled = (UserDefaults.standard.object(forKey: AppPreferenceKey.autoCollapseShelf) as? Bool) ?? true
        let enableQuickActions = UserDefaults.standard.preference(AppPreferenceKey.enableQuickActions, default: PreferenceDefault.enableQuickActions)

        let terminalInstalled = UserDefaults.standard.preference(AppPreferenceKey.terminalNotchInstalled, default: PreferenceDefault.terminalNotchInstalled)
        let terminalEnabled = UserDefaults.standard.preference(AppPreferenceKey.terminalNotchEnabled, default: PreferenceDefault.terminalNotchEnabled)
        let caffeineInstalled = UserDefaults.standard.preference(AppPreferenceKey.caffeineInstalled, default: PreferenceDefault.caffeineInstalled)
        let caffeineEnabled = UserDefaults.standard.preference(AppPreferenceKey.caffeineEnabled, default: PreferenceDefault.caffeineEnabled)
        let cameraInstalled = UserDefaults.standard.preference(AppPreferenceKey.cameraInstalled, default: PreferenceDefault.cameraInstalled)
        let cameraEnabled = UserDefaults.standard.preference(AppPreferenceKey.cameraEnabled, default: PreferenceDefault.cameraEnabled)
        let obsidianInstalled = UserDefaults.standard.preference(AppPreferenceKey.obsidianInstalled, default: PreferenceDefault.obsidianInstalled)
        let obsidianEnabled = UserDefaults.standard.preference(AppPreferenceKey.obsidianEnabled, default: PreferenceDefault.obsidianEnabled)
        let obsidianVisible = obsidianInstalled &&
            obsidianEnabled &&
            !ExtensionType.obsidian.isRemoved &&
            DroppyState.shared.shelfDisplaySlotCount == 0

        let regularButtonsVisible = !dragging && (
            (terminalInstalled && terminalEnabled) ||
            (caffeineInstalled && caffeineEnabled) ||
            (cameraInstalled && cameraEnabled) ||
            obsidianVisible ||
            !autoCollapseEnabled
        )
        let quickActionsVisible = dragging && enableQuickActions

        guard regularButtonsVisible || quickActionsVisible else { return 0 }

        let isDynamicIsland = NotchLayoutConstants.isDynamicIslandMode(for: screen)
        let islandCompensation: CGFloat = isDynamicIsland ? NotchLayoutConstants.floatingButtonIslandCompensation : 0
        let controlHeight: CGFloat = quickActionsVisible ? 44 : 32
        let hoverHeadroom: CGFloat = 20

        return NotchLayoutConstants.floatingButtonGap + islandCompensation + controlHeight + hoverHeadroom
    }

    func isMouseInsideExpandedShelfInteractionZone(on screen: NSScreen, at location: NSPoint = NSEvent.mouseLocation) -> Bool {
        expandedShelfInteractionZone(for: screen).contains(location)
    }

    private func currentInteractionWindowWidth() -> CGFloat {
        let maxSurfaceWidth = max(shelfBaseWidth, todoSplitShelfWidth)
        return max(stableInteractionWindowWidth, maxSurfaceWidth + interactionWidthPadding)
    }
    
    /// Sets up and shows the notch overlay window(s)
    /// Creates windows for all eligible screens based on user settings
    func setupNotchWindow() {
        let hideOnExternal = UserDefaults.standard.bool(forKey: "hideNotchOnExternalDisplays")
        
        for screen in NSScreen.screens {
            let displayID = screen.displayID
            
            // Skip if window already exists for this screen
            guard notchWindows[displayID] == nil else { continue }
            
            if !shouldShowOnScreen(screen, hideOnExternal: hideOnExternal) {
                continue
            }
            
            // Create window for this screen
            createWindowForScreen(screen)
        }
        
        // Start monitors only if we have at least one window
        if !notchWindows.isEmpty {
            startMonitors()
            
            // Restore hidden state from previous session
            let wasHidden = UserDefaults.standard.bool(forKey: AppPreferenceKey.isNotchHidden)
            if wasHidden {
                setTemporarilyHidden(true)
            }
        }
    }
    
    /// Creates a notch window for a specific screen
    private func createWindowForScreen(_ screen: NSScreen) {
        let displayID = screen.displayID
        
        // Window needs to be wide enough for expanded shelf interaction zones.
        // Height is limited to avoid false hover detection in empty areas
        let windowWidth = currentInteractionWindowWidth()
        let windowHeight: CGFloat = 280

        // Position at top center of screen (aligned with notch) using global coordinates
        let xPosition = effectiveShelfCenterX(for: screen) - (windowWidth / 2)
        let yPosition = screen.frame.origin.y + screen.frame.height - windowHeight
        
        let windowFrame = NSRect(
            x: xPosition,
            y: yPosition,
            width: windowWidth,
            height: windowHeight
        )
        
        // Create the custom window (NSPanel for first-click activation)
        let window = NotchWindow(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Store the target screen's display ID for the window
        window.targetDisplayID = displayID
        
        // Set up the view hierarchy
        // 1. Create the SwiftUI view with screen context
        let notchView = NotchShelfView(state: DroppyState.shared, targetScreen: screen)
            .preferredColorScheme(.dark) // Force dark mode always

        let hostingView = NSHostingView(rootView: notchView)
        configureMotionLayer(hostingView)
        hostingView.layer?.backgroundColor = CGColor.clear
        
        // 2. Create the container view that handles drops
        let dragContainer = NotchDragContainer(frame: NSRect(origin: .zero, size: windowFrame.size))
        configureMotionLayer(dragContainer)
        dragContainer.hostingView = hostingView
        dragContainer.addSubview(hostingView)
        
        // Layout
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: dragContainer.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: dragContainer.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: dragContainer.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: dragContainer.trailingAnchor)
        ])
        
        window.contentView = dragContainer
        if let contentView = window.contentView {
            configureMotionLayer(contentView)
        }
        
        // Show the window
        window.orderFrontRegardless()
        
        // Apply screenshot visibility setting
        let hideFromScreenshots = UserDefaults.standard.bool(forKey: "hideNotchFromScreenshots")
        window.sharingType = hideFromScreenshots ? .none : .readOnly
        
        // Store in dictionary
        notchWindows[displayID] = window
        
        // Note: We do NOT delegate to SkyLight here eagerly.
        // Doing so breaks drag-and-drop on the desktop for the built-in screen.
        // Delegation happens ONLY when the screen is actually locked (via sessionDidResignActive).
    }

    /// AppKit-level motion quality guard:
    /// disable implicit layer animations that can cause accidental lateral drift
    /// when frame/bounds/content updates happen in rapid succession.
    private func configureMotionLayer(_ view: NSView) {
        view.wantsLayer = true
        view.layerContentsRedrawPolicy = .onSetNeedsDisplay

        guard let layer = view.layer else { return }
        let noAction = NoAnimationCAAction.shared
        layer.actions = [
            "position": noAction,
            "bounds": noAction,
            "frame": noAction,
            "transform": noAction,
            "sublayerTransform": noAction,
            "opacity": noAction,
            "contents": noAction
        ]
    }
    /// Updates the window's visibility in screenshots based on user preference
    func updateScreenshotVisibility() {
        let hideFromScreenshots = UserDefaults.standard.bool(forKey: "hideNotchFromScreenshots")
        for window in notchWindows.values {
            window.sharingType = hideFromScreenshots ? .none : .readOnly
        }
    }
    
    /// Delegates the built-in display's notch window to SkyLight space for lock screen visibility
    /// Call this when the lock screen media widget setting is enabled
    /// Once delegated, the window is visible on BOTH lock screen and desktop
    func delegateToLockScreen() {
        guard let builtInScreen = NSScreen.builtInWithNotch else {
            print("NotchWindowController: ⚠️ No built-in screen found for lock screen delegation")
            return
        }
        
        guard let window = notchWindows[builtInScreen.displayID] else {
            print("NotchWindowController: ⚠️ No notch window for built-in display")
            return
        }
        
        SkyLightOperator.shared.delegateWindow(window)
        window.isOnLockScreen = true
        
        // CRITICAL: Raise window level to Shielding to be visible above lock screen wallpaper
        // Also ensure collection behavior allows it to persist
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        // CRITICAL: Bring to front of the shielding level
        window.orderFrontRegardless()
        
        print("NotchWindowController: ✅ Delegated notch window to SkyLight for lock screen visibility (Level: Shielding)")
    }
    
    /// Handles returning from lock screen state
    /// Recreates the window to restore standard desktop interactivity (drag-and-drop, level)
    func returnFromLockScreen() {
        guard let builtInScreen = NSScreen.builtInWithNotch else { return }
        
        // Only recycle if we actually have a window that was delegated
        if let window = notchWindows[builtInScreen.displayID], window.isOnLockScreen {
            print("NotchWindowController: 🔓 Returning from lock screen - restoring window properties")
            
            // Restore standard desktop window properties (recycling the window)
            // This prevents SwiftUI view recreation and the associated 'jump' animations
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            window.isOnLockScreen = false
            window.ignoresMouseEvents = true // Reset to safe idle state
            
            // Ensure proper ordering
            window.orderFrontRegardless()
            
            print("NotchWindowController: ✅ Window restored to desktop state (Level: StatusBar)")
        }
    }
    
    /// Closes all notch windows
    func closeWindow() {
        stopMonitors()
        for window in notchWindows.values {
            window.isValid = false
            window.close()
        }
        notchWindows.removeAll()
    }
    
    /// Temporarily hides or shows all notch windows
    /// Animation is handled by SwiftUI (scale + opacity with spring animation)
    /// - Parameter hidden: true to hide, false to show
    func setTemporarilyHidden(_ hidden: Bool) {
        isTemporarilyHidden = hidden
        
        // Persist the hidden state so it survives app restarts
        UserDefaults.standard.set(hidden, forKey: AppPreferenceKey.isNotchHidden)
        
        if hidden {
            // Stop intercepting media keys so system HUDs can appear
            // This ensures volume/brightness indicators show when notch is hidden
            MediaKeyInterceptor.shared.stop()
            
            // Disable hit testing when hidden
            for window in notchWindows.values {
                window.ignoresMouseEvents = true
            }
            stopMonitors()
            startHiddenRightClickMonitor()  // Start listening for right-click to re-show
        } else {
            stopHiddenRightClickMonitor()  // Stop listening for right-click
            
            // Restart media key interceptor if HUD replacement is enabled
            let hudEnabled = (UserDefaults.standard.object(forKey: "enableHUDReplacement") as? Bool) ?? true
            if hudEnabled {
                MediaKeyInterceptor.shared.start()
            }
            
            // Enable hit testing when shown
            for window in notchWindows.values {
                window.ignoresMouseEvents = false
            }
            startMonitors()
        }
    }
    
    /// Starts monitoring for right-click events when the notch is hidden
    /// Right-click in the notch area will re-show it
    private func startHiddenRightClickMonitor() {
        guard hiddenRightClickMonitor == nil else { return }
        
        hiddenRightClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self = self, self.isTemporarilyHidden else { return }
            
            // Issue #57 Fix: Use NSEvent.mouseLocation for screen coordinates
            // Global monitors receive event.locationInWindow in source window's coordinate space, not screen space
            let clickLocation = NSEvent.mouseLocation
            
            // Check if click is in any notch window's original frame area
            for (displayID, _) in self.notchWindows {
                guard let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else { continue }
                
                // Get the notch area at the top center of the screen
                let screenFrame = screen.frame
                let notchWidth: CGFloat = 450  // Approximate notch/island width
                let notchHeight: CGFloat = 60  // Approximate notch/island height
                let centerX = screen.notchAlignedCenterX
                let notchArea = CGRect(
                    x: centerX - notchWidth / 2,
                    y: screenFrame.maxY - notchHeight,
                    width: notchWidth,
                    height: notchHeight
                )
                
                if notchArea.contains(clickLocation) {
                    // Right-click in notch area - re-show the notch/island
                    DispatchQueue.main.async {
                        self.setTemporarilyHidden(false)
                    }
                    return
                }
            }
        }
    }
    
    /// Stops the right-click monitor when notch is shown
    private func stopHiddenRightClickMonitor() {
        if let monitor = hiddenRightClickMonitor {
            NSEvent.removeMonitor(monitor)
            hiddenRightClickMonitor = nil
        }
    }
    
    /// Returns the current display mode label for menu (Notch vs Dynamic Island)
    var displayModeLabel: String {
        // Check if any connected screen has a notch using auxiliary areas (stable on lock screen)
        let screen = NSScreen.builtInWithNotch
        let hasNotch = screen?.auxiliaryTopLeftArea != nil && screen?.auxiliaryTopRightArea != nil
        let useDynamicIsland = (UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool) ?? true
        
        if hasNotch && !useDynamicIsland {
            return "Notch"
        } else {
            return "Dynamic Island"
        }
    }
    
    /// Repositions notch windows when screen configuration changes (dock/undock, resolution)
    /// Also adds/removes windows for screens based on current settings
    /// NOTE: Resolution changes require recreating windows because SwiftUI caches the targetScreen reference
    private func repositionNotchWindow() {
        let hideOnExternal = UserDefaults.standard.bool(forKey: "hideNotchOnExternalDisplays")
        let connectedDisplayIDs = Set(NSScreen.screens.map { $0.displayID })
        
        // Remove windows for disconnected screens
        for displayID in notchWindows.keys {
            if !connectedDisplayIDs.contains(displayID) {
                if let window = notchWindows.removeValue(forKey: displayID) {
                    window.isValid = false
                    window.close()
                }
            }
        }
        
        // Add/remove/recreate windows for connected screens
        for screen in NSScreen.screens {
            let displayID = screen.displayID
            let shouldHaveWindow = shouldShowOnScreen(screen, hideOnExternal: hideOnExternal)
            
            if shouldHaveWindow {
                if let existingWindow = notchWindows[displayID] {
                    // RESOLUTION CHANGE FIX: Check if screen horizontal center changed
                    // Only check X position since height is dynamically managed based on content
                    let windowWidth = self.currentInteractionWindowWidth()
                    let expectedCenterX = effectiveShelfCenterX(for: screen)
                    let currentCenterX = existingWindow.frame.midX
                    
                    // If horizontal center shifted significantly, screen changed - recreate window
                    let horizontalDelta = abs(currentCenterX - expectedCenterX)
                    
                    if horizontalDelta > 50 {  // More than 50 pixels = likely different screen/resolution
                        print("🔄 Screen \(displayID) resolution/position changed - recreating window")
                        existingWindow.isValid = false
                        existingWindow.close()
                        notchWindows.removeValue(forKey: displayID)
                        createWindowForScreen(screen)
                    } else {
                        // Just update X position, keep current height (managed by updateAllWindowsSize)
                        let expectedX = expectedCenterX - (windowWidth / 2)
                        if abs(existingWindow.frame.origin.x - expectedX) > 2 ||
                            abs(existingWindow.frame.width - windowWidth) > 2 {
                            var newFrame = existingWindow.frame
                            newFrame.origin.x = expectedX
                            newFrame.size.width = windowWidth
                            existingWindow.setFrame(newFrame, display: false, animate: false)
                        }
                    }
                } else {
                    // Create new window for this screen
                    createWindowForScreen(screen)
                }
            } else {
                // Remove window if it shouldn't exist on this screen
                if let window = notchWindows.removeValue(forKey: displayID) {
                    window.isValid = false
                    window.close()
                }
            }
        }
    }

    private func shouldShowOnScreen(_ screen: NSScreen, hideOnExternal: Bool) -> Bool {
        if screen.isBuiltIn {
            return true
        }
        if hideOnExternal {
            return false
        }
        return isExternalDisplayEnabled(screen.displayID)
    }

    private func isExternalDisplayEnabled(_ displayID: CGDirectDisplayID) -> Bool {
        let advancedEnabled = UserDefaults.standard.bool(forKey: AppPreferenceKey.externalDisplayAdvancedVisibilityEnabled)
        guard advancedEnabled else { return true }

        let raw = UserDefaults.standard.string(forKey: AppPreferenceKey.externalDisplayVisibilityRules) ?? PreferenceDefault.externalDisplayVisibilityRules
        guard let data = raw.data(using: .utf8),
              let rules = try? JSONDecoder().decode([String: Bool].self, from: data) else {
            return true
        }
        return rules[String(displayID)] ?? true
    }
    
    /// Starts monitoring mouse events to handle expands/collapses
    private func startMonitors() {
        stopMonitors() // Idempotency
        startWatchdog() // Start self-healing watchdog
        
        // 0. Monitor screen configuration changes (dock/undock, resolution changes)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.repositionNotchWindow()
            }
            .store(in: &cancellables)
        
        // 1. Monitor display mode changes (Notch <-> Dynamic Island)
        // This allows immediate visual refresh when user changes the mode in Settings
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main) // Debounce rapid changes
            .sink { [weak self] _ in
                // Reposition window to apply new Dynamic Island dimensions/position
                self?.repositionNotchWindow()
            }
            .store(in: &cancellables)
        
        // 1. React to DragMonitor changes (using Combine)
        DragMonitor.shared.$isDragging
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAllWindowsMouseEventHandling()
            }
            .store(in: &cancellables)

        // 1b. React to HUD state changes (notification HUD needs mouse events)
        NotificationCenter.default.publisher(for: .hudStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                notchDebugLog("🔔 NotchWindowController: Received hudStateDidChange - updating mouse event handling")
                self?.updateAllWindowsMouseEventHandling()
            }
            .store(in: &cancellables)
        
        // CRITICAL (v7.0.2): Also update when drag LOCATION changes during a drag.
        // This ensures the window ignores events when drag moves BELOW the notch,
        // preventing blocking of bookmarks bar and other UI elements.
        // PERFORMANCE (v10.x): Throttle to 200ms to avoid CPU spike from heavy rect calculations
        DragMonitor.shared.$dragLocation
            .receive(on: DispatchQueue.main)
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                // Only update if actively dragging - no need during idle
                if DragMonitor.shared.isDragging {
                    self?.updateAllWindowsMouseEventHandling()
                }
            }
            .store(in: &cancellables)
            
        // 2. React to DroppyState changes (using Observation)
        // Replaces the polling interactionTimer
        setupStateObservation()
        
        // Start fullscreen loop
        isFullscreenMonitoring = true
        fullscreenMonitorLoop()
        
        // Global monitor catches mouse movement when Droppy is not frontmost
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            guard let self else { return }
            // PERFORMANCE (v10.x): Skip drag events unless already hovering over this display's notch.
            // macOS fires hundreds of leftMouseDragged events per second during drag operations.
            // Processing each one causes 100% CPU. We only care about drags that START on the notch.
            if event.type == .leftMouseDragged {
                let mouseLocation = NSEvent.mouseLocation
                if let (_, screen) = self.findWindowForMouseLocation(mouseLocation) {
                    guard DroppyState.shared.isHovering(for: screen.displayID) else { return }
                } else if !DroppyState.shared.isMouseHovering {
                    return
                }
            }
            
            // DEBUG: Log every 60 events to verify monitor is receiving events after unlock
            struct DebugCounter { static var count = 0 }
            DebugCounter.count += 1
            if DebugCounter.count % 60 == 0 {
                notchDebugLog("🐭 NotchWindowController: globalMouseMonitor received \(DebugCounter.count) events")
            }
            self.handleMouseEvent(event)
        }
        notchDebugLog("✅ NotchWindowController: globalMouseMonitor created: \(globalMouseMonitor != nil)")
        
        // GLOBAL CLICK MONITOR (v5.3) - Ultra-reliable single-click shelf opening
        // This catches clicks even when Droppy isn't focused, enabling instant shelf opening
        // Uses a slightly expanded hit zone to match the hover detection expansion
        // Also handles closing shelf when clicking outside (desktop click to close)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self,
                  // CRITICAL: Use object() ?? true to match @AppStorage defaults
                  (UserDefaults.standard.object(forKey: "enableNotchShelf") as? Bool) ?? true else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            
            // Find the window whose screen contains the mouse
            guard let (targetWindow, targetScreen) = self.findWindowForMouseLocation(mouseLocation) else { return }

            // Use media-aware collapsed hit zone so hover/click behavior matches
            // the visible mini player wings in notch mode (Issue #213).
            let notchRect = targetWindow.collapsedInteractionRect()
            // Create a click-friendly zone: ±10px horizontal expansion, upward to screen top
            let screenTopY = targetScreen.frame.maxY
            let upwardExpansion = max(0, screenTopY - notchRect.maxY)

            let clickZone = NSRect(
                x: notchRect.origin.x - 10,           // 10px expansion on left
                y: notchRect.origin.y,                // Keep bottom edge exact
                width: notchRect.width + 20,          // 10px expansion on each side
                height: notchRect.height + upwardExpansion  // Extend to screen top
            )
            // Calculate expanded shelf area (when shelf is open)
            let isExpandedOnTarget = DroppyState.shared.isExpanded(for: targetScreen.displayID)
            var expandedShelfZone: NSRect = .zero
            if isExpandedOnTarget {
                expandedShelfZone = self.expandedShelfInteractionZone(for: targetScreen)
            }

            // Check if click is in notch zone or expanded shelf zone
            let isInNotchZone = clickZone.contains(mouseLocation)
            let isInExpandedShelfZone = isExpandedOnTarget && expandedShelfZone.contains(mouseLocation)

            if isInNotchZone {
                // ROCK-SOLID: Debounce rapid clicks to prevent toggle storms
                let now = Date()
                guard now.timeIntervalSince(self.lastNotchClickTime) > self.clickDebounceInterval else { return }
                self.lastNotchClickTime = now
                
                // Click on notch zone
                // CRITICAL FIX: When shelf is expanded WITH ITEMS, don't intercept clicks!
                // Let them pass through to SwiftUI item buttons (like the X to delete a file).
                // Only toggle when collapsed OR when expanded but empty.
                let hasItems = !DroppyState.shared.items.isEmpty
                let isExpandedToDoSession = ToDoManager.shared.isShelfListExpanded || ToDoManager.shared.isInteractingWithPopover
                if isExpandedOnTarget && (hasItems || isExpandedToDoSession) {
                    // Shelf is expanded with items - let SwiftUI handle the click
                    return
                }
                DispatchQueue.main.async {
                    let animation = DroppyAnimation.notchState(for: targetScreen)
                    withAnimation(animation) {
                        DroppyState.shared.toggleShelfExpansion(for: targetScreen.displayID)
                    }
                }
            } else if isExpandedOnTarget &&
                        !isInExpandedShelfZone &&
                        !self.hasActiveContextMenu() &&
                        !ToDoManager.shared.isInteractingWithPopover &&
                        !self.hasActivePopoverWindow() {
                DispatchQueue.main.async {
                    self.clearShelfSelectionForOutsideClick()
                }
                // CLICK OUTSIDE TO CLOSE: Shelf is open, click is outside shelf area
                // Don't close if a context menu is active (user is interacting with submenu)
                // Don't close if a To-do popover is active (date/edit interaction)
                // Don't close if auto-collapse is disabled (user wants manual control)
                // CRITICAL: Use object() ?? true to match @AppStorage default for new users
                let autoCollapseEnabled = (UserDefaults.standard.object(forKey: "autoCollapseShelf") as? Bool) ?? true
                guard autoCollapseEnabled else { return }
                
                // DELAYED CLOSE: Wait 150ms to see if a drag operation starts
                // This prevents shelf from closing when user clicks to start dragging a file
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // Check if drag started during the delay - if so, don't close
                    guard !DragMonitor.shared.isDragging else { return }
                    guard !ToDoManager.shared.isInteractingWithPopover else { return }
                    guard !self.hasActivePopoverWindow() else { return }
                    guard DroppyState.shared.isExpanded(for: targetScreen.displayID) else { return }
                    
                    withAnimation(DroppyAnimation.notchState(for: targetScreen)) {
                        DroppyState.shared.expandedDisplayID = nil
                        DroppyState.shared.setHovering(for: targetScreen.displayID, isHovering: false)
                    }
                }
            }
        }
        
        // GLOBAL RIGHT-CLICK MONITOR (Issue #57 Fix) - Enable context menu access in idle state
        // When window has ignoresMouseEvents=true, right-clicks don't reach the SwiftUI view.
        // This monitor catches right-clicks on the notch area and programmatically shows the context menu.
        globalRightClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            guard let self = self,
                  // CRITICAL: Use object() ?? true to match @AppStorage defaults
                  (UserDefaults.standard.object(forKey: "enableNotchShelf") as? Bool) ?? true else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            
            // Find the window whose screen contains the mouse
            guard let (targetWindow, targetScreen) = self.findWindowForMouseLocation(mouseLocation) else { return }
            
            // Use media-aware collapsed hit zone so right-click follows visible surface.
            let notchRect = targetWindow.collapsedInteractionRect()
            let screenTopY = targetScreen.frame.maxY
            let upwardExpansion = max(0, screenTopY - notchRect.maxY)
            
            let clickZone = NSRect(
                x: notchRect.origin.x - 10,
                y: notchRect.origin.y,
                width: notchRect.width + 20,
                height: notchRect.height + upwardExpansion
            )
            
            // Check if right-click is in the notch zone
            if clickZone.contains(mouseLocation) {
                // Only hide if the preference is enabled (default: false)
                let enableRightClickHide = UserDefaults.standard.bool(forKey: AppPreferenceKey.enableRightClickHide)
                guard enableRightClickHide else { return }
                
                // Right-click on notch - temporarily hide it
                DispatchQueue.main.async {
                    self.setTemporarilyHidden(true)
                }
            }
        }
        
        // Local monitor catches movement AND clicks when mouse is over the Notch window
        // Global monitor only catches events from OTHER apps - we need local for our own window
        // Also handles closing shelf when clicking outside the shelf area
        // Issue #63: Include rightMouseDown so right-click works with Bartender installed
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }

            // Handle mouse movement
            if event.type == .mouseMoved {
                self.handleMouseEvent(event)
                return event
            }
            
            // Issue #63: Handle right-click locally for Bartender compatibility
            // When Bartender is installed, it may intercept global right-click events
            // This ensures right-click still works by handling it locally
            if event.type == .rightMouseDown {
                // Only intercept clicks if shelf is enabled
                // CRITICAL: Use object() ?? true to match @AppStorage defaults
                guard (UserDefaults.standard.object(forKey: "enableNotchShelf") as? Bool) ?? true else { return event }
                
                let mouseLocation = NSEvent.mouseLocation
                
                // Find window for this click
                guard let (targetWindow, targetScreen) = self.findWindowForMouseLocation(mouseLocation) else { return event }
                
                let notchRect = targetWindow.collapsedInteractionRect()
                let screenTopY = targetScreen.frame.maxY
                let upwardExpansion = max(0, screenTopY - notchRect.maxY)
                
                let clickZone = NSRect(
                    x: notchRect.origin.x - 10,
                    y: notchRect.origin.y,
                    width: notchRect.width + 20,
                    height: notchRect.height + upwardExpansion
                )
                
                if clickZone.contains(mouseLocation) {
                    // Only hide if the preference is enabled (default: false)
                    let enableRightClickHide = UserDefaults.standard.bool(forKey: AppPreferenceKey.enableRightClickHide)
                    guard enableRightClickHide else { return event }
                    
                    // Right-click on notch - temporarily hide it
                    DispatchQueue.main.async {
                        self.setTemporarilyHidden(true)
                    }
                    return nil // Consume the event
                }
                return event
            }

            // Handle click - single-click shelf toggle and click-outside-to-close
            if event.type == .leftMouseDown {
                guard (UserDefaults.standard.object(forKey: "enableNotchShelf") as? Bool) ?? true else { return event }

                let mouseLocation = NSEvent.mouseLocation
                
                // Find the window whose screen contains the mouse
                guard let (targetWindow, targetScreen) = self.findWindowForMouseLocation(mouseLocation) else { return event }

                let notchRect = targetWindow.collapsedInteractionRect()

                // Notch click zone
                let screenTopY = targetScreen.frame.maxY
                let upwardExpansion = max(0, screenTopY - notchRect.maxY)

                let clickZone = NSRect(
                    x: notchRect.origin.x - 10,
                    y: notchRect.origin.y,
                    width: notchRect.width + 20,
                    height: notchRect.height + upwardExpansion
                )

                // Calculate expanded shelf area
                let isExpandedOnTarget = DroppyState.shared.isExpanded(for: targetScreen.displayID)
                var expandedShelfZone: NSRect = .zero
                if isExpandedOnTarget {
                    expandedShelfZone = self.expandedShelfInteractionZone(for: targetScreen)
                }

                let isInNotchZone = clickZone.contains(mouseLocation)
                let isInExpandedShelfZone = isExpandedOnTarget && expandedShelfZone.contains(mouseLocation)

                // Notification HUD click forwarding (strict to the visible HUD bounds).
                if isNotificationHUDActive(on: targetScreen.displayID),
                   let notifZone = notificationHUDInteractionZone(on: targetScreen),
                   notifZone.contains(mouseLocation) {
                    print("🔔 LocalMonitor: Click detected in notification HUD area - opening source app")
                    DispatchQueue.main.async {
                        NotificationHUDManager.shared.openCurrentNotificationApp()
                    }
                    return nil  // Consume the click
                }

                if isInNotchZone {
                    // ROCK-SOLID: Debounce rapid clicks to prevent toggle storms
                    let now = Date()
                    guard now.timeIntervalSince(self.lastNotchClickTime) > self.clickDebounceInterval else { return event }
                    self.lastNotchClickTime = now

                    // Click on notch zone
                    // CRITICAL FIX: When shelf is expanded WITH ITEMS, don't intercept clicks!
                    // Let them pass through to SwiftUI item buttons (like the X to delete a file).
                    let hasItems = !DroppyState.shared.items.isEmpty
                    let isExpandedToDoSession = ToDoManager.shared.isShelfListExpanded || ToDoManager.shared.isInteractingWithPopover
                    if isExpandedOnTarget && (hasItems || isExpandedToDoSession) {
                        // Shelf is expanded with items - let SwiftUI handle the click
                        return event
                    }
                    DispatchQueue.main.async {
                        let animation = DroppyAnimation.notchState(for: targetScreen)
                        withAnimation(animation) {
                            DroppyState.shared.toggleShelfExpansion(for: targetScreen.displayID)
                        }
                    }
                    return nil  // Consume the click event
                } else if isExpandedOnTarget &&
                            !isInExpandedShelfZone &&
                            !self.hasActiveContextMenu() &&
                            !ToDoManager.shared.isInteractingWithPopover &&
                            !self.hasActivePopoverWindow() {
                    DispatchQueue.main.async {
                        self.clearShelfSelectionForOutsideClick()
                    }
                    // CLICK OUTSIDE TO CLOSE: Click is outside the shelf area
                    // Don't close if a context menu is active
                    // Don't close if a To-do popover is active (date/edit interaction)
                    // Don't close if auto-collapse is disabled (user wants manual control)
                    // CRITICAL: Use object() ?? true to match @AppStorage default for new users
                    let autoCollapseEnabled = (UserDefaults.standard.object(forKey: "autoCollapseShelf") as? Bool) ?? true
                    guard autoCollapseEnabled else { return event }
                    
                    // DELAYED CLOSE: Wait 150ms to see if a drag operation starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        // Check if drag started during the delay - if so, don't close
                        guard !DragMonitor.shared.isDragging else { return }
                        guard !ToDoManager.shared.isInteractingWithPopover else { return }
                        guard !self.hasActivePopoverWindow() else { return }
                        guard DroppyState.shared.isExpanded(for: targetScreen.displayID) else { return }
                        
                        withAnimation(DroppyAnimation.notchState(for: targetScreen)) {
                            DroppyState.shared.expandedDisplayID = nil
                            DroppyState.shared.setHovering(for: targetScreen.displayID, isHovering: false)
                        }
                    }
                }
            }

            return event
        }
        
        // Keyboard monitor for spacebar Quick Look preview and Cmd+A select all
        // Local monitor - catches events when shelf is key window
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Route To-do timeline up/down navigation through AppKit monitor for
            // consistent behavior without requiring SwiftUI focus rings.
            if let self,
               self.handleToDoTimelineArrowNavigation(event: event, modifiers: modifiers, fromGlobalMonitor: false) {
                return nil
            }

            // Only handle when shelf is expanded and has items
            guard DroppyState.shared.isExpanded,
                  !DroppyState.shared.items.isEmpty else {
                return event
            }
            
            // Spacebar triggers Quick Look (skip if rename is active)
            if event.keyCode == 49 {
                guard let self, !self.shouldBlockShelfQuickLookShortcut() else {
                    return event
                }
                QuickLookHelper.shared.previewSelectedShelfItems()
                return nil // Consume the event
            }
            
            // Cmd+A selects all shelf items (but NOT when terminal is visible - let text selection work)
            if event.keyCode == 0, modifiers.contains(.command) {
                guard let self, !self.shouldBlockShelfSelectAllShortcut() else {
                    return event
                }
                self.selectAllShelfItems()
                return nil // Consume the event
            }
            
            return event
        }
        
        // Global keyboard monitor - catches spacebar when shelf is visible but not key window
        // This ensures Quick Look works even when clicking on items briefly loses focus
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if let self {
                _ = self.handleToDoTimelineArrowNavigation(event: event, modifiers: modifiers, fromGlobalMonitor: true)
            }

            // Only handle when shelf is expanded and has items
            guard DroppyState.shared.isExpanded,
                  !DroppyState.shared.items.isEmpty else {
                return
            }
            guard let self else { return }
            
            // Spacebar quick look fallback.
            if event.keyCode == 49 {
                guard NSApp.isActive else { return }
                guard self.isMouseNearExpandedShelfZone() else { return }
                guard !self.shouldBlockShelfQuickLookShortcut() else { return }
                QuickLookHelper.shared.previewSelectedShelfItems()
                return
            }

            // Cmd+A select-all fallback.
            if event.keyCode == 0, modifiers.contains(.command) {
                // Non-activating notch windows can miss local key events.
                // Allow global fallback when cursor is over the shelf OR shelf window is key.
                guard self.isMouseNearExpandedShelfZone() || self.isAnyExpandedShelfWindowKey() else { return }
                guard !self.shouldBlockShelfSelectAllShortcut() else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.selectAllShelfItems()
                }
            }
        }
        
        // EDGE DETECTION TIMER (v7.7.2) - Fallback for when cursor is at screen edge
        // macOS STOPS generating mouseMoved events when cursor hits the absolute screen edge.
        // NSEvent.mouseLocation also may not update, so we use CGEvent to get the raw cursor pos.
        edgeDetectionTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self,
                  !self.notchWindows.isEmpty,
                  // CRITICAL: Use object() ?? true to match @AppStorage defaults
                  (UserDefaults.standard.object(forKey: "enableNotchShelf") as? Bool) ?? true,
                  !DroppyState.shared.isExpanded,  // Don't need edge detection when expanded
                  !DragMonitor.shared.isDragging   // Drag monitor handles its own detection
            else { return }
            
            // Get cursor position - prefer CGEvent (works at screen edge), fallback to NSEvent
            // CGEvent can fail without Accessibility permissions, so we need a fallback
            let nsMouseLocation: NSPoint
            if let cgEvent = CGEvent(source: nil) {
                let cgPoint = cgEvent.location
                // Convert CG coordinates (origin top-left of main screen) to NS coordinates (origin bottom-left)
                // CG Y: 0 at top, increases downward
                // NS Y: 0 at bottom, increases upward  
                guard let mainScreen = NSScreen.screens.first else { return }
                nsMouseLocation = NSPoint(x: cgPoint.x, y: mainScreen.frame.maxY - cgPoint.y)
            } else {
                // Fallback: NSEvent.mouseLocation works without permissions but may miss screen edges
                nsMouseLocation = NSEvent.mouseLocation
            }
            
            // Check each window to see if cursor is at the top edge of its screen
            for window in self.notchWindows.values {
                guard let screen = window.notchScreen else { continue }
                
                // CRITICAL FIX: First check if cursor is actually ON this screen
                // This prevents the "activation lane" bug where the cursor coordinates
                // incorrectly match another screen's top edge
                // NOTE: Use a tolerant check because NSRect.contains() excludes the boundary:
                // When cursor is at absolute top edge (y == maxY), frame.contains() returns false.
                // We add a small tolerance to catch edge positions.
                let extendedFrame = NSRect(
                    x: screen.frame.origin.x,
                    y: screen.frame.origin.y,
                    width: screen.frame.width,
                    height: screen.frame.height + 5  // +5px to include absolute top edge
                )
                guard extendedFrame.contains(nsMouseLocation) else { continue }
                
                // Check if cursor is at the top of THIS specific screen
                let screenTop = screen.frame.maxY
                let isAtScreenTop = nsMouseLocation.y >= screenTop - 10  // Within 10px of screen top
                
                guard isAtScreenTop else { continue }
                
                // Check if cursor is within the notch X range
                let notchRect = window.collapsedInteractionRect()
                let isWithinNotchX = window.isWithinTopEdgeHoverBand(
                    x: nsMouseLocation.x,
                    on: screen,
                    notchRect: notchRect,
                    extraPadding: 10
                )
                
                if isWithinNotchX && !DroppyState.shared.isHovering(for: screen.displayID) {
                    // Cursor is at top edge of this screen within notch range - trigger hover!
                    let displayID = screen.displayID  // Capture for async block
                    DispatchQueue.main.async { [weak self] in
                        DroppyState.shared.validateItems()
                        withAnimation(DroppyAnimation.hoverBouncy(for: screen)) {
                            DroppyState.shared.setHovering(for: displayID, isHovering: true)
                        }
                        // Start auto-expand timer with screen context
                        self?.startAutoExpandTimer(for: displayID)
                    }
                    break  // Found a match, no need to check other windows
                }
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        edgeDetectionTimer = timer
        
        // SCROLL WHEEL MONITOR - Detect 2-finger horizontal swipe for media HUD toggle
        // Swipe left = show media HUD, Swipe right = hide media HUD
        // Global monitor catches events from other apps
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
        }
        
        // Local monitor catches events over Droppy's own window
        localScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
            return event  // Pass event through
        }
    }

    /// Returns true while an editable text responder is active (e.g. rename popover text field).
    private func isTextInputResponderActive() -> Bool {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else {
            return false
        }
        return textView.isEditable
    }

    private func shouldBlockShelfQuickLookShortcut() -> Bool {
        DroppyState.shared.isRenaming || isTextInputResponderActive()
    }

    private func shouldBlockShelfSelectAllShortcut() -> Bool {
        (TerminalNotchManager.shared.isInstalled && TerminalNotchManager.shared.isVisible) ||
        DroppyState.shared.isRenaming ||
        isTextInputResponderActive()
    }

    private func handleToDoTimelineArrowNavigation(
        event: NSEvent,
        modifiers: NSEvent.ModifierFlags,
        fromGlobalMonitor: Bool
    ) -> Bool {
        guard event.keyCode == 125 || event.keyCode == 126 else { return false }
        guard modifiers.isEmpty else { return false }
        guard DroppyState.shared.isExpanded else { return false }
        guard ToDoManager.shared.isShelfListExpanded else { return false }
        guard !ToDoManager.shared.isInteractingWithPopover else { return false }
        guard !ToDoManager.shared.isEditingText else { return false }
        guard !isTextInputResponderActive() else { return false }

        if fromGlobalMonitor {
            guard NSApp.isActive else { return false }
            guard !isAnyExpandedShelfWindowKey() else { return false }
            guard isMouseNearExpandedShelfZone() else { return false }
        }

        let step = event.keyCode == 125 ? 1 : -1
        NotificationCenter.default.post(
            name: .todoShelfNavigateTimeline,
            object: nil,
            userInfo: ["step": step]
        )
        return true
    }

    private func selectAllShelfItems() {
        DroppyState.shared.selectAll()
    }

    private func isMouseNearExpandedShelfZone() -> Bool {
        let mouseLocation = NSEvent.mouseLocation
        guard let expandedDisplayID = DroppyState.shared.expandedDisplayID,
              let expandedScreen = NSScreen.screens.first(where: { $0.displayID == expandedDisplayID }) else {
            return false
        }
        let shelfZone = expandedShelfInteractionZone(
            for: expandedScreen,
            horizontalPadding: 20,
            verticalPadding: 20
        )
        return shelfZone.contains(mouseLocation)
    }

    private func isAnyExpandedShelfWindowKey() -> Bool {
        guard let expandedDisplayID = DroppyState.shared.expandedDisplayID else { return false }
        return notchWindows[expandedDisplayID]?.isKeyWindow == true
    }

    private func clearShelfSelectionForOutsideClick() {
        if !DroppyState.shared.selectedItems.isEmpty {
            DroppyState.shared.deselectAll()
        }
        if DroppyState.shared.isRenaming {
            DroppyState.shared.isRenaming = false
            DroppyState.shared.endFileOperation()
        }
    }
    
    private func fullscreenMonitorLoop() {
        guard isFullscreenMonitoring else { return }
        
        if let window = self.notchWindow, window.isValid {
            self.checkFullscreenState()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.fullscreenMonitorLoop()
        }
    }
    
    /// Sets up observation for DroppyState properties
    private func setupStateObservation() {
        // Don't set up observation when hidden - prevents unnecessary updates
        guard !isTemporarilyHidden else { return }
        
        // Track the specific properties that affect mouse event handling
        withObservationTracking {
            _ = DroppyState.shared.isExpanded
            _ = DroppyState.shared.hoveringDisplayID
            _ = DroppyState.shared.isDropTargeted
            _ = DroppyState.shared.items.count  // Track item count for dynamic window sizing
            _ = DroppyState.shared.shelfDisplaySlotCount  // Track row growth changes immediately
            // Track To-do shelf bar expansion drivers so window height updates immediately.
            _ = ToDoManager.shared.isShelfListExpanded
            _ = ToDoManager.shared.items.count
            _ = ToDoManager.shared.showUndoToast
        } onChange: {
            // onChange fires BEFORE the property changes.
            // dispatch async to run update AFTER the change is applied.
            DispatchQueue.main.async { [weak self] in
                // Skip if hidden - prevents stale events and observation buildup
                guard let self = self, !self.isTemporarilyHidden else { return }
                
                self.updateAllWindowsMouseEventHandling()
                
                // CONSTRAINT CASCADE SAFETY: Skip window resize while a drag session is active.
                // During drag, DispatchQueue.main.async runs inside AppKit's nested drag run loop.
                // Calling window.setFrame() there triggers NSDisplayCycleFlush →
                // _willUpdateConstraintsForSubtree → setConstant: → constraintsDidChangeInEngine: →
                // _postWindowNeedsUpdateConstraints re-entrantly → crash.
                // Guard on BOTH flags:
                // - isDropTargeted can be false for parts of an active drag gesture
                // - DragMonitor.isDragging stays true for the full drag lifecycle
                // This ensures we never resize inside AppKit's drag loop.
                if !DroppyState.shared.isDropTargeted && !DragMonitor.shared.isDragging {
                    self.updateAllWindowsSize()
                }
                
                // Must re-register observation after it fires (one-shot)
                self.setupStateObservation()
            }
        }
    }
    
    /// Dynamically resizes all notch windows to fit current shelf content
    /// ROCK-SOLID: Multi-layer protection against size reversion
    /// Layer 1: Throttle rapid updates → Layer 2: Expected size cache
    /// Layer 3: Coalesced deferred updates → Layer 4: Frame application
    /// Layer 5: Immediate validation → Watchdog backup
    private func updateAllWindowsSize() {
        for (displayID, _) in notchWindows {
            scheduleSizeUpdate(for: displayID)
        }
    }
    
    /// Schedules a size update for a specific window with throttling and coalescing
    private func scheduleSizeUpdate(for displayID: CGDirectDisplayID) {
        // Cancel any pending update for this display
        pendingSizeUpdates[displayID]?.cancel()
        
        // Calculate the correct size NOW and cache it immediately
        // This ensures we capture the state at this exact moment
        guard let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else { return }
        let correctHeight = calculateCorrectWindowHeight(for: screen)
        
        // LAYER 1: Cache the expected size IMMEDIATELY (before any async operations)
        // This is the absolute source of truth that the watchdog will enforce
        expectedWindowSizes[displayID] = correctHeight
        
        // LAYER 2: Throttle check - only apply immediately if enough time has passed
        let now = Date()
        let timeSinceLastUpdate = lastSizeUpdateTime[displayID].map { now.timeIntervalSince($0) } ?? .infinity
        
        if timeSinceLastUpdate >= sizeUpdateThrottle {
            // Enough time has passed - apply immediately
            applySizeUpdate(for: displayID, height: correctHeight)
        } else {
            // LAYER 3: Coalesce with deferred update
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                // Re-read the expected size (may have been updated again)
                guard let finalHeight = self.expectedWindowSizes[displayID] else { return }
                self.applySizeUpdate(for: displayID, height: finalHeight)
            }
            pendingSizeUpdates[displayID] = workItem
            
            let delay = sizeUpdateThrottle - timeSinceLastUpdate
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
    
    /// Calculates the correct window height for a screen (pure calculation, no side effects)
    private func calculateCorrectWindowHeight(for screen: NSScreen) -> CGFloat {
        let requiredHeight = DroppyState.expandedShelfHeight(for: screen)
        let minWindowHeight: CGFloat = 280
        return max(minWindowHeight, requiredHeight)
    }
    
    /// Applies a size update to a window (the actual frame change)
    /// LAYER 4: Frame application + LAYER 5: Immediate validation
    private func applySizeUpdate(for displayID: CGDirectDisplayID, height newHeight: CGFloat) {
        guard let window = notchWindows[displayID],
              let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else { return }
        
        // Update timestamp
        lastSizeUpdateTime[displayID] = Date()
        let expectedWidth = currentInteractionWindowWidth()
        let expectedX = effectiveShelfCenterX(for: screen) - (expectedWidth / 2)
        
        // Only resize if significantly different (avoid micro-updates)
        // Keep this coarse to prevent update-constraints feedback loops.
        let currentHeight = window.frame.height
        let currentX = window.frame.origin.x
        let currentWidth = window.frame.width
        let needsHeightUpdate = abs(newHeight - currentHeight) > 10
        let needsXUpdate = abs(expectedX - currentX) > horizontalRecenterTolerance
        let needsWidthUpdate = abs(expectedWidth - currentWidth) > 2
        if needsHeightUpdate || needsXUpdate || needsWidthUpdate {
            // Resize from top - keep window anchored at screen top
            let newFrame = NSRect(
                x: expectedX,
                y: screen.frame.origin.y + screen.frame.height - newHeight,
                width: expectedWidth,
                height: newHeight
            )
            window.setFrame(newFrame, display: false, animate: false)
            window.setFrameTopLeftPoint(NSPoint(x: expectedX, y: screen.frame.maxY))
            
            // LAYER 5: Immediate validation - verify the frame was applied correctly
            DispatchQueue.main.async { [weak self] in
                self?.validateSizeForWindow(displayID: displayID)
            }
        }
    }
    
    /// Validates that a window matches its expected size, self-heals if not
    private func validateSizeForWindow(displayID: CGDirectDisplayID) {
        guard let window = notchWindows[displayID],
              let expectedHeight = expectedWindowSizes[displayID],
              let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else { return }
        
        let currentHeight = window.frame.height
        let deviation = abs(currentHeight - expectedHeight)
        let expectedWidth = currentInteractionWindowWidth()
        let expectedX = effectiveShelfCenterX(for: screen) - (expectedWidth / 2)
        let xDeviation = abs(window.frame.origin.x - expectedX)
        let widthDeviation = abs(window.frame.width - expectedWidth)
        
        if deviation > sizeDeviationTolerance || xDeviation > horizontalRecenterTolerance || widthDeviation > 2 {
            // Size doesn't match - force correct it NOW
            let newFrame = NSRect(
                x: expectedX,
                y: screen.frame.origin.y + screen.frame.height - expectedHeight,
                width: expectedWidth,
                height: expectedHeight
            )
            window.setFrame(newFrame, display: false, animate: false)
            window.setFrameTopLeftPoint(NSPoint(x: expectedX, y: screen.frame.maxY))
        }
    }
    
    /// Forces an immediate size recalculation and application for all windows
    /// Call this any time you need guaranteed correct sizing
    func forceRecalculateAllWindowSizes() {
        for displayID in notchWindows.keys {
            guard let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else { continue }
            let correctHeight = calculateCorrectWindowHeight(for: screen)
            expectedWindowSizes[displayID] = correctHeight
            applySizeUpdate(for: displayID, height: correctHeight)
        }
    }

    /// Requests size recalculation using the controller's built-in throttling/coalescing path.
    /// Prefer this for high-frequency UI updates to keep interaction smooth.
    func recalculateAllWindowSizesCoalesced() {
        updateAllWindowsSize()
    }

    
    /// Updates mouse event handling for all notch windows
    /// CRITICAL: Skips update if windows are temporarily hidden to prevent
    /// stale state observers from re-enabling mouse events
    private func updateAllWindowsMouseEventHandling() {
        // Don't update if hidden - preserves ignoresMouseEvents = true state
        guard !isTemporarilyHidden else { return }
        
        for window in notchWindows.values {
            window.updateMouseEventHandling()
        }
    }
    
    /// Finds the notch window for the screen containing the given mouse location
    /// Returns nil if no window exists for that screen
    private func findWindowForMouseLocation(_ mouseLocation: NSPoint) -> (window: NotchWindow, screen: NSScreen)? {
        // Find which screen contains the mouse
        // NOTE: Use tolerant frame check because NSRect.contains() excludes the boundary.
        // When cursor is at absolute top edge (y == maxY), frame.contains() returns false.
        for screen in NSScreen.screens {
            // Create extended frame to catch cursor at screen edges
            let extendedFrame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y,
                width: screen.frame.width,
                height: screen.frame.height + 5  // +5px to include absolute top edge
            )
            if extendedFrame.contains(mouseLocation) {
                // Check if we have a window for this screen
                if let window = notchWindows[screen.displayID] {
                    return (window, screen)
                }
            }
        }
        return nil
    }    
    /// Stops and releases all monitors and timers
    private func stopMonitors() {
        stopWatchdog() // Stop self-healing watchdog
        cancellables.removeAll()
        
        isFullscreenMonitoring = false
        
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        
        if let monitor = globalKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyboardMonitor = nil
        }
        
        edgeDetectionTimer?.invalidate()
        edgeDetectionTimer = nil
        
        cancelAutoExpandTimer()
        
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        
        if let monitor = localScrollMonitor {
            NSEvent.removeMonitor(monitor)
            localScrollMonitor = nil
        }
        
        if let monitor = globalRightClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalRightClickMonitor = nil
        }
    }
    
    // MARK: - Professional Self-Healing System
    
    /// Sets up system observers for wake/display changes that can break monitors
    private func setupSystemObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        let center = NotificationCenter.default
        
        // Wake from sleep - monitors may need re-registration
        let wakeObserver = workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 NotchWindowController: System woke from sleep - validating monitors")
            self?.handleSystemTransition()
        }
        systemObservers.append(wakeObserver)
        
        // Session became active (screen unlocked) - CRITICAL for event monitors
        // After unlock, NSEvent monitors may stop receiving events
        let unlockObserver = workspace.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔓 NotchWindowController: Screen unlocked - force re-registering monitors")
            // DELAYED RESET: Wait 1.0s to ensure window server has fully transitioned
            // from lock screen mode and the window is ready for interaction
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.forceReregisterMonitors()
            }
        }
        systemObservers.append(unlockObserver)
        
        // Display configuration change (plug/unplug monitors)
        let displayObserver = center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 NotchWindowController: Display configuration changed - validating monitors")
            // Small delay to let display settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.handleSystemTransition()
            }
        }
        systemObservers.append(displayObserver)
        
        // Space change detection (KEY for fullscreen detection!)
        // This fires whenever user enters or exits a fullscreen Space
        let spaceObserver = workspace.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Immediately check fullscreen state when space changes
            self?.checkFullscreenState()
        }
        systemObservers.append(spaceObserver)
        
        // Screen lock detection - re-delegate windows to SkyLight for lock screen visibility
        // This is needed because we destroy and recreate windows on unlock to fix the zombie issue
        // The fresh windows need to be re-delegated before they're shown on the lock screen
        let lockObserver = workspace.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Check if lock screen setting is enabled
            let lockScreenEnabled = UserDefaults.standard.preference(
                AppPreferenceKey.enableLockScreenMediaWidget,
                default: PreferenceDefault.enableLockScreenMediaWidget
            )
            let lockHUDEnabled = UserDefaults.standard.preference(
                AppPreferenceKey.enableLockScreenHUD,
                default: PreferenceDefault.enableLockScreenHUD
            )

            // Lock HUD mode uses its own dedicated lock-screen window surface.
            // Skip delegating the regular notch window to prevent double-surface artifacts.
            if lockScreenEnabled && !lockHUDEnabled {
                print("🔒 NotchWindowController: Screen locking - re-delegating to SkyLight")
                self?.delegateToLockScreen()
            }
        }
        systemObservers.append(lockObserver)
        
        // Dynamic Island height preference change - update window layout immediately
        let islandHeightObserver = center.addObserver(
            forName: NSNotification.Name("DynamicIslandHeightChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📐 NotchWindowController: Island height changed - updating layout")
            self?.repositionNotchWindow()
        }
        systemObservers.append(islandHeightObserver)
    }
    
    /// Forces re-registration of all event monitors
    /// Called after screen unlock when monitors may have become stale
    /// 
    /// CRITICAL FIX (v7.x): SkyLight delegation permanently compromises window event handling.
    /// The only reliable fix is to destroy the delegated windows and create fresh ones.
    /// Fresh windows are NOT delegated to SkyLight (desktop-only). They will be re-delegated
    /// on the next lock event if the lock screen setting is enabled.
    private func forceReregisterMonitors() {
        print("🔄 NotchWindowController: Force re-registering monitors via WINDOW RECREATION")
        
        // 1. Stop all monitors first
        stopMonitors()
        
        // 2. Check if we have SkyLight-delegated windows (built-in display only)
        // If the lock screen setting is enabled, the built-in window was delegated to SkyLight
        // and is now "zombified" for desktop interaction. We must recreate it.
        let lockScreenEnabled = UserDefaults.standard.preference(
            AppPreferenceKey.enableLockScreenMediaWidget,
            default: PreferenceDefault.enableLockScreenMediaWidget
        )
        let lockHUDEnabled = UserDefaults.standard.preference(
            AppPreferenceKey.enableLockScreenHUD,
            default: PreferenceDefault.enableLockScreenHUD
        )
        
        if lockScreenEnabled && !lockHUDEnabled {
            // WINDOW RECREATION: Destroy and rebuild all windows
            // This is the only way to "undelegaDe" from SkyLight
            print("🔥 NotchWindowController: Destroying SkyLight-delegated windows...")
            
            // Close and remove all existing windows
            for window in notchWindows.values {
                window.isValid = false
                window.close()
            }
            notchWindows.removeAll()
            
            // Temporarily disable lock screen delegation during recreation
            // We set a flag that createWindowForScreen will check
            isRecreatingWindowsAfterUnlock = true
            
            // Recreate windows (repositionNotchWindow calls createWindowForScreen)
            repositionNotchWindow()
            
            // Clear the flag
            isRecreatingWindowsAfterUnlock = false
            
            print("✅ NotchWindowController: Fresh windows created (not delegated to SkyLight)")
        } else {
            // Lock screen not enabled, just reset window state normally
            for window in notchWindows.values {
                window.level = .init(Int(CGShieldingWindowLevel()) + 2)
                window.ignoresMouseEvents = true
                window.ignoresMouseEvents = false
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
                window.updateMouseEventHandling()
            }
        }
        
        // 3. Restart monitors with fresh/reset windows
        startMonitors()
        
        // 4. Validate final state
        for window in notchWindows.values {
            window.updateMouseEventHandling()
        }
        
        // 5. Fallback retry if global monitor failed
        if globalMouseMonitor == nil {
            print("⚠️ NotchWindowController: Global monitor failed to start! Retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startMonitors()
            }
        }
    }
    
    /// Removes all system observers
    private func removeSystemObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        let center = NotificationCenter.default
        
        for observer in systemObservers {
            workspace.removeObserver(observer)
            center.removeObserver(observer)
        }
        systemObservers.removeAll()
    }
    
    /// Handles system transitions (wake, display change) by re-validating state
    private func handleSystemTransition() {
        // Skip if intentionally hidden
        guard !isTemporarilyHidden else { return }
        
        // Force re-validation of all window states
        for window in notchWindows.values {
            window.ignoresMouseEvents = false  // Reset to interactive
            window.updateMouseEventHandling()  // Re-apply correct state
        }
        
        // Re-register monitors if needed
        if !isFullscreenMonitoring && !notchWindows.isEmpty {
            stopMonitors()
            startMonitors()
        }
    }
    
    /// Starts the watchdog timer for self-healing (called when monitors start)
    private func startWatchdog() {
        stopWatchdog()  // Ensure no duplicate timers
        
        // Run every 5 seconds - cheap check, guaranteed recovery
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.validateWindowState()
        }
    }
    
    /// Stops the watchdog timer
    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }
    
    /// Validates and self-heals window state if stuck
    /// Called periodically by watchdog timer
    /// ROCK-SOLID: Also validates window sizes as final safety net
    private static var lastWatchdogLogTime: Date?
    private static var lastSizeHealLogTime: Date?
    private func validateWindowState() {
        // Skip if intentionally hidden
        guard !isTemporarilyHidden else { return }
        
        // Check if any window is incorrectly ignoring mouse events
        let enableNotchShelf = (UserDefaults.standard.object(forKey: "enableNotchShelf") as? Bool) ?? true
        
        for (displayID, window) in notchWindows {
            // MOUSE EVENT VALIDATION
            // Check if window is ignoring events when it shouldn't be
            if window.ignoresMouseEvents {
                let isExpanded = DroppyState.shared.isExpanded(for: displayID)
                let isHovering = DroppyState.shared.isHovering(for: displayID)
                let isNotificationHUDActiveOnDisplay = isNotificationHUDActive(on: displayID)

                // Window SHOULD accept events when:
                // 1. Shelf is expanded or hovering (and shelf is enabled)
                // 2. Cursor is inside the visible NotificationHUD hit zone
                let shelfNeedsEvents = enableNotchShelf && (isExpanded || isHovering)
                let hudNeedsEvents: Bool = {
                    guard isNotificationHUDActiveOnDisplay,
                          let screen = NSScreen.screens.first(where: { $0.displayID == displayID }),
                          let notificationZone = notificationHUDInteractionZone(on: screen) else {
                        return false
                    }
                    return notificationZone.contains(NSEvent.mouseLocation)
                }()

                if shelfNeedsEvents || hudNeedsEvents {
                    // Throttle log to once per minute to avoid console spam
                    let now = Date()
                    if Self.lastWatchdogLogTime.map({ now.timeIntervalSince($0) > 60 }) ?? true {
                        let reason = hudNeedsEvents ? "NotificationHUD hit zone" : "shelf expanded/hovering"
                        print("⚠️ Watchdog: Self-healing - window stuck with ignoresMouseEvents=true (\(reason))")
                        Self.lastWatchdogLogTime = now
                    }
                    window.ignoresMouseEvents = false
                    window.updateMouseEventHandling()
                }
            }
            
            // SIZE STABILITY VALIDATION (Rock-Solid Final Safety Net)
            // Verify window matches expected size, self-heal if drifted
            guard let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) else { continue }
            
            // Calculate what the size SHOULD be right now
            let correctHeight = calculateCorrectWindowHeight(for: screen)
            
            // Update expected size if not set or if it's stale
            if expectedWindowSizes[displayID] == nil {
                expectedWindowSizes[displayID] = correctHeight
            }
            
            let currentHeight = window.frame.height
            let deviation = abs(currentHeight - correctHeight)
            
            // If size has drifted more than tolerance, force-correct it
            if deviation > sizeDeviationTolerance {
                // Throttle log to once per minute per display
                let now = Date()
                if Self.lastSizeHealLogTime.map({ now.timeIntervalSince($0) > 60 }) ?? true {
                    print("⚠️ Watchdog: Self-healing - window size drifted by \(Int(deviation))pt (expected: \(Int(correctHeight)), actual: \(Int(currentHeight)))")
                    Self.lastSizeHealLogTime = now
                }
                
                // Update cache and force-apply correct size
                expectedWindowSizes[displayID] = correctHeight
                let newFrame = NSRect(
                    x: window.frame.origin.x,
                    y: screen.frame.origin.y + screen.frame.height - correctHeight,
                    width: window.frame.width,
                    height: correctHeight
                )
                window.setFrame(newFrame, display: false, animate: false)
                window.setFrameTopLeftPoint(NSPoint(x: window.frame.origin.x, y: screen.frame.maxY))
            }
        }
    }
    
    
    private func checkFullscreenState() {
        // Check if auto-hide is enabled
        let autoHideEnabled = (UserDefaults.standard.object(forKey: AppPreferenceKey.autoHideOnFullscreen) as? Bool) ?? PreferenceDefault.autoHideOnFullscreen
        
        // Track which displays are in fullscreen this check
        var currentFullscreenDisplays: Set<CGDirectDisplayID> = []
        
        // Check each notch window's screen for fullscreen
        for (displayID, window) in notchWindows {
            let isFullscreenOnThisDisplay = window.checkForFullscreenAndReturn()
            
            if autoHideEnabled && isFullscreenOnThisDisplay {
                currentFullscreenDisplays.insert(displayID)
            }
        }
        
        // Process per-display fullscreen state with hysteresis
        var updatedFullscreenDisplays = fullscreenDisplayIDs
        
        for (displayID, _) in notchWindows {
            let isDetectedFullscreen = currentFullscreenDisplays.contains(displayID)
            let wasTrackedFullscreen = fullscreenDisplayIDs.contains(displayID)
            
            if isDetectedFullscreen {
                // Immediately enter fullscreen for this display, reset debounce
                fullscreenExitDebounceCounts[displayID] = 0
                if !wasTrackedFullscreen {
                    updatedFullscreenDisplays.insert(displayID)
                }
            } else {
                // Not detecting fullscreen on this display
                if wasTrackedFullscreen {
                    // Apply hysteresis - require multiple consecutive non-fullscreen detections
                    let currentCount = (fullscreenExitDebounceCounts[displayID] ?? 0) + 1
                    fullscreenExitDebounceCounts[displayID] = currentCount
                    
                    if currentCount >= fullscreenExitDebounceThreshold {
                        // Stable non-fullscreen - safe to exit for this display
                        updatedFullscreenDisplays.remove(displayID)
                        fullscreenExitDebounceCounts[displayID] = 0
                        // BUG #133 FIX: Also clear hover-reveal state
                        fullscreenHoverRevealedDisplays.remove(displayID)
                    }
                    // Otherwise, keep display in fullscreen set until debounce threshold reached
                }
            }
        }
        
        // Update published properties on main thread if changed
        if updatedFullscreenDisplays != fullscreenDisplayIDs {
            DispatchQueue.main.async { [weak self] in
                self?.fullscreenDisplayIDs = updatedFullscreenDisplays
                // Also update legacy global flag for any code still using it
                self?.isFullscreen = !updatedFullscreenDisplays.isEmpty
            }
        }
    }
    
    /// Start timer to auto-expand shelf if hovering persists
    /// - Parameter displayID: The display to expand when timer fires (optional for backwards compat)
    func startAutoExpandTimer(for displayID: CGDirectDisplayID? = nil) {
        // DEBUG: Log when timer is started
        notchDebugLog("🟢 startAutoExpandTimer CALLED for displayID: \(displayID?.description ?? "nil")")
        
        cancelAutoExpandTimer() // Reset if already running
        let skipHighAlertHoverHUD = UserDefaults.standard.preference(
            AppPreferenceKey.caffeineInstantlyExpandShelfOnHover,
            default: PreferenceDefault.caffeineInstantlyExpandShelfOnHover
        )

        // High Alert override: by default, active High Alert blocks hover auto-expand.
        // Users can opt out via High Alert settings to expand shelf directly on hover.
        guard !CaffeineManager.shared.isActive || skipHighAlertHoverHUD else {
            HapticFeedback.hover()
            notchDebugLog("⏰ AUTO-EXPAND BLOCKED: High Alert is active")
            return
        }
        
        // CRITICAL: Use object() ?? true to match @AppStorage default for new users
        guard (UserDefaults.standard.object(forKey: "autoExpandShelf") as? Bool) ?? true else { return }

        // Display-specific hover toggles.
        if let displayID = displayID,
           let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
            if screen.isBuiltIn {
                let allowMainMacAutoExpand = (UserDefaults.standard.object(forKey: AppPreferenceKey.autoExpandOnMainMac) as? Bool)
                    ?? PreferenceDefault.autoExpandOnMainMac
                guard allowMainMacAutoExpand else { return }
            } else {
                let allowExternalAutoExpand = (UserDefaults.standard.object(forKey: AppPreferenceKey.autoExpandOnExternalDisplays) as? Bool)
                    ?? PreferenceDefault.autoExpandOnExternalDisplays
                guard allowExternalAutoExpand else { return }
            }
        }
        
        // Use configurable delay (0.5-2.0 seconds, default 1.0s)
        let delay = UserDefaults.standard.double(forKey: "autoExpandDelay")
        let actualDelay = delay > 0 ? delay : 1.0  // Fallback to 1.0s if not set
        notchDebugLog("🟢 AUTO-EXPAND TIMER STARTED with delay: \(actualDelay)s for displayID: \(displayID?.description ?? "nil")")
        autoExpandTimer = Timer.scheduledTimer(withTimeInterval: actualDelay, repeats: false) { [weak self] _ in
            guard self != nil else { return }

            // CRITICAL: Don't expand shelf when NotificationHUD is visible
            // User needs to click the notification, not accidentally expand the shelf
            if HUDManager.shared.isNotificationHUDVisible {
                notchDebugLog("⏰ AUTO-EXPAND BLOCKED: NotificationHUD is visible")
                return
            }

            // High Alert can toggle after timer start; re-check before expanding.
            let skipHighAlertHoverHUD = UserDefaults.standard.preference(
                AppPreferenceKey.caffeineInstantlyExpandShelfOnHover,
                default: PreferenceDefault.caffeineInstantlyExpandShelfOnHover
            )
            if CaffeineManager.shared.isActive && !skipHighAlertHoverHUD {
                notchDebugLog("⏰ AUTO-EXPAND BLOCKED (timer fire): High Alert is active")
                return
            }

            // Check setting again (in case user disabled it during the delay)
            // CRITICAL: Use object() ?? true to match @AppStorage default
            guard (UserDefaults.standard.object(forKey: "autoExpandShelf") as? Bool) ?? true else { return }
            let currentMouse = NSEvent.mouseLocation
            if let displayID = displayID,
               let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
                if screen.isBuiltIn {
                    let allowMainMacAutoExpand = (UserDefaults.standard.object(forKey: AppPreferenceKey.autoExpandOnMainMac) as? Bool)
                        ?? PreferenceDefault.autoExpandOnMainMac
                    guard allowMainMacAutoExpand else { return }
                } else {
                    let allowExternalAutoExpand = (UserDefaults.standard.object(forKey: AppPreferenceKey.autoExpandOnExternalDisplays) as? Bool)
                        ?? PreferenceDefault.autoExpandOnExternalDisplays
                    guard allowExternalAutoExpand else { return }
                }
            }
            
            // SKYLIGHT FIX: Recheck actual mouse geometry at timer fire time
            // After SkyLight lock/unlock, the isHovering state can become stale/incorrect.
            // Instead of trusting the state, we directly check if mouse is over the notch zone.
            let isExpanded = displayID.map { DroppyState.shared.isExpanded(for: $0) } ?? DroppyState.shared.isExpanded
            
            // Find the target screen and check if mouse is in notch zone
            var isMouseOverNotchZone = false
            if let targetDisplayID = displayID,
               let targetWindow = self?.notchWindows[targetDisplayID] {
                isMouseOverNotchZone = self?.isMouseInAutoExpandIntentZone(
                    mouseLocation: currentMouse,
                    window: targetWindow
                ) ?? false
            }
            
            // Also check DroppyState as backup
            let stateHovering = displayID.map { DroppyState.shared.isHovering(for: $0) } ?? DroppyState.shared.isMouseHovering
            let shouldExpand = (isMouseOverNotchZone || stateHovering) && !isExpanded
            
            notchDebugLog("⏰ AUTO-EXPAND TIMER FIRED: stateHovering=\(stateHovering), geometryHovering=\(isMouseOverNotchZone), isExpanded=\(isExpanded), shouldExpand=\(shouldExpand), displayID=\(displayID?.description ?? "nil")")
            
            // Expand if EITHER state or geometry says we're hovering
            if shouldExpand {
                let animationScreen = displayID.flatMap { self?.notchWindows[$0]?.notchScreen }
                DispatchQueue.main.async {
                    withAnimation(DroppyAnimation.notchState(for: animationScreen)) {
                        if let displayID = displayID {
                            // Expand on the specific screen
                            notchDebugLog("📤 EXPANDING SHELF for displayID: \(displayID)")
                            DroppyState.shared.expandShelf(for: displayID)
                        } else {
                            // Fallback: Find screen containing mouse and expand that
                            if let screen = NSScreen.screens.first(where: { $0.frame.contains(currentMouse) }) {
                                notchDebugLog("📤 EXPANDING SHELF for fallback displayID: \(screen.displayID)")
                                DroppyState.shared.expandShelf(for: screen.displayID)
                            }
                        }
                    }
                }
            } else {
                notchDebugLog("⏰ AUTO-EXPAND SKIPPED: stateHovering=\(stateHovering), geometryHovering=\(isMouseOverNotchZone), isExpanded=\(isExpanded)")
            }
        }
    }
    
    func cancelAutoExpandTimer() {
        if autoExpandTimer != nil {
            notchDebugLog("🔴 cancelAutoExpandTimer CALLED (timer was active)")
        }
        autoExpandTimer?.invalidate()
        autoExpandTimer = nil
    }

    /// Hover intent zone for shelf auto-expand.
    private func isMouseInAutoExpandIntentZone(mouseLocation: NSPoint, window: NotchWindow) -> Bool {
        let notchRect = window.collapsedInteractionRect()
        let screenTopY = window.notchScreen?.frame.maxY ?? notchRect.maxY
        let upwardExpansion = max(0, screenTopY - notchRect.maxY)
        let relaxedZone = NSRect(
            x: notchRect.origin.x - 10,
            y: notchRect.origin.y,
            width: notchRect.width + 20,
            height: notchRect.height + upwardExpansion
        )
        return relaxedZone.contains(mouseLocation)
    }

    /// Routed event handler from monitors
    /// Only routes to the window whose screen contains the mouse - prevents race conditions
    private func handleMouseEvent(_ event: NSEvent) {
        // Menu windows dispatch a very high volume of mouse-move events.
        // Skip notch hit-testing while a menu is open to keep menu interactions responsive.
        if hasActiveContextMenu() {
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        
        // Find which window should handle this event (the one whose screen contains the mouse)
        if let (window, screen) = findWindowForMouseLocation(mouseLocation) {
            let displayID = screen.displayID
            let isFullscreenOnThisDisplay = fullscreenDisplayIDs.contains(displayID)
            
            // BUG #133 FIX: Detect hover in fullscreen mode to trigger reveal
            // Uses SAME logic as normal hover detection in handleGlobalMouseEvent
            if isFullscreenOnThisDisplay {
                let alreadyRevealed = fullscreenHoverRevealedDisplays.contains(displayID)
                
                if !alreadyRevealed {
                    // Check if mouse is in the notch area (same logic as normal hover)
                    let interactionRect = window.collapsedInteractionRect()
                    let isInNotchArea = interactionRect.contains(mouseLocation)
                    
                    // Check expanded zone - matches normal hover behavior
                    let screenTopY = screen.frame.maxY
                    let upwardExpansion = (screenTopY - interactionRect.maxY) + 5
                    let expandedRect = NSRect(
                        x: interactionRect.origin.x - 20,
                        y: interactionRect.origin.y,
                        width: interactionRect.width + 40,
                        height: interactionRect.height + upwardExpansion
                    )
                    var isInExpandedZone = expandedRect.contains(mouseLocation)
                    
                    // Fitt's Law special case: at screen top within notch X range = always hover
                    // (Same as normal hover detection - cursor pushed against edge)
                    let isAtScreenTop = mouseLocation.y >= screenTopY - 20
                    let isWithinNotchX = window.isWithinTopEdgeHoverBand(
                        x: mouseLocation.x,
                        on: screen,
                        notchRect: interactionRect
                    )
                    if isAtScreenTop && isWithinNotchX {
                        isInExpandedZone = true
                    }
                    
                    if isInNotchArea || isInExpandedZone {
                        // Trigger reveal - window becomes visible again
                        notchDebugLog("🎬 FULLSCREEN REVEAL: Triggering for display \(displayID)")
                        fullscreenHoverRevealedDisplays.insert(displayID)
                        window.revealInFullscreen()
                    }
                }
            }
            
            // Route event only to the window for this screen
            window.handleGlobalMouseEvent(event)
            if Thread.isMainThread {
                window.updateMouseEventHandling()
            } else {
                DispatchQueue.main.async {
                    window.updateMouseEventHandling()
                }
            }
        } else {
            // Mouse is on a screen with no notch window - reset hover state
            // This handles rare edge cases (e.g., external monitor without shelf enabled)
            // and ensures hover state doesn't get stuck when mouse leaves all notch areas
            if DroppyState.shared.isMouseHovering {
                DispatchQueue.main.async {
                    withAnimation(DroppyAnimation.hoverBouncy(for: nil)) {
                        if let hoveringDisplayID = DroppyState.shared.hoveringDisplayID {
                            DroppyState.shared.setHovering(for: hoveringDisplayID, isHovering: false)
                        } else {
                            DroppyState.shared.isMouseHovering = false
                        }
                    }
                }
            }
        }
    }
    
    /// Called when mouse leaves the notch area while in fullscreen hover-reveal mode (Bug #133)
    func hideFullscreenReveal(for displayID: CGDirectDisplayID) {
        guard fullscreenHoverRevealedDisplays.contains(displayID) else { return }
        fullscreenHoverRevealedDisplays.remove(displayID)
        
        if let window = notchWindows[displayID] {
            window.hideAfterFullscreenReveal()
        }
    }
    
    /// Accumulated horizontal scroll for swipe detection
    private var accumulatedScrollX: CGFloat = 0
    private var lastScrollTime: Date = .distantPast
    /// Debounce rapid repeated media/shelf toggles from a single swipe burst.
    private var lastMediaSwipeToggleAt: Date = .distantPast

    /// Handles scroll wheel events for 2-finger horizontal swipe media HUD toggle
    /// Swipe left = show media HUD, Swipe right = hide media HUD
    /// Works both when collapsed (hover state) and when expanded (shelf view)
    /// DISABLED when terminal is visible (terminal takes over the shelf)
    private func handleScrollEvent(_ event: NSEvent) {
        // Don't spend cycles on shelf/media swipe detection while menus are open.
        if hasActiveContextMenu() {
            return
        }

        // Disable swipe when terminal is visible (terminal takes over the shelf)
        if TerminalNotchManager.shared.isInstalled && TerminalNotchManager.shared.isVisible {
            return
        }

        // Reset accumulated scroll if too much time has passed (new gesture)
        if Date().timeIntervalSince(lastScrollTime) > 0.3 {
            accumulatedScrollX = 0
        }
        lastScrollTime = Date()
        
        let trackpadHorizontalSwipe = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 1.5
        guard trackpadHorizontalSwipe else { return }

        accumulatedScrollX += event.scrollingDeltaX
        
        let mouseLocation = NSEvent.mouseLocation
        
        // Check if mouse is in notch/shelf area
        guard let (window, screen) = findWindowForMouseLocation(mouseLocation) else { return }
        
        // Block swipe switching only on the display that currently owns the expanded To-do list.
        // Compact To-do bar and other displays should still allow swipe between shelf/media.
        if ToDoManager.shared.isShelfListExpanded,
           let expandedDisplayID = DroppyState.shared.expandedDisplayID,
           expandedDisplayID == screen.displayID {
            return
        }

        let notchRect = window.getNotchRect()
        
        // Build swipe detection zone based on current state
        var swipeZone: NSRect
        if DroppyState.shared.isExpanded(for: screen.displayID) {
            // EXPANDED: Cover the full expanded shelf area
            swipeZone = expandedShelfInteractionZone(for: screen)
        } else {
            // COLLAPSED: Expand detection zone slightly around notch for easier swiping
            swipeZone = NSRect(
                x: notchRect.origin.x - 50,
                y: notchRect.origin.y - 30,
                width: notchRect.width + 100,
                height: notchRect.height + 50
            )
        }
        guard swipeZone.contains(mouseLocation) else { return }
        
        // Only toggle if there's a track to show (not idle)
        guard !MusicManager.shared.isPlayerIdle else { return }
        
        // Require accumulated intent to exceed threshold before triggering.
        // Mouse wheel gestures are less granular than trackpad swipes, so use a lower threshold.
        let usingMappedMouseGesture = !event.hasPreciseScrollingDeltas
        let threshold: CGFloat = usingMappedMouseGesture ? 4 : 30
        
        // Determine current effective state for media visibility
        let musicManager = MusicManager.shared
        
        if accumulatedScrollX < -threshold {
            // Swipe LEFT -> Show MEDIA player
            accumulatedScrollX = 0  // Reset after action
            applyMediaSwipeToggle(showMediaHUD: true, on: screen, musicManager: musicManager)
        } else if accumulatedScrollX > threshold {
            // Swipe RIGHT -> Show SHELF (hide media)
            accumulatedScrollX = 0  // Reset after action
            applyMediaSwipeToggle(showMediaHUD: false, on: screen, musicManager: musicManager)
        }
    }

    private func applyMediaSwipeToggle(showMediaHUD: Bool, on screen: NSScreen, musicManager: MusicManager) {
        // Cooldown avoids repeated commits from a single high-velocity gesture stream.
        let now = Date()
        if now.timeIntervalSince(lastMediaSwipeToggleAt) < 0.22 {
            return
        }

        let desiredForced = showMediaHUD
        let desiredHidden = !showMediaHUD

        // Ignore no-op transitions to prevent redundant @Published emissions + animations.
        guard musicManager.isMediaHUDForced != desiredForced || musicManager.isMediaHUDHidden != desiredHidden else {
            return
        }

        lastMediaSwipeToggleAt = now
        withAnimation(DroppyAnimation.smoothContent(for: screen)) {
            musicManager.isMediaHUDForced = desiredForced
            musicManager.isMediaHUDHidden = desiredHidden
        }
    }
}

// MARK: - Screen Helper

/// Helper to find the built-in display with a notch
extension NSScreen {
    /// Returns the built-in display (the one with a notch), regardless of which screen is "main"
    static var builtInWithNotch: NSScreen? {
        // CRITICAL: Use auxiliary areas to detect physical notch, NOT safeAreaInsets
        // safeAreaInsets.top can be 0 on lock screen (no menu bar), but auxiliary areas
        // are hardware-based and always present for notch MacBooks
        if let notchScreen = NSScreen.screens.first(where: { 
            $0.auxiliaryTopLeftArea != nil && $0.auxiliaryTopRightArea != nil 
        }) {
            return notchScreen
        }
        // Fallback to safeAreaInsets check for compatibility
        if let notchScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notchScreen
        }
        // Final fallback to built-in display (localizedName contains "Built-in" or similar)
        return NSScreen.screens.first(where: { $0.localizedName.contains("Built-in") || $0.localizedName.contains("内蔵") })
    }
    
    /// Returns ANY built-in display (with or without notch)
    /// Uses CGDisplayIsBuiltin for reliable hardware-level detection
    /// CRITICAL: Use this for MacBook Air compatibility (no notch models)
    static var builtIn: NSScreen? {
        // Primary: use CGDisplayIsBuiltin - works for ALL MacBooks
        if let builtInScreen = NSScreen.screens.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }) {
            return builtInScreen
        }
        // Fallback: try builtInWithNotch for notch models
        if let notchScreen = builtInWithNotch {
            return notchScreen
        }
        // Last resort: check localized name
        return NSScreen.screens.first(where: { $0.localizedName.contains("Built-in") || $0.localizedName.contains("内蔵") })
    }

    /// Check if a point (in global screen coordinates) is on this screen
    func contains(point: NSPoint) -> Bool {
        return frame.contains(point)
    }

    /// Returns the global X center aligned to physical notch geometry when available.
    /// Falls back to frame midX for external displays or when notch metadata is unavailable.
    var notchAlignedCenterX: CGFloat {
        guard isBuiltIn,
              let leftArea = auxiliaryTopLeftArea,
              let rightArea = auxiliaryTopRightArea else {
            return frame.midX
        }

        let gapMid = (leftArea.maxX + rightArea.minX) / 2
        guard gapMid.isFinite else { return frame.midX }

        // Issue #198:
        // When an external display is primary, auxiliary notch geometry may be reported in
        // different coordinate bases (local, global, and occasionally backing-scale units).
        // Evaluate plausible interpretations and keep the one closest to screen midX.
        let scale = max(backingScaleFactor, 1)
        let candidates: [CGFloat] = [
            gapMid,                          // global points
            frame.origin.x + gapMid,         // local points
            gapMid / scale,                  // global backing units
            frame.origin.x + (gapMid / scale) // local backing units
        ].filter(\.isFinite)

        guard !candidates.isEmpty else { return frame.midX }

        let frameMinX = frame.minX - 1
        let frameMaxX = frame.maxX + 1
        let inFrameCandidates = candidates.filter { candidate in
            candidate >= frameMinX && candidate <= frameMaxX
        }
        let preferred = inFrameCandidates.isEmpty ? candidates : inFrameCandidates
        let best = preferred.min { lhs, rhs in
            abs(lhs - frame.midX) < abs(rhs - frame.midX)
        } ?? frame.midX
        return min(max(best, frame.minX), frame.maxX)
    }
    
    /// Returns the Core Graphics display ID for this screen
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
    
    /// Returns true if this is the built-in MacBook display
    /// Uses CGDisplayIsBuiltin for reliable hardware-level detection
    var isBuiltIn: Bool {
        // CRITICAL: Use CGDisplayIsBuiltin - the reliable hardware-level API
        // This works for ALL MacBooks, including Air models without a notch
        if CGDisplayIsBuiltin(displayID) != 0 {
            return true
        }
        // Fallback for edge cases: check localized name
        let isNameBuiltIn = localizedName.contains("Built-in") || 
                            localizedName.contains("Internal") ||
                            localizedName.contains("内蔵") // Japanese
        return isNameBuiltIn
    }
}

// MARK: - Custom Window Configuration

class NotchWindow: NSPanel {

    /// Flag to indicate if the window is still valid for event handling
    var isValid: Bool = true
    
    /// Flag to indicate if the window is currently delegated to the Lock Screen
    /// When true, we bypass "Hide in Fullscreen" checks to ensure visibility
    var isOnLockScreen: Bool = false
    
    /// The display ID this window is targeting (for multi-monitor support)
    var targetDisplayID: CGDirectDisplayID = 0
    
    /// Returns the screen that this window is targeting
    var notchScreen: NSScreen? {
        // First try to find the screen matching our target display ID
        if targetDisplayID != 0 {
            return NSScreen.screens.first { $0.displayID == targetDisplayID }
        }
        // Fallback to built-in with notch or main
        return NSScreen.builtInWithNotch ?? NSScreen.main
    }

    /// Whether the current screen should use Dynamic Island mode
    /// For external displays: uses externalDisplayUseDynamicIsland setting (always DI since no physical notch)
    /// For built-in display: uses useDynamicIslandStyle setting (only if no physical notch or force test)
    private var needsDynamicIsland: Bool {
        // CRITICAL: Return false (notch mode) when screen is unavailable to prevent layout jumps
        guard let screen = notchScreen else { return false }
        // Use auxiliary areas for stable detection (works on lock screen)
        let hasNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        
        // External displays always use Dynamic Island (no physical notch)
        // The setting determines if they show Notch style or Dynamic Island style
        if !screen.isBuiltIn {
            // Default to true for external displays - use DI style by default
            // Check if the key exists, otherwise use default value of true
            if UserDefaults.standard.object(forKey: "externalDisplayUseDynamicIsland") != nil {
                return (UserDefaults.standard.object(forKey: "externalDisplayUseDynamicIsland") as? Bool) ?? true
            }
            return true  // Default: use Dynamic Island on external displays
        }
        
        // Built-in display uses main Dynamic Island setting
        // Check if the key exists, otherwise use default value of true
        var useDynamicIsland = true  // Default
        if UserDefaults.standard.object(forKey: "useDynamicIslandStyle") != nil {
            useDynamicIsland = (UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool) ?? true
        }
        // Use Dynamic Island if: no physical notch OR force test is enabled (and style is enabled)
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    /// Dynamic Island dimensions
    private let dynamicIslandWidth: CGFloat = 210
    private var dynamicIslandHeight: CGFloat { NotchLayoutConstants.dynamicIslandHeight }
    /// Top margin for Dynamic Island - creates floating effect like iPhone
    private let dynamicIslandTopMargin: CGFloat = 4
    
    fileprivate var notchRect: NSRect {
        guard let screen = notchScreen else { return .zero }

        // DYNAMIC ISLAND MODE: Floating pill centered below screen top edge
        if needsDynamicIsland {
            // Centered at top with margin (floating island effect like iPhone)
            // Use notch-aligned center so DI and notch modes share the same physical anchor.
            let x = screen.notchAlignedCenterX - (dynamicIslandWidth / 2)
            let y = screen.frame.origin.y + screen.frame.height - dynamicIslandTopMargin - dynamicIslandHeight

            return NSRect(
                x: x,
                y: y,
                width: dynamicIslandWidth,
                height: dynamicIslandHeight
            )
        }

        // NOTCH MODE: Standard notch positioning
        var notchWidth: CGFloat = 180
        var notchHeight: CGFloat = NotchLayoutConstants.physicalNotchHeight  // Use fixed constant as default
        // Use notch-aligned center so frame stays physically centered.
        let notchCenterX = screen.notchAlignedCenterX

        // Calculate true notch position and size from safe areas
        // The notch is the gap between the right edge of the left safe area
        // and the left edge of the right safe area
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            // Correct calculation: the gap between the two auxiliary areas
            notchWidth = max(rightArea.minX - leftArea.maxX, 180)
        }

        // Get notch height - prefer safeAreaInsets but fall back to constant
        // CRITICAL: safeAreaInsets.top can be 0 on lock screen, so we use the fixed constant as fallback
        let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        if hasPhysicalNotch {
            let topInset = screen.safeAreaInsets.top
            if topInset > 0 {
                notchHeight = topInset
            }
            // else keep the default NotchLayoutConstants.physicalNotchHeight
        } else if !screen.isBuiltIn {
            // For external displays in notch mode: constrain to menu bar height
            // Menu bar height = difference between full frame and visible frame at the top
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            // Use 24pt as default if menu bar is auto-hidden, but never exceed actual menu bar
            let maxHeight = menuBarHeight > 0 ? menuBarHeight : 24
            notchHeight = min(32, maxHeight)
        }

        // Y position in global coordinates
        let notchY = screen.frame.origin.y + screen.frame.height - notchHeight

        return NSRect(
            x: notchCenterX - (notchWidth / 2),
            y: notchY,
            width: notchWidth,
            height: notchHeight
        )
    }
    
    /// Public accessor for the real hardware notch rect in screen coordinates
    func getNotchRect() -> NSRect {
        return notchRect
    }

    /// Collapsed interaction surface used for hover/click hit-testing.
    /// In built-in notch mode, the mini media HUD renders 50pt wings on each side
    /// of the physical notch. Expand hit-testing to match that visible surface.
    func collapsedInteractionRect() -> NSRect {
        var rect = notchRect
        guard shouldUseMediaWingInteractionRect else { return rect }

        let mediaWingWidth: CGFloat = 50
        rect.origin.x -= mediaWingWidth
        rect.size.width += (mediaWingWidth * 2)
        return rect
    }

    /// Mirrors collapsed mini-media visibility conditions closely enough for hit-testing.
    private var shouldUseMediaWingInteractionRect: Bool {
        guard let screen = notchScreen else { return false }
        guard !needsDynamicIsland else { return false }
        guard screen.isBuiltIn else { return false }
        guard screen.auxiliaryTopLeftArea != nil, screen.auxiliaryTopRightArea != nil else { return false }

        let showMediaPlayer = (UserDefaults.standard.object(forKey: AppPreferenceKey.showMediaPlayer) as? Bool)
            ?? PreferenceDefault.showMediaPlayer
        guard showMediaPlayer else { return false }

        let displayID = targetDisplayID != 0 ? targetDisplayID : screen.displayID
        guard !DroppyState.shared.isExpanded(for: displayID) else { return false }
        guard !NotchWindowController.shared.fullscreenDisplayIDs.contains(displayID) else { return false }

        let music = MusicManager.shared
        guard music.isMediaAvailable else { return false }
        guard !music.isPlayerIdle else { return false }

        // Forced mode stays visible when user swipes it in; otherwise require active playback
        // and not manually hidden.
        return music.isMediaHUDForced || (music.isPlaying && !music.isMediaHUDHidden)
    }

    /// Built-in notch displays can report cursor positions that "skip" across the cutout
    /// at the top edge. Use a stable center-aligned band for top-edge hover intent.
    func isWithinTopEdgeHoverBand(
        x: CGFloat,
        on screen: NSScreen,
        notchRect: NSRect,
        extraPadding: CGFloat = 0
    ) -> Bool {
        let hasPhysicalNotch = screen.isBuiltIn &&
            screen.auxiliaryTopLeftArea != nil &&
            screen.auxiliaryTopRightArea != nil

        if hasPhysicalNotch {
            let centerX = screen.notchAlignedCenterX
            // Keep the top-edge helper close to the actual notch. A very wide
            // band can cause accidental hover activation while using menu-bar items.
            let halfWidth = (notchRect.width / 2) + 12 + extraPadding
            return abs(x - centerX) <= halfWidth
        }

        return x >= (notchRect.minX - 14 - extraPadding) && x <= (notchRect.maxX + 14 + extraPadding)
    }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Configure window properties for overlay behavior
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        
        // CRITICAL: Panel-specific settings for first-click activation (v5.3.7)
        // This allows immediate interaction with shelf items without clicking to activate first
        self.becomesKeyOnlyIfNeeded = true
        
        // CRITICAL: Prevent AppKit from injecting its own unstable transform animations
        self.animationBehavior = .none
        // Ensure manual memory management is stable
        self.isReleasedWhenClosed = false
        
        // START with ignoring mouse events - let clicks pass through in idle state
        self.ignoresMouseEvents = true
    }
    
    /// Track the intended alpha to avoid piling up animations
    private var targetAlpha: CGFloat = 1.0
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        isValid = false
    }
    
    func handleGlobalMouseEvent(_ event: NSEvent) {
        // DEBUG: Log to verify this function is being called after unlock
        struct DebugCounter { static var count = 0; static var lastLog = Date.distantPast }
        DebugCounter.count += 1
        if Date().timeIntervalSince(DebugCounter.lastLog) > 2.0 { // Log every 2 seconds max
            notchDebugLog("🎯 NotchWindow.handleGlobalMouseEvent called \(DebugCounter.count)x, notchRect: \(notchRect)")
            DebugCounter.lastLog = Date()
        }
        
        // CRITICAL: Skip all hover tracking when a context menu is open
        // This prevents view re-renders that would dismiss submenus (Share, Compress, etc.)
        if NotchWindowController.shared.hasActiveContextMenu() {
            return
        }

        // Keep hover state stable while interacting with To-do popovers/date pickers.
        if ToDoManager.shared.isInteractingWithPopover || NotchWindowController.shared.hasActivePopoverWindow() {
            return
        }
        
        // Issue #60: Skip leftMouseDragged events unless already hovering
        // This prevents text selection in browsers from triggering the Dynamic Island
        // When user drags to select text, the cursor may pass through the notch zone briefly
        // We only want to respond to drags if the user was already hovering (intentional drag)
        if event.type == .leftMouseDragged {
            if let screen = notchScreen {
                guard DroppyState.shared.isHovering(for: screen.displayID) else { return }
            } else if !DroppyState.shared.isMouseHovering {
                return
            }
        }
        
        // SAFETY: Use the event's location properties instead of NSEvent.mouseLocation
        // class property to avoid race conditions with the HID event decoding system.
        // For global monitors, we need to convert the event location to screen coordinates.
        // Global events have locationInScreen as the screen-based location.
        let mouseLocation: NSPoint
        if (event.window?.screen ?? notchScreen) != nil {
            // Convert window-relative location to screen coordinates
            if let window = event.window {
                mouseLocation = window.convertPoint(toScreen: event.locationInWindow)
            } else {
                // For events without a window (global monitor), the locationInWindow
                // is already in screen coordinates for global monitors
                mouseLocation = NSEvent.mouseLocation // fallback, cached once
            }
        } else {
            mouseLocation = NSEvent.mouseLocation
        }

        // MULTI-MONITOR SUPPORT: Verify mouse is on this window's screen
        // This is now a simple validation since events are already routed to correct window
        // NOTE: Use tolerant frame check because NSRect.contains() excludes the boundary.
        // When cursor is at absolute top edge (y == maxY), frame.contains() returns false.
        guard let targetScreen = notchScreen else { return }
        let extendedScreenFrame = NSRect(
            x: targetScreen.frame.origin.x,
            y: targetScreen.frame.origin.y,
            width: targetScreen.frame.width,
            height: targetScreen.frame.height + 5  // +5px to include absolute top edge
        )
        guard extendedScreenFrame.contains(mouseLocation) else {
            // DEBUG: Log when guard fails - UNCONDITIONAL for 5 seconds after unlock!
            let timeSinceUnlock = Date().timeIntervalSince(DragMonitor.unlockTime)
            let isVerbose = timeSinceUnlock < 5.0 && timeSinceUnlock > 0
            
            struct GuardDebugCounter { static var count = 0; static var lastLog = Date.distantPast }
            GuardDebugCounter.count += 1
            
            if isVerbose || Date().timeIntervalSince(GuardDebugCounter.lastLog) > 2.0 {
                notchDebugLog("⚠️ GUARD FAILED (\(GuardDebugCounter.count)x, verbose=\(isVerbose)): notchScreen=\(notchScreen != nil ? "\(notchScreen!.displayID)" : "nil"), mouseLocation=\(mouseLocation), frame=\(notchScreen.map { String(describing: $0.frame) } ?? "nil")")
                GuardDebugCounter.lastLog = Date()
            }
            return
        }

        // PRECISE HOVER DETECTION (v5.2)
        // Different logic for NOTCH vs DYNAMIC ISLAND modes
        
        // DEBUG: Log that we passed the guard (unconditional, throttled)
        struct PastGuardDebugCounter { static var count = 0; static var lastLog = Date.distantPast }
        PastGuardDebugCounter.count += 1
        if Date().timeIntervalSince(PastGuardDebugCounter.lastLog) > 2.0 {
            notchDebugLog("✅ PAST GUARD: displayID=\(targetScreen.displayID), mouse=\(mouseLocation), screenFrame=\(targetScreen.frame)")
            PastGuardDebugCounter.lastLog = Date()
        }

        let collapsedRect = collapsedInteractionRect()
        // Use true notch/island geometry for top-edge intent checks.
        // Collapsed interaction rect can include media wings and become too wide.
        let topEdgeReferenceRect = notchRect
        let isOverExactNotch = collapsedRect.contains(mouseLocation)
        var isOverExpandedZone: Bool


        // DEBUG: Temporary logging to diagnose external display island issue
        if needsDynamicIsland {
            // DYNAMIC ISLAND MODE:
            // The island is a floating pill below the menu bar with a gap above it.
            // - Horizontal: ±20px expansion for catching fast horizontal movements
            // - Upward: Extend to absolute screen top (area above island is still interactive)
            // - Downward: NO expansion - must NOT detect below the visible island
            let screenTopY = targetScreen.frame.maxY

            // Extend all the way to screen top (covers the gap above the floating island)
            let upwardExpansion = max(0, screenTopY - collapsedRect.maxY)

            let expandedNotchRect = NSRect(
                x: collapsedRect.origin.x - 10,                     // 10px expansion on left
                y: collapsedRect.origin.y,                          // Keep bottom edge EXACT (no downward expansion!)
                width: collapsedRect.width + 20,                    // 10px expansion on each side = 20px total
                height: collapsedRect.height + upwardExpansion      // Extend upward to screen top (covers the gap)
            )
            isOverExpandedZone = expandedNotchRect.contains(mouseLocation)

            // Special case: If cursor is at the absolute screen top edge within island X range,
            // always treat it as hovering (Fitt's Law - user slamming cursor to top)
            let isAtScreenTop = mouseLocation.y >= targetScreen.frame.maxY - 10  // Within 10px
            let isWithinIslandX = isWithinTopEdgeHoverBand(
                x: mouseLocation.x,
                on: targetScreen,
                notchRect: topEdgeReferenceRect
            )
            if isAtScreenTop && isWithinIslandX {
                isOverExpandedZone = true
            }
        } else {
            // NOTCH MODE:
            // The hardware notch is at the screen's top edge.
            // - Horizontal: ±20px expansion for fast side-to-side movements
            // - Upward: Extend to absolute screen top (Fitt's Law - infinite edge target)
            // - Downward: NO expansion (avoid blocking bookmark bars, URL fields)
            let screenTopY = targetScreen.frame.maxY
            let upwardExpansion = (screenTopY - collapsedRect.maxY) + 5  // +5px buffer to capture absolute edge

            let expandedNotchRect = NSRect(
                x: collapsedRect.origin.x - 10,                     // 10px expansion on left
                y: collapsedRect.origin.y,                          // Keep bottom edge exact (no downward expansion)
                width: collapsedRect.width + 20,                    // 10px expansion on each side = 20px total
                height: collapsedRect.height + upwardExpansion      // Extend to screen top edge + buffer
            )
            isOverExpandedZone = expandedNotchRect.contains(mouseLocation)

            // Special case: If cursor is at/near the absolute top of the screen and within notch X range,
            // always treat it as hovering. The tolerance needs to be generous because:
            // 1. When cursor hits screen edge, no more mouseMoved events are generated
            // 2. The last event before hitting the edge might have a Y slightly below maxY
            // 3. macOS may also report Y at or ABOVE maxY when cursor is at physical edge
            // 4. Menu bar is ~24px, notch is within that space, so 20px tolerance is safe
            let isAtScreenTop = mouseLocation.y >= targetScreen.frame.maxY - 10  // Within 10px of absolute top
            let isWithinNotchX = isWithinTopEdgeHoverBand(
                x: mouseLocation.x,
                on: targetScreen,
                notchRect: topEdgeReferenceRect
            )
            if isAtScreenTop && isWithinNotchX {
                isOverExpandedZone = true
            }
        }

        // Use expanded zone to START hovering, exact zone to MAINTAIN hover
        // Exception: Also maintain hover at the screen top edge (Fitt's Law - user pushing against edge)
        let displayID = targetScreen.displayID
        let currentlyHovering = DroppyState.shared.isHovering(for: displayID)

        // For maintaining hover: exact notch OR at screen top within horizontal bounds
        var isOverExactOrEdge = isOverExactNotch
        let isAtScreenTop = mouseLocation.y >= targetScreen.frame.maxY - 10  // Within 10px
        let isWithinNotchX = isWithinTopEdgeHoverBand(
            x: mouseLocation.x,
            on: targetScreen,
            notchRect: topEdgeReferenceRect
        )
        if isAtScreenTop && isWithinNotchX {
            isOverExactOrEdge = true
        }

        let isOverNotch = currentlyHovering ? isOverExactOrEdge : isOverExpandedZone

        // DEBUG: Unconditional check for isDragging being stuck after unlock
        struct DragDebugCounter { static var lastLog = Date.distantPast; static var count = 0 }
        DragDebugCounter.count += 1
        if DragMonitor.shared.isDragging && Date().timeIntervalSince(DragDebugCounter.lastLog) > 2.0 {
            notchDebugLog("⚠️ DRAG STUCK: isDragging=true for \(DragDebugCounter.count) samples! mouseY=\(mouseLocation.y), screenMaxY=\(targetScreen.frame.maxY)")
            DragDebugCounter.lastLog = Date()
        }
        
        // Only update if not dragging (drag monitor handles that)
        if !DragMonitor.shared.isDragging {
            // DEBUG: Log ALL mouse positions near top 200px to catch edge cases after SkyLight
            let screenMaxY = targetScreen.frame.maxY
            let yThreshold = screenMaxY - 100
            
            // Log periodically to see if we're even getting events
            struct AllEventDebugCounter { static var count = 0; static var lastLog = Date.distantPast }
            AllEventDebugCounter.count += 1
            if Date().timeIntervalSince(AllEventDebugCounter.lastLog) > 2.0 {
                let isNearTop = mouseLocation.y > yThreshold
                notchDebugLog("🔎 MOUSE Y CHECK: mouse.y=\(mouseLocation.y), screenMaxY=\(screenMaxY), threshold=\(yThreshold), nearTop=\(isNearTop), displayID=\(targetScreen.displayID)")
                AllEventDebugCounter.lastLog = Date()
            }
            
            // DEBUG: Log hover detection conditions when mouse is near top of screen
            if mouseLocation.y > yThreshold {
                struct DebugCounter { static var lastLog = Date.distantPast }
                if Date().timeIntervalSince(DebugCounter.lastLog) > 1.0 {
                    notchDebugLog("🔍 HOVER DEBUG: mouse=\(mouseLocation), isOverNotch=\(isOverNotch), currentlyHovering=\(currentlyHovering), isOverExpandedZone=\(isOverExpandedZone), isOverExactOrEdge=\(isOverExactOrEdge)")
                    DebugCounter.lastLog = Date()
                }
            }
            
            if isOverNotch && !currentlyHovering {
                DispatchQueue.main.async {
                    // Validate items before showing shelf (remove ghost files)
                    DroppyState.shared.validateItems()

                    withAnimation(DroppyAnimation.hoverBouncy(for: targetScreen)) {
                        DroppyState.shared.setHovering(for: targetScreen.displayID, isHovering: true)
                    }
                    // Start auto-expand timer with THIS screen's displayID
                    // Critical for multi-monitor: ensures correct screen expands
                    NotchWindowController.shared.startAutoExpandTimer(for: targetScreen.displayID)
                }
            } else if !isOverNotch && currentlyHovering && !DroppyState.shared.isExpanded(for: displayID) {
                // Only reset hover if not expanded (expanded has its own area)
                DispatchQueue.main.async {
                    withAnimation(DroppyAnimation.hoverBouncy(for: targetScreen)) {
                        DroppyState.shared.setHovering(for: displayID, isHovering: false)
                    }
                    NotchWindowController.shared.cancelAutoExpandTimer()
                    
                    // BUG #133 FIX: Trigger delayed hide for fullscreen hover-reveal
                    if NotchWindowController.shared.fullscreenHoverRevealedDisplays.contains(displayID) {
                        // Delay hide slightly to allow re-entry if user is just moving around
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // Recheck: only hide if still not hovering and not expanded
                            if !DroppyState.shared.isHovering(for: displayID) && !DroppyState.shared.isExpanded(for: displayID) {
                                NotchWindowController.shared.hideFullscreenReveal(for: displayID)
                            }
                        }
                    }
                }
            } else if DroppyState.shared.isExpanded(for: targetScreen.displayID) {
                // When shelf is expanded ON THIS SCREEN, check if cursor is in the expanded shelf zone
                // CRITICAL: Only check if THIS screen has the expanded shelf (not just any screen)
                // If so, maintain hover state to prevent auto-collapse
                let expandedShelfZone = NotchWindowController.shared.expandedShelfInteractionZone(for: targetScreen)
                
                let isInExpandedShelf = expandedShelfZone.contains(mouseLocation)
                if isInExpandedShelf && !currentlyHovering {
                    DispatchQueue.main.async {
                        DroppyState.shared.setHovering(for: targetScreen.displayID, isHovering: true)
                    }
                }
                // Reset hover state if user moves OUT of the expanded shelf
                else if !isInExpandedShelf && currentlyHovering {
                    DispatchQueue.main.async {
                        DroppyState.shared.setHovering(for: displayID, isHovering: false)
                        
                        // BUG #133 FIX: Trigger delayed hide for fullscreen hover-reveal
                        if NotchWindowController.shared.fullscreenHoverRevealedDisplays.contains(displayID) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if !DroppyState.shared.isHovering(for: displayID) && !DroppyState.shared.isExpanded(for: displayID) {
                                    NotchWindowController.shared.hideFullscreenReveal(for: displayID)
                                }
                            }
                        }
                    }
                }
            } else if DroppyState.shared.isExpanded && !DroppyState.shared.isExpanded(for: displayID) && currentlyHovering && !isOverNotch {
                // CRITICAL FIX (2-external-monitor bug):
                // Shelf is expanded on a DIFFERENT screen, and mouse is on THIS screen,
                // but NOT over this screen's notch. Reset hover state so the expanded
                // shelf on the other screen can auto-collapse.
                DispatchQueue.main.async {
                    DroppyState.shared.setHovering(for: displayID, isHovering: false)
                }
            }
        }
    }

    
    func updateMouseEventHandling() {
        // Critical: Early exit if window is being deallocated
        guard isValid else { return }
        
        // Must be on main thread
        guard Thread.isMainThread else { return }
        
        // Verify window is still valid before any property access
        guard self.contentView != nil else {
            isValid = false
            return
        }

        // If the notch is temporarily hidden, always ignore mouse events
        if NotchWindowController.shared.isTemporarilyHidden {
            if !self.ignoresMouseEvents {
                self.ignoresMouseEvents = true
            }
            return
        }
        
        // Safely capture state - avoid accessing shared singletons if they might be nil
        // Use local variables to minimize property access time
        let state = DroppyState.shared

        let displayID = targetDisplayID != 0 ? targetDisplayID : (notchScreen?.displayID ?? 0)
        let isExpanded = state.isExpanded(for: displayID)
        let isDropTargeted = state.isDropTargeted && (state.dropTargetDisplayID == nil || state.dropTargetDisplayID == displayID)
        let isDraggingFiles = DragMonitor.shared.isDragging
        let mouseLocation = NSEvent.mouseLocation
        let resolvedScreen = notchScreen ?? NSScreen.screens.first(where: { $0.displayID == displayID })

        var isMouseInExpandedShelfZone = false
        if isExpanded, let screen = resolvedScreen {
            let expandedZone = NotchWindowController.shared.expandedShelfInteractionZone(for: screen)
            isMouseInExpandedShelfZone = expandedZone.contains(mouseLocation)
        }
        
        // CRITICAL FIX (v7.0.2): When dragging, only accept events if drag is OVER the valid drop zone!
        // Previously we captured ALL drags, which blocked areas below the notch (bookmarks bar, etc.)
        // Now we check: is the drag actually over the notch? If not, let it pass through.
        var isDragOverValidZone = false
        if isDraggingFiles {
            let notchRect = getNotchRect()
            
            // Check if drag is over the notch (with horizontal margin for easier targeting)
            let dragZone = NSRect(
                x: notchRect.minX - 20,
                y: notchRect.minY,  // NO downward extension - this is critical!
                width: notchRect.width + 40,
                height: notchRect.height + 20  // Only extend upward
            )
            isDragOverValidZone = dragZone.contains(mouseLocation)
            
            // Also accept if expanded and over the expanded shelf area
            // Use notchScreen for multi-monitor support
            if isExpanded && !isDragOverValidZone, let screen = resolvedScreen {
                let expandedZone = NotchWindowController.shared.expandedShelfInteractionZone(for: screen)
                isDragOverValidZone = expandedZone.contains(mouseLocation)
            }
        }
        
        // CRITICAL FIX (v8.1.x): When shelf is DISABLED, the window should NOT block
        // for shelf-related interactions (hover, expand, drag-to-drop on notch).
        // User only wants floating basket, not the notch/island UI blocking their screen.
        // CRITICAL: Use object() ?? true to match @AppStorage defaults
        let enableNotchShelf = (UserDefaults.standard.object(forKey: "enableNotchShelf") as? Bool) ?? true

        // Notification HUD click-through rule: only capture events while cursor is inside
        // the visible notification surface on THIS display.
        let isNotificationHUDActiveOnDisplay = isNotificationHUDActive(on: displayID)
        let isMouseInNotificationHUDZone: Bool = {
            guard isNotificationHUDActiveOnDisplay,
                  let screen = resolvedScreen,
                  let notificationZone = notificationHUDInteractionZone(on: screen) else {
                return false
            }
            return notificationZone.contains(mouseLocation)
        }()

        // Window should accept mouse events when:
        // - Shelf is expanded AND shelf is enabled (need to interact with items)
        // - Drop is actively targeted on the notch AND shelf is enabled
        // - User is dragging files AND they are OVER a valid drop zone AND shelf is enabled
        // - Cursor is over NotificationHUD (need click to open source app)
        // NOTE: isHovering is intentionally NOT included - hovering just shows the visual effect,
        // but the window should NOT block clicks to underlying apps (e.g., browser tabs) - Issue #150
        // When shelf is disabled, the window passes through ALL mouse events (except for interactive HUDs).
        let shouldAcceptEvents = (enableNotchShelf && (isMouseInExpandedShelfZone || isDropTargeted || isDragOverValidZone)) || isMouseInNotificationHUDZone

        // DEBUG: Log notification HUD state affecting mouse events
        if isNotificationHUDActiveOnDisplay {
            notchDebugLog("🔔 NotchWindow: NotificationHUD active - inZone=\(isMouseInNotificationHUDZone), shouldAcceptEvents=\(shouldAcceptEvents), ignoresMouseEvents=\(self.ignoresMouseEvents)")
        }

        // Only update if the value actually needs to change
        if self.ignoresMouseEvents == shouldAcceptEvents {
            self.ignoresMouseEvents = !shouldAcceptEvents
            if isNotificationHUDActiveOnDisplay {
                notchDebugLog("🔔 NotchWindow: Updated ignoresMouseEvents to \(!shouldAcceptEvents) for NotificationHUD")
            }
        }

        // CRITICAL: When NotificationHUD is active, allow the window to become key immediately
        // This ensures clicks on the notification are processed without requiring a first click to activate
        if isNotificationHUDActiveOnDisplay {
            if self.becomesKeyOnlyIfNeeded {
                self.becomesKeyOnlyIfNeeded = false
                notchDebugLog("🔔 NotchWindow: Set becomesKeyOnlyIfNeeded=false for NotificationHUD clicks")
            }
        } else {
            // Restore default behavior when notification is not visible
            if !self.becomesKeyOnlyIfNeeded {
                self.becomesKeyOnlyIfNeeded = true
            }
        }
    }

    func checkForFullscreen() {
        _ = checkForFullscreenAndReturn()
    }
    
    /// Returns true if fullscreen is detected (for NotchWindowController to track)
    func checkForFullscreenAndReturn() -> Bool {
        // CRITICAL: Never hide during drag operations - user needs to drop files!
        if DragMonitor.shared.isDragging {
            if targetAlpha != 1.0 {
                targetAlpha = 1.0
                alphaValue = 1.0
            }
            return false
        }
        
        // CRITICAL: Never hide on Lock Screen (even if it looks like a fullscreen app)
        if isOnLockScreen {
            if targetAlpha != 1.0 {
                targetAlpha = 1.0
                alphaValue = 1.0
            }
            return false
        }
        
        // Check if auto-hide is enabled
        let autoHideEnabled = (UserDefaults.standard.object(forKey: AppPreferenceKey.autoHideOnFullscreen) as? Bool) ?? PreferenceDefault.autoHideOnFullscreen
        guard autoHideEnabled else {
            // Setting disabled - ensure window is visible
            if targetAlpha != 1.0 {
                targetAlpha = 1.0
                alphaValue = 1.0
            }
            return false
        }
        
        // FULLSCREEN DETECTION using private SkyLight API
        // This is the approach used by Droppy and Droppy via system APIs
        // It directly queries macOS for Space metadata - a Space is fullscreen if it has a TileLayoutManager
        
        // Use notchScreen for multi-monitor support
        guard let screen = notchScreen else { return false }
        
        // Get display UUID for multi-monitor matching
        guard let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
        let displayID = CGDirectDisplayID(displayNumber.uint32Value)
        guard let displayUUID = CGDisplayCreateUUIDFromDisplayID(displayID) else { return false }
        let displayUUIDString = CFUUIDCreateString(nil, displayUUID.takeRetainedValue()) as String
        
        // Use private API to get managed display spaces
        guard let displaySpaces = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [NSDictionary] else { 
            return false 
        }
        
        var isFullscreen = false
        
        for displayDict in displaySpaces {
            // Match this display by UUID
            guard let displayIdentifier = displayDict["Display Identifier"] as? String,
                  displayIdentifier == displayUUIDString else { continue }
            
            // Get current space info
            guard let currentSpace = displayDict["Current Space"] as? [String: Any],
                  let spacesList = displayDict["Spaces"] as? [[String: Any]] else { continue }
            
            let activeSpaceID = currentSpace["ManagedSpaceID"] as? Int ?? -1
            
            // Find the active space in the list
            guard let activeSpace = spacesList.first(where: { ($0["ManagedSpaceID"] as? Int) == activeSpaceID }) else { continue }
            
            // THE KEY CHECK: If TileLayoutManager exists, it's a fullscreen Space!
            // This is how macOS internally tracks fullscreen Spaces
            let tileLayoutManager = activeSpace["TileLayoutManager"] as? [String: Any]
            isFullscreen = tileLayoutManager != nil
            break
        }
        
        // Check if "hide media only" mode is enabled
        // When enabled, the window stays visible but we still return isFullscreen
        // so the media player knows to hide (via fullscreenDisplayIDs in NotchShelfView)
        let hideMediaOnly = (UserDefaults.standard.object(forKey: AppPreferenceKey.hideMediaOnlyOnFullscreen) as? Bool) ?? PreferenceDefault.hideMediaOnlyOnFullscreen
        
        // BUG #133 FIX: Check if we're in hover-reveal mode for this display
        let isHoverRevealed = NotchWindowController.shared.fullscreenHoverRevealedDisplays.contains(targetDisplayID)
        
        // If hideMediaOnly is enabled, don't hide the window - just report fullscreen status
        // This allows volume/brightness HUDs to still appear while media is hidden
        // Also respect hover-reveal state - don't hide if user has triggered reveal via top-edge hover
        let shouldHide = isFullscreen && !hideMediaOnly && !isHoverRevealed
        let newTargetAlpha: CGFloat = shouldHide ? 0.0 : 1.0
        
        // Only trigger animation if the TARGET has changed
        if self.targetAlpha != newTargetAlpha {
            self.targetAlpha = newTargetAlpha
            
            // Directly set alpha without animation to prevent Core Animation crashes
            self.alphaValue = newTargetAlpha
        }
        
        // Return the fullscreen status (not whether we're hiding)
        // This is used by NotchWindowController to track fullscreenDisplayIDs
        return isFullscreen
    }
    
    // MARK: - Fullscreen Hover-Reveal (Bug #133)
    
    /// Reveal the window when user hovers at top edge in fullscreen mode
    func revealInFullscreen() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        }
        targetAlpha = 1.0
    }
    
    /// Hide the window when user stops hovering in fullscreen mode
    func hideAfterFullscreenReveal() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 0.0
        }
        targetAlpha = 0.0
    }
    
    // Ensure the window can become key to receive input - but only when appropriate
    // Don't steal key window status from other Droppy windows (Settings, Clipboard, etc.)
    // OPTIMIZED: Check specific singletons instead of iterating all windows (O(1) vs O(n))
    override var canBecomeKey: Bool {
        // Fast check: if another Droppy window is the current key window, yield
        if let keyWindow = NSApp.keyWindow, keyWindow !== self {
            // Check if current key window is one of our important windows
            if keyWindow is ClipboardPanel || keyWindow is BasketPanel ||
               keyWindow.title == "Settings" || keyWindow.title.contains("Update") ||
               keyWindow.title == "Welcome to Droppy" {
                return false
            }
        }

        let displayID = targetDisplayID != 0 ? targetDisplayID : (notchScreen?.displayID ?? 0)
        // NotificationHUD needs key window status for click redirection.
        let isNotificationHUDActiveOnDisplay = isNotificationHUDActive(on: displayID)

        // Become key when:
        // - Shelf is expanded and needs interaction
        // - Mouse is hovering (about to interact)
        // - NotificationHUD is visible on this display
        return DroppyState.shared.isExpanded(for: displayID) ||
            DroppyState.shared.isHovering(for: displayID) ||
            isNotificationHUDActiveOnDisplay
    }
}

// MARK: - Private SkyLight API for Fullscreen Space Detection
// CGS types and functions are now provided by Utilities/CGSShims.swift
