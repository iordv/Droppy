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
    
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    
    var body: some Scene {
        MenuBarExtra("Droppy", image: "MenuBarIcon", isInserted: $showInMenuBar) {
            Button("Check for Updates...") {
                UpdateChecker.shared.checkAndNotify()
            }
            
            Divider()
            
            Button("Settings...") {
                SettingsWindowController.shared.showSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("Quit Droppy") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

/// App delegate to manage application lifecycle and notch window
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Must be stored as property to stay alive (services won't work if deallocated)
    private let serviceProvider = ServiceProvider()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        _ = DragMonitor.shared
        _ = NotchWindowController.shared
        _ = FloatingBasketWindowController.shared
        _ = UpdateChecker.shared
        _ = ClipboardManager.shared
        _ = ClipboardWindowController.shared
        
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
            
            // 2. Clipboard Global Shortcut (Beta)
            // This MUST start even if no windows are visible
            if UserDefaults.standard.bool(forKey: "enableClipboardBeta") {
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
            
            // 4. AirPods Connection Monitor
            // Start if AirPods HUD is enabled
            let airPodsHUDEnabled = UserDefaults.standard.object(forKey: "showAirPodsHUD") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "showAirPodsHUD")
            if airPodsHUDEnabled {
                print("🎧 Droppy: Starting AirPods Connection Monitor")
                AirPodsManager.shared.startMonitoring()
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
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop drag monitoring
        DragMonitor.shared.stopMonitoring()
        
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
