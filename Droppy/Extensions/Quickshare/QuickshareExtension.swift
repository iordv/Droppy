//
//  QuickshareExtension.swift
//  Droppy
//
//  Self-contained definition for Droppy Quickshare extension
//

import SwiftUI

struct QuickshareExtension: ExtensionDefinition {
    static let id = "quickshare"
    static let title = "Droppy Quickshare"
    static let subtitle = "Effortless file sharing with 0x0.st"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .cyan
    
    static let description = "Upload files instantly and get shareable links. Powered by 0x0.st (The Null Pointer), Droppy Quickshare focuses on speed, privacy, and simplicity. Files are hosted temporarily with strict retention policies."
    
    static let features: [(icon: String, text: String)] = [
        ("drop.fill", "Instant file upload"),
        ("link", "Automatic link copying"),
        ("clock", "Smart expiration tracking"),
        ("menubar.rectangle", "Menu Bar access")
    ]
    
    // We can use a screenshot from the website if available, or nil for now
    static var screenshotURL: URL? {
        nil
    }
    
    // Use app icon or nil for now
    static var iconURL: URL? {
        nil
    }
    
    static let iconPlaceholder = "drop.fill"
    static let iconPlaceholderColor: Color = .cyan
    
    static func cleanup() {
        // Quickshare is a core extension and handles its own cleanup via QuickshareManager
    }
}
