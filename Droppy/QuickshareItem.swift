//
//  QuickshareItem.swift
//  Droppy
//
//  Model for storing Quickshare upload history with management tokens
//

import Foundation
import AppKit

/// Represents a file uploaded via Droppy Quickshare
struct QuickshareItem: Identifiable, Codable, Equatable {
    let id: UUID
    let filename: String
    let shareURL: String
    let token: String  // X-Token from 0x0.st for management
    let uploadDate: Date
    let fileSize: Int64
    let expirationDate: Date
    let thumbnailData: Data?  // Base64-encoded preview (PNG, max 64x64)
    let isZip: Bool  // Whether this is a zip archive (for stacked icon)
    let itemCount: Int  // Number of items (1 for single file, >1 for multi-file zip)
    
    init(filename: String, shareURL: String, token: String, fileSize: Int64, thumbnailData: Data? = nil, itemCount: Int = 1) {
        self.id = UUID()
        self.filename = filename
        self.shareURL = shareURL
        self.token = token
        self.uploadDate = Date()
        self.fileSize = fileSize
        self.expirationDate = Self.calculateExpiration(fileSize: fileSize, from: Date())
        self.thumbnailData = thumbnailData
        self.isZip = filename.lowercased().hasSuffix(".zip")
        self.itemCount = itemCount
    }
    
    // MARK: - Codable (Backward Compatibility)
    
    enum CodingKeys: String, CodingKey {
        case id, filename, shareURL, token, uploadDate, fileSize, expirationDate
        case thumbnailData, isZip, itemCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        filename = try container.decode(String.self, forKey: .filename)
        shareURL = try container.decode(String.self, forKey: .shareURL)
        token = try container.decode(String.self, forKey: .token)
        uploadDate = try container.decode(Date.self, forKey: .uploadDate)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
        expirationDate = try container.decode(Date.self, forKey: .expirationDate)
        
        // New fields (provide defaults if missing)
        thumbnailData = try container.decodeIfPresent(Data.self, forKey: .thumbnailData)
        isZip = try container.decodeIfPresent(Bool.self, forKey: .isZip) ?? filename.lowercased().hasSuffix(".zip")
        itemCount = try container.decodeIfPresent(Int.self, forKey: .itemCount) ?? 1
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(filename, forKey: .filename)
        try container.encode(shareURL, forKey: .shareURL)
        try container.encode(token, forKey: .token)
        try container.encode(uploadDate, forKey: .uploadDate)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(expirationDate, forKey: .expirationDate)
        try container.encodeIfPresent(thumbnailData, forKey: .thumbnailData)
        try container.encode(isZip, forKey: .isZip)
        try container.encode(itemCount, forKey: .itemCount)
    }
    
    /// Calculate expiration date based on 0x0.st retention formula
    /// retention = min_age + (min_age - max_age) * pow((file_size / max_size - 1), 3)
    /// min_age = 30 days, max_age = 365 days, max_size = 512 MiB
    static func calculateExpiration(fileSize: Int64, from uploadDate: Date) -> Date {
        let minAge: Double = 30  // days
        let maxAge: Double = 365 // days
        let maxSize: Double = 512 * 1024 * 1024 // 512 MiB in bytes
        
        let sizeRatio = Double(fileSize) / maxSize
        let clampedRatio = min(max(sizeRatio, 0), 1) // Clamp to [0, 1]
        
        // retention = min_age + (min_age - max_age) * pow((file_size / max_size - 1), 3)
        let retentionDays = minAge + (minAge - maxAge) * pow(clampedRatio - 1, 3)
        
        return uploadDate.addingTimeInterval(retentionDays * 24 * 60 * 60)
    }
    
    /// Generate a thumbnail from a file URL (max 64x64)
    static func generateThumbnail(from url: URL) -> Data? {
        // For images, generate a small preview
        let ext = url.pathExtension.lowercased()
        
        if ["jpg", "jpeg", "png", "gif", "webp", "heic", "tiff", "bmp"].contains(ext) {
            guard let image = NSImage(contentsOf: url) else { return nil }
            return resizeImage(image, maxSize: 64)
        }
        
        // For other files, use Quick Look thumbnail
        if let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? {
            return resizeImage(icon, maxSize: 64)
        }
        
        return nil
    }
    
    /// Resize an NSImage to fit within maxSize while preserving aspect ratio
    private static func resizeImage(_ image: NSImage, maxSize: CGFloat) -> Data? {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }
        
        let scale = min(maxSize / originalSize.width, maxSize / originalSize.height, 1.0)
        let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        
        guard let tiff = newImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return png
    }
    
    /// Get the thumbnail as NSImage
    var thumbnail: NSImage? {
        guard let data = thumbnailData else { return nil }
        return NSImage(data: data)
    }
    
    /// Formatted time until expiration
    var expirationText: String {
        let now = Date()
        if expirationDate < now {
            return "Expired"
        }
        
        let interval = expirationDate.timeIntervalSince(now)
        let days = Int(interval / (24 * 60 * 60))
        
        if days > 30 {
            let months = days / 30
            return "Expires in \(months) month\(months == 1 ? "" : "s")"
        } else if days > 0 {
            return "Expires in \(days) day\(days == 1 ? "" : "s")"
        } else {
            let hours = Int(interval / (60 * 60))
            if hours > 0 {
                return "Expires in \(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                return "Expires soon"
            }
        }
    }
    
    /// Whether the file has expired
    var isExpired: Bool {
        expirationDate < Date()
    }
    
    /// Formatted file size
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    /// Short version of the share URL for display
    var shortURL: String {
        shareURL.replacingOccurrences(of: "https://", with: "")
    }
}
