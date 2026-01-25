import AppKit
import SwiftUI

/// Manages the settings window for Droppy
final class SettingsWindowController: NSObject, NSWindowDelegate {
    /// Shared instance
    static let shared = SettingsWindowController()
    
    /// The settings window
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    /// Shows the settings window, creating it if necessary
    func showSettings() {
        showSettings(openingExtension: nil)
    }
    
    /// Extension type to open when settings loads (cleared after use)
    private(set) var pendingExtensionToOpen: ExtensionType?
    
    /// Shows the settings window with optional extension sheet
    /// - Parameter extensionType: If provided, will navigate to Extensions and open this extension's info sheet
    func showSettings(openingExtension extensionType: ExtensionType?) {
        // Store the pending extension before potentially creating the window
        pendingExtensionToOpen = extensionType
        
        // If window already exists, just bring it to front
        if let window = window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            
            // Post notification so SettingsView can handle the extension
            if extensionType != nil {
                NotificationCenter.default.post(name: .openExtensionFromDeepLink, object: extensionType)
            }
            return
        }
        
        // Create the SwiftUI view
        let settingsView = SettingsView()
            .preferredColorScheme(.dark) // Force dark mode always
        let hostingView = NSHostingView(rootView: settingsView)
        
        // SettingsView uses macOS 26 Tahoe glass design
        let windowWidth: CGFloat = 850
        let windowHeight: CGFloat = 650
        
        // Create the window
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.center()
        newWindow.title = "Settings"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .visible
        
        // Configure background and appearance
        // NOTE: Do NOT use isMovableByWindowBackground to avoid buttons triggering window drag
        newWindow.isMovableByWindowBackground = false
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isReleasedWhenClosed = false
        
        newWindow.delegate = self
        newWindow.contentView = hostingView
        
        self.window = newWindow
        
        // PREMIUM: Start scaled down and invisible for spring animation
        newWindow.alphaValue = 0
        if let contentView = newWindow.contentView {
            contentView.wantsLayer = true
            contentView.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
            contentView.layer?.opacity = 0
        }
        
        // Bring to front and activate
        // Use slight delay to ensure NotchWindow's canBecomeKey has time to update
        // after detecting this window is visible
        newWindow.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            newWindow.makeKeyAndOrderFront(nil)
            
            // Post notification after window is ready
            if extensionType != nil {
                NotificationCenter.default.post(name: .openExtensionFromDeepLink, object: extensionType)
            }
        }
        
        // PREMIUM: CASpringAnimation for true spring physics with overshoot
        if let layer = newWindow.contentView?.layer {
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
            newWindow.animator().alphaValue = 1.0
        })
        
        // PREMIUM: Haptic confirms settings opened
        HapticFeedback.expand()
    }
    
    /// Close the settings window
    func close() {
        window?.close()
    }
    
    /// Clears the pending extension (called after SettingsView consumes it)
    func clearPendingExtension() {
        pendingExtensionToOpen = nil
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
