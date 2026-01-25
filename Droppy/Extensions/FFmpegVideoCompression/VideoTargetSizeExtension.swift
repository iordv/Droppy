//
//  VideoTargetSizeExtension.swift
//  Droppy
//
//  Self-contained definition for Video Target Size (FFmpeg) extension
//

import SwiftUI

struct VideoTargetSizeExtension: ExtensionDefinition {
    static let id = "ffmpegVideoCompression"
    static let title = "Video Target Size"
    static let subtitle = "Compress videos to exact file sizes"
    static let category: ExtensionGroup = .media
    static let categoryColor = Color(red: 0.0, green: 0.5, blue: 0.25) // Dark green
    
    static let description = "Compress videos to exact file sizes using FFmpeg two-pass encoding. Perfect for file size limits on Discord, email, or social media."
    
    static let features: [(icon: String, text: String)] = [
        ("target", "Exact file size targeting"),
        ("film", "Two-pass encoding for accuracy"),
        ("arrow.down.circle", "One-time FFmpeg install"),
        ("bolt.fill", "Fast H.264/AAC processing")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/video-target-size-screenshot.png")
    }
    
    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/video-target-size.png")
    }
    
    static let iconPlaceholder = "film"
    static let iconPlaceholderColor: Color = .orange
    
    static func cleanup() {
        FFmpegInstallManager.shared.cleanup()
    }
}
