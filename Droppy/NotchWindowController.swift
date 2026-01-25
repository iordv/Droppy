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

/// Manages the transparent overlay window positioned at the MacBook notch
final class NotchWindowController: NSObject, ObservableObject {
    /// Dictionary of notch windows keyed by display ID (supports multi-monitor)
    private var notchWindows: [CGDirectDisplayID: NotchWindow] = [:]
    
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
        // Check for any window at popup menu level (101) or higher
        return NSApp.windows.contains { $0.level.rawValue >= NSWindow.Level.popUpMenu.rawValue }
    }
    
    /// Sets up and shows the notch overlay window(s)
    /// Creates windows for all eligible screens based on user settings
    func setupNotchWindow() {
        let hideOnExternal = UserDefaults.standard.bool(forKey: "hideNotchOnExternalDisplays")
        
        for screen in NSScreen.screens {
            let displayID = screen.displayID
            
            // Skip if window already exists for this screen
            guard notchWindows[displayID] == nil else { continue }
            
            // Skip external displays if user has hidden notch on external
            if hideOnExternal && !screen.isBuiltIn {
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
        
        // Window needs to be wide enough for expanded shelf
        // Height is limited to avoid false hover detection in empty areas
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 280

        // Position at top center of screen (aligned with notch) using global coordinates
        let xPosition = screen.frame.origin.x + (screen.frame.width - windowWidth) / 2
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
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = CGColor.clear
        
        // 2. Create the container view that handles drops
        let dragContainer = NotchDragContainer(frame: NSRect(origin: .zero, size: windowFrame.size))
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
        
        // Show the window
        window.orderFrontRegardless()
        
        // Apply screenshot visibility setting
        let hideFromScreenshots = UserDefaults.standard.bool(forKey: "hideNotchFromScreenshots")
        window.sharingType = hideFromScreenshots ? .none : .readOnly
        
        // Store in dictionary
        notchWindows[displayID] = window
    }
    /// Updates the window's visibility in screenshots based on user preference
    func updateScreenshotVisibility() {
        let hideFromScreenshots = UserDefaults.standard.bool(forKey: "hideNotchFromScreenshots")
        for window in notchWindows.values {
            window.sharingType = hideFromScreenshots ? .none : .readOnly
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
                let notchArea = CGRect(
                    x: screenFrame.midX - notchWidth / 2,
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
        // Check if any connected screen has a notch
        let hasNotch = NSScreen.builtInWithNotch?.safeAreaInsets.top ?? 0 > 0
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
            let shouldHaveWindow = !hideOnExternal || screen.isBuiltIn
            
            if shouldHaveWindow {
                if let existingWindow = notchWindows[displayID] {
                    // RESOLUTION CHANGE FIX: Check if screen horizontal center changed
                    // Only check X position since height is dynamically managed based on content
                    let windowWidth: CGFloat = 500
                    let expectedCenterX = screen.frame.origin.x + screen.frame.width / 2
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
                        let expectedX = screen.frame.origin.x + (screen.frame.width - windowWidth) / 2
                        if abs(existingWindow.frame.origin.x - expectedX) > 2 {
                            var newFrame = existingWindow.frame
                            newFrame.origin.x = expectedX
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
        
        // CRITICAL (v7.0.2): Also update when drag LOCATION changes during a drag.
        // This ensures the window ignores events when drag moves BELOW the notch,
        // preventing blocking of bookmarks bar and other UI elements.
        DragMonitor.shared.$dragLocation
            .receive(on: DispatchQueue.main)
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
            self?.handleMouseEvent(event)
        }
        
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

            // Get the notch rect from the window for that screen
            let notchRect = targetWindow.getNotchRect()
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
            let isExpanded = DroppyState.shared.isExpanded
            var expandedShelfZone: NSRect = .zero
            if isExpanded {
                let expandedWidth: CGFloat = 450
                let centerX = targetScreen.frame.origin.x + targetScreen.frame.width / 2
                
                // Issue #64: Use unified height calculator (single source of truth)
                let expandedHeight = DroppyState.expandedShelfHeight(for: targetScreen)

                expandedShelfZone = NSRect(
                    x: centerX - expandedWidth / 2,
                    y: targetScreen.frame.origin.y + targetScreen.frame.height - expandedHeight,
                    width: expandedWidth,
                    height: expandedHeight
                )
            }

            // Check if click is in notch zone or expanded shelf zone
            let isInNotchZone = clickZone.contains(mouseLocation)
            let isInExpandedShelfZone = isExpanded && expandedShelfZone.contains(mouseLocation)

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
                if isExpanded && hasItems {
                    // Shelf is expanded with items - let SwiftUI handle the click
                    return
                }
                DispatchQueue.main.async {
                    withAnimation(DroppyAnimation.transition) {
                        DroppyState.shared.toggleShelfExpansion(for: targetScreen.displayID)
                    }
                }
            } else if isExpanded && !isInExpandedShelfZone && !self.hasActiveContextMenu() {
                // CLICK OUTSIDE TO CLOSE: Shelf is open, click is outside shelf area
                // Don't close if a context menu is active (user is interacting with submenu)
                // Don't close if auto-collapse is disabled (user wants manual control)
                // CRITICAL: Use object() ?? true to match @AppStorage default for new users
                let autoCollapseEnabled = (UserDefaults.standard.object(forKey: "autoCollapseShelf") as? Bool) ?? true
                guard autoCollapseEnabled else { return }
                
                // DELAYED CLOSE: Wait 150ms to see if a drag operation starts
                // This prevents shelf from closing when user clicks to start dragging a file
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // Check if drag started during the delay - if so, don't close
                    guard !DragMonitor.shared.isDragging else { return }
                    
                    withAnimation(DroppyAnimation.transition) {
                        DroppyState.shared.expandedDisplayID = nil
                        DroppyState.shared.isMouseHovering = false
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
            
            // Get the notch rect and create a click zone
            let notchRect = targetWindow.getNotchRect()
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
                
                let notchRect = targetWindow.getNotchRect()
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

                let notchRect = targetWindow.getNotchRect()

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
                let isExpanded = DroppyState.shared.isExpanded
                var expandedShelfZone: NSRect = .zero
                if isExpanded {
                    let expandedWidth: CGFloat = 450
                    let centerX = targetScreen.frame.origin.x + targetScreen.frame.width / 2
                    
                    // Issue #64: Use unified height calculator (single source of truth)
                    let expandedHeight = DroppyState.expandedShelfHeight(for: targetScreen)

                    expandedShelfZone = NSRect(
                        x: centerX - expandedWidth / 2,
                        y: targetScreen.frame.origin.y + targetScreen.frame.height - expandedHeight,
                        width: expandedWidth,
                        height: expandedHeight
                    )
                }

                let isInNotchZone = clickZone.contains(mouseLocation)
                let isInExpandedShelfZone = isExpanded && expandedShelfZone.contains(mouseLocation)

                if isInNotchZone {
                    // ROCK-SOLID: Debounce rapid clicks to prevent toggle storms
                    let now = Date()
                    guard now.timeIntervalSince(self.lastNotchClickTime) > self.clickDebounceInterval else { return event }
                    self.lastNotchClickTime = now
                    
                    // Click on notch zone
                    // CRITICAL FIX: When shelf is expanded WITH ITEMS, don't intercept clicks!
                    // Let them pass through to SwiftUI item buttons (like the X to delete a file).
                    let hasItems = !DroppyState.shared.items.isEmpty
                    if isExpanded && hasItems {
                        // Shelf is expanded with items - let SwiftUI handle the click
                        return event
                    }
                    DispatchQueue.main.async {
                        withAnimation(DroppyAnimation.transition) {
                            DroppyState.shared.toggleShelfExpansion(for: targetScreen.displayID)
                        }
                    }
                    return nil  // Consume the click event
                } else if isExpanded && !isInExpandedShelfZone && !self.hasActiveContextMenu() {
                    // CLICK OUTSIDE TO CLOSE: Click is outside the shelf area
                    // Don't close if a context menu is active
                    // Don't close if auto-collapse is disabled (user wants manual control)
                    // CRITICAL: Use object() ?? true to match @AppStorage default for new users
                    let autoCollapseEnabled = (UserDefaults.standard.object(forKey: "autoCollapseShelf") as? Bool) ?? true
                    guard autoCollapseEnabled else { return event }
                    
                    // DELAYED CLOSE: Wait 150ms to see if a drag operation starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        // Check if drag started during the delay - if so, don't close
                        guard !DragMonitor.shared.isDragging else { return }
                        
                        withAnimation(DroppyAnimation.transition) {
                            DroppyState.shared.expandedDisplayID = nil
                            DroppyState.shared.isMouseHovering = false
                        }
                    }
                }
            }

            return event
        }
        
        // Keyboard monitor for spacebar Quick Look preview and Cmd+A select all
        // Local monitor - catches events when shelf is key window
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle when shelf is expanded and has items
            guard DroppyState.shared.isExpanded,
                  !DroppyState.shared.items.isEmpty else {
                return event
            }
            
            // Spacebar triggers Quick Look (skip if rename is active)
            if event.keyCode == 49, !DroppyState.shared.isRenaming {
                QuickLookHelper.shared.previewSelectedShelfItems()
                return nil // Consume the event
            }
            
            // Cmd+A selects all shelf items (but NOT when terminal is visible - let text selection work)
            if event.keyCode == 0, event.modifierFlags.contains(.command),
               !(TerminalNotchManager.shared.isInstalled && TerminalNotchManager.shared.isVisible) {
                DroppyState.shared.selectAll()
                return nil // Consume the event
            }
            
            return event
        }
        
        // Global keyboard monitor - catches spacebar when shelf is visible but not key window
        // This ensures Quick Look works even when clicking on items briefly loses focus
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Only handle when shelf is expanded and has items
            guard DroppyState.shared.isExpanded,
                  !DroppyState.shared.items.isEmpty else {
                return
            }
            
            // Only handle spacebar for Quick Look (not Cmd+A - that requires local focus)
            if event.keyCode == 49, !DroppyState.shared.isRenaming {
                // Check if mouse is over the shelf area (user intent to interact with shelf)
                let mouseLocation = NSEvent.mouseLocation
                if let (_, screen) = self?.findWindowForMouseLocation(mouseLocation) {
                    // Check if mouse is in the expanded shelf area
                    let expandedWidth: CGFloat = 450
                    let centerX = screen.frame.origin.x + screen.frame.width / 2
                    let rowCount = ceil(Double(DroppyState.shared.items.count) / 5.0)
                    let expandedHeight: CGFloat = CGFloat(max(1, rowCount) * 110 + 100)
                    
                    let shelfZone = NSRect(
                        x: centerX - expandedWidth / 2 - 20,
                        y: screen.frame.origin.y + screen.frame.height - expandedHeight - 20,
                        width: expandedWidth + 40,
                        height: expandedHeight + 40
                    )
                    
                    if shelfZone.contains(mouseLocation) {
                        QuickLookHelper.shared.previewSelectedShelfItems()
                    }
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
                guard screen.frame.contains(nsMouseLocation) else { continue }
                
                // Check if cursor is at the top of THIS specific screen
                let screenTop = screen.frame.maxY
                let isAtScreenTop = nsMouseLocation.y >= screenTop - 10  // Within 10px of screen top
                
                guard isAtScreenTop else { continue }
                
                // Check if cursor is within the notch X range
                let notchRect = window.getNotchRect()
                let isWithinNotchX = nsMouseLocation.x >= notchRect.minX - 40 && nsMouseLocation.x <= notchRect.maxX + 40
                
                if isWithinNotchX && !DroppyState.shared.isHovering(for: screen.displayID) {
                    // Cursor is at top edge of this screen within notch range - trigger hover!
                    let displayID = screen.displayID  // Capture for async block
                    DispatchQueue.main.async { [weak self] in
                        DroppyState.shared.validateItems()
                        withAnimation(DroppyAnimation.hoverBouncy) {
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
            _ = DroppyState.shared.isMouseHovering
            _ = DroppyState.shared.isDropTargeted
            _ = DroppyState.shared.items.count  // Track item count for dynamic window sizing
        } onChange: {
            // onChange fires BEFORE the property changes.
            // dispatch async to run update AFTER the change is applied.
            DispatchQueue.main.async { [weak self] in
                // Skip if hidden - prevents stale events and observation buildup
                guard let self = self, !self.isTemporarilyHidden else { return }
                
                self.updateAllWindowsMouseEventHandling()
                self.updateAllWindowsSize()  // Resize windows to fit content
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
        
        // Only resize if significantly different (avoid micro-updates)
        let currentHeight = window.frame.height
        if abs(newHeight - currentHeight) > 10 {
            // Resize from top - keep window anchored at screen top
            let newFrame = NSRect(
                x: window.frame.origin.x,
                y: screen.frame.origin.y + screen.frame.height - newHeight,
                width: window.frame.width,
                height: newHeight
            )
            window.setFrame(newFrame, display: false, animate: false)
            
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
        
        if deviation > sizeDeviationTolerance {
            // Size doesn't match - force correct it NOW
            let newFrame = NSRect(
                x: window.frame.origin.x,
                y: screen.frame.origin.y + screen.frame.height - expectedHeight,
                width: window.frame.width,
                height: expectedHeight
            )
            window.setFrame(newFrame, display: false, animate: false)
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
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
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
            // If shelf is enabled but window is ignoring events AND not in a valid ignore state
            if enableNotchShelf && window.ignoresMouseEvents {
                // Check if this is actually correct
                let isExpanded = DroppyState.shared.isExpanded
                let isHovering = DroppyState.shared.isMouseHovering
                
                // If shelf is expanded or mouse is hovering, window SHOULD accept events
                if isExpanded || isHovering {
                    // Throttle log to once per minute to avoid console spam
                    let now = Date()
                    if Self.lastWatchdogLogTime == nil || now.timeIntervalSince(Self.lastWatchdogLogTime!) > 60 {
                        print("⚠️ Watchdog: Self-healing - window stuck with ignoresMouseEvents=true")
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
                if Self.lastSizeHealLogTime == nil || now.timeIntervalSince(Self.lastSizeHealLogTime!) > 60 {
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
        // CRITICAL: Use object() ?? true to match @AppStorage default for new users
        guard (UserDefaults.standard.object(forKey: "autoExpandShelf") as? Bool) ?? true else { return }
        
        cancelAutoExpandTimer() // Reset if already running
        
        // Use configurable delay (0.5-2.0 seconds, default 1.0s)
        let delay = UserDefaults.standard.double(forKey: "autoExpandDelay")
        let actualDelay = delay > 0 ? delay : 1.0  // Fallback to 1.0s if not set
        autoExpandTimer = Timer.scheduledTimer(withTimeInterval: actualDelay, repeats: false) { [weak self] _ in
            guard self != nil else { return }
            
            // Check setting again (in case user disabled it during the delay)
            // CRITICAL: Use object() ?? true to match @AppStorage default
            guard (UserDefaults.standard.object(forKey: "autoExpandShelf") as? Bool) ?? true else { return }
            
            // Only expand if still hovering and not already expanded
            if DroppyState.shared.isMouseHovering && !DroppyState.shared.isExpanded {
                DispatchQueue.main.async {
                    withAnimation(DroppyAnimation.transition) {
                        if let displayID = displayID {
                            // Expand on the specific screen
                            DroppyState.shared.expandShelf(for: displayID)
                        } else {
                            // Fallback: Find screen containing mouse and expand that
                            let mouseLocation = NSEvent.mouseLocation
                            if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
                                DroppyState.shared.expandShelf(for: screen.displayID)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func cancelAutoExpandTimer() {
        autoExpandTimer?.invalidate()
        autoExpandTimer = nil
    }

    /// Routed event handler from monitors
    /// Only routes to the window whose screen contains the mouse - prevents race conditions
    private func handleMouseEvent(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        
        // Find which window should handle this event (the one whose screen contains the mouse)
        if let (window, _) = findWindowForMouseLocation(mouseLocation) {
            // Route event only to the window for this screen
            window.handleGlobalMouseEvent(event)
        } else {
            // Mouse is on a screen with no notch window - reset hover state
            // This handles rare edge cases (e.g., external monitor without shelf enabled)
            // and ensures hover state doesn't get stuck when mouse leaves all notch areas
            if DroppyState.shared.isMouseHovering {
                DispatchQueue.main.async {
                    withAnimation(DroppyAnimation.hoverBouncy) {
                        DroppyState.shared.isMouseHovering = false
                    }
                }
            }
        }
    }
    
    /// Accumulated horizontal scroll for swipe detection
    private var accumulatedScrollX: CGFloat = 0
    private var lastScrollTime: Date = .distantPast
    
    /// Handles scroll wheel events for 2-finger horizontal swipe media HUD toggle
    /// Swipe left = show media HUD, Swipe right = hide media HUD
    /// Works both when collapsed (hover state) and when expanded (shelf view)
    /// DISABLED when terminal is visible (terminal takes over the shelf)
    private func handleScrollEvent(_ event: NSEvent) {
        // Disable swipe when terminal is visible (terminal takes over the shelf)
        if TerminalNotchManager.shared.isInstalled && TerminalNotchManager.shared.isVisible {
            return
        }
        
        // Reset accumulated scroll if too much time has passed (new gesture)
        if Date().timeIntervalSince(lastScrollTime) > 0.3 {
            accumulatedScrollX = 0
        }
        lastScrollTime = Date()
        
        // Accumulate horizontal scroll
        accumulatedScrollX += event.scrollingDeltaX
        
        // Only handle when clearly horizontal swipe (X dominates Y by 1.5x)
        // And accumulated scroll exceeds threshold
        guard abs(accumulatedScrollX) > abs(event.scrollingDeltaY) * 1.5 else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        
        // Check if mouse is in notch/shelf area
        guard let (window, screen) = findWindowForMouseLocation(mouseLocation) else { return }
        let notchRect = window.getNotchRect()
        
        // Build swipe detection zone based on current state
        var swipeZone: NSRect
        if DroppyState.shared.isExpanded {
            // EXPANDED: Cover the full expanded shelf area
            let expandedWidth: CGFloat = 450
            let centerX = screen.frame.origin.x + screen.frame.width / 2
            let rowCount = max(1, ceil(Double(DroppyState.shared.items.count) / 5.0))
            let expandedHeight = rowCount * 110 + 100  // Extra height for safety
            
            swipeZone = NSRect(
                x: centerX - expandedWidth / 2,
                y: screen.frame.origin.y + screen.frame.height - expandedHeight,
                width: expandedWidth,
                height: expandedHeight
            )
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
        
        // Require accumulated scroll to exceed threshold before triggering
        let threshold: CGFloat = 30
        
        // Determine current effective state for media visibility
        let musicManager = MusicManager.shared
        
        if accumulatedScrollX < -threshold {
            // Swipe LEFT -> Show MEDIA player
            accumulatedScrollX = 0  // Reset after action
            // Force immediate SwiftUI update (fixes delay when cursor is stationary)
            musicManager.objectWillChange.send()
            // PREMIUM PARITY: Use .smooth(duration: 0.35) for content transitions
            withAnimation(DroppyAnimation.smoothContent) {
                musicManager.isMediaHUDForced = true
                musicManager.isMediaHUDHidden = false
            }
        } else if accumulatedScrollX > threshold {
            // Swipe RIGHT -> Show SHELF (hide media)
            accumulatedScrollX = 0  // Reset after action
            // Force immediate SwiftUI update (fixes delay when cursor is stationary)
            musicManager.objectWillChange.send()
            // PREMIUM PARITY: Use .smooth(duration: 0.35) for content transitions
            withAnimation(DroppyAnimation.smoothContent) {
                musicManager.isMediaHUDForced = false
                musicManager.isMediaHUDHidden = true
            }
        }
    }
}

// MARK: - Screen Helper

/// Helper to find the built-in display with a notch
extension NSScreen {
    /// Returns the built-in display (the one with a notch), regardless of which screen is "main"
    static var builtInWithNotch: NSScreen? {
        // First, try to find a screen with safeAreaInsets.top > 0 (has a notch)
        if let notchScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notchScreen
        }
        // Fallback to built-in display (localizedName contains "Built-in" or similar)
        return NSScreen.screens.first(where: { $0.localizedName.contains("Built-in") || $0.localizedName.contains("内蔵") })
    }

    /// Check if a point (in global screen coordinates) is on this screen
    func contains(point: NSPoint) -> Bool {
        return frame.contains(point)
    }
    
    /// Returns the Core Graphics display ID for this screen
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
    
    /// Returns true if this is the built-in MacBook display
    var isBuiltIn: Bool {
        // Check localized name for built-in indicators (multiple languages)
        let isNameBuiltIn = localizedName.contains("Built-in") || 
                            localizedName.contains("Internal") ||
                            localizedName.contains("内蔵") // Japanese
        // Alternative: Check if this screen has a notch (MacBook-specific)
        let hasNotch = safeAreaInsets.top > 0
        return isNameBuiltIn || hasNotch
    }
}

// MARK: - Custom Window Configuration

class NotchWindow: NSPanel {

    /// Flag to indicate if the window is still valid for event handling
    var isValid: Bool = true
    
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
        guard let screen = notchScreen else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
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
    private let dynamicIslandHeight: CGFloat = 37
    /// Top margin for Dynamic Island - creates floating effect like iPhone
    private let dynamicIslandTopMargin: CGFloat = 4
    
    private var notchRect: NSRect {
        guard let screen = notchScreen else { return .zero }

        // DYNAMIC ISLAND MODE: Floating pill centered below screen top edge
        if needsDynamicIsland {
            // Centered at top with margin (floating island effect like iPhone)
            // Use screen.frame.origin for global coordinates (multi-monitor support)
            let x = screen.frame.origin.x + (screen.frame.width - dynamicIslandWidth) / 2
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
        var notchHeight: CGFloat = 32
        // Use global screen coordinates for X position
        var notchX: CGFloat = screen.frame.origin.x + screen.frame.width / 2 - notchWidth / 2  // Fallback

        // Calculate true notch position and size from safe areas
        // The notch is the gap between the right edge of the left safe area
        // and the left edge of the right safe area
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            // Correct calculation: the gap between the two auxiliary areas
            notchWidth = max(rightArea.minX - leftArea.maxX, 180)
            // Derive X position directly from auxiliary areas (already in screen-local coordinates)
            // Convert to global coordinates by adding screen origin
            notchX = screen.frame.origin.x + leftArea.maxX
        }

        // Get notch height from safe area insets
        let topInset = screen.safeAreaInsets.top
        if topInset > 0 {
            notchHeight = topInset
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
            x: notchX,
            y: notchY,
            width: notchWidth,
            height: notchHeight
        )
    }
    
    /// Public accessor for the real hardware notch rect in screen coordinates
    func getNotchRect() -> NSRect {
        return notchRect
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
        // CRITICAL: Skip all hover tracking when a context menu is open
        // This prevents view re-renders that would dismiss submenus (Share, Compress, etc.)
        if NotchWindowController.shared.hasActiveContextMenu() {
            return
        }
        
        // Issue #60: Skip leftMouseDragged events unless already hovering
        // This prevents text selection in browsers from triggering the Dynamic Island
        // When user drags to select text, the cursor may pass through the notch zone briefly
        // We only want to respond to drags if the user was already hovering (intentional drag)
        if event.type == .leftMouseDragged && !DroppyState.shared.isMouseHovering {
            return
        }
        
        // SAFETY: Use the event's location properties instead of NSEvent.mouseLocation
        // class property to avoid race conditions with the HID event decoding system.
        // For global monitors, we need to convert the event location to screen coordinates.
        // Global events have locationInScreen as the screen-based location.
        let mouseLocation: NSPoint
        if (event.window?.screen ?? notchScreen) != nil {
            // Convert window-relative location to screen coordinates
            if event.window != nil {
                mouseLocation = event.window!.convertPoint(toScreen: event.locationInWindow)
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
        guard let targetScreen = notchScreen, targetScreen.frame.contains(mouseLocation) else {
            return
        }

        // PRECISE HOVER DETECTION (v5.2)
        // Different logic for NOTCH vs DYNAMIC ISLAND modes

        let isOverExactNotch = notchRect.contains(mouseLocation)
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
            let upwardExpansion = max(0, screenTopY - notchRect.maxY)

            let expandedNotchRect = NSRect(
                x: notchRect.origin.x - 20,                     // 20px expansion on left
                y: notchRect.origin.y,                          // Keep bottom edge EXACT (no downward expansion!)
                width: notchRect.width + 40,                    // 20px expansion on each side = 40px total
                height: notchRect.height + upwardExpansion      // Extend upward to screen top (covers the gap)
            )
            isOverExpandedZone = expandedNotchRect.contains(mouseLocation)

            // Special case: If cursor is at the absolute screen top edge within island X range,
            // always treat it as hovering (Fitt's Law - user slamming cursor to top)
            let isAtScreenTop = mouseLocation.y >= targetScreen.frame.maxY - 20  // Within 20px
            let isWithinIslandX = mouseLocation.x >= notchRect.minX - 30 && mouseLocation.x <= notchRect.maxX + 30
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
            let upwardExpansion = (screenTopY - notchRect.maxY) + 5  // +5px buffer to capture absolute edge

            let expandedNotchRect = NSRect(
                x: notchRect.origin.x - 20,                     // 20px expansion on left
                y: notchRect.origin.y,                          // Keep bottom edge exact (no downward expansion)
                width: notchRect.width + 40,                    // 20px expansion on each side = 40px total
                height: notchRect.height + upwardExpansion      // Extend to screen top edge + buffer
            )
            isOverExpandedZone = expandedNotchRect.contains(mouseLocation)

            // Special case: If cursor is at/near the absolute top of the screen and within notch X range,
            // always treat it as hovering. The tolerance needs to be generous because:
            // 1. When cursor hits screen edge, no more mouseMoved events are generated
            // 2. The last event before hitting the edge might have a Y slightly below maxY
            // 3. macOS may also report Y at or ABOVE maxY when cursor is at physical edge
            // 4. Menu bar is ~24px, notch is within that space, so 20px tolerance is safe
            let isAtScreenTop = mouseLocation.y >= targetScreen.frame.maxY - 20  // Within 20px of absolute top
            let isWithinNotchX = mouseLocation.x >= notchRect.minX - 30 && mouseLocation.x <= notchRect.maxX + 30
            if isAtScreenTop && isWithinNotchX {
                isOverExpandedZone = true
            }
        }

        // Use expanded zone to START hovering, exact zone to MAINTAIN hover
        // Exception: Also maintain hover at the screen top edge (Fitt's Law - user pushing against edge)
        let currentlyHovering = DroppyState.shared.isMouseHovering

        // For maintaining hover: exact notch OR at screen top within horizontal bounds
        var isOverExactOrEdge = isOverExactNotch
        let isAtScreenTop = mouseLocation.y >= targetScreen.frame.maxY - 15  // Within 15px
        let isWithinNotchX = mouseLocation.x >= notchRect.minX - 30 && mouseLocation.x <= notchRect.maxX + 30
        if isAtScreenTop && isWithinNotchX {
            isOverExactOrEdge = true
        }

        let isOverNotch = currentlyHovering ? isOverExactOrEdge : isOverExpandedZone

        // Only update if not dragging (drag monitor handles that)
        if !DragMonitor.shared.isDragging {
            if isOverNotch && !currentlyHovering {
                DispatchQueue.main.async {
                    // Validate items before showing shelf (remove ghost files)
                    DroppyState.shared.validateItems()

                    withAnimation(DroppyAnimation.hoverBouncy) {
                        DroppyState.shared.setHovering(for: targetScreen.displayID, isHovering: true)
                    }
                    // Start auto-expand timer with THIS screen's displayID
                    // Critical for multi-monitor: ensures correct screen expands
                    NotchWindowController.shared.startAutoExpandTimer(for: targetScreen.displayID)
                }
            } else if !isOverNotch && currentlyHovering && !DroppyState.shared.isExpanded {
                // Only reset hover if not expanded (expanded has its own area)
                DispatchQueue.main.async {
                    withAnimation(DroppyAnimation.hoverBouncy) {
                        DroppyState.shared.setHovering(for: targetScreen.displayID, isHovering: false)
                    }
                    NotchWindowController.shared.cancelAutoExpandTimer()
                }
            } else if DroppyState.shared.isExpanded(for: targetScreen.displayID) {
                // When shelf is expanded ON THIS SCREEN, check if cursor is in the expanded shelf zone
                // CRITICAL: Only check if THIS screen has the expanded shelf (not just any screen)
                // If so, maintain hover state to prevent auto-collapse
                let expandedWidth: CGFloat = 450
                let centerX = targetScreen.frame.origin.x + targetScreen.frame.width / 2
                
                // Issue #64: Use unified height calculator (single source of truth)
                let expandedHeight = DroppyState.expandedShelfHeight(for: targetScreen)
                
                let expandedShelfZone = NSRect(
                    x: centerX - expandedWidth / 2,
                    y: targetScreen.frame.origin.y + targetScreen.frame.height - expandedHeight,
                    width: expandedWidth,
                    height: expandedHeight
                )
                
                let isInExpandedShelf = expandedShelfZone.contains(mouseLocation)
                if isInExpandedShelf && !currentlyHovering {
                    DispatchQueue.main.async {
                        DroppyState.shared.setHovering(for: targetScreen.displayID, isHovering: true)
                    }
                }
                // Reset hover state if user moves OUT of the expanded shelf
                else if !isInExpandedShelf && currentlyHovering {
                    DispatchQueue.main.async {
                        DroppyState.shared.setHovering(for: targetScreen.displayID, isHovering: false)
                    }
                }
            } else if DroppyState.shared.isExpanded && currentlyHovering && !isOverNotch {
                // CRITICAL FIX (2-external-monitor bug):
                // Shelf is expanded on a DIFFERENT screen, and mouse is on THIS screen,
                // but NOT over this screen's notch. Reset hover state so the expanded
                // shelf on the other screen can auto-collapse.
                DispatchQueue.main.async {
                    DroppyState.shared.isMouseHovering = false
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
        
        // Safely capture state - avoid accessing shared singletons if they might be nil
        // Use local variables to minimize property access time
        let state = DroppyState.shared
        
        let isExpanded = state.isExpanded
        let isHovering = state.isMouseHovering
        let isDropTargeted = state.isDropTargeted
        let isDraggingFiles = DragMonitor.shared.isDragging
        
        // CRITICAL FIX (v7.0.2): When dragging, only accept events if drag is OVER the valid drop zone!
        // Previously we captured ALL drags, which blocked areas below the notch (bookmarks bar, etc.)
        // Now we check: is the drag actually over the notch? If not, let it pass through.
        var isDragOverValidZone = false
        if isDraggingFiles {
            let mouseLocation = NSEvent.mouseLocation
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
            if isExpanded && !isDragOverValidZone, let screen = notchScreen {
                let expandedWidth: CGFloat = 450
                // Use global coordinates
                let centerX = screen.frame.origin.x + screen.frame.width / 2
                
                // Issue #64: Use unified height calculator (single source of truth)
                let expandedHeight = DroppyState.expandedShelfHeight(for: screen)

                let expandedZone = NSRect(
                    x: centerX - expandedWidth / 2,
                    y: screen.frame.origin.y + screen.frame.height - expandedHeight,
                    width: expandedWidth,
                    height: expandedHeight
                )
                isDragOverValidZone = expandedZone.contains(mouseLocation)
            }
        }
        
        // CRITICAL FIX (v8.1.x): When shelf is DISABLED, the window should NOT block
        // for shelf-related interactions (hover, expand, drag-to-drop on notch).
        // User only wants floating basket, not the notch/island UI blocking their screen.
        // HUDs are handled separately and render passively without needing click interaction.
        // CRITICAL: Use object() ?? true to match @AppStorage defaults
        let enableNotchShelf = (UserDefaults.standard.object(forKey: "enableNotchShelf") as? Bool) ?? true
        
        // Window should accept mouse events when:
        // - Shelf is expanded AND shelf is enabled (need to interact with items)
        // - User is hovering over notch AND shelf is enabled (need click to open)
        // - Drop is actively targeted on the notch AND shelf is enabled
        // - User is dragging files AND they are OVER a valid drop zone AND shelf is enabled
        // When shelf is disabled, the window passes through ALL mouse events.
        // HUDs are display-only and don't require mouse hit detection.
        let shouldAcceptEvents = enableNotchShelf && (isExpanded || isHovering || isDropTargeted || isDragOverValidZone)
        
        // Only update if the value actually needs to change
        if self.ignoresMouseEvents == shouldAcceptEvents {
            self.ignoresMouseEvents = !shouldAcceptEvents
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
        
        let shouldHide = isFullscreen
        let newTargetAlpha: CGFloat = shouldHide ? 0.0 : 1.0
        
        // Only trigger animation if the TARGET has changed
        if self.targetAlpha != newTargetAlpha {
            self.targetAlpha = newTargetAlpha
            
            // Directly set alpha without animation to prevent Core Animation crashes
            self.alphaValue = newTargetAlpha
        }
        
        return shouldHide
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
        
        // Only become key when shelf is expanded and needs interaction
        return DroppyState.shared.isExpanded || DroppyState.shared.isMouseHovering
    }
}

// MARK: - Private SkyLight API for Fullscreen Space Detection
// These private APIs are used by Droppy and Droppy (via system APIs) for reliable fullscreen detection
private typealias CGSConnectionID = Int32
@_silgen_name("CGSMainConnectionID") private func CGSMainConnectionID() -> CGSConnectionID
@_silgen_name("CGSCopyManagedDisplaySpaces") private func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray?
