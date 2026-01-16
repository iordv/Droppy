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

// MARK: - Element Capture Manager

@MainActor
final class ElementCaptureManager: ObservableObject {
    static let shared = ElementCaptureManager()
    
    // MARK: - Published State
    
    @Published private(set) var isActive = false
    @Published private(set) var currentElementFrame: CGRect = .zero
    @Published private(set) var hasElement = false
    @Published var shortcut: SavedShortcut? {
        didSet { saveShortcut() }
    }
    @Published private(set) var isShortcutEnabled = false
    
    // MARK: - Private Properties
    
    private var highlightWindow: ElementHighlightWindow?
    private var mouseTrackingTimer: Timer?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastDetectedFrame: CGRect = .zero
    private var hotkeyMonitor: Any?
    private var escapeMonitor: Any?  // Local monitor for ESC key
    
    // MARK: - Configuration
    
    private let highlightPadding: CGFloat = 4.0
    private let highlightColor = NSColor.systemCyan
    private let borderWidth: CGFloat = 2.0
    private let cornerRadius: CGFloat = 6.0
    private let mousePollingInterval: TimeInterval = 1.0 / 60.0  // 60 FPS
    private let shortcutKey = "elementCaptureShortcut"
    
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
        
        loadShortcut()
        if shortcut != nil {
            startMonitoringShortcut()
        }
    }
    
    // MARK: - Public API
    
    /// Start element capture mode
    func startCaptureMode() {
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
        
        isActive = true
        
        // Create overlay window
        setupHighlightWindow()
        
        // Start mouse tracking
        startMouseTracking()
        
        // Install event tap to intercept clicks
        installEventTap()
        
        // Install ESC key monitor to cancel
        installEscapeMonitor()
        
        // Change cursor to crosshair
        NSCursor.crosshair.push()
        
        print("[ElementCapture] Capture mode started")
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
        
        // Restore cursor
        NSCursor.pop()
        
        print("[ElementCapture] Capture mode stopped")
    }
    
    // MARK: - Shortcut Persistence
    
    private func loadShortcut() {
        if let data = UserDefaults.standard.data(forKey: shortcutKey),
           let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            shortcut = decoded
        }
    }
    
    private func saveShortcut() {
        if let s = shortcut, let encoded = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(encoded, forKey: shortcutKey)
            // Stop old monitor and start new one with updated shortcut
            stopMonitoringShortcut()
            startMonitoringShortcut()
            // Notify menu to refresh
            NotificationCenter.default.post(name: .elementCaptureShortcutChanged, object: nil)
        } else {
            UserDefaults.standard.removeObject(forKey: shortcutKey)
            stopMonitoringShortcut()
            // Notify menu to refresh
            NotificationCenter.default.post(name: .elementCaptureShortcutChanged, object: nil)
        }
    }
    
    // MARK: - Global Hotkey Monitoring
    
    func startMonitoringShortcut() {
        // Don't start if extension is disabled
        guard !ExtensionType.elementCapture.isRemoved else { return }
        // Prevent duplicate monitoring
        guard hotkeyMonitor == nil else { return }
        guard let savedShortcut = shortcut else { return }
        
        hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // CRITICAL: Check if extension is disabled - stops shortcuts from working
            guard !ExtensionType.elementCapture.isRemoved else { return }
            
            // Check if the pressed key matches our shortcut
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            if Int(event.keyCode) == savedShortcut.keyCode &&
               flags.rawValue == savedShortcut.modifiers {
                // Use async to avoid blocking event handler
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.isActive {
                        self.stopCaptureMode()
                    } else {
                        self.startCaptureMode()
                    }
                }
            }
        }
        
        isShortcutEnabled = true
        print("[ElementCapture] Shortcut monitoring started: \(savedShortcut.description)")
    }
    
    func stopMonitoringShortcut() {
        if let monitor = hotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyMonitor = nil
        }
        isShortcutEnabled = false
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
        let alert = NSAlert()
        alert.messageText = "Permissions Required"
        alert.informativeText = "Element Capture requires Accessibility and Screen Recording permissions.\n\nPlease grant these in System Settings > Privacy & Security."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Check which permission is missing and open the right pane
            if !PermissionManager.shared.isScreenRecordingGranted {
                PermissionManager.shared.openScreenRecordingSettings()
            } else if !PermissionManager.shared.isAccessibilityGranted {
                PermissionManager.shared.openAccessibilitySettings()
            }
        }
    }
    
    // MARK: - Highlight Window Setup
    
    private func setupHighlightWindow() {
        // Get the main screen's frame
        guard let screen = NSScreen.main else { return }
        
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
        
        // Convert from Cocoa (bottom-left) to Quartz (top-left) coordinates
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else {
            hideHighlight()
            return
        }
        
        let quartzPoint = convertToQuartzCoordinates(mouseLocation, screen: screen)
        
        // Try Accessibility API first, fall back to window detection
        let elementFrame: CGRect
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
        
        // Apply padding
        let paddedFrame = elementFrame.insetBy(dx: -highlightPadding, dy: -highlightPadding)
        
        // Only update if frame changed significantly (avoid micro-jitters)
        if !framesAreNearlyEqual(paddedFrame, lastDetectedFrame) {
            lastDetectedFrame = paddedFrame
            currentElementFrame = paddedFrame
            hasElement = true
            
            // Convert back to Cocoa coordinates for the overlay
            let cocoaFrame = convertToCocoaCoordinates(paddedFrame, screen: screen)
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
        // Get the primary screen's height (Quartz uses primary screen as reference)
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        return CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }
    
    /// Convert Quartz coordinates (top-left origin) to Cocoa coordinates (bottom-left origin)
    private func convertToCocoaCoordinates(_ rect: CGRect, screen: NSScreen) -> CGRect {
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
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) else {
            return nil
        }
        
        // Get size
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let sizeValue = sizeValue else {
            return nil
        }
        
        var size = CGSize.zero
        guard AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
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
        }
        
        // 6. Stop capture mode
        stopCaptureMode()
    }
    
    private func captureRect(_ rect: CGRect) async throws -> CGImage {
        // Get available content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Find the display containing the rect
        guard let display = content.displays.first(where: { display in
            let displayFrame = CGRect(x: 0, y: 0, width: display.width, height: display.height)
            return displayFrame.intersects(rect)
        }) else {
            throw CaptureError.noDisplay
        }
        
        // Calculate pixel dimensions (Retina scaling)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // Configure capture
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width * scale)
        config.height = Int(rect.height * scale)
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
        
        // Stop monitoring shortcut
        stopMonitoringShortcut()
        
        // Clear saved shortcut
        shortcut = nil
        UserDefaults.standard.removeObject(forKey: shortcutKey)
        
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
        
        // Add highlight view
        self.contentView = highlightView
        highlightView.frame = contentRect
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
        
        // Create SwiftUI view (no extra clipShape - view handles its own clipping)
        let previewView = CapturePreviewView(image: image)
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



