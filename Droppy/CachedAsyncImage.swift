//
//  CachedAsyncImage.swift
//  Droppy
//
//  A cached version of AsyncImage that persists images across view recreations
//  to prevent fallback icons from flashing during reloads.
//

import SwiftUI
import ImageIO

/// A cached async image that stores loaded images to prevent re-fetching
/// and fallback icon flashing on view recreation.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: NSImage?
    @State private var isLoading = false
    @State private var hasFailed = false
    @State private var loadTask: Task<Void, Never>?
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(nsImage: image))
            } else if hasFailed {
                placeholder()
            } else {
                // Loading state - show subtle placeholder, not the fallback icon
                RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                    .fill(AdaptiveColors.buttonBackgroundAuto)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                            .opacity(0.5)
                    )
            }
        }
        .onAppear {
            startLoading()
        }
        .onChange(of: url) { _, _ in
            image = nil
            hasFailed = false
            isLoading = false
            startLoading()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }
    
    private func startLoading() {
        loadTask?.cancel()
        loadTask = nil

        guard let url = url else {
            hasFailed = true
            return
        }
        
        // Check cache first
        if let cached = ExtensionIconCache.shared.cachedImage(for: url) {
            self.image = cached
            self.hasFailed = false
            self.isLoading = false
            return
        }
        
        guard !isLoading else { return }
        isLoading = true
        hasFailed = false
        
        loadTask = Task {
            let loadedImage = await ExtensionIconCache.shared.loadImage(for: url)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.image = loadedImage
                self.hasFailed = loadedImage == nil
                self.isLoading = false
                self.loadTask = nil
            }
        }
    }
}

/// Thread-safe, bounded in-memory cache for extension icons.
/// Also deduplicates concurrent loads for the same URL.
final class ExtensionIconCache {
    static let shared = ExtensionIconCache()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlightTasks: [URL: Task<NSImage?, Never>] = [:]
    private let lock = NSLock()

    private init() {
        cache.countLimit = 120
        cache.totalCostLimit = 12 * 1024 * 1024
    }

    func cachedImage(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func clearCache() {
        lock.lock()
        let tasks = Array(inFlightTasks.values)
        inFlightTasks.removeAll()
        lock.unlock()
        for task in tasks {
            task.cancel()
        }
        cache.removeAllObjects()
    }

    func loadImage(for url: URL) async -> NSImage? {
        if let cached = cachedImage(for: url) {
            return cached
        }

        if let existingTask = existingInFlightTask(for: url) {
            return await existingTask.value
        }

        let task = Task<NSImage?, Never> { [weak self] in
            defer { self?.removeInFlightTask(for: url) }

            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 15

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled else { return nil }

                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    return nil
                }

                guard let image = Self.decodeImage(from: data) else {
                    return nil
                }

                self?.store(image, for: url)
                return image
            } catch {
                return nil
            }
        }

        setInFlightTask(task, for: url)
        return await task.value
    }

    private func existingInFlightTask(for url: URL) -> Task<NSImage?, Never>? {
        lock.lock()
        defer { lock.unlock() }
        return inFlightTasks[url]
    }

    private func setInFlightTask(_ task: Task<NSImage?, Never>, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        inFlightTasks[url] = task
    }

    private func removeInFlightTask(for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        inFlightTasks.removeValue(forKey: url)
    }

    private func store(_ image: NSImage, for url: URL) {
        let pixelWidth = Int(max(image.size.width, 1))
        let pixelHeight = Int(max(image.size.height, 1))
        let estimatedCost = max(pixelWidth * pixelHeight * 4, 1)
        cache.setObject(image, forKey: url as NSURL, cost: estimatedCost)
    }

    private static func decodeImage(from data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return NSImage(data: data)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 960
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return NSImage(data: data)
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }
}
