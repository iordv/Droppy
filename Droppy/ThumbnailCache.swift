//
//  ThumbnailCache.swift
//  Droppy
//
//  Created by Droppy on 07/01/2026.
//  Memory-efficient thumbnail caching for clipboard images
//

import AppKit
import SwiftUI
import Foundation
import ImageIO
import PDFKit
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
    
    /// Cache for multi-page document previews (PDFs, Office docs)
    private let pageCache = NSCache<NSString, NSImage>()
    
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
        
        // Page cache for multi-page documents (PDFs, Office docs)
        pageCache.countLimit = 50
        pageCache.totalCostLimit = 4 * 1024 * 1024 // 4MB max
        
        // CRITICAL: Warmup QuickLook and Metal shaders on background thread during startup
        // This eliminates the ~1 second lag on first file drop by forcing Metal shader compilation now
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.warmupQuickLook()
        }
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
        
        for path in warmupPaths {
            Task(priority: .utility) { [weak self] in
                guard let self else { return }
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
            }
        }
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
    /// Returns nil if no QuickLook thumbnail available - let view use NSWorkspace fallback
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
        
        // Return nil - let view use direct NSWorkspace.icon fallback
        return nil
    }
    
    // MARK: - Batch Preloading (Performance Optimization)
    
    /// Maximum concurrent QuickLook thumbnail generations
    /// Too high overwhelms the system, too low is slow
    private static let maxConcurrentThumbnails = 6
    
    /// Preload thumbnails for multiple items concurrently with throttling
    /// Uses TaskGroup with concurrency limit to prevent system overload
    /// - Parameters:
    ///   - items: Array of items to preload thumbnails for
    ///   - size: Thumbnail size (default 120x120)
    ///   - onThumbnailLoaded: Optional callback for each loaded thumbnail (on MainActor)
    func preloadThumbnails(
        for items: [DroppedItem],
        size: CGSize = CGSize(width: 120, height: 120),
        onThumbnailLoaded: ((UUID, NSImage) -> Void)? = nil
    ) async {
        // Filter to only items that need loading
        let itemsNeedingLoad = items.filter { cachedThumbnail(for: $0) == nil }
        
        guard !itemsNeedingLoad.isEmpty else { return }
        
        // Use TaskGroup with concurrency control via chunking
        let chunks = itemsNeedingLoad.chunked(into: Self.maxConcurrentThumbnails)
        
        for chunk in chunks {
            await withTaskGroup(of: (UUID, NSImage?).self) { group in
                for item in chunk {
                    group.addTask {
                        let thumbnail = await self.loadThumbnailAsync(for: item, size: size)
                        return (item.id, thumbnail)
                    }
                }
                
                // Process results as they complete
                for await (id, thumbnail) in group {
                    if let thumb = thumbnail, let callback = onThumbnailLoaded {
                        await MainActor.run {
                            callback(id, thumb)
                        }
                    }
                }
            }
        }
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
    
    /// Async load QuickLook thumbnail for any file path (used by clipboard)
    /// Returns nil if no QuickLook thumbnail available - caller should use icon fallback
    func loadFileThumbnailAsync(path: String, size: CGSize = CGSize(width: 120, height: 120)) async -> NSImage? {
        let cacheKey = "file:\(path):\(Int(size.width))" as NSString
        
        // Check cache first
        if let cached = fileCache.object(forKey: cacheKey) {
            return cached
        }
        
        // Generate async using QuickLook
        let url = URL(fileURLWithPath: path)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .all  // Include icon fallbacks
        )
        
        do {
            let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let thumbnail = rep.nsImage
            let estimatedCost = Int(size.width * size.height * 4)
            fileCache.setObject(thumbnail, forKey: cacheKey, cost: estimatedCost)
            return thumbnail
        } catch {
            // Return nil - let caller use icon fallback
            return nil
        }
    }
    
    /// Get cached thumbnail for a file URL (synchronous, returns nil if not cached)
    /// Used for drag previews where async is not possible - shows actual thumbnail if already generated
    func getCachedThumbnail(for url: URL, size: CGSize = CGSize(width: 120, height: 120)) -> NSImage? {
        // First, try to find the item by URL (thumbnails are cached by item UUID).
        let basketItems = FloatingBasketWindowController.basketsWithItems.flatMap { $0.basketState.items }
        let allItems = DroppyState.shared.items + basketItems
        if let item = allItems.first(where: { $0.url == url }) {
            let cacheKey = item.id.uuidString as NSString
            if let cached = fileCache.object(forKey: cacheKey) {
                return cached
            }
        }
        
        // Check clipboard items - temp files include first 8 chars of UUID in filename
        // e.g. "filename_A1B2C3D4.png" where A1B2C3D4 is the UUID prefix
        let filename = url.lastPathComponent
        if url.path.contains("DroppyClipboard") {
            // This is a clipboard temp file - try to match UUID prefix
            for clipboardItem in ClipboardManager.shared.history {
                let uuidPrefix = String(clipboardItem.id.uuidString.prefix(8))
                if filename.contains(uuidPrefix) {
                    // Found matching clipboard item - get its thumbnail
                    if let thumbnail = self.thumbnail(for: clipboardItem) {
                        return thumbnail
                    }
                    break
                }
            }
        }
        
        // Fallback: try the file path cache key (used by loadFileThumbnailAsync)
        let pathCacheKey = "file:\(url.path):\(Int(size.width))" as NSString
        return fileCache.object(forKey: pathCacheKey)
    }
    
    /// Render a native macOS folder icon for drag previews
    /// Uses NSWorkspace folder icon with hue rotation for pinned folders (matching basket/shelf display)
    func renderFolderIcon(size: CGFloat = 64, isPinned: Bool = false) -> NSImage {
        let cacheKey = "nativeFolder:\(isPinned ? "pinned" : "regular"):\(Int(size))" as NSString
        
        // Check cache first
        if let cached = iconCache.object(forKey: cacheKey) {
            return cached
        }
        
        // Get native macOS folder icon
        let folderIcon = NSWorkspace.shared.icon(for: .folder)
        folderIcon.size = NSSize(width: size, height: size)
        
        // For pinned folders, apply hue rotation (180 degrees = orange/gold tint)
        if isPinned {
            // Create a view to apply hue rotation effect
            let iconView = NSImageView(frame: NSRect(x: 0, y: 0, width: size, height: size))
            iconView.image = folderIcon
            iconView.imageScaling = .scaleProportionallyUpOrDown
            
            // Apply Core Image filter for hue rotation
            if let cgImage = folderIcon.cgImage(forProposedRect: nil, context: nil, hints: nil),
               let filter = CIFilter(name: "CIHueAdjust") {
                let ciImage = CIImage(cgImage: cgImage)
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(CGFloat.pi, forKey: kCIInputAngleKey) // 180 degrees in radians
                
                if let outputImage = filter.outputImage {
                    let context = CIContext()
                    if let outputCG = context.createCGImage(outputImage, from: outputImage.extent) {
                        let result = NSImage(cgImage: outputCG, size: NSSize(width: size, height: size))
                        iconCache.setObject(result, forKey: cacheKey, cost: 4096)
                        return result
                    }
                }
            }
        }
        
        // Cache and return regular folder icon
        iconCache.setObject(folderIcon, forKey: cacheKey, cost: 4096)
        return folderIcon
    }
    
    // MARK: - Multi-Page Document Support
    
    /// Get the number of pages in a document (PDF, or 1 for other types)
    func pageCount(for path: String) -> Int {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        
        // PDFs have native page support
        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url) else { return 1 }
            return pdf.pageCount
        }
        
        // Office documents use QuickLook which only provides first page
        // Future: Could use document frameworks for true multi-page
        return 1
    }
    
    /// Load a specific page from a multi-page document as an image
    /// Returns nil if page doesn't exist or can't be rendered
    func loadDocumentPage(path: String, pageIndex: Int, size: CGSize = CGSize(width: 400, height: 400)) async -> NSImage? {
        let cacheKey = "page:\(path):\(pageIndex):\(Int(size.width))" as NSString
        
        // Check cache first
        if let cached = pageCache.object(forKey: cacheKey) {
            return cached
        }
        
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        
        // PDFs: Use PDFKit for high-quality page rendering
        if ext == "pdf" {
            return await Task.detached(priority: .userInitiated) {
                guard let pdf = PDFDocument(url: url),
                      let page = pdf.page(at: pageIndex) else { return nil }
                
                let pageRect = page.bounds(for: .mediaBox)
                let scale = min(size.width / pageRect.width, size.height / pageRect.height)
                let scaledSize = CGSize(
                    width: pageRect.width * scale,
                    height: pageRect.height * scale
                )
                
                let image = NSImage(size: scaledSize)
                image.lockFocus()
                
                if let context = NSGraphicsContext.current?.cgContext {
                    context.setFillColor(NSColor.white.cgColor)
                    context.fill(CGRect(origin: .zero, size: scaledSize))
                    
                    context.scaleBy(x: scale, y: scale)
                    page.draw(with: .mediaBox, to: context)
                }
                
                image.unlockFocus()
                
                // Cache on main thread
                await MainActor.run {
                    let estimatedCost = Int(scaledSize.width * scaledSize.height * 4)
                    self.pageCache.setObject(image, forKey: cacheKey, cost: estimatedCost)
                }
                
                return image
            }.value
        }
        
        // For other file types (first page only via QuickLook)
        if pageIndex == 0 {
            return await loadFileThumbnailAsync(path: path, size: size)
        }
        
        return nil
    }
    
    /// Generate a scaled-down thumbnail from image data using ImageIO
    /// This is faster and more memory-efficient than NSImage drawing
    /// (Cherry-picked from PR #87)
    private func generateThumbnail(from data: Data) -> NSImage? {
        // Use ImageIO to create thumbnail source - avoids full image decode into memory
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        
        // Calculate max pixel size (Retina aware)
        let maxPixelSize = max(thumbnailSize.width, thumbnailSize.height) * 2
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        
        // Generate thumbnail efficiently without full image decode
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        
        // Convert to NSImage
        return NSImage(cgImage: cgImage, size: thumbnailSize)
    }
    
    /// Clear a specific item from cache (e.g., when deleted)
    func invalidate(itemId: UUID) {
        cache.removeObject(forKey: itemId.uuidString as NSString)
        fileCache.removeObject(forKey: itemId.uuidString as NSString)
    }

    /// Clears heavy thumbnail/image preview caches while keeping lightweight icons warm.
    /// Use this when transient UI (basket/preview panels) is dismissed to reclaim RAM.
    func clearTransientPreviews() {
        cache.removeAllObjects()
        fileCache.removeAllObjects()
        pageCache.removeAllObjects()
    }
    
    /// Clear entire cache (e.g., on memory warning)
    func clearAll() {
        cache.removeAllObjects()
        fileCache.removeAllObjects()
        iconCache.removeAllObjects()
        pageCache.removeAllObjects()
    }
}

// MARK: - Array Chunking Extension

extension Array {
    /// Splits array into chunks of specified size
    /// Used for batching concurrent operations
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
