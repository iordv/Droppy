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
        // Note: Auto-hide is now scheduled when cursor leaves menu bar, not when showing
    }
    
    /// Hides the section.
    func hide() {
        guard !isHidden else { return }
        guard let manager else { return }
        
        // Cancel any pending auto-hide
        manager.cancelAutoHide()
        
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
            
            // Create the base image
            var image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Toggle Menu Bar")
            
            // Apply gradient if enabled
            if manager?.useGradientIcon == true, let baseImage = image {
                // Use the original image size to prevent distortion
                let size = baseImage.size
                let gradientImage = NSImage(size: size, flipped: false) { bounds in
                    // Draw gradient background masked by the symbol
                    guard let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
                    guard let context = NSGraphicsContext.current?.cgContext else { return false }
                    
                    // Create grayscale gradient (light to dark, top to bottom)
                    let lightGray = NSColor(white: 0.7, alpha: 1.0).cgColor
                    let darkGray = NSColor(white: 0.3, alpha: 1.0).cgColor
                    let colors = [lightGray, darkGray] as CFArray
                    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return false }
                    
                    // Clip to the symbol shape
                    context.clip(to: bounds, mask: cgImage)
                    
                    // Draw gradient from top to bottom
                    context.drawLinearGradient(gradient, start: CGPoint(x: bounds.midX, y: bounds.maxY), end: CGPoint(x: bounds.midX, y: 0), options: [])
                    
                    return true
                }
                gradientImage.isTemplate = false
                image = gradientImage
            }
            
            button.image = image
            
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
                
                // Check if chevron separator should be shown
                if manager?.showChevronSeparator == true {
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
                } else {
                    // No chevron - just hide it
                    button.alphaValue = 0
                    button.image = nil
                }
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
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)
        
        menu.addItem(.separator())
        
        let disableItem = NSMenuItem(
            title: "Disable Menu Bar Manager",
            action: #selector(disableExtension),
            keyEquivalent: ""
        )
        disableItem.target = self
        disableItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Disable")
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
    
    /// Triggers the initial state update. Must be called after sections are populated.
    func triggerInitialState() {
        guard let section else {
            print("[ControlItem] triggerInitialState: section is nil!")
            return
        }
        
        print("[ControlItem] Triggering initial state for \(section.name.rawValue)")
        
        // Set the length based on section
        statusItem.length = switch section.name {
        case .visible: Lengths.standard
        case .hidden:
            switch state {
            case .hideItems: Lengths.expanded
            case .showItems: Lengths.standard
            }
        }
        
        // Make sure constraint is active
        constraint?.isActive = true
        
        // Update the appearance
        updateStatusItem(with: state)
        
        print("[ControlItem] Status item length: \(statusItem.length), isVisible: \(statusItem.isVisible)")
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
    case dot = "dot"
    case arrow = "arrow"
    case square = "square"
    case diamond = "diamond"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .eye: return "Eye"
        case .chevron: return "Chevron"
        case .circle: return "Circle"
        case .line: return "Lines"
        case .dot: return "Dot"
        case .arrow: return "Arrow"
        case .square: return "Square"
        case .diamond: return "Diamond"
        }
    }
    
    var visibleSymbol: String {
        switch self {
        case .eye: return "eye.fill"
        case .chevron: return "chevron.right"
        case .circle: return "circle.fill"
        case .line: return "line.3.horizontal"
        case .dot: return "smallcircle.filled.circle"
        case .arrow: return "arrowtriangle.right.fill"
        case .square: return "square.fill"
        case .diamond: return "diamond.fill"
        }
    }
    
    var hiddenSymbol: String {
        switch self {
        case .eye: return "eye.slash.fill"
        case .chevron: return "chevron.left"
        case .circle: return "circle"
        case .line: return "line.3.horizontal.decrease"
        case .dot: return "smallcircle.circle"
        case .arrow: return "arrowtriangle.left.fill"
        case .square: return "square"
        case .diamond: return "diamond"
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
    
    /// Whether to use gradient-colored icon
    @Published var useGradientIcon: Bool {
        didSet {
            UserDefaults.standard.set(useGradientIcon, forKey: "MenuBarManager_UseGradientIcon")
            updateIconAppearance()
        }
    }
    
    /// Auto-hide delay in seconds (0 means don't auto-hide)
    @Published var autoHideDelay: Double {
        didSet { UserDefaults.standard.set(autoHideDelay, forKey: "MenuBarManager_AutoHideDelay") }
    }
    
    /// Whether to show chevron separator when icons are hidden
    @Published var showChevronSeparator: Bool {
        didSet {
            UserDefaults.standard.set(showChevronSeparator, forKey: "MenuBarManager_ShowChevronSeparator")
            // Update the hidden section's appearance
            if let hiddenSection = section(withName: .hidden) {
                hiddenSection.controlItem.updateStatusItem(with: hiddenSection.controlItem.state)
            }
        }
    }
    
    /// Spacing offset for menu bar items (-8 to +8, where 0 is default)
    /// Affects NSStatusItemSpacing and NSStatusItemSelectionPadding system-wide
    @Published var itemSpacingOffset: Int {
        didSet {
            UserDefaults.standard.set(itemSpacingOffset, forKey: "MenuBarManager_ItemSpacingOffset")
        }
    }
    
    /// Whether spacing changes are pending restart
    @Published var spacingChangesPending: Bool = false
    
    /// Default spacing value used by macOS
    private let defaultSpacingValue = 16
    
    /// Applies the current item spacing offset (requires restarting apps with menu bar items)
    func applyItemSpacing() async throws {
        if itemSpacingOffset == 0 {
            // Remove custom values to restore defaults
            try await runDefaultsCommand(["delete", "-currentHost", "-globalDomain", "NSStatusItemSpacing"])
            try await runDefaultsCommand(["delete", "-currentHost", "-globalDomain", "NSStatusItemSelectionPadding"])
        } else {
            let newValue = defaultSpacingValue + itemSpacingOffset
            try await runDefaultsCommand(["-currentHost", "write", "-globalDomain", "NSStatusItemSpacing", "-int", String(newValue)])
            try await runDefaultsCommand(["-currentHost", "write", "-globalDomain", "NSStatusItemSelectionPadding", "-int", String(newValue)])
        }
        
        // Mark that changes need restart
        await MainActor.run {
            spacingChangesPending = true
        }
    }
    
    /// Runs a defaults command
    private func runDefaultsCommand(_ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/defaults")
        process.arguments = arguments
        
        try await Task.detached {
            try process.run()
            process.waitUntilExit()
        }.value
    }
    
    /// Mouse monitoring
    private var mouseMonitor: Any?
    
    /// Auto-hide timer
    private var autoHideTimer: Timer?
    
    /// Schedules auto-hide after showing items
    func scheduleAutoHide() {
        // Cancel any existing timer
        cancelAutoHide()
        
        // Only schedule if auto-hide is enabled (delay > 0)
        guard autoHideDelay > 0 else {
            print("[MenuBarManager] Auto-hide disabled (delay = 0)")
            return
        }
        
        print("[MenuBarManager] Scheduling auto-hide in \(autoHideDelay)s")
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                print("[MenuBarManager] Auto-hide timer fired")
                strongSelf.hideAllSections()
            }
        }
    }
    
    /// Cancels any pending auto-hide
    func cancelAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }
    
    /// Hides all sections
    private func hideAllSections() {
        print("[MenuBarManager] Hiding all sections")
        for section in sections {
            section.hide()
        }
    }
    
    /// Initializes a new menu bar manager instance.
    init() {
        // Load saved settings - use unified ExtensionType.isRemoved as primary source
        // Also check legacy key for backwards compatibility
        let isRemovedViaExtension = ExtensionType.menuBarManager.isRemoved
        let isRemovedViaLegacy = UserDefaults.standard.bool(forKey: "MenuBarManager_Removed")
        let savedEnabled = !isRemovedViaExtension && !isRemovedViaLegacy
        
        self.isEnabled = savedEnabled
        self.showOnHover = UserDefaults.standard.bool(forKey: "MenuBarManager_ShowOnHover")
        let storedDelay = UserDefaults.standard.double(forKey: "MenuBarManager_ShowOnHoverDelay")
        self.showOnHoverDelay = storedDelay == 0 ? 0.3 : storedDelay
        self.iconSet = MBMIconSet(rawValue: UserDefaults.standard.string(forKey: "MenuBarManager_IconSet") ?? "") ?? .eye
        
        // Load additional settings
        self.useGradientIcon = UserDefaults.standard.bool(forKey: "MenuBarManager_UseGradientIcon")
        let storedAutoHide = UserDefaults.standard.double(forKey: "MenuBarManager_AutoHideDelay")
        self.autoHideDelay = storedAutoHide  // 0 means don't auto-hide
        // Default to true for chevron separator
        if UserDefaults.standard.object(forKey: "MenuBarManager_ShowChevronSeparator") == nil {
            self.showChevronSeparator = true
        } else {
            self.showChevronSeparator = UserDefaults.standard.bool(forKey: "MenuBarManager_ShowChevronSeparator")
        }
        
        // Load item spacing offset (default is 0)
        self.itemSpacingOffset = UserDefaults.standard.integer(forKey: "MenuBarManager_ItemSpacingOffset")
        
        print("[MenuBarManager] INIT CALLED, isEnabled: \(savedEnabled)")
        
        // Always perform setup to create sections
        performSetup()
        
        // If not enabled, remove from menu bar
        if !savedEnabled {
            for section in sections {
                section.controlItem.removeFromMenuBar()
            }
        }
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
        
        // CRITICAL: Trigger initial state update AFTER sections are populated
        // This is necessary because the ControlItem's section lookup fails during init
        // since sections array is not yet assigned
        for section in sections {
            section.controlItem.triggerInitialState()
            }
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
        
        // Listen for open settings notification
        NotificationCenter.default.publisher(for: .menuBarManagerOpenSettings)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                SettingsWindowController.shared.showSettings(openingExtension: .menuBarManager)
            }
            .store(in: &c)
        
        // Listen for disable notification
        NotificationCenter.default.publisher(for: .menuBarManagerDisable)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isEnabled = false
            }
            .store(in: &c)
        
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
                // Cursor entered menu bar - cancel any auto-hide timer and show
                cancelAutoHide()
                hiddenSection.show()
            } else if isInMenuBar && !hiddenSection.isHidden {
                // Cursor still in menu bar while items are shown - cancel any pending hide
                cancelAutoHide()
            } else if !isInMenuBar && !hiddenSection.isHidden {
                // Cursor left menu bar - schedule auto-hide if enabled, otherwise use hover delay
                if autoHideDelay > 0 {
                    // Start auto-hide timer when cursor leaves (not already running)
                    if autoHideTimer == nil {
                        scheduleAutoHide()
                    }
                } else {
                    // Auto-hide disabled - use hover delay to hide
                    DispatchQueue.main.asyncAfter(deadline: .now() + showOnHoverDelay) { [weak self] in
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
        // Clear both legacy and unified removed flags
        UserDefaults.standard.set(false, forKey: "MenuBarManager_Removed")
        ExtensionType.menuBarManager.setRemoved(false)
        
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
        
        // Use unified state - both for backwards compatibility
        UserDefaults.standard.set(true, forKey: "MenuBarManager_Removed")
        ExtensionType.menuBarManager.setRemoved(true)
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
