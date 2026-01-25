//
//  FinderServicesExtension.swift
//  Droppy
//
//  Self-contained definition for Finder Services extension
//

import SwiftUI

struct FinderServicesExtension: ExtensionDefinition {
    static let id = "finder"  // Also matches "finderServices"
    static let title = "Finder Services"
    static let subtitle = "Right-click → Add to Droppy"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .blue
    
    static let description = "Access Droppy directly from Finder's right-click menu. Add selected files to the Shelf or Basket without switching apps."
    
    static let features: [(icon: String, text: String)] = [
        ("cursorarrow.click.2", "Right-click context menu"),
        ("bolt.fill", "Instant integration"),
        ("checkmark.seal.fill", "No extra apps required"),
        ("gearshape", "Configurable in Settings")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/finder-screenshot.png")
    }
    
    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/finder.png")
    }
    
    static let iconPlaceholder = "folder"
    static let iconPlaceholderColor: Color = .blue
    
    // No cleanup needed
}
