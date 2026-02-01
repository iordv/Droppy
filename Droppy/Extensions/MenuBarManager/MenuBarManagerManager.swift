//
//  MenuBarManager.swift
//  Droppy
//
//  Menu Bar Manager - Hide/show menu bar icons using ICE-style divider expansion
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
    
    /// The visible toggle button - always shows eye icon, click to toggle
    private var toggleItem: NSStatusItem?
    
    /// The chevron indicator - visible only when icons are hidden (to the left of toggle)
    private var chevronItem: NSStatusItem?
    
    /// The invisible divider that expands to push items off-screen
    private var dividerItem: NSStatusItem?
    
    /// Autosave names for position persistence
    private let toggleAutosaveName = "DroppyMenuBarToggle"
    private let chevronAutosaveName = "DroppyMenuBarChevron"
    private let dividerAutosaveName = "DroppyMenuBarDivider"
    
    // MARK: - Constants
    
    /// Standard length for toggle (shows chevron)
    private let toggleLength: CGFloat = NSStatusItem.variableLength
    
    /// Standard length for divider (thin, almost invisible)
    private let dividerStandardLength: CGFloat = 1
    
    /// Expanded length to push items off-screen (ICE uses 10,000)
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
        
        isEnabled = true
        UserDefaults.standard.set(true, forKey: enabledKey)
        
        // Clear any stale chevron position to force it next to toggle
        // (The autosave mechanism may have cached a far-left position)
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position \(chevronAutosaveName)")
        
        // Create all status items
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
        // Create the toggle button FIRST (so it appears rightmost, near system tray)
        toggleItem = NSStatusBar.system.statusItem(withLength: toggleLength)
        toggleItem?.autosaveName = toggleAutosaveName
        
        if let button = toggleItem?.button {
            button.target = self
            button.action = #selector(toggleClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create the divider SECOND (expands to hide items, positioned to the left)
        dividerItem = NSStatusBar.system.statusItem(withLength: dividerStandardLength)
        dividerItem?.autosaveName = dividerAutosaveName
        
        if let button = dividerItem?.button {
            // Make divider invisible
            button.title = ""
            button.image = nil
        }
        
        // Create the chevron LAST so it appears directly to the LEFT of the toggle
        // (NSStatusBar places items right-to-left based on creation order when no position is saved)
        // Using autosaveName to persist position next to the toggle
        chevronItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        chevronItem?.autosaveName = chevronAutosaveName
        chevronItem?.isVisible = true // Start visible (default is expanded/showing all icons)
        
        if let button = chevronItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            button.image = NSImage(systemSymbolName: "chevron.compact.left", accessibilityDescription: "Drag icons left of here to hide them")?
                .withSymbolConfiguration(config)
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
        
        if let item = chevronItem {
            let autosaveName = item.autosaveName as String
            let cached = StatusItemDefaults.preferredPosition(for: autosaveName)
            NSStatusBar.system.removeStatusItem(item)
            if let pos = cached { StatusItemDefaults.setPreferredPosition(pos, for: autosaveName) }
            chevronItem = nil
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
            // Items visible - show open eye (click to hide)
            button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Hide menu bar icons")?
                .withSymbolConfiguration(config)
        } else {
            // Items hidden - show slashed eye (click to show)
            button.image = NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: "Show menu bar icons")?
                .withSymbolConfiguration(config)
        }
    }
    
    private func applyExpansionState() {
        guard let dividerItem = dividerItem else { return }
        
        if isExpanded {
            // Show all icons - divider at minimal length, SHOW chevron (indicates drag zone)
            dividerItem.length = dividerStandardLength
            chevronItem?.isVisible = true // Show chevron when icons are visible
        } else {
            // Hide icons - expand divider, hide chevron (no need to show drag zone)
            dividerItem.length = dividerExpandedLength
            chevronItem?.isVisible = false // Hide chevron when icons are hidden
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
        
        menu.addItem(withTitle: isExpanded ? "Hide Menu Bar Icons" : "Show Menu Bar Icons",
                     action: #selector(toggleFromMenu),
                     keyEquivalent: "")
        menu.items.last?.target = self
        
        menu.addItem(.separator())
        
        menu.addItem(withTitle: "How to Use",
                     action: #selector(showHowTo),
                     keyEquivalent: "")
        menu.items.last?.target = self
        
        menu.addItem(.separator())
        
        menu.addItem(withTitle: "Disable Menu Bar Manager",
                     action: #selector(disableFromMenu),
                     keyEquivalent: "")
        menu.items.last?.target = self
        
        toggleItem?.menu = menu
        toggleItem?.button?.performClick(nil)
        toggleItem?.menu = nil
    }
    
    @objc private func toggleFromMenu() {
        toggleExpanded()
    }
    
    @objc private func showHowTo() {
        // Show Droppy-style notification
        DroppyAlertController.shared.showSimple(
            style: .info,
            title: "How to Use Menu Bar Manager",
            message: "1. Click the eye icon to hide icons (a chevron will appear)\n2. Hold ⌘ and drag icons LEFT of the chevron to hide them\n3. Click the eye again to show/hide those icons\n\nIcons to the right of the chevron stay visible."
        )
    }
    
    @objc private func disableFromMenu() {
        disable()
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
