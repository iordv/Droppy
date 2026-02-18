//
//  DroppedItem.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing
import AppKit
import AVKit

/// Utilities for handling dropped web links as first-class Droppy items.
enum DroppyLinkSupport {
    private static let supportedWebSchemes: Set<String> = ["http", "https"]
    private static let remoteURLType = NSPasteboard.PasteboardType("public.url")

    static func parseWebURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              isSupportedRemoteURL(url),
              url.host != nil else {
            return nil
        }
        return url
    }

    static func isSupportedRemoteURL(_ url: URL) -> Bool {
        guard !url.isFileURL, let scheme = url.scheme?.lowercased() else { return false }
        return supportedWebSchemes.contains(scheme)
    }

    static func extractRemoteURLs(from pasteboard: NSPasteboard) -> [URL] {
        var remoteURLs: [URL] = []
        var seen: Set<String> = []

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls where isSupportedRemoteURL(url) {
                appendUniqueRemoteURL(url, to: &remoteURLs, seen: &seen)
            }
        }

        if let items = pasteboard.pasteboardItems {
            for item in items {
                if let rawURL = item.string(forType: .URL) ?? item.string(forType: remoteURLType),
                   let parsed = parseWebURL(from: rawURL) {
                    appendUniqueRemoteURL(parsed, to: &remoteURLs, seen: &seen)
                    continue
                }

                if let rawText = item.string(forType: .string),
                   let parsed = parseWebURL(from: rawText) {
                    appendUniqueRemoteURL(parsed, to: &remoteURLs, seen: &seen)
                }
            }
        }

        return remoteURLs
    }

    static func createTextOrLinkFiles(from pasteboard: NSPasteboard, in directory: URL) -> [URL] {
        let remoteURLs = extractRemoteURLs(from: pasteboard)
        if !remoteURLs.isEmpty {
            return createWeblocFiles(for: remoteURLs, in: directory)
        }

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            return []
        }

        guard let textFileURL = createTextFile(with: text, in: directory) else {
            return []
        }
        return [textFileURL]
    }

    static func createWeblocFiles(for remoteURLs: [URL], in directory: URL) -> [URL] {
        guard !remoteURLs.isEmpty else { return [] }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        var created: [URL] = []
        var seen: Set<String> = []
        for remoteURL in remoteURLs where isSupportedRemoteURL(remoteURL) {
            let key = remoteURL.absoluteString
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            if let fileURL = createWeblocFile(for: remoteURL, in: directory) {
                created.append(fileURL)
            }
        }
        return created
    }

    static func resolveRemoteURL(from fileURL: URL) -> URL? {
        guard fileURL.isFileURL else { return nil }
        let ext = fileURL.pathExtension.lowercased()

        switch ext {
        case "webloc":
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let urlString = plist["URL"] as? String,
               let parsed = parseWebURL(from: urlString) {
                return parsed
            }
            if let raw = String(data: data, encoding: .utf8) {
                return parseWebURL(from: raw)
            }
            return nil

        case "url":
            guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
            let lines = raw.components(separatedBy: .newlines)
            if let urlLine = lines.first(where: { $0.lowercased().hasPrefix("url=") }) {
                let value = String(urlLine.dropFirst(4))
                return parseWebURL(from: value)
            }
            return parseWebURL(from: raw)

        case "txt":
            let isLegacyDroppedLink =
                fileURL.lastPathComponent.hasPrefix("Text ") &&
                fileURL.path.contains("DroppyDrops-")
            guard isLegacyDroppedLink else { return nil }
            guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
            return parseWebURL(from: raw)

        default:
            return nil
        }
    }

    static func normalizeQuickshareInputURLs(_ urls: [URL]) -> (fileURLs: [URL], remoteURLs: [URL]) {
        var fileURLs: [URL] = []
        var remoteURLs: [URL] = []
        var seenFilePaths: Set<String> = []
        var seenRemoteURLs: Set<String> = []

        for url in urls {
            if url.isFileURL {
                if let remoteURL = resolveRemoteURL(from: url) {
                    let key = remoteURL.absoluteString
                    guard !seenRemoteURLs.contains(key) else { continue }
                    seenRemoteURLs.insert(key)
                    remoteURLs.append(remoteURL)
                    continue
                }

                let key = url.standardizedFileURL.path
                guard !seenFilePaths.contains(key) else { continue }
                seenFilePaths.insert(key)
                fileURLs.append(url)
                continue
            }

            guard isSupportedRemoteURL(url) else { continue }
            let key = url.absoluteString
            guard !seenRemoteURLs.contains(key) else { continue }
            seenRemoteURLs.insert(key)
            remoteURLs.append(url)
        }

        return (fileURLs, remoteURLs)
    }

    private static func createWeblocFile(for remoteURL: URL, in directory: URL) -> URL? {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let host = remoteURL.host ?? "Link"
        let fileName = uniqueFileName(
            baseName: sanitizeFileName(host),
            ext: "webloc"
        )
        let fileURL = directory.appendingPathComponent(fileName)

        let plist = ["URL": remoteURL.absoluteString]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else {
            return nil
        }

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    private static func createTextFile(with text: String, in directory: URL) -> URL? {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        let fileName = uniqueFileName(baseName: "Text", ext: "txt")
        let fileURL = directory.appendingPathComponent(fileName)

        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    private static func appendUniqueRemoteURL(_ url: URL, to urls: inout [URL], seen: inout Set<String>) {
        let key = url.absoluteString
        guard !seen.contains(key) else { return }
        seen.insert(key)
        urls.append(url)
    }

    private static func uniqueFileName(baseName: String, ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "\(baseName) \(timestamp)-\(String(UUID().uuidString.prefix(8))).\(ext)"
    }

    private static func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var sanitized = name.components(separatedBy: invalid).joined(separator: "_")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.isEmpty { sanitized = "Link" }
        if sanitized.count > 40 { sanitized = String(sanitized.prefix(40)) }
        return sanitized
    }
}

/// Represents a file or item dropped onto the Droppy shelf
struct DroppedItem: Identifiable, Hashable, Transferable {
    let id = UUID()
    let url: URL
    let name: String
    let fileType: UTType?
    let icon: NSImage  // PERFORMANCE: Static placeholder - real icon loads async via ThumbnailCache
    var thumbnail: NSImage?
    let dateAdded: Date
    var isTemporary: Bool = false  // Tracks if this file was created as a temp file (conversion, ZIP, etc.)
    var isPinned: Bool = false  // Pinned folders persist across auto-clean and sessions
    
    /// Universal placeholder icon - never triggers Metal shader compilation
    /// Used as immediate fallback while real icons load async
    static let placeholderIcon: NSImage = {
        // SF Symbol rendered to static image - no Metal shaders involved
        let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .regular)
        if let symbol = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            return symbol
        }
        // Ultimate fallback: empty image
        return NSImage(size: NSSize(width: 32, height: 32))
    }()
    
    /// Whether this item is a directory/folder
    var isDirectory: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Remote web link represented by this item, if it is a link file.
    var remoteLinkURL: URL? {
        DroppyLinkSupport.resolveRemoteURL(from: url)
    }

    /// Preferred URL to share for this item.
    /// For link files, this is the remote HTTP(S) URL.
    /// For normal files, this is the file URL itself.
    var preferredShareURL: URL {
        remoteLinkURL ?? url
    }
    
    /// Generates a tooltip string listing the folder's contents (up to 8 items)
    var folderContentsTooltip: String? {
        guard isDirectory else { return nil }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            
            if contents.isEmpty {
                return "Empty folder"
            }
            
            let maxItems = 8
            let sortedContents = contents.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            let displayItems = sortedContents.prefix(maxItems)
            
            var lines = displayItems.map { "• \($0.lastPathComponent)" }
            
            if contents.count > maxItems {
                lines.append("…and \(contents.count - maxItems) more")
            }
            
            return lines.joined(separator: "\n")
        } catch {
            return nil
        }
    }
    
    // Conformance to Transferable using the URL as a proxy
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.url)
    }
    
    init(url: URL, isTemporary: Bool = false) {
        self.url = url
        self.name = url.lastPathComponent
        self.fileType = UTType(filenameExtension: url.pathExtension)
        // PERFORMANCE: Use static placeholder to avoid Metal shader compilation lag
        // Real icon/thumbnail loads asynchronously via ThumbnailCache.loadThumbnailAsync()
        self.icon = DroppedItem.placeholderIcon
        self.dateAdded = Date()
        self.thumbnail = nil
        self.isTemporary = isTemporary
    }
    
    // MARK: - Hashable & Equatable (PERFORMANCE CRITICAL)
    // Use ID-only comparison - synthesized version hashes URL, NSImage, etc.
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DroppedItem, rhs: DroppedItem) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Cleans up temporary files when item is removed from shelf/basket
    func cleanupIfTemporary() {
        if isTemporary {
            TemporaryFileStorageService.shared.removeTemporaryFileIfNeeded(at: url)
        }
    }
    
    /// Generates a thumbnail for the file asynchronously
    /// Returns nil if no QuickLook thumbnail available - view should use NSWorkspace.icon fallback
    func generateThumbnail(size: CGSize = CGSize(width: 64, height: 64)) async -> NSImage? {
        // SPECIAL CASE: Videos - use AVAssetImageGenerator for actual frame thumbnails
        // QuickLook often returns generic icons instead of video frames
        if isVideo {
            if let videoThumbnail = await generateVideoThumbnail(size: size) {
                return videoThumbnail
            }
        }
        
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .thumbnail
        )
        
        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return thumbnail.nsImage
        } catch {
            // FALLBACK FOR IMAGES: Try loading directly with NSImage
            // This fixes pasted images that QuickLook may fail to render
            if isImage, let image = NSImage(contentsOf: url) {
                // Resize to requested size for memory efficiency
                let resized = NSImage(size: size)
                resized.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: size),
                          from: NSRect(origin: .zero, size: image.size),
                          operation: .copy,
                          fraction: 1.0)
                resized.unlockFocus()
                return resized
            }
            // Return nil - let view use NSWorkspace.icon fallback
            return nil
        }
    }
    
    /// Returns true if this item is a video file
    var isVideo: Bool {
        guard let fileType = fileType else { return false }
        return fileType.conforms(to: .movie) || fileType.conforms(to: .video)
    }
    
    /// Generates a thumbnail from video using AVAssetImageGenerator
    /// Extracts a frame from 1 second into the video
    private func generateVideoThumbnail(size: CGSize) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: size.width * 2, height: size.height * 2) // Retina
            
            // Extract frame at 1 second (or start if video is shorter)
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, error in
                if result == .succeeded, let cgImage = cgImage {
                    let nsImage = NSImage(cgImage: cgImage, size: size)
                    continuation.resume(returning: nsImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Copies the file to the clipboard (with actual content for images)
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Link files copy as actual URLs (not .webloc/.txt files).
        if let remoteLinkURL {
            let absolute = remoteLinkURL.absoluteString
            pasteboard.setString(absolute, forType: .string)
            pasteboard.setString(absolute, forType: .URL)
            pasteboard.writeObjects([remoteLinkURL as NSURL])
            return
        }
        
        // For images, copy the actual image data so it pastes into apps like Outlook
        if let fileType = fileType, fileType.conforms(to: .image) {
            if let image = NSImage(contentsOf: url) {
                pasteboard.writeObjects([image])
                // Also add file URL as fallback
                pasteboard.writeObjects([url as NSURL])
                return
            }
        }
        
        // For PDFs, copy both PDF data and file reference
        if let fileType = fileType, fileType.conforms(to: .pdf) {
            if let pdfData = try? Data(contentsOf: url) {
                pasteboard.setData(pdfData, forType: .pdf)
            }
            pasteboard.writeObjects([url as NSURL])
            return
        }
        
        // For text files, copy the text content directly
        if let fileType = fileType, fileType.conforms(to: .plainText) {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                pasteboard.setString(text, forType: .string)
            }
            pasteboard.writeObjects([url as NSURL])
            return
        }
        
        // Default: copy file URL
        pasteboard.writeObjects([url as NSURL])
    }
    
    /// Opens the file with the default application
    func openFile() {
        if let remoteLinkURL {
            NSWorkspace.shared.open(remoteLinkURL)
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    /// Opens the file with a specific application
    func openWith(applicationURL: URL) {
        NSWorkspace.shared.open([url], withApplicationAt: applicationURL, configuration: NSWorkspace.OpenConfiguration())
    }
    
    // MARK: - Available Apps Cache (Static)
    
    /// Cache for available apps by file extension (reduces expensive system queries)
    private static var availableAppsCache: [String: (apps: [(name: String, icon: NSImage, url: URL)], timestamp: Date)] = [:]
    private static let cacheTTL: TimeInterval = 60 // 60 second cache
    private static let maxCacheEntries = 64
    
    /// Gets the list of applications that can open this file (cached)
    /// Returns an array of (name, icon, URL) tuples sorted by name
    func getAvailableApplications() -> [(name: String, icon: NSImage, url: URL)] {
        let ext = url.pathExtension.lowercased()
        let now = Date()

        // Keep cache bounded to avoid gradual memory growth from rare file types.
        DroppedItem.pruneAvailableAppsCache(now: now)
        
        // Check cache first
        if let cached = DroppedItem.availableAppsCache[ext],
           now.timeIntervalSince(cached.timestamp) < DroppedItem.cacheTTL {
            return cached.apps
        }
        
        // Query the system
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: url)
        
        var apps: [(name: String, icon: NSImage, url: URL)] = []
        
        for appURL in appURLs {
            let name = appURL.deletingPathExtension().lastPathComponent
            let icon = ThumbnailCache.shared.cachedIcon(forPath: appURL.path)
            apps.append((name: name, icon: icon, url: appURL))
        }
        
        // Sort by name alphabetically
        let sorted = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        // Cache the result
        DroppedItem.availableAppsCache[ext] = (apps: sorted, timestamp: Date())
        
        return sorted
    }

    private static func pruneAvailableAppsCache(now: Date) {
        availableAppsCache = availableAppsCache.filter {
            now.timeIntervalSince($0.value.timestamp) < cacheTTL
        }

        guard availableAppsCache.count > maxCacheEntries else { return }

        let overflow = availableAppsCache.count - maxCacheEntries
        let keysToDrop = availableAppsCache
            .sorted { $0.value.timestamp < $1.value.timestamp }
            .prefix(overflow)
            .map { $0.key }
        for key in keysToDrop {
            availableAppsCache.removeValue(forKey: key)
        }
    }

    static func clearAvailableAppsCache() {
        availableAppsCache.removeAll()
    }
    
    /// Reveals the file in Finder
    func revealInFinder() {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
    
    /// Returns true if this item is an image file
    var isImage: Bool {
        guard let fileType = fileType else { return false }
        return fileType.conforms(to: .image)
    }
    
    /// Removes the background from this image and returns a new DroppedItem
    /// - Returns: URL of the new image with transparent background
    @MainActor
    func removeBackground() async throws -> URL {
        return try await BackgroundRemovalManager.shared.removeBackground(from: url)
    }
    
    /// Saves the file directly to the user's Downloads folder
    /// Returns the URL of the saved file if successful
    @MainActor
    @discardableResult
    func saveToDownloads() -> URL? {
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        var destinationURL = downloadsURL.appendingPathComponent(name)
        
        // Handle duplicate filenames
        var counter = 1
        let fileNameWithoutExtension = destinationURL.deletingPathExtension().lastPathComponent
        let fileExtension = destinationURL.pathExtension
        
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let newName = "\(fileNameWithoutExtension) \(counter)"
            destinationURL = downloadsURL.appendingPathComponent(newName).appendingPathExtension(fileExtension)
            counter += 1
        }
        
        do {
            try FileManager.default.copyItem(at: self.url, to: destinationURL)
            
            // Visual feedback: Bounce the dock icon
            NSApplication.shared.requestUserAttention(.informationalRequest)
            
            // Select in Finder so the user knows where it is
            NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: downloadsURL.path)
            
            return destinationURL
        } catch {
            print("Error saving to downloads: \(error)")
            return nil
        }
    }
    
    /// Renames the file and returns a new DroppedItem with the updated URL
    /// Returns nil if rename failed
    func renamed(to newName: String) -> DroppedItem? {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        
        // Ensure we keep the correct extension if user doesn't provide one
        var finalName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentExtension = url.pathExtension
        let newExtension = (finalName as NSString).pathExtension
        
        if newExtension.isEmpty && !currentExtension.isEmpty {
            finalName = finalName + "." + currentExtension
        }
        
        var newURL = directory.appendingPathComponent(finalName)
        
        // Don't rename if it's the same name
        if newURL.path == url.path {
            return nil
        }
        
        // Check if source exists
        if !fileManager.fileExists(atPath: url.path) {
            print("DroppedItem.renamed: Cannot rename - source file not found: \(url.path)")
            return nil
        }
        
        // If destination exists, auto-increment the filename (like Finder does)
        if fileManager.fileExists(atPath: newURL.path) {
            let baseName = newURL.deletingPathExtension().lastPathComponent
            let ext = newURL.pathExtension
            var counter = 1
            
            while fileManager.fileExists(atPath: newURL.path) {
                let incrementedName = ext.isEmpty ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(ext)"
                newURL = directory.appendingPathComponent(incrementedName)
                counter += 1
                
                // Safety limit to prevent infinite loop
                if counter > 100 {
                    print("DroppedItem.renamed: Failed - too many duplicates")
                    return nil
                }
            }
        }
        
        do {
            try fileManager.moveItem(at: url, to: newURL)
            return DroppedItem(url: newURL)
        } catch {
            print("DroppedItem.renamed: Failed to rename: \(error.localizedDescription)")
            return nil
        }
    }
}
