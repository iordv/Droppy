//
//  TermiNotchExtension.swift
//  Droppy
//
//  Self-contained definition for Termi-Notch extension
//

import SwiftUI

struct TermiNotchExtension: ExtensionDefinition {
    static let id = "terminalNotch"
    static let title = "Termi-Notch"
    static let subtitle = "Quick access terminal in your notch"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .green
    
    static let description = "A Quake-style drop-down terminal embedded in your notch. Run quick commands without switching apps, or expand for a full terminal experience."
    
    static let features: [(icon: String, text: String)] = [
        ("terminal", "Full terminal emulation"),
        ("keyboard", "Customizable keyboard shortcut"),
        ("rectangle.expand.vertical", "Quick command & expanded modes"),
        ("arrow.up.forward.app", "Open in your terminal app anytime")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/terminal-notch-screenshot.png")
    }
    
    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/terminotch.jpg")
    }
    
    static let iconPlaceholder = "terminal"
    static let iconPlaceholderColor: Color = .green
    
    static func cleanup() {
        TerminalNotchManager.shared.cleanup()
    }
}
