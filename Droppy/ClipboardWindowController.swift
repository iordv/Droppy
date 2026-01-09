import Cocoa
import SwiftUI

class ClipboardWindowController: NSObject, NSWindowDelegate {
    static let shared = ClipboardWindowController()
    
    var window: NSWindow!
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    private override init() {
        super.init()
        // Lazy setup when needed or on init? Let's do on init to be ready.
        setupWindow()
    }
    
    func setupWindow() {
        let clipboardView = ClipboardManagerView(
            onPaste: { item in
                self.paste(item)
            },
            onClose: {
                self.close()
            },
            onReset: {
                self.resetWindowSize()
            }
        )
        
        // Use NSHostingView like SettingsWindowController for native sidebar appearance
        let hostingView = NSHostingView(rootView: clipboardView)
        
        // Use ClipboardPanel (custom NSPanel subclass) for proper focus handling
        // ClipboardPanel overrides canBecomeKey and canBecomeMain to allow interaction
        // even after other windows (like media player) have taken focus
        window = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "Clipboard"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible  // Same as Settings
        
        // Configure background and appearance - EXACTLY like Settings
        // NOTE: Do NOT use isMovableByWindowBackground to avoid entries/buttons triggering window drag
        window.isMovableByWindowBackground = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        
        window.delegate = self
        window.contentView = hostingView
        
        // Note: Removed level = .popUpMenu and custom collectionBehavior to match Settings
        
        // Allow clicking on it and becoming key
        window.ignoresMouseEvents = false
    }

    func resetWindowSize() {
        guard let window = window, let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let newRect = NSRect(
            x: screenRect.midX - 520, 
            y: screenRect.midY - 320, 
            width: 1040, 
            height: 640
        )
        DispatchQueue.main.async {
            window.setFrame(newRect, display: true, animate: true)
        }
    }
    
    private var isAnimating = false
    private var previousApp: NSRunningApplication?

    func toggle() {
        guard let window = window else {
            setupWindow()
            show()
            return
        }
        if window.isVisible {
            close()
        } else {
            show()
        }
    }
    
    private var clickMonitor: Any?
    private var localClickMonitor: Any?

    func show() {
        guard !isAnimating, let window = window else { return }
        
        // Save previous app
        if let frontmost = NSWorkspace.shared.frontmostApplication, 
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmost
        }
        
        // Center window
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = window.frame
            let x = screenRect.midX - (windowRect.width / 2)
            let y = screenRect.midY - (windowRect.height / 2)
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        isAnimating = true
        window.alphaValue = 0
        
        // ✅ Restore Focus to allow Keyboard Navigation (Arrows + Enter)
        // Use orderFront first, then async makeKey to ensure NotchWindow's canBecomeKey updates
        window.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
        
        // Start monitoring for clicks outside to auto-close (since we are not Key)
        startClickMonitoring()
        
        print("⌨️ Droppy: Showing Clipboard Window")
        
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.25
        NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeOut)
        window.animator().alphaValue = 1.0
        NSAnimationContext.endGrouping()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.isAnimating = false
        }
    }

    func close() {
        guard let window = window, window.isVisible, !isAnimating else { return }
        
        // Stop monitoring immediately
        stopClickMonitoring()
        
        isAnimating = true
        print("⌨️ Droppy: Fading Out Clipboard Window (Duration: 0.35s)...")
        
        // Use explicit grouping to force commit even if app is deactivating
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0.35
        NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeOut)
        NSAnimationContext.current.completionHandler = { [weak self] in
            // Only order out AFTER animation completes
            self?.window?.orderOut(nil)
            self?.isAnimating = false
            self?.window?.alphaValue = 1.0 
        }
        window.animator().alphaValue = 0
        NSAnimationContext.endGrouping()
    }
    
    // MARK: - Click Monitoring (Auto-Close)

    
    private func startClickMonitoring() {
        stopClickMonitoring()
        
        print("🖱️ Droppy: Starting Click Monitoring")
        
        // 1. Global Monitor (Clicks sent to OTHER apps)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.window, window.isVisible else { return }
            
            // Check if click is outside our window frame
            let mouseLoc = NSEvent.mouseLocation
            let windowFrame = window.frame
            
            if !windowFrame.contains(mouseLoc) {
                print("🖱️ Droppy: Global Click Outside (Loc: \(mouseLoc) | Frame: \(windowFrame)) -> Closing")
                DispatchQueue.main.async {
                    self.close()
                }
            }
        }
        
        // 2. Local Monitor (Clicks sent to OUR app)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.window, window.isVisible else { return event }
            
            // Don't close if click is on the OCR window
            if let ocrWindow = OCRWindowController.shared.window, event.window == ocrWindow {
                return event
            }
            
            if event.window != window {
                print("🖱️ Droppy: Local Click Outside (Window: \(String(describing: event.window))) -> Closing")
                DispatchQueue.main.async {
                    self.close()
                }
            } else {
                 // Click was inside the window, check coordinates just in case (e.g. slight border issues)
                 let mouseLoc = NSEvent.mouseLocation
                 if !window.frame.contains(mouseLoc) {
                     // Can happen if event.window is set but coordinate is outside? Rare.
                     print("🖱️ Droppy: Local Click reported inside but coords outside -> Closing")
                     DispatchQueue.main.async { self.close() }
                 }
            }
            return event
        }
    }
    
    private func stopClickMonitoring() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }
    
    func paste(_ item: ClipboardItem) {
        guard let window = window else { return }
        
        // Dismiss clipboard immediately
        isAnimating = true
        // Stop monitoring to prevent double-closes
        stopClickMonitoring()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.isAnimating = false
            
            // The Mirror Method (V12): Refined Sequence
            if let targetApp = self?.previousApp {
                let pid = targetApp.processIdentifier
                
                // 1. Hide Droppy first
                NSApp.hide(nil)
                NSApp.deactivate()
                
                // 2. Tiny wait to ensure Droppy is gone from focus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    // 3. Activate target app with all windows
                    targetApp.activate(options: .activateAllWindows)
                    
                    // 4. Wait for focus to settle (Matches ClipBook's 150ms)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        ClipboardManager.shared.paste(item: item, targetPID: pid)
                    }
                }
            } else {
                NSApp.hide(nil)
                NSApp.deactivate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    ClipboardManager.shared.paste(item: item)
                }
            }
        })
    }

    // Removed dead code: windowDidResignKey (Window is never Key now)

    
    // MARK: - Global Shortcut (Carbon)
    private var globalHotKey: GlobalHotKey?
    
    func startMonitoringShortcut() {
        stopMonitoringShortcut()
        
        // Load saved shortcut
        var targetKeyCode = 49 // Space
        var targetModifiers: UInt = NSEvent.ModifierFlags([.command, .shift]).rawValue
        
        if let data = UserDefaults.standard.data(forKey: "clipboardShortcut"),
           let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            targetKeyCode = decoded.keyCode
            targetModifiers = decoded.modifiers
        }
        
        // 1. Carbon HotKey (Works even with Secure Input / Password Fields)
        globalHotKey = GlobalHotKey(keyCode: targetKeyCode, modifiers: targetModifiers) { [weak self] in
            print("⌨️ Droppy: Global Shortcut Triggered (Carbon)")
            self?.toggle()
        }
        
        // 2. Only keep Local Monitor for swallowing the event when active
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.rawValue == targetModifiers && event.keyCode == targetKeyCode {
                return nil
            }
            return event
        }
        
        // 3. Permission Check & Prompt
        // Wait 3.5 seconds to allow IOHIDManager retry logic (up to 3s) to complete first
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.checkPermissions()
        }
    }
    
    private func checkPermissions() {
        // First check WITHOUT prompting - use AXIsProcessTrusted() instead of AXIsProcessTrustedWithOptions with prompt
        let isAccessibilityTrusted = AXIsProcessTrusted()
        
        // Input Monitoring Check
        // First check the runtime variable, then fall back to cached grant
        // The cache persists across launches when IOHIDManager has successfully opened before
        let isInputMonitoringActive = globalHotKey?.isInputMonitoringActive ?? false
        let hasCachedGrant = UserDefaults.standard.bool(forKey: "inputMonitoringGranted")
        
        // If either the runtime check passes OR we have a cached successful grant, consider it active
        // This prevents repeated prompts when TCC is slow to respond
        let inputMonitoringOk = isInputMonitoringActive || hasCachedGrant
        
        // If all permissions are granted, return without prompting
        if isAccessibilityTrusted && inputMonitoringOk {
            return
        }
        
        // Build message with missing permissions
        var missingPermissions: [String] = []
        if !isAccessibilityTrusted { missingPermissions.append("• Accessibility (for Paste)") }
        if !inputMonitoringOk { missingPermissions.append("• Input Monitoring (for Global Hotkey)") }
        
        let message = "To work in password fields and all apps, Droppy needs:\n\n" +
            missingPermissions.joined(separator: "\n") +
            "\n\nPlease enable them in System Settings."
        
        // Save whether input monitoring was the issue for when user clicks Open Settings
        let needsInputMonitoring = !inputMonitoringOk
        
        // Show styled alert
        Task { @MainActor in
            let shouldOpen = await DroppyAlertController.shared.showPermissions(
                title: "Permissions Required",
                message: message
            )
            
            if shouldOpen {
                if needsInputMonitoring {
                    // Open Input Monitoring (Privacy_ListenEvent)
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                } else {
                    // Open Accessibility
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        }
    }
    
    func stopMonitoringShortcut() {
        // GlobalHotKey deinit handles unregistration
        globalHotKey = nil
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
}

// MARK: - Custom Panel Class
class ClipboardPanel: NSPanel {
    // ✅ FIX: Allow window to become key so it can receive Keyboard Events (Enter, Arrows)
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    // ✅ FIX v5.3: Configure panel for immediate click handling
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Panel should become key on any click, not just title bar
        self.becomesKeyOnlyIfNeeded = false
        
        // Ensure the panel can accept mouse events immediately
        self.isFloatingPanel = false
        self.worksWhenModal = true
    }
}
