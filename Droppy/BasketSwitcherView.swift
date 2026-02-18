//
//  BasketSwitcherView.swift
//  Droppy
//
//  Created by Droppy on 06/02/2026.
//
//  Cmd+Tab style overlay for selecting between multiple baskets during drag.
//  Shows all active baskets as colored cards with drop targets.
//

import SwiftUI
import UniformTypeIdentifiers

private let basketSwitcherDropTypes: [UTType] = [
    .fileURL,
    .url,
    .text,
    .image,
    .movie,
    .data
]

/// Cmd+Tab style overlay for selecting which basket to drop files into
/// Appears when jiggling while dragging with multiple baskets active
struct BasketSwitcherView: View {
    /// All basket controllers to display
    let baskets: [FloatingBasketWindowController]
    /// Called when a file is dropped on a basket card (with providers to add)
    let onDropToBasket: (FloatingBasketWindowController, [NSItemProvider]) -> Void
    /// Called when user drops on "New Basket" card
    let onDropToNewBasket: ([NSItemProvider]) -> Void
    /// Called to dismiss the switcher
    let onDismiss: () -> Void
    
    @State private var hoveredBasketIndex: Int? = nil
    @State private var isNewBasketHovered: Bool = false

    private var visibleBaskets: [FloatingBasketWindowController] {
        baskets.filter { !$0.basketState.items.isEmpty }
    }
    
    var body: some View {
        ZStack {
            // Dimming background
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Basket cards row
            HStack(spacing: 20) {
                // Existing baskets
                ForEach(Array(visibleBaskets.enumerated()), id: \.offset) { index, basket in
                    BasketSwitcherCard(
                        basket: basket,
                        isHovered: hoveredBasketIndex == index,
                        onDrop: { providers in onDropToBasket(basket, providers) }
                    )
                    .onHover { hovering in
                        if hovering && hoveredBasketIndex != index {
                            HapticFeedback.hover()
                        }
                        withAnimation(DroppyAnimation.hover) {
                            hoveredBasketIndex = hovering ? index : nil
                        }
                    }
                }
                
                // "New Basket" card
                NewBasketSwitcherCard(
                    isHovered: isNewBasketHovered,
                    onDrop: onDropToNewBasket
                )
                .onHover { hovering in
                    if hovering && !isNewBasketHovered {
                        HapticFeedback.hover()
                    }
                    withAnimation(DroppyAnimation.hover) {
                        isNewBasketHovered = hovering
                    }
                }
            }
            .padding(24)
            .background(
                // Glassmorphism container
                RoundedRectangle(cornerRadius: 20)
                    .droppyGlassFill()
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AdaptiveColors.overlayAuto(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            )
        }
    }
}

/// Click-to-select overlay for switching between baskets (triggered by keyboard shortcut)
/// Unlike the drop-based switcher, this lets users click on a basket to show it
struct BasketSelectionView: View {
    let baskets: [FloatingBasketWindowController]
    let onSelect: (FloatingBasketWindowController) -> Void
    let onNewBasket: () -> Void
    let onDismiss: () -> Void
    
    @State private var hoveredBasketIndex: Int? = nil
    @State private var isNewBasketHovered: Bool = false

    private var visibleBaskets: [FloatingBasketWindowController] {
        baskets.filter { !$0.basketState.items.isEmpty }
    }
    
    var body: some View {
        ZStack {
            // Dimming background
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Basket cards row
            HStack(spacing: 20) {
                // Existing baskets
                ForEach(Array(visibleBaskets.enumerated()), id: \.offset) { index, basket in
                    BasketSelectionCard(
                        basket: basket,
                        isHovered: hoveredBasketIndex == index,
                        onSelect: {
                            onSelect(basket)
                        }
                    )
                    .onHover { hovering in
                        withAnimation(DroppyAnimation.hover) {
                            hoveredBasketIndex = hovering ? index : nil
                        }
                    }
                }
                
                // New basket card
                NewBasketSelectionCard(
                    isHovered: isNewBasketHovered,
                    onSelect: onNewBasket
                )
                .onHover { hovering in
                    withAnimation(DroppyAnimation.hover) {
                        isNewBasketHovered = hovering
                    }
                }
            }
            .padding(24)
            .background(
                // Glassmorphism container
                RoundedRectangle(cornerRadius: 20)
                    .droppyGlassFill()
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AdaptiveColors.overlayAuto(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            )
        }
    }
}

/// Selection card for a basket (clickable)
struct BasketSelectionCard: View {
    let basket: FloatingBasketWindowController
    let isHovered: Bool
    let onSelect: () -> Void
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(basket.accentColor.color.opacity(isHovered ? 0.25 : 0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(basket.accentColor.color.opacity(isHovered ? 0.5 : 0.3), lineWidth: 1)
            )
    }
    
    private var handleIndicator: some View {
        Capsule()
            .fill(basket.accentColor.color.opacity(isHovered ? 0.8 : 0.5))
            .frame(width: 44, height: 5)
            .padding(.top, 8)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            handleIndicator
                .padding(.bottom, 6)

            if !basket.basketState.items.isEmpty {
                PeekFileCountHeader(items: basket.basketState.items, style: .plain)
                    .padding(.top, 2)
            }

            VStack(spacing: 0) {
                if basket.basketState.items.isEmpty {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(AdaptiveColors.secondaryTextAuto.opacity(0.82))
                } else {
                    BasketStackPreviewView(items: basket.basketState.items)
                        .frame(width: 142, height: 104, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .padding(.horizontal, 10)
        .frame(width: 160, height: 180)
        .background(cardBackground)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(DroppyAnimation.bouncy, value: isHovered)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

/// "New Basket" card for selection mode
struct NewBasketSelectionCard: View {
    let isHovered: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Plus icon
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(
                    isHovered
                        ? AdaptiveColors.primaryTextAuto
                        : AdaptiveColors.secondaryTextAuto.opacity(0.85)
                )
            
            Text("New Basket")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(AdaptiveColors.primaryTextAuto.opacity(isHovered ? 0.98 : 0.88))
        }
        .frame(width: 160, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AdaptiveColors.overlayAuto(isHovered ? 0.15 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .foregroundStyle(AdaptiveColors.overlayAuto(isHovered ? 0.68 : 0.5))
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(DroppyAnimation.bouncy, value: isHovered)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

/// "New Basket" card for creating a new basket when dropping
struct NewBasketSwitcherCard: View {
    let isHovered: Bool
    let onDrop: ([NSItemProvider]) -> Void
    
    @State private var isDropTargeted: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Plus icon
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(
                    AdaptiveColors.overlayAuto(isDropTargeted ? 1.0 : (isHovered ? 1.0 : 0.7))
                )
            
            Text("New Basket")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AdaptiveColors.primaryTextAuto.opacity(isHovered || isDropTargeted ? 0.98 : 0.88))
            
            Text(isDropTargeted ? "Release!" : "Drop to create")
                .font(.caption2)
                .foregroundStyle(AdaptiveColors.secondaryTextAuto.opacity(isDropTargeted ? 0.95 : (isHovered ? 0.85 : 0.72)))
        }
        .frame(width: 160, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AdaptiveColors.overlayAuto(isDropTargeted ? 0.25 : (isHovered ? 0.15 : 0.1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            AdaptiveColors.overlayAuto(isDropTargeted ? 1.0 : (isHovered ? 0.6 : 0.3)),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                )
        )
        // Match basket's pressed effect: scale DOWN when targeted
        .scaleEffect(isDropTargeted ? 0.97 : (isHovered ? 1.02 : 1.0))
        .animation(DroppyAnimation.bouncy, value: isHovered)
        .animation(DroppyAnimation.bouncy, value: isDropTargeted)
        .contentShape(Rectangle())
        .onDrop(of: basketSwitcherDropTypes, isTargeted: $isDropTargeted) { providers in
            onDrop(providers)
            return true
        }
    }
}

/// Individual basket card in the switcher
struct BasketSwitcherCard: View {
    let basket: FloatingBasketWindowController
    let isHovered: Bool
    let onDrop: ([NSItemProvider]) -> Void
    
    @State private var isDropTargeted: Bool = false
    
    /// Access basketState directly (uses @Observable, not ObservableObject)
    private var basketState: BasketState {
        basket.basketState
    }
    
    /// Card background with accent color and drop target indication
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(basket.accentColor.color.opacity(isDropTargeted ? 0.5 : (isHovered ? 0.4 : 0.2)))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        basket.accentColor.color.opacity(isDropTargeted ? 1.0 : (isHovered ? 0.8 : 0.4)),
                        lineWidth: isDropTargeted ? 3 : 2
                    )
            )
    }
    
    /// Handle capsule matching the basket's drag handle
    private var handleIndicator: some View {
        Capsule()
            .fill(basket.accentColor.color.opacity(isHovered ? 0.8 : 0.5))
            .frame(width: 44, height: 5)
            .padding(.top, 8)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            handleIndicator
                .padding(.bottom, 6)

            if !basketState.items.isEmpty {
                PeekFileCountHeader(items: basketState.items, style: .plain)
                    .padding(.top, 2)
            }

            VStack(spacing: 4) {
                if basketState.items.isEmpty {
                    Image(systemName: isDropTargeted ? "plus.circle.fill" : "tray")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(basket.accentColor.color.opacity(isDropTargeted ? 1.0 : 0.6))
                    Text(isDropTargeted ? "Drop here" : "Empty")
                        .font(.caption)
                        .foregroundStyle(isDropTargeted ? basket.accentColor.color : .secondary)
                } else {
                    BasketStackPreviewView(items: basketState.items)
                        .frame(width: 142, height: 104, alignment: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .padding(.horizontal, 10)
        .frame(width: 160, height: 180)
        .background(cardBackground)
        // Match basket's pressed effect: scale DOWN when targeted (like button being pushed)
        .scaleEffect(isDropTargeted ? 0.97 : (isHovered ? 1.02 : 1.0))
        .animation(DroppyAnimation.bouncy, value: isHovered)
        .animation(DroppyAnimation.bouncy, value: isDropTargeted)
        .contentShape(Rectangle())
        .onDrop(of: basketSwitcherDropTypes, isTargeted: $isDropTargeted) { providers in
            onDrop(providers)
            return true
        }
    }
}

// MARK: - Tracked Folder Switcher View

/// Switcher view specifically for tracked folder file additions
/// Shows the pending file(s) and lets user tap a basket to add them
struct TrackedFolderSwitcherView: View {
    let baskets: [FloatingBasketWindowController]
    let pendingFiles: [URL]
    let onSelectBasket: (FloatingBasketWindowController) -> Void
    let onDismiss: () -> Void
    
    @State private var hoveredBasketIndex: Int? = nil

    private var visibleBaskets: [FloatingBasketWindowController] {
        baskets.filter { !$0.basketState.items.isEmpty }
    }
    
    /// File info for display
    private var filePreviewText: String {
        if pendingFiles.count == 1 {
            return pendingFiles[0].lastPathComponent
        } else {
            return "\(pendingFiles.count) files"
        }
    }
    
    var body: some View {
        ZStack {
            // Dimming background
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 20) {
                // File preview header
                VStack(spacing: 8) {
                    // File icon(s)
                    if pendingFiles.count == 1 {
                        let icon = ThumbnailCache.shared.cachedIcon(forPath: pendingFiles[0].path)
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AdaptiveColors.secondaryTextAuto.opacity(0.88))
                    }
                    
                    Text(filePreviewText)
                        .font(.headline)
                        .foregroundStyle(AdaptiveColors.primaryTextAuto)
                    
                    Text("Select a basket to add")
                        .font(.subheadline)
                        .foregroundStyle(AdaptiveColors.secondaryTextAuto.opacity(0.82))
                }
                .padding(.bottom, 8)
                
                // Basket cards row
                HStack(spacing: 20) {
                    ForEach(Array(visibleBaskets.enumerated()), id: \.offset) { index, basket in
                        TrackedFolderBasketCard(
                            basket: basket,
                            isHovered: hoveredBasketIndex == index,
                            onSelect: { onSelectBasket(basket) }
                        )
                        .onHover { hovering in
                            if hovering && hoveredBasketIndex != index {
                                HapticFeedback.hover()
                            }
                            withAnimation(DroppyAnimation.hover) {
                                hoveredBasketIndex = hovering ? index : nil
                            }
                        }
                    }
                }
            }
            .padding(24)
            .background(
                // Glassmorphism container
                RoundedRectangle(cornerRadius: 20)
                    .droppyGlassFill()
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AdaptiveColors.overlayAuto(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            )
        }
    }
}

/// Basket card for tracked folder switcher (tap to select, no drop)
private struct TrackedFolderBasketCard: View {
    let basket: FloatingBasketWindowController
    let isHovered: Bool
    let onSelect: () -> Void
    
    private var basketState: BasketState {
        basket.basketState
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(basket.accentColor.color.opacity(isHovered ? 0.4 : 0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(basket.accentColor.color.opacity(isHovered ? 0.8 : 0.4), lineWidth: 2)
            )
    }
    
    private var handleIndicator: some View {
        Capsule()
            .fill(basket.accentColor.color.opacity(isHovered ? 0.8 : 0.5))
            .frame(width: 44, height: 5)
            .padding(.top, 8)
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                handleIndicator
                    .padding(.bottom, 6)

                if !basketState.items.isEmpty {
                    PeekFileCountHeader(items: basketState.items, style: .plain)
                        .padding(.top, 2)
                }
                
                VStack(spacing: 4) {
                    if basketState.items.isEmpty {
                        Image(systemName: "tray")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(basket.accentColor.color.opacity(0.6))
                        Text("Empty")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        BasketStackPreviewView(items: basketState.items)
                            .frame(width: 142, height: 104, alignment: .bottom)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .padding(.horizontal, 10)
            .frame(width: 160, height: 180)
            .background(cardBackground)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovered)
        }
        .buttonStyle(.plain)
    }
}
// MARK: - Window Controller for Switcher

/// Window controller for the basket switcher overlay
final class BasketSwitcherWindowController {
    static let shared = BasketSwitcherWindowController()
    
    private var switcherWindow: NSPanel?
    private var hostingView: NSHostingView<BasketSwitcherView>?
    
    /// Whether the switcher is currently visible
    var isVisible: Bool {
        switcherWindow?.isVisible ?? false
    }
    
    /// Baskets that were hidden when switcher opened (to restore on close)
    private var hiddenBaskets: [FloatingBasketWindowController] = []
    
    /// Global shortcut registration for triggering switcher.
    private var shortcutHotKey: GlobalHotKey?
    
    /// Debounce repeated keyDown events.
    private var lastShortcutTriggerAt: Date = .distantPast
    private var shortcutSignature: String = ""
    
    private var userDefaultsObserver: NSObjectProtocol?
    
    private init() {
        // Set up shortcut monitoring on init
        setupShortcutMonitor()
        
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            self?.setupShortcutMonitor()
        }
    }
    
    deinit {
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
    }
    
    /// Reloads the shortcut configuration (called when settings change)
    func reloadShortcutConfiguration() {
        setupShortcutMonitor()
    }
    
    private func setupShortcutMonitor() {
        // Shortcut is only meaningful when floating basket and multi-basket are enabled.
        let floatingEnabled = UserDefaults.standard.preference(
            AppPreferenceKey.enableFloatingBasket,
            default: PreferenceDefault.enableFloatingBasket
        )
        let multiEnabled = UserDefaults.standard.preference(
            AppPreferenceKey.enableMultiBasket,
            default: PreferenceDefault.enableMultiBasket
        )
        guard floatingEnabled, multiEnabled else {
            guard shortcutSignature != "disabled" else { return }
            shortcutSignature = "disabled"
            shortcutHotKey = nil
            return
        }
        
        // Load saved shortcut.
        guard let data = UserDefaults.standard.data(forKey: AppPreferenceKey.basketSwitcherShortcut),
              let savedShortcut = try? JSONDecoder().decode(SavedShortcut.self, from: data) else {
            guard shortcutSignature != "none" else { return }
            shortcutSignature = "none"
            shortcutHotKey = nil
            return
        }

        let signature = "\(savedShortcut.keyCode):\(savedShortcut.modifiers)"
        guard signature != shortcutSignature else { return }
        shortcutSignature = signature

        // Remove existing shortcut registration, then register the updated shortcut.
        shortcutHotKey = nil

        shortcutHotKey = GlobalHotKey(
            keyCode: savedShortcut.keyCode,
            modifiers: savedShortcut.modifiers,
            enableIOHIDFallback: false
        ) { [weak self] in
            guard let self else { return }

            // Debounce key repeat.
            let now = Date()
            guard now.timeIntervalSince(self.lastShortcutTriggerAt) > 0.25 else {
                return
            }
            self.lastShortcutTriggerAt = now

            DispatchQueue.main.async {
                self.showFromShortcut()
            }
        }
    }
    
    /// Shows the switcher from keyboard shortcut (shows ALL baskets including hidden)
    private func showFromShortcut() {
        let floatingEnabled = UserDefaults.standard.preference(
            AppPreferenceKey.enableFloatingBasket,
            default: PreferenceDefault.enableFloatingBasket
        )
        guard floatingEnabled else { return }
        
        let multiBasketEnabled = UserDefaults.standard.preference(
            AppPreferenceKey.enableMultiBasket,
            default: PreferenceDefault.enableMultiBasket
        )
        if !multiBasketEnabled {
            FloatingBasketWindowController.enforceSingleBasketMode()
        }
        
        // Collect all basket controllers (shared + spawned), including hidden and empty baskets.
        // If this is the untouched initial state (only shared basket and it's empty),
        // hide that placeholder card and show only "New Basket".
        let allBaskets = FloatingBasketWindowController.allBaskets
        let selectionBaskets = allBaskets.filter { basket in
            let isInitialEmptySharedOnly =
                allBaskets.count == 1 &&
                basket === FloatingBasketWindowController.shared &&
                basket.basketState.items.isEmpty
            return !isInitialEmptySharedOnly
        }

        // Always show the switcher UI for this shortcut, even with one basket.
        // This keeps behavior aligned with the "Basket Switcher" naming and UX expectation.
        showForSelection(baskets: selectionBaskets) { selectedBasket in
            selectedBasket.showBasket()
        }
    }
    
    /// Shows the basket switcher overlay
    /// - Parameters:
    ///   - baskets: The baskets to display
    ///   - onSelectBasket: Callback when a basket is selected for the drop (receives providers)
    func show(baskets: [FloatingBasketWindowController], onSelectBasket: @escaping (FloatingBasketWindowController, [NSItemProvider]) -> Void) {
        guard baskets.count >= 2 else { return }  // Only show for 2+ baskets
        
        // Dismiss existing
        hide()
        
        // Fade out all visible baskets to avoid visual clutter and track them
        hiddenBaskets = []
        for basket in baskets {
            if let window = basket.basketWindow, window.isVisible {
                hiddenBaskets.append(basket)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().alphaValue = 0
                }
            }
        }
        
        guard let screen = overlayScreen() else { return }
        
        // Create switcher view
        let switcherView = BasketSwitcherView(
            baskets: baskets,
            onDropToBasket: { [weak self] basket, providers in
                // Resolve dropped providers into concrete local URLs.
                Task { @MainActor in
                    let urls = await Self.extractDroppedURLs(from: providers)
                    if !urls.isEmpty {
                        basket.basketState.addItems(from: urls)
                    }
                }
                onSelectBasket(basket, providers)
                self?.hide()
            },
            onDropToNewBasket: { [weak self] providers in
                // Spawn a new basket and add the dropped files
                let newBasket = FloatingBasketWindowController.spawnNewBasket()
                
                // Resolve dropped providers into concrete local URLs.
                Task { @MainActor in
                    let urls = await Self.extractDroppedURLs(from: providers)
                    if !urls.isEmpty {
                        newBasket.basketState.addItems(from: urls)
                    }
                }
                onSelectBasket(newBasket, providers)
                self?.hide()
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )
        
        // Create window
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        
        // Create hosting view
        let hosting = NSHostingView(rootView: switcherView)
        hosting.frame = panel.contentView?.bounds ?? NSRect.zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hosting)
        
        // Store references
        switcherWindow = panel
        hostingView = hosting
        
        // Animate in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }
    
    /// Hides the basket switcher overlay
    func hide() {
        guard let panel = switcherWindow else {
            if !hiddenBaskets.isEmpty {
                for basket in hiddenBaskets {
                    basket.basketWindow?.alphaValue = 1
                }
                hiddenBaskets = []
            }
            hostingView = nil
            return
        }
        
        // Store reference to clean up after animation
        let panelToClose = panel
        let hostingToRemove = hostingView
        let basketsToRestore = hiddenBaskets
        
        // Clear references immediately to prevent double-hide issues
        switcherWindow = nil
        hostingView = nil
        hiddenBaskets = []
        
        // Immediately make panel ignore mouse events to unblock screen
        panelToClose.ignoresMouseEvents = true
        
        // Fade baskets back in
        for basket in basketsToRestore {
            if let window = basket.basketWindow {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().alphaValue = 1
                }
            }
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panelToClose.animator().alphaValue = 0
        } completionHandler: {
            hostingToRemove?.removeFromSuperview()
            panelToClose.orderOut(nil)
            panelToClose.close()
        }
    }
    
    /// Shows the basket switcher for clicking to select (no drop, just show the basket)
    /// Used when triggered via keyboard shortcut
    /// - Parameters:
    ///   - baskets: The baskets to display
    ///   - onSelectBasket: Callback when a basket is clicked
    func showForSelection(baskets: [FloatingBasketWindowController], onSelectBasket: @escaping (FloatingBasketWindowController) -> Void) {
        // Dismiss existing
        hide()
        
        // Fade out all visible baskets
        hiddenBaskets = []
        for basket in baskets {
            if let window = basket.basketWindow, window.isVisible {
                hiddenBaskets.append(basket)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().alphaValue = 0
                }
            }
        }
        
        guard let screen = overlayScreen() else { return }
        
        // Create selection view
        let selectionView = BasketSelectionView(
            baskets: baskets,
            onSelect: { [weak self] basket in
                self?.hide()
                onSelectBasket(basket)
            },
            onNewBasket: { [weak self] in
                self?.hide()
                let newBasket = FloatingBasketWindowController.spawnNewBasket()
                onSelectBasket(newBasket)
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )
        
        // Create window
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        
        // Create hosting view
        let hosting = NSHostingView(rootView: selectionView)
        hosting.frame = screen.frame
        panel.contentView = hosting
        
        // Store references
        switcherWindow = panel
        
        // Animate in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }
    
    /// Shows the basket switcher for tracked folder file additions
    /// Displays which files will be added and lets user pick the basket
    /// - Parameters:
    ///   - baskets: The baskets to choose from
    ///   - pendingFiles: The files that will be added to the selected basket
    ///   - onSelect: Callback when a basket is selected
    func showForTrackedFolder(baskets: [FloatingBasketWindowController], pendingFiles: [URL], onSelect: @escaping (FloatingBasketWindowController) -> Void) {
        guard baskets.count >= 2, !pendingFiles.isEmpty else { return }
        
        // Dismiss existing
        hide()
        
        // Fade out visible baskets for a cleaner picker focus.
        hiddenBaskets = []
        for basket in baskets {
            if let window = basket.basketWindow, window.isVisible {
                hiddenBaskets.append(basket)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    window.animator().alphaValue = 0
                }
            }
        }
        
        guard let screen = overlayScreen() else { return }
        
        // Create switcher view with file preview
        let switcherView = TrackedFolderSwitcherView(
            baskets: baskets,
            pendingFiles: pendingFiles,
            onSelectBasket: { [weak self] basket in
                onSelect(basket)
                self?.hide()
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )
        
        // Create window
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        
        // Create hosting view
        let hosting = NSHostingView(rootView: switcherView)
        hosting.frame = panel.contentView?.bounds ?? NSRect.zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hosting)
        
        // Store references
        switcherWindow = panel
        
        // Animate in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }
    
    private func overlayScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return mouseScreen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
    
    private static func extractDroppedURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        var seenPaths: Set<String> = []
        
        for provider in providers {
            if let url = await extractDroppedURL(from: provider) {
                let normalizedPath = url.standardizedFileURL.path
                guard !seenPaths.contains(normalizedPath) else { continue }
                seenPaths.insert(normalizedPath)
                urls.append(url)
            }
        }
        
        return urls
    }
    
    private static func extractDroppedURL(from provider: NSItemProvider) async -> URL? {
        // 1) Standard file-url payload.
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let item = await loadItem(from: provider, typeIdentifier: UTType.fileURL.identifier),
           let fileURL = fileURL(from: item) {
            return fileURL
        }
        
        // 2) Generic URL payload (only accept local file URLs).
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let item = await loadItem(from: provider, typeIdentifier: UTType.url.identifier),
           let fileURL = fileURL(from: item) {
            return fileURL
        }
        
        // 3) File representations (image/movie/data providers like Photos, etc.).
        for typeIdentifier in [UTType.image.identifier, UTType.movie.identifier, UTType.data.identifier] {
            guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else { continue }
            if let representedURL = await loadFileRepresentation(from: provider, typeIdentifier: typeIdentifier) {
                return representedURL
            }
        }
        
        // 4) Plain text fallback: persist dropped text into a temp file.
        if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier),
           let item = await loadItem(from: provider, typeIdentifier: UTType.text.identifier),
           let text = text(from: item),
           !text.isEmpty {
            return writeTextToTemporaryFile(text)
        }
        
        return nil
    }
    
    private static func loadItem(from provider: NSItemProvider, typeIdentifier: String) async -> NSSecureCoding? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }
    
    private static func loadFileRepresentation(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let fileManager = FileManager.default
                let destinationDir = fileManager.temporaryDirectory.appendingPathComponent("DroppySwitcherDrops", isDirectory: true)
                try? fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
                
                let fileName = url.lastPathComponent.isEmpty ? "Dropped-\(UUID().uuidString)" : url.lastPathComponent
                let destination = destinationDir.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
                
                do {
                    try fileManager.copyItem(at: url, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private static func fileURL(from item: NSSecureCoding) -> URL? {
        if let url = item as? URL, url.isFileURL {
            return url
        }
        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL {
            return url
        }
        if let string = item as? String {
            if let url = URL(string: string), url.isFileURL {
                return url
            }
            if string.hasPrefix("/") {
                let fileURL = URL(fileURLWithPath: string)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    return fileURL
                }
            }
        }
        if let string = item as? NSString {
            let value = String(string)
            if let url = URL(string: value), url.isFileURL {
                return url
            }
            if value.hasPrefix("/") {
                let fileURL = URL(fileURLWithPath: value)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    return fileURL
                }
            }
        }
        return nil
    }
    
    private static func text(from item: NSSecureCoding) -> String? {
        if let text = item as? String {
            return text
        }
        if let text = item as? NSString {
            return String(text)
        }
        if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
            return text
        }
        return nil
    }
    
    private static func writeTextToTemporaryFile(_ text: String) -> URL? {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent("DroppySwitcherDrops", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let filename = "Text \(formatter.string(from: Date()))-\(UUID().uuidString).txt"
        let fileURL = directory.appendingPathComponent(filename)
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}
