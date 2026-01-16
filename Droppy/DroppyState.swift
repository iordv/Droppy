//
//  DroppyState.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI
import Observation

/// Main application state for the Droppy shelf
@Observable
final class DroppyState {
    /// Items currently on the shelf
    var items: [DroppedItem] = []
    
    /// Items currently in the floating basket (separate storage)
    var basketItems: [DroppedItem] = []
    
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
    
    /// Whether the mouse is hovering over the notch (no files)
    var isMouseHovering: Bool = false
    
    /// Whether the shelf is expanded to show items (Notch View)
    var isExpanded: Bool = false
    
    /// Whether the floating basket is currently visible
    var isBasketVisible: Bool = false
    
    /// Whether the basket is expanded to show items
    var isBasketExpanded: Bool = false
    
    /// Whether files are being hovered over the basket
    var isBasketTargeted: Bool = false
    
    /// Whether files are being hovered over the AirDrop zone in the basket
    var isAirDropZoneTargeted: Bool = false
    
    /// Whether any rename text field is currently active (blocks spacebar Quick Look)
    var isRenaming: Bool = false
    
    /// Counter for file operations in progress (zip, compress, convert, rename)
    /// Used to prevent auto-hide during these operations
    /// Auto-hide is blocked when this is > 0
    private(set) var fileOperationCount: Int = 0
    
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
    
    /// Shared instance for app-wide access
    static let shared = DroppyState()
    
    private init() {}
    
    // MARK: - Item Management (Shelf)
    
    /// Adds a new item to the shelf
    func addItem(_ item: DroppedItem) {
        // Avoid duplicates
        guard !items.contains(where: { $0.url == item.url }) else { return }
        items.append(item)
    }
    
    /// Adds multiple items from file URLs
    func addItems(from urls: [URL]) {
        for url in urls {
            let item = DroppedItem(url: url)
            addItem(item)
        }
    }
    
    /// Removes an item from the shelf
    func removeItem(_ item: DroppedItem) {
        item.cleanupIfTemporary()
        items.removeAll { $0.id == item.id }
        selectedItems.remove(item.id)
        cleanupTempFoldersIfEmpty()
    }
    
    /// Removes selected items
    func removeSelectedItems() {
        let itemsToRemove = items.filter { selectedItems.contains($0.id) }
        for item in itemsToRemove {
            item.cleanupIfTemporary()
        }
        items.removeAll { selectedItems.contains($0.id) }
        selectedItems.removeAll()
        cleanupTempFoldersIfEmpty()
    }
    
    /// Clears all items from the shelf
    func clearAll() {
        for item in items {
            item.cleanupIfTemporary()
        }
        items.removeAll()
        selectedItems.removeAll()
        cleanupTempFoldersIfEmpty()
    }
    
    /// Validates that all items still exist on disk and removes ghost items
    /// Call this when shelf becomes visible or after drag operations
    func validateItems() {
        let fileManager = FileManager.default
        let ghostItems = items.filter { !fileManager.fileExists(atPath: $0.url.path) }
        
        for item in ghostItems {
            print("🗑️ Droppy: Removing ghost item (file no longer exists): \(item.name)")
            items.removeAll { $0.id == item.id }
            selectedItems.remove(item.id)
        }
    }
    
    /// Validates that all basket items still exist on disk and removes ghost items
    func validateBasketItems() {
        let fileManager = FileManager.default
        let ghostItems = basketItems.filter { !fileManager.fileExists(atPath: $0.url.path) }
        
        for item in ghostItems {
            print("🗑️ Droppy: Removing ghost basket item (file no longer exists): \(item.name)")
            basketItems.removeAll { $0.id == item.id }
            selectedBasketItems.remove(item.id)
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
    
    /// Adds a new item to the basket
    func addBasketItem(_ item: DroppedItem) {
        // Avoid duplicates
        guard !basketItems.contains(where: { $0.url == item.url }) else { return }
        basketItems.append(item)
    }
    
    /// Adds multiple items to the basket from file URLs
    /// PERFORMANCE: Batched to trigger single state update instead of N updates
    func addBasketItems(from urls: [URL]) {
        let existingURLs = Set(basketItems.map { $0.url })
        let newItems = urls.compactMap { url -> DroppedItem? in
            guard !existingURLs.contains(url) else { return nil }
            return DroppedItem(url: url)
        }
        guard !newItems.isEmpty else { return }
        basketItems.append(contentsOf: newItems)
    }
    
    /// Removes an item from the basket
    func removeBasketItem(_ item: DroppedItem) {
        item.cleanupIfTemporary()
        basketItems.removeAll { $0.id == item.id }
        selectedBasketItems.remove(item.id)
        cleanupTempFoldersIfEmpty()
    }
    
    /// Removes an item from the basket WITHOUT cleanup (for transfers to shelf)
    /// Use this when moving items between collections to preserve the file on disk
    func removeBasketItemForTransfer(_ item: DroppedItem) {
        basketItems.removeAll { $0.id == item.id }
        selectedBasketItems.remove(item.id)
        // NOTE: No cleanupIfTemporary() - file stays on disk for destination collection
    }
    
    /// Removes an item from the shelf WITHOUT cleanup (for transfers to basket)
    /// Use this when moving items between collections to preserve the file on disk
    func removeItemForTransfer(_ item: DroppedItem) {
        items.removeAll { $0.id == item.id }
        selectedItems.remove(item.id)
        // NOTE: No cleanupIfTemporary() - file stays on disk for destination collection
    }
    
    /// Clears all items from the basket
    func clearBasket() {
        for item in basketItems {
            item.cleanupIfTemporary()
        }
        basketItems.removeAll()
        selectedBasketItems.removeAll()
        cleanupTempFoldersIfEmpty()
    }
    
    /// Moves all basket items to the shelf
    func moveBasketToShelf() {
        for item in basketItems {
            addItem(item)
        }
        // Clear arrays without cleanup - files now belong to shelf
        basketItems.removeAll()
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
