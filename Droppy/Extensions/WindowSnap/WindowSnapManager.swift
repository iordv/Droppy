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
    // Display movement actions
    case moveToLeftDisplay
    case moveToRightDisplay
    case moveToDisplay1
    case moveToDisplay2
    case moveToDisplay3
    // Display 2 specific snap positions
    case leftHalfDisplay2
    case rightHalfDisplay2
    case maximizeDisplay2
    
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
        case .moveToLeftDisplay: return "Left Display"
        case .moveToRightDisplay: return "Right Display"
        case .moveToDisplay1: return "Display 1"
        case .moveToDisplay2: return "Display 2"
        case .moveToDisplay3: return "Display 3"
        case .leftHalfDisplay2: return "Left ½ Display 2"
        case .rightHalfDisplay2: return "Right ½ Display 2"
        case .maximizeDisplay2: return "Max Display 2"
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
        case .maximize: return "arrow.up.backward.and.arrow.down.forward"
        case .center: return "arrow.up.and.down.and.arrow.left.and.right"
        case .restore: return "arrow.down.forward.and.arrow.up.backward"
        case .moveToLeftDisplay: return "arrow.left.to.line"
        case .moveToRightDisplay: return "arrow.right.to.line"
        case .moveToDisplay1: return "1.circle"
        case .moveToDisplay2: return "2.circle"
        case .moveToDisplay3: return "3.circle"
        case .leftHalfDisplay2: return "rectangle.lefthalf.filled"
        case .rightHalfDisplay2: return "rectangle.righthalf.filled"
        case .maximizeDisplay2: return "arrow.up.backward.and.arrow.down.forward"
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
        // Display movement: Ctrl+Opt+E (left), Ctrl+Opt+R (right), Ctrl+Opt+1/2/3
        case .moveToLeftDisplay:  return SavedShortcut(keyCode: 14, modifiers: ctrlOpt) // E
        case .moveToRightDisplay: return SavedShortcut(keyCode: 15, modifiers: ctrlOpt) // R
        case .moveToDisplay1:     return SavedShortcut(keyCode: 18, modifiers: ctrlOpt) // 1
        case .moveToDisplay2:     return SavedShortcut(keyCode: 19, modifiers: ctrlOpt) // 2
        case .moveToDisplay3:     return SavedShortcut(keyCode: 20, modifiers: ctrlOpt) // 3
        // Display 2 specific positions: no defaults (user configurable)
        case .leftHalfDisplay2:   return nil
        case .rightHalfDisplay2:  return nil
        case .maximizeDisplay2:   return nil
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
        // Display movement actions: center window on target screen
        case .moveToLeftDisplay, .moveToRightDisplay, .moveToDisplay1, .moveToDisplay2, .moveToDisplay3:
            let centerW = visibleW * 2 / 3
            let centerH = visibleH * 2 / 3
            return CGRect(
                x: visibleX + (visibleW - centerW) / 2,
                y: visibleY + (visibleH - centerH) / 2,
                width: centerW,
                height: centerH
            )
        // Display 2 specific positions (calculated relative to display 2)
        case .leftHalfDisplay2:
            return CGRect(x: visibleX, y: visibleY, width: visibleW / 2, height: visibleH)
        case .rightHalfDisplay2:
            return CGRect(x: visibleX + visibleW / 2, y: visibleY, width: visibleW / 2, height: visibleH)
        case .maximizeDisplay2:
            return CGRect(x: visibleX, y: visibleY, width: visibleW, height: visibleH)
        }
    }
    
    /// Whether this action moves windows between displays
    var isDisplayMovement: Bool {
        switch self {
        case .moveToLeftDisplay, .moveToRightDisplay, .moveToDisplay1, .moveToDisplay2, .moveToDisplay3:
            return true
        default:
            return false
        }
    }
    
    /// Whether this action specifically targets display 2
    var isDisplay2Specific: Bool {
        switch self {
        case .leftHalfDisplay2, .rightHalfDisplay2, .maximizeDisplay2:
            return true
        default:
            return false
        }
    }
}

enum WindowSnapResizeMode: String, CaseIterable, Identifiable, Codable {
    case classic
    case closestCorner

    var id: String { rawValue }
}

private enum WindowSnapInteractionType {
    case move
    case resize
}

private enum WindowSnapResizeCorner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

private struct WindowSnapDragState {
    let type: WindowSnapInteractionType
    let window: AXUIElement
    let appPID: pid_t
    let initialFrame: CGRect
    let initialMousePoint: CGPoint  // Screen coordinates (Y=0 at top)
    let resizeCorner: WindowSnapResizeCorner?
    var activeSnapAction: SnapAction?
    var activeSnapFrame: CGRect?
}

private struct WindowSnapPointerTarget {
    let window: AXUIElement
    let app: NSRunningApplication?
    let bundleID: String?
    let pid: pid_t
}

// MARK: - Window Snap Manager

@MainActor
final class WindowSnapManager: ObservableObject {
    static let shared = WindowSnapManager()
    
    // MARK: - Published State
    
    @Published private(set) var isEnabled = false
    @Published var shortcuts: [SnapAction: SavedShortcut] = [:]
    
    // MARK: - Private Properties
    
    private var hotkeyMonitors: [SnapAction: GlobalHotKey] = [:]  // Carbon-based for reliability
    private var savedWindowFrames: [pid_t: CGRect] = [:]  // For restore functionality
    private var pointerDownMonitor: Any?
    private var pointerDragMonitor: Any?
    private var pointerUpMonitor: Any?
    private var pointerFlagsMonitor: Any?
    private var dragState: WindowSnapDragState?
    private var lastDragUpdateAt: TimeInterval = 0
    private var defaultsObserver: NSObjectProtocol?
    
    // Cycle behavior tracking (Rectangle-style repeated shortcut cycling)
    private var lastSnapAction: SnapAction?
    private var lastSnapTime: Date?
    private var lastSnapScreen: NSScreen?
    private let cycleTimeWindow: TimeInterval = 1.5  // Seconds to consider repeated press
    
    // Animation duration for smooth spring animation
    private let animationDuration: TimeInterval = 0.3
    private let animationSteps: Int = 30
    private let pointerFrameInterval: TimeInterval = 1.0 / 120.0
    private let edgeSnapThreshold: CGFloat = 44
    private let edgeSnapStickyInset: CGFloat = 22
    private let minResizeWidth: CGFloat = 360
    private let minResizeHeight: CGFloat = 240

    private let shortcutsKey = "windowSnapShortcuts"
    private let excludedAppsKey = "windowSnapExcludedApps"
    
    // MARK: - Initialization
    
    private init() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPointerMonitoring()
            }
        }
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    var pointerModeEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.windowSnapPointerModeEnabled,
            default: PreferenceDefault.windowSnapPointerModeEnabled
        )
    }

    var bringToFrontWhenHandling: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.windowSnapBringToFrontWhenHandling,
            default: PreferenceDefault.windowSnapBringToFrontWhenHandling
        )
    }

    var resizeMode: WindowSnapResizeMode {
        let raw = UserDefaults.standard.preference(
            AppPreferenceKey.windowSnapResizeMode,
            default: PreferenceDefault.windowSnapResizeMode
        )
        return WindowSnapResizeMode(rawValue: raw) ?? .closestCorner
    }

    var moveModifierMask: UInt {
        let value = UserDefaults.standard.object(forKey: AppPreferenceKey.windowSnapMoveModifierMask) as? NSNumber
        return value?.uintValue ?? PreferenceDefault.windowSnapMoveModifierMask
    }

    var resizeModifierMask: UInt {
        let value = UserDefaults.standard.object(forKey: AppPreferenceKey.windowSnapResizeModifierMask) as? NSNumber
        return value?.uintValue ?? PreferenceDefault.windowSnapResizeModifierMask
    }

    var excludedAppBundleIDs: Set<String> {
        guard let data = UserDefaults.standard.data(forKey: excludedAppsKey),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        return decoded
    }

    func updateExcludedApp(_ bundleID: String, excluded: Bool) {
        var updated = excludedAppBundleIDs
        if excluded {
            updated.insert(bundleID)
        } else {
            updated.remove(bundleID)
        }
        if let encoded = try? JSONEncoder().encode(updated) {
            UserDefaults.standard.set(encoded, forKey: excludedAppsKey)
        }
    }
    
    // DEBUG: Write to file for debugging
    private func debugLog(_ message: String) {
        let logPath = "/tmp/droppy_windowsnap_debug.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
        }
        print(message)  // Also print for console
    }
    
    /// Called from AppDelegate after app finishes launching
    func loadAndStartMonitoring() {
        debugLog("[WindowSnap] loadAndStartMonitoring called")
        
        // Don't start if extension is disabled
        guard !ExtensionType.windowSnap.isRemoved else {
            debugLog("[WindowSnap] Extension is disabled, skipping monitoring")
            print("[WindowSnap] Extension is disabled, skipping monitoring")
            return
        }
        
        // Ensure we don't accumulate stale monitors on repeated boots/enables.
        stopMonitoringAllShortcuts()
        shortcuts.removeAll()

        debugLog("[WindowSnap] Extension is enabled, loading shortcuts…")
        loadShortcuts()
        debugLog("[WindowSnap] Loaded \(shortcuts.count) shortcuts from UserDefaults")

        refreshPointerMonitoring()
        
        if !shortcuts.isEmpty {
            startMonitoringAllShortcuts()
            debugLog("[WindowSnap] Monitoring started for \(shortcuts.count) shortcuts")
        } else {
            debugLog("[WindowSnap] No shortcuts configured, not starting monitors")
            refreshEnabledState()
        }
    }

    /// Re-evaluate runtime monitor state from latest preferences.
    func refreshConfiguration() {
        refreshPointerMonitoring()
        refreshEnabledState()
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
              let currentScreen = getCurrentScreen(for: window) else {
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
        
        // Determine target screen (handles display movement and cycling)
        let targetScreen: NSScreen
        let targetFrame: CGRect
        
        if action.isDisplayMovement {
            // Direct display movement actions
            print("[WindowSnap] Display movement: \(action.title)")
            print("[WindowSnap]   Current screen: \(currentScreen.localizedName)")
            print("[WindowSnap]   Available screens: \(NSScreen.screens.map { $0.localizedName })")
            
            if let screen = getTargetScreen(for: action, from: currentScreen) {
                targetScreen = screen
                // Preserve window size and center on new screen
                targetFrame = preservedPositionFrame(for: window, on: screen)
            } else {
                print("[WindowSnap] No target display found for \(action.title)")
                return
            }
        } else if action.isDisplay2Specific {
            // Snap to specific position on secondary display (non-primary)
            // "Display 2" means the external/secondary monitor, not the second in X-sorted order
            let allScreens = NSScreen.screens
            print("[WindowSnap] Display 2 specific action: \(action.title)")
            print("[WindowSnap]   All screens: \(allScreens.map { "\($0.localizedName) @ x=\($0.frame.origin.x)" })")
            
            // Find the secondary display (first non-primary screen)
            // NSScreen.screens[0] is always the primary display (with menu bar)
            guard allScreens.count > 1 else {
                print("[WindowSnap] Display 2 not available (only \(allScreens.count) display)")
                return
            }
            
            // Target the first non-primary display (screen at index 1+)
            targetScreen = allScreens[1]
            targetFrame = action.targetFrame(for: targetScreen)
            print("[WindowSnap]   Primary screen: \(allScreens[0].localizedName)")
            print("[WindowSnap]   Target screen (secondary): \(targetScreen.localizedName)")
            print("[WindowSnap]   Target frame: \(targetFrame)")
        } else if action == .restore {
            // Restore to saved frame or center
            let pid = getFrontmostAppPID()
            if let pid = pid, let savedFrame = savedWindowFrames[pid] {
                targetFrame = savedFrame
                targetScreen = currentScreen
            } else {
                targetFrame = action.targetFrame(for: currentScreen)
                targetScreen = currentScreen
            }
        } else {
            // Regular snap action - check for cycle behavior
            let now = Date()
            if let lastAction = lastSnapAction,
               let lastTime = lastSnapTime,
               let lastScreen = lastSnapScreen,
               lastAction == action,
               now.timeIntervalSince(lastTime) < cycleTimeWindow {
                // Cycle to next screen
                if let nextScreen = getAdjacentScreen(from: lastScreen, direction: .right) {
                    targetScreen = nextScreen
                    lastSnapScreen = nextScreen
                } else {
                    // Wrap around to first screen
                    targetScreen = getScreensSortedByPosition().first ?? currentScreen
                    lastSnapScreen = targetScreen
                }
            } else {
                // First press or different action
                targetScreen = currentScreen
                lastSnapScreen = currentScreen
            }
            
            targetFrame = action.targetFrame(for: targetScreen)
            lastSnapAction = action
            lastSnapTime = now
        }
        
        // Keep preview hint, but commit snap immediately for reliable behavior.
        SnapPreviewWindow.shared.showPreview(at: targetFrame, duration: 0.12)
        setWindowFrame(window, frame: targetFrame)
        
        print("[WindowSnap] Executed action: \(action.title) on \(targetScreen.localizedName)")
    }
    
    /// Set shortcut for a snap action
    func setShortcut(_ shortcut: SavedShortcut?, for action: SnapAction) {
        // Stop monitoring old shortcut
        stopMonitoringShortcut(for: action)
        
        if let shortcut = shortcut {
            let sanitized = sanitizedShortcut(shortcut)
            shortcuts[action] = sanitized
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
        shortcuts.removeAll()
        print("[WindowSnap] loadShortcuts: Reading from key '\(shortcutsKey)'")
        
        guard let data = UserDefaults.standard.data(forKey: shortcutsKey) else {
            print("[WindowSnap] loadShortcuts: No data found in UserDefaults")
            return
        }
        
        print("[WindowSnap] loadShortcuts: Found \(data.count) bytes of data")
        
        guard let decoded = try? JSONDecoder().decode([String: SavedShortcut].self, from: data) else {
            print("[WindowSnap] loadShortcuts: Failed to decode shortcut data")
            return
        }
        
        print("[WindowSnap] loadShortcuts: Decoded \(decoded.count) shortcuts")
        
        for (key, shortcut) in decoded {
            if let action = SnapAction(rawValue: key) {
                let sanitized = sanitizedShortcut(shortcut)
                shortcuts[action] = sanitized
                print("[WindowSnap] loadShortcuts: Loaded \(action.title) -> keyCode=\(sanitized.keyCode), modifiers=\(sanitized.modifiers)")
            } else {
                print("[WindowSnap] loadShortcuts: Unknown action key '\(key)'")
            }
        }
    }
    
    private func saveShortcuts() {
        var toEncode: [String: SavedShortcut] = [:]
        for (action, shortcut) in shortcuts {
            toEncode[action.rawValue] = shortcut
        }
        
        print("[WindowSnap] Saving \(toEncode.count) shortcuts to UserDefaults")
        
        do {
            let encoded = try JSONEncoder().encode(toEncode)
            UserDefaults.standard.set(encoded, forKey: shortcutsKey)
            
            // Force synchronize and verify
            UserDefaults.standard.synchronize()
            
            // Read back to verify
            if let readBack = UserDefaults.standard.data(forKey: shortcutsKey) {
                print("[WindowSnap] Successfully saved and verified shortcuts (\(readBack.count) bytes)")
            } else {
                print("[WindowSnap] ERROR: Save appeared to succeed but data cannot be read back!")
            }
        } catch {
            print("[WindowSnap] ERROR: Failed to encode shortcuts: \(error)")
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
        print("[WindowSnap] Started monitoring \(shortcuts.count) shortcuts")
        refreshPointerMonitoring()
        refreshEnabledState()
    }
    
    func stopMonitoringAllShortcuts() {
        for action in SnapAction.allCases {
            stopMonitoringShortcut(for: action)
        }
        stopPointerMonitoring()
        refreshEnabledState()
    }
    
    private func startMonitoringShortcut(for action: SnapAction) {
        // Prevent duplicate monitoring
        guard hotkeyMonitors[action] == nil else { return }
        guard let savedShortcut = shortcuts[action] else { return }
        
        debugLog("[WindowSnap] Registering GlobalHotKey for \(action.title): keyCode=\(savedShortcut.keyCode), modifiers=\(savedShortcut.modifiers)")
        
        // Use GlobalHotKey (Carbon-based) for reliable global shortcut detection
        hotkeyMonitors[action] = GlobalHotKey(
            keyCode: savedShortcut.keyCode,
            modifiers: savedShortcut.modifiers,
            enableIOHIDFallback: false
        ) { [weak self] in
            guard let self = self else { return }
            // CRITICAL: Check if extension is disabled
            guard !ExtensionType.windowSnap.isRemoved else { return }
            
            self.debugLog("[WindowSnap] ✅ Shortcut triggered via GlobalHotKey: \(action.title)")
            self.executeAction(action)
        }
        
        refreshEnabledState()
    }
    
    private func stopMonitoringShortcut(for action: SnapAction) {
        hotkeyMonitors.removeValue(forKey: action)  // GlobalHotKey deinit handles unregistration
        refreshEnabledState()
    }

    private func refreshEnabledState() {
        isEnabled = !hotkeyMonitors.isEmpty || pointerMonitorsAreActive
    }

    private var shouldStartPointerMonitoring: Bool {
        pointerModeEnabled && !ExtensionType.windowSnap.isRemoved
    }

    private var pointerMonitorsAreActive: Bool {
        pointerDownMonitor != nil ||
        pointerDragMonitor != nil ||
        pointerUpMonitor != nil ||
        pointerFlagsMonitor != nil
    }

    private func refreshPointerMonitoring() {
        if shouldStartPointerMonitoring {
            startPointerMonitoring()
        } else {
            stopPointerMonitoring()
        }
    }

    private func sanitizedShortcut(_ shortcut: SavedShortcut) -> SavedShortcut {
        let allowed: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let normalized = NSEvent.ModifierFlags(rawValue: shortcut.modifiers).intersection(allowed)
        return SavedShortcut(keyCode: shortcut.keyCode, modifiers: normalized.rawValue)
    }

    private func startPointerMonitoring() {
        guard shouldStartPointerMonitoring else {
            stopPointerMonitoring()
            return
        }

        guard pointerDownMonitor == nil else {
            refreshEnabledState()
            return
        }

        pointerDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let location = event.locationInWindow
            let modifiers = event.modifierFlags
            Task { @MainActor [weak self] in
                self?.handlePointerMouseDown(location: location, modifiers: modifiers)
            }
        }

        refreshEnabledState()
    }

    private func startPointerSessionMonitoring() {
        guard shouldStartPointerMonitoring else { return }

        if pointerDragMonitor == nil {
            pointerDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
                let location = event.locationInWindow
                let modifiers = event.modifierFlags
                Task { @MainActor [weak self] in
                    self?.handlePointerMouseDragged(location: location, modifiers: modifiers)
                }
            }
        }

        if pointerUpMonitor == nil {
            pointerUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handlePointerMouseUp()
                }
            }
        }

        if pointerFlagsMonitor == nil {
            pointerFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                let modifiers = event.modifierFlags
                Task { @MainActor [weak self] in
                    self?.handlePointerFlagsChanged(modifiers: modifiers)
                }
            }
        }

        refreshEnabledState()
    }

    private func stopPointerSessionMonitoring() {
        if let monitor = pointerDragMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = pointerUpMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = pointerFlagsMonitor { NSEvent.removeMonitor(monitor) }

        pointerDragMonitor = nil
        pointerUpMonitor = nil
        pointerFlagsMonitor = nil
        refreshEnabledState()
    }

    private func stopPointerMonitoring() {
        if let monitor = pointerDownMonitor { NSEvent.removeMonitor(monitor) }
        pointerDownMonitor = nil
        stopPointerSessionMonitoring()
        dragState = nil
        SnapPreviewWindow.shared.hidePreview()
        refreshEnabledState()
    }

    private func handlePointerMouseDown(location _: CGPoint, modifiers: NSEvent.ModifierFlags) {
        guard shouldStartPointerMonitoring else { return }

        let normalizedModifiers = normalizedModifierFlags(modifiers)
        guard let interaction = interactionType(for: normalizedModifiers) else { return }

        guard checkAccessibilityPermission() else {
            showPermissionAlert()
            return
        }

        let pointer = convertAppKitPointToScreenPoint(NSEvent.mouseLocation)
        guard let target = resolvePointerTarget(at: pointer) else { return }

        if let bundleID = target.bundleID {
            if bundleID == Bundle.main.bundleIdentifier || excludedAppBundleIDs.contains(bundleID) {
                return
            }
        }

        if bringToFrontWhenHandling {
            _ = target.app?.activate()
        }

        guard let initialFrame = getWindowFrame(target.window) else { return }
        let resizeCorner = interaction == .resize ? resolvedResizeCorner(for: initialFrame, pointer: pointer) : nil

        dragState = WindowSnapDragState(
            type: interaction,
            window: target.window,
            appPID: target.pid,
            initialFrame: initialFrame,
            initialMousePoint: pointer,
            resizeCorner: resizeCorner,
            activeSnapAction: nil,
            activeSnapFrame: nil
        )

        startPointerSessionMonitoring()
        savedWindowFrames[target.pid] = initialFrame
        lastDragUpdateAt = 0
    }

    private func handlePointerMouseDragged(location _: CGPoint, modifiers: NSEvent.ModifierFlags) {
        guard var state = dragState, shouldStartPointerMonitoring else { return }

        let now = ProcessInfo.processInfo.systemUptime
        if now - lastDragUpdateAt < pointerFrameInterval { return }
        lastDragUpdateAt = now

        let normalizedModifiers = normalizedModifierFlags(modifiers)
        guard modifiersMatch(normalizedModifiers, for: state.type) else {
            finishDragSession(commitSnap: true)
            return
        }

        let currentPointer = convertAppKitPointToScreenPoint(NSEvent.mouseLocation)
        let delta = CGPoint(
            x: currentPointer.x - state.initialMousePoint.x,
            y: currentPointer.y - state.initialMousePoint.y
        )

        let proposedFrame: CGRect
        switch state.type {
        case .move:
            proposedFrame = CGRect(
                x: state.initialFrame.origin.x + delta.x,
                y: state.initialFrame.origin.y + delta.y,
                width: state.initialFrame.width,
                height: state.initialFrame.height
            )
        case .resize:
            proposedFrame = resizedFrame(
                from: state.initialFrame,
                corner: state.resizeCorner ?? .bottomRight,
                delta: delta
            )
        }

        if state.type == .move, let screen = screenForScreenPoint(currentPointer) {
            if let snapAction = detectSnapAction(at: currentPointer, on: screen) {
                let snapFrame = snapAction.targetFrame(for: screen)
                if state.activeSnapAction != snapAction || state.activeSnapFrame != snapFrame {
                    SnapPreviewWindow.shared.showPreview(at: snapFrame, duration: 0)
                }
                state.activeSnapAction = snapAction
                state.activeSnapFrame = snapFrame
            } else if let activeAction = state.activeSnapAction,
                      isPointerWithinStickySnapZone(pointer: currentPointer, on: screen, action: activeAction) {
                // Keep current preview/action while pointer jitters near the same edge/corner.
            } else {
                if state.activeSnapAction != nil {
                    SnapPreviewWindow.shared.hidePreview()
                }
                state.activeSnapAction = nil
                state.activeSnapFrame = nil
            }
        } else {
            // Resizing should not also edge-snap; keep behavior deterministic.
            if state.activeSnapAction != nil {
                SnapPreviewWindow.shared.hidePreview()
            }
            state.activeSnapAction = nil
            state.activeSnapFrame = nil
        }

        if state.type == .move {
            setWindowPosition(state.window, position: proposedFrame.origin)
        } else {
            setWindowFrame(state.window, frame: proposedFrame)
        }
        dragState = state
    }

    private func handlePointerMouseUp() {
        guard dragState != nil else { return }
        finishDragSession(commitSnap: true)
    }

    private func handlePointerFlagsChanged(modifiers: NSEvent.ModifierFlags) {
        guard let state = dragState else { return }
        let normalizedModifiers = normalizedModifierFlags(modifiers)
        if !modifiersMatch(normalizedModifiers, for: state.type) {
            finishDragSession(commitSnap: true)
        }
    }

    private func finishDragSession(commitSnap: Bool) {
        guard let state = dragState else {
            stopPointerSessionMonitoring()
            return
        }

        if commitSnap, let snapFrame = state.activeSnapFrame {
            setWindowFrame(state.window, frame: snapFrame)
        }

        SnapPreviewWindow.shared.hidePreview()
        dragState = nil
        stopPointerSessionMonitoring()
    }

    private func interactionType(for modifiers: NSEvent.ModifierFlags) -> WindowSnapInteractionType? {
        if modifiersMatch(modifiers, requiredMask: resizeModifierMask) {
            return .resize
        }
        if modifiersMatch(modifiers, requiredMask: moveModifierMask) {
            return .move
        }
        return nil
    }

    private func normalizedModifierFlags(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.command, .option, .control, .shift, .function])
    }

    private func modifierFlags(from mask: UInt) -> NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: mask).intersection([.command, .option, .control, .shift, .function])
    }

    private func modifiersMatch(_ current: NSEvent.ModifierFlags, requiredMask: UInt) -> Bool {
        let required = modifierFlags(from: requiredMask)
        guard !required.isEmpty else { return false }
        return normalizedModifierFlags(current) == required
    }

    private func modifiersMatch(_ current: NSEvent.ModifierFlags, for interaction: WindowSnapInteractionType) -> Bool {
        switch interaction {
        case .move:
            return modifiersMatch(current, requiredMask: moveModifierMask)
        case .resize:
            return modifiersMatch(current, requiredMask: resizeModifierMask)
        }
    }

    private func resolvedResizeCorner(for frame: CGRect, pointer: CGPoint) -> WindowSnapResizeCorner {
        guard resizeMode == .closestCorner else { return .bottomRight }

        let corners: [(WindowSnapResizeCorner, CGPoint)] = [
            (.topLeft, CGPoint(x: frame.minX, y: frame.minY)),
            (.topRight, CGPoint(x: frame.maxX, y: frame.minY)),
            (.bottomLeft, CGPoint(x: frame.minX, y: frame.maxY)),
            (.bottomRight, CGPoint(x: frame.maxX, y: frame.maxY))
        ]

        return corners.min(by: { lhs, rhs in
            let ld = hypot(lhs.1.x - pointer.x, lhs.1.y - pointer.y)
            let rd = hypot(rhs.1.x - pointer.x, rhs.1.y - pointer.y)
            return ld < rd
        })?.0 ?? .bottomRight
    }

    private func resizedFrame(from initialFrame: CGRect, corner: WindowSnapResizeCorner, delta: CGPoint) -> CGRect {
        switch corner {
        case .bottomRight:
            let width = max(minResizeWidth, initialFrame.width + delta.x)
            let height = max(minResizeHeight, initialFrame.height + delta.y)
            return CGRect(x: initialFrame.minX, y: initialFrame.minY, width: width, height: height)
        case .topLeft:
            let width = max(minResizeWidth, initialFrame.width - delta.x)
            let height = max(minResizeHeight, initialFrame.height - delta.y)
            return CGRect(
                x: initialFrame.maxX - width,
                y: initialFrame.maxY - height,
                width: width,
                height: height
            )
        case .topRight:
            let width = max(minResizeWidth, initialFrame.width + delta.x)
            let height = max(minResizeHeight, initialFrame.height - delta.y)
            return CGRect(
                x: initialFrame.minX,
                y: initialFrame.maxY - height,
                width: width,
                height: height
            )
        case .bottomLeft:
            let width = max(minResizeWidth, initialFrame.width - delta.x)
            let height = max(minResizeHeight, initialFrame.height + delta.y)
            return CGRect(
                x: initialFrame.maxX - width,
                y: initialFrame.minY,
                width: width,
                height: height
            )
        }
    }

    private func screenForScreenPoint(_ point: CGPoint) -> NSScreen? {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSScreen.screens.first { screen in
            let frame = screen.frame
            let screenCoordsFrame = CGRect(
                x: frame.origin.x,
                y: primaryHeight - frame.origin.y - frame.height,
                width: frame.width,
                height: frame.height
            )
            return screenCoordsFrame.insetBy(dx: -1, dy: -1).contains(point)
        } ?? NSScreen.main
    }

    private func resolvePointerTarget(at screenPoint: CGPoint) -> WindowSnapPointerTarget? {
        let systemElement = AXUIElementCreateSystemWide()
        var hitElement: AXUIElement?
        let hitStatus = AXUIElementCopyElementAtPosition(systemElement, Float(screenPoint.x), Float(screenPoint.y), &hitElement)

        if hitStatus == .success, let hitElement {
            if let window = resolveWindowElement(from: hitElement) {
                var pid: pid_t = 0
                AXUIElementGetPid(window, &pid)
                if pid != 0 && pid != ProcessInfo.processInfo.processIdentifier {
                    let app = NSRunningApplication(processIdentifier: pid)
                    return WindowSnapPointerTarget(
                        window: window,
                        app: app,
                        bundleID: app?.bundleIdentifier,
                        pid: pid
                    )
                }
            }
        }

        // Fallback for apps that don't expose hit-testing cleanly.
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontmostApp.processIdentifier
        guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }
        guard let window = getFrontmostWindow() else { return nil }

        return WindowSnapPointerTarget(
            window: window,
            app: frontmostApp,
            bundleID: frontmostApp.bundleIdentifier,
            pid: pid
        )
    }

    private func resolveWindowElement(from element: AXUIElement) -> AXUIElement? {
        // Prefer direct window attribute if available.
        if let directWindow = copyAXElementAttribute(from: element, attribute: kAXWindowAttribute as CFString) {
            return directWindow
        }

        var current: AXUIElement? = element
        for _ in 0..<10 {
            guard let node = current else { break }
            if let role = copyAXStringAttribute(from: node, attribute: kAXRoleAttribute as CFString),
               role == (kAXWindowRole as String) {
                return node
            }
            current = copyAXElementAttribute(from: node, attribute: kAXParentAttribute as CFString)
        }
        return nil
    }

    private func copyAXElementAttribute(from element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func copyAXStringAttribute(from element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              let string = value as? String else {
            return nil
        }
        return string
    }

    private func convertAppKitPointToScreenPoint(_ appKitPoint: CGPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: appKitPoint.x, y: primaryHeight - appKitPoint.y)
    }

    private func visibleFrameInScreenCoordinates(for screen: NSScreen) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let visible = screen.visibleFrame
        return CGRect(
            x: visible.origin.x,
            y: primaryHeight - visible.origin.y - visible.height,
            width: visible.width,
            height: visible.height
        )
    }

    private func detectSnapAction(at pointer: CGPoint, on screen: NSScreen) -> SnapAction? {
        let visible = visibleFrameInScreenCoordinates(for: screen)
        let expandedBounds = visible.insetBy(dx: -edgeSnapThreshold, dy: -edgeSnapThreshold)
        guard expandedBounds.contains(pointer) else { return nil }

        let nearLeft = pointer.x <= visible.minX + edgeSnapThreshold
        let nearRight = pointer.x >= visible.maxX - edgeSnapThreshold
        let nearTop = pointer.y <= visible.minY + edgeSnapThreshold
        let nearBottom = pointer.y >= visible.maxY - edgeSnapThreshold

        if nearTop && nearLeft { return .topLeft }
        if nearTop && nearRight { return .topRight }
        if nearBottom && nearLeft { return .bottomLeft }
        if nearBottom && nearRight { return .bottomRight }
        if nearTop { return .maximize }
        if nearLeft { return .leftHalf }
        if nearRight { return .rightHalf }
        if nearBottom { return .bottomHalf }
        return nil
    }

    private func isPointerWithinStickySnapZone(pointer: CGPoint, on screen: NSScreen, action: SnapAction) -> Bool {
        let visible = visibleFrameInScreenCoordinates(for: screen)
        let sticky = edgeSnapThreshold + edgeSnapStickyInset

        let nearLeft = pointer.x <= visible.minX + sticky
        let nearRight = pointer.x >= visible.maxX - sticky
        let nearTop = pointer.y <= visible.minY + sticky
        let nearBottom = pointer.y >= visible.maxY - sticky

        switch action {
        case .topLeft:
            return nearTop && nearLeft
        case .topRight:
            return nearTop && nearRight
        case .bottomLeft:
            return nearBottom && nearLeft
        case .bottomRight:
            return nearBottom && nearRight
        case .maximize:
            return nearTop
        case .leftHalf:
            return nearLeft
        case .rightHalf:
            return nearRight
        case .bottomHalf:
            return nearBottom
        default:
            return false
        }
    }

    // MARK: - Permission Checking
    
    private func checkAccessibilityPermission() -> Bool {
        return PermissionManager.shared.isAccessibilityGranted
    }
    
    private func showPermissionAlert() {
        // Use ONLY macOS native dialogs - no Droppy custom dialogs
        print("🔐 WindowSnapManager: Requesting Accessibility via native dialog")
        PermissionManager.shared.requestAccessibility(context: .userInitiated)
    }
    
    // MARK: - Window Manipulation (Accessibility API)
    
    private func getFrontmostWindow() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        var windowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)
        
        guard result == .success, windowValue != nil else { return nil }
        // CF type cast always succeeds - the AX API guarantees the type when result is .success
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
        // CF type cast always succeeds when AXUIElementCopyAttributeValue returns .success
        let axPositionValue = positionValue as! AXValue
        guard AXValueGetValue(axPositionValue, .cgPoint, &position) else { return nil }
        
        // Get size
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let sizeValue = sizeValue else { return nil }
        
        var size = CGSize.zero
        // CF type cast always succeeds when AXUIElementCopyAttributeValue returns .success
        let axSizeValue = sizeValue as! AXValue
        guard AXValueGetValue(axSizeValue, .cgSize, &size) else { return nil }
        
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

    private func setWindowPosition(_ window: AXUIElement, position: CGPoint) {
        var position = position
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }
    }
    
    // MARK: - Multi-Display Navigation
    
    enum ScreenDirection {
        case left
        case right
    }
    
    /// Get all screens sorted by their X position (left to right)
    private func getScreensSortedByPosition() -> [NSScreen] {
        return NSScreen.screens.sorted { $0.frame.origin.x < $1.frame.origin.x }
    }
    
    /// Get adjacent screen in specified direction
    private func getAdjacentScreen(from screen: NSScreen, direction: ScreenDirection) -> NSScreen? {
        let sortedScreens = getScreensSortedByPosition()
        guard let currentIndex = sortedScreens.firstIndex(of: screen) else { return nil }
        
        switch direction {
        case .left:
            guard currentIndex > 0 else { return nil }
            return sortedScreens[currentIndex - 1]
        case .right:
            guard currentIndex < sortedScreens.count - 1 else { return nil }
            return sortedScreens[currentIndex + 1]
        }
    }
    
    /// Get target screen for a display movement action
    private func getTargetScreen(for action: SnapAction, from currentScreen: NSScreen) -> NSScreen? {
        let allScreens = NSScreen.screens  // [0] is always primary
        
        switch action {
        case .moveToLeftDisplay:
            return getAdjacentScreen(from: currentScreen, direction: .left)
        case .moveToRightDisplay:
            return getAdjacentScreen(from: currentScreen, direction: .right)
        case .moveToDisplay1:
            // Display 1 = primary display (the one with menu bar)
            return allScreens.count > 0 ? allScreens[0] : nil
        case .moveToDisplay2:
            // Display 2 = first secondary display
            return allScreens.count > 1 ? allScreens[1] : nil
        case .moveToDisplay3:
            // Display 3 = second secondary display
            return allScreens.count > 2 ? allScreens[2] : nil
        default:
            return currentScreen
        }
    }
    
    /// Calculate window frame that preserves relative position when moving to new screen
    private func preservedPositionFrame(for window: AXUIElement, on targetScreen: NSScreen) -> CGRect {
        guard let currentFrame = getWindowFrame(window) else {
            // Fallback: center on new screen
            return SnapAction.center.targetFrame(for: targetScreen)
        }
        
        guard let currentScreen = getCurrentScreen(for: window) else {
            return SnapAction.center.targetFrame(for: targetScreen)
        }
        
        // Convert coordinates for proper calculation
        guard let primaryScreen = NSScreen.screens.first else {
            return SnapAction.center.targetFrame(for: targetScreen)
        }
        let primaryHeight = primaryScreen.frame.height
        
        // Convert source screen visible frame to screen coordinates
        // NSScreen uses AppKit coords (Y=0 at bottom), AXUIElement uses screen coords (Y=0 at top)
        let sourceVisible = currentScreen.visibleFrame
        let sourceVisibleScreenY = primaryHeight - sourceVisible.origin.y - sourceVisible.height
        
        // Convert target screen visible frame to screen coordinates
        let targetVisible = targetScreen.visibleFrame
        let targetVisibleScreenY = primaryHeight - targetVisible.origin.y - targetVisible.height
        
        // Calculate relative position (0.0 to 1.0) within source visible area
        // X coordinate is the same in both coordinate systems
        let relativeX = (currentFrame.origin.x - sourceVisible.origin.x) / sourceVisible.width
        let relativeY = (currentFrame.origin.y - sourceVisibleScreenY) / sourceVisible.height
        
        // Preserve window size (clamped to target screen)
        let newWidth = min(currentFrame.width, targetVisible.width)
        let newHeight = min(currentFrame.height, targetVisible.height)
        
        // Apply relative position to target screen
        var newX = targetVisible.origin.x + (relativeX * targetVisible.width)
        var newY = targetVisibleScreenY + (relativeY * targetVisible.height)
        
        // Clamp to visible bounds to ensure window stays on screen
        newX = max(targetVisible.origin.x, min(newX, targetVisible.origin.x + targetVisible.width - newWidth))
        newY = max(targetVisibleScreenY, min(newY, targetVisibleScreenY + targetVisible.height - newHeight))
        
        print("[WindowSnap] Moving to display: \(targetScreen.localizedName)")
        print("[WindowSnap]   Source: \(currentScreen.localizedName) frame=\(currentFrame)")
        print("[WindowSnap]   Target frame: (\(Int(newX)), \(Int(newY)), \(Int(newWidth)), \(Int(newHeight)))")
        
        return CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
    }
}

// MARK: - CGRect Extension for Animation

private extension CGRect {
    static var zero: CGRect { CGRect(x: 0, y: 0, width: 0, height: 0) }
}
