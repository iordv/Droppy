import UniformTypeIdentifiers
import Combine
//
//  FloatingBasketView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

//
//  FloatingBasketView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

// MARK: - Floating Basket View

/// A floating basket view that appears during file drags as an alternative drop zone
struct FloatingBasketView: View {
    /// Per-basket state - each basket is fully independent (multi-basket support)
    @Bindable var basketState: BasketState
    
    /// Accent color for this basket instance (multi-basket visual distinction)
    var accentColor: BasketAccentColor = .teal
    
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.showClipboardButton) private var showClipboardButton = PreferenceDefault.showClipboardButton
    @AppStorage(AppPreferenceKey.enableNotchShelf) private var enableNotchShelf = PreferenceDefault.enableNotchShelf
    @AppStorage(AppPreferenceKey.enableAutoClean) private var enableAutoClean = PreferenceDefault.enableAutoClean
    @AppStorage(AppPreferenceKey.enableQuickActions) private var enableQuickActions = PreferenceDefault.enableQuickActions
    
    // MARK: - Dropover-Style State
    /// Whether the basket is expanded to show the full grid view
    @State private var isExpanded = false
    /// Whether to show list view instead of grid view
    @State private var isListView = false
    
    @State private var dashPhase: CGFloat = 0
    
    /// Dash phase freezes when any zone is targeted (animation pause effect)
    /// BUT NOT when dragging over quick action buttons (they're separate from basket)
    private var effectiveDashPhase: CGFloat {
        (basketState.isTargeted || basketState.isAirDropZoneTargeted) && !basketState.isQuickActionsTargeted ? 0 : dashPhase
    }
    
    // Drag-to-select state
    @State private var isDragSelecting = false
    @State private var dragSelectionStart: CGPoint = .zero
    @State private var dragSelectionCurrent: CGPoint = .zero
    @State private var basketScrollView: NSScrollView?
    @State private var scrollViewportFrame: CGRect = .zero
    @State private var autoScrollVelocity: CGFloat = 0
    private let autoScrollTicker = Timer.publish(every: 1.0 / 90.0, on: .main, in: .common).autoconnect()
    
    // Global rename state
    @State private var renamingItemId: UUID?
    
    /// Owning controller for this basket instance.
    private var ownerController: FloatingBasketWindowController? { basketState.ownerController }

    /// Show accent colors only when at least two baskets are visible.
    private var shouldShowAccentColor: Bool {
        ownerController?.shouldShowAccentColor ?? FloatingBasketWindowController.shouldShowAccentColors
    }

    private var effectiveAccentColor: Color {
        shouldShowAccentColor ? accentColor.color : AdaptiveColors.primaryTextAuto
    }
    
    private let cornerRadius: CGFloat = 28
    
    // Each item is 72pt wide + 12pt spacing (in expanded view)
    // For 4 items: 4 * 72 + 3 * 12 = 288 + 36 = 324, plus 18pt padding each side = 360
    private let itemWidth: CGFloat = 72
    private let itemSpacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 18
    private let columnsPerRow: Int = 4
    
    // AirDrop zone width (30% of total when enabled)
    private let airDropZoneWidth: CGFloat = 90

    private var basketPrimaryTextColor: Color {
        AdaptiveColors.primaryTextAuto
    }

    private var basketSecondaryTextColor: Color {
        AdaptiveColors.secondaryTextAuto
    }
    
    /// Full width for 4-column grid: 4 * 68 + 3 * 12 + 12 * 2 = 272 + 36 + 24 = 360 (expanded only)
    private let fullGridWidth: CGFloat = 360
    
    /// Dynamic height that fits content
    private var currentHeight: CGFloat {
        let slotCount = basketState.items.count
        
        if slotCount == 0 {
            return 228
        } else if isExpanded {
            let rowCount = ceil(Double(slotCount) / Double(columnsPerRow))
            let headerHeight: CGFloat = 44  // Header + top padding
            let bottomPadding: CGFloat = 32 // Symmetrical with left/right 18pt + extra for label clearance
            let itemHeight: CGFloat = 90    // Item with label and padding
            let rowSpacing: CGFloat = 12    // Match actual grid row spacing!
            
            if isListView {
                // List view: 25% taller for 1 row, 50% taller for 2+ rows (with scroll)
                let gridHeightFor1Row = headerHeight + itemHeight + bottomPadding
                let gridHeightFor2Rows = headerHeight + (2 * itemHeight) + rowSpacing + bottomPadding
                
                if rowCount <= 1 {
                    return gridHeightFor1Row * 1.25
                } else {
                    return gridHeightFor2Rows * 1.50  // Fixed height, scroll for more
                }
            } else {
                // Grid view: Max 3 rows, then scroll - CONSISTENT BOTTOM PADDING
                let cappedRowCount = min(rowCount, 3)
                return headerHeight + (cappedRowCount * itemHeight) + (max(0, cappedRowCount - 1) * rowSpacing) + bottomPadding
            }
        } else {
            // Initial/collapsed preview card
            return 270
        }
    }
    
    /// Base width - always use full grid width for proper layout
    private var baseWidth: CGFloat {
        if basketState.items.count == 0 {
            return 246
        } else if isExpanded {
            return fullGridWidth  // Full width when expanded (360)
        } else {
            return 236
        }
    }
    
    /// Total width - simplified for Dropover style (no AirDrop split zone)
    private var currentWidth: CGFloat {
        return baseWidth
    }
    
    // Compute selection rectangle from start/current points
    private var selectionRect: CGRect {
        let minX = min(dragSelectionStart.x, dragSelectionCurrent.x)
        let minY = min(dragSelectionStart.y, dragSelectionCurrent.y)
        let maxX = max(dragSelectionStart.x, dragSelectionCurrent.x)
        let maxY = max(dragSelectionStart.y, dragSelectionCurrent.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // Item frames for drag selection
    @State private var itemFrames: [UUID: CGRect] = [:]
    
    // Hover States for buttons
    @State private var isShelfButtonHovering = false
    @State private var isClipboardButtonHovering = false
    @State private var isSelectAllHovering = false
    @State private var isDropHereHovering = false
    @State private var headerFrame: CGRect = .zero
    
    
    var body: some View {
        ZStack {
            Color.clear
            
            VStack(spacing: 16) {
                mainBasketContainer
                
                // Quick Actions bar (only when quick actions are enabled)
                if enableQuickActions {
                    BasketQuickActionsBar(items: basketState.items, basketState: basketState)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        // MARK: - Auto-Hide Hover Tracking
        .onHover { isHovering in
            if isHovering {
                ownerController?.onBasketHoverEnter()
            } else {
                ownerController?.onBasketHoverExit()
            }
        }
        // MARK: - Keyboard Shortcuts
        .background {
            // Hidden button for Cmd+A select all
            Button("") {
                basketState.selectAllBasketItems()
            }
            .keyboardShortcut("a", modifiers: .command)
            .opacity(0)
        }
        .onReceive(autoScrollTicker) { _ in
            performAutoScrollTick()
        }
        .onChange(of: enableQuickActions) { _, enabled in
            if !enabled {
                basketState.hoveredQuickAction = nil
                basketState.isQuickActionsTargeted = false
            }
        }
    }
    
    private var mainBasketContainer: some View {
        ZStack {
            // Background (extracted to reduce type-checker complexity)
            basketBackground
                .droppyFloatingShadow()
            
            // Content - different views based on state
            // Quick action hover explanation takes priority over regular content
            if let hoveredAction = basketState.hoveredQuickAction {
                quickActionExplanation(for: hoveredAction)
                    .transition(.opacity)
            } else if basketState.items.count == 0 {
                emptyContent
            } else if isExpanded {
                // Expanded grid view with full file list
                expandedGridContent
            } else {
                // Collapsed stacked preview (Dropover-style)
                collapsedStackContent
            }
            
            // Selection rectangle overlay (only in expanded view)
            if isDragSelecting && isExpanded && basketState.hoveredQuickAction == nil {
                selectionRectangleOverlay
            }
            
            // PERSISTENT X BUTTON OVERLAY - stays fixed during all content transitions
            // Only show when NOT expanded (expanded has back button instead)
            // Hide when hovering quick actions (explanation overlay shows instead)
            if !isExpanded && basketState.hoveredQuickAction == nil {
                VStack {
                    HStack {
                        // Close button - always xmark (deletes items and closes)
                        BasketCloseButton(iconName: "xmark", action: closeBasket)
                        Spacer()
                        BasketMenuButton(action: hideBasket)
                            .help("Hide basket")
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    
                    Spacer()
                }
            }
        }
        .frame(width: currentWidth, height: currentHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // 3D PRESSED EFFECT: Scale down when targeted (like button being pushed)
        // CRITICAL: Don't show highlight when dragging over quick action buttons (they handle their own drops)
        .scaleEffect((basketState.isTargeted || basketState.isAirDropZoneTargeted) && !basketState.isQuickActionsTargeted ? 0.97 : 1.0)
        .animation(DroppyAnimation.bouncy, value: basketState.isTargeted)
        .animation(DroppyAnimation.bouncy, value: basketState.isAirDropZoneTargeted)
        // NOTE: Drop handling is managed by the AppKit BasketDragContainer (BasketDragContainer.swift)
        // which properly handles NSFilePromiseReceiver for Photos.app compatibility.
        // Do NOT add .dropDestination here - it causes CoreTransferable errors for file promises.
        .coordinateSpace(name: "basketContainer")
        .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
            self.itemFrames = frames
        }
        .simultaneousGesture(dragSelectionGesture, including: .all)
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                dashPhase -= 280
            }
        }
        .onChange(of: basketState.items.count) { oldCount, newCount in
            if newCount == 0 {
                ownerController?.hideBasket()
            }
        }
        .contextMenu {
            if !basketState.items.isEmpty {
                Button {
                    let basketFrame = ownerController?.basketWindow?.frame
                    ReorderWindowController.shared.show(
                        state: DroppyState.shared,
                        target: .basket,
                        anchorFrame: basketFrame,
                        basketState: basketState,
                        basketController: ownerController
                    )
                } label:{
                    Label("Reorder Items", systemImage: "arrow.up.arrow.down")
                }
            }
            
            Button {
                closeBasket()
            } label: {
                Label("Clear Basket", systemImage: "trash")
            }
            
            Divider()
            
            Button {
                SettingsWindowController.shared.showSettings()
            } label: {
                Label("Open Settings", systemImage: "gear")
            }
        }
    }
    
    private var selectionRectangleOverlay: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.2))
            .overlay(
                Rectangle()
                    .stroke(Color.blue, lineWidth: 1)
            )
            .frame(width: selectionRect.width, height: selectionRect.height)
            .position(x: selectionRect.midX, y: selectionRect.midY)
    }
    
    private var dragSelectionGesture: some Gesture {
        // Keep a low threshold so empty-space clicks can clear selection,
        // but only start marquee selection once movement is intentional.
        DragGesture(minimumDistance: 0, coordinateSpace: .named("basketContainer"))
            .onChanged { value in
                let dragDistance = hypot(
                    value.location.x - value.startLocation.x,
                    value.location.y - value.startLocation.y
                )

                if !isDragSelecting {
                    guard dragDistance >= 6 else { return }

                    // Ignore drags starting in the header (window drag area)
                    if headerFrame.contains(value.startLocation) {
                        return
                    }

                    // Item drags/reordering should stay owned by item-level handlers.
                    guard !isPointOverBasketItem(value.startLocation) else { return }

                    // Start selection
                    isDragSelecting = true
                    ownerController?.beginBasketSelectionDrag()
                    dragSelectionStart = value.startLocation
                    basketState.selectedItems.removeAll()
                }

                guard isDragSelecting else { return }
                dragSelectionCurrent = value.location
                updateAutoScrollVelocity(at: value.location)
                
                // Update selection based on items intersecting the rectangle
                updateSelectionFromRect()
            }
            .onEnded { value in
                let dragDistance = hypot(
                    value.location.x - value.startLocation.x,
                    value.location.y - value.startLocation.y
                )
                autoScrollVelocity = 0
                if isDragSelecting {
                    ownerController?.endBasketSelectionDrag()
                } else if dragDistance < 6,
                          !headerFrame.contains(value.startLocation),
                          !isPointOverBasketItem(value.startLocation) {
                    clearBasketSelectionAndRenameState()
                }
                isDragSelecting = false
            }
    }

    private func isPointOverBasketItem(_ point: CGPoint) -> Bool {
        itemFrames.values.contains { frame in
            frame.insetBy(dx: -2, dy: -2).contains(point)
        }
    }
    
    private func updateSelectionFromRect() {
        let newSelection = Set(
            itemFrames.compactMap { id, frame in
                selectionRect.intersects(frame) ? id : nil
            }
        )
        if newSelection != basketState.selectedItems {
            basketState.selectedItems = newSelection
        }
    }

    private func updateAutoScrollVelocity(at location: CGPoint) {
        guard isExpanded, isDragSelecting else {
            autoScrollVelocity = 0
            return
        }
        guard scrollViewportFrame != .zero else {
            autoScrollVelocity = 0
            return
        }

        let threshold: CGFloat = 40
        let topEdge = scrollViewportFrame.minY + threshold
        let bottomEdge = scrollViewportFrame.maxY - threshold

        if location.y < topEdge {
            let distance = min(topEdge - location.y, threshold)
            autoScrollVelocity = -(distance / threshold)
        } else if location.y > bottomEdge {
            let distance = min(location.y - bottomEdge, threshold)
            autoScrollVelocity = distance / threshold
        } else {
            autoScrollVelocity = 0
        }
    }

    private func performAutoScrollTick() {
        guard isExpanded, isDragSelecting else { return }
        guard autoScrollVelocity != 0 else { return }
        guard scrollViewportFrame != .zero, let scrollView = basketScrollView else { return }
        guard let documentView = scrollView.documentView else { return }

        let minStep: CGFloat = 4
        let maxStep: CGFloat = 12
        let logicalDelta = autoScrollVelocity * (minStep + (maxStep - minStep) * abs(autoScrollVelocity))
        // NSScrollView coordinate direction depends on document view flipping.
        let deltaY = documentView.isFlipped ? logicalDelta : -logicalDelta

        let clipView = scrollView.contentView
        let currentY = clipView.bounds.origin.y
        let maxY = max(0, documentView.bounds.height - clipView.bounds.height)
        let newY = min(max(currentY + deltaY, 0), maxY)

        guard abs(newY - currentY) > 0.5 else {
            autoScrollVelocity = 0
            return
        }
        clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: newY))
        scrollView.reflectScrolledClipView(clipView)
        updateSelectionFromRect()
    }
    
    /// Basket background - Dropover style: clean dark container with subtle border
    /// Supports transparency mode: glass material when enabled, solid dark when disabled
    @ViewBuilder
    private var basketBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .droppyTransparentFill(useTransparentBackground)
            .frame(width: currentWidth, height: currentHeight)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        AdaptiveColors.overlayAuto(0.12),
                        lineWidth: 1
                    )
            )
            // Sleek drag handle at top.
            // Keep it visible for empty baskets too so newly created blank baskets
            // can still be repositioned immediately.
            .overlay(alignment: .top) {
                BasketDragHandle(
                    controller: ownerController,
                    accentColor: accentColor,
                    showAccentColor: shouldShowAccentColor
                )
            }
            // Pressed effect when targeted (scale is handled by mainBasketContainer)
            .overlay(
                Group {
                    if basketState.isTargeted {
                        // Accent-colored glow when file is being dragged over
                        RoundedRectangle(cornerRadius: cornerRadius - 4, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [effectiveAccentColor.opacity(0.4), effectiveAccentColor.opacity(0.15)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                            .padding(DroppySpacing.sm)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: basketState.isTargeted)
            )
    }
    
    @ViewBuilder
    private var emptyContent: some View {
        // Dropover-style empty state with "Drop files here" text - PERFECTLY CENTERED
        // X button is now handled by persistent overlay in mainBasketContainer
        VStack {
            Spacer()
            Text("Drop files here")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AdaptiveColors.secondaryTextAuto.opacity(0.88))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Explanation overlay shown when hovering over quick action buttons
    /// X button is handled by persistent overlay in mainBasketContainer
    @ViewBuilder
    private func quickActionExplanation(for action: QuickActionType) -> some View {
        ZStack {
            // Opaque background to hide content underneath
            // Must match basket background style (material for transparent, black for solid)
            if useTransparentBackground {
                Rectangle().droppyGlassFill()
            } else {
                Rectangle().fill(AdaptiveColors.panelBackgroundAuto)
            }
            
            // Centered description text
            Text(action.description)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AdaptiveColors.secondaryTextAuto.opacity(0.88))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var itemsContent: some View {
        VStack(spacing: 8) {
            // Header toolbar (extracted for type-checker)
            basketHeaderToolbar
            
            // Items grid - wrapped in ZStack with background tap handler for deselection
            basketItemsGrid
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Dropover-Style Collapsed Content
    
    /// Collapsed stacked preview matching Dropover exactly
    /// X button and menu are handled by persistent overlay in mainBasketContainer
    private var collapsedStackContent: some View {
        let expandToGrid = {
            withAnimation(DroppyAnimation.basketTransition) {
                isListView = false
                isExpanded = true
            }
        }

        return VStack(spacing: 0) {
            Spacer(minLength: 52)

            // Stacked thumbnail preview - draggable for all files, tappable to expand
            DraggableArea(
                items: {
                    // Provide all basket item URLs for drag
                    basketState.items.map { $0.url as NSURL }
                },
                onTap: { _ in
                    // Tap always opens grid view.
                    expandToGrid()
                },
                onRightClick: {
                    // No right-click action for stack preview
                },
                onDragComplete: { [weak basketState] _ in
                    // Auto-clean after drag if enabled
                    guard let basketState = basketState else { return }
                    let enableAutoClean = UserDefaults.standard.bool(forKey: AppPreferenceKey.enableAutoClean)
                    if enableAutoClean {
                        withAnimation(DroppyAnimation.state) {
                            basketState.clearAll()
                        }
                    }
                },
                selectionSignature: basketState.items.map(\.id).hashValue
            ) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    BasketStackPreviewView(items: basketState.items)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150, alignment: .center)

            Spacer(minLength: 10)

            BasketFileCountLabel(items: basketState.items, isHovering: false, action: expandToGrid)
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    // MARK: - Dropover-Style Expanded Content
    
    /// Expanded content - shows grid or list view based on toggle
    private var expandedGridContent: some View {
        VStack(spacing: 0) {
            // Expanded header with back button and info
            expandedHeader
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 6)
            
            // Items - grid or list view
            if isListView {
                basketListView
            } else {
                basketItemsGrid
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    /// Header for expanded view with back button, title, size, and view toggles
    private var expandedHeader: some View {
        HStack(spacing: 12) {
            // Back button to collapse
            BasketBackButton {
                withAnimation(DroppyAnimation.basketTransition) {
                    isExpanded = false
                }
            }
            
            // Title and size info
            VStack(alignment: .leading, spacing: 2) {
                Text(expandedTitleText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(basketPrimaryTextColor)
                
                Text(totalFileSizeText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(basketSecondaryTextColor)
            }
            
            Spacer()
            
            // View toggle buttons (grid/list)
            HStack(spacing: 8) {
                
                // Grid view button
                Button {
                    withAnimation(DroppyAnimation.state) {
                        isListView = false
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 32))
                .opacity(isListView ? 0.6 : 1.0)
                
                // List view button
                Button {
                    withAnimation(DroppyAnimation.state) {
                        isListView = true
                    }
                } label: {
                    Image(systemName: "list.bullet")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 32))
                .opacity(isListView ? 1.0 : 0.6)
            }
        }
    }
    
    /// Title text for expanded header (e.g., "4 Images")
    private var expandedTitleText: String {
        let count = basketState.items.count
        let allImages = basketState.items.allSatisfy { $0.fileType?.conforms(to: .image) == true }
        
        if allImages {
            return "\(count) \(count == 1 ? "Image" : "Images")"
        } else {
            return "\(count) \(count == 1 ? "File" : "Files")"
        }
    }
    
    /// Total file size text for expanded header
    private var totalFileSizeText: String {
        var totalBytes: Int64 = 0
        for item in basketState.items {
            if let resourceValues = try? item.url.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                totalBytes += Int64(size)
            }
        }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    /// Context menu content for the basket menu button
    @ViewBuilder
    private var basketContextMenuContent: some View {
        Button {
            // Show all files in Finder
            let urls = basketState.items.map(\.url)
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }
        
        Button {
            // Quick Look
            QuickLookHelper.shared.preview(urls: basketState.items.map(\.url))
        } label: {
            Label("Quick Look", systemImage: "eye")
        }
        
        Divider()
        
        // Share menu
        if let shareService = NSSharingService(named: .sendViaAirDrop) {
            Button {
                shareService.perform(withItems: basketState.items.map(\.preferredShareURL))
            } label: {
                Label("AirDrop", systemImage: "airplayaudio")
            }
        }
        
        Button {
            _ = MailHelper.composeEmail(with: basketState.items.map(\.url))
        } label: {
            Label("Mail", systemImage: "envelope.fill")
        }
        
        Button {
            if let messagesService = NSSharingService(named: .composeMessage) {
                messagesService.perform(withItems: basketState.items.map(\.preferredShareURL))
            }
        } label: {
            Label("Messages", systemImage: "message.fill")
        }
        
        Menu("More") {
            ForEach(sharingServicesForItems(basketState.items.map(\.preferredShareURL)), id: \.title) { service in
                Button {
                    service.perform(withItems: basketState.items.map(\.preferredShareURL))
                } label: {
                    Text(service.title)
                }
            }
        }
        
        Divider()
        
        Button {
            // Copy Droppy link (placeholder - could copy file paths)
            let paths = basketState.items.map(\.url.path).joined(separator: "\n")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(paths, forType: .string)
        } label: {
            Label("Copy File Paths", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(role: .destructive) {
            closeBasket()
        } label: {
            Label("Clear Basket", systemImage: "trash")
        }
    }
    
    @ViewBuilder
    private var basketHeaderToolbar: some View {
        HStack {
            Text("\(basketState.items.count) item\(basketState.items.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Move to shelf button (only when shelf is enabled)
            if enableNotchShelf {
                Button {
                    moveToShelf()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.to.line")
                        Text("To Shelf")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
            }
            
            // Clipboard button (optional)
            if showClipboardButton {
                Button {
                    ClipboardWindowController.shared.toggle()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 32))
            }
            
            // Quick Actions buttons (extracted for type-checker)
            quickActionsButtons
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 22)
        .background(WindowDragHandle())
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        headerFrame = proxy.frame(in: .named("basketContainer"))
                    }
                    .onChange(of: proxy.frame(in: .named("basketContainer"))) { _, newFrame in
                        headerFrame = newFrame
                    }
            }
        )
    }
    
    @ViewBuilder
    private var quickActionsButtons: some View {
        if enableQuickActions {
            let allSelected = !basketState.items.isEmpty && basketState.selectedItems.count == basketState.items.count
            
            if allSelected {
                // Add All button - copies all files to Finder folder
                Button {
                    dropSelectedToFinder()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add All")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .green, size: .small))
                .help("Copy all to Finder folder")
            } else {
                // Select All button
                Button {
                    basketState.selectedItems = Set(basketState.items.map(\.id))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Select All")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                .help("Select All (⌘A)")
            }
        }
    }
    
    private var basketItemsGrid: some View {
        ScrollView {
            ZStack(alignment: .top) {
                // Background spacer keeps the ZStack's full hit region.
                Color.clear
                    .contentShape(Rectangle())
                
                // Items grid using LazyVGrid for efficient rendering
                let columns = Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnsPerRow)
                
                LazyVGrid(columns: columns, spacing: 12) {  // Match column spacing
                    // Power Folders first (always distinct, never stacked)
                    ForEach(basketState.powerFolders) { folder in
                        BasketItemView(item: folder, state: basketState, renamingItemId: $renamingItemId) {
                            basketState.powerFolders.removeAll { $0.id == folder.id }
                        }
                        .transition(basketState.isBulkUpdating ? .identity : .opacity)
                    }
                    
                    // Regular items - flat display
                    ForEach(basketState.itemsList) { item in
                        BasketItemView(item: item, state: basketState, renamingItemId: $renamingItemId) {
                            basketState.removeItem(item)
                        }
                        .transition(basketState.isBulkUpdating ? .identity : .opacity)
                    }
                }
                .transaction { transaction in
                    if basketState.isBulkUpdating {
                        transaction.animation = nil
                    }
                }
                .animation(basketState.isBulkUpdating ? nil : DroppyAnimation.basketTransition, value: basketState.itemsList.count)
                .animation(basketState.isBulkUpdating ? nil : DroppyAnimation.basketTransition, value: basketState.powerFolders.count)
                .background(ScrollViewResolver { scrollView in
                    self.basketScrollView = scrollView
                })
            }
            .frame(maxWidth: .infinity, minHeight: max(scrollViewportFrame.height, 1), alignment: .top)
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 18)
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        scrollViewportFrame = proxy.frame(in: .named("basketContainer"))
                    }
                    .onChange(of: proxy.frame(in: .named("basketContainer"))) { _, newFrame in
                        scrollViewportFrame = newFrame
                    }
            }
        )
    }
    
    /// List view for basket items - uses same BasketItemView with list layout for full feature parity
    private var basketListView: some View {
        ScrollView {
            ZStack(alignment: .top) {
                Color.clear
                    .contentShape(Rectangle())

                LazyVStack(spacing: 4) {
                    // Power Folders first
                    ForEach(basketState.powerFolders) { folder in
                        BasketItemView(
                            item: folder,
                            state: basketState,
                            renamingItemId: $renamingItemId,
                            onRemove: {
                                basketState.powerFolders.removeAll { $0.id == folder.id }
                            },
                            layoutMode: .list,
                            listRowWidth: fullGridWidth - (horizontalPadding * 2)  // CRITICAL: Fixed width for text truncation
                        )
                    }
                    
                    // Regular items - flat display (no stacks)
                    ForEach(basketState.itemsList) { item in
                        BasketItemView(
                            item: item,
                            state: basketState,
                            renamingItemId: $renamingItemId,
                            onRemove: {
                                basketState.removeItem(item)
                            },
                            layoutMode: .list,
                            listRowWidth: fullGridWidth - (horizontalPadding * 2)  // CRITICAL: Fixed width for text truncation
                        )
                    }
                }
                .transaction { transaction in
                    if basketState.isBulkUpdating {
                        transaction.animation = nil
                    }
                }
                .animation(basketState.isBulkUpdating ? nil : DroppyAnimation.basketTransition, value: basketState.itemsList.count)
                .animation(basketState.isBulkUpdating ? nil : DroppyAnimation.basketTransition, value: basketState.powerFolders.count)
                .background(ScrollViewResolver { scrollView in
                    self.basketScrollView = scrollView
                })
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, minHeight: max(scrollViewportFrame.height, 1), alignment: .top)
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        scrollViewportFrame = proxy.frame(in: .named("basketContainer"))
                    }
                    .onChange(of: proxy.frame(in: .named("basketContainer"))) { _, newFrame in
                        scrollViewportFrame = newFrame
                    }
            }
        )
        // CRITICAL: Set FIXED width (not max) to force all children to respect bounds
        .frame(width: fullGridWidth)
        // Note: Drop destination handled at container level (mainBasketContainer)
    }

    private func moveToShelf() {
        // Transfer items from basket to shelf (flat, no stacks)
        var itemsToMove: [DroppedItem] = []
        var powerFoldersToMove: [DroppedItem] = []
        
        if basketState.selectedItems.isEmpty {
            // No selection - move ALL items and power folders
            itemsToMove = basketState.itemsList
            powerFoldersToMove = basketState.powerFolders
        } else {
            // Move selected items
            itemsToMove = basketState.itemsList.filter { basketState.selectedItems.contains($0.id) }
            powerFoldersToMove = basketState.powerFolders.filter { basketState.selectedItems.contains($0.id) }
        }

        DroppyState.shared.beginBulkUpdateIfNeeded(itemsToMove.count + powerFoldersToMove.count)
        
        // Collect items that will be moved (to remove after adding)
        var movedItems: [DroppedItem] = []
        var movedFolders: [DroppedItem] = []
        
        // Transfer power folders to shelf (distinct, never grouped)
        for folder in powerFoldersToMove {
            // Avoid duplicates
            guard !DroppyState.shared.shelfPowerFolders.contains(where: { $0.url == folder.url }) else { continue }
            DroppyState.shared.shelfPowerFolders.append(folder)
            movedFolders.append(folder)
        }
        
        // Transfer items to shelf
        let existingShelfURLs = Set(DroppyState.shared.shelfItems.map { $0.url })
        
        for item in itemsToMove {
            // Avoid duplicates
            guard !existingShelfURLs.contains(item.url) else { continue }
            DroppyState.shared.shelfItems.append(item)
            movedItems.append(item)
        }
        
        // Remove moved items from basket AFTER adding them all to shelf
        // This prevents disrupting the iteration with @Published array updates
        for folder in movedFolders {
            basketState.powerFolders.removeAll { $0.id == folder.id }
        }
        for item in movedItems {
            basketState.removeItemForTransfer(item)
        }
        
        basketState.selectedItems.removeAll()
        
        // PREMIUM: Haptic confirms items moved to shelf
        if !itemsToMove.isEmpty || !powerFoldersToMove.isEmpty {
            HapticFeedback.drop()
        }
        
        // Auto-expand shelf on the CORRECT screen:
        // Priority order:
        // 1. If a shelf is already expanded on any screen, use that screen
        // 2. Use the screen where the BASKET WINDOW is located (most reliable)
        // 3. Use the screen where the mouse is currently located
        // 4. Fall back to main screen only as last resort
        if !itemsToMove.isEmpty || !powerFoldersToMove.isEmpty {
            let targetDisplayID: CGDirectDisplayID
            
            if let currentExpandedDisplayID = DroppyState.shared.expandedDisplayID {
                // Use the screen where the shelf is already expanded
                targetDisplayID = currentExpandedDisplayID
            } else if let basketWindow = ownerController?.basketWindow,
                      let basketScreen = basketWindow.screen {
                // Use the screen where the basket window is displayed
                // This is the most reliable way since the user is interacting with the basket
                targetDisplayID = basketScreen.displayID
            } else {
                // Fallback: Find screen containing mouse using flipped coordinates
                let mouseLocation = NSEvent.mouseLocation
                var foundScreen: NSScreen?
                
                for screen in NSScreen.screens {
                    // NSEvent.mouseLocation uses bottom-left origin, same as NSScreen.frame
                    if screen.frame.contains(mouseLocation) {
                        foundScreen = screen
                        break
                    }
                }
                
                if let mouseScreen = foundScreen {
                    targetDisplayID = mouseScreen.displayID
                } else if let mainScreen = NSScreen.main {
                    // Last resort: main screen
                    targetDisplayID = mainScreen.displayID
                } else {
                    return
                }
            }
            
            withAnimation(DroppyAnimation.interactive) {
                DroppyState.shared.expandShelf(for: targetDisplayID)
            }
        }
        
        // Hide basket if empty after move
        if basketState.items.isEmpty {
            ownerController?.hideBasket()
        }
    }

    private func closeBasket() {
        // Close button always clears items and closes the basket
        basketState.clearAll()
        ownerController?.hideBasket()
    }
    
    /// Hides the basket without clearing items (used in multi-basket mode)
    /// Items remain accessible via the basket switcher
    private func hideBasket() {
        ownerController?.hideBasketPreservingState()
    }

    private func dropSelectedToFinder() {
        guard let finderFolder = FinderFolderDetector.getCurrentFinderFolder() else {
            // Show notification that no Finder folder is open
            DroppyAlertController.shared.showSimple(
                style: .info,
                title: "No Finder folder open",
                message: "Open a Finder window to drop files into"
            )
            return
        }
        
        // Get selected items
        let selectedItems = basketState.items.filter { basketState.selectedItems.contains($0.id) }
        guard !selectedItems.isEmpty else { return }
        
        // Copy files to finder folder
        let urls = selectedItems.map { $0.url }
        let copied = FinderFolderDetector.copyFiles(urls, to: finderFolder)
        
        if copied > 0 {
            // Remove from basket
            for item in selectedItems {
                basketState.removeItem(item)
            }
            
            // Show confirmation
            DroppyAlertController.shared.showSimple(
                style: .info,
                title: "Copied \(copied) file\(copied == 1 ? "" : "s")",
                message: "to \(finderFolder.lastPathComponent)"
            )
        }
        
        // Hide basket if empty
        if basketState.items.isEmpty {
            ownerController?.hideBasket()
        }
    }

    private func clearBasketSelectionAndRenameState() {
        basketState.selectedItems.removeAll()
        if renamingItemId != nil {
            basketState.isRenaming = false
            DroppyState.shared.endFileOperation()
        }
        renamingItemId = nil
    }
}

private struct ScrollViewResolver: NSViewRepresentable {
    let onResolve: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            resolveScrollView(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            resolveScrollView(from: nsView)
        }
    }

    private func resolveScrollView(from view: NSView) {
        var current: NSView? = view
        while let candidate = current {
            if let scroll = candidate.enclosingScrollView {
                onResolve(scroll)
                return
            }
            current = candidate.superview
        }
    }
}


// MARK: - Rename Text Field with Auto-Select and Animated Dotted Border
private struct RenameTextField: View {
    @Binding var text: String
    @Binding var isRenaming: Bool
    let onRename: () -> Void
    
    var body: some View {
        AutoSelectTextField(
            text: $text,
            onSubmit: onRename,
            onCancel: { isRenaming = false }
        )
        .font(.system(size: 11, weight: .medium))
        .frame(width: 72)
        .droppyTextInputChrome(
            cornerRadius: DroppyRadius.ml,
            horizontalPadding: 8,
            verticalPadding: 5
        )
    }
}

// MARK: - Auto-Select Text Field (NSViewRepresentable)
private struct AutoSelectTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.textColor = .labelColor
        textField.font = .systemFont(ofSize: 11, weight: .medium)
        textField.alignment = .center
        textField.focusRingType = .none
        textField.stringValue = text
        
        // Make it the first responder and select all text after a brief delay
        // For non-activating panels, we need special handling to make them accept keyboard input
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = textField.window as? NSPanel else { return }
            
            // Temporarily allow the panel to become key window
            window.becomesKeyOnlyIfNeeded = false
            
            // CRITICAL: Activate the app itself - this is what makes the selection blue vs grey
            NSApp.activate(ignoringOtherApps: true)
            
            // Make the window key and order it front to accept keyboard input
            window.makeKeyAndOrderFront(nil)
            
            // Now make the text field first responder
            window.makeFirstResponder(textField)
            
            // Select all text
            textField.selectText(nil)
            if let editor = textField.currentEditor() {
                editor.selectedRange = NSRange(location: 0, length: textField.stringValue.count)
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if text changed externally
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: AutoSelectTextField
        
        init(_ parent: AutoSelectTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Enter pressed - submit
                parent.onSubmit()
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Escape pressed - cancel
                parent.onCancel()
                return true
            }
            return false
        }
    }
}
