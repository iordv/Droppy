//
//  CachedAsyncImage.swift
//  Droppy
//
//  A cached version of AsyncImage that persists images across view recreations
//  to prevent fallback icons from flashing during reloads.
//

import SwiftUI

/// A cached async image that stores loaded images to prevent re-fetching
/// and fallback icon flashing on view recreation.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: NSImage?
    @State private var isLoading = false
    @State private var hasFailed = false
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(nsImage: image))
            } else if hasFailed {
                placeholder()
            } else {
                // Loading state - show subtle placeholder, not the fallback icon
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.15))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                            .opacity(0.5)
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            hasFailed = true
            return
        }
        
        // Check cache first
        if let cached = ExtensionIconCache.shared.image(for: url) {
            self.image = cached
            return
        }
        
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let nsImage = NSImage(data: data) {
                    ExtensionIconCache.shared.cache(nsImage, for: url)
                    await MainActor.run {
                        self.image = nsImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.hasFailed = true
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.hasFailed = true
                    self.isLoading = false
                }
            }
        }
    }
}

/// Simple in-memory cache for extension icons
final class ExtensionIconCache {
    static let shared = ExtensionIconCache()
    private var cache: [URL: NSImage] = [:]
    private let lock = NSLock()
    
    func image(for url: URL) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[url]
    }
    
    func cache(_ image: NSImage, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        cache[url] = image
    }
}
