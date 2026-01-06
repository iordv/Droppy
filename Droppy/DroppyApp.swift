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
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Touch singletons on main thread to ensure proper @AppStorage / UI initialization
        _ = DroppyState.shared
        _ = DragMonitor.shared
        _ = NotchWindowController.shared
        _ = FloatingBasketWindowController.shared
        _ = UpdateChecker.shared
        _ = ClipboardManager.shared
        _ = ClipboardWindowController.shared
        
        // Pre-load GIFs for Settings after a delay to avoid startup race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            GIFPreloader.shared.preloadAll()
        }
        
        // Start analytics (anonymous launch tracking)
        AnalyticsService.shared.logAppLaunch()
        
        // Start monitoring for drag events (polling-based, safe)
        DragMonitor.shared.startMonitoring()
        
        // Setup UI components on main thread
        DispatchQueue.main.async {
            // 1. Notch Shelf
            let enableNotch = UserDefaults.standard.bool(forKey: "enableNotchShelf")
            let isSet = UserDefaults.standard.object(forKey: "enableNotchShelf") != nil
            if enableNotch || !isSet {
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
            // Default to true if key is not set (matches @AppStorage default in SettingsView)
            let hudEnabled = UserDefaults.standard.object(forKey: "enableHUDReplacement") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "enableHUDReplacement")
            if hudEnabled {
                print("🎛️ Droppy: Starting Media Key Interceptor for HUD")
                MediaKeyInterceptor.shared.start()
            }
        }
        
        // Start background update scheduler (checks once per day)
        UpdateChecker.shared.startBackgroundChecking()
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
}
