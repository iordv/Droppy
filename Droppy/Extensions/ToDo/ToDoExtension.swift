//
//  ToDoExtension.swift
//  Droppy
//
//  Self-contained definition for To-do/Notes extension
//

import SwiftUI

struct ToDoExtension: ExtensionDefinition {
    static let id = "todo"
    static let title = "To-do"
    static let subtitle = "Tasks & Notes"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .blue
    
    static let description = "A lightweight task capture bar and checklist. Supports priorities and auto-cleanup of completed tasks."
    
    static let features: [(icon: String, text: String)] = [
        ("checkmark.circle.fill", "Quick task capture"),
        ("list.bullet", "Priority levels with color coding"),
        ("timer", "Auto-cleanup of completed tasks"),
        ("keyboard", "Keyboard shortcuts for power users")
    ]
    
    static let screenshotURL: URL? = nil
    static let previewView: AnyView? = AnyView(ToDoPreviewView())
    
    static let iconURL: URL? = nil 
    static let iconPlaceholder: String = "checklist"
    static let iconPlaceholderColor: Color = .blue
    
    static func cleanup() {
        // No special cleanup needed beyond what standard persistence handles
    }
}
