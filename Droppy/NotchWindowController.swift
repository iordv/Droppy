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
    /// The notch overlay window
    private var notchWindow: NotchWindow?
    
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
    
    /// Shared instance
    static let shared = NotchWindowController()
    
    private override init() {
        super.init()
    }
    
    deinit {
        stopMonitors()
    }
    
    /// Sets up and shows the notch overlay window
    func setupNotchWindow() {
        guard notchWindow == nil else { return }
        guard let screen = NSScreen.main else { return }
        
        // Window needs to be wide enough for expanded shelf and tall enough for glow + shelf
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 200
        
        // Position at top center of screen (aligned with notch)
        let xPosition = (screen.frame.width - windowWidth) / 2
        let yPosition = screen.frame.height - windowHeight
        
        let windowFrame = NSRect(
            x: xPosition,
            y: yPosition,
            width: windowWidth,
            height: windowHeight
        )
        
        // Create the custom window
        let window = NotchWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Set up the view hierarchy
        // 1. Create the SwiftUI view
        let notchView = NotchShelfView(state: DroppyState.shared)
        let hostingView = NSHostingView(rootView: notchView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        
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
        
        self.notchWindow = window
        
        // Apply screenshot visibility setting
        updateScreenshotVisibility()
        
        startMonitors()
    }
    
    /// Updates the window's visibility in screenshots based on user preference
    func updateScreenshotVisibility() {
        let hideFromScreenshots = UserDefaults.standard.bool(forKey: "hideNotchFromScreenshots")
        notchWindow?.sharingType = hideFromScreenshots ? .none : .readOnly
    }
    
    /// Closes the notch window
    func closeWindow() {
        stopMonitors()
        notchWindow?.isValid = false  // Mark as invalid before closing
        notchWindow?.close()
        notchWindow = nil
    }
    
    /// Repositions the notch window when screen configuration changes (dock/undock)
    private func repositionNotchWindow() {
        guard let window = notchWindow, let screen = NSScreen.main else { return }
        
        // Use same dimensions as setupNotchWindow
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 200
        
        // Recalculate position for new screen geometry
        let xPosition = (screen.frame.width - windowWidth) / 2
        let yPosition = screen.frame.height - windowHeight
        
        let newFrame = NSRect(
            x: xPosition,
            y: yPosition,
            width: windowWidth,
            height: windowHeight
        )
        
        // Reposition the window silently without animation
        window.setFrame(newFrame, display: true, animate: false)
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
                self?.notchWindow?.updateMouseEventHandling()
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
        
        // GLOBAL CLICK MONITOR (v5.2) - Enables true single-click shelf opening
        // This catches clicks even when Droppy isn't focused, enabling instant shelf opening
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self,
                  let notchWindow = self.notchWindow,
                  UserDefaults.standard.bool(forKey: "enableNotchShelf") else { return }
            
            // Get the notch rect
            let notchRect = notchWindow.getNotchRect()
            let mouseLocation = NSEvent.mouseLocation
            
            // Only handle clicks directly over the notch
            if notchRect.contains(mouseLocation) {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        DroppyState.shared.isExpanded.toggle()
                    }
                }
            }
        }
        
        // Local monitor catches movement AND clicks when mouse is over the Notch window
        // Global monitor only catches events from OTHER apps - we need local for our own window
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            
            // Handle mouse movement
            if event.type == .mouseMoved {
                self.handleMouseEvent(event)
                return event
            }
            
            // Handle click - single-click shelf toggle
            if event.type == .leftMouseDown {
                guard let notchWindow = self.notchWindow,
                      UserDefaults.standard.bool(forKey: "enableNotchShelf") else { return event }
                
                let notchRect = notchWindow.getNotchRect()
                let mouseLocation = NSEvent.mouseLocation
                
                // Only handle clicks directly over the notch
                if notchRect.contains(mouseLocation) {
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            DroppyState.shared.isExpanded.toggle()
                        }
                    }
                    return nil  // Consume the click event
                }
            }
            
            return event
        }
        
        // Keyboard monitor for spacebar Quick Look preview
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle spacebar when shelf is expanded and has items
            if event.keyCode == 49, // Spacebar
               DroppyState.shared.isExpanded,
               !DroppyState.shared.items.isEmpty {
                QuickLookHelper.shared.previewSelectedShelfItems()
                return nil // Consume the event
            }
            return event
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
                self?.notchWindow?.updateMouseEventHandling()
                // Must re-register observation after it fires (one-shot)
                self?.setupStateObservation()
            }
        }
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
    }
    
    private func checkFullscreenState() {
        guard let window = notchWindow else { return }
        window.checkForFullscreen()
    }
    
    /// Routed event handler from monitors
    private func handleMouseEvent(_ event: NSEvent) {
        // Only proceed if window is still alive
        guard let window = notchWindow else { return }
        window.handleGlobalMouseEvent(event)
    }
}

// MARK: - Custom Window Configuration

class NotchWindow: NSWindow {
    
    /// Flag to indicate if the window is still valid for event handling
    var isValid: Bool = true
    
    /// Whether the current screen lacks a physical notch
    private var needsDynamicIsland: Bool {
        guard let screen = NSScreen.main else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let useDynamicIsland = UserDefaults.standard.bool(forKey: "useDynamicIslandStyle")
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        // Use Dynamic Island if: no physical notch OR force test is enabled (and style is enabled)
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    /// Dynamic Island dimensions
    private let dynamicIslandWidth: CGFloat = 210
    private let dynamicIslandHeight: CGFloat = 37
    
    private var notchRect: NSRect {
        guard let screen = NSScreen.main else { return .zero }
        
        // DYNAMIC ISLAND MODE: Floating pill centered at top
        if needsDynamicIsland {
            let x = (screen.frame.width - dynamicIslandWidth) / 2
            // Position directly below menu bar (no margin to keep hit areas aligned)
            let y = screen.frame.height - 24 - dynamicIslandHeight
            
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
        var notchX: CGFloat = screen.frame.width / 2 - notchWidth / 2  // Fallback
        
        // Calculate true notch position and size from safe areas
        // The notch is the gap between the right edge of the left safe area
        // and the left edge of the right safe area
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            // Correct calculation: the gap between the two auxiliary areas
            notchWidth = max(rightArea.minX - leftArea.maxX, 180)
            // Derive X position directly from auxiliary areas (more robust)
            notchX = leftArea.maxX
        }
        
        // Get notch height from safe area insets
        let topInset = screen.safeAreaInsets.top
        if topInset > 0 {
            notchHeight = topInset
        }
        
        return NSRect(
            x: notchX,
            y: screen.frame.height - notchHeight,
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
        // SAFETY: Use the event's location properties instead of NSEvent.mouseLocation
        // class property to avoid race conditions with the HID event decoding system.
        // For global monitors, we need to convert the event location to screen coordinates.
        // Global events have locationInScreen as the screen-based location.
        let mouseLocation: NSPoint
        if (event.window?.screen ?? NSScreen.main) != nil {
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
        
        // PRECISE HOVER DETECTION (v5.2)
        // The hardware notch is small (~180x32px). Fast cursor movements can skip over it.
        // Extend detection zone UPWARD to the screen's top edge (Fitt's Law - screen edge is "infinite")
        // but NOT downward (to avoid blocking bookmark bars, menu items, etc.)
        // Horizontal: small expansion for fast side-to-side movements
        let screenTopY = NSScreen.main?.frame.maxY ?? notchRect.maxY
        let upwardExpansion = (screenTopY - notchRect.maxY) + 5  // +5px buffer to capture absolute edge
        
        let expandedNotchRect = NSRect(
            x: notchRect.origin.x - 20,                     // 20px expansion on left
            y: notchRect.origin.y,                          // Keep bottom edge exact (no downward expansion)
            width: notchRect.width + 40,                    // 20px expansion on each side = 40px total
            height: notchRect.height + upwardExpansion      // Extend to screen top edge + buffer
        )
        let isOverExactNotch = notchRect.contains(mouseLocation)
        var isOverExpandedZone = expandedNotchRect.contains(mouseLocation)
        
        // Special case: If cursor is at/near the absolute top of the screen and within notch X range,
        // always treat it as hovering. The tolerance needs to be generous because:
        // 1. When cursor hits screen edge, no more mouseMoved events are generated
        // 2. The last event before hitting the edge might have a Y slightly below maxY
        // 3. Menu bar is ~24px, notch is within that space, so 10px tolerance is safe
        if let screen = NSScreen.main {
            let isAtScreenTop = mouseLocation.y >= screen.frame.maxY - 10  // Within 10px of absolute top
            let isWithinNotchX = mouseLocation.x >= notchRect.minX - 20 && mouseLocation.x <= notchRect.maxX + 20
            if isAtScreenTop && isWithinNotchX {
                isOverExpandedZone = true
            }
        }
        
        // Use expanded zone to START hovering, exact zone to MAINTAIN hover
        // This ensures fast cursor movements are caught, but exit detection remains precise
        let currentlyHovering = DroppyState.shared.isMouseHovering
        let isOverNotch = currentlyHovering ? isOverExactNotch : isOverExpandedZone
        
        // Only update if not dragging (drag monitor handles that)
        if !DragMonitor.shared.isDragging {
            if isOverNotch && !currentlyHovering {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        DroppyState.shared.isMouseHovering = true
                    }
                }
            } else if !isOverNotch && currentlyHovering && !DroppyState.shared.isExpanded {
                // Only reset hover if not expanded (expanded has its own area)
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
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
        
        // Window should accept mouse events when:
        // - Shelf is expanded (need to interact with items)
        // - User is hovering over notch (need click to open)
        // - User is dragging files anywhere (need to receive NSDraggingDestination callbacks)
        // - Drop is actively targeted on the notch
        // IMPORTANT: When ignoresMouseEvents = true, NSDraggingDestination methods are ALSO blocked!
        // We MUST include isDraggingFiles to ensure drag/drop events are received.
        let shouldAcceptEvents = isExpanded || isHovering || isDropTargeted || isDraggingFiles
        
        // Only update if the value actually needs to change
        if self.ignoresMouseEvents == shouldAcceptEvents {
            self.ignoresMouseEvents = !shouldAcceptEvents
        }
    }
    
    func checkForFullscreen() {
        guard let screen = NSScreen.main else { return }
        
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
    
    // Ensure the window can become key to receive input
    override var canBecomeKey: Bool {
        return true
    }
}

// MARK: - Drag Handling Container View

class NotchDragContainer: NSView {
    
    weak var hostingView: NSView?
    private var filePromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    private var trackingArea: NSTrackingArea?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        // Drag types
        var types: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .URL,
            .string,
            NSPasteboard.PasteboardType(UTType.data.identifier),
            NSPasteboard.PasteboardType(UTType.item.identifier),
            // Email types for Mail.app
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeMessageTransfer"),
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeAutomator"),
            NSPasteboard.PasteboardType("com.apple.mail.message"),
            NSPasteboard.PasteboardType(UTType.emailMessage.identifier)
        ]
        
        // Add file promise types
        types.append(contentsOf: NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        
        registerForDraggedTypes(types)
        
        // SETUP TRACKING AREA FOR HOVER
        updateTrackingAreas()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = self.trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    // MARK: - Mouse Tracking Methods
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // Global monitor in NotchWindow handles hover detection
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // Global monitor in NotchWindow handles hover detection
        // We don't update state here to avoid conflicts
    }
    
    // MARK: - Single-Click Handling (v5.2)
    // Handle direct clicks on the notch to open shelf with single click
    // This bypasses the issue where first click focuses app and second opens shelf
    override func mouseDown(with event: NSEvent) {
        // Only proceed if notch shelf is enabled
        guard UserDefaults.standard.bool(forKey: "enableNotchShelf") else {
            super.mouseDown(with: event)
            return
        }
        
        // Only handle clicks when user is already hovering (intentional interaction)
        // This ensures we don't block clicks that should pass through to other apps
        guard DroppyState.shared.isMouseHovering else {
            super.mouseDown(with: event)
            return
        }
        
        // Verify click is over the actual notch area (not the expanded detection zone)
        guard let notchWindow = self.window as? NotchWindow else {
            super.mouseDown(with: event)
            return
        }
        
        let mouseLocation = NSEvent.mouseLocation
        let notchRect = notchWindow.getNotchRect()
        
        // Use exact notch rect for click handling to avoid blocking bookmark bars etc
        guard notchRect.contains(mouseLocation) else {
            super.mouseDown(with: event)
            return
        }
        
        // Toggle the shelf expansion
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                DroppyState.shared.isExpanded.toggle()
            }
        }
        // Don't call super - we consumed this click
    }
    
    // We don't need to handle mouseEntered/Exited/Moved here specifically if the SwiftUI view handles it,
    // BUT for a transparent window, the window/view needs to 'see' the mouse.
    // By adding the tracking area, we ensure AppKit wakes up for this view.
    
    // Pass mouse events down to SwiftUI if not handled
    // Pass mouse events down to SwiftUI if not handled
    override func hitTest(_ point: NSPoint) -> NSView? {
        // We want to be selective about when we intercept events vs letting them pass through to apps below.
        
        // 1. Convert point to view coordinates
        let localPoint = convert(point, from: nil)
        
        // 2. Check current state
        let isExpanded = DroppyState.shared.isExpanded
        let isDragging = DragMonitor.shared.isDragging || DroppyState.shared.isDropTargeted
        
        // 3. Define the active interaction area
        // If expanded, the whole expanded area is interactive
        if isExpanded {
            // Expanded shelf is roughly top 450px width, variable height
            // But we can just rely on the SwiftUI view's frame if possible.
            // Since we don't know the exact SwiftUI frame here easily, we can estimate:
            // Expanded width is 450. Centered.
            let expandedWidth: CGFloat = 450
            let centerX = bounds.midX
            let xRange = (centerX - expandedWidth/2)...(centerX + expandedWidth/2)
            
            // Height calculation from NotchShelfView (approx)
            let rowCount = (Double(DroppyState.shared.items.count) / 5.0).rounded(.up)
            var expandedHeight = max(1, rowCount) * 110 + 54
            
            // Add extra height for media player when shelf is empty but music is playing (or recently paused)
            let shouldShowPlayer = MusicManager.shared.isPlaying || MusicManager.shared.wasRecentlyPlaying
            if DroppyState.shared.items.isEmpty && shouldShowPlayer && !MusicManager.shared.isPlayerIdle {
                expandedHeight += 100
            }
             
            // Y is from top (bounds.height) down to (bounds.height - expandedHeight)
            let yRange = (bounds.height - expandedHeight)...bounds.height
            
            if xRange.contains(localPoint.x) && yRange.contains(localPoint.y) {
                 return super.hitTest(point)
            }
            
            // ALSO accept drops at the notch area when expanded (user might drop before moving into shelf)
            if isDragging {
                guard let notchWindow = self.window as? NotchWindow else { return nil }
                let realNotchRect = notchWindow.getNotchRect()
                let mouseScreenPos = NSEvent.mouseLocation
                if realNotchRect.contains(mouseScreenPos) {
                    return super.hitTest(point)
                }
            }
        }
        
        // If dragging, intercept if mouse is over notch OR over the expanded shelf area
        if isDragging {
            let mouseScreenPos = NSEvent.mouseLocation
            
            // Get the real hardware notch rect
            guard let notchWindow = self.window as? NotchWindow else { return nil }
            let realNotchRect = notchWindow.getNotchRect()
            
            // Accept drags over the real notch
            if realNotchRect.contains(mouseScreenPos) {
                return super.hitTest(point)
            }
            
            // When expanded, also accept drags over the expanded shelf area
            if DroppyState.shared.isExpanded {
                guard let screen = NSScreen.main else { return nil }
                
                let expandedWidth: CGFloat = 450
                let centerX = screen.frame.width / 2
                let xMin = centerX - expandedWidth / 2
                let xMax = centerX + expandedWidth / 2
                
                let rowCount = ceil(Double(DroppyState.shared.items.count) / 5.0)
                var expandedHeight = max(1, rowCount) * 110 + 54
                
                let shouldShowPlayer = MusicManager.shared.isPlaying || MusicManager.shared.wasRecentlyPlaying
                if DroppyState.shared.items.isEmpty && shouldShowPlayer && !MusicManager.shared.isPlayerIdle {
                    expandedHeight += 100
                }
                
                let yMin = screen.frame.height - expandedHeight
                let yMax = screen.frame.height
                
                if mouseScreenPos.x >= xMin && mouseScreenPos.x <= xMax &&
                   mouseScreenPos.y >= yMin && mouseScreenPos.y <= yMax {
                    return super.hitTest(point)
                }
            }
            
            // Outside valid drop zones - let the drag pass through to other apps
            return nil
        }
        
        // If Idle (just hovering to open), strict notch area
        // Notch is ~160-180 wide, ~32 high.
        // User complained the activation area is too wide and blocks browser URL bars (which are below the menu bar).
        // Strategy: 
        // 1. Default "Sleep" state: VERY strict area. Just the notch + tiny margin. 
        //    Height <= 44 to stay within standard menu bar height.
        // 2. "Hovering" state: If user triggered hover, expand area to include the "Open Shelf" button so they can click it.
        
        let isHovering = DroppyState.shared.isMouseHovering
        
        if isHovering {
             // Expand to include the "Open Shelf" indicator (offset y ~80, height ~30-40)
             let hoverWidth: CGFloat = 240
             let hoverHeight: CGFloat = 120
             
             let centerX = bounds.midX
             let xRange = (centerX - hoverWidth/2)...(centerX + hoverWidth/2)
             let yRange = (bounds.height - hoverHeight)...bounds.height
             
             if xRange.contains(localPoint.x) && yRange.contains(localPoint.y) {
                  return super.hitTest(point)
             }
        }

        // IDLE STATE: Pass through ALL events to underlying apps.
        // The hover detection is handled by the tracking area, not hitTest.
        // This ensures we don't block Safari URL bars, Outlook search fields, etc.
        // The user can still trigger hover by moving into the notch area,
        // and once isMouseHovering is true, we capture events above.
        return nil
    }
    
    // MARK: - NSDraggingDestination Methods
    
    /// Helper to check if a drag location is over the real hardware notch
    private func isDragOverNotch(_ sender: NSDraggingInfo) -> Bool {
        guard let notchWindow = self.window as? NotchWindow else { return false }
        let notchRect = notchWindow.getNotchRect()
        let dragLocation = sender.draggingLocation
        
        // Convert from window coordinates to screen coordinates
        guard let windowFrame = self.window?.frame else { return false }
        let screenLocation = NSPoint(x: windowFrame.origin.x + dragLocation.x, 
                                     y: windowFrame.origin.y + dragLocation.y)
        
        return notchRect.contains(screenLocation)
    }
    
    /// Helper to check if a drag is over the expanded shelf area
    private func isDragOverExpandedShelf(_ sender: NSDraggingInfo) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let dragLocation = sender.draggingLocation
        
        // Convert from window coordinates to screen coordinates
        guard let windowFrame = self.window?.frame else { return false }
        let screenLocation = NSPoint(x: windowFrame.origin.x + dragLocation.x,
                                     y: windowFrame.origin.y + dragLocation.y)
        
        // Calculate expanded shelf bounds (same logic as hitTest)
        let expandedWidth: CGFloat = 450
        let centerX = screen.frame.width / 2
        let xMin = centerX - expandedWidth / 2
        let xMax = centerX + expandedWidth / 2
        
        // Height calculation
        let rowCount = ceil(Double(DroppyState.shared.items.count) / 5.0)
        var expandedHeight = max(1, rowCount) * 110 + 54
        
        // Add extra height for media player
        let shouldShowPlayer = MusicManager.shared.isPlaying || MusicManager.shared.wasRecentlyPlaying
        if DroppyState.shared.items.isEmpty && shouldShowPlayer && !MusicManager.shared.isPlayerIdle {
            expandedHeight += 100
        }
        
        let yMin = screen.frame.height - expandedHeight
        let yMax = screen.frame.height
        
        return screenLocation.x >= xMin && screenLocation.x <= xMax &&
               screenLocation.y >= yMin && screenLocation.y <= yMax
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let overNotch = isDragOverNotch(sender)
        let isExpanded = DroppyState.shared.isExpanded
        let overExpandedArea = isExpanded && isDragOverExpandedShelf(sender)
        
        // Accept drags over the notch OR over the expanded shelf area
        guard overNotch || overExpandedArea else {
            return [] // Reject - let drag pass through to other apps
        }
        
        // Highlight UI when over a valid drop zone
        let shouldBeTargeted = (overNotch && !isExpanded) || overExpandedArea
        if shouldBeTargeted {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    DroppyState.shared.isDropTargeted = true
                }
            }
        }
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let overNotch = isDragOverNotch(sender)
        let isExpanded = DroppyState.shared.isExpanded
        let overExpandedArea = isExpanded && isDragOverExpandedShelf(sender)
        
        DispatchQueue.main.async {
            // Show highlight when:
            // - Over notch and not expanded (collapsed state trigger)
            // - Over expanded shelf area (expanded state drop zone)
            let shouldBeTargeted = (overNotch && !isExpanded) || overExpandedArea
            if DroppyState.shared.isDropTargeted != shouldBeTargeted {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    DroppyState.shared.isDropTargeted = shouldBeTargeted
                }
            }
        }
        
        // Accept drops over the notch OR over the expanded shelf area
        let canDrop = overNotch || overExpandedArea
        return canDrop ? .copy : []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        // Remove highlight
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                DroppyState.shared.isDropTargeted = false
            }
        }
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        // Ensure highlight is removed
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                DroppyState.shared.isDropTargeted = false
            }
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let isExpanded = DroppyState.shared.isExpanded
        let overNotch = isDragOverNotch(sender)
        let overExpandedArea = isExpanded && isDragOverExpandedShelf(sender)
        
        // Accept drops when over the notch OR over the expanded shelf area
        if !overNotch && !overExpandedArea {
            return false // Reject - let other apps handle the drop
        }
        
        // Remove highlight
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                DroppyState.shared.isDropTargeted = false
            }
        }
        
        
        let pasteboard = sender.draggingPasteboard
        
        // 1. Handle Mail.app emails directly via AppleScript
        // Mail.app's file promises are unreliable, so we use AppleScript to export the full .eml file
        let mailTypes: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeMessageTransfer"),
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeAutomator")
        ]
        let isMailAppEmail = mailTypes.contains(where: { pasteboard.types?.contains($0) ?? false })
        
        if isMailAppEmail {
            print("📧 Mail.app email detected, using AppleScript to export...")
            
            Task { @MainActor in
                let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
                
                let savedFiles = await MailHelper.shared.exportSelectedEmails(to: dropLocation)
                
                if !savedFiles.isEmpty {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        DroppyState.shared.addItems(from: savedFiles)
                    }
                } else {
                    print("📧 No emails exported, AppleScript may need user permission")
                }
            }
            return true
        }

        // 2. Handle File Promises (e.g. from Outlook, Photos, other apps)
        if let promiseReceivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
           !promiseReceivers.isEmpty {
            
            // Create a temporary directory for these files
            let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: dropLocation, withIntermediateDirectories: true, attributes: nil)
            
            // Process file promises asynchronously
            for receiver in promiseReceivers {
                receiver.receivePromisedFiles(atDestination: dropLocation, options: [:], operationQueue: filePromiseQueue) { fileURL, error in
                    guard error == nil else {
                        print("📦 Error receiving promised file: \(error!)")
                        return
                    }
                    print("📦 Successfully received: \(fileURL)")
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            DroppyState.shared.addItems(from: [fileURL])
                        }
                    }
                }
            }
            return true
        }
        
        // 2. Handle File URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    DroppyState.shared.addItems(from: urls)
                }
            }
            return true
        }
        
        // 3. Handle plain text drops (including web URLs) - create a .txt file
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            // Create a temp directory for text files
            let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: dropLocation, withIntermediateDirectories: true, attributes: nil)
            
            // Generate a timestamped filename
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            let timestamp = formatter.string(from: Date())
            let filename = "Text \(timestamp).txt"
            let fileURL = dropLocation.appendingPathComponent(filename)
            
            do {
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        DroppyState.shared.addItems(from: [fileURL])
                    }
                }
                return true
            } catch {
                print("Error saving text file: \(error)")
                return false
            }
        }
        
        return false
    }
}
