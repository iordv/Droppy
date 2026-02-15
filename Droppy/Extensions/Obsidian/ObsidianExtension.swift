//
//  ObsidianExtension.swift
//  Droppy
//
//  Self-contained definition for Obsidian integration extension
//

import SwiftUI

struct ObsidianExtension: ExtensionDefinition {
    static let id = "obsidian"
    static let title = "Obsidian"
    static let subtitle = "Quick notes & append"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .purple

    static let description = "Pin vault notes to the notch shelf for quick append/prepend under specific headings. Supports CLI and filesystem backends, syntax highlighting, and global hotkey access."

    static let features: [(icon: String, text: String)] = [
        ("book.pages", "Pin notes for instant access"),
        ("text.append", "Append or prepend under headings"),
        ("keyboard", "Global hotkey to activate"),
        ("doc.text.magnifyingglass", "Syntax-highlighted full editor"),
        ("terminal", "CLI or filesystem backend")
    ]

    static let screenshotURL: URL? = nil
    static let previewView: AnyView? = AnyView(ObsidianPreviewView())

    static let iconURL: URL? = nil
    static let iconPlaceholder: String = "book.pages"
    static let iconPlaceholderColor: Color = .purple

    static func cleanup() {
        ObsidianManager.shared.cleanup()
    }
}
