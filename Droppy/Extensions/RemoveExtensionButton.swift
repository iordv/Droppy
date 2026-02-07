//
//  DisableExtensionButton.swift
//  Droppy
//
//  Reusable button component for disabling/enabling extensions
//

import SwiftUI

/// A toggle button that disables or enables an extension based on current state
struct DisableExtensionButton: View {
    let extensionType: ExtensionType
    let onStateChanged: (() -> Void)?
    
    @State private var isHovering = false
    @State private var isProcessing = false
    @Environment(\.dismiss) private var dismiss
    
    private var isDisabled: Bool {
        extensionType.isRemoved
    }
    
    init(extensionType: ExtensionType, onStateChanged: (() -> Void)? = nil) {
        self.extensionType = extensionType
        self.onStateChanged = onStateChanged
    }
    
    var body: some View {
        Button {
            if isDisabled {
                // Enable immediately without confirmation
                enableExtension()
            } else {
                // Show confirmation before disabling using native Droppy alert
                showDisableConfirmation()
            }
        } label: {
            HStack(spacing: 4) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: isDisabled ? "plus.circle" : "minus.circle")
                }
                Text(buttonText)
            }
        }
        .buttonStyle(DroppyAccentButtonStyle(color: isDisabled ? .green : .red, size: .small))
        .disabled(isProcessing)
    }
    
    private func showDisableConfirmation() {
        Task { @MainActor in
            let confirmed = await DroppyAlertController.shared.show(
                style: .warning,
                title: "Disable \(extensionType.title)?",
                message: disableMessage,
                primaryButtonTitle: "Disable",
                secondaryButtonTitle: "Cancel"
            )
            if confirmed {
                disableExtension()
            }
        }
    }
    
    private var buttonText: String {
        if isProcessing {
            return isDisabled ? "Enabling..." : "Disabling..."
        }
        return isDisabled ? "Enable" : "Disable"
    }
    
    private var disableMessage: String {
        switch extensionType {
        case .voiceTranscribe:
            return "This will delete the downloaded AI model and all settings. You can reinstall it later."
        case .elementCapture:
            return "This will remove the keyboard shortcut. You can set it up again later."
        case .windowSnap:
            return "This will remove all keyboard shortcuts. You can set them up again later."
        case .spotify:
            return "This will sign out of Spotify and remove connection. You can reconnect later."
        case .appleMusic:
            return "This will disable Apple Music controls. You can enable it again later."
        case .aiBackgroundRemoval:
            return "This will uninstall the AI package. You can reinstall it later."
        case .alfred, .finder, .finderServices:
            return "This will disable the integration. You can enable it again later."
        case .ffmpegVideoCompression:
            return "This will disable Video Target Size compression. You can enable it again later."
        case .terminalNotch:
            return "This will disable the terminal extension. You can enable it again later."
        case .camera:
            return "This will disable Camera and stop the preview. You can enable it again later."
        case .quickshare:
            return "This will disable Quickshare and hide it from menus and quick actions. You can enable it again later."
        case .notificationHUD:
            return "This will stop notification forwarding to your notch. You can enable it again later."
        case .caffeine:
            return "This will disable Caffeine and allow your Mac to sleep normally. You can enable it again later."
        case .menuBarManager:
            return "This will restore all hidden menu bar items and disable the manager. You can enable it again later."
        }
    }
    
    private func disableExtension() {
        isProcessing = true
        
        Task { @MainActor in
            // Run cleanup
            extensionType.cleanup()
            
            // Mark as removed
            extensionType.setRemoved(true)
            
            // Post notification to update UI
            NotificationCenter.default.post(name: .extensionStateChanged, object: extensionType)
            
            // Small delay to show progress
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            isProcessing = false
            
            // Callback
            onStateChanged?()
            
            // Dismiss the sheet
            dismiss()
        }
    }
    private func enableExtension() {
        isProcessing = true
        
        Task { @MainActor in
            // Mark as not removed
            extensionType.setRemoved(false)
            
            // Restart monitoring for extensions that need it
            switch extensionType {
            case .windowSnap:
                WindowSnapManager.shared.loadAndStartMonitoring()
            case .elementCapture:
                ElementCaptureManager.shared.loadAndStartMonitoring()
            case .voiceTranscribe:
                // VoiceTranscribe will need model download, just mark as enabled
                // User needs to reconfigure
                break
            case .spotify:
                // Spotify will auto-refresh when music plays
                SpotifyController.shared.refreshState()
            case .appleMusic:
                // Apple Music will auto-refresh when music plays
                AppleMusicController.shared.refreshState()
            case .notificationHUD:
                // Re-enable notification monitoring
                NotificationHUDManager.shared.startMonitoring()
            case .menuBarManager:
                // Re-enable Menu Bar Manager
                MenuBarManager.shared.enable()
            case .camera:
                break
            default:
                break
            }
            
            // Post notification to update UI
            NotificationCenter.default.post(name: .extensionStateChanged, object: extensionType)
            
            // Small delay to show progress
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            isProcessing = false
            
            // Callback
            onStateChanged?()
            
            // Dismiss the sheet
            dismiss()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DisableExtensionButton(extensionType: .voiceTranscribe)
    }
    .padding()
    .background(Color.black)
}
