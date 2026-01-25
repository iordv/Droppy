//
//  WindowSnapExtension.swift
//  Droppy
//
//  Self-contained definition for Window Snap extension
//

import SwiftUI

struct WindowSnapExtension: ExtensionDefinition {
    static let id = "windowSnap"
    static let title = "Window Snap"
    static let subtitle = "Keyboard-driven window management"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .cyan
    
    static let description = "Snap windows to halves, quarters, thirds, or full screen with customizable keyboard shortcuts. Multi-monitor support included."
    
    static let features: [(icon: String, text: String)] = [
        ("keyboard", "Configurable keyboard shortcuts"),
        ("rectangle.split.2x2", "Halves, quarters, and thirds"),
        ("arrow.up.left.and.arrow.down.right", "Maximize and restore"),
        ("display", "Multi-monitor support")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/window-snap-screenshot.png")
    }
    
    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/window-snap.jpg")
    }
    
    static let iconPlaceholder = "rectangle.split.2x2"
    static let iconPlaceholderColor: Color = .cyan
    
    static func cleanup() {
        WindowSnapManager.shared.cleanup()
    }
}
