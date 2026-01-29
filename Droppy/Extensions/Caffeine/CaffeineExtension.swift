//
//  CaffeineExtension.swift
//  Droppy
//

import SwiftUI

struct CaffeineExtension: ExtensionDefinition {
    static let id = "caffeine"
    static let title = "Caffeine"
    static let subtitle = "Keep your Mac awake"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .brown
    
    static let description = "Prevent your Mac from going to sleep. Choose indefinite mode or set a timer for hours or minutes. Perfect for downloads, presentations, or long-running tasks."
    
    static let features: [(icon: String, text: String)] = [
        ("cup.and.saucer.fill", "Prevent display and system sleep"),
        ("timer", "Timer presets: hours or minutes"),
        ("infinity", "Indefinite mode until disabled"),
        ("bolt.fill", "Lightweight, no battery drain")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/caffeine-screenshot.png")
    }
    
    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/caffeine.png")
    }
    
    static let iconPlaceholder = "cup.and.saucer.fill"
    static let iconPlaceholderColor: Color = .brown
    
    static func cleanup() {
        CaffeineManager.shared.deactivate()
    }
}
