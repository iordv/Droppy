//
//  DroppyBarItem.swift
//  Droppy
//
//  Model for an item displayed in the Droppy Bar.
//  Uses ownerName as the key since bundle IDs can be unreliable.
//

import Cocoa
import Combine

/// Represents a menu bar item that can be displayed in the Droppy Bar
struct DroppyBarItem: Identifiable, Codable, Equatable {
    
    /// Unique identifier - uses ownerName since it's more reliable
    var id: String { ownerName }
    
    /// The name of the app that owns this menu bar item (from MenuBarItem.ownerName)
    let ownerName: String
    
    /// Bundle identifier if available (for getting app icon)
    let bundleIdentifier: String?
    
    /// Display name for tooltips and accessibility
    var displayName: String
    
    /// Position in the Droppy Bar (lower = more left)
    var position: Int
    
    /// Whether this item is currently visible in the Droppy Bar
    var isVisible: Bool = true
    
    // MARK: - Initialization
    
    init(ownerName: String, bundleIdentifier: String?, displayName: String, position: Int = 0) {
        self.ownerName = ownerName
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.position = position
    }
    
    // MARK: - Icon
    
    /// Get the icon for this item from the app bundle
    var icon: NSImage? {
        guard let bundleId = bundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}

// MARK: - DroppyBarItemStore

/// Manages persistence of Droppy Bar items
@MainActor
final class DroppyBarItemStore: ObservableObject {
    
    /// Published list of items in the Droppy Bar
    @Published var items: [DroppyBarItem] = []
    
    /// UserDefaults key for storing items
    private let storageKey = "DroppyBarItemsV2"  // New key for new format
    
    // MARK: - Initialization
    
    init() {
        loadItems()
    }
    
    // MARK: - Persistence
    
    /// Load items from UserDefaults
    func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([DroppyBarItem].self, from: data) else {
            items = []
            print("[DroppyBarItemStore] No saved items found")
            return
        }
        items = decoded.sorted { $0.position < $1.position }
        print("[DroppyBarItemStore] Loaded \(items.count) items: \(items.map { $0.ownerName })")
    }
    
    /// Save items to UserDefaults
    func saveItems() {
        guard let encoded = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
        print("[DroppyBarItemStore] Saved \(items.count) items")
    }
    
    // MARK: - Item Management
    
    /// Add an item to the Droppy Bar
    func addItem(_ item: DroppyBarItem) {
        // Don't add duplicates
        guard !items.contains(where: { $0.ownerName == item.ownerName }) else {
            print("[DroppyBarItemStore] Skipping duplicate: \(item.ownerName)")
            return
        }
        var newItem = item
        newItem.position = items.count
        items.append(newItem)
        saveItems()
        print("[DroppyBarItemStore] Added: \(item.ownerName)")
    }
    
    /// Remove an item from the Droppy Bar
    func removeItem(ownerName: String) {
        items.removeAll { $0.ownerName == ownerName }
        reorderPositions()
        saveItems()
    }
    
    /// Move an item to a new position
    func moveItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < items.count,
              destinationIndex >= 0, destinationIndex < items.count else { return }
        
        let item = items.remove(at: sourceIndex)
        items.insert(item, at: destinationIndex)
        reorderPositions()
        saveItems()
    }
    
    /// Reorder positions after changes
    private func reorderPositions() {
        for (index, _) in items.enumerated() {
            items[index].position = index
        }
    }
    
    /// Get owner names of visible items
    var enabledOwnerNames: Set<String> {
        Set(items.filter { $0.isVisible }.map { $0.ownerName })
    }
    
    /// Check if an item exists
    func hasItem(ownerName: String) -> Bool {
        items.contains { $0.ownerName == ownerName }
    }
    
    /// Clear all items
    func clearAll() {
        items.removeAll()
        saveItems()
        print("[DroppyBarItemStore] Cleared all items")
    }
}
