//
//  SiriNotchExtension.swift
//  Droppy
//
//  Self-contained definition for Siri Notch extension
//  Display Siri interface in the notch instead of top-right corner
//

import SwiftUI

struct SiriNotchExtension: ExtensionDefinition {
    static let id = "siriNotch"
    static let title = "Siri Notch"
    static let subtitle = "Siri interface in your notch"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .purple

    static let description = "Display a beautiful Siri interface directly in your notch when Siri activates. Features an animated waveform and seamlessly integrates with your notch experience."

    static let features: [(icon: String, text: String)] = [
        ("waveform", "Animated Siri waveform in notch"),
        ("mic.fill", "Siri activation detection"),
        ("eye.slash", "Option to hide system Siri window"),
        ("sparkles", "Beautiful gradient animations")
    ]

    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/siri-notch-screenshot.png")
    }

    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/siri-notch.png")
    }

    static let iconPlaceholder = "waveform.circle.fill"
    static let iconPlaceholderColor: Color = .purple

    static func cleanup() {
        SiriNotchManager.shared.cleanup()
    }
}
