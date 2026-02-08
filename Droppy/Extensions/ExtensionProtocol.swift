//
//  ExtensionProtocol.swift
//  Droppy
//
//  Shared types and protocols for the extension system
//

import SwiftUI
import AppKit

// MARK: - Extension Type

enum ExtensionType: String, CaseIterable, Identifiable {
    case aiBackgroundRemoval
    case alfred
    case finder
    case spotify
    case elementCapture
    case windowSnap
    case voiceTranscribe
    case ffmpegVideoCompression
    case terminalNotch
    case camera
    case quickshare
    case appleMusic
    case notificationHUD
    case caffeine
    case menuBarManager
    case todo

    /// URL-safe ID for deep links
    case finderServices  // Alias for finder
    
    var id: String { rawValue }
    
    /// Get the corresponding ExtensionDefinition from the registry
    private var definition: (any ExtensionDefinition.Type)? {
        let lookupID = (self == .finderServices) ? "finder" : rawValue
        return ExtensionRegistry.shared.definition(for: lookupID)
    }
    
    var title: String {
        definition?.title ?? rawValue.capitalized
    }
    
    var subtitle: String {
        definition?.subtitle ?? ""
    }

    /// Whether the extension has been installed/configured enough to be considered available.
    /// This drives UI labeling for "Set Up" vs "Manage" and toggle availability.
    var isInstalledInSystem: Bool {
        switch self {
        case .aiBackgroundRemoval:
            return AIInstallManager.shared.isInstalled
        case .alfred:
            return UserDefaults.standard.bool(forKey: "alfredTracked")
        case .finder, .finderServices:
            return UserDefaults.standard.bool(forKey: "finderTracked")
        case .spotify:
            return UserDefaults.standard.bool(forKey: "spotifyTracked")
        case .appleMusic:
            return !isRemoved
        case .elementCapture:
            return UserDefaults.standard.data(forKey: "elementCaptureShortcut") != nil
        case .windowSnap:
            return !WindowSnapManager.shared.shortcuts.isEmpty || WindowSnapManager.shared.pointerModeEnabled
        case .voiceTranscribe:
            return VoiceTranscribeManager.shared.isModelDownloaded
        case .ffmpegVideoCompression:
            return FFmpegInstallManager.shared.isInstalled
        case .terminalNotch:
            return TerminalNotchManager.shared.isInstalled
        case .camera:
            return UserDefaults.standard.bool(forKey: AppPreferenceKey.cameraInstalled)
        case .quickshare:
            return !isRemoved
        case .notificationHUD:
            return UserDefaults.standard.bool(forKey: AppPreferenceKey.notificationHUDInstalled)
        case .caffeine:
            return UserDefaults.standard.bool(forKey: AppPreferenceKey.caffeineInstalled)
        case .menuBarManager:
            return MenuBarManager.shared.isEnabled
        case .todo:
            return UserDefaults.standard.bool(forKey: AppPreferenceKey.todoInstalled)
        }
    }
    
    var category: String {
        definition?.category.rawValue ?? "Other"
    }
    
    var categoryColor: Color {
        definition?.categoryColor ?? .gray
    }
    
    var description: String {
        definition?.description ?? ""
    }
    
    var features: [(icon: String, text: String)] {
        definition?.features ?? []
    }
    
    /// Screenshot URL loaded from web (keeps app size minimal)
    var screenshotURL: URL? {
        definition?.screenshotURL
    }
    
    /// Optional SwiftUI preview view to use instead of screenshot URL
    var previewView: AnyView? {
        definition?.previewView
    }
    
    @ViewBuilder
    var iconView: some View {
        if let def = definition {
            CachedAsyncImage(url: def.iconURL) { image in
                image.droppyExtensionIcon(contentMode: .fill)
            } placeholder: {
                Image(systemName: def.iconPlaceholder)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(def.iconPlaceholderColor)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
        } else {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 32))
                .foregroundStyle(.gray)
                .frame(width: 64, height: 64)
        }
    }
    
    // MARK: - Removed State
    
    /// UserDefaults key for removed state
    private var removedKey: String { "extension_removed_\(rawValue)" }
    
    /// Check if this extension has been removed by the user
    var isRemoved: Bool {
        return UserDefaults.standard.bool(forKey: removedKey)
    }
    
    /// Set the removed state for this extension
    func setRemoved(_ removed: Bool) {
        UserDefaults.standard.set(removed, forKey: removedKey)
    }
    
    /// Clean up all resources associated with this extension
    /// Called when user removes the extension
    func cleanup() {
        definition?.cleanup()
    }
}
