//
//  IconCache.swift
//  Droppy
//
//  Provides instant file type icons using SF Symbols to avoid Metal shader lag
//

import AppKit
import UniformTypeIdentifiers

/// Provides instant file type icons using SF Symbols
/// This completely avoids the Metal shader compilation lag from NSWorkspace.icon()
final class IconCache {
    static let shared = IconCache()
    
    /// SF Symbol mapping for common file types
    private let symbolMap: [String: String] = [
        // Generic
        "public.item": "doc.fill",
        "public.data": "doc.fill",
        "public.content": "doc.fill",
        "public.text": "doc.text.fill",
        "public.plain-text": "doc.text.fill",
        
        // Documents
        "com.adobe.pdf": "doc.richtext.fill",
        "public.presentation": "doc.text.fill",
        "public.spreadsheet": "tablecells.fill",
        
        // Images
        "public.image": "photo.fill",
        "public.jpeg": "photo.fill",
        "public.png": "photo.fill",
        "public.gif": "photo.fill",
        "public.heic": "photo.fill",
        "public.tiff": "photo.fill",
        "public.svg-image": "photo.fill",
        
        // Audio
        "public.audio": "waveform.circle.fill",
        "public.mp3": "waveform.circle.fill",
        "com.apple.m4a-audio": "waveform.circle.fill",
        "public.aiff-audio": "waveform.circle.fill",
        
        // Video
        "public.movie": "film.fill",
        "public.video": "film.fill",
        "public.mpeg-4": "film.fill",
        "com.apple.quicktime-movie": "film.fill",
        
        // Archives
        "public.archive": "archivebox.fill",
        "public.zip-archive": "archivebox.fill",
        "org.gnu.gnu-zip-archive": "archivebox.fill",
        
        // Code
        "public.source-code": "chevron.left.forwardslash.chevron.right",
        "public.swift-source": "swift",
        "public.script": "chevron.left.forwardslash.chevron.right",
        "public.shell-script": "terminal.fill",
        
        // System
        "public.folder": "folder.fill",
        "public.directory": "folder.fill",
        "com.apple.application-bundle": "app.fill",
        "public.executable": "gearshape.fill",
        
        // Other
        "public.url": "link",
        "public.vcard": "person.crop.square.fill",
        "public.font": "textformat",
        "public.disk-image": "externaldrive.fill"
    ]
    
    /// Fallback icon
    private let fallbackIcon: NSImage
    
    private init() {
        self.fallbackIcon = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: "File")
            ?? NSImage()
    }
    
    /// Returns an SF Symbol-based icon for the UTType (instant, no Metal shaders)
    func icon(for type: UTType) -> NSImage {
        let key = type.identifier
        
        // Try direct match
        if let symbolName = symbolMap[key],
           let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: type.localizedDescription) {
            return configuredIcon(image)
        }
        
        // Try parent types
        for (typeId, symbolName) in symbolMap {
            if let parentType = UTType(typeId), type.conforms(to: parentType),
               let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: type.localizedDescription) {
                return configuredIcon(image)
            }
        }
        
        return configuredIcon(fallbackIcon)
    }
    
    /// Configures the icon with appropriate size and styling
    private func configuredIcon(_ image: NSImage) -> NSImage {
        // Set a reasonable size for the icon
        image.size = NSSize(width: 64, height: 64)
        return image
    }
}
