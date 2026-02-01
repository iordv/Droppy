//
//  MenuBarManagerManager.swift
//  Droppy
//
//  Menu Bar Manager - Hide/show menu bar icons using divider expansion pattern
//  Implementation based on Ice's exact patterns
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
/// Mirrors Ice's StatusItemDefaults exactly
private enum StatusItemDefaults {
    enum Key<Value> {
        @MainActor static var preferredPosition: Key<CGFloat> { Key<CGFloat>() }
        @MainActor static var visible: Key<Bool> { Key<Bool>() }
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

// MARK: - Predicates

/// A namespace for predicates (mirrors Ice's pattern)
private enum Predicates<Input> {
    typealias NonThrowingPredicate = (Input) -> Bool
}

extension Predicates where Input == NSLayoutConstraint {
    /// Creates a predicate that matches the horizontal constraint for a status bar button
    /// Ice pattern: constraint.secondItem === button.superview
    static func controlItemConstraint(button: NSStatusBarButton) -> NonThrowingPredicate {
        return { constraint in
            constraint.secondItem === button.superview
        }
    }
}

// MARK: - Menu Bar Section

/// A representation of a section in the menu bar
/// Mirrors Ice's MenuBarSection
@MainActor
final class MenuBarSection {
    /// Section names
    enum Name: CaseIterable {
        case visible      // The always-visible section (contains the toggle icon)
        case hidden       // The hideable section (expands to hide other items)
        
        var displayString: String {
            switch self {
            case .visible: return "Visible"
            case .hidden: return "Hidden"
            }
        }
    }
    
    /// Possible hiding states (mirrors Ice's ControlItem.HidingState)
    enum HidingState {
        case hideItems  // Divider expanded to 10,000pt, icons pushed off
        case showItems  // Divider at normal width, icons visible
    }
    
    /// The name of this section
    let name: Name
    
    /// The control item that manages this section
    let controlItem: ControlItem
    
    /// A Boolean value that indicates whether the section is hidden
    var isHidden: Bool {
        controlItem.state == .hideItems
    }
    
    /// Creates a section with the given name
    /// Mirrors Ice's convenience init
    init(name: Name) {
        let controlItem = switch name {
        case .visible:
            ControlItem(identifier: .iceIcon, sectionName: name)
        case .hidden:
            ControlItem(identifier: .hidden, sectionName: name)
        }
        self.controlItem = controlItem
        self.name = name
    }
    
    /// Shows the section
    func show() {
        guard isHidden else { return }
        controlItem.state = .showItems
    }
    
    /// Hides the section
    func hide() {
        guard !isHidden else { return }
        controlItem.state = .hideItems
    }
    
    /// Toggles the visibility of the section
    func toggle() {
        if isHidden {
            show()
        } else {
            hide()
        }
    }
}

// MARK: - Control Item

/// A status item that controls a section in the menu bar
/// Mirrors Ice's ControlItem exactly
@MainActor
final class ControlItem {
    /// Possible identifiers for control items (mirrors Ice)
    enum Identifier: String {
        case iceIcon = "DroppyMBM_Icon"
        case hidden = "DroppyMBM_Hidden"
    }
    
    /// Possible lengths for control items (mirrors Ice)
    enum Lengths {
        static let standard: CGFloat = NSStatusItem.variableLength
        static let expanded: CGFloat = 10_000
    }
    
    /// The control item's hiding state
    @Published var state = MenuBarSection.HidingState.hideItems
    
    /// A Boolean value that indicates whether the control item is visible
    @Published var isVisible = true
    
    /// The frame of the control item's window
    @Published private(set) var windowFrame: CGRect?
    
    /// The control item's underlying status item
    private let statusItem: NSStatusItem
    
    /// A horizontal constraint for the control item's content view (THE CONSTRAINT HACK)
    private let constraint: NSLayoutConstraint?
    
    /// The control item's identifier
    private let identifier: Identifier
    
    /// The section name this control item belongs to
    /// CRITICAL: Ice uses section.name for length logic, not identifier
    let sectionName: MenuBarSection.Name
    
    /// Storage for Combine observers
    private var cancellables = Set<AnyCancellable>()
    
    /// The control item's window
    var window: NSWindow? {
        statusItem.button?.window
    }
    
    /// A Boolean value that indicates whether the control item serves as a divider
    var isSectionDivider: Bool {
        identifier != .iceIcon
    }
    
    /// A Boolean value that indicates whether the control item is added to the menu bar
    var isAddedToMenuBar: Bool {
        statusItem.isVisible
    }
    
    /// The status item's button
    var button: NSStatusBarButton? {
        statusItem.button
    }
    
    /// Creates a control item with the given identifier and section name
    init(identifier: Identifier, sectionName: MenuBarSection.Name) {
        let autosaveName = identifier.rawValue
        
        // If the status item doesn't have a preferred position, set it
        // according to the identifier. (Mirrors Ice exactly)
        if StatusItemDefaults[.preferredPosition, autosaveName] == nil {
            switch identifier {
            case .iceIcon:
                StatusItemDefaults[.preferredPosition, autosaveName] = 0
            case .hidden:
                StatusItemDefaults[.preferredPosition, autosaveName] = 1
            }
        }
        
        // Create with length 0 - Combine publishers will set actual length
        self.statusItem = NSStatusBar.system.statusItem(withLength: 0)
        self.statusItem.autosaveName = autosaveName
        self.identifier = identifier
        self.sectionName = sectionName
        
        // THE CONSTRAINT HACK - Mirrors Ice exactly:
        // This could break in a new macOS release, but we need this constraint in order to be
        // able to hide the control item when the "ShowSectionDividers" setting is disabled. A
        // previous implementation used the status item's isVisible property, which was more
        // robust, but would completely remove the control item. With the current set of
        // features, we need to be able to accurately retrieve the items for each section, so
        // we need the control item to always be present to act as a delimiter. The new solution
        // is to remove the constraint that prevents status items from having a length of zero,
        // then resize the content view.
        if
            let button = statusItem.button,
            let constraints = button.window?.contentView?.constraintsAffectingLayout(for: .horizontal),
            let constraint = constraints.first(where: Predicates.controlItemConstraint(button: button))
        {
            self.constraint = constraint
        } else {
            self.constraint = nil
        }
        
        configureStatusItem()
        
        print("[ControlItem] Created \(autosaveName), position=\(String(describing: StatusItemDefaults[.preferredPosition, autosaveName]))")
    }
    
    /// Removes the status item without clearing its stored position (mirrors Ice)
    deinit {
        // Removing the status item has the unwanted side effect of deleting
        // the preferredPosition. Cache and restore it.
        let autosaveName = statusItem.autosaveName as String
        let cached: CGFloat? = StatusItemDefaults[.preferredPosition, autosaveName]
        NSStatusBar.system.removeStatusItem(statusItem)
        StatusItemDefaults[.preferredPosition, autosaveName] = cached
        print("[ControlItem] deinit \(autosaveName), preserved position=\(String(describing: cached))")
    }
    
    /// Sets the initial configuration for the status item
    private func configureStatusItem() {
        // Ice's pattern: defer configureCancellables and updateStatusItem
        defer {
            configureCancellables()
            updateStatusItem(with: state)
        }
        guard let button = statusItem.button else {
            return
        }
        button.target = self
        button.action = #selector(performAction)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    /// Configures the internal observers for the control item (mirrors Ice exactly)
    private func configureCancellables() {
        var c = Set<AnyCancellable>()
        
        // React to state changes for appearance updates
        $state
            .sink { [weak self] state in
                self?.updateStatusItem(with: state)
            }
            .store(in: &c)
        
        // CRITICAL PATTERN FROM ICE:
        // Publishers.CombineLatest($isVisible, $state)
        // Uses section.name for length logic, not identifier!
        Publishers.CombineLatest($isVisible, $state)
            .sink { [weak self] (isVisible, state) in
                guard let self else { return }
                
                if isVisible {
                    // Ice's exact pattern:
                    // statusItem.length = switch section.name {
                    // case .visible: Lengths.standard
                    // case .hidden, .alwaysHidden: switch state { ... }
                    // }
                    statusItem.length = switch sectionName {
                    case .visible:
                        Lengths.standard
                    case .hidden:
                        switch state {
                        case .hideItems: Lengths.expanded
                        case .showItems: Lengths.standard
                        }
                    }
                    constraint?.isActive = true
                } else {
                    // When not visible, use constraint hack for zero width
                    statusItem.length = 0
                    constraint?.isActive = false
                    if let window {
                        var size = window.frame.size
                        size.width = 1
                        window.setContentSize(size)
                    }
                }
                
                print("[ControlItem] \(identifier.rawValue) length=\(statusItem.length), state=\(state), section=\(sectionName)")
            }
            .store(in: &c)
        
        // Sync constraint state with isVisible (mirrors Ice)
        constraint?.publisher(for: \.isActive)
            .removeDuplicates()
            .sink { [weak self] isActive in
                self?.isVisible = isActive
            }
            .store(in: &c)
        
        // Track window frame (mirrors Ice)
        window?.publisher(for: \.frame)
            .sink { [weak self] frame in
                guard
                    let self,
                    let screen = window?.screen,
                    screen.frame.intersects(frame)
                else {
                    return
                }
                windowFrame = frame
            }
            .store(in: &c)
        
        cancellables = c
    }
    
    /// Updates the appearance of the status item using the given hiding state
    /// Mirrors Ice's updateStatusItem exactly
    private func updateStatusItem(with state: MenuBarSection.HidingState) {
        guard let button = statusItem.button else {
            return
        }
        
        switch sectionName {
        case .visible:
            isVisible = true
            // Enable the cell, as it may have been previously disabled
            button.cell?.isEnabled = true
            // Icon changes handled by MenuBarManager
            
        case .hidden:
            switch state {
            case .hideItems:
                isVisible = true
                // Prevent the cell from highlighting while expanded
                button.cell?.isEnabled = false
                // Cell still sometimes briefly flashes on expansion unless manually unhighlighted
                button.isHighlighted = false
                button.image = nil
                
            case .showItems:
                isVisible = true
                // Enable the cell, as it may have been previously disabled
                button.cell?.isEnabled = true
                // Set the divider chevron image (matches Ice's .chevronLarge)
                button.alphaValue = 0.7
                let image = NSImage(size: CGSize(width: 12, height: 12), flipped: false) { bounds in
                    let insetBounds = bounds.insetBy(dx: 1, dy: 1)
                    let path = NSBezierPath()
                    path.move(to: CGPoint(x: (insetBounds.midX + insetBounds.maxX) / 2, y: insetBounds.maxY))
                    path.line(to: CGPoint(x: (insetBounds.minX + insetBounds.midX) / 2, y: insetBounds.midY))
                    path.line(to: CGPoint(x: (insetBounds.midX + insetBounds.maxX) / 2, y: insetBounds.minY))
                    path.lineWidth = 2
                    path.lineCapStyle = .butt
                    NSColor.black.setStroke()
                    path.stroke()
                    return true
                }
                image.isTemplate = true
                button.image = image
            }
        }
    }
    
    @objc private func performAction() {
        guard let event = NSApp.currentEvent else { return }
        NotificationCenter.default.post(
            name: .menuBarManagerItemClicked,
            object: self,
            userInfo: ["identifier": identifier, "event": event]
        )
    }
    
    /// Removes the control item from the menu bar
    func removeFromMenuBar() {
        guard isAddedToMenuBar else { return }
        // Setting statusItem.isVisible to false has the unwanted side effect
        // of deleting the preferredPosition. Cache and restore it.
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
    
    /// Current hiding state (mirrors hidden section's state)
    var state: MenuBarSection.HidingState {
        hiddenSection?.controlItem.state ?? .showItems
    }
    
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
    
    // MARK: - Sections
    
    /// The managed sections in the menu bar
    private(set) var sections = [MenuBarSection]()
    
    /// Returns the section with the given name
    func section(withName name: MenuBarSection.Name) -> MenuBarSection? {
        sections.first { $0.name == name }
    }
    
    /// The visible section (contains the main toggle icon)
    var visibleSection: MenuBarSection? {
        section(withName: .visible)
    }
    
    /// The hidden section (expands to hide other items)
    var hiddenSection: MenuBarSection? {
        section(withName: .hidden)
    }
    
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
    
    // MARK: - Section Initialization
    
    /// Performs the initial setup of the menu bar manager's sections
    /// Mirrors Ice's initializeSections exactly
    private func initializeSections() {
        // Make sure initialization can only happen once
        guard sections.isEmpty else {
            print("[MenuBarManager] Sections already initialized")
            return
        }
        
        // Create sections in order (matches Ice):
        // 1. Visible (main toggle icon)
        // 2. Hidden (divider that expands)
        sections = [
            MenuBarSection(name: .visible),
            MenuBarSection(name: .hidden),
        ]
        
        print("[MenuBarManager] Sections initialized: \(sections.map { $0.name.displayString })")
    }
    
    // MARK: - Public API
    
    /// Enable the menu bar manager
    func enable() {
        guard !isEnabled else { return }
        
        isEnabled = true
        UserDefaults.standard.set(true, forKey: Keys.enabled)
        
        // Initialize sections
        initializeSections()
        
        // Configure Combine observers
        configureCancellables()
        
        // SAFETY-FIRST: Always start with showItems to ensure visibility
        for section in sections {
            section.controlItem.state = .showItems
        }
        
        // Update appearances
        updateMainItemAppearance()
        
        // Start mouse monitoring if hover is enabled
        updateMouseMonitor()
        
        print("[MenuBarManager] Enabled")
    }
    
    /// Disable the menu bar manager
    func disable() {
        guard isEnabled else { return }
        
        // Show all items before disabling
        for section in sections {
            section.show()
        }
        
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Keys.enabled)
        
        // Stop monitors
        stopMouseMonitors()
        cancellables.removeAll()
        
        // Clear sections (ControlItem deinit will preserve positions)
        sections.removeAll()
        
        print("[MenuBarManager] Disabled")
    }
    
    /// Toggle between showing and hiding items
    func toggle() {
        guard let hiddenSection, let visibleSection else { return }
        
        // Toggle the hidden section - this controls the expansion
        hiddenSection.toggle()
        
        // Sync the visible section's state
        visibleSection.controlItem.state = hiddenSection.controlItem.state
        
        UserDefaults.standard.set(state == .hideItems ? "hideItems" : "showItems", forKey: Keys.state)
        
        // Update main icon appearance
        updateMainItemAppearance()
        
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
        StatusItemDefaults[.preferredPosition, "DroppyMBM_Icon"] = nil
        StatusItemDefaults[.preferredPosition, "DroppyMBM_Hidden"] = nil
        
        print("[MenuBarManager] Cleanup complete")
    }
    
    // MARK: - Combine Configuration
    
    private func configureCancellables() {
        var c = Set<AnyCancellable>()
        
        // Observe hidden section state changes (mirrors Ice)
        if let hiddenSection {
            hiddenSection.controlItem.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &c)
        }
        
        cancellables = c
    }
    
    // MARK: - Appearance
    
    private func updateMainItemAppearance() {
        guard let button = visibleSection?.controlItem.button else { return }
        
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
            let event = userInfo["event"] as? NSEvent
        else { return }
        
        switch event.type {
        case .leftMouseUp:
            // Toggle visibility
            toggle()
            
        case .rightMouseUp:
            showContextMenu()
            
        default:
            break
        }
    }
    
    private func showContextMenu() {
        guard let button = visibleSection?.controlItem.button else { return }
        
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
