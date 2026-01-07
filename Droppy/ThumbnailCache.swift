//
//  ThumbnailCache.swift
//  Droppy
//
//  Created by Droppy on 07/01/2026.
//  Memory-efficient thumbnail caching for clipboard images
//

import AppKit
import Foundation

/// Centralized cache for clipboard image thumbnails
/// Uses NSCache for automatic memory pressure eviction
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    
    /// Size for list row thumbnails (32x32 displayed, 64x64 for Retina)
    private let thumbnailSize = CGSize(width: 64, height: 64)
    
    /// NSCache automatically evicts under memory pressure
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        // Limit cache to ~50 thumbnails (each ~16KB = ~800KB max)
        cache.countLimit = 50
        cache.totalCostLimit = 1024 * 1024 // 1MB max
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
    }
    
    /// Clear entire cache (e.g., on memory warning)
    func clearAll() {
        cache.removeAllObjects()
    }
}
