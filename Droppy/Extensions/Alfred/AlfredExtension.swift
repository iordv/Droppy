//
//  AlfredExtension.swift
//  Droppy
//
//  Self-contained definition for Alfred Workflow extension
//

import SwiftUI

struct AlfredExtension: ExtensionDefinition {
    static let id = "alfred"
    static let title = "Alfred Workflow"
    static let subtitle = "Keyboard-first file management"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .purple
    
    static let description = "Seamlessly add files to Droppy's Shelf or Basket directly from Alfred using keyboard shortcuts."
    
    static let features: [(icon: String, text: String)] = [
        ("keyboard", "Customizable keyboard shortcuts"),
        ("bolt.fill", "Instant file transfer"),
        ("folder.fill", "Works with files and folders"),
        ("arrow.right.circle", "Opens workflow in Alfred")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/alfred-screenshot.png")
    }
    
    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/alfred.png")
    }
    
    static let iconPlaceholder = "command.circle.fill"
    static let iconPlaceholderColor: Color = .purple
    
    // No cleanup needed
}
