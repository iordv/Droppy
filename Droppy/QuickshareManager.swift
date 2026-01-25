//
//  QuickshareManager.swift
//  Droppy
//
//  Manages Quickshare upload history with persistence and server-side deletion
//

import Foundation
import AppKit
import Observation

/// Manages Quickshare upload history
@Observable
final class QuickshareManager {
    static let shared = QuickshareManager()
    
    /// All stored quickshare uploads
    private(set) var items: [QuickshareItem] = []
    
    /// Whether a delete operation is in progress
    var isDeletingItem: UUID? = nil
    
    private let storageURL: URL
    
    private init() {
        // Store in Application Support/Droppy/quickshare_history.json
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let droppyDir = appSupport.appendingPathComponent("Droppy")
        try? FileManager.default.createDirectory(at: droppyDir, withIntermediateDirectories: true)
        self.storageURL = droppyDir.appendingPathComponent("quickshare_history.json")
        
        load()
        cleanupExpired()
    }
    
    // MARK: - Public Methods
    
    /// Add a new quickshare item to history
    func addItem(_ item: QuickshareItem) {
        items.insert(item, at: 0) // Most recent first
        save()
    }
    
    /// Remove an item from local history only (does not delete from server)
    func removeFromHistory(_ item: QuickshareItem) {
        items.removeAll { $0.id == item.id }
        save()
    }
    
    /// Delete a file from 0x0.st server and remove from history
    func deleteFromServer(_ item: QuickshareItem) async -> Bool {
        await MainActor.run {
            isDeletingItem = item.id
        }
        
        defer {
            Task { @MainActor in
                isDeletingItem = nil
            }
        }
        
        // Send DELETE request to 0x0.st
        guard let url = URL(string: item.shareURL) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart body with token and delete field
        var body = Data()
        
        // Token field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"token\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(item.token)\r\n".data(using: .utf8)!)
        
        // Delete field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"delete\"\r\n\r\n".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                // 0x0.st returns 200 on successful delete
                let success = httpResponse.statusCode == 200
                
                if success {
                    await MainActor.run {
                        removeFromHistory(item)
                    }
                    print("✅ [Quickshare] Deleted from server: \(item.shareURL)")
                } else {
                    print("❌ [Quickshare] Delete failed with status: \(httpResponse.statusCode)")
                }
                
                return success
            }
        } catch {
            print("❌ [Quickshare] Delete error: \(error)")
        }
        
        return false
    }
    
    /// Copy share URL to clipboard
    func copyToClipboard(_ item: QuickshareItem) {
        let clipboard = NSPasteboard.general
        clipboard.clearContents()
        clipboard.setString(item.shareURL, forType: .string)
        HapticFeedback.copy()
    }
    
    // MARK: - Persistence
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL)
        } catch {
            print("❌ [Quickshare] Failed to save history: \(error)")
        }
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: storageURL)
            items = try JSONDecoder().decode([QuickshareItem].self, from: data)
        } catch {
            print("❌ [Quickshare] Failed to load history: \(error)")
            items = []
        }
    }
    
    /// Remove expired items from history
    private func cleanupExpired() {
        let now = Date()
        let expiredCount = items.filter { $0.expirationDate < now }.count
        items.removeAll { $0.expirationDate < now }
        
        if expiredCount > 0 {
            save()
            print("🧹 [Quickshare] Cleaned up \(expiredCount) expired items")
        }
    }
}
