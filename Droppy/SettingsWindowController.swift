import AppKit
import SwiftUI

/// Manages the settings window for Droppy
final class SettingsWindowController: NSObject, NSWindowDelegate {
    /// Shared instance
    static let shared = SettingsWindowController()
    
    /// The settings window
    private var window: NSWindow?
    
    /// Dedicated lightweight window for Menu Bar Manager quick settings
    private var menuBarManagerWindow: NSWindow?
    
    private override init() {
        super.init()
    }
    
    /// Shows the settings window, creating it if necessary
    func showSettings() {
        showSettings(openingExtension: nil)
    }
    
    /// Shows the settings window and navigates to a specific tab
    /// - Parameter tab: The settings tab to open
    func showSettings(tab: SettingsTab) {
        pendingTabToOpen = tab
        showSettings(openingExtension: nil)
    }
    
    /// Extension type to open when settings loads (cleared after use)
    private(set) var pendingExtensionToOpen: ExtensionType?
    
    /// Tab to open when settings loads (cleared after use)
    private(set) var pendingTabToOpen: SettingsTab?
    
    /// Shows the settings window with optional extension sheet
    /// - Parameter extensionType: If provided, will navigate to Extensions and open this extension's info sheet
    func showSettings(openingExtension extensionType: ExtensionType?) {
        let licenseManager = LicenseManager.shared
        if licenseManager.requiresLicenseEnforcement && !licenseManager.hasAccess {
            pendingExtensionToOpen = nil
            pendingTabToOpen = nil
            close()
            LicenseWindowController.shared.show()
            return
        }

        // Full settings takes precedence over the lightweight MBM quick window.
        closeMenuBarManagerQuickSettings()

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

        let hostingView = NSHostingView(rootView: settingsView)
        
        // Keep all settings tabs at extensions width for layout consistency
        let windowWidth: CGFloat = 920
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
        AppKitMotion.prepareForPresent(newWindow, initialScale: 0.9)
        
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
        AppKitMotion.animateIn(newWindow, initialScale: 0.9, duration: 0.24)
        
        // PREMIUM: Haptic confirms settings opened
        HapticFeedback.expand()
    }
    
    /// Opens a lightweight window that renders only Menu Bar Manager settings.
    /// Used by the menu-bar context menu path for faster startup than full SettingsView.
    func showMenuBarManagerQuickSettings() {
        let licenseManager = LicenseManager.shared
        if licenseManager.requiresLicenseEnforcement && !licenseManager.hasAccess {
            pendingExtensionToOpen = nil
            pendingTabToOpen = nil
            close()
            closeMenuBarManagerQuickSettings()
            LicenseWindowController.shared.show()
            return
        }

        // If full settings is already open, route to the extension sheet there.
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            NotificationCenter.default.post(name: .openExtensionFromDeepLink, object: ExtensionType.menuBarManager)
            return
        }

        if let menuBarManagerWindow {
            NSApp.activate(ignoringOtherApps: true)
            menuBarManagerWindow.makeKeyAndOrderFront(nil)
            return
        }

        let content = MenuBarManagerInfoView(
            installCount: nil,
            rating: nil
        )
        let hostingView = NSHostingView(rootView: content)
        let availableHeight = NSScreen.main?.visibleFrame.height ?? 800
        let windowWidth: CGFloat = 450
        let windowHeight: CGFloat = min(760, max(520, availableHeight - 120))

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newWindow.center()
        newWindow.title = ""
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.standardWindowButton(.closeButton)?.isHidden = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true
        newWindow.isMovableByWindowBackground = false
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.contentView = hostingView

        menuBarManagerWindow = newWindow

        AppKitMotion.prepareForPresent(newWindow, initialScale: 0.95)
        newWindow.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            newWindow.makeKeyAndOrderFront(nil)
        }
        AppKitMotion.animateIn(newWindow, initialScale: 0.95, duration: 0.2)
        HapticFeedback.expand()
    }
    
    /// Close the settings window
    func close() {
        window?.close()
        menuBarManagerWindow?.close()
    }
    
    /// Close the lightweight Menu Bar Manager quick settings window.
    func closeMenuBarManagerQuickSettings() {
        menuBarManagerWindow?.close()
    }
    
    /// Clears the pending extension (called after SettingsView consumes it)
    func clearPendingExtension() {
        pendingExtensionToOpen = nil
    }
    
    /// Clears the pending tab (called after SettingsView consumes it)
    func clearPendingTab() {
        pendingTabToOpen = nil
    }

    /// Ensures no stale AppKit sheet remains attached after SwiftUI sheet dismissal.
    /// This prevents the settings window from staying dimmed due to a dangling sheet link.
    func cleanupAttachedSheetIfPresent() {
        guard let window = window, let sheet = window.attachedSheet else { return }
        window.endSheet(sheet, returnCode: .cancel)
    }
    
    // MARK: - Window Sizing
    
    /// Base width for regular settings tabs
    static let baseWidth: CGFloat = 920
    
    /// Extended width for extensions tab
    static let extensionsWidth: CGFloat = 920
    
    /// Resize the settings window based on the current tab
    /// - Parameter isExtensions: Whether the extensions tab is selected
    func resizeForTab(isExtensions: Bool) {
        guard let window = window else { return }
        
        let targetWidth = isExtensions ? Self.extensionsWidth : Self.baseWidth
        let currentFrame = window.frame
        
        // Only resize if width actually changed
        guard abs(currentFrame.width - targetWidth) > 1 else { return }
        
        // Calculate new frame, keeping window centered horizontally
        let widthDelta = targetWidth - currentFrame.width
        let newFrame = NSRect(
            x: currentFrame.origin.x - widthDelta / 2,
            y: currentFrame.origin.y,
            width: targetWidth,
            height: currentFrame.height
        )
        
        AppKitMotion.animateFrame(window, to: newFrame, duration: 0.2)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow {
            // Aggressively release the hosted SwiftUI tree when the window closes.
            closingWindow.contentView = nil
            closingWindow.delegate = nil
            if closingWindow === window {
                window = nil
            }
            if closingWindow === menuBarManagerWindow {
                menuBarManagerWindow = nil
            }
        }
    }
}
