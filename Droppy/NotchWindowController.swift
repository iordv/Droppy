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
    
    /// Shared instance
    static let shared = NotchWindowController()
    
    private override init() {
        super.init()
    }
    
    deinit {
        stopMonitors()
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
        }
    }
    
    /// Creates a notch window for a specific screen
    private func createWindowForScreen(_ screen: NSScreen) {
        let displayID = screen.displayID
        
        // Window needs to be wide enough for expanded shelf and tall enough for glow + shelf
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 200

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
    
    /// Repositions notch windows when screen configuration changes (dock/undock)
    /// Also adds/removes windows for screens based on current settings
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
        
        // Add/remove/reposition windows for connected screens
        for screen in NSScreen.screens {
            let displayID = screen.displayID
            let shouldHaveWindow = !hideOnExternal || screen.isBuiltIn
            
            if shouldHaveWindow {
                if let window = notchWindows[displayID] {
                    // Reposition existing window
                    let windowWidth: CGFloat = 500
                    let windowHeight: CGFloat = 200
                    let xPosition = screen.frame.origin.x + (screen.frame.width - windowWidth) / 2
                    let yPosition = screen.frame.origin.y + screen.frame.height - windowHeight
                    let newFrame = NSRect(x: xPosition, y: yPosition, width: windowWidth, height: windowHeight)
                    window.setFrame(newFrame, display: true, animate: false)
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
                  UserDefaults.standard.bool(forKey: "enableNotchShelf") else { return }
            
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
                let rowCount = ceil(Double(DroppyState.shared.items.count) / 5.0)
                var expandedHeight = max(1, rowCount) * 110 + 54
                
                // Add extra height for media player when shelf is empty but music is playing
                let shouldShowPlayer = MusicManager.shared.isPlaying || MusicManager.shared.wasRecentlyPlaying
                if DroppyState.shared.items.isEmpty && shouldShowPlayer && !MusicManager.shared.isPlayerIdle {
                    expandedHeight += 100
                }

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
                // Click on notch - toggle shelf
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        DroppyState.shared.isExpanded.toggle()
                    }
                }
            } else if isExpanded && !isInExpandedShelfZone && !self.hasActiveContextMenu() {
                // CLICK OUTSIDE TO CLOSE: Shelf is open, click is outside shelf area
                // Don't close if a context menu is active (user is interacting with submenu)
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        DroppyState.shared.isExpanded = false
                        DroppyState.shared.isMouseHovering = false
                    }
                }
            }
        }
        
        // Local monitor catches movement AND clicks when mouse is over the Notch window
        // Global monitor only catches events from OTHER apps - we need local for our own window
        // Also handles closing shelf when clicking outside the shelf area
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] event in
            guard let self = self else { return event }

            // Handle mouse movement
            if event.type == .mouseMoved {
                self.handleMouseEvent(event)
                return event
            }

            // Handle click - single-click shelf toggle and click-outside-to-close
            if event.type == .leftMouseDown {
                guard UserDefaults.standard.bool(forKey: "enableNotchShelf") else { return event }

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
                    let rowCount = ceil(Double(DroppyState.shared.items.count) / 5.0)
                    var expandedHeight = max(1, rowCount) * 110 + 54
                    
                    // Add extra height for media player when shelf is empty but music is playing
                    let shouldShowPlayer = MusicManager.shared.isPlaying || MusicManager.shared.wasRecentlyPlaying
                    if DroppyState.shared.items.isEmpty && shouldShowPlayer && !MusicManager.shared.isPlayerIdle {
                        expandedHeight += 100
                    }

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
                    // Click on notch - toggle shelf
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            DroppyState.shared.isExpanded.toggle()
                        }
                    }
                    return nil  // Consume the click event
                } else if isExpanded && !isInExpandedShelfZone && !self.hasActiveContextMenu() {
                    // CLICK OUTSIDE TO CLOSE: Click is outside the shelf area
                    // Don't close if a context menu is active
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            DroppyState.shared.isExpanded = false
                            DroppyState.shared.isMouseHovering = false
                        }
                    }
                    return nil  // Consume the click event
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
            
            // Cmd+A selects all shelf items
            if event.keyCode == 0, event.modifierFlags.contains(.command) {
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
                  UserDefaults.standard.bool(forKey: "enableNotchShelf"),
                  !DroppyState.shared.isExpanded,  // Don't need edge detection when expanded
                  !DragMonitor.shared.isDragging   // Drag monitor handles its own detection
            else { return }
            
            // Use CGEvent to get raw cursor position - works even at screen edge
            guard let cgEvent = CGEvent(source: nil) else { return }
            let cgPoint = cgEvent.location
            
            // Convert CG coordinates to NS coordinates for proper multi-monitor support
            // CG: Y=0 at top of main display, increases downward
            // NS: Y=0 at bottom of main display, increases upward
            // The conversion: nsY = mainScreenHeight - cgY
            guard let mainScreen = NSScreen.screens.first else { return }
            let mainScreenHeight = mainScreen.frame.height
            let nsMouseLocation = NSPoint(x: cgPoint.x, y: mainScreenHeight - cgPoint.y)
            
            // Check each window to see if cursor is at the top edge of its screen
            for window in self.notchWindows.values {
                guard let screen = window.notchScreen else { continue }
                
                // Check if cursor is at the top of THIS specific screen
                let screenTop = screen.frame.maxY
                let isAtScreenTop = nsMouseLocation.y >= screenTop - 10  // Within 10px of screen top
                
                guard isAtScreenTop else { continue }
                
                // Check if cursor is within the notch X range
                let notchRect = window.getNotchRect()
                let isWithinNotchX = nsMouseLocation.x >= notchRect.minX - 40 && nsMouseLocation.x <= notchRect.maxX + 40
                
                if isWithinNotchX && !DroppyState.shared.isMouseHovering {
                    // Cursor is at top edge of this screen within notch range - trigger hover!
                    DispatchQueue.main.async {
                        DroppyState.shared.validateItems()
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            DroppyState.shared.isMouseHovering = true
                        }
                        // Start auto-expand timer
                        self.startAutoExpandTimer()
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
        // Track the specific properties that affect mouse event handling
        withObservationTracking {
            _ = DroppyState.shared.isExpanded
            _ = DroppyState.shared.isMouseHovering
            _ = DroppyState.shared.isDropTargeted
        } onChange: {
            // onChange fires BEFORE the property changes.
            // dispatch async to run update AFTER the change is applied.
            DispatchQueue.main.async { [weak self] in
                self?.updateAllWindowsMouseEventHandling()
                // Must re-register observation after it fires (one-shot)
                self?.setupStateObservation()
            }
        }
    }
    
    /// Updates mouse event handling for all notch windows
    private func updateAllWindowsMouseEventHandling() {
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
    }
    
    private func checkFullscreenState() {
        for window in notchWindows.values {
            window.checkForFullscreen()
        }
    }
    
    /// Start timer to auto-expand shelf if hovering persists
    func startAutoExpandTimer() {
        guard UserDefaults.standard.bool(forKey: "autoExpandShelf") else { return }
        
        cancelAutoExpandTimer() // Reset if already running
        
        // 0.5s delay as requested
        autoExpandTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard self != nil else { return }
            
            // Check setting again (in case user disabled it during the delay)
            guard UserDefaults.standard.bool(forKey: "autoExpandShelf") else { return }
            
            // Only expand if still hovering and not already expanded
            if DroppyState.shared.isMouseHovering && !DroppyState.shared.isExpanded {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        DroppyState.shared.isExpanded = true
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
            // Mouse is on a screen with no notch window - clear hover if needed
            if DroppyState.shared.isMouseHovering && !DroppyState.shared.isExpanded {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
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
    private func handleScrollEvent(_ event: NSEvent) {
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
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    // Show media: set forced true, hidden false
                    musicManager.isMediaHUDForced = true
                    musicManager.isMediaHUDHidden = false
                }
            }
        } else if accumulatedScrollX > threshold {
            // Swipe RIGHT -> Show SHELF (hide media)
            accumulatedScrollX = 0  // Reset after action
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    // Hide media: set forced false, hidden true
                    musicManager.isMediaHUDForced = false
                    musicManager.isMediaHUDHidden = true
                }
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
                return UserDefaults.standard.bool(forKey: "externalDisplayUseDynamicIsland")
            }
            return true  // Default: use Dynamic Island on external displays
        }
        
        // Built-in display uses main Dynamic Island setting
        // Check if the key exists, otherwise use default value of true
        var useDynamicIsland = true  // Default
        if UserDefaults.standard.object(forKey: "useDynamicIslandStyle") != nil {
            useDynamicIsland = UserDefaults.standard.bool(forKey: "useDynamicIslandStyle")
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

                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        DroppyState.shared.isMouseHovering = true
                    }
                    // Start auto-expand timer
                    NotchWindowController.shared.startAutoExpandTimer()
                }
            } else if !isOverNotch && currentlyHovering && !DroppyState.shared.isExpanded {
                // Only reset hover if not expanded (expanded has its own area)
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        DroppyState.shared.isMouseHovering = false
                    }
                    NotchWindowController.shared.cancelAutoExpandTimer()
                }
            } else if DroppyState.shared.isExpanded {
                // When shelf is expanded, check if cursor is in the expanded shelf zone
                // If so, maintain hover state to prevent auto-collapse
                let expandedWidth: CGFloat = 450
                let centerX = targetScreen.frame.origin.x + targetScreen.frame.width / 2
                let rowCount = ceil(Double(DroppyState.shared.items.count) / 5.0)
                var expandedHeight = max(1, rowCount) * 110 + 54
                
                // Add media player height if needed
                let shouldShowPlayer = MusicManager.shared.isPlaying || MusicManager.shared.wasRecentlyPlaying
                if DroppyState.shared.items.isEmpty && shouldShowPlayer && !MusicManager.shared.isPlayerIdle {
                    expandedHeight += 100
                }
                
                let expandedShelfZone = NSRect(
                    x: centerX - expandedWidth / 2,
                    y: targetScreen.frame.origin.y + targetScreen.frame.height - expandedHeight,
                    width: expandedWidth,
                    height: expandedHeight
                )
                
                let isInExpandedShelf = expandedShelfZone.contains(mouseLocation)
                if isInExpandedShelf && !currentlyHovering {
                    DispatchQueue.main.async {
                        DroppyState.shared.isMouseHovering = true
                    }
                }
                // Reset hover state if user moves OUT of the expanded shelf
                else if !isInExpandedShelf && currentlyHovering {
                    DispatchQueue.main.async {
                        DroppyState.shared.isMouseHovering = false
                    }
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
                let rowCount = ceil(Double(state.items.count) / 5.0)
                let expandedHeight = max(1, rowCount) * 110 + 54

                let expandedZone = NSRect(
                    x: centerX - expandedWidth / 2,
                    y: screen.frame.origin.y + screen.frame.height - expandedHeight,
                    width: expandedWidth,
                    height: expandedHeight
                )
                isDragOverValidZone = expandedZone.contains(mouseLocation)
            }
        }
        
        // Window should accept mouse events when:
        // - Shelf is expanded (need to interact with items)
        // - User is hovering over notch (need click to open)
        // - Drop is actively targeted on the notch
        // - User is dragging files AND they are OVER a valid drop zone
        // CRITICAL: We now check isDragOverValidZone instead of just isDraggingFiles!
        // This ensures drags below the notch pass through to other apps.
        let shouldAcceptEvents = isExpanded || isHovering || isDropTargeted || isDragOverValidZone
        
        // Only update if the value actually needs to change
        if self.ignoresMouseEvents == shouldAcceptEvents {
            self.ignoresMouseEvents = !shouldAcceptEvents
        }
    }
    
    func checkForFullscreen() {
        // Use notchScreen for multi-monitor support
        guard let screen = notchScreen else { return }

        // 1. Check basic visible frame (Standard Spaces Fullscreen)
        let isNativeFullscreen = screen.visibleFrame.equalTo(screen.frame)
        
        // 2. Check frontmost application presentation options (Games/Video Players)
        // Note: NSRunningApplication does not expose presentationOptions. 
        // We rely on visibleFrame check which detects if Menu Bar / Dock are hidden.
        
        let shouldHide = isNativeFullscreen
        let newTargetAlpha: CGFloat = shouldHide ? 0.0 : 1.0
        
        // Only trigger animation if the TARGET has changed, not just because current alpha is in flux
        if self.targetAlpha != newTargetAlpha {
            self.targetAlpha = newTargetAlpha
            
            // Directly set alpha without animation to prevent Core Animation / WindowServer crashes
            // The previous NSAnimationContext approach caused 'stepTransactionFlush' crashes on some systems
            self.alphaValue = newTargetAlpha
        }
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


