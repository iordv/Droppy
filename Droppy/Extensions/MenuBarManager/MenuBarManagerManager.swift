//
//  MenuBarManagerManager.swift
//  Droppy
//
//  Menu Bar Manager - Hide/show menu bar icons using divider expansion pattern
//  Based on proven open-source patterns for status bar management
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

// MARK: - Status Item Defaults

/// Proxy getters and setters for status item's user defaults values
private enum StatusItemDefaults {
    /// Keys used to look up user defaults values for status items
    enum Key<Value> {
        static var preferredPosition: Key<CGFloat> { Key<CGFloat>() }
        static var visible: Key<Bool> { Key<Bool>() }
    }
    
    static subscript<Value>(key: Key<Value>, autosaveName: String) -> Value? {
        get {
            let stringKey: String
            if Value.self == CGFloat.self {
                stringKey = "NSStatusItem Preferred Position \(autosaveName)"
            } else if Value.self == Bool.self {
                stringKey = "NSStatusItem Visible \(autosaveName)"
            } else {
                return nil
            }
            return UserDefaults.standard.object(forKey: stringKey) as? Value
        }
        set {
            let stringKey: String
            if Value.self == CGFloat.self {
                stringKey = "NSStatusItem Preferred Position \(autosaveName)"
            } else if Value.self == Bool.self {
                stringKey = "NSStatusItem Visible \(autosaveName)"
            } else {
                return
            }
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: stringKey)
            } else {
                UserDefaults.standard.removeObject(forKey: stringKey)
            }
        }
    }
}

// MARK: - Hiding State

/// Possible hiding states for control items
enum HidingState {
    case hideItems  // Divider expanded to 10,000pt, icons pushed off
    case showItems  // Divider at normal width, icons visible
}

// MARK: - Control Item (Status Item Wrapper)

/// A status item that controls a section in the menu bar
/// Follows proven patterns for reliable status bar control
@MainActor
private final class ControlItem {
    /// Possible identifiers for control items
    enum Identifier: String {
        case mainIcon = "DroppyMBM_Icon"       // The toggle button (always visible)
        case hiddenDivider = "DroppyMBM_Hidden" // The divider that expands
    }
    
    /// Lengths for control items
    enum Lengths {
        static let standard: CGFloat = NSStatusItem.variableLength
        static let expanded: CGFloat = 10_000
    }
    
    /// The control item's hiding state
    @Published var state = HidingState.hideItems
    
    /// A Boolean value that indicates whether the control item is visible
    @Published var isVisible = true
    
    /// The control item's identifier
    let identifier: Identifier
    
    /// The underlying status item
    private let statusItem: NSStatusItem
    
    /// Whether this is a section divider (expands to hide) vs main icon (never expands)
    var isSectionDivider: Bool {
        identifier == .hiddenDivider
    }
    
    /// Whether the item is added to menu bar
    var isAddedToMenuBar: Bool {
        statusItem.isVisible
    }
    
    /// The status item's button
    var button: NSStatusBarButton? {
        statusItem.button
    }
    
    /// The control item's window
    var window: NSWindow? {
        statusItem.button?.window
    }
    
    /// Storage for Combine observers
    private var cancellables = Set<AnyCancellable>()
    
    /// Creates a control item with the given identifier
    init(identifier: Identifier) {
        let autosaveName = identifier.rawValue
        
        // CRITICAL: Seed position BEFORE creating item if not already set
        if StatusItemDefaults[.preferredPosition, autosaveName] == nil {
            switch identifier {
            case .mainIcon:
                StatusItemDefaults[.preferredPosition, autosaveName] = 0
            case .hiddenDivider:
                StatusItemDefaults[.preferredPosition, autosaveName] = 1
            }
        }
        
        // Create with length 0 - will be set by Combine publishers
        self.statusItem = NSStatusBar.system.statusItem(withLength: 0)
        self.statusItem.autosaveName = autosaveName
        self.identifier = identifier
        
        configureStatusItem()
        
        print("[ControlItem] Created \(identifier.rawValue), position=\(String(describing: StatusItemDefaults[.preferredPosition, autosaveName]))")
    }
    
    deinit {
        // CRITICAL: Cache position before removing, then restore
        // Removing the status item deletes the preferredPosition
        let autosaveName = statusItem.autosaveName as String
        let cached: CGFloat? = StatusItemDefaults[.preferredPosition, autosaveName]
        NSStatusBar.system.removeStatusItem(statusItem)
        StatusItemDefaults[.preferredPosition, autosaveName] = cached
        print("[ControlItem] deinit \(autosaveName), preserved position=\(String(describing: cached))")
    }
    
    /// Sets up the status item and Combine observers
    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        
        button.target = self
        button.action = #selector(itemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // Set up Combine publishers for reactive length updates
        configureCancellables()
    }
    
    /// Configures Combine publishers for reactive state management
    private func configureCancellables() {
        var c = Set<AnyCancellable>()
        
        // CRITICAL PATTERN: React to both isVisible AND state changes together
        Publishers.CombineLatest($isVisible, $state)
            .sink { [weak self] (isVisible, state) in
                guard let self else { return }
                
                if isVisible {
                    // Main icon NEVER expands - always standard length
                    // Divider expands to hide items, standard to show
                    statusItem.length = switch identifier {
                    case .mainIcon:
                        Lengths.standard
                    case .hiddenDivider:
                        switch state {
                        case .hideItems: Lengths.expanded
                        case .showItems: Lengths.standard
                        }
                    }
                } else {
                    statusItem.length = 0
                }
                
                print("[ControlItem] \(identifier.rawValue) length set to \(statusItem.length)")
            }
            .store(in: &c)
        
        // React to state changes for appearance updates
        $state
            .sink { [weak self] state in
                self?.updateAppearance(for: state)
            }
            .store(in: &c)
        
        cancellables = c
    }
    
    /// Updates the visual appearance based on state
    private func updateAppearance(for state: HidingState) {
        guard let button = statusItem.button else { return }
        
        switch identifier {
        case .mainIcon:
            // Main icon updates handled by MenuBarManager
            break
            
        case .hiddenDivider:
            switch state {
            case .hideItems:
                // Expanded - hide the divider visual
                isVisible = true
                button.cell?.isEnabled = false  // Prevent highlighting
                button.isHighlighted = false
                button.image = nil
                
            case .showItems:
                // Normal - show the chevron divider
                isVisible = true
                button.cell?.isEnabled = true
                button.alphaValue = 0.7
                
                let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
                button.image = NSImage(systemSymbolName: "chevron.compact.left", accessibilityDescription: "Section divider")?
                    .withSymbolConfiguration(config)
                button.image?.isTemplate = true
            }
        }
    }
    
    @objc private func itemClicked() {
        // Clicks handled by MenuBarManager
        if let event = NSApp.currentEvent {
            NotificationCenter.default.post(
                name: .menuBarManagerItemClicked,
                object: self,
                userInfo: ["identifier": identifier, "event": event]
            )
        }
    }
    
    /// Removes the control item from the menu bar
    func removeFromMenuBar() {
        guard isAddedToMenuBar else { return }
        
        // Cache position before hiding
        let autosaveName = statusItem.autosaveName as String
        let cached: CGFloat? = StatusItemDefaults[.preferredPosition, autosaveName]
        statusItem.isVisible = false
        StatusItemDefaults[.preferredPosition, autosaveName] = cached
    }
    
    /// Adds the control item to the menu bar
    func addToMenuBar() {
        guard !isAddedToMenuBar else { return }
        statusItem.isVisible = true
    }
}

// MARK: - Menu Bar Manager

@MainActor
final class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()
    
    // MARK: - Published State
    
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
            updateMainItemAppearance()
        }
    }
    
    /// Convenience: whether icons are currently visible
    var isExpanded: Bool { state == .showItems }
    
    // MARK: - Control Items
    
    /// The main toggle button (rightmost, user clicks to toggle visibility)
    private var mainItem: ControlItem?
    
    /// The hidden section divider (to the LEFT of main, expands to push icons off screen)
    private var dividerItem: ControlItem?
    
    // MARK: - Mouse Monitoring
    
    private var mouseMovedMonitor: Any?
    private var mouseDownMonitor: Any?
    private var isShowOnHoverPrevented = false
    private var preventShowOnHoverTask: Task<Void, Never>?
    
    // MARK: - Storage
    
    private var cancellables = Set<AnyCancellable>()
    
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
        if showOnHoverDelay == 0 { showOnHoverDelay = 0.2 }
        
        if let iconRaw = UserDefaults.standard.string(forKey: Keys.iconSet),
           let icon = MBMIconSet(rawValue: iconRaw) {
            iconSet = icon
        }
        
        // Set up click notification listener
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleItemClick(_:)),
            name: .menuBarManagerItemClicked,
            object: nil
        )
        
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
        
        // Create control items in correct order:
        // 1. Divider FIRST (will be LEFT of main)
        // 2. Main SECOND (will be RIGHT of divider)
        dividerItem = ControlItem(identifier: .hiddenDivider)
        mainItem = ControlItem(identifier: .mainIcon)
        
        // ALWAYS start with showItems to ensure visibility
        state = .showItems
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
        
        // Remove control items (deinit will preserve positions)
        mainItem = nil
        dividerItem = nil
        
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
        
        // Clear saved positions
        StatusItemDefaults[.preferredPosition, ControlItem.Identifier.mainIcon.rawValue] = nil
        StatusItemDefaults[.preferredPosition, ControlItem.Identifier.hiddenDivider.rawValue] = nil
        
        print("[MenuBarManager] Cleanup complete")
    }
    
    // MARK: - State Application
    
    private func applyState() {
        // Propagate state to control items - their Combine publishers will handle the rest
        mainItem?.state = state
        dividerItem?.state = state
        
        // Update main item appearance (icon changes based on state)
        updateMainItemAppearance()
    }
    
    private func updateMainItemAppearance() {
        guard let button = mainItem?.button else { return }
        
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let symbolName = (state == .showItems) ? iconSet.visibleSymbol : iconSet.hiddenSymbol
        
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: state == .showItems ? "Hide menu bar icons" : "Show menu bar icons")?
            .withSymbolConfiguration(config)
        button.image?.isTemplate = true
        
        print("[MenuBarManager] Updated main item appearance: \(symbolName)")
    }
    
    // MARK: - Click Handling
    
    @objc private func handleItemClick(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let identifier = userInfo["identifier"] as? ControlItem.Identifier,
            let event = userInfo["event"] as? NSEvent
        else { return }
        
        switch event.type {
        case .leftMouseUp:
            switch identifier {
            case .mainIcon, .hiddenDivider:
                toggle()
            }
            
        case .rightMouseUp:
            showContextMenu()
            
        default:
            break
        }
    }
    
    private func showContextMenu() {
        guard let button = mainItem?.button else { return }
        
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(
            title: state == .showItems ? "Hide Menu Bar Icons" : "Show Menu Bar Icons",
            action: #selector(menuToggle),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(.separator())
        
        let settingsItem = NSMenuItem(
            title: "Menu Bar Manager Settings...",
            action: #selector(menuOpenSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Show menu at button location
        if let window = button.window {
            let point = NSPoint(x: button.frame.midX, y: button.frame.minY)
            menu.popUp(positioning: nil, at: point, in: window.contentView)
        }
    }
    
    @objc private func menuToggle() {
        toggle()
    }
    
    @objc private func menuOpenSettings() {
        NotificationCenter.default.post(name: .openMenuBarManagerSettings, object: nil)
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
    }
    
    private func handleShowOnHover() {
        guard isEnabled, showOnHover, !isShowOnHoverPrevented else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        
        let menuBarHeight: CGFloat = 24
        let isInMenuBar = mouseLocation.y >= screen.frame.maxY - menuBarHeight
        
        if isInMenuBar && state == .hideItems {
            Task {
                try? await Task.sleep(for: .seconds(showOnHoverDelay))
                let currentLocation = NSEvent.mouseLocation
                let stillInMenuBar = currentLocation.y >= screen.frame.maxY - menuBarHeight
                if stillInMenuBar && state == .hideItems {
                    show()
                }
            }
        }
    }
    
    private func handleMouseDown(_ event: NSEvent) {
        // If clicking outside menu bar while items are shown, hide them
        guard isEnabled, state == .showItems else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        
        let menuBarHeight: CGFloat = 24
        let isInMenuBar = mouseLocation.y >= screen.frame.maxY - menuBarHeight
        
        if !isInMenuBar && showOnHover {
            hide()
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let menuBarManagerStateChanged = Notification.Name("menuBarManagerStateChanged")
    static let openMenuBarManagerSettings = Notification.Name("openMenuBarManagerSettings")
    static let menuBarManagerItemClicked = Notification.Name("menuBarManagerItemClicked")
}
