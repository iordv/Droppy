//
//  SiriNotchManager.swift
//  Droppy
//
//  Manages Siri detection and notch display state
//

import SwiftUI
import AppKit
import Combine

/// Manages the Siri Notch extension state and Siri detection
@MainActor
class SiriNotchManager: ObservableObject {
    static let shared = SiriNotchManager()

    // MARK: - Published State

    /// Whether the Siri notch is visible
    @Published var isVisible: Bool = false

    /// Whether Siri is actively listening
    @Published var isListening: Bool = false

    /// Detected transcription (if available)
    @Published var transcription: String = ""

    /// Last activation timestamp
    @Published var lastActivationAt: Date = .distantPast

    // MARK: - Settings

    /// Whether extension is installed
    @AppStorage(AppPreferenceKey.siriNotchInstalled) var isInstalled: Bool = PreferenceDefault.siriNotchInstalled

    /// Whether to hide the system Siri window
    @AppStorage(AppPreferenceKey.siriNotchHideSystemWindow) var hideSystemWindow: Bool = PreferenceDefault.siriNotchHideSystemWindow

    // MARK: - Private

    private var appObserver: NSObjectProtocol?
    private var deactivateObserver: NSObjectProtocol?
    private var hasInitialized = false

    private init() {
        // Delay initialization to avoid startup flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.hasInitialized = true
            if self?.isInstalled == true {
                self?.startMonitoring()
            }
        }
    }

    // MARK: - Public Methods

    /// Start monitoring for Siri activation
    func startMonitoring() {
        guard appObserver == nil else { return }

        // Detect Siri app activation
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract app before async context
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.Siri" else { return }
            guard let manager = self else { return }
            Task { @MainActor in
                manager.handleSiriActivation()
            }
        }

        // Also listen for Siri deactivation
        deactivateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract app before async context
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.Siri" else { return }
            guard let manager = self else { return }
            Task { @MainActor in
                manager.handleSiriDeactivation()
            }
        }

        // Listen for Siri-related distributed notifications
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSiriNotification(_:)),
            name: nil,
            object: "com.apple.Siri"
        )
    }

    /// Stop monitoring for Siri
    func stopMonitoring() {
        if let observer = appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appObserver = nil
        }

        if let observer = deactivateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            deactivateObserver = nil
        }

        DistributedNotificationCenter.default().removeObserver(self)
    }

    /// Cleanup when extension is removed
    func cleanup() {
        stopMonitoring()
        isVisible = false
        isListening = false
        transcription = ""
        isInstalled = false

        UserDefaults.standard.removeObject(forKey: AppPreferenceKey.siriNotchHideSystemWindow)
    }

    // MARK: - Private Methods

    private func handleSiriActivation() {
        guard hasInitialized, isInstalled, !ExtensionType.siriNotch.isRemoved else { return }

        lastActivationAt = Date()

        withAnimation(DroppyAnimation.expandOpen) {
            isVisible = true
            isListening = true
        }

        // Expand notch shelf on current screen
        if let screen = NSScreen.main {
            DroppyState.shared.expandShelf(for: screen.displayID)
        }

        // Show HUD through centralized manager
        HUDManager.shared.show(.siri, duration: 10.0)  // Longer duration for Siri interactions

        // Optional: Hide system Siri window
        if hideSystemWindow {
            hideSystemSiriWindow()
        }
    }

    private func handleSiriDeactivation() {
        guard isVisible else { return }

        withAnimation(DroppyAnimation.expandClose) {
            isVisible = false
            isListening = false
            transcription = ""
        }

        // Collapse shelf
        DroppyState.shared.expandedDisplayID = nil

        // Dismiss HUD
        HUDManager.shared.dismiss()
    }

    @objc private func handleSiriNotification(_ notification: Notification) {
        // Handle Siri-specific notifications if available
        // This can provide additional state information
    }

    /// Hide the system Siri window using Accessibility API
    private func hideSystemSiriWindow() {
        guard let siriApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.Siri"
        }) else { return }

        let appElement = AXUIElementCreateApplication(siriApp.processIdentifier)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else { return }

        for window in windows {
            // Move window off-screen
            var position = CGPoint(x: -10000, y: -10000)
            if let positionValue = AXValueCreate(.cgPoint, &position) {
                AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            }
        }
    }
}
