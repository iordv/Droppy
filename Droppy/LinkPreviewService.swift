import Foundation
import AppKit
import LinkPresentation

struct RichLinkMetadata: Codable {
    var title: String?
    var description: String?
    var image: Data?
    var icon: Data?
    var domain: String?
}

/// Wrapper class for NSCache (requires class type)
private class CachedMetadata: NSObject {
    let metadata: RichLinkMetadata
    init(_ metadata: RichLinkMetadata) {
        self.metadata = metadata
    }
}

/// Service for fetching and caching link previews for URLs
class LinkPreviewService {
    static let shared = LinkPreviewService()
    
    // Use NSCache for automatic memory pressure eviction (instead of unbounded Dictionary)
    private let metadataCache = NSCache<NSString, CachedMetadata>()
    private let imageCache = NSCache<NSString, NSImage>()
    private var pendingRequests: [String: Task<RichLinkMetadata?, Never>] = [:]
    
    private init() {
        // Limit caches to prevent unbounded growth
        metadataCache.countLimit = 50  // ~50 URLs cached
        imageCache.countLimit = 30     // Images are larger, keep fewer
    }
    
    // MARK: - Public API
    
    /// Fetch metadata for a URL using LinkPresentation and URLSession
    func fetchMetadata(for urlString: String) async -> RichLinkMetadata? {
        let cacheKey = urlString as NSString
        
        // Check cache first
        if let cached = metadataCache.object(forKey: cacheKey) {
            return cached.metadata
        }
        
        // Check if there's already a pending request
        if let pendingTask = pendingRequests[urlString] {
            return await pendingTask.value
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        // Create a task for this request
        let task = Task<RichLinkMetadata?, Never> {
            let provider = LPMetadataProvider()
            provider.timeout = 10
            
            do {
                let metadata = try await provider.startFetchingMetadata(for: url)
                
                var rich = RichLinkMetadata()
                rich.title = metadata.title
                rich.description = metadata.value(forKey: "summary") as? String ?? ""
                rich.domain = url.host
                
                // Try to get image from metadata
                if let imageProvider = metadata.imageProvider {
                    rich.image = await withCheckedContinuation { continuation in
                        imageProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                            continuation.resume(returning: data)
                        }
                    }
                }
                
                // Try to get icon
                if let iconProvider = metadata.iconProvider {
                    rich.icon = await withCheckedContinuation { continuation in
                        iconProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                            continuation.resume(returning: data)
                        }
                    }
                }
                
                _ = await MainActor.run {
                    self.metadataCache.setObject(CachedMetadata(rich), forKey: cacheKey)
                    self.pendingRequests.removeValue(forKey: urlString)
                }
                return rich
            } catch {
                _ = await MainActor.run {
                    self.pendingRequests.removeValue(forKey: urlString)
                }
                print("LinkPreview Error: \(error.localizedDescription)")
                
                // Fallback: Just return basic info
                return RichLinkMetadata(title: nil, description: nil, image: nil, icon: nil, domain: url.host)
            }
        }
        
        pendingRequests[urlString] = task
        return await task.value
    }
    
    /// Check if URL points directly to an image
    func isDirectImageURL(_ urlString: String) -> Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic", "svg", "avif", "apng"]
        let lowercased = urlString.lowercased()
        
        // 1. Check extension
        if let url = URL(string: lowercased) {
            if imageExtensions.contains(url.pathExtension) {
                return true
            }
        }
        
        // 2. Check common image paths/hosts (even without extension)
        if lowercased.contains("i.postimg.cc") || lowercased.contains("i.imgur.com") {
            return true
        }
        
        return false
    }
    
    /// Fetch image directly from URL (for direct image links)
    func fetchImagePreview(for urlString: String) async -> NSImage? {
        let cacheKey = urlString as NSString
        
        // Check cache
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Try to create image from data
            // For AVIF/WEBP, we might need to rely on native support if available
            if let image = NSImage(data: data) {
                _ = await MainActor.run {
                    self.imageCache.setObject(image, forKey: cacheKey)
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
        metadataCache.removeAllObjects()
        imageCache.removeAllObjects()
    }
}
