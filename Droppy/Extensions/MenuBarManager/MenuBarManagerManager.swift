//
//  MenuBarManagerManager.swift
//  Droppy
//
//  Menu Bar Manager - Complete rewrite using exact patterns from open source reference
//

import Cocoa
import Combine

// MARK: - StatusItemDefaults

/// Proxy getters and setters for a status item's user defaults values.
enum StatusItemDefaults {
    /// Keys used to look up user defaults values for status items.
    struct Key<Value> {
        /// The raw value of the key.
        let rawValue: String
        
        /// Returns the full string key for the given autosave name.
        func stringKey(for autosaveName: String) -> String {
            return "NSStatusItem \(rawValue) \(autosaveName)"
        }
    }
    
    /// Accesses the value associated with the specified key and autosave name.
    static subscript<Value>(key: Key<Value>, autosaveName: String) -> Value? {
        get {
            let stringKey = key.stringKey(for: autosaveName)
            return UserDefaults.standard.object(forKey: stringKey) as? Value
        }
        set {
            let stringKey = key.stringKey(for: autosaveName)
            return UserDefaults.standard.set(newValue, forKey: stringKey)
        }
    }
}

extension StatusItemDefaults.Key<CGFloat> {
    static let preferredPosition = Self(rawValue: "Preferred Position")
}

extension StatusItemDefaults.Key<Bool> {
    static let visible = Self(rawValue: "Visible")
}

// MARK: - Predicates

/// A namespace for predicates.
enum Predicates<Input> {
    typealias NonThrowingPredicate = (Input) -> Bool
    
    static func predicate(_ body: @escaping (Input) -> Bool) -> NonThrowingPredicate {
        return body
    }
}

extension Predicates where Input == NSLayoutConstraint {
    static func controlItemConstraint(button: NSStatusBarButton) -> NonThrowingPredicate {
        predicate { constraint in
            constraint.secondItem === button.superview
        }
    }
}

// MARK: - HidingState

/// Possible hiding states for control items.
enum HidingState: String {
    case hideItems
    case showItems
}

// MARK: - MenuBarSection

/// A representation of a section in a menu bar.
@MainActor
final class MenuBarSection {
    /// The name of a menu bar section.
    enum Name: String, CaseIterable {
        case visible = "Visible"
        case hidden = "Hidden"
    }
    
    /// The name of the section.
    let name: Name
    
    /// The control item that manages the section.
    let controlItem: ControlItem
    
    /// Reference to the manager
    private weak var manager: MenuBarManager?
    
    /// A Boolean value that indicates whether the section is hidden.
    var isHidden: Bool {
        switch name {
        case .visible, .hidden:
            return controlItem.state == .hideItems
        }
    }
    
    /// Creates a section with the given name and manager.
    init(name: Name, manager: MenuBarManager) {
        let controlItem = switch name {
        case .visible:
            ControlItem(identifier: .iceIcon, manager: manager)
        case .hidden:
            ControlItem(identifier: .hidden, manager: manager)
        }
        self.name = name
        self.controlItem = controlItem
        self.manager = manager
    }
    
    /// Shows the section.
    func show() {
        guard isHidden else { return }
        guard controlItem.isAddedToMenuBar else { return }
        
        guard let manager else { return }
        
        switch name {
        case .visible:
            guard let hiddenSection = manager.section(withName: .hidden) else { return }
            controlItem.state = .showItems
            hiddenSection.controlItem.state = .showItems
        case .hidden:
            guard let visibleSection = manager.section(withName: .visible) else { return }
            controlItem.state = .showItems
            visibleSection.controlItem.state = .showItems
        }
    }
    
    /// Hides the section.
    func hide() {
        guard !isHidden else { return }
        guard let manager else { return }
        
        switch name {
        case .visible:
            guard let hiddenSection = manager.section(withName: .hidden) else { return }
            controlItem.state = .hideItems
            hiddenSection.controlItem.state = .hideItems
        case .hidden:
            guard let visibleSection = manager.section(withName: .visible) else { return }
            controlItem.state = .hideItems
            visibleSection.controlItem.state = .hideItems
        }
    }
    
    /// Toggles the visibility of the section.
    func toggle() {
        if isHidden {
            show()
        } else {
            hide()
        }
    }
}

// MARK: - ControlItem

/// A status item that controls a section in the menu bar.
@MainActor
final class ControlItem {
    /// Possible identifiers for control items.
    enum Identifier: String, CaseIterable {
        case iceIcon = "DroppyMBM_Icon"
        case hidden = "DroppyMBM_Hidden"
    }
    
    /// Possible lengths for control items.
    enum Lengths {
        static let standard: CGFloat = NSStatusItem.variableLength
        static let expanded: CGFloat = 10_000
    }
    
    /// The control item's hiding state.
    @Published var state = HidingState.hideItems
    
    /// A Boolean value that indicates whether the control item is visible.
    @Published var isVisible = true
    
    /// The frame of the control item's window.
    @Published private(set) var windowFrame: CGRect?
    
    /// Reference to the menu bar manager.
    private weak var manager: MenuBarManager?
    
    /// The control item's underlying status item.
    private let statusItem: NSStatusItem
    
    /// A horizontal constraint for the control item's content view.
    private let constraint: NSLayoutConstraint?
    
    /// The control item's identifier.
    let identifier: Identifier
    
    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()
    
    /// The menu bar section associated with the control item.
    private var section: MenuBarSection? {
        manager?.sections.first { $0.controlItem === self }
    }
    
    /// The control item's window.
    var window: NSWindow? {
        statusItem.button?.window
    }
    
    /// A Boolean value that indicates whether the control item serves as a divider between sections.
    var isSectionDivider: Bool {
        identifier != .iceIcon
    }
    
    /// A Boolean value that indicates whether the control item is currently displayed in the menu bar.
    var isAddedToMenuBar: Bool {
        statusItem.isVisible
    }
    
    /// Creates a control item with the given identifier and manager.
    init(identifier: Identifier, manager: MenuBarManager) {
        let autosaveName = identifier.rawValue
        
        // If the status item doesn't have a preferred position, set it according to the identifier.
        if StatusItemDefaults[.preferredPosition, autosaveName] == nil {
            switch identifier {
            case .iceIcon:
                StatusItemDefaults[.preferredPosition, autosaveName] = 0
            case .hidden:
                StatusItemDefaults[.preferredPosition, autosaveName] = 1
            }
        }
        
        self.statusItem = NSStatusBar.system.statusItem(withLength: 0)
        self.statusItem.autosaveName = autosaveName
        self.identifier = identifier
        self.manager = manager
        
        // This could break in a new macOS release, but we need this constraint in order to be
        // able to hide the control item when the ShowSectionDividers setting is disabled.
        // We need to be able to accurately retrieve the items for each section, so we need
        // the control item to always be present to act as a delimiter. The solution is to
        // remove the constraint that prevents status items from having a length of zero,
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
    }
    
    /// Removes the status item.
    deinit {
        // Note: We cannot access MainActor-isolated StatusItemDefaults from deinit
        // The status item will be removed automatically when the ControlItem is deallocated
    }
    
    /// Configures the internal observers for the control item.
    private func configureCancellables() {
        var c = Set<AnyCancellable>()
        
        $state
            .sink { [weak self] state in
                self?.updateStatusItem(with: state)
            }
            .store(in: &c)
        
        Publishers.CombineLatest($isVisible, $state)
            .sink { [weak self] (isVisible, state) in
                guard
                    let self,
                    let section
                else {
                    return
                }
                if isVisible {
                    statusItem.length = switch section.name {
                    case .visible: Lengths.standard
                    case .hidden:
                        switch state {
                        case .hideItems: Lengths.expanded
                        case .showItems: Lengths.standard
                        }
                    }
                    constraint?.isActive = true
                } else {
                    statusItem.length = 0
                    constraint?.isActive = false
                    if let window {
                        var size = window.frame.size
                        size.width = 1
                        window.setContentSize(size)
                    }
                }
            }
            .store(in: &c)
        
        constraint?.publisher(for: \.isActive)
            .removeDuplicates()
            .sink { [weak self] isActive in
                self?.isVisible = isActive
            }
            .store(in: &c)
        
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
    
    /// Sets the initial configuration for the status item.
    private func configureStatusItem() {
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
    
    /// Updates the appearance of the status item using the given hiding state.
    func updateStatusItem(with state: HidingState) {
        guard
            let section,
            let button = statusItem.button
        else {
            return
        }
        
        switch section.name {
        case .visible:
            isVisible = true
            button.cell?.isEnabled = true
            
            // Get icon set from manager
            let iconSet = manager?.iconSet ?? .eye
            
            // Set the icon based on state
            let iconName = switch state {
            case .hideItems: iconSet.visibleSymbol
            case .showItems: iconSet.hiddenSymbol
            }
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Toggle Menu Bar")
            
            print("[MenuBarManager] Updated main item appearance: \(iconName)")
            
        case .hidden:
            switch state {
            case .hideItems:
                isVisible = true
                // Prevent the cell from highlighting while expanded.
                button.cell?.isEnabled = false
                // Cell still sometimes briefly flashes on expansion unless manually unhighlighted.
                button.isHighlighted = false
                button.image = nil
            case .showItems:
                isVisible = true
                button.cell?.isEnabled = true
                // Set the divider chevron image
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
    
    /// Performs the control item's action.
    @objc private func performAction() {
        guard let event = NSApp.currentEvent else { return }
        
        switch event.type {
        case .leftMouseUp:
            section?.toggle()
        case .rightMouseUp:
            showContextMenu()
        default:
            break
        }
    }
    
    /// Shows a context menu for the control item.
    private func showContextMenu() {
        let menu = NSMenu(title: "Menu Bar Manager")
        
        let settingsItem = NSMenuItem(
            title: "Menu Bar Manager Settings…",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(.separator())
        
        let disableItem = NSMenuItem(
            title: "Disable Menu Bar Manager",
            action: #selector(disableExtension),
            keyEquivalent: ""
        )
        disableItem.target = self
        menu.addItem(disableItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func openSettings() {
        NotificationCenter.default.post(name: .menuBarManagerOpenSettings, object: nil)
    }
    
    @objc private func disableExtension() {
        NotificationCenter.default.post(name: .menuBarManagerDisable, object: nil)
    }
    
    /// Adds the control item to the menu bar.
    func addToMenuBar() {
        guard !isAddedToMenuBar else { return }
        statusItem.isVisible = true
    }
    
    /// Removes the control item from the menu bar.
    func removeFromMenuBar() {
        guard isAddedToMenuBar else { return }
        // Setting `statusItem.isVisible` to `false` has the unwanted side
        // effect of deleting the preferredPosition. Cache and restore it.
        let autosaveName = statusItem.autosaveName as String
        let cached = StatusItemDefaults[.preferredPosition, autosaveName]
        statusItem.isVisible = false
        StatusItemDefaults[.preferredPosition, autosaveName] = cached
    }
}

// MARK: - MenuBarManager

// MARK: - MBMIconSet

/// Icon sets for the menu bar toggle button
enum MBMIconSet: String, CaseIterable, Identifiable {
    case eye = "eye"
    case chevron = "chevron"
    case circle = "circle"
    case line = "line"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .eye: return "Eye"
        case .chevron: return "Chevron"
        case .circle: return "Circle"
        case .line: return "Line"
        }
    }
    
    var visibleSymbol: String {
        switch self {
        case .eye: return "eye.fill"
        case .chevron: return "chevron.right"
        case .circle: return "circle.fill"
        case .line: return "line.horizontal.3"
        }
    }
    
    var hiddenSymbol: String {
        switch self {
        case .eye: return "eye.slash.fill"
        case .chevron: return "chevron.left"
        case .circle: return "circle"
        case .line: return "line.horizontal.3.decrease"
        }
    }
}

/// Manager for the state of the menu bar.
@MainActor
final class MenuBarManager: ObservableObject {
    /// Shared singleton instance
    static let shared = MenuBarManager()
    
    /// The managed sections in the menu bar.
    private(set) var sections = [MenuBarSection]()
    
    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()
    
    /// Published state for current hiding state
    @Published private(set) var state: HidingState = .hideItems
    
    /// Whether the manager is enabled
    @Published var isEnabled: Bool {
        didSet { 
            UserDefaults.standard.set(isEnabled, forKey: "MenuBarManager_Enabled")
            if isEnabled {
                enable()
            } else {
                disable()
            }
        }
    }
    
    /// Show on hover setting
    @Published var showOnHover: Bool {
        didSet { 
            UserDefaults.standard.set(showOnHover, forKey: "MenuBarManager_ShowOnHover")
            setupMouseMonitoring()
        }
    }
    
    /// Hover delay in seconds
    @Published var showOnHoverDelay: Double {
        didSet { UserDefaults.standard.set(showOnHoverDelay, forKey: "MenuBarManager_ShowOnHoverDelay") }
    }
    
    /// Icon set for the toggle button
    @Published var iconSet: MBMIconSet {
        didSet { 
            UserDefaults.standard.set(iconSet.rawValue, forKey: "MenuBarManager_IconSet")
            updateIconAppearance()
        }
    }
    
    /// Mouse monitoring
    private var mouseMonitor: Any?
    
    /// Initializes a new menu bar manager instance.
    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "MenuBarManager_Enabled")
        self.showOnHover = UserDefaults.standard.bool(forKey: "MenuBarManager_ShowOnHover")
        let storedDelay = UserDefaults.standard.double(forKey: "MenuBarManager_ShowOnHoverDelay")
        self.showOnHoverDelay = storedDelay == 0 ? 0.3 : storedDelay
        self.iconSet = MBMIconSet(rawValue: UserDefaults.standard.string(forKey: "MenuBarManager_IconSet") ?? "") ?? .eye
        
        // Check if extension was removed
        if UserDefaults.standard.bool(forKey: "MenuBarManager_Removed") {
            print("[MenuBarManager] Extension was removed, not initializing")
            return
        }
        
        print("[MenuBarManager] INIT CALLED")
        print("[MenuBarManager] Extension not removed, loading settings...")
        
        performSetup()
    }
    
    deinit {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
    }
    
    /// Performs the initial setup of the menu bar manager.
    func performSetup() {
        initializeSections()
        configureCancellables()
        setupMouseMonitoring()
        print("[MenuBarManager] Enabled")
    }
    
    /// Performs the initial setup of the menu bar manager's sections.
    private func initializeSections() {
        // Make sure initialization can only happen once.
        guard sections.isEmpty else {
            print("[MenuBarManager] Sections already initialized")
            return
        }
        
        // CRITICAL: Order matters! Visible first, then hidden.
        sections = [
            MenuBarSection(name: .visible, manager: self),
            MenuBarSection(name: .hidden, manager: self),
        ]
        
        print("[MenuBarManager] Sections initialized: \(sections.map { $0.name.rawValue })")
    }
    
    /// Configures the internal observers for the manager.
    private func configureCancellables() {
        var c = Set<AnyCancellable>()
        
        // Track state changes from sections
        if let hiddenSection = section(withName: .hidden) {
            hiddenSection.controlItem.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newState in
                    self?.state = newState
                }
                .store(in: &c)
        }
        
        cancellables = c
    }
    
    /// Sets up mouse monitoring for show on hover.
    private func setupMouseMonitoring() {
        guard showOnHover else { return }
        
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
        }
    }
    
    /// Handles mouse movement for show on hover.
    private func handleMouseMoved() {
        guard showOnHover else { return }
        
        guard let screen = NSScreen.main else { return }
        let mouseLocation = NSEvent.mouseLocation
        
        // Check if mouse is in the menu bar area
        let menuBarHeight: CGFloat = 24
        let isInMenuBar = mouseLocation.y >= screen.frame.maxY - menuBarHeight
        
        if let hiddenSection = section(withName: .hidden) {
            if isInMenuBar && hiddenSection.isHidden {
                hiddenSection.show()
            } else if !isInMenuBar && !hiddenSection.isHidden {
                // Add a small delay before hiding
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard self != nil else { return }
                    let currentLocation = NSEvent.mouseLocation
                    let stillInMenuBar = currentLocation.y >= screen.frame.maxY - menuBarHeight
                    if !stillInMenuBar {
                        hiddenSection.hide()
                    }
                }
            }
        }
    }
    
    /// Returns the menu bar section with the given name.
    func section(withName name: MenuBarSection.Name) -> MenuBarSection? {
        sections.first { $0.name == name }
    }
    
    /// Toggles the hidden section.
    func toggle() {
        guard let hiddenSection = section(withName: .hidden) else { return }
        hiddenSection.toggle()
        print("[MenuBarManager] Toggled to: \(hiddenSection.controlItem.state)")
    }
    
    /// Enables the menu bar manager.
    func enable() {
        UserDefaults.standard.set(false, forKey: "MenuBarManager_Removed")
        
        if sections.isEmpty {
            performSetup()
        }
        
        for section in sections {
            section.controlItem.addToMenuBar()
        }
        
        print("[MenuBarManager] Enabled")
    }
    
    /// Disables the menu bar manager.
    func disable() {
        for section in sections {
            section.controlItem.removeFromMenuBar()
        }
        
        UserDefaults.standard.set(true, forKey: "MenuBarManager_Removed")
        print("[MenuBarManager] Disabled")
    }
    
    /// Updates the icon appearance based on current iconSet
    func updateIconAppearance() {
        guard let visibleSection = section(withName: .visible) else { return }
        visibleSection.controlItem.updateStatusItem(with: visibleSection.controlItem.state)
    }
    
    /// Cleanup when extension is removed
    func cleanup() {
        disable()
        sections.removeAll()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let menuBarManagerItemClicked = Notification.Name("menuBarManagerItemClicked")
    static let menuBarManagerOpenSettings = Notification.Name("menuBarManagerOpenSettings")
    static let menuBarManagerDisable = Notification.Name("menuBarManagerDisable")
}
