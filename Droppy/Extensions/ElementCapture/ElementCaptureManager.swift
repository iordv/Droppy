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
    case area = "area"
    case fullscreen = "fullscreen"
    case window = "window"
    case ocr = "ocr"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .element: return "Element"
        case .area: return "Area"
        case .fullscreen: return "Fullscreen"
        case .window: return "Window"
        case .ocr: return "OCR"
        }
    }
    
    var icon: String {
        switch self {
        case .element: return "viewfinder"
        case .area: return "rectangle.dashed"
        case .fullscreen: return "rectangle.inset.filled"
        case .window: return "macwindow"
        case .ocr: return "text.viewfinder"
        }
    }
    
    var shortcutKey: String {
        switch self {
        case .element: return "elementCaptureShortcut"
        case .area: return "elementCaptureAreaShortcut"
        case .fullscreen: return "elementCaptureFullscreenShortcut"
        case .window: return "elementCaptureWindowShortcut"
        case .ocr: return "elementCaptureOCRShortcut"
        }
    }
}


// MARK: - Editor Shortcut Actions
enum EditorShortcut: String, CaseIterable, Identifiable {
    // Tool shortcuts
    case arrow, curvedArrow, line, rectangle, ellipse, freehand, highlighter, blur, text
    case cursorSticker, pointerSticker, cursorStickerCircled, pointerStickerCircled, typingIndicatorSticker
    // Action shortcuts
    case strokeSmall, strokeMedium, strokeLarge
    case zoomIn, zoomOut, zoomReset
    case undo, redo
    case cancel, done
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .arrow: return "Arrow"
        case .curvedArrow: return "Curved Arrow"
        case .line: return "Line"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .freehand: return "Freehand"
        case .highlighter: return "Highlighter"
        case .blur: return "Blur"
        case .text: return "Text"
        case .cursorSticker: return "Cursor Sticker"
        case .pointerSticker: return "Pointer Sticker"
        case .cursorStickerCircled: return "Cursor Sticker (Circle)"
        case .pointerStickerCircled: return "Pointer Sticker (Circle)"
        case .typingIndicatorSticker: return "Typing Indicator"
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
        case .arrow: return "arrow.up.forward"
        case .curvedArrow: return "arrow.uturn.up"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .freehand: return "scribble"
        case .highlighter: return "highlighter"
        case .blur: return "eye.slash"
        case .text: return "textformat"
        case .cursorSticker, .cursorStickerCircled: return "cursorarrow"
        case .pointerSticker, .pointerStickerCircled: return "hand.point.up.left.fill"
        case .typingIndicatorSticker: return "ibeam"
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
        case .curvedArrow: return 8  // C
        case .line: return 37        // L
        case .rectangle: return 15   // R
        case .ellipse: return 31     // O
        case .freehand: return 3     // F
        case .highlighter: return 4  // H
        case .blur: return 11        // B
        case .text: return 17        // T
        case .cursorSticker: return 32          // U
        case .pointerSticker: return 35         // P
        case .cursorStickerCircled: return 34   // I
        case .pointerStickerCircled: return 40  // K
        case .typingIndicatorSticker: return 16 // Y
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
        case .arrow, .curvedArrow, .line, .rectangle, .ellipse, .freehand, .highlighter, .blur, .text, .cursorSticker, .pointerSticker, .cursorStickerCircled, .pointerStickerCircled, .typingIndicatorSticker:
            return true
        default:
            return false
        }
    }
    
    /// Tool shortcuts only
    static var tools: [EditorShortcut] {
        [.arrow, .curvedArrow, .line, .rectangle, .ellipse, .freehand, .highlighter, .blur, .text, .cursorSticker, .pointerSticker, .cursorStickerCircled, .pointerStickerCircled, .typingIndicatorSticker]
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
    @Published var areaShortcut: SavedShortcut? {
        didSet { saveShortcut(for: .area) }
    }
    @Published var fullscreenShortcut: SavedShortcut? {
        didSet { saveShortcut(for: .fullscreen) }
    }
    @Published var windowShortcut: SavedShortcut? {
        didSet { saveShortcut(for: .window) }
    }
    @Published var ocrShortcut: SavedShortcut? {
        didSet { saveShortcut(for: .ocr) }
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
    private var globalEscapeMonitor: Any?  // Global monitor for ESC key when focus changes
    private var captureCursorPushed = false
    private var activeMode: ElementCaptureMode = .element  // Current capture mode
    private var isOCRCapture = false  // Flag for OCR mode capture
    private var screenParametersObserver: NSObjectProtocol?
    
    // MARK: - Configuration
    
    private let highlightPadding: CGFloat = 4.0
    private let highlightColor = NSColor.systemCyan
    private let borderWidth: CGFloat = 2.0
    private let cornerRadius: CGFloat = 6.0
    private let mousePollingInterval: TimeInterval = 1.0 / 60.0  // 60 FPS
    
    // MARK: - Initialization
    
    private init() {
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handleScreenParametersChanged()
            }
        }
    }

    deinit {
        if let observer = screenParametersObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
        case .area: return areaShortcut
        case .fullscreen: return fullscreenShortcut
        case .window: return windowShortcut
        case .ocr: return ocrShortcut
        }
    }
    
    /// Set shortcut for a specific mode
    func setShortcut(_ newShortcut: SavedShortcut?, for mode: ElementCaptureMode) {
        switch mode {
        case .element: shortcut = newShortcut
        case .area: areaShortcut = newShortcut
        case .fullscreen: fullscreenShortcut = newShortcut
        case .window: windowShortcut = newShortcut
        case .ocr: ocrShortcut = newShortcut
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

        // Defensive cleanup for cases where a previous run left transient UI state behind.
        stopCaptureMode()
        
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
            activateCaptureCursor()
            
        case .area:
            // Area mode: click-drag to select region
            guard setupAreaSelectionOverlay() else {
                stopCaptureMode()
                return
            }
            installEscapeMonitor()
            activateCaptureCursor()
            print("[ElementCapture] Area selection mode started")
            return
            
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
            
        case .ocr:
            // OCR mode: area selection then perform OCR on result
            guard setupAreaSelectionOverlay(forOCR: true) else {
                stopCaptureMode()
                return
            }
            installEscapeMonitor()
            activateCaptureCursor()
            print("[ElementCapture] OCR capture mode started")
            return
        }
        
        print("[ElementCapture] Capture mode started: \(mode.displayName)")
    }
    
    /// Stop element capture mode
    func stopCaptureMode() {
        let hadState = isActive ||
            mouseTrackingTimer != nil ||
            eventTap != nil ||
            runLoopSource != nil ||
            escapeMonitor != nil ||
            globalEscapeMonitor != nil ||
            highlightWindow != nil ||
            areaSelectionWindow != nil ||
            captureCursorPushed

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
        
        // Hide and destroy area selection window
        areaSelectionWindow?.orderOut(nil)
        areaSelectionWindow = nil
        
        currentScreenDisplayID = 0
        
        // Restore cursor
        deactivateCaptureCursor()

        if hadState {
            print("[ElementCapture] Capture mode stopped")
        }
    }
    
    // MARK: - Shortcut Persistence
    
    private func loadAllShortcuts() {
        for mode in ElementCaptureMode.allCases {
            if let data = UserDefaults.standard.data(forKey: mode.shortcutKey),
               let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
                switch mode {
                case .element: shortcut = decoded
                case .area: areaShortcut = decoded
                case .fullscreen: fullscreenShortcut = decoded
                case .window: windowShortcut = decoded
                case .ocr: ocrShortcut = decoded
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
            modifiers: savedShortcut.modifiers,
            enableIOHIDFallback: false
        ) { [weak self] in
            guard let self = self else { return }
            guard !ExtensionType.elementCapture.isRemoved else { return }
            
            print("🔑 [ElementCapture] ✅ Shortcut triggered for mode: \(mode.displayName)")
            
            if self.isActive {
                self.stopCaptureMode()
            } else {
                self.startCaptureMode(mode: mode)
            }
        }
        
        isShortcutEnabled = !globalHotKeys.isEmpty
        print("[ElementCapture] Shortcut monitoring started for \(mode.displayName): \(savedShortcut.description)")
    }
    
    /// Stop monitoring shortcut for a specific mode
    func stopMonitoringShortcut(for mode: ElementCaptureMode) {
        globalHotKeys[mode] = nil  // GlobalHotKey deinit handles unregistration
        isShortcutEnabled = !globalHotKeys.isEmpty
        print("[ElementCapture] Shortcut monitoring stopped for \(mode.displayName)")
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
        print("🔐 ElementCaptureManager: Checking which permissions are missing…")
        
        if !PermissionManager.shared.isAccessibilityGranted {
            print("🔐 ElementCaptureManager: Requesting Accessibility via native dialog")
            PermissionManager.shared.requestAccessibility(context: .userInitiated)
        }
        
        if !PermissionManager.shared.isScreenRecordingGranted {
            print("🔐 ElementCaptureManager: Requesting Screen Recording via native dialog")
            PermissionManager.shared.requestScreenRecording()
        }
    }
    
    // MARK: - Highlight Window Setup
    
    private var currentScreenDisplayID: CGDirectDisplayID = 0

    /// Resolves the active screen robustly for multi-display setups.
    /// Falls back to nearest screen when coordinate edge cases land just outside a frame.
    private func screenForMouseLocation(_ mouseLocation: NSPoint) -> NSScreen? {
        if let containing = NSScreen.screens.first(where: {
            $0.frame.insetBy(dx: -1, dy: -1).contains(mouseLocation)
        }) {
            return containing
        }

        let nearest = NSScreen.screens.min { lhs, rhs in
            distanceSquared(from: mouseLocation, to: lhs.frame) < distanceSquared(from: mouseLocation, to: rhs.frame)
        }

        return nearest ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func distanceSquared(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let dx = point.x - clampedX
        let dy = point.y - clampedY
        return (dx * dx) + (dy * dy)
    }
    
    private func setupHighlightWindow() {
        // Find the screen where the mouse currently is, not just NSScreen.main
        let mouseLocation = NSEvent.mouseLocation
        
        print("[ElementCapture] setupHighlightWindow: mouse at \(mouseLocation)")
        for (i, s) in NSScreen.screens.enumerated() {
            let displayID = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            print("[ElementCapture]   Screen \(i): displayID=\(displayID), frame=\(s.frame), contains=\(s.frame.contains(mouseLocation))")
        }
        
        // Find the screen containing the mouse
        guard let screen = screenForMouseLocation(mouseLocation) else {
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
        highlightWindow?.onCancel = { [weak self] in
            self?.stopCaptureMode()
        }

        NSApp.activate(ignoringOtherApps: true)
        highlightWindow?.makeKeyAndOrderFront(nil)
        highlightWindow?.orderFrontRegardless()
        print("[ElementCapture] Created highlight window on screen \(currentScreenDisplayID), frame: \(screen.frame)")
    }
    
    // MARK: - Area Selection (Click-Drag)
    
    private var areaSelectionWindow: AreaSelectionWindow?
    
    @discardableResult
    private func setupAreaSelectionOverlay(forOCR: Bool = false) -> Bool {
        // Store OCR mode flag
        isOCRCapture = forOCR
        
        let mouseLocation = NSEvent.mouseLocation
        
        guard let screen = screenForMouseLocation(mouseLocation) else {
            print("[ElementCapture] ERROR: No screen found for area selection!")
            return false
        }
        
        // Set display ID for capture (critical!)
        if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            currentScreenDisplayID = displayID
            print("[ElementCapture] Area selection on displayID=\(displayID)")
        }
        
        areaSelectionWindow = AreaSelectionWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        areaSelectionWindow?.configure { [weak self] selectedRect in
            guard let self = self else { return }
            
            // Capture the selected area
            Task {
                await self.captureArea(selectedRect, on: screen)
            }
        }
        
        areaSelectionWindow?.onCancel = { [weak self] in
            self?.isOCRCapture = false
            self?.stopCaptureMode()
        }
        
        areaSelectionWindow?.presentForCapture()
        NSCursor.crosshair.set()
        print("[ElementCapture] Created area selection window, frame: \(screen.frame)\(forOCR ? " (OCR mode)" : "")")
        return areaSelectionWindow != nil
    }
    
    private func captureArea(_ rect: CGRect, on screen: NSScreen) async {
        guard rect.width > 10 && rect.height > 10 else {
            // Too small, ignore
            stopCaptureMode()
            return
        }
        
        // Hide the selection window before capturing
        await MainActor.run {
            if let overlay = self.areaSelectionWindow {
                overlay.alphaValue = 0
                overlay.orderOut(nil)
                overlay.close()
            }
            self.areaSelectionWindow = nil
        }
        
        // Small delay to let window hide
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // The rect from AreaSelectionView is NSView-local Cocoa coordinates (origin bottom-left).
        // Convert to global Cocoa coordinates and capture directly on the selected screen.
        let screenRect = CGRect(
            x: screen.frame.origin.x + rect.origin.x,
            y: screen.frame.origin.y + rect.origin.y,
            width: rect.width,
            height: rect.height
        )

        print("[ElementCapture] Area capture rect: view=\(rect), screen=\(screenRect)")

        let performOCR = isOCRCapture
        do {
            let image = try await captureRect(screenRect, on: screen)
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

            if performOCR {
                do {
                    let text = try await OCRService.shared.performOCR(on: nsImage)
                    let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let targetDisplayID = self.currentScreenDisplayID
                    await MainActor.run {
                        if normalizedText.isEmpty {
                            OCRWindowController.shared.show(
                                with: "No text detected in the selected area.",
                                targetDisplayID: targetDisplayID
                            )
                        } else {
                            OCRWindowController.shared.presentExtractedText(
                                normalizedText,
                                targetDisplayID: targetDisplayID
                            )
                        }
                    }
                    playScreenshotSound()
                } catch {
                    print("[ElementCapture] OCR failed: \(error)")
                }
            } else {
                copyToClipboard(image)
                playScreenshotSound()
                await MainActor.run {
                    CapturePreviewWindowController.shared.show(with: nsImage)
                }
            }
        } catch {
            print("[ElementCapture] Area capture failed: \(error)")
        }

        await MainActor.run {
            self.isOCRCapture = false
            self.stopCaptureMode()
        }
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
        guard let screen = screenForMouseLocation(mouseLocation) else {
            hideHighlight()
            return
        }
        
        // Move window to this screen if needed
        ensureHighlightWindowOnScreen(screen)
        
        let queryPoints = candidateQueryPoints(for: mouseLocation, on: screen)
        
        // Try Accessibility API first, then fall back to window bounds.
        var elementFrame: CGRect?
        
        for point in queryPoints {
            guard let axFrame = getElementFrameAtPosition(point) else { continue }
            if let sanitized = sanitizeDetectedFrame(axFrame, queryPoint: point, on: screen) {
                elementFrame = sanitized
                break
            }
        }
        
        if elementFrame == nil {
            for point in queryPoints {
                guard let windowFrame = getWindowFrameAtPosition(point) else { continue }
                if let sanitized = sanitizeDetectedFrame(windowFrame, queryPoint: point, on: screen) {
                    elementFrame = sanitized
                    break
                }
            }
        }
        
        guard let elementFrame else {
            hideHighlight()
            return
        }
        
        // Apply padding
        let paddedFrame = elementFrame.insetBy(dx: -highlightPadding, dy: -highlightPadding)
        
        // Only update if frame changed significantly (avoid micro-jitters)
        if !framesAreNearlyEqual(paddedFrame, lastDetectedFrame) {
            lastDetectedFrame = paddedFrame
            
            // Convert back to Cocoa coordinates for the overlay
            let cocoaFrame = convertToCocoaCoordinates(paddedFrame, screen: screen)
            currentElementFrame = cocoaFrame
            hasElement = true
            
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
    
    /// Quartz global coordinates (AX/CGWindow) are anchored to the primary display's
    /// top edge, not the virtual desktop's absolute highest Y across all displays.
    /// Use CGMainDisplayID to avoid NSScreen enumeration-order drift across launches/rebuilds.
    private func quartzReferenceScreen() -> NSScreen? {
        let mainDisplayID = CGMainDisplayID()
        if let screen = NSScreen.screens.first(where: { $0.displayID == mainDisplayID }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func quartzReferenceMaxY() -> CGFloat {
        if let screen = quartzReferenceScreen() {
            return screen.frame.maxY
        }
        let mainBounds = CGDisplayBounds(CGMainDisplayID())
        if mainBounds.height > 0 {
            return mainBounds.maxY
        }
        return NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
    }
    
    private func quartzScreenFrame(for screen: NSScreen) -> CGRect {
        let topY = quartzReferenceMaxY()
        return CGRect(
            x: screen.frame.origin.x,
            y: topY - screen.frame.origin.y - screen.frame.height,
            width: screen.frame.width,
            height: screen.frame.height
        )
    }

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
        }
    }

    /// Convert Cocoa coordinates (bottom-left origin) to Quartz coordinates (top-left origin)
    private func convertToQuartzCoordinates(_ point: NSPoint, screen: NSScreen) -> CGPoint {
        let topY = quartzReferenceMaxY()
        return CGPoint(x: point.x, y: topY - point.y)
    }
    
    /// Convert Quartz coordinates (top-left origin) to Cocoa coordinates (bottom-left origin)
    private func convertToCocoaCoordinates(_ rect: CGRect, screen: NSScreen) -> CGRect {
        let topY = quartzReferenceMaxY()
        return CGRect(
            x: rect.origin.x,
            y: topY - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Some apps/APIs disagree on whether global coordinates are top-left or bottom-left based.
    /// Query both conventions to keep hit-testing stable across displays and scaled modes.
    private func candidateQueryPoints(for mouseLocation: NSPoint, on screen: NSScreen) -> [CGPoint] {
        let quartzPoint = convertToQuartzCoordinates(mouseLocation, screen: screen)
        let cocoaPoint = CGPoint(x: mouseLocation.x, y: mouseLocation.y)
        
        if abs(quartzPoint.x - cocoaPoint.x) < 0.5 && abs(quartzPoint.y - cocoaPoint.y) < 0.5 {
            return [quartzPoint]
        }
        
        return [quartzPoint, cocoaPoint]
    }
    
    private func sanitizeDetectedFrame(_ frame: CGRect, queryPoint: CGPoint, on screen: NSScreen) -> CGRect? {
        guard frame.origin.x.isFinite,
              frame.origin.y.isFinite,
              frame.width.isFinite,
              frame.height.isFinite,
              frame.width >= 1,
              frame.height >= 1 else {
            return nil
        }
        
        let screenQuartz = quartzScreenFrame(for: screen)
        guard frame.intersects(screenQuartz) else { return nil }
        
        // Reject absurd AX values (can be tens of thousands of points for scroll content).
        let maxAllowedDimension = max(screenQuartz.width, screenQuartz.height) * 4.0
        guard frame.width <= maxAllowedDimension, frame.height <= maxAllowedDimension else {
            return nil
        }
        
        guard frame.insetBy(dx: -2, dy: -2).contains(queryPoint) else {
            return nil
        }
        
        let clamped = frame.intersection(screenQuartz)
        guard clamped.width >= 1, clamped.height >= 1 else {
            return nil
        }
        
        return clamped
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
        let excludedWindowIDs = excludedCaptureHelperWindowIDs()
        
        // Find the topmost window containing the point
        for windowInfo in windowList {
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"] else {
                continue
            }
            let windowID = (windowInfo[kCGWindowNumber as String] as? NSNumber).map { CGWindowID($0.uint32Value) }
            if let windowID, excludedWindowIDs.contains(windowID) {
                continue
            }
            
            let windowFrame = CGRect(x: x, y: y, width: width, height: height)
            
            // Check if point is inside this window
            if windowFrame.contains(point) {
                // Skip windows that are too small (likely decorations) or our own overlay
                guard width > 50 && height > 50 else { continue }
                
                return windowFrame
            }
        }
        
        return nil
    }
    
    // MARK: - Event Tap (Click Interception)
    
    private func installEventTap() {
        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.keyDown.rawValue)
        
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
                    
                    print("⚠️ ElementCapture: Tap disabled, re-enabling…")
                    if let tap = manager.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }

                guard manager.isActive else {
                    return Unmanaged.passRetained(event)
                }

                // Fallback ESC handling via event tap so cancellation remains reliable even if
                // local/global key monitors miss a key press due focus changes.
                if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    if keyCode == 53 {
                        DispatchQueue.main.async {
                            manager.stopCaptureMode()
                        }
                        // Never consume Escape globally here; just stop capture and
                        // allow the key event to continue to the focused app.
                        return Unmanaged.passRetained(event)
                    }
                    return Unmanaged.passRetained(event)
                }

                // Capture on click in element mode.
                if type == .leftMouseDown && manager.hasElement {
                    Task { @MainActor in
                        await manager.captureCurrentElement()
                    }
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
        removeEscapeMonitor()

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for ESC key (keyCode 53)
            if event.keyCode == 53 {
                Task { @MainActor in
                    self?.stopCaptureMode()
                }
                return nil  // Swallow the event
            }
            return event
        }

        globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in
                self?.stopCaptureMode()
            }
        }
    }
    
    private func removeEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
        if let monitor = globalEscapeMonitor {
            NSEvent.removeMonitor(monitor)
            globalEscapeMonitor = nil
        }
    }

    private func activateCaptureCursor() {
        if !captureCursorPushed {
            NSCursor.crosshair.push()
            captureCursorPushed = true
        }
        NSCursor.crosshair.set()
    }

    private func deactivateCaptureCursor() {
        if captureCursorPushed {
            NSCursor.pop()
            captureCursorPushed = false
        }
        NSCursor.arrow.set()
    }
    
    // MARK: - Screen Capture
    
    private func captureCurrentElement() async {
        let frameToCapture = currentElementFrame
        let performOCR = isOCRCapture  // Capture flag value before reset
        
        guard frameToCapture.width > 0 && frameToCapture.height > 0 else {
            isOCRCapture = false
            stopCaptureMode()
            return
        }
        guard let targetScreen = screen(for: currentScreenDisplayID) else {
            isOCRCapture = false
            stopCaptureMode()
            return
        }
        
        // 1. Flash animation on the highlight
        highlightWindow?.flashCapture()
        
        // 2. Brief delay for flash effect
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        // 3. Hide overlay
        await MainActor.run {
            self.highlightWindow?.alphaValue = 0
            self.highlightWindow?.orderOut(nil)
        }
        
        // 4. Brief delay to ensure overlay is hidden
        try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        
        // 5. Capture the element
        do {
            let image = try await captureRect(frameToCapture, on: targetScreen)
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            
            if performOCR {
                // OCR mode: extract text from image
                do {
                    let text = try await OCRService.shared.performOCR(on: nsImage)
                    let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !normalizedText.isEmpty {
                        let targetDisplayID = self.currentScreenDisplayID
                        await MainActor.run {
                            OCRWindowController.shared.presentExtractedText(
                                normalizedText,
                                targetDisplayID: targetDisplayID
                            )
                        }
                        playScreenshotSound()
                        print("[ElementCapture] OCR completed successfully")
                    } else {
                        let targetDisplayID = self.currentScreenDisplayID
                        await MainActor.run {
                            OCRWindowController.shared.show(
                                with: "No text detected in the selected area.",
                                targetDisplayID: targetDisplayID
                            )
                        }
                        print("[ElementCapture] OCR returned empty text")
                    }
                } catch {
                    print("[ElementCapture] OCR failed: \(error)")
                }
            } else {
                // Normal capture mode
                copyToClipboard(image)
                playScreenshotSound()
                print("[ElementCapture] Element captured successfully")
                
                // Show preview window with actions
                await MainActor.run {
                    CapturePreviewWindowController.shared.show(with: nsImage)
                }
            }
            
        } catch {
            print("[ElementCapture] Capture failed: \(error)")
            // Note: We don't report failure here because capture can fail for many reasons
            // (invalid rect, window closed, etc.) not just permissions
        }
        
        // 6. Stop capture mode and reset flag
        isOCRCapture = false
        stopCaptureMode()
    }
    
    // MARK: - Fullscreen Capture
    
    private func captureFullscreen() async {
        // Get the screen under the mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = screenForMouseLocation(mouseLocation) else {
            stopCaptureMode()
            return
        }

        // Track which display we're capturing
        if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            currentScreenDisplayID = displayID
        }

        do {
            // Capture full display directly to avoid coordinate transform drift on mixed-DPI docked setups.
            let image = try await captureFullDisplay(on: screen)
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

        stopCaptureMode()
    }
    
    // MARK: - Window Capture
    
    private func captureWindowUnderCursor() async {
        let mouseLocation = NSEvent.mouseLocation
        guard let mouseScreen = screenForMouseLocation(mouseLocation) else {
            print("[ElementCapture] Could not resolve target screen for window capture")
            stopCaptureMode()
            return
        }
        
        let queryPoints = candidateQueryPoints(for: mouseLocation, on: mouseScreen)
        
        var windowFrame: CGRect?
        var targetScreen: NSScreen?
        
        for point in queryPoints {
            guard let frame = getWindowFrameAtPosition(point) else { continue }
            guard let screen = NSScreen.screens.first(where: { quartzScreenFrame(for: $0).intersects(frame) }) else { continue }
            guard let sanitized = sanitizeDetectedFrame(frame, queryPoint: point, on: screen) else { continue }
            windowFrame = sanitized
            targetScreen = screen
            break
        }
        
        guard let windowFrame, let targetScreen else {
            print("[ElementCapture] No window found under cursor")
            stopCaptureMode()
            return
        }
        
        if let displayID = targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            currentScreenDisplayID = displayID
        }
        
        do {
            let cocoaWindowFrame = convertToCocoaCoordinates(windowFrame, screen: targetScreen)
            let image = try await captureRect(cocoaWindowFrame, on: targetScreen)
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
        
        stopCaptureMode()
    }
    
    /// Capture a rect expressed in global Cocoa coordinates, constrained to one target NSScreen.
    /// This avoids cross-display/global-origin assumptions that can crop or offset captures.
    private func captureRect(_ cocoaRect: CGRect, on screen: NSScreen) async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() else {
            print("[ElementCapture] Screen recording permission not granted - aborting capture")
            CGRequestScreenCaptureAccess()
            throw CaptureError.permissionDenied
        }
        
        guard let targetDisplayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            throw CaptureError.noDisplay
        }
        
        // Keep capture requests strictly on the intended screen in global Cocoa coordinates.
        let requestedRect = cocoaRect.standardized
        let clampedCocoaRect = requestedRect.intersection(screen.frame)
        guard clampedCocoaRect.width >= 1, clampedCocoaRect.height >= 1 else {
            throw CaptureError.noElement
        }

        // Full-screen requests are captured via a dedicated path to avoid mixed-resolution
        // conversion edge cases during dock/undock transitions.
        if abs(clampedCocoaRect.origin.x - screen.frame.origin.x) < 0.5 &&
            abs(clampedCocoaRect.origin.y - screen.frame.origin.y) < 0.5 &&
            abs(clampedCocoaRect.width - screen.frame.width) < 0.5 &&
            abs(clampedCocoaRect.height - screen.frame.height) < 0.5 {
            return try await captureFullDisplay(on: screen)
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == targetDisplayID }) else {
            print("[ElementCapture] No display found for ID: \(targetDisplayID)")
            throw CaptureError.noDisplay
        }
        
        let displayWidthPoints = max(CGFloat(display.width), 1)
        let displayHeightPoints = max(CGFloat(display.height), 1)
        let displayBounds = CGRect(x: 0, y: 0, width: displayWidthPoints, height: displayHeightPoints)
        guard displayBounds.width >= 1, displayBounds.height >= 1 else {
            throw CaptureError.noElement
        }
        
        // ScreenCaptureKit sourceRect is expressed in display logical points.
        // Use direct point-space mapping from screen-local Cocoa coordinates.
        
        // Render output at native display pixel density for sharper captures,
        // especially on Retina / HiDPI screens.
        let nativePixelWidth = max(CGFloat(CGDisplayPixelsWide(targetDisplayID)), displayWidthPoints)
        let nativePixelHeight = max(CGFloat(CGDisplayPixelsHigh(targetDisplayID)), displayHeightPoints)
        let nativeScaleX = nativePixelWidth / displayWidthPoints
        let nativeScaleY = nativePixelHeight / displayHeightPoints
        
        var modeScaleX: CGFloat = 1
        var modeScaleY: CGFloat = 1
        if let mode = CGDisplayCopyDisplayMode(targetDisplayID) {
            let modeWidth = max(CGFloat(mode.width), 1)
            let modeHeight = max(CGFloat(mode.height), 1)
            let derivedModeScaleX = CGFloat(mode.pixelWidth) / modeWidth
            let derivedModeScaleY = CGFloat(mode.pixelHeight) / modeHeight
            if derivedModeScaleX.isFinite && derivedModeScaleX > 0 {
                modeScaleX = derivedModeScaleX
            }
            if derivedModeScaleY.isFinite && derivedModeScaleY > 0 {
                modeScaleY = derivedModeScaleY
            }
        }
        
        var outputScaleX = max(nativeScaleX, modeScaleX, screen.backingScaleFactor, 1)
        var outputScaleY = max(nativeScaleY, modeScaleY, screen.backingScaleFactor, 1)
        // Defensive upper bound to avoid pathological output allocations.
        outputScaleX = min(outputScaleX, 4)
        outputScaleY = min(outputScaleY, 4)
        
        let localX = clampedCocoaRect.origin.x - screen.frame.origin.x
        let localYFromBottom = clampedCocoaRect.origin.y - screen.frame.origin.y
        let localYFromTop = screen.frame.height - localYFromBottom - clampedCocoaRect.height
        
        var sourceRect = CGRect(
            x: localX,
            y: localYFromTop,
            width: clampedCocoaRect.width,
            height: clampedCocoaRect.height
        )
        
        // Expand to integral bounds so we never lose edge pixels due fractional coordinates.
        sourceRect = CGRect(
            x: floor(sourceRect.minX),
            y: floor(sourceRect.minY),
            width: ceil(sourceRect.maxX) - floor(sourceRect.minX),
            height: ceil(sourceRect.maxY) - floor(sourceRect.minY)
        )
        
        sourceRect = sourceRect.intersection(displayBounds)
        guard sourceRect.width >= 1, sourceRect.height >= 1 else {
            throw CaptureError.noElement
        }

        // Exclude only active Element Capture helper windows.
        let excludedWindowIDs = excludedCaptureHelperWindowIDs()
        let windowsToExclude = content.windows.filter { window in
            excludedWindowIDs.contains(CGWindowID(window.windowID))
        }
        let filter = SCContentFilter(display: display, excludingWindows: windowsToExclude)
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = max(1, Int((sourceRect.width * outputScaleX).rounded(.up)))
        config.height = max(1, Int((sourceRect.height * outputScaleY).rounded(.up)))
        config.scalesToFit = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        if #available(macOS 14.0, *) {
            config.captureResolution = .best
        }
        
        print("[ElementCapture] Capture(local): displayID=\(targetDisplayID), screen=\(screen.frame), displayBounds=\(displayBounds), requested=\(requestedRect), clamped=\(clampedCocoaRect), source=\(sourceRect), outputScale=\(String(format: "%.2f", outputScaleX))x\(String(format: "%.2f", outputScaleY)), output=\(config.width)x\(config.height)")
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Capture the full selected display directly in ScreenCaptureKit display space.
    /// This avoids Cocoa<->display coordinate conversion errors on mixed-DPI setups.
    private func captureFullDisplay(on screen: NSScreen) async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() else {
            print("[ElementCapture] Screen recording permission not granted - aborting capture")
            CGRequestScreenCaptureAccess()
            throw CaptureError.permissionDenied
        }

        guard let targetDisplayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            throw CaptureError.noDisplay
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == targetDisplayID }) else {
            print("[ElementCapture] No display found for ID: \(targetDisplayID)")
            throw CaptureError.noDisplay
        }

        let displayBounds = CGRect(
            x: 0,
            y: 0,
            width: max(CGFloat(display.width), 1),
            height: max(CGFloat(display.height), 1)
        )
        guard displayBounds.width >= 1, displayBounds.height >= 1 else {
            throw CaptureError.noElement
        }

        let excludedWindowIDs = excludedCaptureHelperWindowIDs()
        let windowsToExclude = content.windows.filter { window in
            excludedWindowIDs.contains(CGWindowID(window.windowID))
        }
        let filter = SCContentFilter(display: display, excludingWindows: windowsToExclude)
        let config = SCStreamConfiguration()
        config.sourceRect = displayBounds
        config.width = max(max(Int(CGDisplayPixelsWide(targetDisplayID)), Int(displayBounds.width.rounded(.up))), 1)
        config.height = max(max(Int(CGDisplayPixelsHigh(targetDisplayID)), Int(displayBounds.height.rounded(.up))), 1)
        config.scalesToFit = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        if #available(macOS 14.0, *) {
            config.captureResolution = .best
        }

        print("[ElementCapture] Capture(full display): displayID=\(targetDisplayID), displayBounds=\(displayBounds), output=\(config.width)x\(config.height)")
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    private func handleScreenParametersChanged() {
        guard isActive else { return }

        let mouseLocation = NSEvent.mouseLocation
        guard let activeScreen = screenForMouseLocation(mouseLocation) else {
            return
        }

        if let displayID = activeScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            currentScreenDisplayID = displayID
        }

        // Refresh overlays to the currently active display geometry after dock/undock.
        if activeMode == .element {
            lastDetectedFrame = .zero
            currentElementFrame = .zero
            hasElement = false
            highlightWindow?.resetHighlight()
            highlightWindow?.setFrame(activeScreen.frame, display: true, animate: false)
            highlightWindow?.orderFrontRegardless()
        } else if activeMode == .area || activeMode == .ocr {
            areaSelectionWindow?.setFrame(activeScreen.frame, display: true, animate: false)
            areaSelectionWindow?.orderFrontRegardless()
        }

        print("[ElementCapture] Screen parameters changed; resynced capture surfaces")
    }

    /// Window IDs for transient capture helper UI that should never appear in screenshots.
    /// NOTE: The screenshot editor window is intentionally NOT excluded so users can capture it.
    private func excludedCaptureHelperWindowIDs() -> Set<CGWindowID> {
        var ids = Set<CGWindowID>()
        if let number = highlightWindow?.windowNumber, number > 0 {
            ids.insert(CGWindowID(number))
        }
        if let number = areaSelectionWindow?.windowNumber, number > 0 {
            ids.insert(CGWindowID(number))
        }
        if let number = CapturePreviewWindowController.shared.currentWindowNumber, number > 0 {
            ids.insert(CGWindowID(number))
        }
        return ids
    }
    
    private func copyToClipboard(_ image: CGImage) {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        var wroteData = false
        
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            wroteData = pasteboard.setData(pngData, forType: .png) || wroteData
        }
        
        if let tiffData = bitmapRep.tiffRepresentation {
            wroteData = pasteboard.setData(tiffData, forType: .tiff) || wroteData
        }
        
        if !wroteData {
            let fallbackImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            pasteboard.writeObjects([fallbackImage])
        }
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
        areaShortcut = nil
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
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
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

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown && event.keyCode == 53 {
            onCancel?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
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
    private var escapeMonitor: Any?
    private var globalEscapeMonitor: Any?

    var currentWindowNumber: Int? { window?.windowNumber }
    
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
        installEscapeMonitors()
        
        // Auto-dismiss after 3 seconds
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }
    
    func dismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        removeEscapeMonitors()
        
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
        removeEscapeMonitors()
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
        hostingView = nil
    }

    private func installEscapeMonitors() {
        removeEscapeMonitors()

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            guard let self = self, let window = self.window, window.isVisible else { return event }
            self.dismiss()
            return nil
        }

        globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor [weak self] in
                guard let self = self, let window = self.window, window.isVisible else { return }
                self.dismiss()
            }
        }
    }

    private func removeEscapeMonitors() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
        if let monitor = globalEscapeMonitor {
            NSEvent.removeMonitor(monitor)
            globalEscapeMonitor = nil
        }
    }
}

// MARK: - Capture Preview View (Styled like Basket)
