//
//  TelepromptyExtension.swift
//  Droppy
//
//  Self-contained definition for Teleprompty extension.
//

import SwiftUI

struct TelepromptyExtension: ExtensionDefinition {
    static let id = "teleprompty"
    static let title = "Teleprompty"
    static let subtitle = "Floating notch teleprompter"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .mint

    static let description = "Adds a floating Teleprompty button under the expanded shelf. Open it to quickly edit your script, then start a live teleprompter that uses your saved speed, font, size, and countdown preferences."

    static let features: [(icon: String, text: String)] = [
        ("text.bubble", "Floating Teleprompty button in expanded shelf"),
        ("slider.horizontal.3", "Adjust speed, font size, width, height, and countdown"),
        ("play.fill", "One-tap start with countdown and smooth scrolling")
    ]

    static let screenshotURL: URL? = nil
    static let previewView: AnyView? = nil

    static let iconURL: URL? = nil
    static let iconPlaceholder: String = "text.bubble"
    static let iconPlaceholderColor: Color = .mint

    static let isCommunity = false

    static func cleanup() {
        TelepromptyManager.shared.cleanup()
    }
}
