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
    
    /// Discovered menu bar items
    @Published private(set) var discoveredItems: [MenuBarItem] = []
    
    /// Item section assignments (itemID -> section)
    @Published private(set) var itemAssignments: [String: MenuBarSection] = [:]
    
    // MARK: - IceBar
    
    /// The IceBar panel for showing hidden items
    private(set) var iceBar: IceBarPanel?
    
    // MARK: - Status Items
    
    /// The visible toggle button - always shows chevron, click to toggle
    private var toggleItem: NSStatusItem?
    
    /// The invisible divider that expands to push items off-screen
    private var dividerItem: NSStatusItem?
    
    /// Autosave names for position persistence
    private let toggleAutosaveName = "DroppyMenuBarToggle"
    private let dividerAutosaveName = "DroppyMenuBarDivider"
    
    // MARK: - Constants
    
    /// Standard length for toggle (shows chevron)
    private let toggleLength: CGFloat = NSStatusItem.variableLength
    
    /// Standard length for divider (thin, almost invisible)
    private let dividerStandardLength: CGFloat = 1
    
    /// Expanded length to push items off-screen
    private let dividerExpandedLength: CGFloat = 10_000
    
    // MARK: - Persistence Keys
    
    private let enabledKey = "menuBarManagerEnabled"
    private let expandedKey = "menuBarManagerExpanded"
    
    // MARK: - Initialization
    
    private init() {
        // Load saved assignments
        itemAssignments = MenuBarItem.loadAssignments()
        
        // Only start if extension is not removed
        guard !ExtensionType.menuBarManager.isRemoved else { return }
        
        if UserDefaults.standard.bool(forKey: enabledKey) {
            enable()
        }
    }
    
    // MARK: - Public API
    
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
        
        // Restore previous expansion state, or default to expanded (showing all icons)
        if UserDefaults.standard.object(forKey: expandedKey) != nil {
            isExpanded = UserDefaults.standard.bool(forKey: expandedKey)
        } else {
            isExpanded = true
        }
        applyExpansionState()
        
        // Create IceBar
        iceBar = IceBarPanel()
        
        // Discover menu bar items
        refreshDiscoveredItems()
        
        print("[MenuBarManager] Enabled, expanded: \(isExpanded), items: \(discoveredItems.count)")
    }
    
    /// Disable the menu bar manager
    func disable() {
        guard isEnabled else { return }
        
        isEnabled = false
        UserDefaults.standard.set(false, forKey: enabledKey)
        
        // Hide and cleanup IceBar
        iceBar?.hide()
        iceBar = nil
        
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
        
        // Notify to refresh Droppy menu
        NotificationCenter.default.post(name: .menuBarManagerStateChanged, object: nil)
        
        print("[MenuBarManager] Toggled: \(isExpanded ? "expanded" : "collapsed")")
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
            print("[MenuBarManager] Toggle button configured with click action")
        } else {
            print("[MenuBarManager] ⚠️ WARNING: Toggle button is nil - clicks will not work!")
        }
        
        // Create the divider (expands to hide items)
        // This should be positioned to the LEFT of the toggle
        dividerItem = NSStatusBar.system.statusItem(withLength: dividerStandardLength)
        dividerItem?.autosaveName = dividerAutosaveName
        
        if let button = dividerItem?.button {
            // Make divider nearly invisible - just a thin separator
            button.title = ""
            button.image = nil
            print("[MenuBarManager] Divider configured")
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
        
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        
        if isExpanded {
            // Items visible (expanded) - show chevron pointing right (icons expanded outward)
            // Issue #83: User expects ">" when expanded
            button.image = NSImage(systemSymbolName: "chevron.compact.right", accessibilityDescription: "Hide menu bar icons")?
                .withSymbolConfiguration(config)
        } else {
            // Items hidden (collapsed) - show chevron pointing left (click to expand)
            // Issue #83: User expects "<" when collapsed, indicating "click to expand"
            button.image = NSImage(systemSymbolName: "chevron.compact.left", accessibilityDescription: "Show menu bar icons")?
                .withSymbolConfiguration(config)
        }
    }
    
    private func applyExpansionState() {
        guard let dividerItem = dividerItem else { return }
        
        if isExpanded {
            // Show hidden items - divider at minimal length
            dividerItem.length = dividerStandardLength
        } else {
            // Hide items - expand divider to push items left off-screen
            dividerItem.length = dividerExpandedLength
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
    
    // MARK: - Diagnostics
    
    /// Print diagnostic information for troubleshooting
    /// Call this from console or debug menu to diagnose issues
    func printDiagnostics() {
        print("[MenuBarManager] === DIAGNOSTICS ===")
        print("  isRemoved: \(ExtensionType.menuBarManager.isRemoved)")
        print("  isEnabled: \(isEnabled)")
        print("  isExpanded: \(isExpanded)")
        print("  discoveredItems: \(discoveredItems.count)")
        print("  toggleItem exists: \(toggleItem != nil)")
        print("  toggleItem.button exists: \(toggleItem?.button != nil)")
        print("  toggleItem.button.target set: \(toggleItem?.button?.target != nil)")
        print("  toggleItem.button.action set: \(toggleItem?.button?.action != nil)")
        print("  dividerItem exists: \(dividerItem != nil)")
        print("  dividerItem.length: \(dividerItem?.length ?? -1)")
        print("  iceBar exists: \(iceBar != nil)")
        print("  UserDefaults enabledKey: \(UserDefaults.standard.bool(forKey: enabledKey))")
        print("  UserDefaults expandedKey: \(UserDefaults.standard.object(forKey: expandedKey) ?? "nil")")
        print("[MenuBarManager] === END DIAGNOSTICS ===")
    }
    
    // MARK: - Item Discovery
    
    /// Refresh discovered menu bar items using CGS APIs
    func refreshDiscoveredItems() {
        let windowInfos = CGSBridging.discoverMenuBarItems()
        
        // Convert to MenuBarItem and apply saved sections
        var items = windowInfos.map { MenuBarItem.from($0) }
        
        // Apply saved section assignments
        for i in items.indices {
            if let savedSection = itemAssignments[items[i].id] {
                items[i].section = savedSection
            }
        }
        
        // Filter out our own toggle/divider items
        items = items.filter { item in
            !item.ownerName.contains("Droppy") || 
            (item.windowName != nil && !item.windowName!.isEmpty)
        }
        
        discoveredItems = items
        print("[MenuBarManager] Discovered \(items.count) items")
    }
    
    // MARK: - Section Management
    
    /// Assign an item to a section
    /// Note: This controls which items appear in the IceBar and UI organization.
    /// Actual menu bar hiding still requires ⌘+dragging items to the left of the divider.
    func setItemSection(_ itemID: String, section: MenuBarSection) {
        itemAssignments[itemID] = section
        MenuBarItem.saveAssignments(itemAssignments)
        
        // Update local cache
        if let index = discoveredItems.firstIndex(where: { $0.id == itemID }) {
            discoveredItems[index].section = section
        }
        
        objectWillChange.send()
        print("[MenuBarManager] Set item \(itemID) to section \(section)")
        
        // If user marks item as hidden, collapse to hide items (if not already)
        // and show the IceBar so they can see the effect
        if section == .hidden || section == .alwaysHidden {
            if isExpanded {
                toggleExpanded() // Collapse to hide
            }
            // Brief delay then show IceBar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showIceBar()
            }
        }
    }
    
    /// Get items for a specific section
    func items(in section: MenuBarSection) -> [MenuBarItem] {
        discoveredItems.filter { $0.section == section }
    }
    
    // MARK: - IceBar
    
    /// Show the IceBar with hidden items
    func showIceBar() {
        guard let iceBar = iceBar,
              let screen = NSScreen.main,
              let toggleButton = toggleItem?.button,
              let toggleWindow = toggleButton.window else {
            print("[MenuBarManager] Cannot show IceBar - missing components")
            return
        }
        
        let hiddenItems = items(in: .hidden) + items(in: .alwaysHidden)
        guard !hiddenItems.isEmpty else {
            print("[MenuBarManager] No hidden items to show")
            return
        }
        
        iceBar.show(items: hiddenItems, anchorFrame: toggleWindow.frame, screen: screen)
    }
    
    /// Hide the IceBar
    func hideIceBar() {
        iceBar?.hide()
    }
    
    /// Toggle IceBar visibility
    func toggleIceBar() {
        if iceBar?.isVisible == true {
            hideIceBar()
        } else {
            showIceBar()
        }
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
