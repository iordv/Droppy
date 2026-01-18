//
//  IconCache.swift
//  Droppy
//
//  Pre-caches file type icons at app startup to eliminate Metal shader lag on first drop
//

import AppKit
import UniformTypeIdentifiers

/// Pre-caches all common file type icons at app startup
/// This eliminates the Metal shader compilation lag that occurs on first NSWorkspace.icon() call
final class IconCache {
    static let shared = IconCache()
    
    /// Pre-cached icons by UTType identifier
    private var cache: [String: NSImage] = [:]
    
    /// Fallback icon used during cache miss (should never happen after warmup)
    private let fallbackIcon: NSImage
    
    private init() {
        // Create fallback icon FIRST (this is instant - uses system image)
        self.fallbackIcon = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: "File")
            ?? NSImage(named: NSImage.multipleDocumentsName) ?? NSImage()
        
        // Pre-cache ALL common file types at startup
        // This triggers Metal shader compilation NOW, not during first drop
        preloadIcons()
    }
    
    /// Returns cached icon for UTType (instant, no Metal shader compilation)
    func icon(for type: UTType) -> NSImage {
        let key = type.identifier
        if let cached = cache[key] {
            return cached
        }
        
        // Cache miss - load and cache (should only happen for rare file types)
        let icon = NSWorkspace.shared.icon(for: type)
        cache[key] = icon
        return icon
    }
    
    /// Pre-loads icons for all common file types
    /// This is called synchronously during init to ensure completion before UI is ready
    private func preloadIcons() {
        // Comprehensive list of file types users might drop
        let commonTypes: [UTType] = [
            // Generic
            .item, .data, .content, .text, .plainText, .utf8PlainText,
            .rtf, .html, .xml, .json, .yaml,
            
            // Documents
            .pdf, .presentation, .spreadsheet, .database,
            .rtfd, .epub,
            
            // Images
            .image, .jpeg, .png, .gif, .tiff, .bmp, .ico, .icns,
            .heic, .heif, .webP, .svg, .rawImage,
            
            // Audio
            .audio, .mp3, .wav, .aiff, .midi, .m4a,
            
            // Video
            .movie, .video, .mpeg, .mpeg2Video, .mpeg4Movie, .quickTimeMovie, .avi,
            
            // Archives
            .archive, .zip, .gzip, .bz2,
            
            // Code
            .sourceCode, .swiftSource, .cSource, .cPlusPlusSource,
            .objectiveCSource, .javaSource, .script, .shellScript,
            .pythonScript, .rubyScript, .perlScript, .phpScript, .javaScript,
            
            // System
            .folder, .directory, .volume, .application, .bundle,
            .package, .framework, .executable, .aliasFile, .symbolicLink,
            
            // Other
            .url, .fileURL, .bookmark, .vCard, .emailMessage, .calendarEvent,
            .font, .log, .diskImage
        ]
        
        // Load each icon - this triggers Metal shader compilation during startup
        for type in commonTypes {
            cache[type.identifier] = NSWorkspace.shared.icon(for: type)
        }
    }
}
