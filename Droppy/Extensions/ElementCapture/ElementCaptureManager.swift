//
//  ElementCaptureManager.swift
//  Droppy
//
//  Magic Element Screenshot - Capture any UI element by hovering and clicking
//  Inspired by Arc Browser's element capture feature
//
//  REQUIRED INFO.PLIST KEYS:
//  <key>NSAccessibilityUsageDescription</key>
//  <string>Droppy needs Accessibility access to detect UI elements for the Element Capture feature.</string>
//
//  <key>NSScreenCaptureUsageDescription</key>
//  <string>Droppy needs Screen Recording access to capture screenshots of UI elements.</string>
//

import SwiftUI
import AppKit
import Combine
import ScreenCaptureKit
import ApplicationServices

// MARK: - Capture Mode
enum ElementCaptureMode: String, CaseIterable, Identifiable {
    case element = "element"
    case fullscreen = "fullscreen"
    case window = "window"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .element: return "Element"
        case .fullscreen: return "Fullscreen"
        case .window: return "Window"
        }
    }
    
    var icon: String {
        switch self {
        case .element: return "viewfinder"
        case .fullscreen: return "rectangle.dashed"
        case .window: return "macwindow"
        }
    }
    
    var shortcutKey: String {
        switch self {
        case .element: return "elementCaptureShortcut"
        case .fullscreen: return "elementCaptureFullscreenShortcut"
        case .window: return "elementCaptureWindowShortcut"
        }
    }
}

// MARK: - Editor Shortcut Actions
enum EditorShortcut: String, CaseIterable, Identifiable {
    // Tool shortcuts
    case arrow, line, rectangle, ellipse, freehand, highlighter, blur, text
    // Action shortcuts
    case strokeSmall, strokeMedium, strokeLarge
    case zoomIn, zoomOut, zoomReset
    case undo, redo
    case cancel, done
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .arrow: return "Arrow"
        case .line: return "Line"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .freehand: return "Freehand"
        case .highlighter: return "Highlighter"
        case .blur: return "Blur"
        case .text: return "Text"
        case .strokeSmall: return "Small Stroke"
        case .strokeMedium: return "Medium Stroke"
        case .strokeLarge: return "Large Stroke"
        case .zoomIn: return "Zoom In"
        case .zoomOut: return "Zoom Out"
        case .zoomReset: return "Reset Zoom"
        case .undo: return "Undo"
        case .redo: return "Redo"
        case .cancel: return "Cancel"
        case .done: return "Done"
        }
    }
    
    var icon: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .freehand: return "scribble"
        case .highlighter: return "highlighter"
        case .blur: return "eye.slash"
        case .text: return "textformat"
        case .strokeSmall: return "1.circle"
        case .strokeMedium: return "2.circle"
        case .strokeLarge: return "3.circle"
        case .zoomIn: return "plus.magnifyingglass"
        case .zoomOut: return "minus.magnifyingglass"
        case .zoomReset: return "arrow.counterclockwise"
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .cancel: return "xmark"
        case .done: return "checkmark"
        }
    }
    
    var shortcutKey: String {
        "elementCaptureEditor_\(rawValue)"
    }
    
    /// Default key code (Carbon key codes)
    var defaultKeyCode: Int {
        switch self {
        case .arrow: return 0        // A
        case .line: return 37        // L
        case .rectangle: return 15   // R
        case .ellipse: return 31     // O
        case .freehand: return 3     // F
        case .highlighter: return 4  // H
        case .blur: return 11        // B
        case .text: return 17        // T
        case .strokeSmall: return 18  // 1
        case .strokeMedium: return 19 // 2
        case .strokeLarge: return 20  // 3
        case .zoomIn: return 24       // =
        case .zoomOut: return 27      // -
        case .zoomReset: return 29    // 0
        case .undo: return 6          // Z (needs Command modifier)
        case .redo: return 6          // Z (needs Command+Shift modifier)
        case .cancel: return 53       // Escape
        case .done: return 36         // Return
        }
    }
    
    /// Default modifiers (raw value)
    var defaultModifiers: UInt {
        switch self {
        case .undo: return NSEvent.ModifierFlags.command.rawValue
        case .redo: return NSEvent.ModifierFlags.command.union(.shift).rawValue
        default: return 0
        }
    }
    
    /// Default shortcut as SavedShortcut
    var defaultShortcut: SavedShortcut {
        SavedShortcut(keyCode: defaultKeyCode, modifiers: defaultModifiers)
    }
    
    /// Is this a tool shortcut vs action shortcut
    var isTool: Bool {
        switch self {
        case .arrow, .line, .rectangle, .ellipse, .freehand, .highlighter, .blur, .text:
            return true
        default:
            return false
        }
    }
    
    /// Tool shortcuts only
    static var tools: [EditorShortcut] {
        [.arrow, .line, .rectangle, .ellipse, .freehand, .highlighter, .blur, .text]
    }
    
    /// Action shortcuts only
    static var actions: [EditorShortcut] {
        [.strokeSmall, .strokeMedium, .strokeLarge, .zoomIn, .zoomOut, .zoomReset, .undo, .redo, .cancel, .done]
    }
}

// MARK: - Element Capture Manager

@MainActor
final class ElementCaptureManager: ObservableObject {
    static let shared = ElementCaptureManager()
    
    // MARK: - Published State
    
    @Published private(set) var isActive = false
    @Published private(set) var currentElementFrame: CGRect = .zero
    @Published private(set) var hasElement = false
    @Published var shortcut: SavedShortcut? {
        didSet { saveShortcut(for: .element) }
    }
    @Published var fullscreenShortcut: SavedShortcut? {
        didSet { saveShortcut(for: .fullscreen) }
    }
    @Published var windowShortcut: SavedShortcut? {
        didSet { saveShortcut(for: .window) }
    }
    @Published private(set) var isShortcutEnabled = false
    
    // MARK: - Private Properties
    
    private var highlightWindow: ElementHighlightWindow?
    private var mouseTrackingTimer: Timer?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastDetectedFrame: CGRect = .zero
    private var globalHotKeys: [ElementCaptureMode: GlobalHotKey] = [:]  // Multiple hot keys
    private var escapeMonitor: Any?  // Local monitor for ESC key
    private var activeMode: ElementCaptureMode = .element  // Current capture mode
    
    // MARK: - Configuration
    
    private let highlightPadding: CGFloat = 4.0
    private let highlightColor = NSColor.systemCyan
    private let borderWidth: CGFloat = 2.0
    private let cornerRadius: CGFloat = 6.0
    private let mousePollingInterval: TimeInterval = 1.0 / 60.0  // 60 FPS
    
    // MARK: - Initialization
    
    private init() {
        // Empty - shortcuts loaded via loadAndStartMonitoring after app launch
    }
    
    /// Called from AppDelegate after app finishes launching
    func loadAndStartMonitoring() {
        // Don't start if extension is disabled
        guard !ExtensionType.elementCapture.isRemoved else {
            print("[ElementCapture] Extension is disabled, skipping monitoring")
            return
        }
        
        loadAllShortcuts()
        startMonitoringAllShortcuts()
    }
    
    // MARK: - Public API
    
    /// Get shortcut for a specific mode
    func shortcut(for mode: ElementCaptureMode) -> SavedShortcut? {
        switch mode {
        case .element: return shortcut
        case .fullscreen: return fullscreenShortcut
        case .window: return windowShortcut
        }
    }
    
    /// Set shortcut for a specific mode
    func setShortcut(_ newShortcut: SavedShortcut?, for mode: ElementCaptureMode) {
        switch mode {
        case .element: shortcut = newShortcut
        case .fullscreen: fullscreenShortcut = newShortcut
        case .window: windowShortcut = newShortcut
        }
    }
    
    /// Start element capture mode
    func startCaptureMode(mode: ElementCaptureMode = .element) {
        // Don't start if extension is disabled
        guard !ExtensionType.elementCapture.isRemoved else {
            print("[ElementCapture] Extension is disabled, ignoring")
            return
        }
        
        guard !isActive else { return }
        
        // Check permissions first
        guard checkPermissions() else {
            showPermissionAlert()
            return
        }
        
        activeMode = mode
        isActive = true
        
        switch mode {
        case .element:
            // Element mode: show highlight & track mouse
            setupHighlightWindow()
            startMouseTracking()
            installEventTap()
            installEscapeMonitor()
            NSCursor.crosshair.push()
            
        case .fullscreen:
            // Fullscreen: immediately capture the entire screen
            Task {
                await captureFullscreen()
            }
            return
            
        case .window:
            // Window mode: capture the window under cursor
            Task {
                await captureWindowUnderCursor()
            }
            return
        }
        
        print("[ElementCapture] Capture mode started: \\(mode.displayName)")
    }
    
    /// Stop element capture mode
    func stopCaptureMode() {
        guard isActive else { return }
        
        isActive = false
        hasElement = false
        currentElementFrame = .zero
        lastDetectedFrame = .zero
        
        // Stop mouse tracking
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
        
        // Remove event tap
        removeEventTap()
        
        // Remove ESC monitor
        removeEscapeMonitor()
        
        // Hide and destroy overlay
        highlightWindow?.orderOut(nil)
        highlightWindow = nil
        currentScreenDisplayID = 0
        
        // Restore cursor
        NSCursor.pop()
        
        print("[ElementCapture] Capture mode stopped")
    }
    
    // MARK: - Shortcut Persistence
    
    private func loadAllShortcuts() {
        for mode in ElementCaptureMode.allCases {
            if let data = UserDefaults.standard.data(forKey: mode.shortcutKey),
               let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
                switch mode {
                case .element: shortcut = decoded
                case .fullscreen: fullscreenShortcut = decoded
                case .window: windowShortcut = decoded
                }
            }
        }
    }
    
    private func saveShortcut(for mode: ElementCaptureMode) {
        let currentShortcut = self.shortcut(for: mode)
        if let s = currentShortcut, let encoded = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(encoded, forKey: mode.shortcutKey)
            // Stop old monitor and start new one with updated shortcut
            stopMonitoringShortcut(for: mode)
            startMonitoringShortcut(for: mode)
            // Notify menu to refresh
            NotificationCenter.default.post(name: .elementCaptureShortcutChanged, object: nil)
        } else {
            UserDefaults.standard.removeObject(forKey: mode.shortcutKey)
            stopMonitoringShortcut(for: mode)
            // Notify menu to refresh
            NotificationCenter.default.post(name: .elementCaptureShortcutChanged, object: nil)
        }
    }
    
    // MARK: - Global Hotkey Monitoring
    
    /// Start monitoring all modes that have shortcuts
    func startMonitoringAllShortcuts() {
        for mode in ElementCaptureMode.allCases {
            if shortcut(for: mode) != nil {
                startMonitoringShortcut(for: mode)
            }
        }
    }
    
    /// Start monitoring shortcut for a specific mode
    func startMonitoringShortcut(for mode: ElementCaptureMode) {
        // Don't start if extension is disabled
        guard !ExtensionType.elementCapture.isRemoved else { return }
        // Prevent duplicate monitoring for this mode
        guard globalHotKeys[mode] == nil else { return }
        guard let savedShortcut = shortcut(for: mode) else { return }
        
        // Use GlobalHotKey (Carbon-based) for reliable global shortcut detection
        globalHotKeys[mode] = GlobalHotKey(
            keyCode: savedShortcut.keyCode,
            modifiers: savedShortcut.modifiers
        ) { [weak self] in
            guard let self = self else { return }
            guard !ExtensionType.elementCapture.isRemoved else { return }
            
            print("🔑 [ElementCapture] ✅ Shortcut triggered for mode: \\(mode.displayName)")
            
            if self.isActive {
                self.stopCaptureMode()
            } else {
                self.startCaptureMode(mode: mode)
            }
        }
        
        isShortcutEnabled = !globalHotKeys.isEmpty
        print("[ElementCapture] Shortcut monitoring started for \\(mode.displayName): \\(savedShortcut.description)")
    }
    
    /// Stop monitoring shortcut for a specific mode
    func stopMonitoringShortcut(for mode: ElementCaptureMode) {
        globalHotKeys[mode] = nil  // GlobalHotKey deinit handles unregistration
        isShortcutEnabled = !globalHotKeys.isEmpty
        print("[ElementCapture] Shortcut monitoring stopped for \\(mode.displayName)")
    }
    
    /// Stop monitoring all shortcuts
    func stopMonitoringAllShortcuts() {
        globalHotKeys.removeAll()
        isShortcutEnabled = false
        print("[ElementCapture] All shortcut monitoring stopped")
    }
    
    // MARK: - Editor Shortcuts API
    
    /// All editor shortcuts (loaded from UserDefaults or defaults)
    var editorShortcuts: [EditorShortcut: SavedShortcut] {
        var shortcuts: [EditorShortcut: SavedShortcut] = [:]
        for action in EditorShortcut.allCases {
            shortcuts[action] = editorShortcut(for: action)
        }
        return shortcuts
    }
    
    /// Get editor shortcut for an action
    func editorShortcut(for action: EditorShortcut) -> SavedShortcut {
        if let data = UserDefaults.standard.data(forKey: action.shortcutKey),
           let saved = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            return saved
        }
        return action.defaultShortcut
    }
    
    /// Set editor shortcut for an action
    func setEditorShortcut(_ shortcut: SavedShortcut, for action: EditorShortcut) {
        if let encoded = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(encoded, forKey: action.shortcutKey)
        }
    }
    
    /// Load default editor shortcuts
    func loadEditorDefaults() {
        for action in EditorShortcut.allCases {
            setEditorShortcut(action.defaultShortcut, for: action)
        }
        print("[ElementCapture] Editor shortcuts reset to defaults")
    }
    
    /// Reset (clear) all editor shortcuts
    func resetEditorShortcuts() {
        for action in EditorShortcut.allCases {
            UserDefaults.standard.removeObject(forKey: action.shortcutKey)
        }
        print("[ElementCapture] All editor shortcuts reset")
    }
    
    // MARK: - Permission Checking
    
    private func checkPermissions() -> Bool {
        // Check Accessibility (with cache fallback)
        let accessibilityOK = PermissionManager.shared.isAccessibilityGranted
        
        // Check Screen Recording (with cache fallback)
        var screenRecordingOK = PermissionManager.shared.isScreenRecordingGranted
        
        if !screenRecordingOK {
            // This will show the system prompt for screen recording
            screenRecordingOK = PermissionManager.shared.requestScreenRecording()
        }
        
        return accessibilityOK && screenRecordingOK
    }
    
    private func showPermissionAlert() {
        // Use ONLY macOS native dialogs - no Droppy custom dialogs
        print("🔐 ElementCaptureManager: Checking which permissions are missing...")
        
        if !PermissionManager.shared.isAccessibilityGranted {
            print("🔐 ElementCaptureManager: Requesting Accessibility via native dialog")
            PermissionManager.shared.requestAccessibility()
        }
        
        if !PermissionManager.shared.isScreenRecordingGranted {
            print("🔐 ElementCaptureManager: Requesting Screen Recording via native dialog")
            PermissionManager.shared.requestScreenRecording()
        }
    }
    
    // MARK: - Highlight Window Setup
    
    private var currentScreenDisplayID: CGDirectDisplayID = 0
    
    private func setupHighlightWindow() {
        // Find the screen where the mouse currently is, not just NSScreen.main
        let mouseLocation = NSEvent.mouseLocation
        
        print("[ElementCapture] setupHighlightWindow: mouse at \(mouseLocation)")
        for (i, s) in NSScreen.screens.enumerated() {
            let displayID = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            print("[ElementCapture]   Screen \(i): displayID=\(displayID), frame=\(s.frame), contains=\(s.frame.contains(mouseLocation))")
        }
        
        // Find the screen containing the mouse
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            print("[ElementCapture] ERROR: No screen found!")
            return
        }
        
        // Track this screen's display ID
        if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            currentScreenDisplayID = displayID
            print("[ElementCapture] Selected screen displayID=\(displayID), frame=\(screen.frame)")
        }
        
        highlightWindow = ElementHighlightWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        highlightWindow?.configure(
            borderColor: highlightColor,
            borderWidth: borderWidth,
            cornerRadius: cornerRadius
        )
        
        highlightWindow?.orderFrontRegardless()
        print("[ElementCapture] Created highlight window on screen \(currentScreenDisplayID), frame: \(screen.frame)")
    }
    
    /// Move highlight window to a different screen when mouse moves there
    private func ensureHighlightWindowOnScreen(_ screen: NSScreen) {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return }
        
        // Only move if actually on a different screen
        guard displayID != currentScreenDisplayID else { return }
        
        print("[ElementCapture] Moving window from screen \(currentScreenDisplayID) to \(displayID)")
        print("[ElementCapture] New screen frame: \(screen.frame)")
        
        currentScreenDisplayID = displayID
        
        // Reset the highlight state BEFORE moving - clears stale coordinates from old screen
        highlightWindow?.resetHighlight()
        
        highlightWindow?.setFrame(screen.frame, display: true, animate: false)
        highlightWindow?.orderFrontRegardless()
    }
    
    // MARK: - Mouse Tracking
    
    private func startMouseTracking() {
        mouseTrackingTimer = Timer.scheduledTimer(withTimeInterval: mousePollingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.updateElementUnderMouse()
            }
        }
        RunLoop.current.add(mouseTrackingTimer!, forMode: .common)
    }
    
    private func updateElementUnderMouse() {
        let mouseLocation = NSEvent.mouseLocation
        
        // Find the screen containing the mouse
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else {
            hideHighlight()
            return
        }
        
        // Move window to this screen if needed
        ensureHighlightWindowOnScreen(screen)
        
        let quartzPoint = convertToQuartzCoordinates(mouseLocation, screen: screen)
        
        // Try Accessibility API first, fall back to window detection
        var elementFrame: CGRect
        if let axFrame = getElementFrameAtPosition(quartzPoint) {
            elementFrame = axFrame
        } else if let windowFrame = getWindowFrameAtPosition(quartzPoint) {
            // Fallback: Use window frame for apps that don't expose Accessibility elements
            // (Electron apps like Spotify, Discord, Zen browser, etc.)
            elementFrame = windowFrame
        } else {
            hideHighlight()
            return
        }
        
        // SAFETY: Clamp element frame to reasonable bounds (prevent scroll container overflow)
        // AX API can return heights like 129,000+ pixels for scroll view content areas
        // which would crash WindowServer when attempting screen capture
        let maxDimension: CGFloat = 10000  // No UI element should exceed this
        if elementFrame.width > maxDimension || elementFrame.height > maxDimension {
            print("[ElementCapture] SAFETY: Clamping oversized frame \(elementFrame.size) to screen bounds")
            // Clamp to visible screen bounds in Quartz coordinates
            let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
            let screenFrameQuartz = CGRect(
                x: screen.frame.origin.x,
                y: primaryScreenHeight - screen.frame.origin.y - screen.frame.height,
                width: screen.frame.width,
                height: screen.frame.height
            )
            elementFrame = elementFrame.intersection(screenFrameQuartz)
            
            // If intersection is empty or invalid, skip
            if elementFrame.isEmpty || elementFrame.width < 1 || elementFrame.height < 1 {
                hideHighlight()
                return
            }
        }
        
        // Apply padding
        let paddedFrame = elementFrame.insetBy(dx: -highlightPadding, dy: -highlightPadding)
        
        // Only update if frame changed significantly (avoid micro-jitters)
        if !framesAreNearlyEqual(paddedFrame, lastDetectedFrame) {
            lastDetectedFrame = paddedFrame
            currentElementFrame = paddedFrame
            hasElement = true
            
            // Convert back to Cocoa coordinates for the overlay
            let cocoaFrame = convertToCocoaCoordinates(paddedFrame, screen: screen)
            
            // DEBUG: Log coordinates for external monitor debugging
            let screenDisplayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            print("[ElementCapture DEBUG] Screen \(screenDisplayID): elementFrame=\(elementFrame), cocoaFrame=\(cocoaFrame)")
            print("[ElementCapture DEBUG] Window frame: \(highlightWindow?.frame ?? .zero)")
            
            highlightWindow?.animateToFrame(cocoaFrame)
        }
    }
    
    private func hideHighlight() {
        hasElement = false
        currentElementFrame = .zero
        highlightWindow?.hideHighlight()
    }
    
    private func framesAreNearlyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 2.0) -> Bool {
        return abs(a.origin.x - b.origin.x) < tolerance &&
               abs(a.origin.y - b.origin.y) < tolerance &&
               abs(a.width - b.width) < tolerance &&
               abs(a.height - b.height) < tolerance
    }
    
    // MARK: - Coordinate Conversion
    
    /// Convert Cocoa coordinates (bottom-left origin) to Quartz coordinates (top-left origin)
    private func convertToQuartzCoordinates(_ point: NSPoint, screen: NSScreen) -> CGPoint {
        // In multi-monitor setups, Quartz Y=0 is at the top of the PRIMARY screen.
        // We need the primary screen's height for coordinate conversion.
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        return CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }
    
    /// Convert Quartz coordinates (top-left origin) to Cocoa coordinates (bottom-left origin)
    private func convertToCocoaCoordinates(_ rect: CGRect, screen: NSScreen) -> CGRect {
        // Quartz Y=0 is at top of primary screen, Cocoa Y=0 is at bottom of primary screen.
        // For ALL screens, the conversion uses the primary screen height as the reference.
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        return CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
    
    // MARK: - Accessibility Element Detection
    
    private func getElementFrameAtPosition(_ point: CGPoint) -> CGRect? {
        // Create system-wide element
        let systemElement = AXUIElementCreateSystemWide()
        
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemElement, Float(point.x), Float(point.y), &element)
        
        guard result == .success, let element = element else {
            return nil
        }
        
        // Get position
        var positionValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              let positionValue = positionValue else {
            return nil
        }
        
        var position = CGPoint.zero
        // CF type cast always succeeds when AXUIElementCopyAttributeValue returns .success
        let axPositionValue = positionValue as! AXValue
        guard AXValueGetValue(axPositionValue, .cgPoint, &position) else {
            return nil
        }
        
        // Get size
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let sizeValue = sizeValue else {
            return nil
        }
        
        var size = CGSize.zero
        // CF type cast always succeeds when AXUIElementCopyAttributeValue returns .success
        let axSizeValue = sizeValue as! AXValue
        guard AXValueGetValue(axSizeValue, .cgSize, &size) else {
            return nil
        }
        
        // Validate frame
        guard size.width > 0 && size.height > 0 else {
            return nil
        }
        
        return CGRect(origin: position, size: size)
    }
    
    // MARK: - Window Fallback Detection
    
    /// Fallback: Get window frame at position when Accessibility API fails
    /// Works for ALL apps including Electron (Spotify, Discord, Zen browser)
    private func getWindowFrameAtPosition(_ point: CGPoint) -> CGRect? {
        // Get all on-screen windows
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        // Find the topmost window containing the point
        for windowInfo in windowList {
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }
            
            let windowFrame = CGRect(x: x, y: y, width: width, height: height)
            
            // Check if point is inside this window
            if windowFrame.contains(point) {
                // Skip windows that are too small (likely decorations) or our own overlay
                guard width > 50 && height > 50 else { continue }
                
                // Skip Droppy's own windows
                if let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                   ownerName == "Droppy" {
                    continue
                }
                
                return windowFrame
            }
        }
        
        return nil
    }
    
    // MARK: - Event Tap (Click Interception)
    
    private func installEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<ElementCaptureManager>.fromOpaque(refcon).takeUnretainedValue()

                // Handle tap being disabled (system temporarily disables if we take too long)
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if !PermissionManager.shared.isAccessibilityGranted {
                        print("❌ ElementCapture: Tap disabled and permissions revoked. Stopping capture.")
                        // Dispatch stop safely
                        DispatchQueue.main.async {
                            manager.stopCaptureMode()
                        }
                        return Unmanaged.passRetained(event)
                    }
                    
                    print("⚠️ ElementCapture: Tap disabled, re-enabling...")
                    if let tap = manager.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }

                // Only handle if we're active and have an element
                if manager.isActive && manager.hasElement {
                    // Trigger capture on main thread
                    Task { @MainActor in
                        await manager.captureCurrentElement()
                    }
                    // Swallow the event (return nil prevents it from propagating)
                    return nil
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            print("[ElementCapture] Failed to create event tap")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        print("[ElementCapture] Event tap installed")
    }
    
    private func removeEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
    }
    
    // MARK: - ESC Key Monitor
    
    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for ESC key (keyCode 53)
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    self?.stopCaptureMode()
                }
                return nil  // Swallow the event
            }
            return event
        }
    }
    
    private func removeEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }
    
    // MARK: - Screen Capture
    
    private func captureCurrentElement() async {
        let frameToCapture = currentElementFrame
        
        guard frameToCapture.width > 0 && frameToCapture.height > 0 else {
            stopCaptureMode()
            return
        }
        
        // 1. Flash animation on the highlight
        highlightWindow?.flashCapture()
        
        // 2. Brief delay for flash effect
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        // 3. Hide overlay
        highlightWindow?.orderOut(nil)
        
        // 4. Brief delay to ensure overlay is hidden
        try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        
        // 5. Capture the element
        do {
            let image = try await captureRect(frameToCapture)
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            
            // Copy to clipboard
            copyToClipboard(image)
            
            // Play screenshot sound
            playScreenshotSound()
            print("[ElementCapture] Element captured successfully")
            
            // Show preview window with actions
            await MainActor.run {
                CapturePreviewWindowController.shared.show(with: nsImage)
            }
            
        } catch {
            print("[ElementCapture] Capture failed: \(error)")
            // Note: We don't report failure here because capture can fail for many reasons
            // (invalid rect, window closed, etc.) not just permissions
        }
        
        // 6. Stop capture mode
        stopCaptureMode()
    }
    
    // MARK: - Fullscreen Capture
    
    private func captureFullscreen() async {
        // Get the screen under the mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            isActive = false
            return
        }
        
        // Convert screen frame (AppKit coords) to Quartz coordinates
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let quartzRect = CGRect(
            x: screen.frame.origin.x,
            y: primaryScreenHeight - screen.frame.origin.y - screen.frame.height,
            width: screen.frame.width,
            height: screen.frame.height
        )
        
        // Track which display we're capturing
        if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            currentScreenDisplayID = displayID
        }
        
        do {
            let image = try await captureRect(quartzRect)
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            
            copyToClipboard(image)
            playScreenshotSound()
            print("[ElementCapture] Fullscreen captured successfully")
            
            await MainActor.run {
                CapturePreviewWindowController.shared.show(with: nsImage)
            }
            
        } catch {
            print("[ElementCapture] Fullscreen capture failed: \(error)")
        }
        
        isActive = false
    }
    
    // MARK: - Window Capture
    
    private func captureWindowUnderCursor() async {
        // Get window under cursor using existing method
        let mouseLocation = NSEvent.mouseLocation
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let quartzMousePoint = CGPoint(x: mouseLocation.x, y: primaryScreenHeight - mouseLocation.y)
        
        guard let windowFrame = getWindowFrameAtPosition(quartzMousePoint) else {
            print("[ElementCapture] No window found under cursor")
            isActive = false
            return
        }
        
        // Find which screen this window is on
        if let screen = NSScreen.screens.first(where: { screen in
            let quartzScreenRect = CGRect(
                x: screen.frame.origin.x,
                y: primaryScreenHeight - screen.frame.origin.y - screen.frame.height,
                width: screen.frame.width,
                height: screen.frame.height
            )
            return quartzScreenRect.intersects(windowFrame)
        }) {
            if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                currentScreenDisplayID = displayID
            }
        }
        
        do {
            let image = try await captureRect(windowFrame)
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            
            copyToClipboard(image)
            playScreenshotSound()
            print("[ElementCapture] Window captured successfully")
            
            await MainActor.run {
                CapturePreviewWindowController.shared.show(with: nsImage)
            }
            
        } catch {
            print("[ElementCapture] Window capture failed: \(error)")
        }
        
        isActive = false
    }
    
    private func captureRect(_ rect: CGRect) async throws -> CGImage {
        // PERMISSION CHECK: Verify screen recording permission BEFORE calling ScreenCaptureKit
        // SCShareableContent triggers macOS prompts even when CGPreflight passes in some cases
        guard CGPreflightScreenCaptureAccess() else {
            print("[ElementCapture] Screen recording permission not granted - aborting capture")
            // Request permission via system dialog
            CGRequestScreenCaptureAccess()
            throw CaptureError.permissionDenied
        }
        
        // SAFETY CHECK 1: Validate input rect has reasonable dimensions
        guard rect.width > 0 && rect.height > 0 && rect.width < 50000 && rect.height < 50000 else {
            print("[ElementCapture] SAFETY: Invalid input rect dimensions: \(rect)")
            throw CaptureError.noElement
        }
        
        // Get available content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Use the tracked display ID from mouse position - this is more reliable than
        // rect intersection which can fail when elements span display boundaries
        let targetDisplayID = currentScreenDisplayID
        
        // Find the SCDisplay matching our tracked display ID
        guard let display = content.displays.first(where: { $0.displayID == targetDisplayID }) else {
            print("[ElementCapture] No display found for ID: \(targetDisplayID)")
            throw CaptureError.noDisplay
        }
        
        // Find the NSScreen for this display to get proper coordinates and scale
        guard let targetScreen = NSScreen.screens.first(where: { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return displayID == display.displayID
        }) else {
            print("[ElementCapture] SAFETY: Could not find NSScreen for display \(display.displayID)")
            throw CaptureError.noDisplay
        }
        
        // Get the display's origin in Quartz coordinates
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let displayOriginQuartz = CGPoint(
            x: targetScreen.frame.origin.x,
            y: primaryScreenHeight - targetScreen.frame.origin.y - targetScreen.frame.height
        )
        
        // Convert global Quartz rect to display-relative coordinates
        var relativeRect = CGRect(
            x: rect.origin.x - displayOriginQuartz.x,
            y: rect.origin.y - displayOriginQuartz.y,
            width: rect.width,
            height: rect.height
        )
        
        // SAFETY CHECK 2: Clamp relativeRect to valid display bounds (0 to displaySize)
        // This prevents negative coordinates and oversized rects that crash WindowServer
        let displayWidth = CGFloat(display.width)
        let displayHeight = CGFloat(display.height)
        
        // Clamp origin to be >= 0
        if relativeRect.origin.x < 0 {
            relativeRect.size.width += relativeRect.origin.x  // Reduce width by overflow
            relativeRect.origin.x = 0
        }
        if relativeRect.origin.y < 0 {
            relativeRect.size.height += relativeRect.origin.y  // Reduce height by overflow
            relativeRect.origin.y = 0
        }
        
        // Clamp to not exceed display bounds
        if relativeRect.maxX > displayWidth {
            relativeRect.size.width = displayWidth - relativeRect.origin.x
        }
        if relativeRect.maxY > displayHeight {
            relativeRect.size.height = displayHeight - relativeRect.origin.y
        }
        
        // SAFETY CHECK 3: Final validation - dimensions must be positive and reasonable
        guard relativeRect.width >= 1 && relativeRect.height >= 1 else {
            print("[ElementCapture] SAFETY: After clamping, rect has invalid dimensions: \(relativeRect)")
            throw CaptureError.noElement
        }
        
        print("[ElementCapture] Capture: global=\(rect), relative=\(relativeRect), display=\(displayWidth)x\(displayHeight)")
        
        // Calculate pixel dimensions (Retina scaling) - use target screen's scale
        let scale = targetScreen.backingScaleFactor
        let pixelWidth = max(1, Int(relativeRect.width * scale))
        let pixelHeight = max(1, Int(relativeRect.height * scale))
        
        // Configure capture
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let config = SCStreamConfiguration()
        config.sourceRect = relativeRect
        config.width = pixelWidth
        config.height = pixelHeight
        config.scalesToFit = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        
        // Capture
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return image
    }
    
    private func copyToClipboard(_ image: CGImage) {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
    }
    
    private func playScreenshotSound() {
        // Play the system screenshot sound
        let soundPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif"
        let soundURL = URL(fileURLWithPath: soundPath)
        if FileManager.default.fileExists(atPath: soundPath) {
            NSSound(contentsOf: soundURL, byReference: true)?.play()
        } else {
            // Fallback to system beep if screenshot sound not found
            NSSound.beep()
        }
    }
    
    // MARK: - Errors
    
    enum CaptureError: Error {
        case noDisplay
        case noElement
        case captureFailed
        case permissionDenied
    }
    
    // MARK: - Extension Removal Cleanup
    
    /// Clean up all Element Capture resources when extension is removed
    func cleanup() {
        // Stop capture mode if active
        if isActive {
            stopCaptureMode()
        }
        
        // Stop monitoring all shortcuts
        stopMonitoringAllShortcuts()
        
        // Clear all saved shortcuts
        shortcut = nil
        fullscreenShortcut = nil
        windowShortcut = nil
        for mode in ElementCaptureMode.allCases {
            UserDefaults.standard.removeObject(forKey: mode.shortcutKey)
        }
        
        // Notify other components
        NotificationCenter.default.post(name: .elementCaptureShortcutChanged, object: nil)
        
        print("[ElementCapture] Cleanup complete")
    }
}

// MARK: - Element Highlight Window

final class ElementHighlightWindow: NSWindow {
    
    private let highlightView = HighlightBorderView()
    private var currentTargetFrame: CGRect = .zero
    
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        
        // Window configuration
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true  // CRITICAL: Don't interfere with AX hit-testing
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Add highlight view - frame must be in window-local coordinates (origin at 0,0)
        // NOT screen coordinates (which contentRect contains for external monitors)
        self.contentView = highlightView
        highlightView.frame = NSRect(origin: .zero, size: contentRect.size)
        highlightView.autoresizingMask = [.width, .height]
    }
    
    func configure(borderColor: NSColor, borderWidth: CGFloat, cornerRadius: CGFloat) {
        highlightView.borderColor = borderColor
        highlightView.borderWidth = borderWidth
        highlightView.cornerRadius = cornerRadius
    }
    
    func animateToFrame(_ frame: CGRect) {
        currentTargetFrame = frame
        highlightView.isHidden = false
        
        // The view now handles its own spring animation internally
        highlightView.highlightFrame = frame
    }
    
    func flashCapture() {
        // Animate flash in
        highlightView.flashOpacity = 1.0
        
        // Animate flash out after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.highlightView.flashOpacity = 0.0
        }
    }
    
    func hideHighlight() {
        highlightView.isHidden = true
        highlightView.highlightFrame = .zero
    }
    
    func resetHighlight() {
        // Reset animation state when moving between screens
        // This clears stale coordinates from the old screen
        highlightView.resetAnimationState()
    }
}

// MARK: - Highlight Border View (With Fluid Animation)

final class HighlightBorderView: NSView {
    
    var borderColor: NSColor = .systemCyan
    var borderWidth: CGFloat = 2.0
    var cornerRadius: CGFloat = 8.0
    var flashOpacity: CGFloat = 0.0 {
        didSet { needsDisplay = true }
    }
    
    // Animation state
    private var displayedFrame: CGRect = .zero
    private var targetFrame: CGRect = .zero
    private var isAnimating = false
    
    // Animation parameters (spring-like feel)
    private let baseSmoothingFactor: CGFloat = 0.18  // Lower = smoother, more fluid
    private let frameInterval: TimeInterval = 1.0 / 120.0  // 120fps for ultra-smooth
    
    var highlightFrame: CGRect = .zero {
        didSet {
            if highlightFrame.isEmpty {
                // Reset immediately when hiding
                targetFrame = .zero
                displayedFrame = .zero
                isAnimating = false
                needsDisplay = true
            } else if displayedFrame.isEmpty {
                // First frame - snap immediately
                targetFrame = highlightFrame
                displayedFrame = highlightFrame
                needsDisplay = true
            } else {
                // Animate to new target
                targetFrame = highlightFrame
                if !isAnimating {
                    isAnimating = true
                    animateToTarget()
                }
            }
        }
    }
    
    /// Reset animation state when window moves between screens
    /// This ensures the next frame snaps immediately with correct coordinates
    func resetAnimationState() {
        displayedFrame = .zero
        targetFrame = .zero
        isAnimating = false
        isHidden = false  // Ensure view is visible
        needsDisplay = true
    }
    
    private func animateToTarget() {
        guard isAnimating else { return }
        
        // Use main thread animation loop
        DispatchQueue.main.async { [weak self] in
            self?.updateAnimation()
        }
    }
    
    private func updateAnimation() {
        guard isAnimating else { return }
        
        // Calculate distance to target
        let dx = targetFrame.origin.x - displayedFrame.origin.x
        let dy = targetFrame.origin.y - displayedFrame.origin.y
        let dw = targetFrame.width - displayedFrame.width
        let dh = targetFrame.height - displayedFrame.height
        
        // Calculate total distance for adaptive smoothing
        let totalDistance = sqrt(dx * dx + dy * dy + dw * dw + dh * dh)
        
        // Adaptive smoothing: faster when far, slower when close (easing out)
        let adaptiveFactor = min(baseSmoothingFactor * (1 + totalDistance / 200), 0.4)
        
        // Check if we're close enough to snap
        let threshold: CGFloat = 0.3
        if abs(dx) < threshold && abs(dy) < threshold && abs(dw) < threshold && abs(dh) < threshold {
            displayedFrame = targetFrame
            isAnimating = false
            needsDisplay = true
            return
        }
        
        // Apply smooth interpolation with easing
        displayedFrame = CGRect(
            x: displayedFrame.origin.x + dx * adaptiveFactor,
            y: displayedFrame.origin.y + dy * adaptiveFactor,
            width: displayedFrame.width + dw * adaptiveFactor,
            height: displayedFrame.height + dh * adaptiveFactor
        )
        
        needsDisplay = true
        
        // Continue animating at high frame rate
        DispatchQueue.main.asyncAfter(deadline: .now() + frameInterval) { [weak self] in
            self?.updateAnimation()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let frameToDraw = displayedFrame.isEmpty ? targetFrame : displayedFrame
        
        guard frameToDraw.width > 0 && frameToDraw.height > 0 else { return }
        
        // Convert screen coordinates to view coordinates
        guard let window = self.window else { return }
        let localFrame = window.convertFromScreen(frameToDraw)
        
        // Draw rounded rectangle border
        let path = NSBezierPath(roundedRect: localFrame, xRadius: cornerRadius, yRadius: cornerRadius)
        path.lineWidth = borderWidth
        
        // Border
        borderColor.setStroke()
        path.stroke()
        
        // Subtle fill
        borderColor.withAlphaComponent(0.1).setFill()
        path.fill()
        
        // Flash overlay (for capture animation)
        if flashOpacity > 0 {
            NSColor.white.withAlphaComponent(flashOpacity * 0.8).setFill()
            path.fill()
        }
    }
}

// MARK: - Capture Preview Window Controller

final class CapturePreviewWindowController {
    static let shared = CapturePreviewWindowController()
    
    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?  // Keep strong reference
    private var autoDismissTimer: Timer?
    
    private init() {}
    
    func show(with image: NSImage) {
        // Clean up any existing window first
        cleanUp()
        
        // Create SwiftUI view with edit callback
        let previewView = CapturePreviewView(
            image: image,
            onEditTapped: { capturedImage in
                Task { @MainActor in
                    ScreenshotEditorWindowController.shared.show(with: capturedImage)
                }
            }
        )
        .preferredColorScheme(.dark) // Force dark mode always
        
        // Fixed size for consistent appearance
        let contentSize = NSSize(width: 280, height: 220)
        
        // Create hosting view with layer clipping for proper rounded corners
        let hosting = NSHostingView(rootView: AnyView(previewView))
        hosting.frame = NSRect(origin: .zero, size: contentSize)
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = true
        hosting.layer?.cornerRadius = 28  // Match the SwiftUI cornerRadius
        self.hostingView = hosting
        
        let newWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        newWindow.contentView = hosting
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true  // Window-level shadow (properly rounded)
        newWindow.level = .floating
        newWindow.isMovableByWindowBackground = true
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Position in bottom-right corner
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = newWindow.frame
            let x = screenFrame.maxX - windowFrame.width - 20
            let y = screenFrame.minY + 20
            newWindow.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Animate in with spring
        newWindow.alphaValue = 0
        newWindow.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            newWindow.animator().alphaValue = 1
        }
        
        self.window = newWindow
        
        // Auto-dismiss after 3 seconds
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }
    
    func dismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        
        guard let window = window else { return }
        
        // Fade out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // Defer cleanup to next run loop to avoid autorelease pool issues
            DispatchQueue.main.async {
                self?.cleanUp()
            }
        })
    }
    
    private func cleanUp() {
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
        hostingView = nil
    }
}

// MARK: - Capture Preview View (Styled like Basket)



