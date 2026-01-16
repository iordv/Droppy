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
    
    @State private var showConfirmation = false
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
                // Show confirmation before disabling
                showConfirmation = true
            }
        } label: {
            HStack(spacing: 6) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: isDisabled ? "plus.circle" : "minus.circle")
                        .font(.system(size: 12, weight: .medium))
                }
                Text(buttonText)
            }
            .fontWeight(.medium)
            .foregroundStyle(isDisabled ? .green : .red)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background((isDisabled ? Color.green : Color.red).opacity(isHovering ? 0.25 : 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .onHover { h in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovering = h
            }
        }
        .confirmationDialog(
            "Disable \(extensionType.title)?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disable Extension", role: .destructive) {
                disableExtension()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(disableMessage)
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
        case .aiBackgroundRemoval:
            return "This will uninstall the AI package. You can reinstall it later."
        case .alfred, .finder, .finderServices:
            return "This will disable the integration. You can enable it again later."
        case .ffmpegVideoCompression:
            return "This will disable Video Target Size compression. You can enable it again later."
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

// MARK: - Notification for Extension State Changes

extension Notification.Name {
    static let extensionStateChanged = Notification.Name("extensionStateChanged")
}

#Preview {
    VStack(spacing: 20) {
        DisableExtensionButton(extensionType: .voiceTranscribe)
    }
    .padding()
    .background(Color.black)
}
