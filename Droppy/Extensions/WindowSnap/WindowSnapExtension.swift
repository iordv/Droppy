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
    static let subtitle = "Pointer + keyboard window management"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .blue // Matches blue window icon
    
    static let description = "Snap windows with shortcuts, or move/resize from anywhere with modifier-drag. Includes live snap zones and multi-monitor support."
    
    static let features: [(icon: String, text: String)] = [
        ("keyboard", "Configurable keyboard shortcuts"),
        ("cursorarrow.motionlines", "Modifier-drag move and resize"),
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
