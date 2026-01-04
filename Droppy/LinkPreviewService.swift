import Foundation
import AppKit
import LinkPresentation

/// Service for fetching and caching link previews for URLs
class LinkPreviewService {
    static let shared = LinkPreviewService()
    
    private var metadataCache: [String: LPLinkMetadata] = [:]
    private var imageCache: [String: NSImage] = [:]
    private var pendingRequests: [String: Task<LPLinkMetadata?, Never>] = [:]
    
    private init() {}
    
    // MARK: - Public API
    
    /// Fetch metadata for a URL using LinkPresentation
    func fetchMetadata(for urlString: String) async -> LPLinkMetadata? {
        // Check cache first
        if let cached = metadataCache[urlString] {
            return cached
        }
        
        // Check if there's already a pending request
        if let pendingTask = pendingRequests[urlString] {
            return await pendingTask.value
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        // Create a task for this request
        let task = Task<LPLinkMetadata?, Never> {
            let provider = LPMetadataProvider()
            provider.timeout = 10
            
            do {
                let metadata = try await provider.startFetchingMetadata(for: url)
                await MainActor.run {
                    self.metadataCache[urlString] = metadata
                    self.pendingRequests.removeValue(forKey: urlString)
                }
                return metadata
            } catch {
                _ = await MainActor.run {
                    self.pendingRequests.removeValue(forKey: urlString)
                }
                print("LinkPreview Error: \(error.localizedDescription)")
                return nil
            }
        }
        
        pendingRequests[urlString] = task
        return await task.value
    }
    
    /// Check if URL points directly to an image
    func isDirectImageURL(_ urlString: String) -> Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic", "svg"]
        guard let url = URL(string: urlString.lowercased()) else { return false }
        return imageExtensions.contains(url.pathExtension)
    }
    
    /// Fetch image directly from URL (for direct image links)
    func fetchImagePreview(for urlString: String) async -> NSImage? {
        // Check cache
        if let cached = imageCache[urlString] {
            return cached
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Try to create image from data - some servers don't return proper content-type
            if let image = NSImage(data: data) {
                await MainActor.run {
                    self.imageCache[urlString] = image
                }
                return image
            }
        } catch {
            print("Image fetch error: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Extract domain from URL for display
    func extractDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return url.host
    }
    
    /// Clear caches (for memory management if needed)
    func clearCache() {
        metadataCache.removeAll()
        imageCache.removeAll()
    }
}
