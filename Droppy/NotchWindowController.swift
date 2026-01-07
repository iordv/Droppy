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
    
    /// Monitor for mouse movement when window is active
    private var localMonitor: Any?
    
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
        startMonitors()
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
        
        // Local monitor catches movement when mouse is over the Notch window
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseEvent(event)
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
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
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
    private var notchRect: NSRect {
        guard let screen = NSScreen.main else { return .zero }
        
        // Dynamic notch dimensions using auxiliary areas
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
        
        // Check if mouse is over the notch area
        let isOverNotch = notchRect.contains(mouseLocation)
        
        // Only update if not dragging (drag monitor handles that)
        if !DragMonitor.shared.isDragging {
            let currentlyHovering = DroppyState.shared.isMouseHovering
            
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
        let dragMonitor = DragMonitor.shared
        
        let isExpanded = state.isExpanded
        let isHovering = state.isMouseHovering
        let isDragging = dragMonitor.isDragging
        let isDropTargeted = state.isDropTargeted
        
        // Window should accept mouse events when:
        // - Shelf is expanded (need to interact with items)
        // - User is hovering over notch (need click to open)
        // - Files are being dragged (need to accept drops)
        let shouldAcceptEvents = isExpanded || isHovering || isDragging || isDropTargeted
        
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
            NSPasteboard.PasteboardType(UTType.item.identifier)
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
        let isDragging = DroppyState.shared.isDropTargeted // Or check drag monitor if needed
        
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
        }
        
        // IfDragging, we want the drop zone active
        if isDragging {
             // Drop zone is roughly 260px wide, 82px high (notch + padding)
             let dropWidth: CGFloat = 260
             let dropHeight: CGFloat = 100 // generous for drop
             
             let centerX = bounds.midX
             let xRange = (centerX - dropWidth/2)...(centerX + dropWidth/2)
             let yRange = (bounds.height - dropHeight)...bounds.height
             
             if xRange.contains(localPoint.x) && yRange.contains(localPoint.y) {
                  return super.hitTest(point)
             }
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
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Highlight UI
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                DroppyState.shared.isDropTargeted = true
            }
        }
        return .copy
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
        // Remove highlight
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                DroppyState.shared.isDropTargeted = false
            }
        }
        
        
        let pasteboard = sender.draggingPasteboard

        
        // 1. Handle File Promises (e.g. from Outlook, Photos)
        if let promiseReceivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
           !promiseReceivers.isEmpty {
            
            // Create a temporary directory for these files
            let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: dropLocation, withIntermediateDirectories: true, attributes: nil)
            
            for receiver in promiseReceivers {
                receiver.receivePromisedFiles(atDestination: dropLocation, options: [:], operationQueue: filePromiseQueue) { fileURL, error in
                    if let error = error {
                        print("Error receiving promised file: \(error)")
                        return
                    }
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
        
        // 3. Handle Web URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    DroppyState.shared.addItems(from: urls)
                }
            }
            return true
        }
        
        // 4. Handle plain text drops - create a .txt file
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
