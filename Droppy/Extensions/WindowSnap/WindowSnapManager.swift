//
//  WindowSnapManager.swift
//  Droppy
//
//  Window Snap - Snap windows to screen positions with keyboard shortcuts
//  Inspired by Rectangle and Spectacle
//
//  REQUIRED INFO.PLIST KEYS:
//  <key>NSAccessibilityUsageDescription</key>
//  <string>Droppy needs Accessibility access to move and resize windows.</string>
//

import SwiftUI
import AppKit
import Combine
import ApplicationServices

// MARK: - Snap Action Definitions

enum SnapAction: String, CaseIterable, Identifiable, Codable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case leftThird
    case centerThird
    case rightThird
    case maximize
    case center
    case restore
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .leftThird: return "Left Third"
        case .centerThird: return "Center Third"
        case .rightThird: return "Right Third"
        case .maximize: return "Maximize"
        case .center: return "Center"
        case .restore: return "Restore"
        }
    }
    
    var icon: String {
        switch self {
        case .leftHalf: return "rectangle.lefthalf.filled"
        case .rightHalf: return "rectangle.righthalf.filled"
        case .topHalf: return "rectangle.tophalf.filled"
        case .bottomHalf: return "rectangle.bottomhalf.filled"
        case .topLeft: return "rectangle.inset.topleft.filled"
        case .topRight: return "rectangle.inset.topright.filled"
        case .bottomLeft: return "rectangle.inset.bottomleft.filled"
        case .bottomRight: return "rectangle.inset.bottomright.filled"
        case .leftThird: return "rectangle.split.3x1"
        case .centerThird: return "rectangle.center.inset.filled"
        case .rightThird: return "rectangle.split.3x1"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .center: return "arrow.up.and.down.and.arrow.left.and.right"
        case .restore: return "arrow.down.right.and.arrow.up.left"
        }
    }
    
    /// Default keyboard shortcut for this action
    var defaultShortcut: SavedShortcut? {
        let ctrl = NSEvent.ModifierFlags.control.rawValue
        let opt = NSEvent.ModifierFlags.option.rawValue
        let ctrlOpt = ctrl | opt
        
        switch self {
        case .leftHalf:    return SavedShortcut(keyCode: 123, modifiers: ctrlOpt) // ←
        case .rightHalf:   return SavedShortcut(keyCode: 124, modifiers: ctrlOpt) // →
        case .topHalf:     return SavedShortcut(keyCode: 126, modifiers: ctrlOpt) // ↑
        case .bottomHalf:  return SavedShortcut(keyCode: 125, modifiers: ctrlOpt) // ↓
        case .topLeft:     return SavedShortcut(keyCode: 32, modifiers: ctrlOpt)  // U
        case .topRight:    return SavedShortcut(keyCode: 34, modifiers: ctrlOpt)  // I
        case .bottomLeft:  return SavedShortcut(keyCode: 38, modifiers: ctrlOpt)  // J
        case .bottomRight: return SavedShortcut(keyCode: 40, modifiers: ctrlOpt)  // K
        case .leftThird:   return SavedShortcut(keyCode: 2, modifiers: ctrlOpt)   // D
        case .centerThird: return SavedShortcut(keyCode: 3, modifiers: ctrlOpt)   // F
        case .rightThird:  return SavedShortcut(keyCode: 5, modifiers: ctrlOpt)   // G
        case .maximize:    return SavedShortcut(keyCode: 36, modifiers: ctrlOpt)  // Return
        case .center:      return SavedShortcut(keyCode: 8, modifiers: ctrlOpt)   // C
        case .restore:     return nil // No default
        }
    }
    
    /// Calculate the target frame for this snap action
    /// Returns frame in SCREEN coordinates (Y=0 at top of primary screen)
    /// which is what AXUIElement expects
    func targetFrame(for screen: NSScreen) -> CGRect {
        // Get the primary screen (for coordinate reference)
        let primaryScreen = NSScreen.screens.first ?? screen
        let primaryHeight = primaryScreen.frame.height
        
        // Get the visible area (excludes menu bar and dock)
        let visibleFrame = screen.visibleFrame
        
        // Convert visibleFrame from Cocoa coords (Y=0 at bottom) to screen coords (Y=0 at top)
        // Screen coords: y = primaryHeight - cocoaY - height
        let visibleX = visibleFrame.origin.x
        let visibleY = primaryHeight - visibleFrame.origin.y - visibleFrame.height
        let visibleW = visibleFrame.width
        let visibleH = visibleFrame.height
        
        // Calculate target rect in screen coordinates
        switch self {
        case .leftHalf:
            return CGRect(x: visibleX, y: visibleY, width: visibleW / 2, height: visibleH)
        case .rightHalf:
            return CGRect(x: visibleX + visibleW / 2, y: visibleY, width: visibleW / 2, height: visibleH)
        case .topHalf:
            return CGRect(x: visibleX, y: visibleY, width: visibleW, height: visibleH / 2)
        case .bottomHalf:
            return CGRect(x: visibleX, y: visibleY + visibleH / 2, width: visibleW, height: visibleH / 2)
        case .topLeft:
            return CGRect(x: visibleX, y: visibleY, width: visibleW / 2, height: visibleH / 2)
        case .topRight:
            return CGRect(x: visibleX + visibleW / 2, y: visibleY, width: visibleW / 2, height: visibleH / 2)
        case .bottomLeft:
            return CGRect(x: visibleX, y: visibleY + visibleH / 2, width: visibleW / 2, height: visibleH / 2)
        case .bottomRight:
            return CGRect(x: visibleX + visibleW / 2, y: visibleY + visibleH / 2, width: visibleW / 2, height: visibleH / 2)
        case .leftThird:
            return CGRect(x: visibleX, y: visibleY, width: visibleW / 3, height: visibleH)
        case .centerThird:
            return CGRect(x: visibleX + visibleW / 3, y: visibleY, width: visibleW / 3, height: visibleH)
        case .rightThird:
            return CGRect(x: visibleX + 2 * visibleW / 3, y: visibleY, width: visibleW / 3, height: visibleH)
        case .maximize:
            return CGRect(x: visibleX, y: visibleY, width: visibleW, height: visibleH)
        case .center:
            let centerW = visibleW * 2 / 3
            let centerH = visibleH * 2 / 3
            return CGRect(
                x: visibleX + (visibleW - centerW) / 2,
                y: visibleY + (visibleH - centerH) / 2,
                width: centerW,
                height: centerH
            )
        case .restore:
            return CGRect(x: visibleX, y: visibleY, width: visibleW, height: visibleH)
        }
    }
}

// MARK: - Window Snap Manager

@MainActor
final class WindowSnapManager: ObservableObject {
    static let shared = WindowSnapManager()
    
    // MARK: - Published State
    
    @Published private(set) var isEnabled = false
    @Published var shortcuts: [SnapAction: SavedShortcut] = [:]
    
    // MARK: - Private Properties
    
    private var hotkeyMonitors: [SnapAction: Any] = [:]
    private var savedWindowFrames: [pid_t: CGRect] = [:]  // For restore functionality
    
    // Animation duration for smooth spring animation
    private let animationDuration: TimeInterval = 0.3
    private let animationSteps: Int = 30
    
    private let shortcutsKey = "windowSnapShortcuts"
    
    // MARK: - Initialization
    
    private init() {
        // Empty - shortcuts loaded via loadAndStartMonitoring after app launch
    }
    
    /// Called from AppDelegate after app finishes launching
    func loadAndStartMonitoring() {
        // Don't start if extension is disabled
        guard !ExtensionType.windowSnap.isRemoved else {
            print("[WindowSnap] Extension is disabled, skipping monitoring")
            return
        }
        
        loadShortcuts()
        if !shortcuts.isEmpty {
            startMonitoringAllShortcuts()
        }
    }
    
    // MARK: - Public API
    
    /// Execute a snap action on the frontmost window
    func executeAction(_ action: SnapAction) {
        // Don't execute if extension is disabled
        guard !ExtensionType.windowSnap.isRemoved else {
            print("[WindowSnap] Extension is disabled, ignoring action")
            return
        }
        
        guard checkAccessibilityPermission() else {
            showPermissionAlert()
            return
        }
        
        guard let window = getFrontmostWindow(),
              let screen = getCurrentScreen(for: window) else {
            print("[WindowSnap] No frontmost window or screen found")
            return
        }
        
        // Save current frame for restore
        if action != .restore {
            if let currentFrame = getWindowFrame(window) {
                let pid = getFrontmostAppPID()
                if let pid = pid {
                    savedWindowFrames[pid] = currentFrame
                }
            }
        }
        
        let targetFrame: CGRect
        if action == .restore {
            // Restore to saved frame or center
            let pid = getFrontmostAppPID()
            if let pid = pid, let savedFrame = savedWindowFrames[pid] {
                targetFrame = savedFrame
            } else {
                targetFrame = action.targetFrame(for: screen)
            }
        } else {
            targetFrame = action.targetFrame(for: screen)
        }
        
        // Show Magnet-style preview overlay, then snap
        SnapPreviewWindow.shared.showPreview(at: targetFrame, duration: 0.2)
        
        // Brief delay for visual feedback, then snap
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            setWindowFrame(window, frame: targetFrame)
        }
        
        print("[WindowSnap] Executed action: \(action.title)")
    }
    
    /// Set shortcut for a snap action
    func setShortcut(_ shortcut: SavedShortcut?, for action: SnapAction) {
        // Stop monitoring old shortcut
        stopMonitoringShortcut(for: action)
        
        if let shortcut = shortcut {
            shortcuts[action] = shortcut
            startMonitoringShortcut(for: action)
        } else {
            shortcuts.removeValue(forKey: action)
        }
        
        saveShortcuts()
        
        // Track activation on first shortcut save
        if !shortcuts.isEmpty && !UserDefaults.standard.bool(forKey: "windowSnapTracked") {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "windowSnap")
            UserDefaults.standard.set(true, forKey: "windowSnapTracked")
        }
        
        // Notify menu to refresh
        NotificationCenter.default.post(name: .windowSnapShortcutChanged, object: nil)
    }
    
    /// Load default shortcuts for all actions
    func loadDefaults() {
        for action in SnapAction.allCases {
            if let defaultShortcut = action.defaultShortcut {
                setShortcut(defaultShortcut, for: action)
            }
        }
    }
    
    /// Clear all shortcuts
    func clearAllShortcuts() {
        for action in SnapAction.allCases {
            setShortcut(nil, for: action)
        }
    }
    
    /// Remove default shortcuts only (keep custom ones)
    func removeDefaults() {
        for action in SnapAction.allCases {
            // Check if current shortcut matches the default
            if let currentShortcut = shortcuts[action],
               let defaultShortcut = action.defaultShortcut,
               currentShortcut.keyCode == defaultShortcut.keyCode &&
               currentShortcut.modifiers == defaultShortcut.modifiers {
                setShortcut(nil, for: action)
            }
        }
    }
    
    // MARK: - Extension Removal Cleanup
    
    /// Clean up all Window Snap resources when extension is removed
    func cleanup() {
        print("[WindowSnap] Cleanup starting - stopping \(hotkeyMonitors.count) monitors")
        
        // Stop monitoring all shortcuts
        stopMonitoringAllShortcuts()
        
        print("[WindowSnap] Monitors after stop: \(hotkeyMonitors.count)")
        
        // Clear all shortcuts
        shortcuts.removeAll()
        
        // Clear saved window frames
        savedWindowFrames.removeAll()
        
        // Clear persisted data
        UserDefaults.standard.removeObject(forKey: shortcutsKey)
        UserDefaults.standard.removeObject(forKey: "windowSnapTracked")
        
        // Notify other components
        NotificationCenter.default.post(name: .windowSnapShortcutChanged, object: nil)
        
        print("[WindowSnap] Cleanup complete - isEnabled: \(isEnabled)")
    }

    
    // MARK: - Shortcut Persistence
    
    private func loadShortcuts() {
        guard let data = UserDefaults.standard.data(forKey: shortcutsKey),
              let decoded = try? JSONDecoder().decode([String: SavedShortcut].self, from: data) else {
            return
        }
        
        for (key, shortcut) in decoded {
            if let action = SnapAction(rawValue: key) {
                shortcuts[action] = shortcut
            }
        }
    }
    
    private func saveShortcuts() {
        var toEncode: [String: SavedShortcut] = [:]
        for (action, shortcut) in shortcuts {
            toEncode[action.rawValue] = shortcut
        }
        
        if let encoded = try? JSONEncoder().encode(toEncode) {
            UserDefaults.standard.set(encoded, forKey: shortcutsKey)
        }
    }
    
    // MARK: - Global Hotkey Monitoring
    
    func startMonitoringAllShortcuts() {
        // Don't start if extension is disabled
        guard !ExtensionType.windowSnap.isRemoved else {
            print("[WindowSnap] Extension is disabled, not starting")
            return
        }
        
        for (action, _) in shortcuts {
            startMonitoringShortcut(for: action)
        }
        isEnabled = true
        print("[WindowSnap] Started monitoring \(shortcuts.count) shortcuts")
    }
    
    func stopMonitoringAllShortcuts() {
        for action in SnapAction.allCases {
            stopMonitoringShortcut(for: action)
        }
        isEnabled = false
    }
    
    private func startMonitoringShortcut(for action: SnapAction) {
        // Prevent duplicate monitoring
        guard hotkeyMonitors[action] == nil else { return }
        guard let savedShortcut = shortcuts[action] else { return }
        
        hotkeyMonitors[action] = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // CRITICAL: Check if extension is disabled - stops shortcuts from working
            guard !ExtensionType.windowSnap.isRemoved else { return }
            
            // Mask to only compare control/option/shift/command - ignore function/numericPad flags
            // Arrow keys include .numericPad and .function flags which would break comparison
            let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
            let eventFlags = event.modifierFlags.intersection(relevantModifiers)
            let savedFlags = NSEvent.ModifierFlags(rawValue: savedShortcut.modifiers).intersection(relevantModifiers)
            
            if Int(event.keyCode) == savedShortcut.keyCode &&
               eventFlags == savedFlags {
                DispatchQueue.main.async {
                    self?.executeAction(action)
                }
            }
        }
        
        isEnabled = true
    }
    
    private func stopMonitoringShortcut(for action: SnapAction) {
        if let monitor = hotkeyMonitors[action] {
            NSEvent.removeMonitor(monitor)
            hotkeyMonitors.removeValue(forKey: action)
        }
    }
    
    // MARK: - Permission Checking
    
    private func checkAccessibilityPermission() -> Bool {
        return PermissionManager.shared.isAccessibilityGranted
    }
    
    private func showPermissionAlert() {
        // Use ONLY macOS native dialogs - no Droppy custom dialogs
        print("🔐 WindowSnapManager: Requesting Accessibility via native dialog")
        PermissionManager.shared.requestAccessibility()
    }
    
    // MARK: - Window Manipulation (Accessibility API)
    
    private func getFrontmostWindow() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        var windowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)
        
        guard result == .success else { return nil }
        return (windowValue as! AXUIElement)
    }
    
    private func getFrontmostAppPID() -> pid_t? {
        return NSWorkspace.shared.frontmostApplication?.processIdentifier
    }
    
    private func getCurrentScreen(for window: AXUIElement) -> NSScreen? {
        guard let windowFrame = getWindowFrame(window) else {
            return NSScreen.main
        }
        
        // CRITICAL: AXUIElement returns frame in SCREEN coordinates (Y=0 at top of primary screen)
        // NSScreen.frame uses APPKIT coordinates (Y=0 at bottom of primary screen)
        // We must convert the window frame before comparing with screen frames
        guard let primaryScreen = NSScreen.screens.first else {
            return NSScreen.main
        }
        let primaryHeight = primaryScreen.frame.height
        
        // Convert window frame from screen coords to AppKit coords
        // AppKit Y = primaryHeight - screenY - height
        let appKitWindowFrame = CGRect(
            x: windowFrame.origin.x,
            y: primaryHeight - windowFrame.origin.y - windowFrame.height,
            width: windowFrame.width,
            height: windowFrame.height
        )
        
        // Find the screen that contains most of the window (now in same coordinate system)
        return NSScreen.screens.max(by: { screen1, screen2 in
            let intersection1 = screen1.frame.intersection(appKitWindowFrame)
            let intersection2 = screen2.frame.intersection(appKitWindowFrame)
            return (intersection1.width * intersection1.height) < (intersection2.width * intersection2.height)
        }) ?? NSScreen.main
    }
    
    private func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        // Get position
        var positionValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              let positionValue = positionValue else { return nil }
        
        var position = CGPoint.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) else { return nil }
        
        // Get size
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let sizeValue = sizeValue else { return nil }
        
        var size = CGSize.zero
        guard AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        
        return CGRect(origin: position, size: size)
    }
    
    /// Animate window to target frame with smooth spring physics
    /// Uses the same fluid animation approach as Element Capture
    private func animateWindowToFrame(_ window: AXUIElement, targetFrame: CGRect) {
        guard let currentFrame = getWindowFrame(window) else {
            // No animation possible, set directly
            setWindowFrame(window, frame: targetFrame)
            return
        }
        
        // Calculate spring animation steps
        let stepDuration = animationDuration / Double(animationSteps)
        
        // Spring physics parameters (matching Element Capture)
        let damping: CGFloat = 0.7
        let response: CGFloat = 0.3
        
        var displayedFrame = currentFrame
        var velocity = CGRect.zero
        
        func updateStep(_ step: Int) {
            guard step < animationSteps else { return }
            
            // Spring physics calculation
            let dx = targetFrame.origin.x - displayedFrame.origin.x
            let dy = targetFrame.origin.y - displayedFrame.origin.y
            let dw = targetFrame.width - displayedFrame.width
            let dh = targetFrame.height - displayedFrame.height
            
            // Spring force + damping
            let springForce: CGFloat = 1.0 / (response * response)
            let dampingForce: CGFloat = 2 * damping / response
            
            velocity.origin.x += (springForce * dx - dampingForce * velocity.origin.x) * CGFloat(stepDuration)
            velocity.origin.y += (springForce * dy - dampingForce * velocity.origin.y) * CGFloat(stepDuration)
            velocity.size.width += (springForce * dw - dampingForce * velocity.size.width) * CGFloat(stepDuration)
            velocity.size.height += (springForce * dh - dampingForce * velocity.size.height) * CGFloat(stepDuration)
            
            displayedFrame.origin.x += velocity.origin.x * CGFloat(stepDuration)
            displayedFrame.origin.y += velocity.origin.y * CGFloat(stepDuration)
            displayedFrame.size.width += velocity.size.width * CGFloat(stepDuration)
            displayedFrame.size.height += velocity.size.height * CGFloat(stepDuration)
            
            // Set window frame
            setWindowFrame(window, frame: displayedFrame)
            
            // Continue animation
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) {
                updateStep(step + 1)
            }
        }
        
        // Start animation loop
        updateStep(0)
        
        // Ensure final frame is exact
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.05) {
            self.setWindowFrame(window, frame: targetFrame)
        }
    }
    
    private func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
        // Rectangle's proven pattern: size -> position -> size
        // This handles moving to different displays properly
        
        // Step 1: Set size first
        var size = CGSize(width: frame.width, height: frame.height)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
        
        // Step 2: Set position
        var position = CGPoint(x: frame.origin.x, y: frame.origin.y)
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }
        
        // Step 3: Set size again (macOS enforces sizes that fit on current display)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }
}

// MARK: - CGRect Extension for Animation

private extension CGRect {
    static var zero: CGRect { CGRect(x: 0, y: 0, width: 0, height: 0) }
}
