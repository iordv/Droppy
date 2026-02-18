import Foundation
import AppKit
import LinkPresentation
import ImageIO

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
    private let pendingRequestsLock = NSLock()
    
    private init() {
        // Limit caches to prevent unbounded growth
        metadataCache.countLimit = 50  // ~50 URLs cached
        imageCache.countLimit = 30     // Images are larger, keep fewer
        imageCache.totalCostLimit = 20 * 1024 * 1024
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
        if let pendingTask = pendingRequest(for: urlString) {
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
                
                self.metadataCache.setObject(CachedMetadata(rich), forKey: cacheKey)
                self.removePendingRequest(for: urlString)
                return rich
            } catch {
                self.removePendingRequest(for: urlString)
                print("LinkPreview Error: \(error.localizedDescription)")
                
                // Fallback: Just return basic info
                return RichLinkMetadata(title: nil, description: nil, image: nil, icon: nil, domain: url.host)
            }
        }
        
        setPendingRequest(task, for: urlString)
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
            if let image = decodePreviewImage(from: data) {
                imageCache.setObject(image, forKey: cacheKey, cost: estimatedCost(for: image))
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
    func clearCache(cancelPending: Bool = true) {
        metadataCache.removeAllObjects()
        imageCache.removeAllObjects()

        guard cancelPending else { return }
        pendingRequestsLock.lock()
        let tasks = Array(pendingRequests.values)
        pendingRequests.removeAll()
        pendingRequestsLock.unlock()
        for task in tasks {
            task.cancel()
        }
    }

    private func decodePreviewImage(from data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return NSImage(data: data)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 900
        ]

        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
        }

        return NSImage(data: data)
    }

    private func estimatedCost(for image: NSImage) -> Int {
        let width = Int(max(image.size.width, 1))
        let height = Int(max(image.size.height, 1))
        return max(width * height * 4, 1)
    }

    private func pendingRequest(for key: String) -> Task<RichLinkMetadata?, Never>? {
        pendingRequestsLock.lock()
        defer { pendingRequestsLock.unlock() }
        return pendingRequests[key]
    }

    private func setPendingRequest(_ task: Task<RichLinkMetadata?, Never>, for key: String) {
        pendingRequestsLock.lock()
        defer { pendingRequestsLock.unlock() }
        pendingRequests[key] = task
    }

    private func removePendingRequest(for key: String) {
        pendingRequestsLock.lock()
        defer { pendingRequestsLock.unlock() }
        pendingRequests.removeValue(forKey: key)
    }
}
