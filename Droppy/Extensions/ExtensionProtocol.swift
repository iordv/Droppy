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
        case .aiBackgroundRemoval: return .blue
        case .alfred: return .blue
        case .finder, .finderServices: return .blue
        case .spotify: return .blue
        case .elementCapture: return .blue
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
            AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/ai-bg.jpg")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "brain.head.profile").font(.system(size: 32)).foregroundStyle(.blue)
                default:
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.2))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .alfred:
            AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/alfred.jpg")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "command.circle.fill").font(.system(size: 32)).foregroundStyle(.blue)
                default:
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.2))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .finder, .finderServices:
            AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/finder.jpg")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "folder").font(.system(size: 32)).foregroundStyle(.blue)
                default:
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.2))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .spotify:
            AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/spotify.jpg")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "music.note.list").font(.system(size: 32)).foregroundStyle(.blue)
                default:
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.2))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .elementCapture:
            AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/element-capture.jpg")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "viewfinder").font(.system(size: 32, weight: .medium)).foregroundStyle(.blue)
                default:
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.2))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .windowSnap:
            AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/window-snap.jpg")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "rectangle.split.2x2").font(.system(size: 32, weight: .medium)).foregroundStyle(.cyan)
                default:
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.2))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
