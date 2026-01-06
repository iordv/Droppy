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
        // If window already exists, just bring it to front
        if let window = window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        // Create the SwiftUI view
        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        
        // SettingsView uses macOS 26 Tahoe glass design
        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 550
        
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
        
        // Bring to front and activate
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
