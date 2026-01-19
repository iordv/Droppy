//
//  ThumbnailCache.swift
//  Droppy
//
//  Created by Droppy on 07/01/2026.
//  Memory-efficient thumbnail caching for clipboard images
//

import AppKit
import Foundation
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// Centralized cache for clipboard image thumbnails
/// Uses NSCache for automatic memory pressure eviction
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    
    /// Size for list row thumbnails (32x32 displayed, 64x64 for Retina)
    private let thumbnailSize = CGSize(width: 64, height: 64)
    
    /// NSCache automatically evicts under memory pressure
    private let cache = NSCache<NSString, NSImage>()
    
    /// Separate cache for DroppedItem thumbnails (file-based)
    private let fileCache = NSCache<NSString, NSImage>()
    
    /// Cache for system icons (very fast lookup)
    private let iconCache = NSCache<NSString, NSImage>()
    
    private init() {
        // Limit cache to ~50 thumbnails (each ~16KB = ~800KB max)
        cache.countLimit = 50
        cache.totalCostLimit = 1024 * 1024 // 1MB max
        
        // File thumbnails cache
        fileCache.countLimit = 100
        fileCache.totalCostLimit = 2 * 1024 * 1024 // 2MB max
        
        // Icon cache (very small, just file icons)
        iconCache.countLimit = 200
        iconCache.totalCostLimit = 512 * 1024 // 512KB max
        
        // NOTE: No synchronous warmup needed - DroppedItem uses placeholder icons
        // and real icons load asynchronously via loadThumbnailAsync()
    }
    
    /// Warms up the icon rendering system to preload Metal shaders
    /// This eliminates the ~1 second lag on first file drop by forcing the
    /// IconRendering.framework Metal shaders to load during app startup
    private func warmupQuickLook() {
        // 1. SYNCHRONOUS: Warmup NSWorkspace icon rendering AND cache by UTType
        let commonTypes: [UTType] = [
            .image, .pdf, .plainText, .data, .folder, .application,
            .jpeg, .png, .gif, .movie, .mp3, .zip, .audio, .video,
            .html, .json, .xml, .sourceCode, .swiftSource, .text,
            .rtf, .archive, .diskImage, .executable, .bundle, .package
        ]
        
        // Pre-cache icons AND force GPU rendering to trigger Metal shader compilation DURING startup
        for type in commonTypes {
            let icon = NSWorkspace.shared.icon(for: type)
            let cacheKey = type.identifier as NSString
            iconCache.setObject(icon, forKey: cacheKey, cost: 4096)
            forceGPURender(icon)
        }
        
        // Also warmup file-based icon (different code path)
        let testIcon = NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Terminal.app")
        forceGPURender(testIcon)
        
        // 2. SYNCHRONOUS: Warmup QuickLook with MULTIPLE file types
        let warmupPaths = [
            "/System/Applications/Utilities/Terminal.app",
            "/System/Library/Desktop Pictures/Sequoia.heic",
            "/System/Library/CoreServices/Finder.app",
            NSHomeDirectory()
        ]
        
        let semaphore = DispatchSemaphore(value: 0)
        var completed = 0
        let total = warmupPaths.count
        
        for path in warmupPaths {
            Task(priority: .userInitiated) {
                let url = URL(fileURLWithPath: path)
                let request = QLThumbnailGenerator.Request(
                    fileAt: url,
                    size: CGSize(width: 64, height: 64),
                    scale: 2.0,
                    representationTypes: .all
                )
                if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                    // Force GPU render the QuickLook thumbnail too
                    await MainActor.run {
                        self.forceGPURender(rep.nsImage)
                    }
                }
                completed += 1
                if completed >= total {
                    semaphore.signal()
                }
            }
        }
        _ = semaphore.wait(timeout: .now() + 5.0)
    }
    
    /// Forces an NSImage to be rendered to GPU, triggering Metal shader compilation
    private func forceGPURender(_ image: NSImage) {
        guard image.size.width > 0 else { return }
        let size = NSSize(width: 32, height: 32)
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let bitmap = bitmap else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
    }
    
    /// Get or create a thumbnail for the given clipboard item
    /// Returns nil if item has no image data
    func thumbnail(for item: ClipboardItem) -> NSImage? {
        guard item.type == .image else { return nil }
        
        let cacheKey = item.id.uuidString as NSString
        
        // Check cache first
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        // Load image data (lazy - from file or legacy inline data)
        guard let imageData = item.loadImageData() else {
            return nil
        }
        
        // Generate thumbnail synchronously (called from main thread, should be fast)
        guard let thumbnail = generateThumbnail(from: imageData) else {
            return nil
        }
        
        // Store in cache with estimated cost (bytes)
        let estimatedCost = Int(thumbnailSize.width * thumbnailSize.height * 4)
        cache.setObject(thumbnail, forKey: cacheKey, cost: estimatedCost)
        
        return thumbnail
    }
    
    /// Get cached thumbnail for DroppedItem (returns nil if not cached, use async version to load)
    func cachedThumbnail(for item: DroppedItem) -> NSImage? {
        let cacheKey = item.id.uuidString as NSString
        return fileCache.object(forKey: cacheKey)
    }
    
    /// Async load thumbnail for DroppedItem and cache it
    func loadThumbnailAsync(for item: DroppedItem, size: CGSize = CGSize(width: 120, height: 120)) async -> NSImage? {
        let cacheKey = item.id.uuidString as NSString
        
        // Check cache first
        if let cached = fileCache.object(forKey: cacheKey) {
            return cached
        }
        
        // Generate async using QuickLook
        if let thumbnail = await item.generateThumbnail(size: size) {
            let estimatedCost = Int(size.width * size.height * 4)
            fileCache.setObject(thumbnail, forKey: cacheKey, cost: estimatedCost)
            return thumbnail
        }
        
        return item.icon
    }
    
    /// Get system icon for a file path (cached, very fast)
    func cachedIcon(forPath path: String) -> NSImage {
        let cacheKey = path as NSString
        
        if let cached = iconCache.object(forKey: cacheKey) {
            return cached
        }
        
        let icon = NSWorkspace.shared.icon(forFile: path)
        iconCache.setObject(icon, forKey: cacheKey, cost: 4096) // ~4KB per icon
        return icon
    }
    
    /// Get pre-warmed icon for UTType (avoids Metal shader compilation lag)
    /// Icons are pre-cached during app startup in warmupQuickLook()
    func cachedIconForType(_ type: UTType) -> NSImage {
        let cacheKey = type.identifier as NSString
        
        // Return pre-cached icon if available (most common types are pre-warmed)
        if let cached = iconCache.object(forKey: cacheKey) {
            return cached
        }
        
        // Fallback: load and cache (may trigger Metal compilation, but rare)
        let icon = NSWorkspace.shared.icon(for: type)
        iconCache.setObject(icon, forKey: cacheKey, cost: 4096)
        return icon
    }
    
    /// Generate a scaled-down thumbnail from image data
    private func generateThumbnail(from data: Data) -> NSImage? {
        guard let originalImage = NSImage(data: data) else { return nil }
        
        let originalSize = originalImage.size
        guard originalSize.width > 0 && originalSize.height > 0 else { return nil }
        
        // Calculate aspect-fit size
        let widthRatio = thumbnailSize.width / originalSize.width
        let heightRatio = thumbnailSize.height / originalSize.height
        let scale = min(widthRatio, heightRatio, 1.0) // Don't upscale small images
        
        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
        
        // Create thumbnail
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        originalImage.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        thumbnail.unlockFocus()
        
        return thumbnail
    }
    
    /// Clear a specific item from cache (e.g., when deleted)
    func invalidate(itemId: UUID) {
        cache.removeObject(forKey: itemId.uuidString as NSString)
        fileCache.removeObject(forKey: itemId.uuidString as NSString)
    }
    
    /// Clear entire cache (e.g., on memory warning)
    func clearAll() {
        cache.removeAllObjects()
        fileCache.removeAllObjects()
        iconCache.removeAllObjects()
    }
}
