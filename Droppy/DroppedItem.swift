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

/// Represents a file or item dropped onto the Droppy shelf
struct DroppedItem: Identifiable, Hashable, Transferable {
    let id = UUID()
    let url: URL
    let name: String
    let fileType: UTType?
    let icon: NSImage  // PERFORMANCE: UTType-based icon (fast) instead of per-file icon
    var thumbnail: NSImage?
    let dateAdded: Date
    var isTemporary: Bool = false  // Tracks if this file was created as a temp file (conversion, ZIP, etc.)
    
    // Conformance to Transferable using the URL as a proxy
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.url)
    }
    
    init(url: URL, isTemporary: Bool = false) {
        self.url = url
        self.name = url.lastPathComponent
        self.fileType = UTType(filenameExtension: url.pathExtension)
        // PERFORMANCE: Use fast UTType-based icon instead of slow per-file icon
        // NSWorkspace.shared.icon(for: UTType) is ~100x faster than icon(forFile:)
        // for bulk operations. Visual difference is minimal for most files.
        if let type = UTType(filenameExtension: url.pathExtension) {
            self.icon = NSWorkspace.shared.icon(for: type)
        } else {
            self.icon = NSWorkspace.shared.icon(for: .data)
        }
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
    func generateThumbnail(size: CGSize = CGSize(width: 64, height: 64)) async -> NSImage? {
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
            return icon
        }
    }
    
    /// Copies the file to the clipboard (with actual content for images)
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
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
    
    /// Gets the list of applications that can open this file (cached)
    /// Returns an array of (name, icon, URL) tuples sorted by name
    func getAvailableApplications() -> [(name: String, icon: NSImage, url: URL)] {
        let ext = url.pathExtension.lowercased()
        
        // Check cache first
        if let cached = DroppedItem.availableAppsCache[ext],
           Date().timeIntervalSince(cached.timestamp) < DroppedItem.cacheTTL {
            return cached.apps
        }
        
        // Query the system
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: url)
        
        var apps: [(name: String, icon: NSImage, url: URL)] = []
        
        for appURL in appURLs {
            let name = appURL.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            apps.append((name: name, icon: icon, url: appURL))
        }
        
        // Sort by name alphabetically
        let sorted = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        // Cache the result
        DroppedItem.availableAppsCache[ext] = (apps: sorted, timestamp: Date())
        
        return sorted
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

