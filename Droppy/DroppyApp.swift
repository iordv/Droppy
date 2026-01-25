//
//  DroppyApp.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

/// Main application entry point for Droppy
@main
struct DroppyApp: App {
    /// App delegate for handling app lifecycle and notch window setup
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage(AppPreferenceKey.showInMenuBar) private var showInMenuBar = PreferenceDefault.showInMenuBar
    @AppStorage(AppPreferenceKey.showQuickshareInMenuBar) private var showQuickshareInMenuBar = PreferenceDefault.showQuickshareInMenuBar
    
    var body: some Scene {
        MenuBarExtra("Droppy", image: "MenuBarIcon", isInserted: $showInMenuBar) {
            DroppyMenuContent()
        }
    }
}

/// Menu content with Element Capture (shows configured shortcut)
struct DroppyMenuContent: View {
    // Track shortcut changes via notification
    @State private var shortcutRefreshId = UUID()
    
    // Observe NotchWindowController for hide state
    @ObservedObject private var notchController = NotchWindowController.shared
    
    // Check if shelf is enabled (to conditionally show hide/show option)
    @AppStorage(AppPreferenceKey.enableNotchShelf) private var enableNotchShelf = PreferenceDefault.enableNotchShelf
    
    // Check if Quickshare menu bar is enabled
    @AppStorage(AppPreferenceKey.showQuickshareInMenuBar) private var showQuickshareInMenuBar = PreferenceDefault.showQuickshareInMenuBar
    
    // Check if extensions are disabled
    private var isElementCaptureDisabled: Bool {
        _ = shortcutRefreshId // Force refresh
        return ExtensionType.elementCapture.isRemoved
    }
    
    private var isWindowSnapDisabled: Bool {
        _ = shortcutRefreshId // Force refresh
        return ExtensionType.windowSnap.isRemoved
    }
    
    private var isMenuBarManagerDisabled: Bool {
        _ = shortcutRefreshId // Force refresh
        return ExtensionType.menuBarManager.isRemoved
    }
    
    private var isMenuBarManagerEnabled: Bool {
        _ = shortcutRefreshId // Force refresh
        return MenuBarManager.shared.isEnabled
    }
    
    private var isMenuBarManagerExpanded: Bool {
        _ = shortcutRefreshId // Force refresh
        return MenuBarManager.shared.isExpanded
    }
    
    // Load saved shortcut for native keyboard shortcut display
    private var savedShortcut: SavedShortcut? {
        // Force re-evaluation when shortcutRefreshId changes
        _ = shortcutRefreshId
        if let data = UserDefaults.standard.data(forKey: "elementCaptureShortcut"),
           let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            return decoded
        }
        return nil
    }
    
    var body: some View {
        // Show/Hide Notch or Dynamic Island toggle (only when shelf is enabled)
        if enableNotchShelf {
            if notchController.isTemporarilyHidden {
                Button {
                    notchController.setTemporarilyHidden(false)
                } label: {
                    Label("Show \(notchController.displayModeLabel)", systemImage: "eye")
                }
            } else {
                Button {
                    notchController.setTemporarilyHidden(true)
                } label: {
                    Label("Hide \(notchController.displayModeLabel)", systemImage: "eye.slash")
                }
            }
            
            Divider()
        }
        
        Button {
            UpdateChecker.shared.checkAndNotify()
        } label: {
            Label("Check for Updates...", systemImage: "arrow.clockwise")
        }
        
        Divider()
        
        if showQuickshareInMenuBar {
            Menu {
                QuickshareMenuContent()
            } label: {
                Label("Quickshare", systemImage: "drop.fill")
            }
        }
        
        // Element Capture with native keyboard shortcut styling (hidden when disabled)
        if !isElementCaptureDisabled {
            elementCaptureButton
                .id(shortcutRefreshId)  // Force rebuild when shortcut changes
        }
        
        // Window Snap submenu with quick actions (hidden when disabled)
        if !isWindowSnapDisabled {
            Menu {
                Button {
                    WindowSnapManager.shared.executeAction(.leftHalf)
                } label: {
                    Label("Left Half", systemImage: "rectangle.lefthalf.filled")
                }
                Button {
                    WindowSnapManager.shared.executeAction(.rightHalf)
                } label: {
                    Label("Right Half", systemImage: "rectangle.righthalf.filled")
                }
                Button {
                    WindowSnapManager.shared.executeAction(.maximize)
                } label: {
                    Label("Maximize", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                Button {
                    WindowSnapManager.shared.executeAction(.center)
                } label: {
                    Label("Center", systemImage: "rectangle.center.inset.filled")
                }
                Divider()
                Button {
                    SettingsWindowController.shared.showSettings(openingExtension: .windowSnap)
                } label: {
                    Label("Configure Shortcuts...", systemImage: "keyboard")
                }
            } label: {
                Label("Window Snap", systemImage: "rectangle.split.2x1")
            }
        }
        
        // Menu Bar Manager submenu (hidden when disabled)
        if !isMenuBarManagerDisabled && isMenuBarManagerEnabled {
            Menu {
                Button {
                    MenuBarManager.shared.toggleExpanded()
                } label: {
                    Label(isMenuBarManagerExpanded ? "Hide Icons" : "Show Icons", systemImage: isMenuBarManagerExpanded ? "eye.slash" : "eye")
                }
                Divider()
                Button {
                    SettingsWindowController.shared.showSettings(openingExtension: .menuBarManager)
                } label: {
                    Label("Configure...", systemImage: "gear")
                }
            } label: {
                Label("Menu Bar Manager", systemImage: "menubar.rectangle")
            }
        }
        
        Divider()
        
        Button {
            SettingsWindowController.shared.showSettings()
        } label: {
            Label("Settings...", systemImage: "gear")
        }
        .keyboardShortcut(",", modifiers: .command)
        
        Divider()
        
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit Droppy", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
        .onReceive(NotificationCenter.default.publisher(for: .elementCaptureShortcutChanged)) { _ in
            shortcutRefreshId = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowSnapShortcutChanged)) { _ in
            shortcutRefreshId = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .extensionStateChanged)) { _ in
            // Refresh when extension is disabled/enabled
            shortcutRefreshId = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuBarManagerStateChanged)) { _ in
            // Refresh when Menu Bar Manager state changes
            shortcutRefreshId = UUID()
        }
    }
    
    @ViewBuilder
    private var elementCaptureButton: some View {
        if let shortcut = savedShortcut, let key = shortcut.keyEquivalent {
            Button {
                ElementCaptureManager.shared.startCaptureMode()
            } label: {
                Label("Element Capture", systemImage: "viewfinder")
            }
            .keyboardShortcut(key, modifiers: shortcut.eventModifiers)
        } else {
            Button {
                ElementCaptureManager.shared.startCaptureMode()
            } label: {
                Label("Element Capture", systemImage: "viewfinder")
            }
        }
    }
}

/// App delegate to manage application lifecycle and notch window
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Must be stored as property to stay alive (services won't work if deallocated)
    private let serviceProvider = ServiceProvider()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // DEBUG: Force clear permission cache to diagnose stuck cache issue
        #if DEBUG
        print("🔐 DEBUG: Force clearing permission cache at launch")
        UserDefaults.standard.removeObject(forKey: "accessibilityGranted")
        UserDefaults.standard.removeObject(forKey: "screenRecordingGranted")
        UserDefaults.standard.removeObject(forKey: "inputMonitoringGranted")
        UserDefaults.standard.synchronize()
        #endif
        
        // Crash detection: Check if last session crashed and offer to report
        CrashReporter.shared.checkForCrashAndPrompt()
        
        // Crash detection: Mark this session as started (will be cleared on clean exit)
        CrashReporter.shared.markSessionStarted()
        
        // MIGRATION (Issue #57): Re-enable menu bar for users who locked themselves out
        // This runs once per user to unlock anyone who disabled the menu bar before this fix
        if !UserDefaults.standard.bool(forKey: "didMigrateMenuBarLockout") {
            UserDefaults.standard.set(true, forKey: "didMigrateMenuBarLockout")
            // If menu bar was hidden, re-enable it to prevent lock-out
            if !UserDefaults.standard.bool(forKey: "showInMenuBar") {
                UserDefaults.standard.set(true, forKey: "showInMenuBar")
                print("🔓 Droppy: Re-enabled menu bar icon (Issue #57 migration)")
            }
        }
        
        
        // Set as accessory app (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Register Finder Services (right-click menu integration)
        // Note: User must manually enable in System Settings > Keyboard > Keyboard Shortcuts > Services
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()  // Refresh Services cache so menu items appear in the list
        
        // Register for URL scheme events (droppy://)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        
        // Touch singletons on main thread to ensure proper @AppStorage / UI initialization
        _ = DroppyState.shared
        DroppyState.shared.restorePinnedFolders()  // Restore pinned folders from previous session
        _ = DragMonitor.shared
        _ = NotchWindowController.shared
        _ = FloatingBasketWindowController.shared
        _ = UpdateChecker.shared
        _ = ClipboardManager.shared
        _ = ClipboardWindowController.shared
        _ = ThumbnailCache.shared  // Warmup QuickLook Metal shaders early
        
        // Load Element Capture and Window Snap shortcuts (after all other singletons are ready)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ElementCaptureManager.shared.loadAndStartMonitoring()
            WindowSnapManager.shared.loadAndStartMonitoring()
            
            // Initialize Voice Transcribe (restores menu bar if it was enabled)
            _ = VoiceTranscribeManager.shared
            
            // Initialize Menu Bar Manager (restores state if it was enabled)
            _ = MenuBarManager.shared
        }
        
        // Start analytics (anonymous launch tracking)
        AnalyticsService.shared.logAppLaunch()
        
        // Start monitoring for drag events (polling-based, safe)
        DragMonitor.shared.startMonitoring()
        
        // Setup UI components on main thread
        DispatchQueue.main.async {
            // 1. Notch Window (needed for Shelf, HUD replacement, and Media Player)
            // The notch window is required for any of these features to work
            let enableNotch = UserDefaults.standard.bool(forKey: "enableNotchShelf")
            let notchIsSet = UserDefaults.standard.object(forKey: "enableNotchShelf") != nil
            let notchShelfEnabled = enableNotch || !notchIsSet  // Default true
            
            let hudEnabled = UserDefaults.standard.object(forKey: "enableHUDReplacement") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "enableHUDReplacement")
            
            let mediaEnabled = UserDefaults.standard.object(forKey: "showMediaPlayer") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "showMediaPlayer")
            
            // Create notch window if ANY of these features are enabled
            if notchShelfEnabled || hudEnabled || mediaEnabled {
                NotchWindowController.shared.setupNotchWindow()
            }
            
            // 2. Clipboard Global Shortcut
            // This MUST start even if no windows are visible
            // Default to enabled if key not set
            let clipboardEnabled = UserDefaults.standard.object(forKey: "enableClipboardBeta") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "enableClipboardBeta")
            if clipboardEnabled {
                print("⌨️ Droppy: Starting Global Clipboard Monitor")
                ClipboardWindowController.shared.startMonitoringShortcut()
            }
            
            // 3. Media Key Interceptor for HUD replacement
            // Start if HUD replacement is enabled to suppress system HUD
            // (hudEnabled already calculated above)
            if hudEnabled {
                print("🎛️ Droppy: Starting Media Key Interceptor for HUD")
                MediaKeyInterceptor.shared.start()
            }
            
            // 4. AirPods HUD monitoring (Bluetooth connection detection)
            let airPodsEnabled = UserDefaults.standard.object(forKey: "enableAirPodsHUD") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "enableAirPodsHUD")
            if airPodsEnabled {
                print("🎧 Droppy: Starting AirPods Connection Monitor")
                AirPodsManager.shared.startMonitoring()
            }
            
            // 5. Tracked Folders (monitors folders for new files)
            let folderObservationEnabled = UserDefaults.standard.bool(forKey: AppPreferenceKey.enableTrackedFolders)
            if folderObservationEnabled {
                print("📁 Droppy: Starting Tracked Folders Monitor")
                TrackedFoldersManager.shared.startMonitoring()
            }
            
            // 6. AUTO-PROMPT FOR PERMISSIONS
            // If any accessibility-dependent feature is enabled but permission not granted, prompt
            let needsAccessibility = hudEnabled || clipboardEnabled
            let axTrusted = AXIsProcessTrusted()
            let cacheValue = UserDefaults.standard.bool(forKey: "accessibilityGranted")
            let isGranted = PermissionManager.shared.isAccessibilityGranted
            
            print("🔐 DEBUG: needsAccessibility=\(needsAccessibility) hudEnabled=\(hudEnabled) clipboardEnabled=\(clipboardEnabled)")
            print("🔐 DEBUG: AXIsProcessTrusted()=\(axTrusted) cache=\(cacheValue) isGranted=\(isGranted)")
            
            if needsAccessibility && !isGranted {
                print("🔐 Droppy: Accessibility needed for enabled features - prompting...")
                PermissionManager.shared.requestAccessibility()
            } else {
                print("🔐 DEBUG: NOT prompting - needsAccessibility=\(needsAccessibility) isGranted=\(isGranted)")
            }
        }
        
        // Start background update scheduler (checks once per day)
        UpdateChecker.shared.startBackgroundChecking()
        
        // Show onboarding wizard for first-time users
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                OnboardingWindowController.shared.show()
            }
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Poll for accessibility permission in case user just returned from System Settings
        // This handles the "TCC delay" where permission is granted but system API returns false for a few seconds
        PermissionManager.shared.startPollingForAccessibility()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Mark clean exit (no crash prompt on next launch)
        CrashReporter.shared.markCleanExit()
        
        // Stop drag monitoring
        DragMonitor.shared.stopMonitoring()
        
        // Stop AirPods monitoring
        AirPodsManager.shared.stopMonitoring()
        
        // Close notch window
        NotchWindowController.shared.closeWindow()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // Prevent app from closing when the settings window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - URL Scheme Handling
    
    /// Handles incoming droppy:// URL events from Alfred and other apps
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            print("⚠️ AppDelegate: Failed to parse URL from event")
            return
        }
        
        // Route to URLSchemeHandler
        URLSchemeHandler.handle(url)
    }
}
