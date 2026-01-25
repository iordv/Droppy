//
//  AIBackgroundRemovalExtension.swift
//  Droppy
//
//  Self-contained definition for AI Background Removal extension
//

import SwiftUI

struct AIBackgroundRemovalExtension: ExtensionDefinition {
    static let id = "aiBackgroundRemoval"
    static let title = "AI Background Removal"
    static let subtitle = "InSPyReNet - State of the Art Quality"
    static let category: ExtensionGroup = .ai
    static let categoryColor: Color = .blue
    
    static let description = "Remove backgrounds from images instantly using local AI processing. No internet connection required."
    
    static let features: [(icon: String, text: String)] = [
        ("cpu", "Runs entirely on-device"),
        ("lock.shield", "Private—images never leave your Mac"),
        ("bolt.fill", "Fast InSPyReNet AI engine"),
        ("arrow.down.circle", "One-click install")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/ai-bg-screenshot.png")
    }
    
    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/ai-bg.jpg")
    }
    
    static let iconPlaceholder = "brain.head.profile"
    static let iconPlaceholderColor: Color = .blue
    
    static func cleanup() {
        AIInstallManager.shared.cleanup()
    }
}
