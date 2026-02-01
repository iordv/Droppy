//
//  MenuBarManagerManager.swift
//  Droppy
//
//  Menu Bar Manager - Hide/show menu bar icons using divider expansion pattern
//

import SwiftUI
import AppKit
import Combine

// MARK: - Icon Set

/// Available icon sets for the main toggle button
enum MBMIconSet: String, CaseIterable, Identifiable {
    case eye = "eye"
    case chevron = "chevron"
    case arrow = "arrow"
    case circle = "circle"
    case door = "door"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .eye: return "Eye"
        case .chevron: return "Chevron"
        case .arrow: return "Arrow"
        case .circle: return "Circle"
        case .door: return "Door"
        }
    }
    
    /// Icon when items are hidden (collapsed state)
    var hiddenSymbol: String {
        switch self {
        case .eye: return "eye.slash.fill"
        case .chevron: return "chevron.left"
        case .arrow: return "arrowshape.left.fill"
        case .circle: return "circle.fill"
        case .door: return "door.left.hand.closed"
        }
    }
    
    /// Icon when items are visible (expanded state)
    var visibleSymbol: String {
        switch self {
        case .eye: return "eye.fill"
        case .chevron: return "chevron.right"
        case .arrow: return "arrowshape.right.fill"
        case .circle: return "circle"
        case .door: return "door.left.hand.open"
        }
    }
}

// MARK: - Status Item Defaults (Position Caching)

/// Proxy for status item UserDefaults values - critical for position persistence
private enum StatusItemDefaults {
    static subscript(autosaveName: String) -> CGFloat? {
        get {
            let key = "NSStatusItem Preferred Position \(autosaveName)"
            return UserDefaults.standard.object(forKey: key) as? CGFloat
        }
        set {
            let key = "NSStatusItem Preferred Position \(autosaveName)"
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}

// MARK: - Menu Bar Manager

@MainActor
final class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()
    
    // MARK: - State
    
    enum HidingState {
        case hideItems  // Divider expanded to 10,000pt, icons pushed off
        case showItems  // Divider at normal width, icons visible
    }
    
    /// Whether the extension is enabled
    @Published private(set) var isEnabled = false
    
    /// Current hiding state
    @Published private(set) var state = HidingState.showItems
    
    /// Whether hover-to-show is enabled
    @Published var showOnHover = false {
        didSet {
            UserDefaults.standard.set(showOnHover, forKey: Keys.showOnHover)
            updateMouseMonitor()
        }
    }
    
    /// Delay before showing/hiding on hover (0.0 - 1.0 seconds)
    @Published var showOnHoverDelay: TimeInterval = 0.2 {
        didSet {
            UserDefaults.standard.set(showOnHoverDelay, forKey: Keys.showOnHoverDelay)
        }
    }
    
    /// Selected icon set for the main toggle button
    @Published var iconSet: MBMIconSet = .eye {
        didSet {
            UserDefaults.standard.set(iconSet.rawValue, forKey: Keys.iconSet)
            updateMainItem()
        }
    }
    
    /// Convenience: whether icons are currently visible
    var isExpanded: Bool { state == .showItems }
    
    /// Prevents hover-to-show temporarily (e.g., when clicking menu bar items)
    private var isShowOnHoverPrevented = false
    private var preventShowOnHoverTask: Task<Void, Never>?
    
    // MARK: - Status Items
    
    /// The main toggle button (rightmost, user clicks to toggle visibility)
    private var mainItem: NSStatusItem?
    
    /// The hidden section divider (to the LEFT of main, expands to push icons off screen)
    private var dividerItem: NSStatusItem?
    
    // Autosave names for position persistence
    private static let mainAutosaveName = "DroppyMBM_Icon"
    private static let dividerAutosaveName = "DroppyMBM_Hidden"
    
    // MARK: - Constants
    
    /// Standard length for visible control items
    private let lengthStandard = NSStatusItem.variableLength
    
    /// Expanded length to push items off screen
    private let lengthExpanded: CGFloat = 10_000
    
    // MARK: - Mouse Monitoring
    
    private var mouseMovedMonitor: Any?
    private var mouseDownMonitor: Any?
    
    // MARK: - Keys
    
    private enum Keys {
        static let enabled = "menuBarManagerEnabled"
        static let state = "menuBarManagerState"
        static let showOnHover = "menuBarManagerShowOnHover"
        static let showOnHoverDelay = "menuBarManagerShowOnHoverDelay"
        static let iconSet = "menuBarManagerIconSet"
    }
    
    // MARK: - Initialization
    
    private init() {
        print("[MenuBarManager] INIT CALLED")
        
        // Only start if extension is not removed
        guard !ExtensionType.menuBarManager.isRemoved else {
            print("[MenuBarManager] BLOCKED - extension is removed!")
            return
        }
        
        print("[MenuBarManager] Extension not removed, loading settings...")
        
        // Load settings
        showOnHover = UserDefaults.standard.bool(forKey: Keys.showOnHover)
        showOnHoverDelay = UserDefaults.standard.double(forKey: Keys.showOnHoverDelay)
        if showOnHoverDelay == 0 { showOnHoverDelay = 0.2 } // Default
        
        if let iconRaw = UserDefaults.standard.string(forKey: Keys.iconSet),
           let icon = MBMIconSet(rawValue: iconRaw) {
            iconSet = icon
        }
        
        if UserDefaults.standard.bool(forKey: Keys.enabled) {
            enable()
        }
    }
    
    // MARK: - Public API
    
    /// Enable the menu bar manager
    func enable() {
        guard !isEnabled else { return }
        
        isEnabled = true
        UserDefaults.standard.set(true, forKey: Keys.enabled)
        
        // Seed positions BEFORE creating items (critical pattern)
        seedPositionsIfNeeded()
        
        // Create status items
        createStatusItems()
        
        // Restore previous state
        if let savedState = UserDefaults.standard.string(forKey: Keys.state) {
            state = savedState == "hideItems" ? .hideItems : .showItems
        } else {
            state = .showItems
        }
        applyState()
        
        // Start mouse monitoring if hover is enabled
        updateMouseMonitor()
        
        print("[MenuBarManager] Enabled, state: \(state)")
    }
    
    /// Disable the menu bar manager
    func disable() {
        guard isEnabled else { return }
        
        // Show all items before disabling
        if state == .hideItems {
            state = .showItems
            applyState()
        }
        
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Keys.enabled)
        
        // Stop monitors
        stopMouseMonitors()
        
        // Remove status items (with position preservation)
        removeStatusItems()
        
        print("[MenuBarManager] Disabled")
    }
    
    /// Toggle between showing and hiding items
    func toggle() {
        state = (state == .showItems) ? .hideItems : .showItems
        UserDefaults.standard.set(state == .hideItems ? "hideItems" : "showItems", forKey: Keys.state)
        applyState()
        
        // Notify for Droppy menu refresh
        NotificationCenter.default.post(name: .menuBarManagerStateChanged, object: nil)
        
        // Allow hover after toggle
        allowShowOnHover()
        
        print("[MenuBarManager] Toggled to: \(state)")
    }
    
    /// Show hidden items
    func show() {
        guard state == .hideItems else { return }
        toggle()
    }
    
    /// Hide items
    func hide() {
        guard state == .showItems else { return }
        toggle()
    }
    
    /// Legacy compatibility
    func toggleExpanded() {
        toggle()
    }
    
    /// Temporarily prevent hover-to-show (used when clicking items)
    func preventShowOnHover() {
        isShowOnHoverPrevented = true
        preventShowOnHoverTask?.cancel()
    }
    
    /// Allow hover-to-show again
    func allowShowOnHover() {
        preventShowOnHoverTask?.cancel()
        preventShowOnHoverTask = Task {
            try? await Task.sleep(for: .seconds(0.5))
            isShowOnHoverPrevented = false
        }
    }
    
    /// Clean up all resources
    func cleanup() {
        disable()
        UserDefaults.standard.removeObject(forKey: Keys.enabled)
        UserDefaults.standard.removeObject(forKey: Keys.state)
        UserDefaults.standard.removeObject(forKey: Keys.showOnHover)
        UserDefaults.standard.removeObject(forKey: Keys.showOnHoverDelay)
        UserDefaults.standard.removeObject(forKey: Keys.iconSet)
        
        // Clear saved positions for fresh start on next enable
        StatusItemDefaults[Self.mainAutosaveName] = nil
        StatusItemDefaults[Self.dividerAutosaveName] = nil
        
        print("[MenuBarManager] Cleanup complete")
    }
    
    // MARK: - Position Management
    
    /// Seed initial positions BEFORE creating items
    private func seedPositionsIfNeeded() {
        // Main icon at position 0 (rightmost)
        if StatusItemDefaults[Self.mainAutosaveName] == nil {
            StatusItemDefaults[Self.mainAutosaveName] = 0
            print("[MenuBarManager] Seeded main icon position")
        }
        // Divider at position 1 (to the left of main)
        if StatusItemDefaults[Self.dividerAutosaveName] == nil {
            StatusItemDefaults[Self.dividerAutosaveName] = 1
            print("[MenuBarManager] Seeded divider position")
        }
    }
    
    // MARK: - Status Items Creation
    
    private func createStatusItems() {
        // Create MAIN item (user's toggle button)
        mainItem = NSStatusBar.system.statusItem(withLength: lengthStandard)
        mainItem?.autosaveName = Self.mainAutosaveName
        
        if let button = mainItem?.button {
            button.target = self
            button.action = #selector(mainItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            print("[MenuBarManager] Created MAIN item, button=\(button), window=\(String(describing: button.window))")
        } else {
            print("[MenuBarManager] ERROR: mainItem has no button!")
        }
        
        // Create DIVIDER item (the hidden section marker that expands)
        dividerItem = NSStatusBar.system.statusItem(withLength: lengthStandard)
        dividerItem?.autosaveName = Self.dividerAutosaveName
        dividerItem?.isVisible = true  // CRITICAL: Ensure divider is visible
        
        if let button = dividerItem?.button {
            button.target = self
            button.action = #selector(dividerClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            print("[MenuBarManager] Created DIVIDER item, button=\(button), window=\(String(describing: button.window))")
        } else {
            print("[MenuBarManager] ERROR: dividerItem has no button!")
        }
        
        print("[MenuBarManager] Created status items - mainItem=\(String(describing: mainItem)), dividerItem=\(String(describing: dividerItem))")
        
        // Debug: Check window positions
        if let mainWindow = mainItem?.button?.window {
            print("[MenuBarManager] MAIN window frame=\(mainWindow.frame), isVisible=\(mainWindow.isVisible)")
        }
        if let dividerWindow = dividerItem?.button?.window {
            print("[MenuBarManager] DIVIDER window frame=\(dividerWindow.frame), isVisible=\(dividerWindow.isVisible)")
        }
        print("[MenuBarManager] mainItem.isVisible=\(String(describing: mainItem?.isVisible)), dividerItem.isVisible=\(String(describing: dividerItem?.isVisible))")
    }
    
    private func removeStatusItems() {
        // Critical pattern: Cache positions before removing, then restore after
        // This prevents NSStatusBar from clearing the preferred positions
        
        if let item = mainItem {
            let autosave = item.autosaveName as String
            let cached = StatusItemDefaults[autosave]
            NSStatusBar.system.removeStatusItem(item)
            StatusItemDefaults[autosave] = cached
            mainItem = nil
        }
        
        if let item = dividerItem {
            let autosave = item.autosaveName as String
            let cached = StatusItemDefaults[autosave]
            NSStatusBar.system.removeStatusItem(item)
            StatusItemDefaults[autosave] = cached
            dividerItem = nil
        }
        
        print("[MenuBarManager] Removed status items")
    }
    
    // MARK: - State Application
    
    private func applyState() {
        updateMainItem()
        updateDividerItem()
    }
    
    private func updateMainItem() {
        guard let button = mainItem?.button else { return }
        
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        
        let symbolName = (state == .showItems) ? iconSet.visibleSymbol : iconSet.hiddenSymbol
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: state == .showItems ? "Hide menu bar icons" : "Show menu bar icons")?
            .withSymbolConfiguration(config)
        button.image?.isTemplate = true
    }
    
    private func updateDividerItem() {
        guard let dividerItem = dividerItem, let button = dividerItem.button else {
            print("[MenuBarManager] updateDividerItem: NO DIVIDER ITEM!")
            return
        }
        
        print("[MenuBarManager] updateDividerItem: state=\(state), current length=\(dividerItem.length)")
        
        switch state {
        case .showItems:
            // Normal width - show chevron indicator
            dividerItem.length = lengthStandard
            button.cell?.isEnabled = true
            button.alphaValue = 0.7
            
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            let chevronImage = NSImage(systemSymbolName: "chevron.compact.left", accessibilityDescription: "Drag icons left to hide")?
                .withSymbolConfiguration(config)
            button.image = chevronImage
            button.image?.isTemplate = true
            print("[MenuBarManager] updateDividerItem: SET TO SHOW (length=\(dividerItem.length)), image=\(String(describing: chevronImage)), button.image=\(String(describing: button.image)), button.frame=\(button.frame)")
            
        case .hideItems:
            // Expanded to push icons off - Button Stealth Pattern
            dividerItem.length = lengthExpanded
            button.cell?.isEnabled = false  // Prevent highlighting
            button.isHighlighted = false     // Force unhighlight
            button.image = nil               // Hide the chevron
            print("[MenuBarManager] updateDividerItem: SET TO HIDE (length=\(dividerItem.length))")
        }
    }
    
    // MARK: - Mouse Monitoring
    
    private func updateMouseMonitor() {
        if showOnHover && isEnabled {
            startMouseMonitors()
        } else {
            stopMouseMonitors()
        }
    }
    
    private func startMouseMonitors() {
        guard mouseMovedMonitor == nil else { return }
        
        mouseMovedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleShowOnHover()
        }
        
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleMouseDown(event)
        }
        
        print("[MenuBarManager] Started mouse monitors")
    }
    
    private func stopMouseMonitors() {
        if let monitor = mouseMovedMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMovedMonitor = nil
        }
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDownMonitor = nil
        }
        print("[MenuBarManager] Stopped mouse monitors")
    }
    
    private var isMouseInsideMenuBar: Bool {
        guard let screen = NSScreen.main else { return false }
        let mouseLocation = NSEvent.mouseLocation
        return mouseLocation.y > screen.visibleFrame.maxY && mouseLocation.y <= screen.frame.maxY
    }
    
    private var isMouseInsideEmptyMenuBarSpace: Bool {
        // Simple heuristic: mouse is in menu bar and not directly over any known items
        // For full accuracy, would need to query WindowInfo, but this works for most cases
        isMouseInsideMenuBar
    }
    
    private func handleShowOnHover() {
        guard showOnHover, !isShowOnHoverPrevented, isEnabled else { return }
        
        Task {
            if state == .hideItems && isMouseInsideEmptyMenuBarSpace {
                // Want to show
                try? await Task.sleep(for: .seconds(showOnHoverDelay))
                guard isMouseInsideEmptyMenuBarSpace else { return }
                await MainActor.run { show() }
            } else if state == .showItems && !isMouseInsideMenuBar {
                // Want to hide
                try? await Task.sleep(for: .seconds(showOnHoverDelay))
                guard !isMouseInsideMenuBar else { return }
                await MainActor.run { hide() }
            }
        }
    }
    
    private func handleMouseDown(_ event: NSEvent) {
        guard showOnHover, isMouseInsideMenuBar else { return }
        preventShowOnHover()
    }
    
    // MARK: - Actions
    
    @objc private func mainItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        
        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        default:
            toggle()
        }
    }
    
    @objc private func dividerClicked() {
        guard let event = NSApp.currentEvent else { return }
        
        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        default:
            toggle()
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let toggleTitle = (state == .showItems) ? "Hide Menu Bar Icons" : "Show Menu Bar Icons"
        menu.addItem(withTitle: toggleTitle, action: #selector(toggleFromMenu), keyEquivalent: "")
        menu.items.last?.target = self
        
        menu.addItem(.separator())
        
        // Hover to show toggle
        let hoverItem = NSMenuItem(title: "Show on Hover", action: #selector(toggleHoverFromMenu), keyEquivalent: "")
        hoverItem.target = self
        hoverItem.state = showOnHover ? .on : .off
        menu.addItem(hoverItem)
        
        menu.addItem(.separator())
        
        menu.addItem(withTitle: "How to Use", action: #selector(showHowTo), keyEquivalent: "")
        menu.items.last?.target = self
        
        menu.addItem(.separator())
        
        menu.addItem(withTitle: "Disable Menu Bar Manager", action: #selector(disableFromMenu), keyEquivalent: "")
        menu.items.last?.target = self
        
        mainItem?.menu = menu
        mainItem?.button?.performClick(nil)
        mainItem?.menu = nil
    }
    
    @objc private func toggleFromMenu() {
        toggle()
    }
    
    @objc private func toggleHoverFromMenu() {
        showOnHover.toggle()
    }
    
    @objc private func showHowTo() {
        DroppyAlertController.shared.showSimple(
            style: .info,
            title: "How to Use Menu Bar Manager",
            message: "1. Hold ⌘ and drag icons to the LEFT of the chevron ‹\n2. Click the eye icon to hide/show those icons\n\nIcons to the RIGHT of the chevron stay visible."
        )
    }
    
    @objc private func disableFromMenu() {
        disable()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openMenuBarManagerSettings = Notification.Name("openMenuBarManagerSettings")
    static let menuBarManagerStateChanged = Notification.Name("menuBarManagerStateChanged")
}
