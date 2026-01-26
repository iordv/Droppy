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
        
        print("[MenuBarManager] Enabled, expanded: \(isExpanded)")
    }
    
    /// Disable the menu bar manager
    func disable() {
        guard isEnabled else { return }
        
        isEnabled = false
        UserDefaults.standard.set(false, forKey: enabledKey)
        
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
        // IMPORTANT: Set initial preferred positions if not already set
        // Lower position = further RIGHT in menu bar
        // Toggle should be rightmost (position 0) so it stays visible when divider expands
        // Divider should be to the LEFT of toggle (higher position number)
        if StatusItemDefaults.preferredPosition(for: toggleAutosaveName) == nil {
            StatusItemDefaults.setPreferredPosition(0, for: toggleAutosaveName)
        }
        if StatusItemDefaults.preferredPosition(for: dividerAutosaveName) == nil {
            StatusItemDefaults.setPreferredPosition(1, for: dividerAutosaveName)
        }
        
        // Create DIVIDER FIRST (positioned to the LEFT of toggle)
        // When it expands, it pushes items to ITS left off-screen, not the toggle
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
        
        // Create toggle button SECOND (stays to the RIGHT, always visible)
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
        
        // Same size and weight for both states
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        
        let symbolName = isExpanded ? "circle.fill" : "circle"
        let description = isExpanded ? "Hide menu bar icons" : "Show menu bar icons"
        
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)?
            .withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
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
            message: "1. Hold ⌘ (Command) and drag menu bar icons\n2. Move icons to the LEFT of the dot (●) to hide them\n3. Click the dot to show/hide those icons\n\nFilled dot = icons visible, empty dot = icons hidden."
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

