//
//  TrackedFoldersManager.swift
//  Droppy
//
//  Monitors specified folders for new files and triggers shelf/basket display
//  Uses DispatchSource for efficient file system monitoring
//

import Foundation
import Combine
import AppKit

// MARK: - Watched Folder Model

/// Represents a folder being monitored for new files
struct WatchedFolder: Codable, Identifiable, Equatable {
    let id: UUID
    let bookmarkData: Data  // Security-scoped bookmark for persistent access
    var destination: TrackedFolderDestination
    
    /// Resolve the URL from the security-scoped bookmark
    func resolveURL() -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        
        // Start accessing security-scoped resource
        _ = url.startAccessingSecurityScopedResource()
        return url
    }
    
    /// Display name for the folder
    var displayName: String {
        resolveURL()?.lastPathComponent ?? "Unknown Folder"
    }
    
    /// Full path for display
    var displayPath: String {
        resolveURL()?.path ?? "Unknown Path"
    }
}

/// Where to show new files from watched folders
enum TrackedFolderDestination: String, Codable, CaseIterable {
    case shelf = "shelf"
    case basket = "basket"
    
    var displayName: String {
        switch self {
        case .shelf: return "Notch Shelf"
        case .basket: return "Floating Basket"
        }
    }
    
    var icon: String {
        switch self {
        case .shelf: return "rectangle.topthird.inset.filled"
        case .basket: return "tray.and.arrow.down"
        }
    }
}

// MARK: - Folder Observation Manager

/// Manages folder monitoring and triggers shelf/basket display for new files
@MainActor
final class TrackedFoldersManager: ObservableObject {
    static let shared = TrackedFoldersManager()
    
    // MARK: - Published State
    
    @Published private(set) var watchedFolders: [WatchedFolder] = []
    @Published private(set) var isMonitoring: Bool = false
    
    // MARK: - Private Properties
    
    private var folderMonitors: [UUID: DispatchSourceFileSystemObject] = [:]
    private var folderContents: [UUID: Set<String>] = [:]  // Track existing files
    private let monitorQueue = DispatchQueue(label: "com.droppy.trackedFolders", qos: .utility)
    
    /// Pending files waiting to be batched (per folder)
    private var pendingFiles: [UUID: Set<URL>] = [:]
    /// Debounce work items (per folder)
    private var debounceWorkItems: [UUID: DispatchWorkItem] = [:]
    /// Debounce delay - collect files for this long before creating stack
    private let debounceDelay: TimeInterval = 0.5
    /// Temporary/in-progress download artifacts we should never surface in Shelf/Basket.
    private let transientDownloadExtensions: Set<String> = [
        "download",     // Safari
        "crdownload",   // Chrome/Chromium
        "part",         // Firefox/others
        "partial",
        "filepart",
        "opdownload",   // Opera
        "aria2",        // aria2
        "tmp",
        "temp"
    ]
    
    private let userDefaultsKey = "trackedFoldersFolders"
    
    // MARK: - Initialization
    
    private init() {
        loadFolders()
    }
    
    // MARK: - Public API
    
    /// Add a folder to monitor
    func addFolder(_ url: URL, destination: TrackedFolderDestination) {
        // Create security-scoped bookmark for persistent access
        guard let bookmarkData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            print("TrackedFolders: Failed to create bookmark for \(url.path)")
            return
        }
        
        let folder = WatchedFolder(
            id: UUID(),
            bookmarkData: bookmarkData,
            destination: destination
        )
        
        watchedFolders.append(folder)
        saveFolders()
        
        // Start monitoring if enabled
        if isMonitoring {
            startMonitoringFolder(folder)
        }
        
        print("TrackedFolders: Added folder \(url.lastPathComponent) → \(destination.displayName)")
    }
    
    /// Remove a folder from monitoring
    func removeFolder(_ id: UUID) {
        stopMonitoringFolder(id)
        watchedFolders.removeAll { $0.id == id }
        saveFolders()
        print("TrackedFolders: Removed folder")
    }
    
    /// Update destination for a folder
    func updateDestination(for id: UUID, to destination: TrackedFolderDestination) {
        if let index = watchedFolders.firstIndex(where: { $0.id == id }) {
            watchedFolders[index].destination = destination
            saveFolders()
            print("TrackedFolders: Updated \(watchedFolders[index].displayName) → \(destination.displayName)")
        }
    }
    
    /// Start monitoring all folders
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        for folder in watchedFolders {
            startMonitoringFolder(folder)
        }
        
        print("TrackedFolders: Started monitoring \(watchedFolders.count) folder(s)")
    }
    
    /// Stop monitoring all folders
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        
        for id in folderMonitors.keys {
            stopMonitoringFolder(id)
        }
        
        print("TrackedFolders: Stopped monitoring")
    }
    
    // MARK: - Private Methods
    
    private func startMonitoringFolder(_ folder: WatchedFolder) {
        guard let url = folder.resolveURL() else {
            print("TrackedFolders: Could not resolve URL for folder \(folder.id)")
            return
        }
        
        // Get initial folder contents
        let initialFiles = getFolderContents(url)
        folderContents[folder.id] = initialFiles
        
        // Create file descriptor for monitoring
        let fd = open(url.path, O_EVTONLY)
        guard fd != -1 else {
            print("TrackedFolders: Could not open folder \(url.lastPathComponent)")
            return
        }
        
        // Create dispatch source for file system events
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,  // Triggered when files are added/modified
            queue: monitorQueue
        )
        
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleFolderChange(folder)
            }
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        source.resume()
        folderMonitors[folder.id] = source
        
        print("TrackedFolders: Now monitoring \(url.lastPathComponent)")
    }
    
    private func stopMonitoringFolder(_ id: UUID) {
        if let source = folderMonitors[id] {
            source.cancel()
            folderMonitors.removeValue(forKey: id)
        }
        folderContents.removeValue(forKey: id)
    }
    
    private func handleFolderChange(_ folder: WatchedFolder) {
        guard let url = folder.resolveURL() else { return }
        
        let currentFiles = getFolderContents(url)
        let previousFiles = folderContents[folder.id] ?? []
        
        // Find new files (in current but not in previous)
        let newFiles = currentFiles.subtracting(previousFiles)
        
        if !newFiles.isEmpty {
            // Update tracked contents immediately
            folderContents[folder.id] = currentFiles
            
            // Create URLs for new files
            let newFileURLs = Set(newFiles.map { url.appendingPathComponent($0) })
            
            // Add to pending batch
            if pendingFiles[folder.id] == nil {
                pendingFiles[folder.id] = []
            }
            pendingFiles[folder.id]?.formUnion(newFileURLs)
            
            print("TrackedFolders: Batching \(newFiles.count) new file(s) from \(url.lastPathComponent)")
            
            // Cancel existing debounce timer
            debounceWorkItems[folder.id]?.cancel()
            
            // Schedule new debounce timer
            let folderId = folder.id
            let workItem = DispatchWorkItem { [weak self] in
                Task { @MainActor [weak self] in
                    self?.flushPendingFiles(for: folderId)
                }
            }
            debounceWorkItems[folder.id] = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        }
    }
    
    /// Flush pending files for a folder as a single stack
    private func flushPendingFiles(for folderId: UUID) {
        guard let urls = pendingFiles[folderId], !urls.isEmpty else { return }
        
        // Look up folder fresh to get current destination setting
        guard let folder = watchedFolders.first(where: { $0.id == folderId }) else { return }
        
        // Clear pending
        pendingFiles[folderId] = nil
        debounceWorkItems[folderId] = nil
        
        let urlArray = Array(urls)
            .filter { shouldTrackFile(url: $0) }
        guard !urlArray.isEmpty else {
            return
        }
        let state = DroppyState.shared
        
        print("TrackedFolders: Flushing \(urlArray.count) file(s) to \(folder.destination.displayName)")
        
        switch folder.destination {
        case .shelf:
            // Add all pending files to shelf
            state.addItems(from: urlArray)
            state.isExpanded = true  // This expands the notch shelf
            print("TrackedFolders: Added \(urlArray.count) file(s) to Shelf")
            
        case .basket:
            // Check if multi-basket mode is on and we have 2+ baskets
            let multiBasketEnabled = UserDefaults.standard.preference(
                AppPreferenceKey.enableMultiBasket,
                default: PreferenceDefault.enableMultiBasket
            )
            var allBaskets: [FloatingBasketWindowController] = FloatingBasketWindowController.visibleBaskets
            for basket in FloatingBasketWindowController.basketsWithItems where !allBaskets.contains(where: { $0 === basket }) {
                allBaskets.append(basket)
            }
            
            if multiBasketEnabled && allBaskets.count >= 2 {
                // Show switcher so user can pick which basket to add to
                // Store the URLs to add after user selects a basket
                let pendingURLs = urlArray
                BasketSwitcherWindowController.shared.showForTrackedFolder(
                    baskets: allBaskets,
                    pendingFiles: pendingURLs
                ) { selectedBasket in
                    selectedBasket.basketState.addItems(from: pendingURLs)
                    selectedBasket.showBasket(atLastPosition: true)
                }
                print("TrackedFolders: Showing switcher for \(urlArray.count) file(s)")
            } else {
                // Single basket or only 1 basket active - add directly
                FloatingBasketWindowController.addItemsFromExternalSource(urlArray, showAtLastPosition: true)
                print("TrackedFolders: Added \(urlArray.count) file(s) to Basket")
            }
        }
    }
    
    private func getFolderContents(_ url: URL) -> Set<String> {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: url.path) else {
            return []
        }
        return Set(contents.filter { shouldTrackFileName($0) })
    }

    private func shouldTrackFileName(_ name: String) -> Bool {
        // Ignore hidden files and known temporary download artifacts.
        if name.hasPrefix(".") {
            return false
        }
        return !isTransientDownloadArtifact(name)
    }

    private func shouldTrackFile(url: URL) -> Bool {
        if !FileManager.default.fileExists(atPath: url.path) {
            return false
        }
        return shouldTrackFileName(url.lastPathComponent)
    }

    private func isTransientDownloadArtifact(_ name: String) -> Bool {
        let normalized = name.lowercased()
        let ext = (normalized as NSString).pathExtension
        if !ext.isEmpty && transientDownloadExtensions.contains(ext) {
            return true
        }
        return false
    }
    
    // MARK: - Persistence
    
    private func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let folders = try? JSONDecoder().decode([WatchedFolder].self, from: data) else {
            return
        }
        watchedFolders = folders
    }
    
    private func saveFolders() {
        guard let data = try? JSONEncoder().encode(watchedFolders) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}
