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
        item.cleanupIfTemporary()  // Clean up temp file before removing
        items.removeAll { $0.id == item.id }
        selectedItems.remove(item.id)
    }
    
    /// Removes selected items
    func removeSelectedItems() {
        items.removeAll { selectedItems.contains($0.id) }
        selectedItems.removeAll()
    }
    
    /// Clears all items from the shelf
    func clearAll() {
        for item in items {
            item.cleanupIfTemporary()  // Clean up each temp file
        }
        items.removeAll()
        selectedItems.removeAll()
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
    func replaceItems(_ oldItems: [DroppedItem], with newItem: DroppedItem) {
        for oldItem in oldItems {
            items.removeAll { $0.id == oldItem.id }
            selectedItems.remove(oldItem.id)
        }
        items.append(newItem)
        selectedItems.insert(newItem.id)
    }
    
    /// Removes multiple basket items and adds a new item in their place (for ZIP creation)
    func replaceBasketItems(_ oldItems: [DroppedItem], with newItem: DroppedItem) {
        for oldItem in oldItems {
            basketItems.removeAll { $0.id == oldItem.id }
            selectedBasketItems.remove(oldItem.id)
        }
        basketItems.append(newItem)
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
    func addBasketItems(from urls: [URL]) {
        for url in urls {
            let item = DroppedItem(url: url)
            addBasketItem(item)
        }
    }
    
    /// Removes an item from the basket
    func removeBasketItem(_ item: DroppedItem) {
        item.cleanupIfTemporary()  // Clean up temp file before removing
        basketItems.removeAll { $0.id == item.id }
        selectedBasketItems.remove(item.id)
    }
    
    /// Clears all items from the basket
    func clearBasket() {
        for item in basketItems {
            item.cleanupIfTemporary()  // Clean up each temp file
        }
        basketItems.removeAll()
        selectedBasketItems.removeAll()
    }
    
    /// Moves all basket items to the shelf
    func moveBasketToShelf() {
        for item in basketItems {
            addItem(item)
        }
        clearBasket()
    }
    
    // MARK: - Selection (Shelf)
    
    /// Toggles selection for an item
    func toggleSelection(_ item: DroppedItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    /// Selects all items
    func selectAll() {
        selectedItems = Set(items.map { $0.id })
    }
    
    /// Deselects all items
    func deselectAll() {
        selectedItems.removeAll()
    }
    
    // MARK: - Selection (Basket)
    
    /// Toggles selection for a basket item
    func toggleBasketSelection(_ item: DroppedItem) {
        if selectedBasketItems.contains(item.id) {
            selectedBasketItems.remove(item.id)
        } else {
            selectedBasketItems.insert(item.id)
        }
    }
    
    /// Selects all basket items
    func selectAllBasket() {
        selectedBasketItems = Set(basketItems.map { $0.id })
    }
    
    /// Deselects all basket items
    func deselectAllBasket() {
        selectedBasketItems.removeAll()
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
