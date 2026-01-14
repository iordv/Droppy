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
        case .voiceTranscribe: return "Voice Transcribe"
        }
    }
    
    var subtitle: String {
        switch self {
        case .aiBackgroundRemoval: return "InSPyReNet - State of the Art Quality"
        case .alfred: return "Keyboard-first file management"
        case .finder, .finderServices: return "Right-click → Add to Droppy"
        case .spotify: return "Control playback from your notch"
        case .elementCapture: return "Capture any screen element instantly"
        case .windowSnap: return "Keyboard-driven window management"
        case .voiceTranscribe: return "On-device speech-to-text transcription"
        }
    }
    
    var category: String {
        switch self {
        case .aiBackgroundRemoval: return "AI"
        case .alfred, .finder, .finderServices, .elementCapture, .windowSnap: return "Productivity"
        case .spotify: return "Media"
        case .voiceTranscribe: return "AI"
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
        case .voiceTranscribe: return .blue
        }
    }
    
    var description: String {
        switch self {
        case .aiBackgroundRemoval:
            return "Remove backgrounds from images instantly using local AI processing. No internet connection required."
        case .alfred:
            return "Seamlessly add files to Droppy's Shelf or Basket directly from Alfred using keyboard shortcuts."
        case .finder, .finderServices:
            return "Access Droppy directly from Finder's right-click menu. Add selected files to the Shelf or Basket without switching apps."
        case .spotify:
            return "Control Spotify playback directly from your notch. See album art, track info, and playback controls without switching apps."
        case .elementCapture:
            return "Capture specific screen elements and copy them to clipboard or add to Droppy. Perfect for grabbing UI components, icons, or any visual element."
        case .windowSnap:
            return "Snap windows to halves, quarters, thirds, or full screen with customizable keyboard shortcuts. Multi-monitor support included."
        case .voiceTranscribe:
            return "Transcribe audio recordings to text using WhisperKit AI. 100% on-device processing means your voice never leaves your Mac—completely private."
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
        case .voiceTranscribe:
            return [
                ("mic.fill", "One-tap Quick Record from menu bar"),
                ("cpu", "100% on-device AI processing"),
                ("globe", "99+ languages supported"),
                ("lock.fill", "Private—audio never leaves your Mac")
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
        case .voiceTranscribe:
            return URL(string: baseURL + "voice-transcribe-screenshot.png")
        }
    }
    
    @ViewBuilder
    var iconView: some View {
        switch self {
        case .aiBackgroundRemoval:
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/ai-bg.jpg")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "brain.head.profile").font(.system(size: 32)).foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .alfred:
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/alfred.jpg")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "command.circle.fill").font(.system(size: 32)).foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .finder, .finderServices:
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/finder.jpg")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "folder").font(.system(size: 32)).foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .spotify:
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/spotify.jpg")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "music.note.list").font(.system(size: 32)).foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .elementCapture:
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/element-capture.jpg")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "viewfinder").font(.system(size: 32, weight: .medium)).foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .windowSnap:
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/window-snap.jpg")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "rectangle.split.2x2").font(.system(size: 32, weight: .medium)).foregroundStyle(.cyan)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .voiceTranscribe:
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/voice-transcribe.jpg")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "waveform.and.mic").font(.system(size: 32, weight: .medium)).foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
