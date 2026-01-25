//
//  QuickshareItem.swift
//  Droppy
//
//  Model for storing Quickshare upload history with management tokens
//

import Foundation

/// Represents a file uploaded via Droppy Quickshare
struct QuickshareItem: Identifiable, Codable, Equatable {
    let id: UUID
    let filename: String
    let shareURL: String
    let token: String  // X-Token from 0x0.st for management
    let uploadDate: Date
    let fileSize: Int64
    let expirationDate: Date
    
    init(filename: String, shareURL: String, token: String, fileSize: Int64) {
        self.id = UUID()
        self.filename = filename
        self.shareURL = shareURL
        self.token = token
        self.uploadDate = Date()
        self.fileSize = fileSize
        self.expirationDate = Self.calculateExpiration(fileSize: fileSize, from: Date())
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
