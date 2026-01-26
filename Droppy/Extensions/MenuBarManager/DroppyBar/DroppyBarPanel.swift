//
//  DroppyBarPanel.swift
//  Droppy
//
//  Simplified Droppy Bar that shows user-selected app icons.
//  Click to activate the app.
//

import Cocoa
import SwiftUI

/// A floating panel that displays user-selected status menu icons.
@MainActor
final class DroppyBarPanel: NSPanel {
    
    /// Shared image cache
    let imageCache = MenuBarItemImageCache()
    
    /// The current screen
    private(set) var currentScreen: NSScreen?
    
    // MARK: - Initialization
    
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupPanel()
    }
    
    private func setupPanel() {
        // Panel appearance - match Ice styling
        title = "Droppy Bar"
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        allowsToolTipsWhenApplicationIsInactive = true
        backgroundColor = .clear
        hasShadow = false  // Shadow handled by SwiftUI
        
        // Floating behavior
        level = .mainMenu + 1
        isFloatingPanel = true
        hidesOnDeactivate = false
        animationBehavior = .none
        
        // Collection behavior
        collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle, .moveToActiveSpace]
        
        // Accept first mouse
        acceptsMouseMovedEvents = true
    }
    
    // MARK: - Show/Hide
    
    /// Show the panel on the specified screen
    func show(on screen: NSScreen? = nil) async {
        // Find the screen with the mouse cursor if not specified
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = screen ?? NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        
        guard let targetScreen = targetScreen else { return }
        
        currentScreen = targetScreen
        
        // Update image cache before showing
        await imageCache.updateCache()
        
        // Create content view
        let hostingView = DroppyBarHostingView(
            rootView: DroppyBarContentView(imageCache: imageCache, closePanel: { [weak self] in
                self?.close()
            })
        )
        contentView = hostingView
        
        // Position and show
        updateOrigin(for: targetScreen)
        orderFrontRegardless()
        
        print("[DroppyBar] Shown on screen: \(targetScreen.localizedName)")
    }
    
    /// Update the panel position for the given screen
    private func updateOrigin(for screen: NSScreen) {
        let menuBarHeight: CGFloat = 24
        
        // Calculate origin Y: just below menu bar
        let originY = (screen.frame.maxY - 1) - menuBarHeight - frame.height
        
        // Calculate origin X: right side of screen, with padding
        let originX = screen.frame.maxX - frame.width - 8
        
        setFrameOrigin(CGPoint(x: originX, y: originY))
    }
    
    override func close() {
        super.close()
        contentView = nil
        currentScreen = nil
    }
}

// MARK: - DroppyBarHostingView

/// Custom hosting view that accepts first mouse
private final class DroppyBarHostingView: NSHostingView<DroppyBarContentView> {
    override var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - DroppyBarContentView

/// SwiftUI content view - Ice-style capsule bar with icons
struct DroppyBarContentView: View {
    @ObservedObject var imageCache: MenuBarItemImageCache
    let closePanel: () -> Void
    
    @State private var items: [MenuBarItem] = []
    @State private var showingConfiguration = false
    
    private var contentHeight: CGFloat {
        imageCache.menuBarHeight ?? 24
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if items.isEmpty {
                if !CGPreflightScreenCaptureAccess() {
                    permissionNeededView
                } else {
                    configurePromptView
                }
            } else {
                ForEach(items) { item in
                    DroppyBarItemView(
                        item: item,
                        imageCache: imageCache,
                        closePanel: closePanel
                    )
                }
            }
            
            // Configure button
            configureButton
        }
        .frame(height: contentHeight)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        // Ice-style capsule background
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .clipShape(Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.33), radius: 2.5)
        .padding(5)
        .fixedSize()
        .onAppear {
            loadItems()
        }
        .sheet(isPresented: $showingConfiguration) {
            DroppyBarConfigView(onDismiss: {
                showingConfiguration = false
                loadItems()
            })
        }
    }
    
    private var permissionNeededView: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Screen recording required")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
    }
    
    private var configurePromptView: some View {
        Text("Click + to add icons")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
    }
    
    private var configureButton: some View {
        Button {
            showingConfiguration = true
        } label: {
            Image(systemName: "plus.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .help("Configure Droppy Bar icons")
    }
    
    private func loadItems() {
        // Get all menu bar items
        let allItems = MenuBarItem.getMenuBarItems(onScreenOnly: false, activeSpaceOnly: true)
        
        // Get configured owner names from store
        let configuredOwnerNames = MenuBarManager.shared.getDroppyBarItemStore().enabledOwnerNames
        
        print("[DroppyBar] Looking for \(configuredOwnerNames.count) configured items: \(configuredOwnerNames)")
        
        // Filter to only show configured items
        if configuredOwnerNames.isEmpty {
            items = []
            print("[DroppyBar] No configured items, showing empty")
        } else {
            items = allItems.filter { item in
                let isMatch = configuredOwnerNames.contains(item.ownerName)
                if isMatch {
                    print("[DroppyBar] Match: \(item.ownerName)")
                }
                return isMatch
            }
            print("[DroppyBar] Showing \(items.count) matched items")
        }
    }
}

// MARK: - DroppyBarItemView

/// A single menu bar item in the Droppy Bar
struct DroppyBarItemView: View {
    let item: MenuBarItem
    @ObservedObject var imageCache: MenuBarItemImageCache
    let closePanel: () -> Void
    
    private var image: NSImage? {
        imageCache.getImage(for: item)
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback: show app icon
                if let app = item.owningApplication,
                   let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .padding(.horizontal, 4)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .overlay {
            DroppyBarClickHandler(item: item, closePanel: closePanel)
        }
        .help(item.displayName)
    }
}

// MARK: - DroppyBarClickHandler

/// NSViewRepresentable for proper mouse event handling
struct DroppyBarClickHandler: NSViewRepresentable {
    let item: MenuBarItem
    let closePanel: () -> Void
    
    func makeNSView(context: Context) -> DroppyBarClickView {
        DroppyBarClickView(item: item, closePanel: closePanel)
    }
    
    func updateNSView(_ nsView: DroppyBarClickView, context: Context) {}
}

/// NSView that handles mouse clicks
final class DroppyBarClickView: NSView {
    let item: MenuBarItem
    let closePanel: () -> Void
    
    private var lastMouseDownDate = Date.now
    private var lastMouseDownLocation = CGPoint.zero
    
    init(item: MenuBarItem, closePanel: @escaping () -> Void) {
        self.item = item
        self.closePanel = closePanel
        super.init(frame: .zero)
        self.toolTip = item.displayName
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        lastMouseDownDate = .now
        lastMouseDownLocation = NSEvent.mouseLocation
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        // Only trigger if quick click (not drag)
        let elapsed = Date.now.timeIntervalSince(lastMouseDownDate)
        let distance = hypot(NSEvent.mouseLocation.x - lastMouseDownLocation.x,
                            NSEvent.mouseLocation.y - lastMouseDownLocation.y)
        
        guard elapsed < 0.5 && distance < 5 else { return }
        
        performClick(mouseButton: .left)
    }
    
    override func rightMouseUp(with event: NSEvent) {
        super.rightMouseUp(with: event)
        performClick(mouseButton: .right)
    }
    
    private func performClick(mouseButton: CGMouseButton) {
        // Close panel first
        closePanel()
        
        // Click the menu bar item using scromble mechanism
        Task { @MainActor in
            // Small delay for panel to close
            try? await Task.sleep(for: .milliseconds(50))
            
            do {
                try await EventScrombler.shared.clickItem(item, mouseButton: mouseButton)
            } catch {
                print("[DroppyBar] Click failed: \(error), falling back to activation")
                // Fallback: just activate the app
                item.owningApplication?.activate()
            }
        }
    }
}
