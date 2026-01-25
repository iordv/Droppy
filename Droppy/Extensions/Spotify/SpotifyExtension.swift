//
//  SpotifyExtension.swift
//  Droppy
//
//  Self-contained definition for Spotify Integration extension
//

import SwiftUI

struct SpotifyExtension: ExtensionDefinition {
    static let id = "spotify"
    static let title = "Spotify Integration"
    static let subtitle = "Control playback from your notch"
    static let category: ExtensionGroup = .media
    static let categoryColor = Color(red: 0.12, green: 0.84, blue: 0.38) // Spotify green
    
    static let description = "Control Spotify playback directly from your notch. See album art, track info, and playback controls without switching apps."
    
    static let features: [(icon: String, text: String)] = [
        ("music.note", "Now playing info in notch"),
        ("play.circle.fill", "Playback controls"),
        ("photo.fill", "Album art display"),
        ("link", "Secure OAuth connection")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/spotify-screenshot.jpg")
    }
    
    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/spotify.png")
    }
    
    static let iconPlaceholder = "music.note.list"
    static let iconPlaceholderColor = Color(red: 0.12, green: 0.84, blue: 0.38)
    
    static func cleanup() {
        SpotifyAuthManager.shared.cleanup()
    }
}
