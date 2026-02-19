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
    
    /// AirDrop zone width (must match NotchShelfView.airDropZoneWidth)
    private let airDropZoneWidth: CGFloat = 90
    
    /// Track if current drag is valid (for Power Folders restriction)
    private var currentDragIsValid: Bool = true
    /// True only when this drag session auto-expanded the shelf from collapsed state.
    private var expandedForCurrentDrag: Bool = false

    private func activeDisplayID() -> CGDirectDisplayID? {
        if let notchWindow = self.window as? NotchWindow {
            if notchWindow.targetDisplayID != 0 {
                return notchWindow.targetDisplayID
            }
            return notchWindow.notchScreen?.displayID
        }
        return nil
    }

    private func isExpandedOnTargetDisplay() -> Bool {
        guard let displayID = activeDisplayID() else { return DroppyState.shared.isExpanded }
        return DroppyState.shared.isExpanded(for: displayID)
    }

    private func isHoveringOnTargetDisplay() -> Bool {
        guard let displayID = activeDisplayID() else { return DroppyState.shared.isMouseHovering }
        return DroppyState.shared.isHovering(for: displayID)
    }

    private func isNotificationHUDActiveOnThisDisplay() -> Bool {
        guard HUDManager.shared.isNotificationHUDVisible else { return false }
        guard NotificationHUDManager.shared.currentNotification != nil else { return false }
        return true
    }

    private func collapseTemporaryDragExpansion() {
        guard expandedForCurrentDrag else { return }
        expandedForCurrentDrag = false

        if let displayID = activeDisplayID() {
            withAnimation(DroppyAnimation.state) {
                DroppyState.shared.collapseShelf(for: displayID)
            }
        } else {
            withAnimation(DroppyAnimation.state) {
                DroppyState.shared.isExpanded = false
            }
        }
    }

    /// Enlarged interaction rect for collapsed stacked shelf preview so users can click it directly.
    private func collapsedShelfTapRect(from notchRect: NSRect, isExpanded: Bool) -> NSRect? {
        guard !isExpanded else { return nil }
        let count = DroppyState.shared.shelfDisplaySlotCount
        guard count > 0 else { return nil }

        let footprint = ShelfStackPeekView.preferredFootprint(for: count)
        let width = min(320, max(notchRect.width + 24, footprint.width + 18))
        let height = min(182, max(112, footprint.height + 18))

        return NSRect(
            x: notchRect.midX - (width / 2),
            y: notchRect.maxY - height,
            width: width,
            height: height
        )
    }

    private func collapsedInteractionRect(for notchWindow: NotchWindow) -> NSRect {
        notchWindow.collapsedInteractionRect()
    }

    private func expandedInteractionZoneInScreen(for screen: NSScreen) -> NSRect {
        NotchWindowController.shared.expandedShelfInteractionZone(for: screen)
    }

    private func expandedInteractionZoneInLocal(for screen: NSScreen) -> NSRect? {
        guard let windowFrame = window?.frame else { return nil }
        let screenZone = expandedInteractionZoneInScreen(for: screen)
        return NSRect(
            x: screenZone.minX - windowFrame.minX,
            y: screenZone.minY - windowFrame.minY,
            width: screenZone.width,
            height: screenZone.height
        )
    }

    
    
    
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
            if let area = trackingArea {
                addTrackingArea(area)
            }
            return
        }
        
        let isExpanded = isExpandedOnTargetDisplay()
        let isHovering = isHoveringOnTargetDisplay()
        let isDragging = DragMonitor.shared.isDragging
        let isActive = isExpanded || isHovering || isDragging
        
        // Calculate tracking rect based on state
        let trackingRect: NSRect
        
        if isExpanded {
            // When expanded, track the canonical interaction zone used by controller monitors.
            guard let screen = notchWindow.notchScreen,
                  let expandedZone = expandedInteractionZoneInLocal(for: screen) else {
                trackingRect = NSRect(x: bounds.midX - 130, y: bounds.height - 50, width: 260, height: 50)
                let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
                trackingArea = NSTrackingArea(rect: trackingRect, options: options, owner: self, userInfo: nil)
                if let area = trackingArea {
                    addTrackingArea(area)
                }
                return
            }
            trackingRect = expandedZone
        } else if isActive {
            // When hovering/dragging but not expanded, use slightly expanded notch bounds
            let notchRect = collapsedInteractionRect(for: notchWindow)
            // Convert screen coordinates to local view coordinates
            guard let windowFrame = window?.frame else {
                trackingRect = NSRect(x: bounds.midX - 130, y: bounds.height - 50, width: 260, height: 50)
                let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
                trackingArea = NSTrackingArea(rect: trackingRect, options: options, owner: self, userInfo: nil)
                if let area = trackingArea {
                    addTrackingArea(area)
                }
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
            let notchRect = collapsedInteractionRect(for: notchWindow)
            guard let windowFrame = window?.frame else {
                // Fallback minimal rect
                trackingRect = NSRect(x: bounds.midX - 105, y: bounds.height - 40, width: 210, height: 40)
                let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
                trackingArea = NSTrackingArea(rect: trackingRect, options: options, owner: self, userInfo: nil)
                if let area = trackingArea {
                    addTrackingArea(area)
                }
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
        if let area = trackingArea {
            addTrackingArea(area)
        }
    }
    
    /// Sets up observation for state changes that require tracking area updates
    private func setupStateObservation() {
        guard !stateObservationActive else { return }
        stateObservationActive = true
        
        withObservationTracking {
            _ = DroppyState.shared.expandedDisplayID
            _ = DroppyState.shared.hoveringDisplayID
            _ = ToDoManager.shared.isShelfListExpanded
            _ = ToDoManager.shared.isRemindersSyncEnabled
            _ = ToDoManager.shared.isCalendarSyncEnabled
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
        if isNotificationHUDActiveOnThisDisplay() {
            return true
        }
        
        // Only accept first mouse when shelf is expanded (has items to interact with)
        guard isExpandedOnTargetDisplay() else {
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
        guard let event = event,
              let notchWindow = self.window as? NotchWindow,
              let screen = notchWindow.notchScreen,
              let window = self.window else { return false }

        let clickLocation = window.convertPoint(toScreen: event.locationInWindow)
        return expandedInteractionZoneInScreen(for: screen).contains(clickLocation)
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
        if isNotificationHUDActiveOnThisDisplay() {
            super.mouseDown(with: event)
            return
        }

        // Only proceed if notch shelf is enabled
        // CRITICAL: Use object() ?? true to match @AppStorage default
        guard (UserDefaults.standard.object(forKey: "enableNotchShelf") as? Bool) ?? true else {
            super.mouseDown(with: event)
            return
        }

        // When expanded, never steal clicks in the notch strip.
        // Let SwiftUI controls (media/buttons/toggles) handle interaction directly.
        guard !isExpandedOnTargetDisplay() else {
            super.mouseDown(with: event)
            return
        }
        
        // Only handle clicks when user is already hovering (intentional interaction)
        // This ensures we don't block clicks that should pass through to other apps
        guard isHoveringOnTargetDisplay() else {
            super.mouseDown(with: event)
            return
        }
        
        // Verify click is over the actual notch area (not the expanded detection zone)
        guard let notchWindow = self.window as? NotchWindow else {
            super.mouseDown(with: event)
            return
        }
        
        let mouseLocation = NSEvent.mouseLocation
        let notchRect = collapsedInteractionRect(for: notchWindow)
        
        let collapsedRect = collapsedShelfTapRect(from: notchRect, isExpanded: false)
        let clickInsideInteractiveZone = notchRect.contains(mouseLocation) || (collapsedRect?.contains(mouseLocation) ?? false)
        
        // Keep pass-through when click is outside the visible notch/stack surface.
        guard clickInsideInteractiveZone else {
            super.mouseDown(with: event)
            return
        }

        // When collapsed stack preview is visible, let SwiftUI/DraggableArea own click+drag.
        let hasCollapsedPeek = DroppyState.shared.shelfDisplaySlotCount > 0
        if hasCollapsedPeek {
            super.mouseDown(with: event)
            return
        }
        
        // Toggle the shelf expansion for THIS specific screen
        let displayID = notchWindow.targetDisplayID
        let animationScreen = notchWindow.notchScreen
        DispatchQueue.main.async {
            let animation = DroppyAnimation.notchState(for: animationScreen)
            withAnimation(animation) {
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
        // Keep NotificationHUD interactive even when shelf itself is collapsed/non-hovering.
        if isNotificationHUDActiveOnThisDisplay() {
            return super.hitTest(point)
        }

        // We want to be selective about when we intercept events vs letting them pass through to apps below.
        
        // 1. Check current state
        let isExpanded = isExpandedOnTargetDisplay()
        let mouseIsDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
        let dragPasteboardHasTypes = !((NSPasteboard(name: .drag).types ?? []).isEmpty)
        let probableExternalDrag = mouseIsDown && dragPasteboardHasTypes
        let isDragging = DragMonitor.shared.isDragging || DroppyState.shared.isDropTargeted || probableExternalDrag
        
        // 2. Define the active interaction area
        // If expanded, the whole expanded area is interactive
        if isExpanded {
            guard let notchWindow = self.window as? NotchWindow,
                  let screen = notchWindow.notchScreen else { return nil }
            let mouseScreenPos = NSEvent.mouseLocation
            let expandedZone = expandedInteractionZoneInScreen(for: screen)

            if expandedZone.contains(mouseScreenPos) {
                return super.hitTest(point)
            }
            
            // ALSO accept drops at the notch area when expanded (user might drop before moving into shelf)
            if isDragging {
                let realNotchRect = collapsedInteractionRect(for: notchWindow)
                if realNotchRect.contains(mouseScreenPos) {
                    return super.hitTest(point)
                }
            }
        }
        
        // If dragging, intercept if mouse is near top of screen around notch area
        // Use a generous hit area so auto-expand works well
        if isDragging {
            let mouseScreenPos = NSEvent.mouseLocation
            
            guard let notchWindow = self.window as? NotchWindow,
                  let screen = notchWindow.notchScreen else { return nil }
            let notchRect = collapsedInteractionRect(for: notchWindow)
            let collapsedRect = collapsedShelfTapRect(from: notchRect, isExpanded: isExpandedOnTargetDisplay())
            
            // Use expanded notch area (wider and taller to catch media player HUD)
            let centerX = screen.notchAlignedCenterX
            var xMin = centerX - 200
            var xMax = centerX + 200
            var yMin = screen.frame.origin.y + screen.frame.height - 100
            let yMax = screen.frame.origin.y + screen.frame.height

            if let collapsedRect {
                xMin = min(xMin, collapsedRect.minX - 8)
                xMax = max(xMax, collapsedRect.maxX + 8)
                yMin = min(yMin, collapsedRect.minY - 8)
            }
            
            if mouseScreenPos.x >= xMin && mouseScreenPos.x <= xMax &&
               mouseScreenPos.y >= yMin && mouseScreenPos.y <= yMax {
                return super.hitTest(point)
            }
            
            // When expanded, also accept drags over the expanded shelf area
            // Use notchScreen for multi-monitor support
            if isExpandedOnTargetDisplay() {
                guard let notchWindow = self.window as? NotchWindow,
                      let screen = notchWindow.notchScreen else { return nil }
                let expandedZone = expandedInteractionZoneInScreen(for: screen)
                if expandedZone.contains(mouseScreenPos) {
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
        
        let isHovering = isHoveringOnTargetDisplay()
        
        if isHovering {
            // PRECISE HOVER HIT AREA (v6.5.1):
            // Only capture clicks within the ACTUAL notch/island bounds + small margin.
            // CRITICAL: NO downward extension - this was blocking Chrome's bookmarks bar!
            // The indicator appears INSIDE the notch area, so we don't need extra space below.
            guard let notchWindow = self.window as? NotchWindow else { return nil }
            let notchRect = collapsedInteractionRect(for: notchWindow)
            let mouseScreenPos = NSEvent.mouseLocation
            let collapsedRect = collapsedShelfTapRect(from: notchRect, isExpanded: isExpanded)
            
            // Horizontal: notch bounds + 10px on each side for comfortable clicking.
            // Include collapsed stacked peek bounds when visible.
            var xMin = notchRect.minX - 10
            var xMax = notchRect.maxX + 10
            if let collapsedRect {
                xMin = min(xMin, collapsedRect.minX - 4)
                xMax = max(xMax, collapsedRect.maxX + 4)
            }
            
            // Vertical: default notch-only hit zone, plus collapsed stacked peek zone when visible.
            var yMin = notchRect.minY
            if let collapsedRect {
                yMin = min(yMin, collapsedRect.minY - 4)
            }
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
    
    /// Helper to check if a drag location is over the notch area (generous for auto-expand)
    private func isDragOverNotch(_ sender: NSDraggingInfo) -> Bool {
        guard let notchWindow = self.window as? NotchWindow,
              let screen = notchWindow.notchScreen else { return false }
        
        let dragLocation = sender.draggingLocation
        guard let windowFrame = self.window?.frame else { return false }
        let screenLocation = NSPoint(x: windowFrame.origin.x + dragLocation.x, 
                                     y: windowFrame.origin.y + dragLocation.y)
        
        // Use generous hit area matching hitTest logic.
        // Include full collapsed stacked shelf height/width when present.
        let centerX = screen.notchAlignedCenterX
        var xMin = centerX - 200
        var xMax = centerX + 200
        var yMin = screen.frame.origin.y + screen.frame.height - 100
        let yMax = screen.frame.origin.y + screen.frame.height

        let notchRect = collapsedInteractionRect(for: notchWindow)
        if let collapsedRect = collapsedShelfTapRect(from: notchRect, isExpanded: isExpandedOnTargetDisplay()) {
            xMin = min(xMin, collapsedRect.minX - 8)
            xMax = max(xMax, collapsedRect.maxX + 8)
            yMin = min(yMin, collapsedRect.minY - 8)
        }
        
        return screenLocation.x >= xMin && screenLocation.x <= xMax &&
               screenLocation.y >= yMin && screenLocation.y <= yMax
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

        let expandedZone = expandedInteractionZoneInScreen(for: screen)
        return expandedZone.contains(screenLocation)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        currentDragIsValid = true
        if !isExpandedOnTargetDisplay() {
            expandedForCurrentDrag = false
        }
        
        // Check Power Folders restriction
        // CRITICAL: Use object() ?? true to match @AppStorage default
        let powerFoldersEnabled = (UserDefaults.standard.object(forKey: "enablePowerFolders") as? Bool) ?? true
        
        if !powerFoldersEnabled {
            let pasteboard = sender.draggingPasteboard
            // Only read URLs if we need to check for folders
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
                // Check if any URL is a directory
                let hasFolder = urls.prefix(10).contains { url in
                    var isDir: ObjCBool = false
                    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
                }
                
                if hasFolder {
                    print("🚫 Shelf: Rejected folder drop (Power Folders disabled)")
                    currentDragIsValid = false
                    return []
                }
            }
        }

        let overNotch = isDragOverNotch(sender)
        let isExpanded = isExpandedOnTargetDisplay()
        let overExpandedArea = isExpanded && isDragOverExpandedShelf(sender)
        
        // Accept drags over the notch OR over the expanded shelf area
        guard overNotch || overExpandedArea else {
            return [] // Reject - let drag pass through to other apps
        }
        
        // Issue #136 FIX: Manually activate DragMonitor for Dock folder/system drags
        // NSPasteboard(name: .drag) polling doesn't detect Dock folder drags, but
        // NSDraggingDestination does receive them. Force-set the drag state so the
        // shelf shows action buttons (Share, AirDrop, etc.)
        if !DragMonitor.shared.isDragging {
            let dragLocation = sender.draggingLocation
            if let windowFrame = self.window?.frame {
                let screenLocation = NSPoint(x: windowFrame.origin.x + dragLocation.x,
                                             y: windowFrame.origin.y + dragLocation.y)
                DragMonitor.shared.forceSetDragging(true, location: screenLocation)
            } else {
                DragMonitor.shared.forceSetDragging(true)
            }
        }
        
        // Restore clear drag feedback: temporarily expand while dragging over notch.
        if overNotch && !isExpanded {
            if let notchWindow = self.window as? NotchWindow,
               let displayID = notchWindow.notchScreen?.displayID {
                let animationScreen = notchWindow.notchScreen
                DispatchQueue.main.async {
                    withAnimation(DroppyAnimation.notchState(for: animationScreen)) {
                        DroppyState.shared.expandShelf(for: displayID)
                    }
                }
                expandedForCurrentDrag = true
            }
        }

        if overNotch || overExpandedArea {
            // Highlight UI when over expanded drop zone
            // Also track which screen for multi-monitor expand fix
            if let notchWindow = self.window as? NotchWindow,
               let displayID = notchWindow.notchScreen?.displayID {
                DispatchQueue.main.async {
                    DroppyState.shared.isDropTargeted = true
                    DroppyState.shared.dropTargetDisplayID = displayID  // Track which screen
                }
            }
        }
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Respect validity check from draggingEntered
        if !currentDragIsValid { return [] }
        
        let overNotch = isDragOverNotch(sender)
        let isExpanded = isExpandedOnTargetDisplay()
        let overExpandedArea = isExpanded && isDragOverExpandedShelf(sender)
        
        DispatchQueue.main.async {
            // Keep highlight while over notch OR expanded shelf drop zone.
            // Important when shelf is temporarily expanded for drag feedback.
            let shouldBeTargeted = overNotch || overExpandedArea
            if DroppyState.shared.isDropTargeted != shouldBeTargeted {
                DroppyState.shared.isDropTargeted = shouldBeTargeted
            }
        }
        
        // Accept drops over the notch OR over the expanded shelf area
        let canDrop = overNotch || overExpandedArea
        return canDrop ? .copy : []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        // Remove highlight state
        DispatchQueue.main.async {
            DroppyState.shared.isDropTargeted = false
            DroppyState.shared.dropTargetDisplayID = nil
        }
        collapseTemporaryDragExpansion()
        
        // Issue #136: Also clear force-set drag state when drag exits
        // Only if mouse button is no longer pressed (drag truly ended)
        let mouseIsDown = NSEvent.pressedMouseButtons & 1 != 0
        if !mouseIsDown {
            DragMonitor.shared.forceSetDragging(false)
        }
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        // Ensure highlight state is removed
        DispatchQueue.main.async {
            DroppyState.shared.isDropTargeted = false
            DroppyState.shared.dropTargetDisplayID = nil
        }
        collapseTemporaryDragExpansion()
        
        // Issue #136: Clear force-set drag state when drag operation ends
        DragMonitor.shared.forceSetDragging(false)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // Respect validity check
        if !currentDragIsValid { return false }
        
        let isExpanded = isExpandedOnTargetDisplay()
        let overNotch = isDragOverNotch(sender)
        let overExpandedArea = isExpanded && isDragOverExpandedShelf(sender)
        
        // Accept drops when over the notch OR over the expanded shelf area
        if !overNotch && !overExpandedArea {
            collapseTemporaryDragExpansion()
            return false // Reject - let other apps handle the drop
        }
        
        // CRITICAL: Capture target display ID from THIS window's screen BEFORE clearing state
        // This ensures items are added and shelf expands on the correct monitor
        let targetDisplayID: CGDirectDisplayID? = {
            if let notchWindow = self.window as? NotchWindow,
               let displayID = notchWindow.notchScreen?.displayID {
                return displayID
            }
            return nil
        }()
        
        // Remove highlight state
        DroppyState.shared.isDropTargeted = false
        DroppyState.shared.dropTargetDisplayID = nil
        collapseTemporaryDragExpansion()

        func revealShelfAfterDrop() {
            if let displayID = targetDisplayID {
                DroppyState.shared.expandShelf(for: displayID)
            } else {
                DroppyState.shared.triggerAutoExpand()
            }
        }
        
        // Check if drop is in AirDrop zone - feature removed, now handled by quick actions
        
        
        let pasteboard = sender.draggingPasteboard
        
        // 1. Handle Mail.app emails directly via AppleScript
        // Mail.app's file promises are unreliable, so we use AppleScript to export the full .eml file
        let mailTypes: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeMessageTransfer"),
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeAutomator")
        ]
        let isMailAppEmail = mailTypes.contains(where: { pasteboard.types?.contains($0) ?? false })
        
        if isMailAppEmail {
            print("📧 Mail.app email detected, using AppleScript to export…")
            
            Task { @MainActor in
                let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
                
                let savedFiles = await MailHelper.shared.exportSelectedEmails(to: dropLocation)
                
                if !savedFiles.isEmpty {
                    let animationScreen = targetDisplayID.flatMap { displayID in
                        NSScreen.screens.first(where: { $0.displayID == displayID })
                    }
                    withAnimation(DroppyAnimation.notchState(for: animationScreen)) {
                        DroppyState.shared.addItems(from: savedFiles, shouldAutoExpand: false)
                        revealShelfAfterDrop()
                    }
                } else {
                    print("📧 No emails exported, AppleScript may need user permission")
                }
            }
            return true
        }

        // 2. Handle File Promises (e.g. from Outlook, Photos, other apps)
        // Photos.app uses file promises - the actual file is delivered asynchronously
        // This can timeout for iCloud photos that need downloading first
        if let promiseReceivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
           !promiseReceivers.isEmpty {
            
            // Create a temporary directory for these files
            let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: dropLocation, withIntermediateDirectories: true, attributes: nil)
            
            // Track success/failure for user feedback
            let totalCount = promiseReceivers.count
            var successCount = 0
            var errorCount = 0
            let completionLock = NSLock()
            
            // Process file promises asynchronously
            for receiver in promiseReceivers {
                print("📦 Shelf: Receiving file promise from \(receiver.fileTypes)")
                
                receiver.receivePromisedFiles(atDestination: dropLocation, options: [:], operationQueue: filePromiseQueue) { [targetDisplayID] fileURL, error in
                    completionLock.lock()
                    defer { completionLock.unlock() }
                    
                    if let error = error {
                        errorCount += 1
                        print("📦 Shelf: File promise failed: \(error.localizedDescription)")
                        
                        // Show feedback on last item if all failed
                        if errorCount + successCount == totalCount && errorCount > 0 && successCount == 0 {
                            DispatchQueue.main.async {
                                Task {
                                    await DroppyAlertController.shared.showError(
                                        title: "Drop Failed",
                                        message: "Could not receive file from Photos. If using iCloud Photos, ensure the image is downloaded locally first."
                                    )
                                }
                            }
                        }
                        return
                    }
                    
                    successCount += 1
                    print("📦 Shelf: Successfully received \(fileURL.lastPathComponent)")
                    DispatchQueue.main.async {
                        let animationScreen = targetDisplayID.flatMap { displayID in
                            NSScreen.screens.first(where: { $0.displayID == displayID })
                        }
                        withAnimation(DroppyAnimation.notchState(for: animationScreen)) {
                            DroppyState.shared.addItems(from: [fileURL], shouldAutoExpand: false)
                            revealShelfAfterDrop()
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
                let animationScreen = targetDisplayID.flatMap { displayID in
                    NSScreen.screens.first(where: { $0.displayID == displayID })
                }
                withAnimation(DroppyAnimation.itemInsertion(for: animationScreen)) {
                    DroppyState.shared.addItems(from: urls, shouldAutoExpand: false)
                    revealShelfAfterDrop()
                }
            }
            return true
        }
        
        // 3. Handle text/URL drops.
        // Web links are materialized as .webloc items; plain text remains a .txt file.
        let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dropLocation, withIntermediateDirectories: true, attributes: nil)
        let droppedFiles = DroppyLinkSupport.createTextOrLinkFiles(from: pasteboard, in: dropLocation)
        if !droppedFiles.isEmpty {
            DispatchQueue.main.async {
                let animationScreen = targetDisplayID.flatMap { displayID in
                    NSScreen.screens.first(where: { $0.displayID == displayID })
                }
                withAnimation(DroppyAnimation.itemInsertion(for: animationScreen)) {
                    DroppyState.shared.addItems(from: droppedFiles, shouldAutoExpand: false)
                    revealShelfAfterDrop()
                }
            }
            return true
        }
        
        return false
    }
}
