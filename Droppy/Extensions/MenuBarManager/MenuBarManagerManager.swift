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
        case alwaysHidden = "Always Hidden"
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
        case .visible, .hidden, .alwaysHidden:
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
        case .alwaysHidden:
            ControlItem(identifier: .alwaysHidden, manager: manager)
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
        case .visible, .hidden:
            guard let visibleSection = manager.section(withName: .visible),
                  let hiddenSection = manager.section(withName: .hidden),
                  let alwaysHiddenSection = manager.section(withName: .alwaysHidden) else {
                return
            }
            visibleSection.controlItem.state = .showItems
            hiddenSection.controlItem.state = .showItems
            // Always-hidden stays collapsed during normal menu-bar hover reveal.
            alwaysHiddenSection.controlItem.state = .hideItems
        case .alwaysHidden:
            guard let visibleSection = manager.section(withName: .visible),
                  let hiddenSection = manager.section(withName: .hidden),
                  let alwaysHiddenSection = manager.section(withName: .alwaysHidden) else {
                return
            }
            visibleSection.controlItem.state = .showItems
            hiddenSection.controlItem.state = .showItems
            alwaysHiddenSection.controlItem.state = .showItems
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
        case .visible, .hidden:
            guard let visibleSection = manager.section(withName: .visible),
                  let hiddenSection = manager.section(withName: .hidden),
                  let alwaysHiddenSection = manager.section(withName: .alwaysHidden) else {
                return
            }
            visibleSection.controlItem.state = .hideItems
            hiddenSection.controlItem.state = .hideItems
            alwaysHiddenSection.controlItem.state = .hideItems
        case .alwaysHidden:
            controlItem.state = .hideItems
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
        case alwaysHidden = "DroppyMBM_AlwaysHidden"
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

    /// Reused context menu to avoid recreating menu/window objects on every right click.
    private lazy var contextMenu: NSMenu = {
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

        return menu
    }()
    
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
            case .alwaysHidden:
                StatusItemDefaults[.preferredPosition, autosaveName] = 2
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
                    case .hidden, .alwaysHidden:
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
        // Show context menu on right-down to avoid accidental activation of the first menu item.
        button.sendAction(on: [.leftMouseUp, .rightMouseDown])
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
            button.image =
                manager?.toggleIconImage(for: state)
                ?? NSImage(systemSymbolName: iconName, accessibilityDescription: "Toggle Menu Bar")
            
        case .hidden:
            guard manager?.showChevronSeparator == true else {
                isVisible = false
                button.cell?.isEnabled = false
                button.isHighlighted = false
                button.alphaValue = 0
                button.image = nil
                return
            }

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

                // Render a neutral separator line between visible and hidden items.
                button.alphaValue = 0.7
                if let image = NSImage(systemSymbolName: "line.vertical", accessibilityDescription: nil) {
                    image.isTemplate = true
                    button.image = image
                } else {
                    let image = NSImage(size: CGSize(width: 10, height: 12), flipped: false) { bounds in
                        let x = bounds.midX
                        let path = NSBezierPath()
                        path.move(to: CGPoint(x: x, y: bounds.minY + 1))
                        path.line(to: CGPoint(x: x, y: bounds.maxY - 1))
                        path.lineWidth = 1.5
                        path.lineCapStyle = .round
                        NSColor.labelColor.setStroke()
                        path.stroke()
                        return true
                    }
                    image.isTemplate = true
                    button.image = image
                }
            }
        case .alwaysHidden:
            isVisible = true
            button.cell?.isEnabled = false
            button.isHighlighted = false
            // Keep this divider functionally present for section layout,
            // but visually hidden in normal usage.
            button.alphaValue = 0
            button.image = nil
        }
    }
    
    /// Performs the control item's action.
    @objc private func performAction() {
        guard let event = NSApp.currentEvent else { return }
        
        switch event.type {
        case .leftMouseUp:
            // When hover mode is enabled, clicking toggles the locked visible state
            if let manager = manager, manager.showOnHover {
                if let hiddenSection = section, hiddenSection.name == .hidden || hiddenSection.name == .visible {
                    if manager.isLockedVisible {
                        // Currently locked visible - unlock and hide
                        manager.isLockedVisible = false
                        section?.hide()
                    } else {
                        // Not locked - lock visible and show
                        manager.isLockedVisible = true
                        section?.show()
                    }
                } else {
                    section?.toggle()
                }
            } else {
                // Normal toggle behavior when hover is disabled
                section?.toggle()
            }
        case .rightMouseDown:
            showContextMenu()
        default:
            break
        }
    }
    
    /// Shows a context menu for the control item.
    private func showContextMenu() {
        guard let button = statusItem.button else { return }

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(contextMenu, with: event, for: button)
        } else {
            contextMenu.popUp(positioning: nil, at: NSPoint(x: button.bounds.midX, y: button.bounds.maxY), in: button)
        }
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
        case .hidden, .alwaysHidden:
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
    case umbrella = "umbrella"
    case sunglasses = "sunglasses"
    
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
        case .umbrella: return "Umbrella"
        case .sunglasses: return "Sunglasses"
        }
    }
    
    var visibleSymbol: String {
        switch self {
        case .eye: return "eye.fill"
        case .chevron: return "chevron.left"
        case .circle: return "circle.fill"
        case .line: return "line.3.horizontal"
        case .dot: return "smallcircle.filled.circle"
        case .arrow: return "arrowtriangle.right.fill"
        case .square: return "square.fill"
        case .diamond: return "diamond.fill"
        case .umbrella: return "umbrella.fill"
        case .sunglasses: return "sunglasses"
        }
    }
    
    var hiddenSymbol: String {
        switch self {
        case .eye: return "eye.slash.fill"
        case .chevron: return "chevron.right"
        case .circle: return "circle"
        case .line: return "line.3.horizontal.decrease"
        case .dot: return "smallcircle.circle"
        case .arrow: return "arrowtriangle.left.fill"
        case .square: return "square"
        case .diamond: return "diamond"
        case .umbrella: return "umbrella"
        case .sunglasses: return "sunglasses"
        }
    }
}

// MARK: - RehideStrategy

/// How hidden menu bar items rehide after being revealed.
enum RehideStrategy: String, CaseIterable, Identifiable {
    /// Rehide when clicking outside the menu bar area.
    case smart = "smart"
    /// Rehide after a configurable timer delay.
    case timed = "timed"
    /// Rehide when the frontmost application changes.
    case focusLoss = "focusLoss"
    /// Never auto-rehide; only hide on explicit click.
    case manual = "manual"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .smart: return "Smart"
        case .timed: return "Timed"
        case .focusLoss: return "Focus Loss"
        case .manual: return "Manual"
        }
    }
    
    var description: String {
        switch self {
        case .smart: return "Rehide when you click outside the menu bar"
        case .timed: return "Rehide after a delay"
        case .focusLoss: return "Rehide when switching apps"
        case .manual: return "Only hide when you click the toggle"
        }
    }
}

// MARK: - HoverModifierKey

/// Optional modifier key that must be held while hovering to reveal hidden icons.
enum HoverModifierKey: String, CaseIterable, Identifiable {
    case none = "none"
    case option = "option"
    case command = "command"
    case control = "control"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .option: return "⌥ Option"
        case .command: return "⌘ Command"
        case .control: return "⌃ Control"
        }
    }
    
    var eventFlags: NSEvent.ModifierFlags? {
        switch self {
        case .none: return nil
        case .option: return .option
        case .command: return .command
        case .control: return .control
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
        didSet {
            let clamped = min(max(showOnHoverDelay, 0), 2)
            if clamped != showOnHoverDelay {
                showOnHoverDelay = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: "MenuBarManager_ShowOnHoverDelay")
        }
    }
    
    /// Icon set for the toggle button
    @Published var iconSet: MBMIconSet {
        didSet { 
            UserDefaults.standard.set(iconSet.rawValue, forKey: "MenuBarManager_IconSet")
            toggleIconCache.removeAll()
            updateIconAppearance()
        }
    }
    
    /// Whether to use gradient-colored icon
    @Published var useGradientIcon: Bool {
        didSet {
            UserDefaults.standard.set(useGradientIcon, forKey: "MenuBarManager_UseGradientIcon")
            toggleIconCache.removeAll()
            updateIconAppearance()
        }
    }
    
    /// Auto-hide delay in seconds (used by `.timed` rehide strategy)
    @Published var autoHideDelay: Double {
        didSet { UserDefaults.standard.set(autoHideDelay, forKey: "MenuBarManager_AutoHideDelay") }
    }
    
    /// How hidden icons should rehide after being revealed.
    @Published var rehideStrategy: RehideStrategy {
        didSet {
            UserDefaults.standard.set(rehideStrategy.rawValue, forKey: "MenuBarManager_RehideStrategy")
            setupRehideObservers()
        }
    }
    
    /// Optional modifier key that must be held when hovering to reveal.
    @Published var hoverModifierKey: HoverModifierKey {
        didSet {
            UserDefaults.standard.set(hoverModifierKey.rawValue, forKey: "MenuBarManager_HoverModifierKey")
        }
    }
    
    /// Whether to show a separator between visible and hidden icons.
    @Published var showChevronSeparator: Bool {
        didSet {
            // Separator is required for correct hide/reveal behavior.
            if showChevronSeparator == false {
                showChevronSeparator = true
                return
            }
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
    
    /// Whether icons are locked visible (overrides hover behavior)
    /// When true, clicking the eye locks icons visible; clicking again unlocks
    @Published var isLockedVisible: Bool = false
    
    /// Whether currently applying spacing changes
    @Published var isApplyingSpacing: Bool = false

    /// Cache for rendered toggle icons so hover/show-hide doesn't redraw every transition.
    private var toggleIconCache: [String: NSImage] = [:]

    /// Prevent cross-singleton callbacks while shared singletons are still initializing.
    private var isInitializing = true
    
    /// Default spacing value used by macOS
    private let defaultSpacingValue = 16
    
    /// Applies the current item spacing offset and restarts apps with menu bar items
    func applyItemSpacing() async {
        await MainActor.run { isApplyingSpacing = true }
        
        do {
            if itemSpacingOffset == 0 {
                // Remove custom values to restore defaults
                try? await runDefaultsCommand(["delete", "-currentHost", "-globalDomain", "NSStatusItemSpacing"])
                try? await runDefaultsCommand(["delete", "-currentHost", "-globalDomain", "NSStatusItemSelectionPadding"])
            } else {
                let newValue = defaultSpacingValue + itemSpacingOffset
                try await runDefaultsCommand(["-currentHost", "write", "-globalDomain", "NSStatusItemSpacing", "-int", String(newValue)])
                try await runDefaultsCommand(["-currentHost", "write", "-globalDomain", "NSStatusItemSelectionPadding", "-int", String(newValue)])
            }
            
            // Wait a moment for defaults to be written
            try? await Task.sleep(for: .milliseconds(100))
            
            // Restart the menu bar
            await restartMenuBar()
            
        } catch {
            print("[MenuBarManager] Failed to apply spacing: \(error)")
        }
        
        await MainActor.run { isApplyingSpacing = false }
    }
    
    /// Restarts the menu bar to apply spacing changes
    private func restartMenuBar() async {
        // Restart SystemUIServer which handles the menu bar
        // This will refresh all menu bar items with new spacing
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/killall")
        process.arguments = ["SystemUIServer"]
        
        try? await Task.detached {
            try process.run()
            process.waitUntilExit()
        }.value
        
        // Also restart ControlCenter for Control Center items
        let controlCenterProcess = Process()
        controlCenterProcess.executableURL = URL(filePath: "/usr/bin/killall")
        controlCenterProcess.arguments = ["ControlCenter"]
        
        try? await Task.detached {
            try controlCenterProcess.run()
            controlCenterProcess.waitUntilExit()
        }.value
        
        print("[MenuBarManager] Restarted menu bar with new spacing")
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

    /// Returns the visible toggle icon image for the provided state.
    func toggleIconImage(for state: HidingState) -> NSImage? {
        let symbolName = switch state {
        case .hideItems: iconSet.visibleSymbol
        case .showItems: iconSet.hiddenSymbol
        }
        let cacheKey = "\(symbolName)|\(useGradientIcon)"

        if let cachedImage = toggleIconCache[cacheKey] {
            return cachedImage
        }

        guard let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Toggle Menu Bar") else {
            return nil
        }

        if !useGradientIcon {
            baseImage.isTemplate = true
            toggleIconCache[cacheKey] = baseImage
            return baseImage
        }

        guard let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            baseImage.isTemplate = true
            toggleIconCache[cacheKey] = baseImage
            return baseImage
        }

        let gradientImage = NSImage(size: baseImage.size, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let lightGray = NSColor(white: 0.7, alpha: 1.0).cgColor
            let darkGray = NSColor(white: 0.3, alpha: 1.0).cgColor
            let colors = [lightGray, darkGray] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) else {
                return false
            }

            context.clip(to: bounds, mask: cgImage)
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: bounds.midX, y: bounds.maxY),
                end: CGPoint(x: bounds.midX, y: bounds.minY),
                options: []
            )
            return true
        }
        gradientImage.isTemplate = false
        toggleIconCache[cacheKey] = gradientImage
        return gradientImage
    }
    
    /// Mouse monitoring
    private var mouseMonitor: Any?
    
    /// Global mouse-down monitor for `.smart` rehide strategy.
    private var smartRehideMouseDownMonitor: Any?
    
    /// Workspace observation for `.focusLoss` rehide strategy.
    private var focusLossObserver: NSObjectProtocol?

    /// Last processed mouse-move timestamp for hover handling.
    private var lastMouseMoveProcessTime: TimeInterval = 0

    /// NSMenu tracking depth for fast early-out while any menu is open.
    private var activeMenuTrackingDepth: Int = 0

    /// Uptime timestamp for the latest NSMenu tracking notification.
    private var lastMenuTrackingEventTime: TimeInterval = 0

    /// Cached result for active menu-window detection to avoid scanning NSApp.windows on every mouse event.
    private var cachedHasActiveMenuWindow = false

    /// Timestamp for the menu-window cache.
    private var lastActiveMenuWindowCheckTime: TimeInterval = 0

    /// Tracks whether hover logic is currently paused because a menu is open.
    private var isHoverPausedForActiveMenu = false
    
    /// Auto-hide timer
    private var autoHideTimer: Timer?

    /// Debounced hide task used when auto-hide is disabled and hover delay is active.
    /// Keeping only one pending task prevents unbounded closure buildup on mouse move events.
    private var pendingHoverHideWorkItem: DispatchWorkItem?
    
    /// Schedules auto-hide after showing items
    func scheduleAutoHide() {
        // Cancel any existing timer
        cancelAutoHide()
        cancelPendingHoverHide()
        
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
                let now = ProcessInfo.processInfo.systemUptime
                if strongSelf.shouldDeferAutoHide(now: now) {
                    strongSelf.scheduleAutoHideRetry()
                    return
                }
                strongSelf.hideAllSections()
            }
        }
    }
    
    /// Cancels any pending auto-hide
    func cancelAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    /// Cancels any pending delayed hide task scheduled from mouse move events.
    private func cancelPendingHoverHide() {
        pendingHoverHideWorkItem?.cancel()
        pendingHoverHideWorkItem = nil
    }
    
    /// Hides all sections
    private func hideAllSections() {
        print("[MenuBarManager] Hiding all sections")
        for section in sections {
            section.hide()
        }
    }

    /// Re-check auto-hide shortly while menus/interactions are still active.
    private func scheduleAutoHideRetry() {
        cancelAutoHide()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                let now = ProcessInfo.processInfo.systemUptime
                if strongSelf.shouldDeferAutoHide(now: now) {
                    strongSelf.scheduleAutoHideRetry()
                    return
                }
                strongSelf.hideAllSections()
            }
        }
    }

    /// Returns true when auto-hide should wait because user is still interacting with a menu.
    private func shouldDeferAutoHide(now: TimeInterval) -> Bool {
        if isLockedVisible {
            return true
        }
        if hasActiveMenuWindow(now: now) {
            return true
        }
        if hasAnyOnScreenPopupMenuWindow() {
            return true
        }
        return false
    }

    /// Detect popup-menu windows globally (not just this app), to avoid hiding while a status menu is open.
    private func hasAnyOnScreenPopupMenuWindow() -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let currentPID = getpid()

        let popUpLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        let mainMenuLayer = Int(CGWindowLevelForKey(.mainMenuWindow))
        let acceptedLayers = Set([popUpLayer - 1, popUpLayer, popUpLayer + 1, statusLayer, mainMenuLayer])
        let mouseAppKit = NSEvent.mouseLocation
        let mouseQuartzRect = MenuBarFloatingCoordinateConverter.appKitToQuartz(
            CGRect(x: mouseAppKit.x, y: mouseAppKit.y, width: 1, height: 1)
        )
        let mouseQuartzPoint = CGPoint(x: mouseQuartzRect.midX, y: mouseQuartzRect.midY)

        for window in windows {
            let ownerPID: pid_t
            if let pid = window[kCGWindowOwnerPID as String] as? Int32 {
                ownerPID = pid_t(pid)
            } else if let pid = window[kCGWindowOwnerPID as String] as? Int {
                ownerPID = pid_t(pid)
            } else {
                continue
            }
            // Ignore Droppy's own utility windows (floating panel/popovers).
            if ownerPID == currentPID {
                continue
            }

            let layer = window[kCGWindowLayer as String] as? Int ?? Int.min
            guard acceptedLayers.contains(layer) else { continue }

            if let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
               let bounds = CGRect(dictionaryRepresentation: boundsDict),
               !bounds.contains(mouseQuartzPoint) {
                continue
            }
            return true
        }

        return false
    }
    
    /// Initializes a new menu bar manager instance.
    init() {
        // Load saved settings - default to ENABLED for new users
        // Only disable if user has explicitly disabled the extension
        // Check if either removal key was ever explicitly set to true
        let extensionRemovedKey = "extension_removed_menuBarManager"
        let legacyRemovedKey = "MenuBarManager_Removed"
        
        // Default to enabled (true) unless explicitly disabled
        // This ensures new users see Menu Bar Manager as available
        let wasExplicitlyRemoved: Bool
        if UserDefaults.standard.object(forKey: extensionRemovedKey) != nil {
            wasExplicitlyRemoved = UserDefaults.standard.bool(forKey: extensionRemovedKey)
        } else if UserDefaults.standard.object(forKey: legacyRemovedKey) != nil {
            wasExplicitlyRemoved = UserDefaults.standard.bool(forKey: legacyRemovedKey)
        } else {
            // Neither key exists - this is a new user, default to ENABLED
            wasExplicitlyRemoved = false
        }
        
        self.isEnabled = !wasExplicitlyRemoved
        self.showOnHover = UserDefaults.standard.bool(forKey: "MenuBarManager_ShowOnHover")
        let hasStoredDelay = UserDefaults.standard.object(forKey: "MenuBarManager_ShowOnHoverDelay") != nil
        let storedDelay = UserDefaults.standard.double(forKey: "MenuBarManager_ShowOnHoverDelay")
        self.showOnHoverDelay = hasStoredDelay ? min(max(storedDelay, 0), 2) : 0.3
        self.iconSet = MBMIconSet(rawValue: UserDefaults.standard.string(forKey: "MenuBarManager_IconSet") ?? "") ?? .eye
        
        // Load additional settings
        self.useGradientIcon = UserDefaults.standard.bool(forKey: "MenuBarManager_UseGradientIcon")
        let storedAutoHide = UserDefaults.standard.double(forKey: "MenuBarManager_AutoHideDelay")
        self.autoHideDelay = storedAutoHide  // 0 means don't auto-hide
        self.rehideStrategy = RehideStrategy(rawValue: UserDefaults.standard.string(forKey: "MenuBarManager_RehideStrategy") ?? "") ?? .timed
        self.hoverModifierKey = HoverModifierKey(rawValue: UserDefaults.standard.string(forKey: "MenuBarManager_HoverModifierKey") ?? "") ?? .none
        // Default to true for separator display
        self.showChevronSeparator = true
        UserDefaults.standard.set(true, forKey: "MenuBarManager_ShowChevronSeparator")
        
        // Load item spacing offset (default is 0)
        self.itemSpacingOffset = UserDefaults.standard.integer(forKey: "MenuBarManager_ItemSpacingOffset")
        
        print("[MenuBarManager] INIT CALLED, isEnabled: \(self.isEnabled)")
        
        // Always perform setup to create sections
        performSetup()
        
        // If not enabled, remove from menu bar
        if !self.isEnabled {
            for section in sections {
                section.controlItem.removeFromMenuBar()
            }
        } else {
            setAlwaysHiddenSectionEnabled(false)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.isEnabled {
                MenuBarFloatingBarManager.shared.start()
            } else {
                MenuBarFloatingBarManager.shared.stop()
            }
        }

        isInitializing = false
        setupRehideObservers()
    }
    
    deinit {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        pendingHoverHideWorkItem?.cancel()
        pendingHoverHideWorkItem = nil
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        // Inline teardown — deinit is nonisolated so we can't call @MainActor methods
        if let smartRehideMouseDownMonitor {
            NSEvent.removeMonitor(smartRehideMouseDownMonitor)
        }
        if let focusLossObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(focusLossObserver)
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
            MenuBarSection(name: .alwaysHidden, manager: self),
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
                    guard let self else { return }
                    self.state = newState
                    guard !self.isInitializing else { return }
                    MenuBarFloatingBarManager.shared.setMenuBarHiddenSectionVisible(newState == .showItems)
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

        NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.activeMenuTrackingDepth += 1
                self.lastMenuTrackingEventTime = ProcessInfo.processInfo.systemUptime
                self.cachedHasActiveMenuWindow = true
                self.isHoverPausedForActiveMenu = true
                self.cancelAutoHide()
                self.cancelPendingHoverHide()
            }
            .store(in: &c)

        NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.activeMenuTrackingDepth = max(0, self.activeMenuTrackingDepth - 1)
                self.lastMenuTrackingEventTime = ProcessInfo.processInfo.systemUptime
                if self.activeMenuTrackingDepth == 0 {
                    self.cachedHasActiveMenuWindow = false
                    self.isHoverPausedForActiveMenu = false
                }
            }
            .store(in: &c)
        
        cancellables = c
    }
    
    /// Sets up mouse monitoring for show on hover.
    private func setupMouseMonitoring() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }

        guard showOnHover else {
            cancelAutoHide()
            cancelPendingHoverHide()
            resetMenuWindowDetectionState()
            return
        }

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
        }
    }
    
    /// Handles mouse movement for show on hover.
    private func handleMouseMoved() {
        guard showOnHover else { return }

        // High-frequency global mouse events can flood this path.
        // Cap processing to ~120 Hz to reduce CPU churn.
        let now = ProcessInfo.processInfo.systemUptime
        let minInterval: TimeInterval = 1.0 / 120.0
        guard now - lastMouseMoveProcessTime >= minInterval else { return }
        lastMouseMoveProcessTime = now

        // Keep menu interactions smooth by pausing hover logic while any menu is open.
        if hasActiveMenuWindow(now: now) {
            if !isHoverPausedForActiveMenu {
                cancelAutoHide()
                cancelPendingHoverHide()
                isHoverPausedForActiveMenu = true
            }
            return
        }
        isHoverPausedForActiveMenu = false
        
        // When icons are locked visible via eye click, skip hover behavior
        guard !isLockedVisible else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = interactionScreen(for: mouseLocation) else { return }
        let menuBarHeight = effectiveMenuBarHeight(for: screen)
        
        // Check if mouse is in the menu bar area
        let isAtTop = mouseLocation.y >= screen.frame.maxY - menuBarHeight
        
        // CRITICAL: Only reveal on the RIGHT side of the notch
        // Left side contains Apple menu bar items, right side contains app/third-party items
        // The notch/Dynamic Island belongs to Droppy's shelf, not the menu bar
        let isOnRightSideOfNotch = isOnRightSideMenuBarArea(mouseLocation: mouseLocation, screen: screen)
        
        let isInMenuBar = isAtTop && isOnRightSideOfNotch

        
        if let hiddenSection = section(withName: .hidden) {
            if isInMenuBar && hiddenSection.isHidden {
                // Check if a modifier key is required and if it's held
                if let requiredFlags = hoverModifierKey.eventFlags {
                    guard NSEvent.modifierFlags.contains(requiredFlags) else { return }
                }
                // Cursor entered menu bar - cancel any auto-hide timer and show
                cancelAutoHide()
                cancelPendingHoverHide()
                hiddenSection.show()
            } else if isInMenuBar && !hiddenSection.isHidden {
                // Cursor still in menu bar while items are shown - cancel any pending hide
                cancelAutoHide()
                cancelPendingHoverHide()
            } else if !isInMenuBar && !hiddenSection.isHidden {
                // Cursor left menu bar — apply rehide strategy
                switch rehideStrategy {
                case .timed:
                    if autoHideDelay > 0 {
                        cancelPendingHoverHide()
                        if autoHideTimer == nil {
                            scheduleAutoHide()
                        }
                    } else {
                        scheduleHoverDelayedHide(screen: screen, menuBarHeight: menuBarHeight, hiddenSection: hiddenSection)
                    }
                case .smart:
                    // Smart strategy hides on mouse-down outside menu bar (handled by monitor).
                    // Still schedule a hover-delayed hide as a fallback when cursor leaves.
                    scheduleHoverDelayedHide(screen: screen, menuBarHeight: menuBarHeight, hiddenSection: hiddenSection)
                case .focusLoss:
                    // FocusLoss strategy hides on app switch (handled by observer).
                    // No timer-based hide needed.
                    break
                case .manual:
                    // Manual strategy — never auto-hide.
                    break
                }
            }
        }
    }
    
    /// Schedules a hover-delayed hide task for when the cursor leaves the menu bar.
    private func scheduleHoverDelayedHide(
        screen: NSScreen,
        menuBarHeight: CGFloat,
        hiddenSection: MenuBarSection
    ) {
        guard pendingHoverHideWorkItem == nil else { return }

        let screenFrame = screen.frame
        let delay = showOnHoverDelay
        let workItem = DispatchWorkItem { [weak self, weak hiddenSection] in
            guard let self else { return }
            self.pendingHoverHideWorkItem = nil
            guard let hiddenSection else { return }
            guard !self.isLockedVisible else { return }

            let currentLocation = NSEvent.mouseLocation
            let stillAtTop = currentLocation.y >= screenFrame.maxY - menuBarHeight
            let stillOnRightSideOfNotch = self.isOnRightSideMenuBarArea(
                mouseLocation: currentLocation,
                screen: screen
            )
            let stillInMenuBar = stillAtTop && stillOnRightSideOfNotch

            if !stillInMenuBar {
                hiddenSection.hide()
            }
        }

        pendingHoverHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func interactionScreen(for mouseLocation: CGPoint) -> NSScreen? {
        if let hiddenFrame = controlItemFrame(for: .hidden),
           let hiddenScreen = NSScreen.screens.first(where: { $0.frame.intersects(hiddenFrame) }) {
            return hiddenScreen
        }
        if let alwaysHiddenFrame = controlItemFrame(for: .alwaysHidden),
           let alwaysHiddenScreen = NSScreen.screens.first(where: { $0.frame.intersects(alwaysHiddenFrame) }) {
            return alwaysHiddenScreen
        }
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
    }

    private func effectiveMenuBarHeight(for screen: NSScreen) -> CGFloat {
        let inferredHeight = screen.frame.maxY - screen.visibleFrame.maxY
        if inferredHeight > 0 {
            return inferredHeight
        }
        return max(24, NSStatusBar.system.thickness)
    }

    private func isOnRightSideMenuBarArea(mouseLocation: CGPoint, screen: NSScreen) -> Bool {
        let hasNotch = screen.safeAreaInsets.top > 0
        if !hasNotch {
            return mouseLocation.x > screen.frame.midX
        }
        let notchExclusionWidth: CGFloat = 200
        return mouseLocation.x > screen.frame.midX + (notchExclusionWidth / 2)
    }

    private func hasActiveMenuWindow(now: TimeInterval) -> Bool {
        if RunLoop.current.currentMode == .eventTracking || RunLoop.main.currentMode == .eventTracking {
            cachedHasActiveMenuWindow = true
            return true
        }

        if activeMenuTrackingDepth > 0 {
            // NSMenu didBegin/didEnd can occasionally become unbalanced.
            // Treat depth as authoritative only for a short grace period,
            // then require corroborating menu-window evidence.
            let trackingGrace: TimeInterval = 0.9
            if now - lastMenuTrackingEventTime <= trackingGrace {
                cachedHasActiveMenuWindow = true
                return true
            }
        }

        // Re-check at most ~30 Hz; active menu windows don't need per-event detection fidelity.
        let checkInterval: TimeInterval = 1.0 / 30.0
        if now - lastActiveMenuWindowCheckTime < checkInterval {
            return cachedHasActiveMenuWindow
        }
        lastActiveMenuWindowCheckTime = now

        let hasActiveMenu = NSApp.windows.contains { window in
            guard window.isVisible else { return false }
            guard window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue else { return false }
            let className = NSStringFromClass(type(of: window)).lowercased()
            return className.contains("menu")
        }

        if !hasActiveMenu, activeMenuTrackingDepth > 0 {
            activeMenuTrackingDepth = 0
        }
        cachedHasActiveMenuWindow = hasActiveMenu
        return hasActiveMenu
    }

    private func resetMenuWindowDetectionState() {
        cachedHasActiveMenuWindow = false
        lastActiveMenuWindowCheckTime = 0
        isHoverPausedForActiveMenu = false
        activeMenuTrackingDepth = 0
        lastMenuTrackingEventTime = 0
    }
    
    // MARK: - Rehide Strategy Observers
    
    /// Installs or tears down observers for the current rehide strategy.
    private func setupRehideObservers() {
        tearDownRehideObservers()
        
        switch rehideStrategy {
        case .smart:
            smartRehideMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.handleSmartRehideMouseDown(event)
            }
        case .focusLoss:
            focusLossObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleFocusLossAppSwitch()
                }
            }
        case .timed, .manual:
            break
        }
    }
    
    /// Removes all rehide strategy observers.
    private func tearDownRehideObservers() {
        if let smartRehideMouseDownMonitor {
            NSEvent.removeMonitor(smartRehideMouseDownMonitor)
            self.smartRehideMouseDownMonitor = nil
        }
        if let focusLossObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(focusLossObserver)
            self.focusLossObserver = nil
        }
    }
    
    /// Smart strategy: hide when clicking outside the menu bar area.
    private func handleSmartRehideMouseDown(_ event: NSEvent) {
        guard !isLockedVisible else { return }
        guard let hiddenSection = section(withName: .hidden), !hiddenSection.isHidden else { return }
        
        // Don't rehide if clicking inside a menu that's already open
        let now = ProcessInfo.processInfo.systemUptime
        if hasActiveMenuWindow(now: now) || hasAnyOnScreenPopupMenuWindow() { return }
        
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = interactionScreen(for: mouseLocation) else { return }
        let menuBarHeight = effectiveMenuBarHeight(for: screen)
        let isAtTop = mouseLocation.y >= screen.frame.maxY - menuBarHeight
        let isOnRightSide = isOnRightSideMenuBarArea(mouseLocation: mouseLocation, screen: screen)
        
        if !(isAtTop && isOnRightSide) {
            hiddenSection.hide()
        }
    }
    
    /// Focus loss strategy: hide when the frontmost application changes.
    private func handleFocusLossAppSwitch() {
        guard !isLockedVisible else { return }
        guard let hiddenSection = section(withName: .hidden), !hiddenSection.isHidden else { return }
        
        // Small delay to avoid racing with menu bar item click → app activation sequences
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            guard !self.isLockedVisible else { return }
            guard let section = self.section(withName: .hidden), !section.isHidden else { return }
            section.hide()
        }
    }
    
    /// Returns the menu bar section with the given name.
    func section(withName name: MenuBarSection.Name) -> MenuBarSection? {
        sections.first { $0.name == name }
    }

    /// Returns whether a section's control item is currently present in the menu bar.
    func isSectionEnabled(_ sectionName: MenuBarSection.Name) -> Bool {
        section(withName: sectionName)?.controlItem.isAddedToMenuBar == true
    }

    /// Returns the window frame for a section control item.
    func controlItemFrame(for sectionName: MenuBarSection.Name) -> CGRect? {
        section(withName: sectionName)?.controlItem.windowFrame
    }

    /// Enables or disables the always-hidden section divider item.
    func setAlwaysHiddenSectionEnabled(_ enabled: Bool) {
        guard let alwaysHiddenSection = section(withName: .alwaysHidden) else { return }
        if enabled {
            // Keep AH divider left of the hidden divider in preferred-position defaults.
            let hiddenAutosave = ControlItem.Identifier.hidden.rawValue
            let alwaysAutosave = ControlItem.Identifier.alwaysHidden.rawValue
            let hiddenPosition = StatusItemDefaults[.preferredPosition, hiddenAutosave] ?? 1
            let alwaysPosition = StatusItemDefaults[.preferredPosition, alwaysAutosave] ?? (hiddenPosition + 1)
            if alwaysPosition <= hiddenPosition {
                StatusItemDefaults[.preferredPosition, alwaysAutosave] = hiddenPosition + 1
            }
            alwaysHiddenSection.controlItem.addToMenuBar()
        } else {
            alwaysHiddenSection.controlItem.state = .hideItems
            alwaysHiddenSection.controlItem.removeFromMenuBar()
        }
    }

    /// Temporarily reveal all sections while the settings pane is open so
    /// users can scan and assign icons reliably.
    func showAllSectionsForSettingsInspection() {
        guard let visibleSection = section(withName: .visible),
              let hiddenSection = section(withName: .hidden),
              let alwaysHiddenSection = section(withName: .alwaysHidden) else {
            return
        }
        cancelAutoHide()
        cancelPendingHoverHide()
        setAlwaysHiddenSectionEnabled(true)

        // Shield transition (legacy pattern):
        // 1) main hidden separator expands (shield),
        // 2) always-hidden separator contracts to visual,
        // 3) main separator contracts to reveal everything.
        hiddenSection.controlItem.state = .hideItems
        alwaysHiddenSection.controlItem.state = .showItems
        visibleSection.controlItem.state = .showItems
        hiddenSection.controlItem.state = .showItems
    }

    /// Restore section visibility after settings closes.
    func restoreSectionVisibilityAfterSettings(
        hiddenWasVisible: Bool,
        alwaysHiddenWasVisible: Bool,
        alwaysHiddenWasEnabled: Bool
    ) {
        guard let visibleSection = section(withName: .visible),
              let hiddenSection = section(withName: .hidden),
              let alwaysHiddenSection = section(withName: .alwaysHidden) else {
            return
        }

        // Restore through a shield step to avoid separator race artifacts.
        hiddenSection.controlItem.state = .hideItems
        alwaysHiddenSection.controlItem.state = .hideItems

        if hiddenWasVisible {
            visibleSection.controlItem.state = .showItems
            hiddenSection.controlItem.state = .showItems
            alwaysHiddenSection.controlItem.state = alwaysHiddenWasVisible ? .showItems : .hideItems
        } else {
            visibleSection.controlItem.state = .hideItems
            hiddenSection.controlItem.state = .hideItems
            alwaysHiddenSection.controlItem.state = .hideItems
        }

        let floatingNeedsAlwaysHiddenSection =
            MenuBarFloatingBarManager.shared.isFeatureEnabled
            && !MenuBarFloatingBarManager.shared.alwaysHiddenItemIDs.isEmpty
        setAlwaysHiddenSectionEnabled(alwaysHiddenWasEnabled || floatingNeedsAlwaysHiddenSection)
    }
    
    /// Toggles the hidden section.
    func toggle() {
        guard let hiddenSection = section(withName: .hidden) else { return }
        hiddenSection.toggle()
        print("[MenuBarManager] Toggled to: \(hiddenSection.controlItem.state)")
    }
    
    /// Enables the menu bar manager.
    func enable() {
        // Support direct callers that don't flip the published toggle first.
        if !isEnabled {
            isEnabled = true
            return
        }

        // Clear both legacy and unified removed flags
        UserDefaults.standard.set(false, forKey: "MenuBarManager_Removed")
        ExtensionType.menuBarManager.setRemoved(false)
        
        if sections.isEmpty {
            performSetup()
        }
        
        section(withName: .visible)?.controlItem.addToMenuBar()
        section(withName: .hidden)?.controlItem.addToMenuBar()
        setAlwaysHiddenSectionEnabled(false)

        setupMouseMonitoring()
        MenuBarFloatingBarManager.shared.start()
        
        print("[MenuBarManager] Enabled")
    }
    
    /// Disables the menu bar manager.
    func disable() {
        // Support direct callers that don't flip the published toggle first.
        if isEnabled {
            isEnabled = false
            return
        }

        cancelAutoHide()
        cancelPendingHoverHide()
        resetMenuWindowDetectionState()
        tearDownRehideObservers()
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }

        for section in sections {
            section.controlItem.removeFromMenuBar()
        }
        MenuBarFloatingBarManager.shared.stop()
        
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
        MenuBarFloatingBarManager.shared.stop()
        cancelAutoHide()
        cancelPendingHoverHide()
        resetMenuWindowDetectionState()
        tearDownRehideObservers()
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
        sections.removeAll()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let menuBarManagerItemClicked = Notification.Name("menuBarManagerItemClicked")
    static let menuBarManagerOpenSettings = Notification.Name("menuBarManagerOpenSettings")
    static let menuBarManagerDisable = Notification.Name("menuBarManagerDisable")
}
