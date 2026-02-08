//
//  FloatingBasketWindowController.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Accent colors for distinguishing multiple baskets
/// Colors are subtle and designed to work well on dark backgrounds
enum BasketAccentColor: Int, CaseIterable {
    case teal = 0
    case coral = 1
    case indigo = 2
    case amber = 3
    case rose = 4
    case mint = 5
    
    /// The SwiftUI color for this accent
    var color: Color {
        switch self {
        case .teal:   return Color(hue: 0.50, saturation: 0.55, brightness: 0.75) // Teal
        case .coral:  return Color(hue: 0.03, saturation: 0.55, brightness: 0.90) // Coral/Orange
        case .indigo: return Color(hue: 0.72, saturation: 0.50, brightness: 0.80) // Indigo/Purple
        case .amber:  return Color(hue: 0.12, saturation: 0.60, brightness: 0.95) // Amber/Yellow
        case .rose:   return Color(hue: 0.92, saturation: 0.45, brightness: 0.85) // Rose/Pink
        case .mint:   return Color(hue: 0.42, saturation: 0.45, brightness: 0.80) // Mint/Green
        }
    }
    
    /// Get the next available color based on current basket count
    static func nextColor(for existingCount: Int) -> BasketAccentColor {
        let index = existingCount % allCases.count
        return allCases[index]
    }
}

/// Manages the floating basket window that appears during file drags
final class FloatingBasketWindowController: NSObject {
    /// The floating basket window
    var basketWindow: NSPanel?
    
    /// Primary shared instance (for backwards compatibility)
    static let shared = FloatingBasketWindowController(accentColor: .teal)
    
    /// All active basket instances (multi-basket support)
    private static var activeBaskets: [FloatingBasketWindowController] = []

    /// Single source for multi-basket preference reads with default fallback.
    private static var isMultiBasketEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.enableMultiBasket,
            default: PreferenceDefault.enableMultiBasket
        )
    }
    
    /// This basket's accent color for visual distinction
    let accentColor: BasketAccentColor

    /// Whether this basket should currently render accent coloring.
    var shouldShowAccentColor: Bool {
        Self.shouldShowAccentColors
    }
    
    /// Per-basket state (items, selection, targeting) - each basket is fully independent
    let basketState = BasketState()
    
    /// Check if any basket is currently visible (includes shared + active baskets)
    static var isAnyBasketVisible: Bool {
        // Check shared instance first
        if shared.basketWindow?.isVisible == true { return true }
        // Then check any spawned baskets
        return activeBaskets.contains { $0.basketWindow?.isVisible == true }
    }
    
    /// Get all visible baskets (includes shared if visible)
    /// NOTE: Only returns baskets with actually visible windows
    static var visibleBaskets: [FloatingBasketWindowController] {
        var result = activeBaskets.filter { $0.basketWindow?.isVisible == true }
        if shared.basketWindow?.isVisible == true && !result.contains(where: { $0 === shared }) {
            result.insert(shared, at: 0)
        }
        return result
    }

    /// Accent colors are only shown when 2+ baskets are visible.
    static var shouldShowAccentColors: Bool {
        visibleBaskets.count >= 2
    }
    
    /// Get all baskets that have items (for hide timer logic, may be hidden)
    static var basketsWithItems: [FloatingBasketWindowController] {
        var result = activeBaskets.filter { !$0.basketState.items.isEmpty }
        if !shared.basketState.items.isEmpty && !result.contains(where: { $0 === shared }) {
            result.insert(shared, at: 0)
        }
        return result
    }

    /// Returns true when there are baskets with items that are currently hidden.
    static var hasHiddenBasketsWithItems: Bool {
        basketsWithItems.contains { $0.basketWindow?.isVisible != true || $0.isInPeekMode }
    }

    /// Get all basket controllers (shared + spawned), regardless of item count or visibility.
    static var allBaskets: [FloatingBasketWindowController] {
        var result = activeBaskets
        if !result.contains(where: { $0 === shared }) {
            result.insert(shared, at: 0)
        }
        return result
    }

    /// Adds inbound files to the best available basket and reveals it.
    /// Used by non-drag entry points (URL scheme, services, clipboard, tracked folders, etc.).
    @discardableResult
    static func addItemsFromExternalSource(_ urls: [URL], showAtLastPosition: Bool = false) -> FloatingBasketWindowController {
        guard !urls.isEmpty else { return shared }
        let target = targetBasketForInboundAdd()
        target.basketState.addItems(from: urls)
        if showAtLastPosition {
            target.showBasket(atLastPosition: true)
        } else {
            target.showBasket()
        }
        return target
    }

    /// Adds a pre-built dropped item (preserves metadata like `isTemporary`) and reveals the target basket.
    @discardableResult
    static func addDroppedItemFromExternalSource(_ item: DroppedItem, showAtLastPosition: Bool = false) -> FloatingBasketWindowController {
        let target = targetBasketForInboundAdd()
        target.basketState.addItem(item)
        if showAtLastPosition {
            target.showBasket(atLastPosition: true)
        } else {
            target.showBasket()
        }
        return target
    }

    /// Closes all visible baskets (shared and spawned).
    static func closeAllBaskets() {
        DragMonitor.shared.stopIdleJiggleMonitoring()
        BasketSwitcherWindowController.shared.hide()
        
        let spawnedBaskets = activeBaskets
        shared.hideBasket(force: true)
        for basket in spawnedBaskets {
            basket.hideBasket(force: true)
        }
    }
    
    /// Merges any spawned baskets back into the shared basket and closes spawned windows.
    /// Used when switching from multi-basket mode to single-basket mode.
    static func enforceSingleBasketMode() {
        BasketSwitcherWindowController.shared.hide()
        guard !activeBaskets.isEmpty else { return }
        
        let spawnedBaskets = activeBaskets
        let hadVisibleBaskets = isAnyBasketVisible
        
        for basket in spawnedBaskets {
            mergeBasketItems(from: basket.basketState, into: shared.basketState)
        }
        
        for basket in spawnedBaskets {
            if let panel = basket.basketWindow {
                panel.orderOut(nil)
                basket.basketWindow = nil
            }
            basket.stopKeyboardMonitor()
            basket.stopMouseTrackingMonitor()
            basket.cancelHideTimer()
            basket.isInPeekMode = false
            basket.isPeekAnimating = false
            basket.isShowingOrHiding = false
        }
        activeBaskets.removeAll()
        
        if hadVisibleBaskets && !shared.basketState.items.isEmpty {
            shared.showBasket(atLastPosition: true)
        }
        
        DragMonitor.shared.stopIdleJiggleMonitoring()
        
        DroppyState.shared.isBasketVisible = shared.basketWindow?.isVisible == true
        DroppyState.shared.isBasketTargeted = false
    }
    
    private static func mergeBasketItems(from source: BasketState, into destination: BasketState) {
        var existingURLs = Set(destination.items.map(\.url))
        
        func promotePinIfNeeded(for url: URL, sourcePinned: Bool) {
            guard sourcePinned else { return }
            if let index = destination.powerFolders.firstIndex(where: { $0.url == url }) {
                destination.powerFolders[index].isPinned = true
                return
            }
            if let index = destination.itemsList.firstIndex(where: { $0.url == url }) {
                destination.itemsList[index].isPinned = true
            }
        }
        
        for folder in source.powerFolders where !existingURLs.contains(folder.url) {
            destination.powerFolders.append(folder)
            existingURLs.insert(folder.url)
        }
        for folder in source.powerFolders where existingURLs.contains(folder.url) {
            promotePinIfNeeded(for: folder.url, sourcePinned: folder.isPinned)
        }
        
        for item in source.itemsList where !existingURLs.contains(item.url) {
            destination.itemsList.append(item)
            existingURLs.insert(item.url)
        }
        for item in source.itemsList where existingURLs.contains(item.url) {
            promotePinIfNeeded(for: item.url, sourcePinned: item.isPinned)
        }
    }
    
    private static func frontmostVisibleBasket() -> FloatingBasketWindowController? {
        let visible = visibleBaskets
        guard !visible.isEmpty else { return nil }
        
        for window in NSApp.orderedWindows {
            if let basket = visible.first(where: { $0.basketWindow === window }) {
                return basket
            }
        }
        
        if let keyBasket = visible.first(where: { $0.basketWindow?.isKeyWindow == true }) {
            return keyBasket
        }
        
        return visible.first
    }

    /// Chooses which basket should receive inbound items from non-drag flows.
    private static func targetBasketForInboundAdd() -> FloatingBasketWindowController {
        if !isMultiBasketEnabled, !activeBaskets.isEmpty {
            enforceSingleBasketMode()
        }
        
        if let visible = frontmostVisibleBasket() {
            return visible
        }

        if isMultiBasketEnabled {
            if let hiddenSpawnedWithItems = activeBaskets.first(where: { !$0.basketState.items.isEmpty && $0.basketWindow?.isVisible != true }) {
                return hiddenSpawnedWithItems
            }
            if !shared.basketState.items.isEmpty {
                return shared
            }
        }

        return shared
    }
    
    /// (Removed beta setting property)
    
    /// Prevent re-entrance
    private var isShowingOrHiding = false
    
    /// Initial basket position on screen (for determining expand direction)
    private var initialBasketOrigin: CGPoint = .zero
    
    /// Track if basket should expand upward (true) or downward (false)
    /// Set once when basket appears to avoid layout recalculations
    private(set) var shouldExpandUpward: Bool = true
    
    /// Keyboard monitor for spacebar Quick Look
    private var keyboardMonitor: Any?
    
    // MARK: - Auto-Hide Peek Mode (v5.3)
    
    /// Whether basket is currently in peek mode (collapsed at edge)
    private(set) var isInPeekMode: Bool = false
    
    /// Whether peek animation is currently running (prevents cursor interruption)
    private var isPeekAnimating: Bool = false
    
    /// Absolute deadline for auto-hide after cursor leaves basket bounds.
    private var hideDeadline: Date?
    
    /// Poller that enforces deterministic auto-hide timing, even if hover exit events are missed.
    private var autoHidePollTimer: Timer?
    
    /// Mouse tracking monitor for hover detection (global monitor)
    private var mouseTrackingMonitor: Any?
    
    /// Local mouse tracking monitor for when basket window is focused
    private var localMouseTrackingMonitor: Any?
    
    /// Stored full-size basket position for restoration
    private var fullSizeFrame: NSRect = .zero
    
    /// Display currently owning basket positioning/peek behavior.
    private var activeBasketDisplayID: CGDirectDisplayID?
    
    /// Last used basket position (for tracked folders to reopen at same spot)
    private var lastBasketFrame: NSRect = .zero
    
    /// Peek sliver size in pixels - how much of the window stays on screen
    /// With 3D tilt + 0.85 scale, we need less visible area
    private let peekSize: CGFloat = 200

    /// True while user is drag-selecting items inside the basket.
    /// Prevents accidental auto-hide when the drag temporarily leaves the basket bounds.
    private var isBasketSelectionDragActive: Bool = false
    
    /// Creates a new basket controller with the specified accent color
    init(accentColor: BasketAccentColor) {
        self.accentColor = accentColor
        super.init()
        basketState.ownerController = self
    }
    
    /// Called by DragMonitor when jiggle is detected during an active drag
    /// - If dragging + 1 basket visible: spawn new basket (if multi-basket enabled)
    /// - If dragging + 2+ baskets visible: show basket switcher
    /// - If no basket visible: show primary basket
    func onJiggleDetected() {
        guard !isShowingOrHiding else { return }
        guard DragMonitor.shared.isDragging else { return }
        
        let multiBasketEnabled = Self.isMultiBasketEnabled
        if !multiBasketEnabled && !Self.activeBaskets.isEmpty {
            Self.enforceSingleBasketMode()
        }
        let hiddenWithItems = Self.basketsWithItems.filter { $0.basketWindow?.isVisible != true }
        
        if Self.isAnyBasketVisible {
            // Basket(s) already visible
            if multiBasketEnabled {
                // DRAGGING a file with basket visible
                if !hiddenWithItems.isEmpty {
                    // STEP 1: Show hidden baskets first
                    Self.showAllHiddenBaskets()
                    // After showing hidden, check if switcher needed (delayed to let windows appear)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let allVisible = Self.visibleBaskets
                        if allVisible.count >= 2 {
                            BasketSwitcherWindowController.shared.show(baskets: allVisible) { selected, _ in
                                selected.basketWindow?.orderFrontRegardless()
                            }
                        }
                    }
                } else {
                    // No hidden baskets - check visible count
                    let allVisible = Self.visibleBaskets
                    if allVisible.count >= 2 {
                        // STEP 2: 2+ baskets visible → show switcher
                        BasketSwitcherWindowController.shared.show(baskets: allVisible) { selected, _ in
                            selected.basketWindow?.orderFrontRegardless()
                        }
                    } else {
                        // STEP 3: Only 1 basket → spawn new
                        Self.spawnNewBasket()
                    }
                }
            }
            // Already visible and single-basket mode: keep current basket.
        } else {
            // No basket visible - show hidden baskets or primary basket
            if !hiddenWithItems.isEmpty {
                Self.showAllHiddenBaskets()
            } else {
                showBasket()
            }
        }
    }
    
    /// Shows all previously auto-hidden baskets that still have items
    /// Positions them side-by-side horizontally so they don't overlap
    static func showAllHiddenBaskets() {
        // Ensure legacy idle-jiggle monitor stays off.
        DragMonitor.shared.stopIdleJiggleMonitoring()
        
        // Single-basket mode should reveal only one basket.
        if !isMultiBasketEnabled {
            if !activeBaskets.isEmpty {
                enforceSingleBasketMode()
            }
            
            if !shared.basketState.items.isEmpty {
                shared.showBasket(atLastPosition: true)
            } else {
                shared.showBasket()
            }
            return
        }
        
        // Collect all baskets that need to be shown (have items but window is not visible)
        var basketsToShow: [FloatingBasketWindowController] = []
        
        // Check shared basket - show if has items and window is not visible
        if !shared.basketState.items.isEmpty && shared.basketWindow?.isVisible != true {
            basketsToShow.append(shared)
        }
        // Check active baskets
        for basket in activeBaskets {
            if !basket.basketState.items.isEmpty && basket.basketWindow?.isVisible != true {
                basketsToShow.append(basket)
            }
        }
        
        guard !basketsToShow.isEmpty else { return }
        
        // Calculate staggered positions centered around mouse
        let mouseLocation = NSEvent.mouseLocation
        let basketWidth: CGFloat = 220  // Collapsed basket width
        let spacing: CGFloat = 20       // Space between baskets
        let totalWidth = CGFloat(basketsToShow.count) * basketWidth + CGFloat(basketsToShow.count - 1) * spacing
        let startX = mouseLocation.x - totalWidth / 2
        
        for (index, basket) in basketsToShow.enumerated() {
            let xOffset = startX + CGFloat(index) * (basketWidth + spacing) + basketWidth / 2
            let position = NSPoint(x: xOffset, y: mouseLocation.y)
            basket.showBasket(at: position)
        }
    }
    
    /// Spawns a new basket with the next accent color
    /// - Returns: The newly created basket controller (or shared if single-basket mode)
    @discardableResult
    static func spawnNewBasket() -> FloatingBasketWindowController {
        // Respect single-basket mode - return existing basket instead of spawning
        let multiBasketEnabled = Self.isMultiBasketEnabled
        guard multiBasketEnabled else {
            if !activeBaskets.isEmpty {
                enforceSingleBasketMode()
            }
            shared.showBasket()
            return shared
        }
        
        // Cancel all hide timers on existing baskets to prevent inadvertent hiding
        // Include shared basket explicitly since it might not be in visibleBaskets
        shared.cancelHideTimer()
        for basket in activeBaskets {
            basket.cancelHideTimer()
        }
        
        // Color based on ALL baskets (including hidden) to avoid duplicates
        // shared counts as 1, plus all spawned baskets
        let allBasketsCount = 1 + activeBaskets.count
        let nextColor = BasketAccentColor.nextColor(for: allBasketsCount)
        let newBasket = FloatingBasketWindowController(accentColor: nextColor)
        activeBaskets.append(newBasket)
        newBasket.showBasket()
        return newBasket
    }
    
    /// Removes a basket from the active collection (called when closed)
    static func removeBasket(_ basket: FloatingBasketWindowController) {
        activeBaskets.removeAll { $0 === basket }
    }
    
    /// Called by DragMonitor when drag ends
    func onDragEnded() {
        guard basketWindow != nil, !isShowingOrHiding else { return }
        
        // Auto-hide disabled = NO baskets ever auto-hide
        guard isAutoHideEnabled else { return }
        
        // Don't hide during file operations or sharing
        guard !DroppyState.shared.isFileOperationInProgress, !DroppyState.shared.isSharingInProgress else { return }
        
        // Don't hide if the basket switcher is visible
        guard !BasketSwitcherWindowController.shared.isVisible else { return }
        
        // Delay to allow drop operation to complete before checking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.basketWindow != nil else { return }
            
            // Re-check guards after delay
            guard !DroppyState.shared.isFileOperationInProgress, !DroppyState.shared.isSharingInProgress else { return }
            guard !BasketSwitcherWindowController.shared.isVisible else { return }
            
            // Auto-hide enabled = ALL empty baskets hide (consistent behavior)
            if self.basketState.items.isEmpty {
                self.hideBasket()
            }
        }
    }
    
    // MARK: - Position Calculation
    
    /// Calculates the basket position centered on mouse
    private func calculateBasketPosition() -> NSRect {
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 600
        let mouseLocation = NSEvent.mouseLocation
        
        return NSRect(
            x: mouseLocation.x - windowWidth/2,
            y: mouseLocation.y - windowHeight/2,
            width: windowWidth,
            height: windowHeight
        )
    }
    
    /// Resolve the display that should control basket positioning.
    /// Preference: panel overlap -> panel center -> panel screen -> tracked display ID -> mouse screen -> fallback.
    private func resolveBasketScreen(for panel: NSPanel? = nil) -> NSScreen? {
        if let panel {
            // 1) Pick the display with maximum overlap with the basket window frame.
            // This keeps hide/peek pinned to the display where the basket actually is.
            let panelFrame = panel.frame
            var bestScreen: NSScreen?
            var bestArea: CGFloat = 0
            for screen in NSScreen.screens {
                let intersection = panelFrame.intersection(screen.frame)
                if !intersection.isNull && !intersection.isEmpty {
                    let area = intersection.width * intersection.height
                    if area > bestArea {
                        bestArea = area
                        bestScreen = screen
                    }
                }
            }
            if let bestScreen {
                activeBasketDisplayID = bestScreen.displayID
                return bestScreen
            }
            
            // 2) Fallback to center-point containment.
            let panelCenter = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
            if let centerScreen = NSScreen.screens.first(where: { $0.frame.contains(panelCenter) }) {
                activeBasketDisplayID = centerScreen.displayID
                return centerScreen
            }
            
            // 3) Fallback to AppKit panel screen.
            if let panelScreen = panel.screen {
                activeBasketDisplayID = panelScreen.displayID
                return panelScreen
            }
        }
        
        // 4) Fallback to the last known tracked display.
        if let activeBasketDisplayID,
           let trackedScreen = NSScreen.screens.first(where: { $0.displayID == activeBasketDisplayID }) {
            return trackedScreen
        }
        
        // 5) Fallback to mouse location.
        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            activeBasketDisplayID = mouseScreen.displayID
            return mouseScreen
        }
        
        // 6) Final fallback.
        let fallbackScreen = NSScreen.main ?? NSScreen.screens.first
        if let fallbackScreen {
            activeBasketDisplayID = fallbackScreen.displayID
        }
        return fallbackScreen
    }
    
    // MARK: - moveBasketToMouse() REMOVED
    // Jiggle-to-move behavior replaced with spawn-new-basket in Issue #160

    
    /// Shows the basket at a specific position (used for staggered multi-basket reveal)
    /// - Parameter position: The center point where the basket should appear
    func showBasket(at position: NSPoint) {
        guard !isShowingOrHiding else { return }
        DragMonitor.shared.stopIdleJiggleMonitoring()
        
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 600
        let xPosition = position.x - windowWidth / 2
        let yPosition = position.y - windowHeight / 2
        let targetFrame = NSRect(x: xPosition, y: yPosition, width: windowWidth, height: windowHeight)
        
        if let panel = basketWindow {
            panel.alphaValue = 1.0
            panel.setFrame(targetFrame, display: true)
            panel.orderFrontRegardless()
            DroppyState.shared.isBasketVisible = true
            isInPeekMode = false
            isPeekAnimating = false
            cancelHideTimer()
            startKeyboardMonitor()
            startMouseTrackingMonitor()
        } else {
            // Create new window at target position (delegate to showBasket which handles creation)
            // Set the target frame temporarily and call regular showBasket
            lastBasketFrame = targetFrame
            showBasket(atLastPosition: true)
        }
    }
    
    /// Shows the basket near the current mouse location (or last position if specified)
    /// - Parameter atLastPosition: If true, opens at last used position instead of mouse location
    func showBasket(atLastPosition: Bool = false) {
        guard !isShowingOrHiding else { return }
        DragMonitor.shared.stopIdleJiggleMonitoring()
        
        // Defensive check: reuse existing hidden window IF it belongs to this controller
        // (Do NOT steal windows from other basket instances - multi-basket support)
        if let panel = basketWindow {
            panel.alphaValue = 1.0 // Ensure visible
            if atLastPosition && lastBasketFrame.width > 0 {
                panel.setFrame(lastBasketFrame, display: true)
            } else {
                // Position at mouse (inline - moveBasketToMouse removed in #160)
                let mouseLocation = NSEvent.mouseLocation
                let windowWidth: CGFloat = 500
                let windowHeight: CGFloat = 600
                let xPosition = mouseLocation.x - windowWidth / 2
                let yPosition = mouseLocation.y - windowHeight / 2
                let newFrame = NSRect(x: xPosition, y: yPosition, width: windowWidth, height: windowHeight)
                panel.setFrame(newFrame, display: true)
            }
            panel.orderFrontRegardless()
            DroppyState.shared.isBasketVisible = true
            isInPeekMode = false
            isPeekAnimating = false
            cancelHideTimer()
            startKeyboardMonitor()
            startMouseTrackingMonitor()
            return
        }

        isShowingOrHiding = true
        
        // Calculate window position - use last position if requested and available
        let windowFrame: NSRect
        if atLastPosition && lastBasketFrame.width > 0 {
            windowFrame = lastBasketFrame
        } else {
            windowFrame = calculateBasketPosition()
        }
        
        // Store initial position for expand direction logic
        let mouseLocation = atLastPosition && lastBasketFrame.width > 0 
            ? CGPoint(x: lastBasketFrame.midX, y: lastBasketFrame.midY)
            : NSEvent.mouseLocation
        initialBasketOrigin = CGPoint(x: mouseLocation.x, y: mouseLocation.y)
        
        // Calculate expand direction once (basket expands upward if low on screen, downward if high)
        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.screens.first(where: { $0.frame.contains(windowCenter) }) {
            let screenMidY = screen.frame.height / 2
            // Use actual window position for expand direction
            shouldExpandUpward = windowFrame.midY < screenMidY
            activeBasketDisplayID = screen.displayID
        } else {
            shouldExpandUpward = true
        }

        
        // Use custom BasketPanel for floating utility window that can still accept text input
        let panel = BasketPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Position just above Clipboard Manager (.popUpMenu = 101)
        panel.level = NSWindow.Level(Int(NSWindow.Level.popUpMenu.rawValue) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        
        // CRITICAL: Prevent AppKit from injecting its own unstable transform animations
        panel.animationBehavior = .none
        // Ensure manual memory management is stable
        panel.isReleasedWhenClosed = false
        
        // Create SwiftUI view with this basket's state (fully independent)
        let basketView = FloatingBasketView(basketState: basketState, accentColor: accentColor)

        let hostingView = NSHostingView(rootView: basketView)
        
        

        
        // Create drag container with this basket's state
        let dragContainer = BasketDragContainer(
            frame: NSRect(origin: .zero, size: windowFrame.size),
            basketState: basketState,
            controller: self
        )
        dragContainer.addSubview(hostingView)
        
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: dragContainer.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: dragContainer.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: dragContainer.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: dragContainer.trailingAnchor)
        ])
        
        panel.contentView = dragContainer
        
        // Reset notch hover
        DroppyState.shared.isMouseHovering = false
        DroppyState.shared.isDropTargeted = false
        
        // Set visible FIRST to kick off view rendering
        DroppyState.shared.isBasketVisible = true
        
        AppKitMotion.prepareForPresent(panel, initialScale: 0.88)
        panel.orderFrontRegardless()
        panel.makeKey() // Make key window so keyboard shortcuts work
        AppKitMotion.animateIn(panel, initialScale: 0.88, duration: 0.22)
        
        basketWindow = panel
        lastBasketFrame = windowFrame  // Save position for tracked folder reopening
        isShowingOrHiding = false
        
        // PREMIUM: Haptic feedback confirms jiggle gesture success
        HapticFeedback.expand()
        
        // DEFERRED: Validate basket items AFTER animation starts (file system checks can lag)
        DispatchQueue.main.async {
            DroppyState.shared.validateBasketItems()
        }
        
        // Start keyboard monitor for Quick Look preview
        startKeyboardMonitor()
        
        // Start mouse tracking for auto-hide peek mode
        startMouseTrackingMonitor()
    }
    
    /// Global keyboard monitor (fallback when panel isn't key window)
    private var globalKeyboardMonitor: Any?
    
    /// Starts keyboard monitor for spacebar Quick Look and Cmd+A select all
    private func startKeyboardMonitor() {
        stopKeyboardMonitor() // Clean up any existing
        
        // Local monitor - catches events when basket is key window
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.basketWindow?.isVisible == true,
                  !(self?.basketState.items.isEmpty ?? true) else {
                return event
            }
            
            // Spacebar triggers Quick Look (but never while renaming or typing)
            if event.keyCode == 49 {
                let shouldBlockQuickLook = (self?.basketState.isRenaming ?? false) ||
                    DroppyState.shared.isRenaming ||
                    (self?.isTextInputResponderActive() ?? false)
                guard !shouldBlockQuickLook else {
                    return event
                }
                let selectedItems = self?.basketState.items.filter { self?.basketState.selectedItems.contains($0.id) == true } ?? []
                let urls: [URL]
                if selectedItems.isEmpty {
                    urls = self?.basketState.items.first.map { [$0.url] } ?? []
                } else {
                    urls = selectedItems.map(\.url)
                }
                if !urls.isEmpty {
                    QuickLookHelper.shared.preview(urls: urls, from: self?.basketWindow)
                }
                return nil // Consume the event
            }
            
            // Cmd+A selects all basket items
            if event.keyCode == 0, event.modifierFlags.contains(.command) {
                let shouldBlockSelectAll = (self?.basketState.isRenaming ?? false) ||
                    DroppyState.shared.isRenaming ||
                    (self?.isTextInputResponderActive() ?? false)
                guard !shouldBlockSelectAll else {
                    return event
                }
                self?.basketState.selectedItems = Set(self?.basketState.items.map(\.id) ?? [])
                return nil // Consume the event
            }
            
            return event
        }
        
        // Global monitor - catches events when basket is visible but not key window
        // This ensures spacebar works even when clicking on items briefly loses focus
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.basketWindow?.isVisible == true,
                  !(self?.basketState.items.isEmpty ?? true) else {
                return
            }
            
            // Only handle spacebar for Quick Look (not Cmd+A - that requires local focus)
            if event.keyCode == 49 {
                let shouldBlockQuickLook = (self?.basketState.isRenaming ?? false) ||
                    DroppyState.shared.isRenaming ||
                    (self?.isTextInputResponderActive() ?? false)
                guard !shouldBlockQuickLook else {
                    return
                }
                // Check if mouse is over the basket window (user intent to interact with basket)
                if let basketFrame = self?.basketWindow?.frame {
                    let mouseLocation = NSEvent.mouseLocation
                    let expandedFrame = basketFrame.insetBy(dx: -20, dy: -20) // Small margin
                    if expandedFrame.contains(mouseLocation) {
                        let selectedItems = self?.basketState.items.filter { self?.basketState.selectedItems.contains($0.id) == true } ?? []
                        let urls: [URL]
                        if selectedItems.isEmpty {
                            urls = self?.basketState.items.first.map { [$0.url] } ?? []
                        } else {
                            urls = selectedItems.map(\.url)
                        }
                        if !urls.isEmpty {
                            QuickLookHelper.shared.preview(urls: urls, from: self?.basketWindow)
                        }
                    }
                }
            }
        }
    }
    
    /// Stops the keyboard monitor
    private func stopKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        if let monitor = globalKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyboardMonitor = nil
        }
    }

    /// Returns true while an editable text responder is active (e.g. rename popover field).
    private func isTextInputResponderActive() -> Bool {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else {
            return false
        }
        return textView.isEditable
    }
    
    /// Hides the basket window.
    /// - Parameters:
    ///   - preserveState: When true, keeps the basket/controller alive and only hides the window.
    ///   - force: When true, bypasses operation guards (used for explicit settings-level close-all).
    func hideBasket(preserveState: Bool = false, force: Bool = false) {
        guard let panel = basketWindow, !isShowingOrHiding else { return }
        
        // Block hiding during file operations UNLESS basket is empty (user cleared it manually)
        if !force &&
            (DroppyState.shared.isFileOperationInProgress || DroppyState.shared.isSharingInProgress) &&
            !basketState.items.isEmpty {
            return 
        }

        if preserveState {
            hideBasketPreservingState(panel)
            return
        }
        
        isShowingOrHiding = true
        basketState.isTargeted = false
        basketState.isAirDropZoneTargeted = false
        basketState.isQuickActionsTargeted = false
        
        // Stop keyboard monitoring
        stopKeyboardMonitor()
        
        // Stop mouse tracking
        stopMouseTrackingMonitor()
        
        // Reset peek mode
        isInPeekMode = false
        
        // PREMIUM: Critically damped spring matching shelf expandClose (response: 0.45, damping: 1.0)
        // Faster, no-wobble collapse animation
        AppKitMotion.animateOut(panel, targetScale: 0.95, duration: 0.2) { [weak self] in
            panel.orderOut(nil)
            AppKitMotion.resetPresentationState(panel)
            if let self = self {
                Self.removeBasket(self) // Clean up from multi-basket tracking
                self.basketWindow = nil
                DroppyState.shared.isBasketVisible = Self.isAnyBasketVisible
                DroppyState.shared.isBasketTargeted = false
                self.isShowingOrHiding = false
            }
        }
    }

    /// Hides basket without destroying controller/state (used by multi-basket "eye" action).
    func hideBasketPreservingState() {
        hideBasket(preserveState: true)
    }

    private func hideBasketPreservingState(_ panel: NSPanel) {
        isShowingOrHiding = true
        basketState.isTargeted = false
        basketState.isAirDropZoneTargeted = false
        basketState.isQuickActionsTargeted = false

        stopKeyboardMonitor()
        stopMouseTrackingMonitor()
        cancelHideTimer()
        isInPeekMode = false
        isPeekAnimating = false

        AppKitMotion.animateOut(panel, targetScale: 0.96, duration: 0.18) { [weak self] in
            guard let self else { return }
            panel.orderOut(nil)
            AppKitMotion.resetPresentationState(panel)
            DroppyState.shared.isBasketVisible = Self.isAnyBasketVisible
            DroppyState.shared.isBasketTargeted = false
            self.isShowingOrHiding = false

        }
    }
    
    // MARK: - Auto-Hide Peek Mode Methods (v5.3)
    
    /// Checks if auto-hide mode is enabled
    private var isAutoHideEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.enableBasketAutoHide,
            default: PreferenceDefault.enableBasketAutoHide
        )
    }
    
    /// Gets the configured auto-hide delay in seconds
    private var autoHideDelay: Double {
        let delay = UserDefaults.standard.double(forKey: AppPreferenceKey.basketAutoHideDelay)
        return delay > 0 ? delay : PreferenceDefault.basketAutoHideDelay
    }
    
    /// Starts mouse tracking/polling for auto-hide behavior.
    func startMouseTrackingMonitor() {
        stopMouseTrackingMonitor() // Clean up existing
        
        startAutoHidePolling()
        
        // GLOBAL monitor for peeking fallback.
        mouseTrackingMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.handleMouseMovement()
        }
    }
    
    /// Stops mouse tracking monitors
    private func stopMouseTrackingMonitor() {
        if let monitor = mouseTrackingMonitor {
            NSEvent.removeMonitor(monitor)
            mouseTrackingMonitor = nil
        }
        if let localMonitor = localMouseTrackingMonitor {
            NSEvent.removeMonitor(localMonitor)
            localMouseTrackingMonitor = nil
        }
        stopAutoHidePolling()
    }
    
    private func startAutoHidePolling() {
        autoHidePollTimer?.invalidate()
        autoHidePollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.evaluateAutoHideState()
        }
        if let autoHidePollTimer {
            RunLoop.main.add(autoHidePollTimer, forMode: .common)
        }
    }
    
    private func stopAutoHidePolling() {
        autoHidePollTimer?.invalidate()
        autoHidePollTimer = nil
    }
    
    /// Handles mouse movement for auto-hide logic (Peek Mode Only)
    private func handleMouseMovement() {
        // We only care about this global check if we are peeking!
        // If fully visible, BasketDragContainer handles mouseEntered/Exited
        guard let panel = basketWindow, panel.isVisible, isInPeekMode, !isShowingOrHiding else { return }
        
        // Don't interrupt during peek animations
        guard !isPeekAnimating else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let currentFrame = panel.frame

        // Only reveal when the cursor is actually inside the visible sliver
        // This prevents early reveal from near-edge proximity
        let visibleFrame = resolveBasketScreen(for: panel)?.visibleFrame ?? .zero
        let sliverFrame = currentFrame.intersection(visibleFrame)
        let isMouseOverBasket = !sliverFrame.isNull && sliverFrame.contains(mouseLocation)
        
        if isMouseOverBasket {
            // Mouse hovered over peek sliver - reveal
            cancelHideTimer()
            revealFromEdge()
        } 
        // Note: We don't need "else" here because startHideTimer is for "exiting" the basket.
        // If we are peeking, we are essentially "already hidden".
    }
    
    /// Starts the delayed hide timer (configurable delay, default 2 seconds)
    func startHideTimer() {
        guard isAutoHideEnabled, !isInPeekMode else { return }
        guard !isBasketSelectionDragActive else { return }
        hideDeadline = Date().addingTimeInterval(autoHideDelay)
        startAutoHidePolling()
    }
    
    /// Cancels any pending hide timer
    func cancelHideTimer() {
        hideDeadline = nil
    }
    
    /// Auto-hides the basket (replaces slideToEdge peek behavior)
    /// Simply hides the basket; users can reopen via drag jiggle or switcher shortcut.
    func autoHideBasket() {
        guard isAutoHideEnabled else { return }
        if hideDeadline == nil {
            hideDeadline = Date()
        }
        evaluateAutoHideState()
    }
    
    private func evaluateAutoHideState() {
        guard let panel = basketWindow, panel.isVisible else {
            hideDeadline = nil
            return
        }
        guard isAutoHideEnabled, !basketState.items.isEmpty else {
            hideDeadline = nil
            return
        }
        guard !isInPeekMode else {
            hideDeadline = nil
            return
        }
        
        let mouseLocation = NSEvent.mouseLocation
        if panel.frame.contains(mouseLocation) {
            hideDeadline = nil
            return
        }
        
        if Self.visibleBaskets.count > 1 {
            for otherBasket in Self.visibleBaskets where otherBasket !== self {
                if let frame = otherBasket.basketWindow?.frame, frame.contains(mouseLocation) {
                    hideDeadline = nil
                    return
                }
            }
        }
        
        if hideDeadline == nil {
            hideDeadline = Date().addingTimeInterval(autoHideDelay)
        }
        
        guard let hideDeadline else { return }
        guard Date() >= hideDeadline else { return }
        
        guard !isBasketSelectionDragActive,
              !DroppyState.shared.isFileOperationInProgress,
              !DroppyState.shared.isSharingInProgress,
              !isShowingOrHiding,
              !isPeekAnimating else {
            return
        }
        
        performAutoHide(panel)
    }
    
    private func performAutoHide(_ panel: NSPanel) {
        guard let screen = resolveBasketScreen(for: panel) else { return }
        activeBasketDisplayID = screen.displayID
        hideDeadline = nil
        
        // Store current position for restoration
        fullSizeFrame = panel.frame
        
        // Mark as auto-hidden so it can be restored via drag jiggle or shortcut workflow.
        isInPeekMode = true
        isPeekAnimating = true
        
        AppKitMotion.animateOut(panel, targetScale: 0.97, duration: 0.22) { [weak self] in
            guard let self = self else { return }
            self.isPeekAnimating = false
            self.stopMouseTrackingMonitor()
            panel.orderOut(nil)
            AppKitMotion.resetPresentationState(panel)  // Reset alpha for when it shows again
        }
    }
    
    /// Legacy slideToEdge - kept for compatibility, now just calls autoHideBasket
    func slideToEdge() {
        autoHideBasket()
    }
    
    /// Reveals the basket from auto-hidden mode
    /// Since we now fully hide instead of peeking, this just shows the basket
    func revealFromEdge() {
        guard isInPeekMode, !isPeekAnimating else { return }
        
        isInPeekMode = false
        showBasket()
    }
    
    /// Called when cursor enters the basket area (from FloatingBasketView)
    func onBasketHoverEnter() {
        guard isAutoHideEnabled else { return }
        cancelHideTimer()
        if isInPeekMode {
            revealFromEdge()
        }
    }
    
    /// Called when cursor exits the basket area (from FloatingBasketView)
    func onBasketHoverExit() {
        guard isAutoHideEnabled, !basketState.items.isEmpty else { return }
        guard !isBasketSelectionDragActive else { return }

        // If cursor is still inside the basket window, don't start hide
        if let panel = basketWindow {
            let mouseLocation = NSEvent.mouseLocation
            if panel.frame.contains(mouseLocation) {
                return
            }
        }
        
        // Multi-basket: Don't hide if mouse moved to another visible basket
        let mouseLocation = NSEvent.mouseLocation
        if Self.visibleBaskets.count > 1 {
            for otherBasket in Self.visibleBaskets where otherBasket !== self {
                if let frame = otherBasket.basketWindow?.frame, frame.contains(mouseLocation) {
                    return  // Mouse is entering another basket, don't hide this one
                }
            }
        }
        
        // Don't trigger hide during file operations
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        // Don't trigger hide during animations (prevent race conditions)
        guard !isPeekAnimating else { return }
        
        if !isInPeekMode {
            startHideTimer()
        }
    }

    /// Called when drag-selection starts in the basket grid/list.
    func beginBasketSelectionDrag() {
        isBasketSelectionDragActive = true
        cancelHideTimer()
    }

    /// Called when drag-selection ends in the basket grid/list.
    func endBasketSelectionDrag() {
        isBasketSelectionDragActive = false

        guard isAutoHideEnabled, !basketState.items.isEmpty else { return }
        guard !isInPeekMode, !isPeekAnimating else { return }
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        guard let panel = basketWindow else { return }

        // If selection ended with cursor outside the basket, start normal hide delay.
        let mouseLocation = NSEvent.mouseLocation
        if !panel.frame.contains(mouseLocation) {
            startHideTimer()
        }
    }
}
