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
    
    /// URL-safe ID for deep links
    case finderServices  // Alias for finder
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .aiBackgroundRemoval: return "AI Background Removal"
        case .alfred: return "Alfred Workflow"
        case .finder, .finderServices: return "Finder Services"
        case .spotify: return "Spotify Integration"
        case .elementCapture: return "Element Capture"
        case .windowSnap: return "Window Snap"
        }
    }
    
    var subtitle: String {
        switch self {
        case .aiBackgroundRemoval: return "One-click install"
        case .alfred: return "Requires Powerpack"
        case .finder, .finderServices: return "One-time setup"
        case .spotify: return "No setup needed"
        case .elementCapture: return "Keyboard shortcuts"
        case .windowSnap: return "Keyboard shortcuts"
        }
    }
    
    var category: String {
        switch self {
        case .aiBackgroundRemoval: return "AI"
        case .alfred, .finder, .finderServices, .elementCapture, .windowSnap: return "Productivity"
        case .spotify: return "Media"
        }
    }
    
    // Colors matching the extension card accent colors
    var categoryColor: Color {
        switch self {
        case .aiBackgroundRemoval: return .pink
        case .alfred: return .purple
        case .finder, .finderServices: return .blue
        case .spotify: return .green
        case .elementCapture: return .orange
        case .windowSnap: return .cyan
        }
    }
    
    var description: String {
        switch self {
        case .aiBackgroundRemoval:
            return "Remove backgrounds from images instantly using local AI. No internet required, your images stay private. One-click install gets you started in seconds."
        case .alfred:
            return "Push any selected file or folder to Droppy instantly with a customizable Alfred hotkey. Perfect for power users who prefer keyboard-driven workflows."
        case .finder, .finderServices:
            return "Right-click any file in Finder to instantly add it to Droppy. No extra apps needed—it's built right into macOS."
        case .spotify:
            return "Control Spotify playback directly from the notch. See album art, track info, and use play/pause controls without switching apps."
        case .elementCapture:
            return "Capture specific screen elements and copy them to clipboard or add to Droppy. Perfect for grabbing UI components, icons, or any visual element."
        case .windowSnap:
            return "Snap windows to screen positions using keyboard shortcuts. Halves, quarters, thirds, maximize, and center—all at your fingertips."
        }
    }
    
    var features: [(icon: String, text: String)] {
        switch self {
        case .aiBackgroundRemoval:
            return [
                ("cpu", "Runs entirely on-device"),
                ("lock.shield", "Private—images never leave your Mac"),
                ("bolt.fill", "Fast InSPyReNet AI engine"),
                ("arrow.down.circle", "One-click install")
            ]
        case .alfred:
            return [
                ("keyboard", "Customizable keyboard shortcuts"),
                ("bolt.fill", "Instant file transfer"),
                ("folder.fill", "Works with files and folders"),
                ("arrow.right.circle", "Opens workflow in Alfred")
            ]
        case .finder, .finderServices:
            return [
                ("cursorarrow.click.2", "Right-click context menu"),
                ("bolt.fill", "Instant integration"),
                ("checkmark.seal.fill", "No extra apps required"),
                ("gearshape", "Configurable in Settings")
            ]
        case .spotify:
            return [
                ("music.note", "Now playing info in notch"),
                ("play.circle.fill", "Playback controls"),
                ("photo.fill", "Album art display"),
                ("link", "Secure OAuth connection")
            ]
        case .elementCapture:
            return [
                ("keyboard", "Configurable keyboard shortcuts"),
                ("rectangle.dashed", "Select screen regions"),
                ("doc.on.clipboard", "Copy to clipboard"),
                ("plus.circle", "Add directly to Droppy")
            ]
        case .windowSnap:
            return [
                ("keyboard", "Configurable keyboard shortcuts"),
                ("rectangle.split.2x2", "Halves, quarters, and thirds"),
                ("arrow.up.left.and.arrow.down.right", "Maximize and restore"),
                ("display", "Multi-monitor support")
            ]
        }
    }
    
    /// Screenshot URL loaded from web (keeps app size minimal)
    var screenshotURL: URL? {
        let baseURL = "https://iordv.github.io/Droppy/assets/images/"
        switch self {
        case .aiBackgroundRemoval:
            return URL(string: baseURL + "ai-bg-screenshot.png")
        case .alfred:
            return URL(string: baseURL + "alfred-screenshot.png")
        case .finder, .finderServices:
            return URL(string: baseURL + "finder-screenshot.png")
        case .spotify:
            return URL(string: baseURL + "spotify-screenshot.jpg")
        case .elementCapture:
            return URL(string: baseURL + "element-capture-screenshot.png")
        case .windowSnap:
            return URL(string: baseURL + "window-snap-screenshot.png")
        }
    }
    
    @ViewBuilder
    var iconView: some View {
        switch self {
        case .aiBackgroundRemoval:
            AIExtensionIcon(size: 64)
        case .alfred:
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.15))
                Image("AlfredIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            }
            .frame(width: 64, height: 64)
        case .finder, .finderServices:
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.15))
                Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            }
            .frame(width: 64, height: 64)
        case .spotify:
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.15))
                Image("SpotifyIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            }
            .frame(width: 64, height: 64)
        case .elementCapture:
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.15))
                Image(systemName: "viewfinder")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.orange)
            }
            .frame(width: 64, height: 64)
        case .windowSnap:
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.15))
                Image(systemName: "rectangle.split.2x2")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 64, height: 64)
        }
    }
}
