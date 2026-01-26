//
//  DroppyState.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI
import Observation
import AppKit

/// Status of a Quick Share upload operation
enum QuickShareStatus: Equatable {
    case idle
    case uploading
    case success(urls: [String])
    case failed
}

/// Types of quick actions available in the basket
enum QuickActionType: String, CaseIterable {
    case airdrop
    case messages
    case mail
    case quickshare
    
    /// SF Symbol icon for the action
    var icon: String {
        switch self {
        case .airdrop: return "dot.radiowaves.left.and.right"
        case .messages: return "message.fill"
        case .mail: return "envelope.fill"
        case .quickshare: return "drop.fill"
        }
    }
    
    /// Title for the action
    var title: String {
        switch self {
        case .airdrop: return "AirDrop"
        case .messages: return "Messages"
        case .mail: return "Mail"
        case .quickshare: return "Quickshare"
        }
    }
    
    /// Description explaining what the action does
    var description: String {
        switch self {
        case .airdrop: return "Send files wirelessly to nearby Apple devices"
        case .messages: return "Share files via iMessage or SMS"
        case .mail: return "Attach files to a new email"
        case .quickshare: return "Upload to cloud and copy shareable link"
        }
    }
}

/// Main application state for the Droppy shelf
@Observable
final class DroppyState {
    // MARK: - Simple Item Arrays (post-v9.3.0 - stacks removed)
    
    /// Items currently on the shelf (regular files)
    var shelfItems: [DroppedItem] = []
    
    /// Power Folders on shelf (pinned directories)
    var shelfPowerFolders: [DroppedItem] = []
    
    /// Items currently in the basket (regular files)
    var basketItemsList: [DroppedItem] = []
    
    /// Power Folders in basket (pinned directories)
    var basketPowerFolders: [DroppedItem] = []
    
    /// Legacy computed property - returns all shelf items + power folders
    var items: [DroppedItem] {
        get { shelfItems + shelfPowerFolders }
        set {
            shelfItems = newValue.filter { !($0.isPinned && $0.isDirectory) }
            shelfPowerFolders = newValue.filter { $0.isPinned && $0.isDirectory }
        }
    }
    
    /// Legacy computed property - returns all basket items + power folders
    var basketItems: [DroppedItem] {
        get { basketItemsList + basketPowerFolders }
        set {
            basketItemsList = newValue.filter { !($0.isPinned && $0.isDirectory) }
            basketPowerFolders = newValue.filter { $0.isPinned && $0.isDirectory }
        }
    }
    
    /// Number of display slots used on shelf (for grid layout calculations)
    /// Now simply the count of all items
    var shelfDisplaySlotCount: Int {
        shelfItems.count + shelfPowerFolders.count
    }
    
    /// Number of display slots used in basket (for grid layout calculations)
    var basketDisplaySlotCount: Int {
        basketItemsList.count + basketPowerFolders.count
    }
    
    
    /// Whether the shelf is currently visible
    var isShelfVisible: Bool = false
    
    /// Currently selected items for bulk operations
    var selectedItems: Set<UUID> = []
    
    /// Currently selected basket items
    var selectedBasketItems: Set<UUID> = []
    
    /// Position where the shelf should appear (near cursor)
    var shelfPosition: CGPoint = .zero
    
    /// Whether the drop zone is currently targeted (hovered with files)
    var isDropTargeted: Bool = false
    
    /// Which screen (displayID) is currently being drop-targeted
    /// Used to ensure only the correct screen's shelf expands when items are dropped
    var dropTargetDisplayID: CGDirectDisplayID? = nil
    
    /// Tracks which screen (by displayID) has mouse hovering over the notch
    /// Only one screen can show hover effect at a time
    var hoveringDisplayID: CGDirectDisplayID? = nil
    
    /// Convenience property for backwards compatibility - true if ANY screen is being hovered
    var isMouseHovering: Bool {
        get { hoveringDisplayID != nil }
        set {
            if !newValue {
                hoveringDisplayID = nil
            }
            // Note: Setting to true without screen context is deprecated
            // Use setHovering(for:) instead
        }
    }
    
    /// Sets hover state for a specific screen
    func setHovering(for displayID: CGDirectDisplayID, isHovering: Bool) {
        if isHovering {
            hoveringDisplayID = displayID
        } else if hoveringDisplayID == displayID {
            hoveringDisplayID = nil
        }
    }
    
    /// Checks if a specific screen has hover state
    func isHovering(for displayID: CGDirectDisplayID) -> Bool {
        return hoveringDisplayID == displayID
    }
    
    /// Tracks which screen (by displayID) has the shelf expanded
    /// Only one screen can have the shelf expanded at a time to prevent mirroring
    var expandedDisplayID: CGDirectDisplayID? = nil
    
    /// Convenience property for backwards compatibility - true if ANY screen has shelf expanded
    var isExpanded: Bool {
        get { expandedDisplayID != nil }
        set {
            if !newValue {
                expandedDisplayID = nil
            }
            // Note: Setting to true without screen context is deprecated
            // Use expandShelf(for:) instead
        }
    }
    
    /// Expands the shelf on a specific screen (collapses any other expanded shelf)
    func expandShelf(for displayID: CGDirectDisplayID) {
        expandedDisplayID = displayID
        HapticFeedback.expand()
    }
    
    /// Checks if a specific screen has the expanded shelf
    func isExpanded(for displayID: CGDirectDisplayID) -> Bool {
        return expandedDisplayID == displayID
    }
    
    /// Collapses the shelf on a specific screen (only if that screen is expanded)
    func collapseShelf(for displayID: CGDirectDisplayID) {
        if expandedDisplayID == displayID {
            expandedDisplayID = nil
            HapticFeedback.expand()
        }
    }
    
    /// Toggles the shelf expansion on a specific screen
    func toggleShelfExpansion(for displayID: CGDirectDisplayID) {
        if expandedDisplayID == displayID {
            expandedDisplayID = nil
        } else {
            expandedDisplayID = displayID
        }
    }
    
    /// Triggers auto-expansion of the shelf on the most appropriate screen
    /// Called when items are added (from tracked folders, clipboard, etc.)
    func triggerAutoExpand() {
        // Run on main thread to ensure UI/Animation safety
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Check user preference (default: true)
            let autoExpand = (UserDefaults.standard.object(forKey: AppPreferenceKey.autoExpandShelf) as? Bool) ?? true
            guard autoExpand else { return }
            
            // Priority for expansion:
            // 1. Existing expanded shelf (don't switch screens unexpectedly)
            // 2. Screen with mouse cursor (user is likely looking here)
            // 3. Main screen (fallback)
            
            var targetDisplayID: CGDirectDisplayID?
            
            if let current = self.expandedDisplayID {
                targetDisplayID = current
            } else {
                // Find screen containing mouse
                let mouseLocation = NSEvent.mouseLocation
                // Note: NSEvent.mouseLocation is in global coordinates? No, it's screen coordinates.
                // We just need to find which screen frame contains it.
                if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
                    targetDisplayID = screen.displayID
                } else {
                    targetDisplayID = NSScreen.main?.displayID
                }
            }
            
            if let displayID = targetDisplayID {
                withAnimation(DroppyAnimation.interactive) {
                    self.expandShelf(for: displayID)
                }
            }
        }
    }
    
    /// Whether the floating basket is currently visible
    var isBasketVisible: Bool = false
    
    /// Whether the basket is expanded to show items
    var isBasketExpanded: Bool = false
    
    /// Whether files are being hovered over the basket
    var isBasketTargeted: Bool = false
    
    /// Whether files are being hovered over the AirDrop zone in the basket
    var isAirDropZoneTargeted: Bool = false
    
    /// Whether files are being hovered over the AirDrop zone in the shelf
    var isShelfAirDropZoneTargeted: Bool = false
    
    /// Whether files are being hovered over any quick action button in the basket
    /// Used to suppress basket highlight and keep quick actions bar expanded
    var isQuickActionsTargeted: Bool = false
    
    /// Which quick action is currently being hovered (nil if none)
    /// Used to show action-specific explanations in the basket content area
    var hoveredQuickAction: QuickActionType? = nil
    
    /// Whether any rename text field is currently active (blocks spacebar Quick Look)
    var isRenaming: Bool = false
    
    /// Counter for file operations in progress (zip, compress, convert, rename)
    /// Used to prevent auto-hide during these operations
    /// Auto-hide is blocked when this is > 0
    private(set) var fileOperationCount: Int = 0
    
    /// Global flag to block hover interactions (e.g. tooltips) when context menus are open
    var isInteractionBlocked: Bool = false
    
    /// Increment the file operation counter (called at start of operation)
    func beginFileOperation() {
        fileOperationCount += 1
    }
    
    /// Decrement the file operation counter (called at end of operation)
    func endFileOperation() {
        fileOperationCount = max(0, fileOperationCount - 1)
    }
    
    /// Convenience property to check if any operation is in progress
    var isFileOperationInProgress: Bool {
        return fileOperationCount > 0
    }
    
    /// Whether an async sharing operation is in progress (e.g. iCloud upload)
    /// Blocks auto-hiding of the basket window
    var isSharingInProgress: Bool = false
    
    /// Current status of Quick Share upload operation
    /// Used to show uploading/success/failed feedback in the basket UI
    var quickShareStatus: QuickShareStatus = .idle
    
    /// Items currently showing poof animation (for bulk operations)
    /// Each item view observes this and triggers its own animation
    var poofingItemIds: Set<UUID> = []
    
    /// Items currently being processed (for bulk operation spinners)
    /// Each item view observes this to show/hide spinner
    var processingItemIds: Set<UUID> = []
    
    /// Trigger poof animation for a specific item
    func triggerPoof(for itemId: UUID) {
        poofingItemIds.insert(itemId)
    }
    
    /// Clear poof state for an item (called after animation completes)
    func clearPoof(for itemId: UUID) {
        poofingItemIds.remove(itemId)
    }
    
    /// Mark an item as being processed (shows spinner)
    func beginProcessing(for itemId: UUID) {
        processingItemIds.insert(itemId)
    }
    
    /// Mark an item as finished processing (hides spinner)
    func endProcessing(for itemId: UUID) {
        processingItemIds.remove(itemId)
    }
    
    /// Pending converted file ready to download (temp URL, original filename)
    var pendingConversion: (tempURL: URL, filename: String)?
    
    // MARK: - Unified Height Calculator (Issue #64)
    // Single source of truth for expanded shelf hit-test height.
    // CRITICAL: This uses MAX of all possible heights to ensure buttons are ALWAYS clickable.
    // SwiftUI state is complex and hard to replicate - this guarantees interactivity.
    
    /// Calculates the hit-test height for the expanded shelf
    /// Uses MAX of all possible heights to guarantee buttons are always clickable
    /// - Parameter screen: The screen to calculate for (provides notch height)
    /// - Returns: Total hit-test height in points
    static func expandedShelfHeight(for screen: NSScreen) -> CGFloat {
        let notchHeight = screen.safeAreaInsets.top
        let isDynamicIsland = notchHeight <= 0 || UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        let topPaddingDelta: CGFloat = isDynamicIsland ? 0 : (notchHeight - 20)
        let notchCompensation: CGFloat = isDynamicIsland ? 0 : notchHeight
        
        // Calculate ALL possible content heights
        let terminalHeight: CGFloat = 180 + topPaddingDelta
        let mediaPlayerHeight: CGFloat = 140 + topPaddingDelta
        // Use shelfDisplaySlotCount for correct row count
        let rowCount = ceil(Double(DroppyState.shared.shelfDisplaySlotCount) / 5.0)
        let shelfHeight: CGFloat = max(1, rowCount) * 110 + notchCompensation
        
        // Use MAXIMUM of all possible heights - guarantees we cover the actual visual
        var height = max(terminalHeight, max(mediaPlayerHeight, shelfHeight))
        
        // DYNAMIC BUTTON SPACE: Only add padding when floating buttons are actually visible
        // TermiNotch button shows when INSTALLED (not just when terminal output is visible)
        // Buttons visible when: TermiNotch is installed OR auto-collapse is disabled
        let terminalButtonVisible = TerminalNotchManager.shared.isInstalled
        let autoCollapseEnabled = (UserDefaults.standard.object(forKey: "autoCollapseShelf") as? Bool) ?? true
        let hasFloatingButtons = terminalButtonVisible || !autoCollapseEnabled
        
        if hasFloatingButtons {
            // Button offset (12 gap + 6 island) + button height (46) + extra margin = 100pt
            height += 100
        }
        
        return height
    }
    
    /// Shared instance for app-wide access
    static let shared = DroppyState()
    
    private init() {}
    
    // MARK: - Item Management (Shelf)
    
    /// Adds a new item to the shelf
    func addItem(_ item: DroppedItem) {
        // Check for Power Folder (pinned directory)
        let enablePowerFolders = UserDefaults.standard.object(forKey: AppPreferenceKey.enablePowerFolders) as? Bool ?? true
        if item.isDirectory && enablePowerFolders {
            // Power Folders go to separate list
            guard !shelfPowerFolders.contains(where: { $0.url == item.url }) else { return }
            var pinnedItem = item
            pinnedItem.isPinned = true
            shelfPowerFolders.append(pinnedItem)
        } else {
            // Regular items - avoid duplicates
            guard !shelfItems.contains(where: { $0.url == item.url }) else { return }
            shelfItems.append(item)
        }
        triggerAutoExpand()
        HapticFeedback.drop()
    }
    
    /// Adds multiple items from file URLs
    func addItems(from urls: [URL]) {
        let enablePowerFolders = UserDefaults.standard.object(forKey: AppPreferenceKey.enablePowerFolders) as? Bool ?? true
        
        var regularItems: [DroppedItem] = []
        var powerFolders: [DroppedItem] = []
        
        // Get all existing URLs to check for duplicates
        let existingURLs = Set(shelfItems.map { $0.url } + shelfPowerFolders.map { $0.url })
        
        for url in urls {
            // Skip duplicates
            guard !existingURLs.contains(url) else { continue }
            
            let item = DroppedItem(url: url)
            
            // Power Folders: Directories go to separate list
            if item.isDirectory && enablePowerFolders {
                var pinnedItem = item
                pinnedItem.isPinned = true
                powerFolders.append(pinnedItem)
            } else {
                regularItems.append(item)
            }
        }
        
        // Add Power Folders
        shelfPowerFolders.append(contentsOf: powerFolders)
        
        // Add regular items
        if !regularItems.isEmpty {
            shelfItems.append(contentsOf: regularItems)
            triggerAutoExpand()
            HapticFeedback.drop()
        }
        
        if !powerFolders.isEmpty {
            triggerAutoExpand()
            HapticFeedback.drop()
        }
    }
    
    /// Removes an item from the shelf
    func removeItem(_ item: DroppedItem) {
        item.cleanupIfTemporary()
        
        // Remove from power folders
        shelfPowerFolders.removeAll { $0.id == item.id }
        
        // Remove from regular items
        shelfItems.removeAll { $0.id == item.id }
        
        selectedItems.remove(item.id)
        cleanupTempFoldersIfEmpty()
        HapticFeedback.delete()
    }
    
    /// Removes selected items
    func removeSelectedItems() {
        // Remove from power folders
        for item in shelfPowerFolders.filter({ selectedItems.contains($0.id) }) {
            item.cleanupIfTemporary()
        }
        shelfPowerFolders.removeAll { selectedItems.contains($0.id) }
        
        // Remove from regular items
        for item in shelfItems.filter({ selectedItems.contains($0.id) }) {
            item.cleanupIfTemporary()
        }
        shelfItems.removeAll { selectedItems.contains($0.id) }
        
        selectedItems.removeAll()
        cleanupTempFoldersIfEmpty()
    }
    
    /// Clears all items from the shelf
    func clearAll() {
        for item in shelfItems {
            item.cleanupIfTemporary()
        }
        for item in shelfPowerFolders {
            item.cleanupIfTemporary()
        }
        shelfItems.removeAll()
        shelfPowerFolders.removeAll()
        selectedItems.removeAll()
        cleanupTempFoldersIfEmpty()
    }
    
    // MARK: - Folder Pinning
    
    /// Toggles the pinned state of a folder item
    func togglePin(_ item: DroppedItem) {
        // Check shelf items
        if let index = shelfItems.firstIndex(where: { $0.id == item.id }) {
            shelfItems[index].isPinned.toggle()
            savePinnedFolders()
            HapticFeedback.pin()
            return
        }
        
        // Check shelf power folders
        if let index = shelfPowerFolders.firstIndex(where: { $0.id == item.id }) {
            shelfPowerFolders[index].isPinned.toggle()
            savePinnedFolders()
            HapticFeedback.pin()
            return
        }
        
        // Check basket items
        if let index = basketItemsList.firstIndex(where: { $0.id == item.id }) {
            basketItemsList[index].isPinned.toggle()
            savePinnedFolders()
            HapticFeedback.pin()
            return
        }
        
        // Check basket power folders
        if let index = basketPowerFolders.firstIndex(where: { $0.id == item.id }) {
            basketPowerFolders[index].isPinned.toggle()
            savePinnedFolders()
            HapticFeedback.pin()
            return
        }
    }
    
    /// Saves pinned folder URLs to UserDefaults for persistence across sessions
    private func savePinnedFolders() {
        let pinnedURLs = (items + basketItems)
            .filter { $0.isPinned }
            .map { $0.url.absoluteString }
        UserDefaults.standard.set(pinnedURLs, forKey: "pinnedFolderURLs")
    }
    
    /// Restores pinned folders from previous session
    func restorePinnedFolders() {
        guard let savedURLs = UserDefaults.standard.stringArray(forKey: "pinnedFolderURLs") else { return }
        let pinnedSet = Set(savedURLs)
        
        // Restore pinned state for matching items
        for i in items.indices {
            if pinnedSet.contains(items[i].url.absoluteString) {
                items[i].isPinned = true
            }
        }
        for i in basketItems.indices {
            if pinnedSet.contains(basketItems[i].url.absoluteString) {
                basketItems[i].isPinned = true
            }
        }
        
        // Re-add pinned folders that aren't currently in shelf/basket
        let currentURLs = Set((items + basketItems).map { $0.url.absoluteString })
        for urlString in savedURLs {
            guard !currentURLs.contains(urlString),
                  let url = URL(string: urlString),
                  FileManager.default.fileExists(atPath: url.path) else { continue }
            
            var item = DroppedItem(url: url)
            item.isPinned = true
            items.append(item)
        }
    }
    
    /// Validates that all items still exist on disk and removes ghost items
    /// Call this when shelf becomes visible or after drag operations
    func validateItems() {
        let fileManager = FileManager.default
        let ghostItems = items.filter { !fileManager.fileExists(atPath: $0.url.path) }
        
        for item in ghostItems {
            print("🗑️ Droppy: Removing ghost item (file no longer exists): \(item.name)")
            removeItem(item)
        }
    }
    
    /// Validates that all basket items still exist on disk and removes ghost items
    func validateBasketItems() {
        let fileManager = FileManager.default
        let ghostItems = basketItems.filter { !fileManager.fileExists(atPath: $0.url.path) }
        
        for item in ghostItems {
            print("🗑️ Droppy: Removing ghost basket item (file no longer exists): \(item.name)")
            removeBasketItem(item)
        }
    }
    
    /// Cleans up orphaned temp folders when both shelf and basket are empty
    private func cleanupTempFoldersIfEmpty() {
        guard items.isEmpty && basketItems.isEmpty else { return }
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        
        // Clean up DroppyClipboard folder
        let clipboardDir = tempDir.appendingPathComponent("DroppyClipboard")
        if fileManager.fileExists(atPath: clipboardDir.path) {
            try? fileManager.removeItem(at: clipboardDir)
        }
        
        // Clean up DroppyDrops-* folders
        if let contents = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for url in contents {
                if url.lastPathComponent.hasPrefix("DroppyDrops-") {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
    }
    
    /// Replaces an item in the shelf with a new item (for conversions)
    func replaceItem(_ oldItem: DroppedItem, with newItem: DroppedItem) {
        if let index = items.firstIndex(where: { $0.id == oldItem.id }) {
            items[index] = newItem
            // Transfer selection if the old item was selected
            if selectedItems.contains(oldItem.id) {
                selectedItems.remove(oldItem.id)
                selectedItems.insert(newItem.id)
            }
        }
    }
    
    /// Replaces an item in the basket with a new item (for conversions)
    func replaceBasketItem(_ oldItem: DroppedItem, with newItem: DroppedItem) {
        if let index = basketItems.firstIndex(where: { $0.id == oldItem.id }) {
            basketItems[index] = newItem
            // Transfer selection if the old item was selected
            if selectedBasketItems.contains(oldItem.id) {
                selectedBasketItems.remove(oldItem.id)
                selectedBasketItems.insert(newItem.id)
            }
        }
    }
    
    /// Removes multiple items and adds a new item in their place (for ZIP creation)
    /// PERFORMANCE: Atomic replacement prevents momentary empty state that could trigger hide
    func replaceItems(_ oldItems: [DroppedItem], with newItem: DroppedItem) {
        let idsToRemove = Set(oldItems.map { $0.id })
        // Build new array atomically - never empty if newItem is added
        var newItems = items.filter { !idsToRemove.contains($0.id) }
        newItems.append(newItem)
        items = newItems
        // Update selection
        selectedItems.subtract(idsToRemove)
        selectedItems.insert(newItem.id)
    }
    
    /// Removes multiple basket items and adds a new item in their place (for ZIP creation)
    /// PERFORMANCE: Atomic replacement prevents momentary empty state that could trigger hide
    func replaceBasketItems(_ oldItems: [DroppedItem], with newItem: DroppedItem) {
        let idsToRemove = Set(oldItems.map { $0.id })
        // Build new array atomically - never empty if newItem is added
        var newBasketItems = basketItems.filter { !idsToRemove.contains($0.id) }
        newBasketItems.append(newItem)
        basketItems = newBasketItems
        // Update selection
        selectedBasketItems.subtract(idsToRemove)
        selectedBasketItems.insert(newItem.id)
    }
    
    // MARK: - Item Management (Basket)
    
    /// Adds a new item to the basket (creates single-item stack)
    func addBasketItem(_ item: DroppedItem) {
        // Check for Power Folder (directory) - folders are NOT auto-pinned, user must pin manually
        let enablePowerFolders = UserDefaults.standard.object(forKey: AppPreferenceKey.enablePowerFolders) as? Bool ?? true
        if item.isDirectory && enablePowerFolders {
            guard !basketPowerFolders.contains(where: { $0.url == item.url }) else { return }
            basketPowerFolders.append(item)
        } else {
            guard !basketItemsList.contains(where: { $0.url == item.url }) else { return }
            basketItemsList.append(item)
        }
        HapticFeedback.drop()
    }
    
    /// Adds multiple items to the basket from file URLs
    func addBasketItems(from urls: [URL]) {
        let enablePowerFolders = UserDefaults.standard.object(forKey: AppPreferenceKey.enablePowerFolders) as? Bool ?? true
        
        var regularItems: [DroppedItem] = []
        var powerFolders: [DroppedItem] = []
        
        let existingURLs = Set(basketItemsList.map { $0.url } + basketPowerFolders.map { $0.url })
        
        for url in urls {
            guard !existingURLs.contains(url) else { continue }
            
            let item = DroppedItem(url: url)
            
            if item.isDirectory && enablePowerFolders {
                powerFolders.append(item)
            } else {
                regularItems.append(item)
            }
        }
        
        basketPowerFolders.append(contentsOf: powerFolders)
        basketItemsList.append(contentsOf: regularItems)
        
        if !regularItems.isEmpty || !powerFolders.isEmpty {
            HapticFeedback.drop()
        }
    }
    
    /// Removes an item from the basket
    func removeBasketItem(_ item: DroppedItem) {
        item.cleanupIfTemporary()
        
        basketPowerFolders.removeAll { $0.id == item.id }
        basketItemsList.removeAll { $0.id == item.id }
        
        selectedBasketItems.remove(item.id)
        cleanupTempFoldersIfEmpty()
        HapticFeedback.delete()
    }
    
    /// Removes an item from the basket WITHOUT cleanup (for transfers to shelf)
    func removeBasketItemForTransfer(_ item: DroppedItem) {
        basketPowerFolders.removeAll { $0.id == item.id }
        basketItemsList.removeAll { $0.id == item.id }
        selectedBasketItems.remove(item.id)
    }
    
    /// Removes an item from the shelf WITHOUT cleanup (for transfers to basket)
    func removeItemForTransfer(_ item: DroppedItem) {
        shelfPowerFolders.removeAll { $0.id == item.id }
        shelfItems.removeAll { $0.id == item.id }
        selectedItems.remove(item.id)
    }
    
    /// Clears all items from the basket (preserves pinned folders)
    func clearBasket() {
        // Cleanup regular items
        for item in basketItemsList {
            item.cleanupIfTemporary()
        }
        basketItemsList.removeAll()
        
        // Only remove unpinned power folders - pinned folders stay
        let unpinnedFolders = basketPowerFolders.filter { !$0.isPinned }
        for item in unpinnedFolders {
            item.cleanupIfTemporary()
        }
        basketPowerFolders.removeAll { !$0.isPinned }
        
        selectedBasketItems.removeAll()
        cleanupTempFoldersIfEmpty()
    }
    
    /// Moves all basket items to the shelf
    func moveBasketToShelf() {
        // Move power folders
        for folder in basketPowerFolders {
            if !shelfPowerFolders.contains(where: { $0.url == folder.url }) {
                shelfPowerFolders.append(folder)
            }
        }
        
        // Move regular items
        for item in basketItemsList {
            if !shelfItems.contains(where: { $0.url == item.url }) {
                shelfItems.append(item)
            }
        }
        
        // Clear basket without cleanup
        basketItemsList.removeAll()
        basketPowerFolders.removeAll()
        selectedBasketItems.removeAll()
    }
    
    // MARK: - Selection (Shelf)
    
    /// The last item ID that was interacted with (anchor for range selection)
    var lastSelectionAnchor: UUID?
    
    /// Toggles selection for an item
    func toggleSelection(_ item: DroppedItem) {
        lastSelectionAnchor = item.id
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    /// Selects an item exclusively (clears others)
    func select(_ item: DroppedItem) {
        lastSelectionAnchor = item.id
        selectedItems = [item.id]
    }
    
    /// Selects a range from the last anchor to this item (Shift+Click)
    func selectRange(to item: DroppedItem) {
        // If no anchor or anchor not in current items, treated as single select
        guard let anchorId = lastSelectionAnchor,
              let anchorIndex = items.firstIndex(where: { $0.id == anchorId }),
              let targetIndex = items.firstIndex(where: { $0.id == item.id }) else {
            select(item)
            return
        }
        
        let start = min(anchorIndex, targetIndex)
        let end = max(anchorIndex, targetIndex)
        
        let rangeIds = items[start...end].map { $0.id }
        
        // Add range to existing selection (standard macOS behavior depends, but additive is common for Shift)
        // Actually standard macOS behavior for Shift+Click in Finder:
        // - If previous click was single select: extends selection from anchor to target
        // - If previous was Cmd select: extends from anchor to target, preserving others? 
        // Simplest effective behavior: Union the range with existing selection
        selectedItems.formUnion(rangeIds)
        
        // NOTE: We do NOT update lastSelectionAnchor on Shift+Click usually, 
        // allowing successive Shift+Clicks to modify the range from original anchor.
        // But for simplicity here, let's keep the anchor as is or update it?
        // Finder behavior: Click A (anchor=A). Shift-Click C (selects A-C). Shift-Click D (selects A-D).
        // So anchor should remains A! So we do NOT update lastSelectionAnchor.
    }
    
    /// Selects all items
    func selectAll() {
        selectedItems = Set(items.map { $0.id })
    }
    
    /// Deselects all items
    func deselectAll() {
        selectedItems.removeAll()
        lastSelectionAnchor = nil
    }
    
    // MARK: - Selection (Basket)
    
    /// The last basket item ID that was interacted with (anchor for range selection)
    var lastBasketSelectionAnchor: UUID?
    
    /// Toggles selection for a basket item
    func toggleBasketSelection(_ item: DroppedItem) {
        lastBasketSelectionAnchor = item.id
        if selectedBasketItems.contains(item.id) {
            selectedBasketItems.remove(item.id)
        } else {
            selectedBasketItems.insert(item.id)
        }
    }
    
    /// Selects a basket item exclusively
    func selectBasket(_ item: DroppedItem) {
        lastBasketSelectionAnchor = item.id
        selectedBasketItems = [item.id]
    }
    
    /// Selects a range of basket items (Shift+Click)
    func selectBasketRange(to item: DroppedItem) {
        guard let anchorId = lastBasketSelectionAnchor,
              let anchorIndex = basketItems.firstIndex(where: { $0.id == anchorId }),
              let targetIndex = basketItems.firstIndex(where: { $0.id == item.id }) else {
            selectBasket(item)
            return
        }
        
        let start = min(anchorIndex, targetIndex)
        let end = max(anchorIndex, targetIndex)
        
        let rangeIds = basketItems[start...end].map { $0.id }
        selectedBasketItems.formUnion(rangeIds)
    }
    
    /// Selects all basket items
    func selectAllBasket() {
        selectedBasketItems = Set(basketItems.map { $0.id })
    }
    
    /// Deselects all basket items
    func deselectAllBasket() {
        selectedBasketItems.removeAll()
        lastBasketSelectionAnchor = nil
    }
    
    // MARK: - Clipboard
    
    /// Copies all selected items (or all items if none selected) to clipboard
    func copyToClipboard() {
        let itemsToCopy = selectedItems.isEmpty 
            ? items 
            : items.filter { selectedItems.contains($0.id) }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(itemsToCopy.map { $0.url as NSURL })
        HapticFeedback.copy()
    }
    
    // MARK: - Shelf Visibility
    
    /// Shows the shelf at the specified position
    func showShelf(at position: CGPoint) {
        shelfPosition = position
        isShelfVisible = true
    }
    
    /// Hides the shelf
    func hideShelf() {
        isShelfVisible = false
    }
    
    /// Toggles shelf visibility
    func toggleShelf() {
        isShelfVisible.toggle()
    }
}
