import Cocoa
import SwiftUI

class ClipboardWindowController: NSObject, NSWindowDelegate {
    static let shared = ClipboardWindowController()
    
    var window: NSWindow!
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    // Copy+Favorite shortcut (Issue #43)
    private var copyFavoriteHotKey: GlobalHotKey?
    private var copyFavoriteLocalMonitor: Any?
    
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
        .preferredColorScheme(.dark) // Force dark mode always
        
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
        
        // Fix for Issue #33: Prevent snapping back to previous window/space
        // Allow floating over full screen apps and on all desktops
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
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
        
        // PREMIUM SPRING: Start scaled down for bouncy appear animation
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0) // More noticeable scale
            contentView.layer?.opacity = 0
        }
        
        // ✅ Restore Focus to allow Keyboard Navigation (Arrows + Enter)
        // Use orderFront first, then async makeKey to ensure NotchWindow's canBecomeKey updates
        window.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            // Post notification for View to reset state (Search/Selection)
            NotificationCenter.default.post(name: .clipboardWindowDidShow, object: nil)
        }
        
        // Start monitoring for clicks outside to auto-close (since we are not Key)
        startClickMonitoring()
        
        print("⌨️ Droppy: Showing Clipboard Window")
        
        // PREMIUM: Use CASpringAnimation for true spring physics with visible overshoot
        if let layer = window.contentView?.layer {
            // Fade in (faster)
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 0
            fadeAnim.toValue = 1
            fadeAnim.duration = 0.12  // Faster fade
            fadeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fadeAnim.fillMode = .forwards
            fadeAnim.isRemovedOnCompletion = false
            layer.add(fadeAnim, forKey: "fadeIn")
            layer.opacity = 1
            
            // Scale with spring overshoot (snappier - stiffness 420 for fast response)
            let scaleAnim = CASpringAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.85
            scaleAnim.toValue = 1.0
            scaleAnim.mass = 1.0
            scaleAnim.stiffness = 420  // Higher = faster (was 280)
            scaleAnim.damping = 22     // Slightly more damped for snappy feel
            scaleAnim.initialVelocity = 10
            scaleAnim.duration = scaleAnim.settlingDuration
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            layer.add(scaleAnim, forKey: "scaleSpring")
            layer.transform = CATransform3DIdentity
        }
        
        // Fade window alpha (faster)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
        })
        
        // PREMIUM: Haptic confirms clipboard opened
        HapticFeedback.expand()
    }

    func close() {
        guard let window = window, window.isVisible, !isAnimating else { return }
        
        // Stop monitoring immediately
        stopClickMonitoring()
        
        // Reset editing state to ensure shortcuts work correctly next time
        ClipboardManager.shared.isEditingContent = false
        
        isAnimating = true
        print("⌨️ Droppy: Fading Out Clipboard Window (Duration: 0.25s)...")
        
        // PREMIUM SPRING: Ensure layer backing for smooth animation
        if let contentView = window.contentView {
            contentView.wantsLayer = true
        }
        
        // PREMIUM SPRING ANIMATION: Scale down + fade out (snappier close)
        let smoothCurve = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15  // Faster close (was 0.2)
            context.timingFunction = smoothCurve
            context.allowsImplicitAnimation = true
            window.animator().alphaValue = 0
            window.contentView?.layer?.transform = CATransform3DMakeScale(0.94, 0.94, 1.0)
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.window?.contentView?.layer?.transform = CATransform3DIdentity // Reset for next show
            self?.window?.alphaValue = 1.0
            self?.isAnimating = false
        })
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
            
            // Don't close if click is on the Rename window
            if let renameWindow = RenameWindowController.shared.window, event.window == renameWindow {
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
                
                // 1. Hide Droppy window (already ordered out), just ensure focus returns
                // NSApp.hide(nil) - REMOVED: This was hiding the Notch window too!
                // NSApp.deactivate() - REMOVED: Unnecessary if we activate target app
                
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
                // No previous app, just hide window and paste (fallback)
                // NSApp.hide(nil) - REMOVED
                // NSApp.deactivate() - REMOVED
                
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
            self?.checkPermissionsDebounced()
        }
        
        // 4. Start Copy+Favorite shortcut (Issue #43)
        startCopyFavoriteShortcut()
    }
    
    /// Tracks last permission check to prevent rapid re-checks
    private var lastPermissionCheckTime: Date?
    private let permissionCheckDebounceInterval: TimeInterval = 30 // Only check every 30 seconds max
    
    private func checkPermissionsDebounced() {
        // Debounce: Skip if we checked recently to prevent TCC race conditions
        if let lastCheck = lastPermissionCheckTime,
           Date().timeIntervalSince(lastCheck) < permissionCheckDebounceInterval {
            print("🔐 ClipboardWindowController: Skipping permission check (debounced)")
            return
        }
        lastPermissionCheckTime = Date()
        
        checkPermissions()
    }
    
    private func checkPermissions() {
        // Use centralized PermissionManager with caching
        let accessibilityOk = PermissionManager.shared.isAccessibilityGranted
        
        // Input Monitoring Check (uses runtime check + cache)
        let isInputMonitoringActive = globalHotKey?.isInputMonitoringActive ?? false
        let inputMonitoringOk = PermissionManager.shared.isInputMonitoringGranted(runtimeCheck: isInputMonitoringActive)
        
        // If all permissions are granted, return without prompting
        if accessibilityOk && inputMonitoringOk {
            return
        }
        
        // Build message with missing permissions
        var missingPermissions: [String] = []
        if !accessibilityOk { missingPermissions.append("• Accessibility (for Paste)") }
        if !inputMonitoringOk { missingPermissions.append("• Input Monitoring (for Global Hotkey)") }
        
        print("🔐 ClipboardWindowController: Missing permissions: \(missingPermissions.joined(separator: ", "))")
        
        // Use ONLY macOS native dialogs - no Droppy custom dialogs
        if !accessibilityOk {
            print("🔐 ClipboardWindowController: Requesting Accessibility via native dialog")
            PermissionManager.shared.requestAccessibility()
        }
        if !inputMonitoringOk {
            print("🔐 ClipboardWindowController: Opening Input Monitoring settings (no native dialog available)")
            PermissionManager.shared.openInputMonitoringSettings()
        }
    }
    
    func stopMonitoringShortcut() {
        // GlobalHotKey deinit handles unregistration
        globalHotKey = nil
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        // Also stop Copy+Favorite shortcut
        stopCopyFavoriteShortcut()
    }
    
    // MARK: - Copy+Favorite Shortcut (Issue #43)
    
    func startCopyFavoriteShortcut() {
        stopCopyFavoriteShortcut()
        
        // Check if enabled
        guard UserDefaults.standard.bool(forKey: "clipboardCopyFavoriteEnabled") else { 
            print("⌨️ Droppy: Copy+Favorite disabled")
            return 
        }
        
        // Load saved shortcut or use default (Cmd+Shift+C)
        var targetKeyCode = 8 // C key
        var targetModifiers: UInt = NSEvent.ModifierFlags([.command, .shift]).rawValue
        
        if let data = UserDefaults.standard.data(forKey: "clipboardCopyFavoriteShortcut"),
           let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            targetKeyCode = decoded.keyCode
            targetModifiers = decoded.modifiers
        }
        
        print("⌨️ Droppy: Registering Copy+Favorite shortcut - keyCode: \(targetKeyCode), modifiers: \(targetModifiers)")
        
        // Register Carbon HotKey for Copy+Favorite
        copyFavoriteHotKey = GlobalHotKey(keyCode: targetKeyCode, modifiers: targetModifiers) {
            print("⌨️ Droppy: Copy+Favorite Shortcut Triggered")
            // Get the current clipboard content and favorite it
            ClipboardManager.shared.copyAndFavoriteCurrentClipboard()
        }
        
        // Local monitor to swallow the event
        copyFavoriteLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.rawValue == targetModifiers && event.keyCode == targetKeyCode {
                return nil
            }
            return event
        }
        
        print("⌨️ Droppy: Copy+Favorite Shortcut Registered")
    }
    
    func stopCopyFavoriteShortcut() {
        copyFavoriteHotKey = nil
        
        if let monitor = copyFavoriteLocalMonitor {
            NSEvent.removeMonitor(monitor)
            copyFavoriteLocalMonitor = nil
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
