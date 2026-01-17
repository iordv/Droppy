import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Notch Drag Container
// Extracted from NotchWindowController.swift for faster incremental builds

class NotchDragContainer: NSView {
    
    weak var hostingView: NSView?
    private var filePromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    private var trackingArea: NSTrackingArea?
    
    /// State observation cancellable for tracking area updates
    private var stateObservationActive = false
    
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
        
        // Start observing state changes to update tracking area when shelf expands/collapses
        setupStateObservation()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = self.trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }
        
        // CRITICAL FIX (v7.7.26): Only create tracking area over the ACTUAL visible notch bounds,
        // not the full container bounds. This prevents blocking menu bar buttons when collapsed.
        // The tracking area dynamically adjusts based on whether the shelf is active.
        
        // Get real notch bounds from the parent window
        guard let notchWindow = self.window as? NotchWindow else {
            // Fallback: create a minimal tracking area at the top of the container
            let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
            let minimalRect = NSRect(x: bounds.midX - 130, y: bounds.height - 50, width: 260, height: 50)
            trackingArea = NSTrackingArea(rect: minimalRect, options: options, owner: self, userInfo: nil)
            addTrackingArea(trackingArea!)
            return
        }
        
        let isExpanded = DroppyState.shared.isExpanded
        let isHovering = DroppyState.shared.isMouseHovering
        let isDragging = DragMonitor.shared.isDragging
        let isActive = isExpanded || isHovering || isDragging
        
        // Calculate tracking rect based on state
        let trackingRect: NSRect
        
        if isExpanded {
            // When expanded, track the full expanded shelf area
            let expandedWidth: CGFloat = 450
            let centerX = bounds.midX
            let rowCount = (Double(DroppyState.shared.items.count) / 5.0).rounded(.up)
            var expandedHeight = max(1, rowCount) * 110 + 54
            
            // Add media player height if needed
            let shouldShowPlayer = MusicManager.shared.isPlaying || MusicManager.shared.wasRecentlyPlaying
            if DroppyState.shared.items.isEmpty && shouldShowPlayer && !MusicManager.shared.isPlayerIdle {
                expandedHeight += 100
            }
            
            trackingRect = NSRect(
                x: centerX - expandedWidth / 2,
                y: bounds.height - expandedHeight,
                width: expandedWidth,
                height: expandedHeight
            )
        } else if isActive {
            // When hovering/dragging but not expanded, use slightly expanded notch bounds
            let notchRect = notchWindow.getNotchRect()
            // Convert screen coordinates to local view coordinates
            guard let windowFrame = window?.frame else {
                trackingRect = NSRect(x: bounds.midX - 130, y: bounds.height - 50, width: 260, height: 50)
                let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
                trackingArea = NSTrackingArea(rect: trackingRect, options: options, owner: self, userInfo: nil)
                addTrackingArea(trackingArea!)
                return
            }
            
            // Convert notch screen rect to window-local coordinates
            let localX = notchRect.minX - windowFrame.minX
            let localY = notchRect.minY - windowFrame.minY
            
            trackingRect = NSRect(
                x: localX - 20,
                y: localY,
                width: notchRect.width + 40,
                height: bounds.height - localY  // Extend to top of container
            )
        } else {
            // COLLAPSED STATE: Use minimal tracking area just over the visible notch
            // This is the key fix - we don't track the full container when idle
            let notchRect = notchWindow.getNotchRect()
            guard let windowFrame = window?.frame else {
                // Fallback minimal rect
                trackingRect = NSRect(x: bounds.midX - 105, y: bounds.height - 40, width: 210, height: 40)
                let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
                trackingArea = NSTrackingArea(rect: trackingRect, options: options, owner: self, userInfo: nil)
                addTrackingArea(trackingArea!)
                return
            }
            
            // Convert notch screen rect to window-local coordinates
            let localX = notchRect.minX - windowFrame.minX
            let localY = notchRect.minY - windowFrame.minY
            
            // Only track the exact notch area + small margin, NOT extending below
            trackingRect = NSRect(
                x: localX - 10,
                y: localY,
                width: notchRect.width + 20,
                height: bounds.height - localY  // Only extend upward to screen top
            )
        }
        
        // NOTE: .mouseMoved removed - it was causing continuous events that triggered
        // state updates and interfered with context menus.
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: trackingRect, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    /// Sets up observation for state changes that require tracking area updates
    private func setupStateObservation() {
        guard !stateObservationActive else { return }
        stateObservationActive = true
        
        withObservationTracking {
            _ = DroppyState.shared.isExpanded
            _ = DroppyState.shared.isMouseHovering
        } onChange: {
            DispatchQueue.main.async { [weak self] in
                self?.updateTrackingAreas()
                self?.stateObservationActive = false
                self?.setupStateObservation()  // Re-register (one-shot observation)
            }
        }
    }
    
    // MARK: - First Mouse Activation (v5.8.9)
    // Enable immediate interaction with shelf items without requiring window activation first.
    // This allows dragging files from the shelf even when another app is frontmost.
    // IMPORTANT: Only enable when shelf is expanded AND no other Droppy windows are visible
    // to prevent blocking interaction with Settings, Clipboard, etc.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Only accept first mouse when shelf is expanded (has items to interact with)
        guard DroppyState.shared.isExpanded else {
            return false
        }
        
        // OPTIMIZED: Check key window instead of iterating all windows (O(1) vs O(n))
        // If another important Droppy window is the key window, don't steal first mouse
        if let keyWindow = NSApp.keyWindow, keyWindow !== self.window {
            if keyWindow is ClipboardPanel || keyWindow is BasketPanel ||
               keyWindow.title == "Settings" || keyWindow.title.contains("Update") ||
               keyWindow.title == "Welcome to Droppy" {
                return false
            }
        }
        
        // Verify the click is actually within the expanded shelf area
        guard let event = event else { return true }
        let locationInWindow = event.locationInWindow
        let locationInView = convert(locationInWindow, from: nil)
        
        // Check if within expanded shelf bounds (approximate)
        let expandedWidth: CGFloat = 450
        let centerX = bounds.midX
        let xRange = (centerX - expandedWidth/2)...(centerX + expandedWidth/2)
        
        if xRange.contains(locationInView.x) {
            return true
        }
        
        return false
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
        
        // Toggle the shelf expansion for THIS specific screen
        let displayID = notchWindow.targetDisplayID
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                DroppyState.shared.toggleShelfExpansion(for: displayID)
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
            // Use notchScreen for multi-monitor support
            if DroppyState.shared.isExpanded {
                guard let notchWindow = self.window as? NotchWindow,
                      let screen = notchWindow.notchScreen else { return nil }

                let expandedWidth: CGFloat = 450
                // Use global coordinates
                let centerX = screen.frame.origin.x + screen.frame.width / 2
                let xMin = centerX - expandedWidth / 2
                let xMax = centerX + expandedWidth / 2

                let rowCount = ceil(Double(DroppyState.shared.items.count) / 5.0)
                var expandedHeight = max(1, rowCount) * 110 + 54

                let shouldShowPlayer = MusicManager.shared.isPlaying || MusicManager.shared.wasRecentlyPlaying
                if DroppyState.shared.items.isEmpty && shouldShowPlayer && !MusicManager.shared.isPlayerIdle {
                    expandedHeight += 100
                }

                let yMin = screen.frame.origin.y + screen.frame.height - expandedHeight
                let yMax = screen.frame.origin.y + screen.frame.height

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
            // PRECISE HOVER HIT AREA (v6.5.1):
            // Only capture clicks within the ACTUAL notch/island bounds + small margin.
            // CRITICAL: NO downward extension - this was blocking Chrome's bookmarks bar!
            // The indicator appears INSIDE the notch area, so we don't need extra space below.
            guard let notchWindow = self.window as? NotchWindow else { return nil }
            let notchRect = notchWindow.getNotchRect()
            let mouseScreenPos = NSEvent.mouseLocation
            
            // Horizontal: notch bounds + 10px on each side for comfortable clicking
            let xMin = notchRect.minX - 10
            let xMax = notchRect.maxX + 10
            
            // Vertical: From notch bottom to screen top ONLY - no downward extension!
            // This ensures we don't block bookmark bars, URL fields, or other UI below the notch
            let yMin = notchRect.minY  // Exact notch bottom - NO extension below!
            // Use notchScreen for multi-monitor support
            let yMax = notchWindow.notchScreen?.frame.maxY ?? notchRect.maxY
            
            if mouseScreenPos.x >= xMin && mouseScreenPos.x <= xMax &&
               mouseScreenPos.y >= yMin && mouseScreenPos.y <= yMax {
                return super.hitTest(point)
            }
            
            // CRITICAL FIX: Mouse is hovering but OUTSIDE the notch area (e.g., below it)
            // We MUST return nil to ensure clicks pass through to apps below the notch!
            return nil
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
        // Use notchScreen for multi-monitor support
        guard let notchWindow = self.window as? NotchWindow,
              let screen = notchWindow.notchScreen else { return false }
        let dragLocation = sender.draggingLocation

        // Convert from window coordinates to screen coordinates
        guard let windowFrame = self.window?.frame else { return false }
        let screenLocation = NSPoint(x: windowFrame.origin.x + dragLocation.x,
                                     y: windowFrame.origin.y + dragLocation.y)

        // Calculate expanded shelf bounds (same logic as hitTest)
        // Use global coordinates
        let expandedWidth: CGFloat = 450
        let centerX = screen.frame.origin.x + screen.frame.width / 2
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

        let yMin = screen.frame.origin.y + screen.frame.height - expandedHeight
        let yMax = screen.frame.origin.y + screen.frame.height

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
