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
    /// Items currently on the shelf (LEGACY - maintained for backwards compatibility)
    /// Use shelfStacks for new code - this flattens all stacks into a single array
    var items: [DroppedItem] {
        get {
            // Flatten all stacks + power folders into items array
            var allItems: [DroppedItem] = []
            for stack in shelfStacks {
                allItems.append(contentsOf: stack.items)
            }
            allItems.append(contentsOf: shelfPowerFolders)
            return allItems
        }
        set {
            // Direct set clears stacks and creates individual stacks per item
            shelfStacks = newValue.filter { !$0.isPinned || !$0.isDirectory }
                .map { ItemStack(item: $0) }
            shelfPowerFolders = newValue.filter { $0.isPinned && $0.isDirectory }
        }
    }
    
    /// Items currently in the floating basket (LEGACY - maintained for backwards compatibility)
    var basketItems: [DroppedItem] {
        get {
            var allItems: [DroppedItem] = []
            for stack in basketStacks {
                allItems.append(contentsOf: stack.items)
            }
            allItems.append(contentsOf: basketPowerFolders)
            return allItems
        }
        set {
            basketStacks = newValue.filter { !$0.isPinned || !$0.isDirectory }
                .map { ItemStack(item: $0) }
            basketPowerFolders = newValue.filter { $0.isPinned && $0.isDirectory }
        }
    }
    
    // MARK: - Stacked Items Architecture (v9.3.0)
    
    /// Stacks of items for the shelf (groups dropped together)
    var shelfStacks: [ItemStack] = []
    
    /// Stacks of items for the basket
    var basketStacks: [ItemStack] = []
    
    /// Power Folders on shelf (always distinct, never stacked)
    var shelfPowerFolders: [DroppedItem] = []
    
    /// Power Folders in basket (always distinct, never stacked)
    var basketPowerFolders: [DroppedItem] = []
    
    /// Whether stacking mode is enabled (user setting)
    @ObservationIgnored
    var enableStackedView: Bool {
        get { UserDefaults.standard.object(forKey: "enableStackedView") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "enableStackedView") }
    }
    
    /// Number of display slots used on shelf (for grid layout calculations)
    /// Collapsed stacks count as 1, expanded stacks count as their item count + 1 (collapse button)
    var shelfDisplaySlotCount: Int {
        var count = shelfPowerFolders.count
        for stack in shelfStacks {
            if stack.isExpanded {
                count += stack.count + 1  // Items + collapse button
            } else {
                count += 1  // Collapsed stack = 1 slot
            }
        }
        return count
    }
    
    /// Number of display slots used in basket (for grid layout calculations)
    var basketDisplaySlotCount: Int {
        var count = basketPowerFolders.count
        for stack in basketStacks {
            if stack.isExpanded {
                count += stack.count + 1  // Items + collapse button
            } else {
                count += 1  // Collapsed stack = 1 slot
            }
        }
        return count
    }
    
    
    /// Whether the shelf is currently visible
    var isShelfVisible: Bool = false
    
    /// Currently selected items for bulk operations
    var selectedItems: Set<UUID> = []
    
    /// Currently selected basket items
    var selectedBasketItems: Set<UUID> = []
    
    /// Currently selected stacks (by stack ID) for bulk operations
    var selectedStacks: Set<UUID> = []
    
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
        // Use shelfDisplaySlotCount for correct row count (collapsed stacks = 1 slot)
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
    
    /// Adds a new item to the shelf (creates single-item stack)
    func addItem(_ item: DroppedItem) {
        // Check for Power Folder (pinned directory)
        let enablePowerFolders = UserDefaults.standard.object(forKey: AppPreferenceKey.enablePowerFolders) as? Bool ?? true
        if item.isDirectory && enablePowerFolders {
            // Power Folders go to separate list (never stacked)
            guard !shelfPowerFolders.contains(where: { $0.url == item.url }) else { return }
            var pinnedItem = item
            pinnedItem.isPinned = true
            shelfPowerFolders.append(pinnedItem)
        } else {
            // Regular items - avoid duplicates across all stacks
            let allExistingURLs = shelfStacks.flatMap { $0.items.map { $0.url } }
            guard !allExistingURLs.contains(item.url) else { return }
            shelfStacks.append(ItemStack(item: item))
        }
        triggerAutoExpand()
        HapticFeedback.drop()
    }
    
    /// Adds an item to an existing stack (for drag-into-stack feature)
    /// Works for both shelf stacks and basket stacks
    func addItemToStack(_ item: DroppedItem, stackId: UUID) {
        // Try shelf stacks first
        if let stackIndex = shelfStacks.firstIndex(where: { $0.id == stackId }) {
            // Check if item is already in this stack
            guard !shelfStacks[stackIndex].items.contains(where: { $0.url == item.url }) else { return }
            
            // Check if item exists anywhere else - if so, remove it first
            for i in shelfStacks.indices {
                if shelfStacks[i].id != stackId {
                    shelfStacks[i].items.removeAll { $0.url == item.url }
                }
            }
            // Remove empty stacks
            shelfStacks.removeAll { $0.isEmpty }
            
            // Re-find index after modifications (removeAll may have changed indices)
            guard let newStackIndex = shelfStacks.firstIndex(where: { $0.id == stackId }) else { return }
            
            // Add to the target stack
            shelfStacks[newStackIndex].items.append(item)
            triggerAutoExpand()
            return
        }
        
        // Try basket stacks
        if let stackIndex = basketStacks.firstIndex(where: { $0.id == stackId }) {
            // Check if item is already in this stack
            guard !basketStacks[stackIndex].items.contains(where: { $0.url == item.url }) else { return }
            
            // Check if item exists anywhere else in basket - if so, remove it first
            for i in basketStacks.indices {
                if basketStacks[i].id != stackId {
                    basketStacks[i].items.removeAll { $0.url == item.url }
                }
            }
            // Remove empty stacks
            basketStacks.removeAll { $0.isEmpty }
            
            // Re-find index after modifications (removeAll may have changed indices)
            guard let newStackIndex = basketStacks.firstIndex(where: { $0.id == stackId }) else { return }
            
            // Add to the target stack
            basketStacks[newStackIndex].items.append(item)
        }
    }
    
    /// Adds multiple items from file URLs (creates a SINGLE stack for all items)
    /// This is the key method for stacking - items dropped together = one stack
    /// - Parameters:
    ///   - urls: File URLs to add
    ///   - forceStackAppearance: If true, stack always renders as stack even with 1 item (for tracked folders)
    func addItems(from urls: [URL], forceStackAppearance: Bool = false) {
        let enablePowerFolders = UserDefaults.standard.object(forKey: AppPreferenceKey.enablePowerFolders) as? Bool ?? true
        
        var regularItems: [DroppedItem] = []
        var powerFolders: [DroppedItem] = []
        
        // Get all existing URLs to check for duplicates
        let existingURLs = Set(shelfStacks.flatMap { $0.items.map { $0.url } } + shelfPowerFolders.map { $0.url })
        
        for url in urls {
            // Skip duplicates
            guard !existingURLs.contains(url) else { continue }
            
            let item = DroppedItem(url: url)
            
            // Power Folders: Directories go to separate list (always distinct)
            if item.isDirectory && enablePowerFolders {
                var pinnedItem = item
                pinnedItem.isPinned = true
                powerFolders.append(pinnedItem)
            } else {
                regularItems.append(item)
            }
        }
        
        // Add Power Folders individually (never stacked)
        shelfPowerFolders.append(contentsOf: powerFolders)
        
        // Create a SINGLE stack for all regular items dropped together
        if !regularItems.isEmpty {
            var stack = ItemStack(items: regularItems)
            stack.forceStackAppearance = forceStackAppearance
            shelfStacks.append(stack)
            triggerAutoExpand()
            HapticFeedback.drop()
        }
        
        if !powerFolders.isEmpty {
            triggerAutoExpand()
            HapticFeedback.drop()
        }
    }
    
    /// Removes an item from the shelf (from any stack)
    func removeItem(_ item: DroppedItem) {
        item.cleanupIfTemporary()
        
        // Remove from power folders
        shelfPowerFolders.removeAll { $0.id == item.id }
        
        // Remove from stacks
        for i in shelfStacks.indices.reversed() {
            shelfStacks[i].removeItem(withId: item.id)
            // Remove empty stacks
            if shelfStacks[i].isEmpty {
                shelfStacks.remove(at: i)
            }
        }
        
        selectedItems.remove(item.id)
        cleanupTempFoldersIfEmpty()
        HapticFeedback.delete()
    }
    
    /// Removes selected items from all stacks
    func removeSelectedItems() {
        // Remove from power folders
        for item in shelfPowerFolders.filter({ selectedItems.contains($0.id) }) {
            item.cleanupIfTemporary()
        }
        shelfPowerFolders.removeAll { selectedItems.contains($0.id) }
        
        // Remove from stacks
        for i in shelfStacks.indices.reversed() {
            for itemId in selectedItems {
                if let item = shelfStacks[i].items.first(where: { $0.id == itemId }) {
                    item.cleanupIfTemporary()
                }
                shelfStacks[i].removeItem(withId: itemId)
            }
            if shelfStacks[i].isEmpty {
                shelfStacks.remove(at: i)
            }
        }
        
        selectedItems.removeAll()
        cleanupTempFoldersIfEmpty()
    }
    
    /// Clears all items from the shelf
    func clearAll() {
        for stack in shelfStacks {
            stack.cleanupTemporaryFiles()
        }
        for item in shelfPowerFolders {
            item.cleanupIfTemporary()
        }
        shelfStacks.removeAll()
        shelfPowerFolders.removeAll()
        selectedItems.removeAll()
        cleanupTempFoldersIfEmpty()
    }
    
    // MARK: - Stack Management
    
    /// Toggles stack expansion (collapsed ↔ expanded)
    func toggleStackExpansion(_ stackId: UUID) {
        if let index = shelfStacks.firstIndex(where: { $0.id == stackId }) {
            shelfStacks[index].isExpanded.toggle()
        }
        if let index = basketStacks.firstIndex(where: { $0.id == stackId }) {
            basketStacks[index].isExpanded.toggle()
        }
    }
    
    /// Expands a stack
    func expandStack(_ stackId: UUID) {
        if let index = shelfStacks.firstIndex(where: { $0.id == stackId }) {
            shelfStacks[index].isExpanded = true
        }
        if let index = basketStacks.firstIndex(where: { $0.id == stackId }) {
            basketStacks[index].isExpanded = true
        }
    }
    
    /// Collapses a stack
    func collapseStack(_ stackId: UUID) {
        if let index = shelfStacks.firstIndex(where: { $0.id == stackId }) {
            shelfStacks[index].isExpanded = false
        }
        if let index = basketStacks.firstIndex(where: { $0.id == stackId }) {
            basketStacks[index].isExpanded = false
        }
    }
    
    /// Removes an entire stack
    func removeStack(_ stackId: UUID) {
        if let index = shelfStacks.firstIndex(where: { $0.id == stackId }) {
            shelfStacks[index].cleanupTemporaryFiles()
            // Remove all items from selection
            for item in shelfStacks[index].items {
                selectedItems.remove(item.id)
            }
            shelfStacks.remove(at: index)
            cleanupTempFoldersIfEmpty()
            HapticFeedback.delete()
        }
    }
    
    /// Selects all items in a stack (works for both shelf and basket)
    func selectAllInStack(_ stackId: UUID) {
        // Check shelf stacks first
        if let stack = shelfStacks.first(where: { $0.id == stackId }) {
            selectedItems.formUnion(stack.itemIds)
            return
        }
        // Check basket stacks
        if let stack = basketStacks.first(where: { $0.id == stackId }) {
            selectedBasketItems.formUnion(stack.itemIds)
        }
    }
    
    // MARK: - Folder Pinning
    
    /// Toggles the pinned state of a folder item
    func togglePin(_ item: DroppedItem) {
        // Check shelf stacks
        for stackIndex in shelfStacks.indices {
            if let itemIndex = shelfStacks[stackIndex].items.firstIndex(where: { $0.id == item.id }) {
                shelfStacks[stackIndex].items[itemIndex].isPinned.toggle()
                savePinnedFolders()
                HapticFeedback.pin()
                return
            }
        }
        
        // Check shelf power folders
        if let index = shelfPowerFolders.firstIndex(where: { $0.id == item.id }) {
            shelfPowerFolders[index].isPinned.toggle()
            savePinnedFolders()
            HapticFeedback.pin()
            return
        }
        
        // Check basket stacks
        for stackIndex in basketStacks.indices {
            if let itemIndex = basketStacks[stackIndex].items.firstIndex(where: { $0.id == item.id }) {
                basketStacks[stackIndex].items[itemIndex].isPinned.toggle()
                savePinnedFolders()
                HapticFeedback.pin()
                return
            }
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
            let allExistingURLs = basketStacks.flatMap { $0.items.map { $0.url } }
            guard !allExistingURLs.contains(item.url) else { return }
            basketStacks.append(ItemStack(item: item))
        }
        HapticFeedback.drop()
    }
    
    /// Adds multiple items to the basket from file URLs
    /// CHANGED: Each file now creates its OWN separate stack (no auto-stacking)
    /// Users can manually create stacks via context menu > Create Stack
    /// - Parameters:
    ///   - urls: File URLs to add
    ///   - forceStackAppearance: If true, stack always renders as stack even with 1 item (for tracked folders)
    func addBasketItems(from urls: [URL], forceStackAppearance: Bool = false) {
        let enablePowerFolders = UserDefaults.standard.object(forKey: AppPreferenceKey.enablePowerFolders) as? Bool ?? true
        
        var regularItems: [DroppedItem] = []
        var powerFolders: [DroppedItem] = []
        
        let existingURLs = Set(basketStacks.flatMap { $0.items.map { $0.url } } + basketPowerFolders.map { $0.url })
        
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
        
        // CHANGED: Create INDIVIDUAL stacks for each item (no auto-stacking)
        // Users can manually create stacks via right-click > Create Stack
        for item in regularItems {
            var stack = ItemStack(item: item)
            stack.forceStackAppearance = forceStackAppearance
            basketStacks.append(stack)
        }
        
        if !regularItems.isEmpty || !powerFolders.isEmpty {
            HapticFeedback.drop()
        }
    }
    
    /// Adds an existing stack to the basket (preserves stack structure)
    /// Use this when transferring stacks between shelf/basket to maintain grouping
    func addStackToBasket(_ stack: ItemStack) {
        // Check for duplicates
        let existingURLs = Set(basketStacks.flatMap { $0.items.map { $0.url } })
        let newItems = stack.items.filter { !existingURLs.contains($0.url) }
        
        guard !newItems.isEmpty else { return }
        
        // Create new stack with filtered items (preserving stack identity)
        var newStack = stack
        newStack.items = newItems
        basketStacks.append(newStack)
        HapticFeedback.drop()
    }
    
    /// Adds an existing stack to the shelf (preserves stack structure)
    /// Use this when transferring stacks between basket/shelf to maintain grouping
    func addStackToShelf(_ stack: ItemStack) {
        // Check for duplicates
        let existingURLs = Set(shelfStacks.flatMap { $0.items.map { $0.url } })
        let newItems = stack.items.filter { !existingURLs.contains($0.url) }
        
        guard !newItems.isEmpty else { return }
        
        // Create new stack with filtered items (preserving stack identity)
        var newStack = stack
        newStack.items = newItems
        shelfStacks.append(newStack)
        HapticFeedback.drop()
    }
    
    /// Removes an item from the basket (from any stack)
    func removeBasketItem(_ item: DroppedItem) {
        item.cleanupIfTemporary()
        
        basketPowerFolders.removeAll { $0.id == item.id }
        
        for i in basketStacks.indices.reversed() {
            basketStacks[i].removeItem(withId: item.id)
            if basketStacks[i].isEmpty {
                basketStacks.remove(at: i)
            }
        }
        
        selectedBasketItems.remove(item.id)
        cleanupTempFoldersIfEmpty()
        HapticFeedback.delete()
    }
    
    /// Removes an item from the basket WITHOUT cleanup (for transfers to shelf)
    func removeBasketItemForTransfer(_ item: DroppedItem) {
        basketPowerFolders.removeAll { $0.id == item.id }
        
        for i in basketStacks.indices.reversed() {
            basketStacks[i].removeItem(withId: item.id)
            if basketStacks[i].isEmpty {
                basketStacks.remove(at: i)
            }
        }
        
        selectedBasketItems.remove(item.id)
    }
    
    /// Removes an item from the shelf WITHOUT cleanup (for transfers to basket)
    func removeItemForTransfer(_ item: DroppedItem) {
        shelfPowerFolders.removeAll { $0.id == item.id }
        
        for i in shelfStacks.indices.reversed() {
            shelfStacks[i].removeItem(withId: item.id)
            if shelfStacks[i].isEmpty {
                shelfStacks.remove(at: i)
            }
        }
        
        selectedItems.remove(item.id)
    }
    
    /// Clears all items from the basket (preserves pinned folders)
    func clearBasket() {
        // Cleanup and remove all stacks
        for stack in basketStacks {
            stack.cleanupTemporaryFiles()
        }
        basketStacks.removeAll()
        
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
        
        // Move stacks (merge all items into a single new stack)
        var allItems: [DroppedItem] = []
        for stack in basketStacks {
            allItems.append(contentsOf: stack.items)
        }
        if !allItems.isEmpty {
            shelfStacks.append(ItemStack(items: allItems))
        }
        
        // Clear basket without cleanup
        basketStacks.removeAll()
        basketPowerFolders.removeAll()
        selectedBasketItems.removeAll()
    }
    
    /// Removes a basket stack by ID
    func removeBasketStack(_ stackId: UUID) {
        if let index = basketStacks.firstIndex(where: { $0.id == stackId }) {
            basketStacks[index].cleanupTemporaryFiles()
            for item in basketStacks[index].items {
                selectedBasketItems.remove(item.id)
            }
            basketStacks.remove(at: index)
            cleanupTempFoldersIfEmpty()
            HapticFeedback.delete()
        }
    }
    
    /// Selects all items in a basket stack
    func selectAllInBasketStack(_ stackId: UUID) {
        if let stack = basketStacks.first(where: { $0.id == stackId }) {
            selectedBasketItems.formUnion(stack.itemIds)
        }
    }
    
    /// Toggles expansion state of a basket stack
    func toggleBasketStackExpansion(_ stackId: UUID) {
        if let index = basketStacks.firstIndex(where: { $0.id == stackId }) {
            basketStacks[index].isExpanded.toggle()
        }
    }
    
    /// Collapses a basket stack (explicit collapse for UI button)
    func collapseBasketStack(_ stackId: UUID) {
        if let index = basketStacks.firstIndex(where: { $0.id == stackId }) {
            basketStacks[index].isExpanded = false
        }
    }
    
    /// Creates a new stack from selected basket items (manual stacking)
    /// Requires at least 2 items selected
    /// Returns true if stack was created successfully
    @discardableResult
    func createStackFromSelectedBasketItems() -> Bool {
        // Need at least 2 items to create a stack
        guard selectedBasketItems.count >= 2 else { return false }
        
        // Collect all selected items from across all stacks
        var itemsToStack: [DroppedItem] = []
        var stackIndicesToRemove: [Int] = []
        
        for (index, stack) in basketStacks.enumerated() {
            let selectedFromStack = stack.items.filter { selectedBasketItems.contains($0.id) }
            if !selectedFromStack.isEmpty {
                itemsToStack.append(contentsOf: selectedFromStack)
                
                // Check if we're taking ALL items from this stack
                if selectedFromStack.count == stack.items.count {
                    stackIndicesToRemove.append(index)
                }
            }
        }
        
        guard itemsToStack.count >= 2 else { return false }
        
        // Remove items from their original stacks
        for itemId in selectedBasketItems {
            for i in basketStacks.indices {
                basketStacks[i].items.removeAll { $0.id == itemId }
            }
        }
        
        // Remove now-empty stacks (in reverse order to maintain indices)
        for index in stackIndicesToRemove.sorted().reversed() {
            if basketStacks[index].isEmpty {
                basketStacks.remove(at: index)
            }
        }
        
        // Also clean up any other empty stacks
        basketStacks.removeAll { $0.isEmpty }
        
        // Create the new stack with all selected items
        let newStack = ItemStack(items: itemsToStack)
        basketStacks.append(newStack)
        
        // Clear selection
        selectedBasketItems.removeAll()
        
        HapticFeedback.drop()
        return true
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
        selectedStacks.removeAll()
        lastSelectionAnchor = nil
    }
    
    // MARK: - Selection (Stacks)
    
    /// Selects a single stack (clears other stack selections)
    func selectStack(_ stack: ItemStack) {
        selectedStacks = [stack.id]
        // Also select all items within the stack
        selectedItems.formUnion(stack.itemIds)
    }
    
    /// Toggles selection of a stack (for Cmd+Click)
    func toggleStackSelection(_ stack: ItemStack) {
        if selectedStacks.contains(stack.id) {
            selectedStacks.remove(stack.id)
            selectedItems.subtract(stack.itemIds)
        } else {
            selectedStacks.insert(stack.id)
            selectedItems.formUnion(stack.itemIds)
        }
    }
    
    /// Checks if a stack is selected
    func isStackSelected(_ stack: ItemStack) -> Bool {
        selectedStacks.contains(stack.id)
    }
    
    /// Selects all stacks
    func selectAllStacks() {
        selectedStacks = Set(shelfStacks.map { $0.id })
        // Also select all items within all stacks
        for stack in shelfStacks {
            selectedItems.formUnion(stack.itemIds)
        }
    }
    
    /// Deselects all stacks
    func deselectAllStacks() {
        selectedStacks.removeAll()
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
        selectedBasketStacks.removeAll()
        lastBasketSelectionAnchor = nil
    }
    
    /// Selected basket stacks (by stack ID)
    var selectedBasketStacks: Set<UUID> = []
    
    /// Selects all basket stacks
    func selectAllBasketStacks() {
        selectedBasketStacks = Set(basketStacks.map { $0.id })
        // Also select all items within all stacks
        for stack in basketStacks {
            selectedBasketItems.formUnion(stack.itemIds)
        }
    }
    
    /// Deselects all basket stacks
    func deselectAllBasketStacks() {
        selectedBasketStacks.removeAll()
    }
    
    /// Checks if a basket stack is selected
    func isBasketStackSelected(_ stack: ItemStack) -> Bool {
        selectedBasketStacks.contains(stack.id)
    }
    
    /// Toggles basket stack selection
    func toggleBasketStackSelection(_ stack: ItemStack) {
        if selectedBasketStacks.contains(stack.id) {
            selectedBasketStacks.remove(stack.id)
            selectedBasketItems.subtract(stack.itemIds)
        } else {
            selectedBasketStacks.insert(stack.id)
            selectedBasketItems.formUnion(stack.itemIds)
        }
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
