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
        case .quickshare: return QuickActionsCloudProvider.selected.icon
        }
    }
    
    /// Title for the action
    var title: String {
        switch self {
        case .airdrop: return "AirDrop"
        case .messages: return "Messages"
        case .mail: return "Mail"
        case .quickshare: return QuickActionsCloudProvider.selected.quickActionTitle
        }
    }
    
    /// Description explaining what the action does
    var description: String {
        switch self {
        case .airdrop: return "Send files wirelessly to nearby Apple devices"
        case .messages: return "Share files via iMessage or SMS"
        case .mail: return "Attach files to a new email"
        case .quickshare: return QuickActionsCloudProvider.selected.quickActionDescription
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
    
    /// Whether files are being hovered over any quick action button in the shelf
    /// Used to keep shelf quick actions bar visible during drag
    var isShelfQuickActionsTargeted: Bool = false
    
    /// Which quick action is currently being hovered (nil if none)
    /// Used to show action-specific explanations in the basket content area
    var hoveredQuickAction: QuickActionType? = nil
    
    /// Which shelf quick action is currently being hovered (nil if none)
    /// Used to show action-specific explanations in the shelf content area
    var hoveredShelfQuickAction: QuickActionType? = nil
    
    /// Flag to indicate bulk add operation in progress
    /// When true, item transitions are skipped for performance
    var isBulkAdding: Bool = false

    /// Flag to indicate any bulk update (add/remove/move) in progress
    /// Used to disable animations during large changes
    var isBulkUpdating: Bool = false

    /// Threshold for considering an update "bulk"
    private let bulkUpdateThreshold: Int = 6
    
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
        // Use auxiliary areas for stable notch detection (works on lock screen)
        let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        let topInset = screen.safeAreaInsets.top
        let notchHeight = hasPhysicalNotch ? (topInset > 0 ? topInset : NotchLayoutConstants.physicalNotchHeight) : 0
        let isDynamicIsland = NotchLayoutConstants.usesDynamicIslandStyle(for: screen)
        let topPaddingDelta: CGFloat = isDynamicIsland ? 0 : (notchHeight - 20)
        let notchCompensation: CGFloat = isDynamicIsland ? 0 : notchHeight
        
        // Calculate ALL possible content heights
        let terminalHeight: CGFloat = 180 + topPaddingDelta
        let mediaPlayerHeight: CGFloat = 140 + topPaddingDelta
        let telepromptyPromptHeightSetting = UserDefaults.standard.preference(
            AppPreferenceKey.telepromptyPromptHeight,
            default: PreferenceDefault.telepromptyPromptHeight
        )
        let telepromptyContentHeight: CGFloat = TelepromptyManager.shared.isPromptVisible
            ? CGFloat(max(100, min(telepromptyPromptHeightSetting, 260))) + 56
            : (TelepromptyManager.shared.isInlineEditorVisible ? 196 : 110)
        let telepromptyHeight: CGFloat = TelepromptyManager.shared.isShelfViewVisible
            ? (telepromptyContentHeight + 40 + topPaddingDelta)
            : 0

        // TODO shelf bar contributes to expanded height and must be part of hit testing.
        let todoInstalled = UserDefaults.standard.preference(AppPreferenceKey.todoInstalled, default: PreferenceDefault.todoInstalled)
        let todoActive = todoInstalled && !ExtensionType.todo.isRemoved &&
            DroppyState.shared.shelfDisplaySlotCount == 0

        // Use shelfDisplaySlotCount for correct row count - cap at 3 rows (scroll for rest)
        let rowCount = min(ceil(Double(DroppyState.shared.shelfDisplaySlotCount) / 5.0), 3)
        let todoBarHeight: CGFloat = todoActive
            ? ToDoShelfBar.expandedHeight(
                isListExpanded: ToDoManager.shared.isShelfListExpanded,
                itemCount: ToDoManager.shared.items.count,
                notchHeight: notchCompensation,
                showsUndoToast: ToDoManager.shared.showUndoToast
            )
            : 0
        let shouldSkipBaseShelfHeight = DroppyState.shared.shelfDisplaySlotCount == 0 &&
            ToDoManager.shared.isShelfListExpanded &&
            todoBarHeight > 0
        let shelfBaseHeight: CGFloat = shouldSkipBaseShelfHeight
            ? notchCompensation
            : max(1, rowCount) * 116 + notchCompensation
        let shelfHeight: CGFloat = shelfBaseHeight + todoBarHeight
        
        // Use MAXIMUM of all possible heights - guarantees we cover the actual visual
        var height = max(terminalHeight, max(mediaPlayerHeight, max(shelfHeight, telepromptyHeight)))

        // Keep the expanded shadow fully visible.
        // Must match the extra bottom padding in NotchShelfView.morphingBackground.
        let expandedShadowOverflow: CGFloat = 18
        height += expandedShadowOverflow
        
        // DYNAMIC BUTTON SPACE: Only add padding when floating buttons are actually visible
        // TermiNotch button shows when INSTALLED (not just when terminal output is visible)
        // Buttons visible when: TermiNotch is installed OR auto-collapse is disabled OR dragging (Quick Actions bar)
        // Issue #134 FIX: Include isDragging since Quick Actions bar appears during file drags
        let terminalInstalled = UserDefaults.standard.preference(AppPreferenceKey.terminalNotchInstalled, default: PreferenceDefault.terminalNotchInstalled)
        let terminalEnabled = UserDefaults.standard.preference(AppPreferenceKey.terminalNotchEnabled, default: PreferenceDefault.terminalNotchEnabled)
        let terminalButtonVisible = terminalInstalled && terminalEnabled
        let autoCollapseEnabled = (UserDefaults.standard.object(forKey: "autoCollapseShelf") as? Bool) ?? true
        let caffeineInstalled = UserDefaults.standard.preference(AppPreferenceKey.caffeineInstalled, default: PreferenceDefault.caffeineInstalled)
        let caffeineEnabled = UserDefaults.standard.preference(AppPreferenceKey.caffeineEnabled, default: PreferenceDefault.caffeineEnabled)
        let caffeineButtonVisible = caffeineInstalled && caffeineEnabled
        let cameraInstalled = UserDefaults.standard.preference(AppPreferenceKey.cameraInstalled, default: PreferenceDefault.cameraInstalled)
        let cameraEnabled = UserDefaults.standard.preference(AppPreferenceKey.cameraEnabled, default: PreferenceDefault.cameraEnabled)
        let cameraButtonVisible = cameraInstalled && cameraEnabled && !ExtensionType.camera.isRemoved
        let telepromptyInstalled = UserDefaults.standard.preference(AppPreferenceKey.telepromptyInstalled, default: PreferenceDefault.telepromptyInstalled)
        let telepromptyEnabled = UserDefaults.standard.preference(AppPreferenceKey.telepromptyEnabled, default: PreferenceDefault.telepromptyEnabled)
        let telepromptyButtonVisible = telepromptyInstalled && telepromptyEnabled && !ExtensionType.teleprompty.isRemoved
        let isDragging = DragMonitor.shared.isDragging
        let hasFloatingButtons = terminalButtonVisible || !autoCollapseEnabled || isDragging || caffeineButtonVisible || cameraButtonVisible || telepromptyButtonVisible
        
        if hasFloatingButtons {
            // Reserve space for offset + button/bar size + hover/animation headroom.
            // This is dynamic per mode and only applied when controls are actually shown.
            let islandCompensation: CGFloat = isDynamicIsland ? NotchLayoutConstants.floatingButtonIslandCompensation : 0
            let controlHeight: CGFloat = isDragging ? 44 : 32
            let floatingControlsReserve =
                NotchLayoutConstants.floatingButtonGap +
                islandCompensation +
                controlHeight +
                20  // Bottom headroom - prevents clipping
            height += floatingControlsReserve
        }
        
        return height
    }
    
    /// Shared instance for app-wide access
    static let shared = DroppyState()
    
    private init() {}
    
    // MARK: - Item Management (Shelf)
    
    /// Adds a new item to the shelf
    /// - Parameter shouldAutoExpand: When false, keeps shelf collapsed for stacked-peek UX.
    func addItem(_ item: DroppedItem, shouldAutoExpand: Bool = true) {
        // Check for Power Folder (pinned directory) -> DISABLED AUTO-PIN (User Request)
        // Folders are now treated as regular items unless manually pinned
        guard !shelfItems.contains(where: { $0.url == item.url }) else { return }
        shelfItems.append(item)
        if shouldAutoExpand {
            triggerAutoExpand()
        }
        HapticFeedback.drop()
    }
    
    /// Adds multiple items from file URLs
    /// PERFORMANCE: Uses isBulkAdding flag to skip per-item animations for bulk operations
    /// PERFORMANCE: Uses Set for O(1) duplicate checking instead of O(n) contains()
    /// - Parameter shouldAutoExpand: When false, keeps shelf collapsed for stacked-peek UX.
    func addItems(from urls: [URL], shouldAutoExpand: Bool = true) {
        let droppedItems = urls.map { DroppedItem(url: $0) }
        addItems(droppedItems, shouldAutoExpand: shouldAutoExpand)
    }

    /// Adds multiple pre-built dropped items to the shelf (preserves metadata like watched-folder source).
    /// - Parameter shouldAutoExpand: When false, keeps shelf collapsed for stacked-peek UX.
    func addItems(_ droppedItems: [DroppedItem], shouldAutoExpand: Bool = true) {
        guard !droppedItems.isEmpty else { return }
        
        // PERFORMANCE: Skip per-item transitions for bulk adds (>3 items)
        let isBulk = droppedItems.count > 3
        if isBulk {
            isBulkAdding = true
            isBulkUpdating = true
        }
        
        // PERFORMANCE: Build Set of existing URLs for O(1) lookup instead of O(n) contains()
        // This changes duplicate checking from O(n*m) to O(n+m)
        var existingShelfURLs = Set(shelfItems.map(\.url))
        var existingPowerFolderURLs = Set(shelfPowerFolders.map(\.url))
        
        var regularItems: [DroppedItem] = []
        regularItems.reserveCapacity(droppedItems.count) // PERFORMANCE: Pre-allocate array
        
        for item in droppedItems {
            // O(1) duplicate check using Set
            guard !existingShelfURLs.contains(item.url) && !existingPowerFolderURLs.contains(item.url) else {
                continue
            }
            regularItems.append(item)
            existingShelfURLs.insert(item.url)
            existingPowerFolderURLs.insert(item.url)
        }
        
        if !regularItems.isEmpty {
            if isBulk {
                // Keep bulk updates lightweight (no per-item transitions), but still animate
                // container/layout growth so large drops don't visually "snap".
                withAnimation(DroppyAnimation.itemInsertion) {
                    shelfItems.append(contentsOf: regularItems)
                }
                if shouldAutoExpand {
                    triggerAutoExpand()
                }

                // Clear bulk flag after the insertion animation settles.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                    self?.isBulkAdding = false
                    self?.isBulkUpdating = false
                }
            } else {
                withAnimation(DroppyAnimation.state) {
                    shelfItems.append(contentsOf: regularItems)
                }
                if shouldAutoExpand {
                    triggerAutoExpand()
                }
            }
            HapticFeedback.drop()
        } else if isBulk {
            isBulkAdding = false
            isBulkUpdating = false
        }
    }

    func beginBulkUpdateIfNeeded(_ count: Int) {
        guard count > bulkUpdateThreshold else { return }
        isBulkUpdating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isBulkUpdating = false
        }
    }

    private func invalidateThumbnailCache(for item: DroppedItem) {
        ThumbnailCache.shared.invalidate(itemId: item.id)
    }

    private func invalidateThumbnailCache(for items: [DroppedItem]) {
        for item in items {
            ThumbnailCache.shared.invalidate(itemId: item.id)
        }
    }
    
    /// Removes an item from the shelf
    func removeItem(_ item: DroppedItem, allowPinnedRemoval: Bool = false) {
        // Pinned folders are persistent and must be explicitly unpinned before removal.
        guard allowPinnedRemoval || !item.isPinned else { return }

        item.cleanupIfTemporary()
        invalidateThumbnailCache(for: item)
        
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
        beginBulkUpdateIfNeeded(selectedItems.count)
        let idsToRemove = Set(
            items
                .filter { selectedItems.contains($0.id) && !$0.isPinned }
                .map(\.id)
        )

        // Remove from power folders
        for item in shelfPowerFolders.filter({ idsToRemove.contains($0.id) }) {
            item.cleanupIfTemporary()
        }
        invalidateThumbnailCache(for: shelfPowerFolders.filter { idsToRemove.contains($0.id) })
        shelfPowerFolders.removeAll { idsToRemove.contains($0.id) }
        
        // Remove from regular items
        for item in shelfItems.filter({ idsToRemove.contains($0.id) }) {
            item.cleanupIfTemporary()
        }
        invalidateThumbnailCache(for: shelfItems.filter { idsToRemove.contains($0.id) })
        shelfItems.removeAll { idsToRemove.contains($0.id) }
        
        selectedItems.removeAll()
        cleanupTempFoldersIfEmpty()
    }
    
    /// Clears all non-pinned items from the shelf (pinned folders persist)
    func clearAll() {
        beginBulkUpdateIfNeeded(shelfItems.count + shelfPowerFolders.count)

        let removableShelfItems = shelfItems.filter { !$0.isPinned }
        let removablePowerFolders = shelfPowerFolders.filter { !$0.isPinned }

        for item in removableShelfItems {
            item.cleanupIfTemporary()
        }
        invalidateThumbnailCache(for: removableShelfItems)
        for item in removablePowerFolders {
            item.cleanupIfTemporary()
        }
        invalidateThumbnailCache(for: removablePowerFolders)

        shelfItems.removeAll { !$0.isPinned }
        shelfPowerFolders.removeAll { !$0.isPinned }

        selectedItems.removeAll()
        cleanupTempFoldersIfEmpty()
        MemoryRecoveryCoordinator.reclaimTransientMemory(forceAllocatorTrim: false)
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
            removeItem(item, allowPinnedRemoval: true)
        }
    }
    
    /// Validates that all basket items still exist on disk and removes ghost items
    func validateBasketItems() {
        let fileManager = FileManager.default
        let ghostItems = basketItems.filter { !fileManager.fileExists(atPath: $0.url.path) }
        
        for item in ghostItems {
            print("🗑️ Droppy: Removing ghost basket item (file no longer exists): \(item.name)")
            removeBasketItem(item, allowPinnedRemoval: true)
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
            invalidateThumbnailCache(for: oldItem)
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
            invalidateThumbnailCache(for: oldItem)
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
        invalidateThumbnailCache(for: oldItems)
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
        invalidateThumbnailCache(for: oldItems)
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
    /// PERFORMANCE: Uses isBulkAdding flag to skip per-item animations for bulk operations
    func addBasketItems(from urls: [URL]) {
        let droppedItems = urls.map { DroppedItem(url: $0) }
        addBasketItems(droppedItems)
    }

    /// Adds multiple pre-built dropped items to the basket (preserves metadata like watched-folder source).
    func addBasketItems(_ droppedItems: [DroppedItem]) {
        guard !droppedItems.isEmpty else { return }
        
        // PERFORMANCE: Skip per-item transitions for bulk adds (>3 items)
        let isBulk = droppedItems.count > 3
        if isBulk {
            isBulkAdding = true
            isBulkUpdating = true
        }
        
        let enablePowerFolders = UserDefaults.standard.object(forKey: AppPreferenceKey.enablePowerFolders) as? Bool ?? true
        
        var regularItems: [DroppedItem] = []
        var powerFolders: [DroppedItem] = []
        regularItems.reserveCapacity(droppedItems.count) // PERFORMANCE: Pre-allocate array
        
        var existingURLs = Set(basketItemsList.map { $0.url } + basketPowerFolders.map { $0.url })
        
        for item in droppedItems {
            guard !existingURLs.contains(item.url) else { continue }
            existingURLs.insert(item.url)
            
            if item.isDirectory && enablePowerFolders {
                powerFolders.append(item)
            } else {
                regularItems.append(item)
            }
        }
        
        if !regularItems.isEmpty || !powerFolders.isEmpty {
            basketPowerFolders.append(contentsOf: powerFolders)
            basketItemsList.append(contentsOf: regularItems)
            HapticFeedback.drop()
            
            if isBulk {
                // Clear bulk flag after UI settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.isBulkAdding = false
                    self?.isBulkUpdating = false
                }
            }
        } else if isBulk {
            isBulkAdding = false
            isBulkUpdating = false
        }
    }
    
    /// Removes an item from the basket
    func removeBasketItem(_ item: DroppedItem, allowPinnedRemoval: Bool = false) {
        // Pinned folders are persistent and must be explicitly unpinned before removal.
        guard allowPinnedRemoval || !item.isPinned else { return }

        item.cleanupIfTemporary()
        invalidateThumbnailCache(for: item)
        
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
        beginBulkUpdateIfNeeded(basketItemsList.count + basketPowerFolders.count)
        // Cleanup regular non-pinned items
        let removableBasketItems = basketItemsList.filter { !$0.isPinned }
        for item in removableBasketItems {
            item.cleanupIfTemporary()
        }
        invalidateThumbnailCache(for: removableBasketItems)
        basketItemsList.removeAll { !$0.isPinned }
        
        // Only remove unpinned power folders - pinned folders stay
        let unpinnedFolders = basketPowerFolders.filter { !$0.isPinned }
        for item in unpinnedFolders {
            item.cleanupIfTemporary()
        }
        invalidateThumbnailCache(for: unpinnedFolders)
        basketPowerFolders.removeAll { !$0.isPinned }
        
        selectedBasketItems.removeAll()
        cleanupTempFoldersIfEmpty()
        MemoryRecoveryCoordinator.reclaimTransientMemory(forceAllocatorTrim: false)
    }
    
    /// Moves all basket items to the shelf
    func moveBasketToShelf() {
        beginBulkUpdateIfNeeded(basketItemsList.count + basketPowerFolders.count)
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
    /// - Parameter additive: when true (Cmd+Shift), unions with existing selection.
    func selectRange(to item: DroppedItem, additive: Bool = false) {
        let orderedItems = shelfPowerFolders + shelfItems
        let targetIndex = orderedItems.firstIndex(where: { $0.id == item.id })
        guard let targetIndex else {
            select(item)
            return
        }

        // Finder-style fallback: if the explicit anchor is missing/stale, use the first
        // currently selected item in visual order as the temporary range anchor.
        let resolvedAnchorID: UUID? = {
            if let anchor = lastSelectionAnchor,
               orderedItems.contains(where: { $0.id == anchor }) {
                return anchor
            }
            return orderedItems.first(where: { selectedItems.contains($0.id) })?.id
        }()

        guard let anchorID = resolvedAnchorID,
              let anchorIndex = orderedItems.firstIndex(where: { $0.id == anchorID }) else {
            select(item)
            return
        }

        lastSelectionAnchor = anchorID
        
        let start = min(anchorIndex, targetIndex)
        let end = max(anchorIndex, targetIndex)
        
        let rangeIds = orderedItems[start...end].map { $0.id }
        if additive {
            selectedItems.formUnion(rangeIds)
        } else {
            selectedItems = Set(rangeIds)
        }
    }
    
    /// Selects all items
    func selectAll() {
        selectedItems = Set(items.map { $0.id })
        if lastSelectionAnchor == nil {
            lastSelectionAnchor = shelfPowerFolders.first?.id ?? shelfItems.first?.id
        }
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
        let shareURLs = itemsToCopy.map(\.preferredShareURL)
        pasteboard.writeObjects(shareURLs as [NSURL])
        if shareURLs.count == 1, let onlyURL = shareURLs.first, !onlyURL.isFileURL {
            let absolute = onlyURL.absoluteString
            pasteboard.setString(absolute, forType: .URL)
            pasteboard.setString(absolute, forType: .string)
        }
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
