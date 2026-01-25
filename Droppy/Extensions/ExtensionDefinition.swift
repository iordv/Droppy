//
//  ExtensionDefinition.swift
//  Droppy
//
//  Protocol-based extension system for Single Source of Truth
//  Each extension defines its metadata in one place
//

import SwiftUI

// MARK: - Extension Group (for extension metadata)

/// Category for extension metadata (not to be confused with ExtensionCategory in SettingsPreviewViews)
enum ExtensionGroup: String, CaseIterable {
    case ai = "AI"
    case productivity = "Productivity"
    case media = "Media"
    
    var color: Color {
        switch self {
        case .ai: return .blue
        case .productivity: return .purple
        case .media: return Color(red: 0.12, green: 0.84, blue: 0.38)
        }
    }
}

// MARK: - Extension Definition Protocol

/// Protocol for self-contained extension metadata
/// Each extension implements this in its own folder
protocol ExtensionDefinition {
    /// Unique identifier matching ExtensionType rawValue
    static var id: String { get }
    
    /// Display name shown in Extension Store
    static var title: String { get }
    
    /// Short tagline under title
    static var subtitle: String { get }
    
    /// Category for grouping
    static var category: ExtensionGroup { get }
    
    /// Accent color for the extension card
    static var categoryColor: Color { get }
    
    /// Full description for details view
    static var description: String { get }
    
    /// Feature list with SF Symbol icons
    static var features: [(icon: String, text: String)] { get }
    
    /// URL to screenshot image (loaded from web)
    static var screenshotURL: URL? { get }
    
    /// URL to icon image (loaded from web)
    static var iconURL: URL? { get }
    
    /// Placeholder SF Symbol while icon loads
    static var iconPlaceholder: String { get }
    
    /// Placeholder icon color
    static var iconPlaceholderColor: Color { get }
    
    /// Clean up extension resources when uninstalled
    static func cleanup()
    
    /// Optional SwiftUI view to show instead of screenshot URL
    static var previewView: AnyView? { get }
}

// MARK: - Default Implementations

extension ExtensionDefinition {
    /// Default category color from category
    static var categoryColor: Color { category.color }
    
    /// Default no-op cleanup
    static func cleanup() {}
    
    /// Default placeholder color
    static var iconPlaceholderColor: Color { .blue }
    
    /// Default no preview view (uses screenshotURL instead)
    static var previewView: AnyView? { nil }
}

// MARK: - Extension Registry

/// Singleton registry of all available extensions
/// Provides discovery and lookup by ID
final class ExtensionRegistry {
    static let shared = ExtensionRegistry()
    
    /// All registered extension definitions
    private(set) var definitions: [any ExtensionDefinition.Type] = []
    
    /// Lookup by ID
    private var definitionsByID: [String: any ExtensionDefinition.Type] = [:]
    
    private init() {
        // Register all extensions
        register(AIBackgroundRemovalExtension.self)
        register(AlfredExtension.self)
        register(FinderServicesExtension.self)
        register(SpotifyExtension.self)
        register(ElementCaptureExtension.self)
        register(WindowSnapExtension.self)
        register(VoiceTranscribeExtension.self)
        register(VideoTargetSizeExtension.self)
        register(TermiNotchExtension.self)
        register(MenuBarManagerExtension.self)
        register(QuickshareExtension.self)
    }
    
    /// Register an extension definition
    func register<T: ExtensionDefinition>(_ definition: T.Type) {
        definitions.append(definition)
        definitionsByID[definition.id] = definition
    }
    
    /// Get definition by ID
    func definition(for id: String) -> (any ExtensionDefinition.Type)? {
        definitionsByID[id]
    }
    
    /// Get all definitions in a category
    func definitions(in category: ExtensionGroup) -> [any ExtensionDefinition.Type] {
        definitions.filter { $0.category == category }
    }
}

// MARK: - Icon View Helper

/// Reusable icon view for extension cards
struct ExtensionIconView<T: ExtensionDefinition>: View {
    let definition: T.Type
    var size: CGFloat = 64
    
    var body: some View {
        CachedAsyncImage(url: definition.iconURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Image(systemName: definition.iconPlaceholder)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(definition.iconPlaceholderColor)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }
}
