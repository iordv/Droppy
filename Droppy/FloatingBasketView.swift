import UniformTypeIdentifiers
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
    @Bindable var state: DroppyState
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.showClipboardButton) private var showClipboardButton = PreferenceDefault.showClipboardButton
    @AppStorage(AppPreferenceKey.enableNotchShelf) private var enableNotchShelf = PreferenceDefault.enableNotchShelf
    @AppStorage(AppPreferenceKey.enableAutoClean) private var enableAutoClean = PreferenceDefault.enableAutoClean
    @AppStorage(AppPreferenceKey.enableAirDropZone) private var enableAirDropZone = PreferenceDefault.enableAirDropZone
    @AppStorage(AppPreferenceKey.enableQuickActions) private var enableQuickActions = PreferenceDefault.enableQuickActions
    
    // MARK: - Dropover-Style State
    /// Whether the basket is expanded to show the full grid view
    @State private var isExpanded = false
    /// Hover state for the file count label
    @State private var isFileLabelHovering = false
    /// Whether to show list view instead of grid view
    @State private var isListView = false
    
    @State private var dashPhase: CGFloat = 0
    
    /// Dash phase freezes when any zone is targeted (animation pause effect)
    /// BUT NOT when dragging over quick action buttons (they're separate from basket)
    private var effectiveDashPhase: CGFloat {
        (state.isBasketTargeted || state.isAirDropZoneTargeted) && !state.isQuickActionsTargeted ? 0 : dashPhase
    }
    
    // Drag-to-select state
    @State private var isDragSelecting = false
    @State private var dragSelectionStart: CGPoint = .zero
    @State private var dragSelectionCurrent: CGPoint = .zero
    
    // Global rename state
    @State private var renamingItemId: UUID?
    
    private let cornerRadius: CGFloat = 28
    
    // Each item is 64pt wide + 12pt spacing
    // For 4 items: 4 * 64 + 3 * 12 = 256 + 36 = 292, plus 12pt padding each side = 316
    private let itemWidth: CGFloat = 64
    private let itemSpacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 12
    private let columnsPerRow: Int = 4
    
    // AirDrop zone width (30% of total when enabled)
    private let airDropZoneWidth: CGFloat = 90
    
    /// Full width for 4-column grid: 4 * 64 + 3 * 12 + 12 * 2 = 256 + 36 + 24 = 316
    private let fullGridWidth: CGFloat = 316
    
    /// Dynamic height that fits content
    private var currentHeight: CGFloat {
        let slotCount = state.basketDisplaySlotCount
        
        if slotCount == 0 {
            return 260  // Empty basket - SAME size as collapsed
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
            // Collapsed stacked preview - same as empty
            return 260
        }
    }
    
    /// Base width - always use full grid width for proper layout
    private var baseWidth: CGFloat {
        if state.basketDisplaySlotCount == 0 {
            return 240  // Empty state width - SAME as collapsed
        } else if isExpanded {
            return fullGridWidth  // Full width when expanded
        } else {
            return 240  // Collapsed width - same as empty
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
                
                // Quick Actions bar - ALWAYS visible when basket appears
                // Users can drag files directly onto action buttons for quick share
                BasketQuickActionsBar(items: state.basketItems)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.basketDisplaySlotCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        // MARK: - Auto-Hide Hover Tracking
        .onHover { isHovering in
            if isHovering {
                FloatingBasketWindowController.shared.onBasketHoverEnter()
            } else {
                FloatingBasketWindowController.shared.onBasketHoverExit()
            }
        }
        // MARK: - Keyboard Shortcuts
        .background {
            // Hidden button for Cmd+A select all
            Button("") {
                state.selectAllBasket()
                state.selectAllBasketStacks()
            }
            .keyboardShortcut("a", modifiers: .command)
            .opacity(0)
        }
    }
    
    private var mainBasketContainer: some View {
        ZStack {
            // Background (extracted to reduce type-checker complexity)
            basketBackground
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            
            // Content - different views based on state
            // Quick action hover explanation takes priority over regular content
            if let hoveredAction = state.hoveredQuickAction {
                quickActionExplanation(for: hoveredAction)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if state.basketDisplaySlotCount == 0 {
                emptyContent
            } else if isExpanded {
                // Expanded grid view with full file list
                expandedGridContent
            } else {
                // Collapsed stacked preview (Dropover-style)
                collapsedStackContent
            }
            
            // Selection rectangle overlay (only in expanded view)
            if isDragSelecting && isExpanded && state.hoveredQuickAction == nil {
                selectionRectangleOverlay
            }
        }
        .frame(width: currentWidth, height: currentHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // 3D PRESSED EFFECT: Scale down when targeted (like button being pushed)
        // CRITICAL: Don't show highlight when dragging over quick action buttons (they handle their own drops)
        .scaleEffect((state.isBasketTargeted || state.isAirDropZoneTargeted) && !state.isQuickActionsTargeted ? 0.97 : 1.0)
        .animation(DroppyAnimation.bouncy, value: state.isBasketTargeted)
        .animation(DroppyAnimation.bouncy, value: state.isAirDropZoneTargeted)
        .animation(DroppyAnimation.bouncy, value: state.basketDisplaySlotCount)
        // WINDOW-WIDE DROP DESTINATION: Catch all file drops anywhere in the basket
        .dropDestination(for: URL.self) { urls, location in
            // Add all dropped files to basket
            for url in urls {
                let newItem = DroppedItem(url: url)
                withAnimation(DroppyAnimation.bouncy) {
                    state.addBasketItem(newItem)
                }
            }
            HapticFeedback.drop()
            return true
        } isTargeted: { targeted in
            state.isBasketTargeted = targeted
        }
        .coordinateSpace(name: "basketContainer")
        .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
            self.itemFrames = frames
        }
        .gesture(dragSelectionGesture)
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                dashPhase -= 280
            }
        }
        .onChange(of: state.basketDisplaySlotCount) { oldCount, newCount in
            if newCount == 0 {
                FloatingBasketWindowController.shared.hideBasket()
            }
        }
        .contextMenu {
            // Create Stack option - only enabled when 2+ items selected
            if state.selectedBasketItems.count >= 2 {
                Button {
                    state.createStackFromSelectedBasketItems()
                } label: {
                    Label("Create Stack", systemImage: "square.stack.3d.up.fill")
                }
                
                Divider()
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
        DragGesture(minimumDistance: 5, coordinateSpace: .local)
            .onChanged { value in
                if !isDragSelecting {
                    // Ignore drags starting in the header (window drag area)
                    if headerFrame.contains(value.startLocation) {
                        return
                    }
                    
                    // Check if drag started on an item using robust geometry data
                    for frame in itemFrames.values {
                        if frame.contains(value.startLocation) {
                            return
                        }
                    }
                    
                    // Start selection
                    isDragSelecting = true
                    dragSelectionStart = value.startLocation
                    state.deselectAllBasket()
                }
                dragSelectionCurrent = value.location
                
                // Update selection based on items intersecting the rectangle
                updateSelectionFromRect()
            }
            .onEnded { _ in
                isDragSelecting = false
            }
    }
    
    private func updateSelectionFromRect() {
        state.deselectAllBasket()
        
        // Use captured frames, which accounts for scrolling and layout accurately
        for (id, frame) in itemFrames {
            if selectionRect.intersects(frame) {
                state.selectedBasketItems.insert(id)
            }
        }
    }
    
    /// Basket background - Dropover style: clean dark container with subtle border
    /// Supports transparency mode: glass material when enabled, solid dark when disabled
    @ViewBuilder
    private var basketBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
            .frame(width: currentWidth, height: currentHeight)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(useTransparentBackground ? 0.12 : 0.06), lineWidth: 1)
            )
            // Sleek drag handle at top (only when files present)
            .overlay(alignment: .top) {
                if state.basketDisplaySlotCount > 0 {
                    BasketDragHandle()
                }
            }
            // Pressed effect when targeted (scale is handled by mainBasketContainer)
            .overlay(
                Group {
                    if state.isBasketTargeted {
                        // Subtle glow when file is being dragged over
                        RoundedRectangle(cornerRadius: cornerRadius - 4, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                            .padding(8)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: state.isBasketTargeted)
            )
    }
    
    @ViewBuilder
    private var emptyContent: some View {
        // Dropover-style empty state with "Drop files here" text - PERFECTLY CENTERED
        ZStack {
            // Centered text
            Text("Drop files here")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            
            // X button overlay in top-left
            VStack {
                HStack {
                    BasketCloseButton {
                        closeBasket()
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Explanation overlay shown when hovering over quick action buttons
    @ViewBuilder
    private func quickActionExplanation(for action: QuickActionType) -> some View {
        ZStack {
            // Centered text (matches "Drop files here" style)
            Text(action.description)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            
            // X button overlay in top-left
            VStack {
                HStack {
                    BasketCloseButton {
                        closeBasket()
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                
                Spacer()
            }
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
    private var collapsedStackContent: some View {
        VStack(spacing: 0) {
            // Header with X and chevron buttons
            HStack {
                BasketCloseButton {
                    closeBasket()
                }
                
                Spacer()
                
                // Menu button with context menu
                Menu {
                    basketContextMenuContent
                } label: {
                    BasketMenuButton { }
                        .allowsHitTesting(false)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            // Perfect symmetry: equal distance from left, right, and top edges
            .padding(.horizontal, 18)
            .padding(.top, 18)
            
            Spacer()
            
            // Stacked thumbnail preview - draggable for all files, tappable to expand
            DraggableArea(
                items: {
                    // Provide all basket item URLs for drag
                    state.basketItems.map { $0.url as NSURL }
                },
                onTap: { _ in
                    // Tap to expand
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                },
                onRightClick: {
                    // No right-click action for stack preview
                },
                onDragComplete: { [weak state] _ in
                    // Auto-clean after drag if enabled
                    guard let state = state else { return }
                    let enableAutoClean = UserDefaults.standard.bool(forKey: AppPreferenceKey.enableAutoClean)
                    if enableAutoClean {
                        withAnimation(DroppyAnimation.state) {
                            state.clearBasket()
                        }
                    }
                },
                selectionSignature: state.basketItems.count
            ) {
                BasketStackPreviewView(items: state.basketItems, state: state)
            }
            
            Spacer()
            
            // File count label - also tappable to expand
            BasketFileCountLabel(items: state.basketItems, isHovering: isFileLabelHovering) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded = true
                }
            }
            .onHover { hovering in
                isFileLabelHovering = hovering
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                basketItemsList
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded = false
                }
            }
            
            // Title and size info
            VStack(alignment: .leading, spacing: 2) {
                Text(expandedTitleText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(totalFileSizeText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            // View toggle buttons (grid/list)
            HStack(spacing: 8) {
                
                // Grid view button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isListView = false
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 32))
                .opacity(isListView ? 0.6 : 1.0)
                
                // List view button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
        let count = state.basketItems.count
        let allImages = state.basketItems.allSatisfy { $0.fileType?.conforms(to: .image) == true }
        
        if allImages {
            return "\(count) \(count == 1 ? "Image" : "Images")"
        } else {
            return "\(count) \(count == 1 ? "File" : "Files")"
        }
    }
    
    /// Total file size text for expanded header
    private var totalFileSizeText: String {
        var totalBytes: Int64 = 0
        for item in state.basketItems {
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
            let urls = state.basketItems.map(\.url)
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }
        
        Button {
            // Quick Look
            QuickLookHelper.shared.preview(urls: state.basketItems.map(\.url))
        } label: {
            Label("Quick Look", systemImage: "eye")
        }
        
        Divider()
        
        // Share menu
        if let shareService = NSSharingService(named: .sendViaAirDrop) {
            Button {
                shareService.perform(withItems: state.basketItems.map(\.url))
            } label: {
                Label("AirDrop", systemImage: "airplayaudio")
            }
        }
        
        Button {
            if let mailService = NSSharingService(named: .composeEmail) {
                mailService.perform(withItems: state.basketItems.map(\.url))
            }
        } label: {
            Label("Mail", systemImage: "envelope.fill")
        }
        
        Button {
            if let messagesService = NSSharingService(named: .composeMessage) {
                messagesService.perform(withItems: state.basketItems.map(\.url))
            }
        } label: {
            Label("Messages", systemImage: "message.fill")
        }
        
        Menu("More") {
            ForEach(NSSharingService.sharingServices(forItems: state.basketItems.map(\.url)), id: \.title) { service in
                Button {
                    service.perform(withItems: state.basketItems.map(\.url))
                } label: {
                    Text(service.title)
                }
            }
        }
        
        Divider()
        
        Button {
            // Copy Droppy link (placeholder - could copy file paths)
            let paths = state.basketItems.map(\.url.path).joined(separator: "\n")
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
            Text("\(state.basketItems.count) item\(state.basketItems.count == 1 ? "" : "s")")
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
            let allSelected = !state.basketItems.isEmpty && state.selectedBasketItems.count == state.basketItems.count
            
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
                    state.selectAllBasket()
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
            ZStack {
                // Background tap handler - catches clicks on empty areas
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        state.deselectAllBasket()
                        // If rename was active, end the file operation lock
                        if renamingItemId != nil {
                            state.isRenaming = false
                            state.endFileOperation()
                        }
                        renamingItemId = nil
                    }
                
                // Items grid using LazyVGrid for efficient rendering
                let columns = Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnsPerRow)
                
                LazyVGrid(columns: columns, spacing: 12) {  // Match column spacing
                    // Power Folders first (always distinct, never stacked)
                    ForEach(state.basketPowerFolders) { folder in
                        BasketItemView(item: folder, state: state, renamingItemId: $renamingItemId) {
                            withAnimation(DroppyAnimation.state) {
                                state.basketPowerFolders.removeAll { $0.id == folder.id }
                            }
                        }
                        .transition(.stackDrop)
                    }
                    
                    // Stacks - render based on expansion state
                    ForEach(state.basketStacks) { stack in
                        if stack.isExpanded {
                            // Collapse button as first item in expanded stack
                            StackCollapseButton(itemCount: stack.count) {
                                withAnimation(ItemStack.collapseAnimation) {
                                    state.collapseBasketStack(stack.id)
                                }
                            }
                            .transition(.stackExpand(index: 0))
                            
                            // Expanded: show all items individually
                            ForEach(stack.items) { item in
                                BasketItemView(item: item, state: state, renamingItemId: $renamingItemId) {
                                    withAnimation(DroppyAnimation.state) {
                                        state.removeBasketItem(item)
                                    }
                                }
                                .transition(.stackExpand(index: (stack.items.firstIndex(where: { $0.id == item.id }) ?? 0) + 1))
                            }
                        } else if stack.isSingleItem, let item = stack.coverItem {
                            // Single item - render as normal
                            BasketItemView(item: item, state: state, renamingItemId: $renamingItemId) {
                                withAnimation(DroppyAnimation.state) {
                                    state.removeBasketItem(item)
                                }
                            }
                            .transition(.stackDrop)
                        } else {
                            // Multi-item collapsed stack
                            StackedItemView(
                                stack: stack,
                                state: state,
                                onExpand: {
                                    withAnimation(ItemStack.expandAnimation) {
                                        state.toggleBasketStackExpansion(stack.id)
                                    }
                                },
                                onRemove: {
                                    withAnimation(DroppyAnimation.state) {
                                        state.removeBasketStack(stack.id)
                                    }
                                }
                            )
                            .transition(.stackDrop)
                        }
                    }
                }
                .animation(DroppyAnimation.bouncy, value: state.basketStacks.count)
                .animation(DroppyAnimation.bouncy, value: state.basketPowerFolders.count)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 18)
        }
    }
    
    /// List view for basket items - uses same BasketItemView with list layout for full feature parity
    private var basketItemsList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                // Power Folders first
                ForEach(state.basketPowerFolders) { folder in
                    BasketItemView(
                        item: folder,
                        state: state,
                        renamingItemId: $renamingItemId,
                        onRemove: {
                            withAnimation(DroppyAnimation.state) {
                                state.basketPowerFolders.removeAll { $0.id == folder.id }
                            }
                        },
                        layoutMode: .list
                    )
                }
                
                // Stacks - render based on expansion state
                ForEach(state.basketStacks) { stack in
                    if stack.isExpanded {
                        // List-styled collapse button
                        StackCollapseListRow(itemCount: stack.count) {
                            withAnimation(ItemStack.collapseAnimation) {
                                state.collapseBasketStack(stack.id)
                            }
                        }
                        
                        // Expanded: show all items individually in list mode
                        ForEach(stack.items) { item in
                            BasketItemView(
                                item: item,
                                state: state,
                                renamingItemId: $renamingItemId,
                                onRemove: {
                                    withAnimation(DroppyAnimation.state) {
                                        state.removeBasketItem(item)
                                    }
                                },
                                layoutMode: .list
                            )
                        }
                    } else if stack.isSingleItem, let item = stack.coverItem {
                        // Single item - render as normal
                        BasketItemView(
                            item: item,
                            state: state,
                            renamingItemId: $renamingItemId,
                            onRemove: {
                                withAnimation(DroppyAnimation.state) {
                                    state.removeBasketItem(item)
                                }
                            },
                            layoutMode: .list
                        )
                    } else {
                        // Multi-item collapsed stack - show as tappable row
                        StackListRow(
                            stack: stack,
                            state: state,
                            onExpand: {
                                withAnimation(ItemStack.expandAnimation) {
                                    state.toggleBasketStackExpansion(stack.id)
                                }
                            },
                            onRemove: {
                                withAnimation(DroppyAnimation.state) {
                                    state.removeBasketStack(stack.id)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 24)
            .padding(.bottom, 18)
        }
        // Note: Drop destination handled at container level (mainBasketContainer)
    }

    
    private func moveToShelf() {
        // STACK PRESERVATION: Transfer entire stacks as stacks, not individual items
        // This ensures that items grouped as a stack in the basket remain stacked on the shelf
        
        // Determine which stacks to move
        var stacksToMove: [ItemStack] = []
        var powerFoldersToMove: [DroppedItem] = []
        
        if state.selectedBasketItems.isEmpty && state.selectedBasketStacks.isEmpty {
            // No selection - move ALL stacks and power folders
            stacksToMove = state.basketStacks
            powerFoldersToMove = state.basketPowerFolders
        } else {
            // Move selected stacks (entire stacks that are selected)
            for stack in state.basketStacks {
                if state.selectedBasketStacks.contains(stack.id) {
                    // Entire stack is selected
                    stacksToMove.append(stack)
                } else {
                    // Check if any items in this stack are individually selected
                    let selectedItemsInStack = stack.items.filter { state.selectedBasketItems.contains($0.id) }
                    if !selectedItemsInStack.isEmpty {
                        // Create a new stack with just the selected items
                        if selectedItemsInStack.count == stack.items.count {
                            // All items selected - move the whole stack
                            stacksToMove.append(stack)
                        } else {
                            // Only some items selected - create partial stack
                            stacksToMove.append(ItemStack(items: selectedItemsInStack))
                        }
                    }
                }
            }
            
            // Move selected power folders
            powerFoldersToMove = state.basketPowerFolders.filter { state.selectedBasketItems.contains($0.id) }
        }
        
        // Transfer power folders to shelf (distinct, never stacked)
        for folder in powerFoldersToMove {
            // Avoid duplicates
            guard !state.shelfPowerFolders.contains(where: { $0.url == folder.url }) else { continue }
            state.shelfPowerFolders.append(folder)
            state.basketPowerFolders.removeAll { $0.id == folder.id }
        }
        
        // Transfer stacks to shelf as complete stacks
        let existingShelfURLs = Set(state.shelfStacks.flatMap { $0.items.map { $0.url } })
        
        for stack in stacksToMove {
            // Filter out any items that already exist on shelf
            let newItems = stack.items.filter { !existingShelfURLs.contains($0.url) }
            guard !newItems.isEmpty else { continue }
            
            // Create the new shelf stack preserving the stack structure
            var newStack = ItemStack(items: newItems)
            newStack.forceStackAppearance = stack.forceStackAppearance
            state.shelfStacks.append(newStack)
            
            // Remove transferred items from basket
            for item in newItems {
                state.removeBasketItemForTransfer(item)
            }
        }
        
        state.deselectAllBasket()
        state.selectedBasketStacks.removeAll()
        
        // PREMIUM: Haptic confirms items moved to shelf
        if !stacksToMove.isEmpty || !powerFoldersToMove.isEmpty {
            HapticFeedback.drop()
        }
        
        // Auto-expand shelf on the CORRECT screen:
        // Priority order:
        // 1. If a shelf is already expanded on any screen, use that screen
        // 2. Use the screen where the BASKET WINDOW is located (most reliable)
        // 3. Use the screen where the mouse is currently located
        // 4. Fall back to main screen only as last resort
        if !stacksToMove.isEmpty || !powerFoldersToMove.isEmpty {
            let targetDisplayID: CGDirectDisplayID
            
            if let currentExpandedDisplayID = state.expandedDisplayID {
                // Use the screen where the shelf is already expanded
                targetDisplayID = currentExpandedDisplayID
            } else if let basketWindow = FloatingBasketWindowController.shared.basketWindow,
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
                state.expandShelf(for: targetDisplayID)
            }
        }
        
        // Hide basket if empty after move
        if state.basketItems.isEmpty {
            FloatingBasketWindowController.shared.hideBasket()
        }
    }
    
    private func closeBasket() {
        state.clearBasket()
        FloatingBasketWindowController.shared.hideBasket()
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
        let selectedItems = state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
        guard !selectedItems.isEmpty else { return }
        
        // Copy files to finder folder
        let urls = selectedItems.map { $0.url }
        let copied = FinderFolderDetector.copyFiles(urls, to: finderFolder)
        
        if copied > 0 {
            // Remove from basket
            for item in selectedItems {
                state.removeBasketItem(item)
            }
            
            // Show confirmation
            DroppyAlertController.shared.showSimple(
                style: .info,
                title: "Copied \(copied) file\(copied == 1 ? "" : "s")",
                message: "to \(finderFolder.lastPathComponent)"
            )
        }
        
        // Hide basket if empty
        if state.basketItems.isEmpty {
            FloatingBasketWindowController.shared.hideBasket()
        }
    }
}




// MARK: - Rename Text Field with Auto-Select and Animated Dotted Border
private struct RenameTextField: View {
    @Binding var text: String
    @Binding var isRenaming: Bool
    let onRename: () -> Void
    
    @State private var dashPhase: CGFloat = 0
    
    var body: some View {
        AutoSelectTextField(
            text: $text,
            onSubmit: onRename,
            onCancel: { isRenaming = false }
        )
        .font(.system(size: 11, weight: .medium))
        .frame(width: 72)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        // Animated dotted blue outline
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    Color.accentColor.opacity(0.8),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        dash: [3, 3],
                        dashPhase: dashPhase
                    )
                )
        )
        .onAppear {
            // Animate the marching ants
            withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                dashPhase = 6
            }
        }
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
        textField.textColor = .white
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

// MARK: - Stack List Row

/// Compact list row for collapsed stacks - tap to expand
struct StackListRow: View {
    let stack: ItemStack
    let state: DroppyState
    let onExpand: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovering = false
    @State private var isDropTargeted = false
    @State private var thumbnail: NSImage?
    
    var body: some View {
        DraggableArea(
            items: {
                // Drag all items in the stack
                stack.items.map { $0.url as NSURL }
            },
            onTap: { _ in
                onExpand()
            },
            onRightClick: {
                // Right-click does nothing special
            },
            onDragComplete: nil,
            selectionSignature: stack.id.hashValue
        ) {
            HStack(spacing: 12) {
                // Stack icon with count badge
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let thumb = thumbnail {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Image(systemName: "square.stack.3d.up.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.5))
                                )
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    
                    // Count badge
                    Text("\(stack.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.blue))
                        .offset(x: 4, y: 4)
                }
                
                // Stack info
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stack.count) Items")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    
                    Text("Tap to expand · Drag to export")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Stack indicator
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isDropTargeted ? Color.blue.opacity(0.4) : Color.white.opacity(isHovering ? 0.18 : 0.12))
            )
            .overlay(
                // Blue border when drop targeted
                Capsule()
                    .stroke(Color.blue, lineWidth: isDropTargeted ? 2 : 0)
            )
            .scaleEffect(isDropTargeted ? 1.05 : (isHovering ? 1.02 : 1.0))
        }
        .dropDestination(for: URL.self) { urls, location in
            // Add dropped files to this stack
            for url in urls {
                let newItem = DroppedItem(url: url)
                withAnimation(DroppyAnimation.bouncy) {
                    state.addItemToStack(newItem, stackId: stack.id)
                }
            }
            HapticFeedback.drop()
            return true
        } isTargeted: { targeted in
            withAnimation(DroppyAnimation.bouncy) {
                isDropTargeted = targeted
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(DroppyAnimation.hoverBouncy, value: isHovering)
        .animation(DroppyAnimation.bouncy, value: isDropTargeted)
        .contextMenu {
            Button {
                onExpand()
            } label: {
                Label("Expand Stack", systemImage: "rectangle.expand.vertical")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove Stack", systemImage: "trash")
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard let coverItem = stack.coverItem else { return }
        Task {
            let size = CGSize(width: 72, height: 72)
            if let thumb = await coverItem.generateThumbnail(size: size) {
                await MainActor.run {
                    self.thumbnail = thumb
                }
            }
        }
    }
}

// MARK: - Stack Collapse List Row

/// List-styled collapse button to match the capsule row design
struct StackCollapseListRow: View {
    let itemCount: Int
    let onCollapse: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            HapticFeedback.pop()
            onCollapse()
        }) {
            HStack(spacing: 12) {
                // Collapse icon in circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                    
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 36, height: 36)
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Collapse Stack")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    
                    Text("\(itemCount) items")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Collapse indicator
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(isHovering ? 0.18 : 0.12))
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(DroppyPillButtonStyle())
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(DroppyAnimation.hoverBouncy, value: isHovering)
    }
}
