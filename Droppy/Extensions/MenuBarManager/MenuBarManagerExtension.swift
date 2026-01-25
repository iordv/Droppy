//
//  MenuBarManagerExtension.swift
//  Droppy
//
//  Self-contained definition for Menu Bar Manager extension
//

import SwiftUI

struct MenuBarManagerExtension: ExtensionDefinition {
    static let id = "menuBarManager"
    static let title = "Menu Bar Manager"
    static let subtitle = "Clean up your menu bar"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .blue
    
    static let description = "Hide unused menu bar icons and reveal them with a click. Keep your menu bar clean and organized with always-visible, auto-hide, and always-hidden preferences for each icon."
    
    static let features: [(icon: String, text: String)] = [
        ("menubar.rectangle", "Hide/show menu bar icons"),
        ("chevron.left.2", "Click to expand hidden icons"),
        ("eye", "Always visible icons stay put"),
        ("eye.slash", "Always hidden icons stay hidden")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/screenshots/menu-bar-manager.png")
    }
    
    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/menu-bar-manager.jpg")
    }
    
    static let iconPlaceholder = "menubar.rectangle"
    static let iconPlaceholderColor: Color = .blue
    
    static func cleanup() {
        MenuBarManager.shared.cleanup()
    }
}
