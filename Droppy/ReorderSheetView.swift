//
//  ReorderSheetView.swift
//  Droppy
//
//  Created by Jordy Spruit on 05/02/2026.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Reorder Target

enum ReorderTarget {
    case shelf
    case basket
}

// MARK: - Reorder Sheet View

/// A native Droppy overlay for reordering shelf or basket items via drag-and-drop list interface
struct ReorderSheetView: View {
    @Bindable var state: DroppyState
    @Binding var isPresented: Bool
    var target: ReorderTarget = .shelf
    var basketState: BasketState? = nil
    
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    
    /// Local copy of items for reordering (applied on Done)
    @State private var reorderableItems: [DroppedItem] = []
    
    /// Currently dragging item
    @State private var draggingItem: DroppedItem?
    
    private var sourceItems: [DroppedItem] {
        switch target {
        case .shelf: state.shelfItems
        case .basket: basketState?.items ?? FloatingBasketWindowController.shared.basketState.items
        }
    }
    
    private var title: String {
        switch target {
        case .shelf: "Reorder Shelf"
        case .basket: "Reorder Basket"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
                .padding(.horizontal, DroppySpacing.xxl)
            
            // Scrollable list of items
            if reorderableItems.isEmpty {
                emptyState
            } else {
                itemsList
            }
            
            Divider()
                .padding(.horizontal, DroppySpacing.xxl)
            
            // Footer with actions
            footer
        }
        .frame(minWidth: 340, idealWidth: 400, maxWidth: 500)  // 2-column width
        .frame(minHeight: 400, idealHeight: 500, maxHeight: 700)  // Taller default
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .onAppear {
            reorderableItems = sourceItems
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text("\(reorderableItems.count) items")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DroppySpacing.xxl)
        .padding(.vertical, DroppySpacing.lg)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: DroppySpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No items to reorder")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, DroppySpacing.huge)
    }
    
    // MARK: - Items List (2-Column Grid)
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: DroppySpacing.md),
        GridItem(.flexible(), spacing: DroppySpacing.md)
    ]
    
    private var itemsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: gridColumns, spacing: DroppySpacing.smd) {
                ForEach(reorderableItems) { item in
                    ReorderableGridItem(
                        item: item,
                        isDragging: draggingItem?.id == item.id
                    )
                    .onDrag {
                        withAnimation(DroppyAnimation.bouncy) {
                            draggingItem = item
                        }
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: ReorderDropDelegateSheet(
                        item: item,
                        items: $reorderableItems,
                        draggingItem: $draggingItem
                    ))
                }
                .animation(DroppyAnimation.bouncy, value: reorderableItems.map(\.id))
            }
            .padding(.horizontal, DroppySpacing.lg)
            .padding(.vertical, DroppySpacing.md)
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(spacing: 8) {
            // Cancel button - pill style (secondary, left)
            Button {
                isPresented = false
            } label: {
                Text("Cancel")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            // Done button - accent style (primary, right)
            Button {
                // Apply new order to state based on target
                switch target {
                case .shelf:
                    state.shelfItems = reorderableItems
                case .basket:
                    if let basketState {
                        basketState.items = reorderableItems
                    } else {
                        FloatingBasketWindowController.shared.basketState.items = reorderableItems
                    }
                }
                isPresented = false
            } label: {
                Text("Done")
            }
            .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
        }
        .padding(DroppySpacing.lg)
    }
}

// MARK: - Reorderable Item Row

struct ReorderableItemRow: View {
    let item: DroppedItem
    let isDragging: Bool
    var isDropTarget: Bool = false
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: DroppySpacing.md) {
            // Drag handle - animated opacity when dragging
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary.opacity(isDragging ? 0.3 : 0.6))
                .scaleEffect(isDragging ? 1.1 : 1.0)
            
            // Thumbnail
            thumbnailView
            
            // Name and type
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if item.isDirectory {
                    Text("Folder")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if !item.url.pathExtension.isEmpty {
                    Text(item.url.pathExtension.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, DroppySpacing.md)
        .padding(.vertical, DroppySpacing.smd)
        .background(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .fill(AdaptiveColors.overlayAuto(backgroundOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .stroke(strokeColor, lineWidth: isDropTarget ? 1.5 : 1)
        )
        // Lift effect when dragging
        .opacity(isDragging ? 0.6 : 1.0)
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .shadow(color: .black.opacity(isDragging ? 0.3 : 0), radius: 8, y: 4)
        .zIndex(isDragging ? 100 : 0)
        // Smooth animations
        .animation(DroppyAnimation.bouncy, value: isDragging)
        .animation(DroppyAnimation.hoverQuick, value: isHovering)
        .animation(DroppyAnimation.hover, value: isDropTarget)
        .onHover { hovering in
            isHovering = hovering
        }
        .contentShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .task {
            await loadThumbnail()
        }
    }
    
    private var backgroundOpacity: Double {
        if isDragging {
            return 0.15
        } else if isDropTarget {
            return 0.10
        } else if isHovering {
            return 0.08
        } else {
            return 0.04
        }
    }
    
    private var strokeColor: Color {
        if isDropTarget {
            return .blue.opacity(0.5)
        } else if isHovering {
            return .white.opacity(0.10)
        } else {
            return .white.opacity(0.05)
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                .fill(AdaptiveColors.overlayAuto(0.04))
        )
    }
    
    private func loadThumbnail() async {
        if let cached = ThumbnailCache.shared.cachedThumbnail(for: item) {
            thumbnail = cached
        } else if let asyncThumbnail = await ThumbnailCache.shared.loadThumbnailAsync(for: item, size: CGSize(width: 56, height: 56)) {
            withAnimation(DroppyAnimation.hover) {
                thumbnail = asyncThumbnail
            }
        }
    }
}

// MARK: - Reorderable Grid Item (2-Column)

struct ReorderableGridItem: View {
    let item: DroppedItem
    let isDragging: Bool
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: DroppySpacing.smd) {
            // Compact thumbnail
            ZStack {
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AdaptiveColors.overlayAuto(0.04))
            )
            
            // Name (single line)
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 40)  // Very compact
        .padding(.horizontal, DroppySpacing.smd)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AdaptiveColors.overlayAuto(backgroundOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(isHovering ? 0.12 : 0.06), lineWidth: 1)
        )
        // Lift effect when dragging
        .opacity(isDragging ? 0.6 : 1.0)
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .shadow(color: .black.opacity(isDragging ? 0.25 : 0), radius: 6, y: 3)
        .zIndex(isDragging ? 100 : 0)
        // Smooth animations
        .animation(DroppyAnimation.bouncy, value: isDragging)
        .animation(DroppyAnimation.hoverQuick, value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .contentShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .task {
            await loadThumbnail()
        }
    }
    
    private var backgroundOpacity: Double {
        if isDragging {
            return 0.15
        } else if isHovering {
            return 0.08
        } else {
            return 0.04
        }
    }
    
    private func loadThumbnail() async {
        if let cached = ThumbnailCache.shared.cachedThumbnail(for: item) {
            thumbnail = cached
        } else if let asyncThumbnail = await ThumbnailCache.shared.loadThumbnailAsync(for: item, size: CGSize(width: 96, height: 96)) {
            withAnimation(DroppyAnimation.hover) {
                thumbnail = asyncThumbnail
            }
        }
    }
}

// MARK: - Reorder Drop Delegate

struct ReorderDropDelegateSheet: DropDelegate {
    let item: DroppedItem
    @Binding var items: [DroppedItem]
    @Binding var draggingItem: DroppedItem?
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem,
              dragging.id != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == dragging.id }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        withAnimation(DroppyAnimation.bouncy) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Reorder Window Controller

class ReorderWindowController {
    static let shared = ReorderWindowController()
    
    private var window: NSPanel?
    private var currentTarget: ReorderTarget?
    private weak var hiddenBasketController: FloatingBasketWindowController?
    
    private init() {}
    
    /// Show reorder sheet positioned relative to an anchor
    /// - Parameters:
    ///   - state: The DroppyState
    ///   - target: .shelf or .basket
    ///   - anchorFrame: Screen-space frame of the anchor element (shelf or basket window frame)
    @MainActor
    func show(
        state: DroppyState,
        target: ReorderTarget,
        anchorFrame: NSRect? = nil,
        basketState: BasketState? = nil,
        basketController: FloatingBasketWindowController? = nil
    ) {
        // Dismiss any existing window
        dismiss()
        
        // Store target for dismiss logic
        self.currentTarget = target
        self.hiddenBasketController = nil
        
        // Hide basket while reordering (cleaner than z-fighting)
        if target == .basket {
            let controllerToHide = basketController ?? FloatingBasketWindowController.shared
            self.hiddenBasketController = controllerToHide
            controllerToHide.basketWindow?.orderOut(nil)
        }
        
        var isPresented = true
        let isPresentedBinding = Binding(
            get: { isPresented },
            set: { [weak self] newValue in
                isPresented = newValue
                if !newValue {
                    self?.dismiss()
                }
            }
        )
        
        let reorderView = ReorderSheetView(
            state: state,
            isPresented: isPresentedBinding,
            target: target,
            basketState: basketState
        )
        
        let hostingView = NSHostingView(rootView: reorderView)
        hostingView.setFrameSize(hostingView.fittingSize)
        
        let contentSize = hostingView.fittingSize
        let panelWidth = contentSize.width
        let panelHeight = contentSize.height
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Hide titlebar but keep resize functionality
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Size constraints for resizing (match SwiftUI frame)
        panel.minSize = NSSize(width: 340, height: 400)
        panel.maxSize = NSSize(width: 500, height: 700)
        
        // Position based on target and anchor
        if let anchor = anchorFrame {
            switch target {
            case .shelf:
                // Centered BELOW the shelf (anchor is at top of screen)
                let x = anchor.midX - (panelWidth / 2)
                let y = anchor.minY - panelHeight - 12  // 12pt gap below shelf
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            case .basket:
                // Centered ON the basket (panel midpoint aligns with basket midpoint)
                let x = anchor.midX - (panelWidth / 2)
                let y = anchor.midY - (panelHeight / 2)  // Centered on basket
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        } else {
            panel.center()
        }
        
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu  // High enough to be above basket/shelf
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = false
        
        panel.contentView = hostingView
        
        self.window = panel
        
        // PREMIUM: Start scaled down and invisible for spring animation
        panel.alphaValue = 0
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
            contentView.layer?.opacity = 0
        }
        
        panel.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
        
        // PREMIUM: CASpringAnimation for bouncy appear
        if let layer = panel.contentView?.layer {
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 0
            fadeAnim.toValue = 1
            fadeAnim.duration = 0.2
            fadeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fadeAnim.fillMode = .forwards
            fadeAnim.isRemovedOnCompletion = false
            layer.add(fadeAnim, forKey: "fadeIn")
            layer.opacity = 1
            
            let scaleAnim = CASpringAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.85
            scaleAnim.toValue = 1.0
            scaleAnim.mass = 1.0
            scaleAnim.stiffness = 280
            scaleAnim.damping = 20
            scaleAnim.initialVelocity = 8
            scaleAnim.duration = scaleAnim.settlingDuration
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            layer.add(scaleAnim, forKey: "scaleSpring")
            layer.transform = CATransform3DIdentity
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        })
    }
    
    func dismiss() {
        window?.close()
        window = nil
        
        // Restore basket if we were reordering basket items
        if currentTarget == .basket {
            if let hiddenBasketController {
                hiddenBasketController.basketWindow?.orderFront(nil)
            } else {
                FloatingBasketWindowController.shared.basketWindow?.orderFront(nil)
            }
        }
        hiddenBasketController = nil
        currentTarget = nil
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        ReorderSheetView(
            state: DroppyState.shared,
            isPresented: .constant(true)
        )
    }
}
