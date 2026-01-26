//
//  EventScrombler.swift
//  Droppy
//
//  Ice-style event delivery for reliably clicking menu bar items.
//  Simplified version that avoids Swift 6 async/CFRunLoop conflicts.
//

import Cocoa
import Carbon.HIToolbox

/// Error types for event delivery
enum EventError: Error, LocalizedError {
    case invalidEventSource
    case eventCreationFailure
    case eventDeliveryFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidEventSource: return "Could not create event source"
        case .eventCreationFailure: return "Could not create CGEvent"
        case .eventDeliveryFailed: return "Event delivery failed"
        }
    }
}

/// Ice-style event delivery
@MainActor
final class EventScrombler {
    
    /// Shared instance
    static let shared = EventScrombler()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Click a menu bar item reliably
    /// - Parameters:
    ///   - item: The menu bar item to click
    ///   - mouseButton: Mouse button to use (.left or .right)
    func clickItem(_ item: MenuBarItem, mouseButton: CGMouseButton = .left) async throws {
        print("[EventScrombler] Clicking \(item.displayName)")
        
        // Get current frame
        guard let currentFrame = MenuBarItem.getCurrentFrame(for: item.windowID),
              currentFrame.width > 0 else {
            print("[EventScrombler] Could not get frame for \(item.displayName)")
            throw EventError.eventDeliveryFailed
        }
        
        // Save cursor position
        guard let cursorLocation = CGEvent(source: nil)?.location else {
            throw EventError.invalidEventSource
        }
        
        // Create event source with proper settings
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw EventError.invalidEventSource
        }
        
        // Permit events during suppression states (critical for background apps)
        permitAllEvents(source: source)
        
        // Calculate click point (center of item)
        let clickPoint = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        
        // Get event types for mouse button
        let (downType, upType) = getEventTypes(for: mouseButton)
        
        // Create mouse events
        guard let mouseDownEvent = CGEvent(
            mouseEventSource: source,
            mouseType: downType,
            mouseCursorPosition: clickPoint,
            mouseButton: mouseButton
        ) else {
            throw EventError.eventCreationFailure
        }
        
        guard let mouseUpEvent = CGEvent(
            mouseEventSource: source,
            mouseType: upType,
            mouseCursorPosition: clickPoint,
            mouseButton: mouseButton
        ) else {
            throw EventError.eventCreationFailure
        }
        
        // Set target fields for specific PID targeting
        setEventTargetFields(mouseDownEvent, item: item)
        setEventTargetFields(mouseUpEvent, item: item)
        
        // Hide cursor
        CGDisplayHideCursor(CGMainDisplayID())
        
        // Warp cursor to click point
        CGWarpMouseCursorPosition(clickPoint)
        
        // Small delay for warp
        try await Task.sleep(for: .milliseconds(10))
        
        // Post the events using .cghidEventTap for better reliability
        // This is the HID layer which is closer to hardware events
        mouseDownEvent.post(tap: .cghidEventTap)
        
        // Small delay between down and up
        try await Task.sleep(for: .milliseconds(50))
        
        mouseUpEvent.post(tap: .cghidEventTap)
        
        // Wait for event to process
        try await Task.sleep(for: .milliseconds(100))
        
        // Restore cursor
        CGWarpMouseCursorPosition(cursorLocation)
        CGDisplayShowCursor(CGMainDisplayID())
        
        print("[EventScrombler] Click complete for \(item.displayName)")
    }
    
    // MARK: - Alternative: Direct Activation
    
    /// Fallback: just activate the app and let user click manually
    func activateApp(for item: MenuBarItem) {
        if let app = item.owningApplication {
            app.activate()
            print("[EventScrombler] Activated app: \(app.localizedName ?? "unknown")")
        }
    }
    
    // MARK: - Private Implementation
    
    /// Configure event source to permit events during suppression
    private func permitAllEvents(source: CGEventSource) {
        // Allow local mouse events during all suppression states
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateRemoteMouseDrag
        )
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        source.localEventsSuppressionInterval = 0
    }
    
    /// Set target fields on event for specific PID delivery
    private func setEventTargetFields(_ event: CGEvent, item: MenuBarItem) {
        // Target the specific process
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(item.ownerPID))
        
        // Set window under mouse pointer
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(item.windowID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(item.windowID))
    }
    
    /// Get down/up event types for mouse button
    private func getEventTypes(for button: CGMouseButton) -> (down: CGEventType, up: CGEventType) {
        switch button {
        case .left: return (.leftMouseDown, .leftMouseUp)
        case .right: return (.rightMouseDown, .rightMouseUp)
        case .center: return (.otherMouseDown, .otherMouseUp)
        @unknown default: return (.leftMouseDown, .leftMouseUp)
        }
    }
}
