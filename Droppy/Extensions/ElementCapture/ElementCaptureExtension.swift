//
//  ElementCaptureExtension.swift
//  Droppy
//
//  Self-contained definition for Element Capture extension
//

import SwiftUI

struct ElementCaptureExtension: ExtensionDefinition {
    static let id = "elementCapture"
    static let title = "Element Capture"
    static let subtitle = "Capture any screen element instantly"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .blue
    
    static let description = "Capture specific screen elements and copy them to clipboard or add to Droppy. Perfect for grabbing UI components, icons, or any visual element."
    
    static let features: [(icon: String, text: String)] = [
        ("keyboard", "Configurable keyboard shortcuts"),
        ("rectangle.dashed", "Select screen regions"),
        ("doc.on.clipboard", "Copy to clipboard"),
        ("plus.circle", "Add directly to Droppy")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/element-capture-screenshot.png")
    }
    
    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/element-capture.jpg")
    }
    
    static let iconPlaceholder = "viewfinder"
    static let iconPlaceholderColor: Color = .blue
    
    static func cleanup() {
        ElementCaptureManager.shared.cleanup()
    }
}
