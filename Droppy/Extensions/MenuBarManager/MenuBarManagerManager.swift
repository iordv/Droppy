//
//  MenuBarManager.swift
//  Droppy
//
//  Menu Bar Manager - Hide/show menu bar icons using divider expansion
//  Uses two NSStatusItems: a visible toggle button and an expanding divider
//

import SwiftUI
import AppKit
import Combine

// MARK: - Menu Bar Manager

@MainActor
final class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()
    
    // MARK: - Published State
    
    /// Whether the extension is enabled
    @Published private(set) var isEnabled = false
    
    /// Whether hidden icons are currently expanded (visible)
    @Published private(set) var isExpanded = true
    

    
    /// Whether the Droppy Bar is enabled (shows when expanding menu bar icons)
    @Published var droppyBarEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(droppyBarEnabled, forKey: droppyBarEnabledKey)
            // Bar visibility is now controlled by isExpanded, not separate toggle
            if droppyBarEnabled && isExpanded {
                showDroppyBar()
            } else {
                hideDroppyBar()
            }
        }
    }
    
    // MARK: - Status Items
    
    /// The visible toggle button - always shows dot, click to toggle
    private var toggleItem: NSStatusItem?
    
    /// The invisible divider that expands to push items off-screen
    private var dividerItem: NSStatusItem?
    
    /// Autosave names for position persistence
    private let toggleAutosaveName = "DroppyMenuBarToggle"
    private let dividerAutosaveName = "DroppyMenuBarDivider"
    
    // MARK: - Droppy Bar
    
    /// The floating Droppy Bar panel
    private var droppyBarPanel: DroppyBarPanel?
    
    /// Item store for Droppy Bar
    private let droppyBarItemStore = DroppyBarItemStore()
    
    /// Cover panel that hides selected menu bar items
    private var coverPanel: MenuBarCoverPanel?
    
    /// Combine cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()
    

    // MARK: - Constants
    
    /// Standard length for toggle (shows chevron)
    private let toggleLength: CGFloat = NSStatusItem.variableLength
    
    /// Standard length for divider (shows icon)
    private let dividerStandardLength: CGFloat = NSStatusItem.variableLength
    
    /// Expanded length to push items off-screen
    private let dividerExpandedLength: CGFloat = 10_000
    
    // MARK: - Persistence Keys
    
    private let enabledKey = "menuBarManagerEnabled"
    private let expandedKey = "menuBarManagerExpanded"

    private let droppyBarEnabledKey = "droppyBarEnabled"
    
    // MARK: - Initialization
    
    private init() {
        // Only start if extension is not removed
        guard !ExtensionType.menuBarManager.isRemoved else { return }
        

        
        // Load Droppy Bar preference (don't trigger didSet during init)
        let savedDroppyBarEnabled = UserDefaults.standard.bool(forKey: droppyBarEnabledKey)
        
        if UserDefaults.standard.bool(forKey: enabledKey) {
            enable()
        }
        
        // Show Droppy Bar after setup if it was enabled
        if savedDroppyBarEnabled {
            droppyBarEnabled = true
        }
    }
    
    // MARK: - Public API
    
    /// Get the Droppy Bar item store for configuration
    func getDroppyBarItemStore() -> DroppyBarItemStore {
        droppyBarItemStore
    }
    
    /// Enable the menu bar manager
    func enable() {
        guard !isEnabled else { return }
        
        // FIX: Clear any stale removed state when explicitly enabling
        // This fixes the singleton resurrection bug where init guard failed
        // but user later tries to enable via Extensions UI
        if ExtensionType.menuBarManager.isRemoved {
            print("[MenuBarManager] Clearing stale removed state")
            ExtensionType.menuBarManager.setRemoved(false)
        }
        
        isEnabled = true
        UserDefaults.standard.set(true, forKey: enabledKey)
        
        // Create both status items
        createStatusItems()
        
        // Create cover panel for hiding selected items
        setupCoverPanel()
        
        // Subscribe to item store changes to auto-hide selected items
        setupItemStoreSubscription()
        
        // Restore previous expansion state, or default to expanded (showing all icons)
        if UserDefaults.standard.object(forKey: expandedKey) != nil {
            isExpanded = UserDefaults.standard.bool(forKey: expandedKey)
        } else {
            isExpanded = true
        }
        applyExpansionState()
        
        // Apply cover for any already-selected items
        updateCoverForSelectedItems()
        
        print("[MenuBarManager] Enabled, expanded: \(isExpanded)")
    }
    
    /// Disable the menu bar manager
    func disable() {
        guard isEnabled else { return }
        
        isEnabled = false
        UserDefaults.standard.set(false, forKey: enabledKey)
        
        // Clean up cover panel
        coverPanel?.stopAutoUpdate()
        coverPanel?.clearCover()
        coverPanel = nil
        cancellables.removeAll()
        
        // Show all items before removing
        if !isExpanded {
            isExpanded = true
            applyExpansionState()
        }
        
        // Remove both status items
        removeStatusItems()
        
        print("[MenuBarManager] Disabled")
    }
    
    /// Toggle between expanded and collapsed states
    func toggleExpanded() {
        isExpanded.toggle()

        UserDefaults.standard.set(isExpanded, forKey: expandedKey)
        applyExpansionState()
        
        // Also toggle Droppy Bar if enabled
        if droppyBarEnabled {
            if isExpanded {
                showDroppyBar()
            } else {
                hideDroppyBar()
            }
        }
        
        // Notify to refresh Droppy menu
        NotificationCenter.default.post(name: .menuBarManagerStateChanged, object: nil)
        
        print("[MenuBarManager] Toggled: \(isExpanded ? "expanded" : "collapsed")")
    }
    
    /// Set the expansion state directly (used by Droppy Bar click handler)
    func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else { return }
        
        isExpanded = expanded

        UserDefaults.standard.set(isExpanded, forKey: expandedKey)
        applyExpansionState()
        
        // Also toggle Droppy Bar if enabled
        if droppyBarEnabled {
            if isExpanded {
                showDroppyBar()
            } else {
                hideDroppyBar()
            }
        }
        
        NotificationCenter.default.post(name: .menuBarManagerStateChanged, object: nil)
        print("[MenuBarManager] Set expanded: \(isExpanded)")
    }
    
    /// Clean up all resources
    func cleanup() {
        disable()
        UserDefaults.standard.removeObject(forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: expandedKey)
        
        print("[MenuBarManager] Cleanup complete")
    }
    

    // MARK: - Status Items Creation
    
    private func createStatusItems() {
        // Create the toggle button (always visible, shows chevron)
        toggleItem = NSStatusBar.system.statusItem(withLength: toggleLength)
        toggleItem?.autosaveName = toggleAutosaveName
        
        if let button = toggleItem?.button {
            button.target = self
            button.action = #selector(toggleClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            print("[MenuBarManager] Toggle button configured - Preferred Position: 0")
            // Try to force position 0
            StatusItemDefaults.setPreferredPosition(0, for: toggleAutosaveName)
        } else {
            print("[MenuBarManager] ⚠️ WARNING: Toggle button is nil - clicks will not work!")
        }
        
        // Create the divider (expands to hide items)
        // This should be positioned to the LEFT of the toggle (Position 1)
        dividerItem = NSStatusBar.system.statusItem(withLength: dividerStandardLength)
        dividerItem?.autosaveName = dividerAutosaveName
        
        if let button = dividerItem?.button {
            // Make divider visible so users know where to drag items
            // Using a distinct "separator" style icon
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .light)
            button.image = NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: "Hiding Divider")?
                .withSymbolConfiguration(config)
            button.imagePosition = .imageOnly
            
            // Add a tooltip to explain what this is
            button.toolTip = "Drag items to the LEFT of this divider to hide them from the main bar."
            
            print("[MenuBarManager] Divider configured - Preferred Position: 1")
            StatusItemDefaults.setPreferredPosition(1, for: dividerAutosaveName)
        } else {
            print("[MenuBarManager] ⚠️ WARNING: Divider button is nil - expansion may not work!")
        }
        
        updateToggleIcon()
        
        print("[MenuBarManager] Created status items")
    }
    
    private func removeStatusItems() {
        if let item = toggleItem {
            let autosaveName = item.autosaveName as String
            let cached = StatusItemDefaults.preferredPosition(for: autosaveName)
            NSStatusBar.system.removeStatusItem(item)
            if let pos = cached { StatusItemDefaults.setPreferredPosition(pos, for: autosaveName) }
            toggleItem = nil
        }
        
        if let item = dividerItem {
            let autosaveName = item.autosaveName as String
            let cached = StatusItemDefaults.preferredPosition(for: autosaveName)
            NSStatusBar.system.removeStatusItem(item)
            if let pos = cached { StatusItemDefaults.setPreferredPosition(pos, for: autosaveName) }
            dividerItem = nil
        }
        
        print("[MenuBarManager] Removed status items")
    }
    
    private func updateToggleIcon() {
        guard let button = toggleItem?.button else { return }
        
        let config = NSImage.SymbolConfiguration(pointSize: 8, weight: .regular)
        
        if isExpanded {
            // Items shown - show filled dot
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Hide menu bar icons")?
                .withSymbolConfiguration(config)
        } else {
            // Items hidden - show empty dot
            button.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Show menu bar icons")?
                .withSymbolConfiguration(config)
        }
    }
    
    private func applyExpansionState() {
        guard let dividerItem = dividerItem, let button = dividerItem.button else { return }
        
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .light)
        
        if isExpanded {
            // Show hidden items - divider at standard length
            dividerItem.length = dividerStandardLength
            // Show the "Hider" icon so users know where the boundary is
            button.image = NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: "Hiding Divider")?
                .withSymbolConfiguration(config)
            button.isEnabled = true
        } else {
            // Hide items - expand divider to push items left off-screen
            dividerItem.length = dividerExpandedLength
            // Clear icon so it's just empty space
            button.image = nil
            button.isEnabled = false
        }
        
        updateToggleIcon()
    }
    
    // MARK: - Actions
    
    @objc private func toggleClicked() {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            // Right-click: show menu
            showContextMenu()
        } else {
            // Left-click: toggle expansion
            toggleExpanded()
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(
            title: isExpanded ? "Hide Menu Bar Icons" : "Show Menu Bar Icons",
            action: #selector(toggleFromMenu),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.image = NSImage(systemSymbolName: isExpanded ? "eye.slash" : "eye", accessibilityDescription: nil)
        menu.addItem(toggleItem)
        
        menu.addItem(.separator())
        

        
        let howToItem = NSMenuItem(
            title: "How to Use",
            action: #selector(showHowTo),
            keyEquivalent: ""
        )
        howToItem.target = self
        howToItem.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: nil)
        menu.addItem(howToItem)
        
        menu.addItem(.separator())
        
        let disableItem = NSMenuItem(
            title: "Disable Menu Bar Manager",
            action: #selector(disableFromMenu),
            keyEquivalent: ""
        )
        disableItem.target = self
        disableItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        menu.addItem(disableItem)
        
        self.toggleItem?.menu = menu
        self.toggleItem?.button?.performClick(nil)
        self.toggleItem?.menu = nil
    }
    
    @objc private func toggleFromMenu() {
        toggleExpanded()
    }
    

    
    @objc private func showHowTo() {
        // Show Droppy-style notification
        DroppyAlertController.shared.showSimple(
            style: .info,
            title: "How to Use Menu Bar Manager",
            message: "1. Hold ⌘ (Command) and drag menu bar icons\n2. Move icons to the LEFT of the chevron to hide them\n3. Click the chevron to show/hide those icons\n\nIcons to the right of the chevron stay visible."
        )
    }
    
    @objc private func disableFromMenu() {
        disable()
    }
    
    // MARK: - Droppy Bar Methods
    
    /// Show the Droppy Bar panel
    private func showDroppyBar() {
        if droppyBarPanel == nil {
            droppyBarPanel = DroppyBarPanel()
        }
        
        // Find the screen containing the mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        
        Task { @MainActor in
            await droppyBarPanel?.show(on: screen)
        }
        print("[MenuBarManager] Droppy Bar shown")
    }
    
    /// Hide the Droppy Bar panel
    private func hideDroppyBar() {
        droppyBarPanel?.orderOut(nil)
        print("[MenuBarManager] Droppy Bar hidden")
    }
    
    /// Toggle Droppy Bar visibility
    func toggleDroppyBar() {
        if droppyBarPanel?.isVisible == true {
            hideDroppyBar()
        } else {
            showDroppyBar()
        }
    }
    
    // MARK: - Cover Panel (Hide Selected Items)
    
    /// Set up the cover panel
    private func setupCoverPanel() {
        coverPanel = MenuBarCoverPanel()
        coverPanel?.startAutoUpdate()
        print("[MenuBarManager] Cover panel created")
    }
    
    /// Subscribe to item store changes to auto-hide selected items
    private func setupItemStoreSubscription() {
        droppyBarItemStore.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCoverForSelectedItems()
            }
            .store(in: &cancellables)
        print("[MenuBarManager] Subscribed to item store changes")
    }
    
    /// Update the cover panel to hide currently selected items
    func updateCoverForSelectedItems() {
        guard isEnabled else { return }
        
        // Get owner names of items that should be hidden (selected in Droppy Bar config)
        let selectedOwnerNames = droppyBarItemStore.enabledOwnerNames
        
        guard !selectedOwnerNames.isEmpty else {
            coverPanel?.clearCover()
            return
        }
        
        // Get current menu bar items
        let allItems = MenuBarItem.getMenuBarItems()
        
        // Find the items that match our selected owners
        let itemsToHide = allItems.filter { selectedOwnerNames.contains($0.ownerName) }
        
        // Deduplicate by owner
        var seen = Set<String>()
        let uniqueItemsToHide = itemsToHide.filter { item in
            if seen.contains(item.ownerName) { return false }
            seen.insert(item.ownerName)
            return true
        }
        
        if !uniqueItemsToHide.isEmpty {
            print("[MenuBarManager] Hiding \(uniqueItemsToHide.count) items: \(uniqueItemsToHide.map { $0.ownerName })")
            coverPanel?.updateCover(for: uniqueItemsToHide)
        } else {
            coverPanel?.clearCover()
        }
    }
    
    // MARK: - Diagnostics
    
    /// Print diagnostic information for troubleshooting
    /// Call this from console or debug menu to diagnose issues
    func printDiagnostics() {
        print("[MenuBarManager] === DIAGNOSTICS ===")
        print("  isRemoved: \(ExtensionType.menuBarManager.isRemoved)")
        print("  isEnabled: \(isEnabled)")
        print("  isExpanded: \(isExpanded)")
        print("  toggleItem exists: \(toggleItem != nil)")
        print("  toggleItem.button exists: \(toggleItem?.button != nil)")
        print("  toggleItem.button.target set: \(toggleItem?.button?.target != nil)")
        print("  toggleItem.button.action set: \(toggleItem?.button?.action != nil)")
        print("  dividerItem exists: \(dividerItem != nil)")
        print("  dividerItem.length: \(dividerItem?.length ?? -1)")
        print("  UserDefaults enabledKey: \(UserDefaults.standard.bool(forKey: enabledKey))")
        print("  UserDefaults expandedKey: \(UserDefaults.standard.object(forKey: expandedKey) ?? "nil")")
        print("[MenuBarManager] === END DIAGNOSTICS ===")
    }
}

// MARK: - StatusItemDefaults Helper

private enum StatusItemDefaults {
    private static let positionPrefix = "NSStatusItem Preferred Position"
    
    static func preferredPosition(for autosaveName: String) -> Double? {
        UserDefaults.standard.object(forKey: "\(positionPrefix) \(autosaveName)") as? Double
    }
    
    static func setPreferredPosition(_ position: Double, for autosaveName: String) {
        UserDefaults.standard.set(position, forKey: "\(positionPrefix) \(autosaveName)")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openMenuBarManagerSettings = Notification.Name("openMenuBarManagerSettings")
    static let menuBarManagerStateChanged = Notification.Name("menuBarManagerStateChanged")
}

