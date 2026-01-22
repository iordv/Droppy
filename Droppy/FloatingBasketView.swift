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
    
    @State private var dashPhase: CGFloat = 0
    
    /// Dash phase freezes when any zone is targeted (animation pause effect)
    private var effectiveDashPhase: CGFloat {
        (state.isBasketTargeted || state.isAirDropZoneTargeted) ? 0 : dashPhase
    }
    
    // Drag-to-select state
    @State private var isDragSelecting = false
    @State private var dragSelectionStart: CGPoint = .zero
    @State private var dragSelectionCurrent: CGPoint = .zero
    
    // Global rename state
    @State private var renamingItemId: UUID?
    
    private let cornerRadius: CGFloat = 28
    
    // Each item is 76pt wide + 8pt spacing between = 84pt per item
    // For 4 items: 4 * 76 + 3 * 8 = 304 + 24 = 328, plus 24pt padding each side = 376
    private let itemWidth: CGFloat = 76
    private let itemSpacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 24
    private let columnsPerRow: Int = 4
    
    // AirDrop zone width (30% of total when enabled)
    private let airDropZoneWidth: CGFloat = 90
    
    /// Full width for 4-column grid: 4 * 76 + 3 * 8 + 24 * 2 = 304 + 24 + 48 = 376
    private let fullGridWidth: CGFloat = 376
    
    /// Dynamic height that fits content
    private var currentHeight: CGFloat {
        let slotCount = state.basketDisplaySlotCount
        
        if slotCount == 0 {
            return 130  // Empty basket
        } else {
            let rowCount = ceil(Double(slotCount) / Double(columnsPerRow))
            // 96pt per item height + 8pt spacing + 60pt header
            return max(1, rowCount) * (96 + itemSpacing) + 60
        }
    }
    
    /// Base width - always use full grid width for proper layout
    private var baseWidth: CGFloat {
        if state.basketDisplaySlotCount == 0 {
            return 200  // Compact empty state
        } else {
            return fullGridWidth  // Always full width when items present
        }
    }
    
    /// Total width including AirDrop zone when enabled AND basket is empty
    private var currentWidth: CGFloat {
        let showAirDropZone = enableAirDropZone && state.basketDisplaySlotCount == 0
        return baseWidth + (showAirDropZone ? airDropZoneWidth : 0)
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
            
            VStack(spacing: 12) {
                mainBasketContainer
            }
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
        ZStack(alignment: .top) {
            // Background (extracted to reduce type-checker complexity)
            basketBackground
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            
            // Content
            if state.basketDisplaySlotCount == 0 {
                emptyContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                itemsContent
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            
            // Selection rectangle overlay
            if isDragSelecting {
                selectionRectangleOverlay
            }
        }
        .frame(width: currentWidth, height: currentHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .scaleEffect((state.isBasketTargeted || state.isAirDropZoneTargeted) ? 1.03 : 1.0)
        .animation(DroppyAnimation.bouncy, value: state.isBasketTargeted)
        .animation(DroppyAnimation.bouncy, value: state.isAirDropZoneTargeted)
        .animation(DroppyAnimation.bouncy, value: state.basketDisplaySlotCount)
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
    
    /// Basket background with glass effect and dashed border (extracted for type-checker)
    @ViewBuilder
    private var basketBackground: some View {
        // AirDrop zone only shows when basket is empty
        let showAirDropZone = enableAirDropZone && state.basketDisplaySlotCount == 0
        
        if showAirDropZone {
            // Wider basket with AirDrop zone on right (only when empty)
            ZStack(alignment: .leading) {
                // Single background for the whole basket
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(useTransparentBackground ? Color.clear : Color.black)
                    .frame(width: currentWidth, height: currentHeight)
                    .background {
                        if useTransparentBackground {
                            Color.clear
                                .liquidGlass(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                
                // Left zone outline (main basket - blue when targeted)
                RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous)
                    .stroke(
                        state.isBasketTargeted ? Color.blue : Color.white.opacity(0.2),
                        style: StrokeStyle(
                            lineWidth: state.isBasketTargeted ? 2 : 1.5,
                            lineCap: .round,
                            dash: [6, 8],
                            dashPhase: effectiveDashPhase
                        )
                    )
                    .frame(width: baseWidth - 20, height: currentHeight - 20)
                    .offset(x: 10)
                
                // Right zone outline (AirDrop - red when targeted)
                RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous)
                    .stroke(
                        state.isAirDropZoneTargeted ? Color.blue : Color.white.opacity(0.2),
                        style: StrokeStyle(
                            lineWidth: state.isAirDropZoneTargeted ? 2 : 1.5,
                            lineCap: .round,
                            dash: [6, 8],
                            dashPhase: effectiveDashPhase
                        )
                    )
                    .frame(width: airDropZoneWidth - 15, height: currentHeight - 20)
                    .offset(x: baseWidth + 5)
                
                // AirDrop icon centered in the right zone - same size as NotchFace
                Image("AirDropIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .scaleEffect(state.isAirDropZoneTargeted ? 1.1 : 1.0)
                    .animation(DroppyAnimation.bouncy, value: state.isAirDropZoneTargeted)
                    .frame(width: airDropZoneWidth - 15, height: currentHeight - 20)
                    .offset(x: baseWidth + 5)
            }
        } else {
            // Normal basket layout (AirDrop disabled OR basket has items)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(useTransparentBackground ? Color.clear : Color.black)
                .frame(width: currentWidth, height: currentHeight)
                .background {
                    if useTransparentBackground {
                        Color.clear
                            .liquidGlass(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous)
                        .stroke(
                            state.isBasketTargeted ? Color.blue : Color.white.opacity(0.2),
                            style: StrokeStyle(
                                lineWidth: state.isBasketTargeted ? 2 : 1.5,
                                lineCap: .round,
                                dash: [6, 8],
                                dashPhase: effectiveDashPhase
                            )
                        )
                        .padding(12)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
    
    @ViewBuilder
    private var emptyContent: some View {
        if enableAirDropZone {
            // Split layout when AirDrop zone is enabled
            HStack(spacing: 0) {
                // Main basket zone content - face centered within the outline (10pt padding)
                NotchFace(size: 50, isExcited: state.isBasketTargeted)
                    .frame(width: baseWidth - 20, height: currentHeight - 20)
                    .frame(width: baseWidth)
                
                // Empty space - the icon is already in airDropZoneBackground
                Color.clear
                    .frame(width: airDropZoneWidth)
            }
            .allowsHitTesting(false)
        } else {
            // Original layout when AirDrop zone is disabled - centered with padding matching outline
            NotchFace(size: 50, isExcited: state.isBasketTargeted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(10)
                .allowsHitTesting(false)
        }
    }
    
    private var itemsContent: some View {
        VStack(spacing: 8) {
            // Header toolbar (extracted for type-checker)
            basketHeaderToolbar
            
            // Items grid - wrapped in ZStack with background tap handler for deselection
            basketItemsGrid
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
                            .font(.system(size: 10, weight: .bold))
                        Text("To Shelf")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(isShelfButtonHovering ? 1.0 : 0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    withAnimation(DroppyAnimation.hover) {
                        isShelfButtonHovering = isHovering
                    }
                }
            }
            
            // Clipboard button (optional)
            if showClipboardButton {
                Button {
                    ClipboardWindowController.shared.toggle()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isClipboardButtonHovering ? .primary : .secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(isClipboardButtonHovering ? 0.2 : 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    withAnimation(DroppyAnimation.hover) {
                        isClipboardButtonHovering = isHovering
                    }
                }
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
                            .font(.system(size: 10, weight: .bold))
                        Text("Add All")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(isDropHereHovering ? 1.0 : 0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    withAnimation(DroppyAnimation.hover) {
                        isDropHereHovering = isHovering
                    }
                }
                .help("Copy all to Finder folder")
            } else {
                // Select All button
                Button {
                    state.selectAllBasket()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Select All")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(isSelectAllHovering ? 1.0 : 0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    withAnimation(DroppyAnimation.hover) {
                        isSelectAllHovering = isHovering
                    }
                }
                .help("Select All (⌘A)")
            }
        }
    }
    
    private var basketItemsGrid: some View {
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
            
            LazyVGrid(columns: columns, spacing: itemSpacing) {
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
        .padding(.bottom, 16)
    }
    
    private func moveToShelf() {
        // Move selected items if any are selected, otherwise move all
        let itemsToMove: [DroppedItem]
        if state.selectedBasketItems.isEmpty {
            itemsToMove = state.basketItems
        } else {
            itemsToMove = state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
        }
        
        // Remove moved items from basket and add to shelf
        // Use transfer-safe removal to preserve files on disk
        for item in itemsToMove {
            state.addItem(item)
            state.removeBasketItemForTransfer(item)
        }
        state.deselectAllBasket()
        
        // PREMIUM: Haptic confirms items moved to shelf
        if !itemsToMove.isEmpty {
            HapticFeedback.drop()
        }
        
        // Auto-expand shelf on the CORRECT screen:
        // Priority order:
        // 1. If a shelf is already expanded on any screen, use that screen
        // 2. Use the screen where the BASKET WINDOW is located (most reliable)
        // 3. Use the screen where the mouse is currently located
        // 4. Fall back to main screen only as last resort
        if !itemsToMove.isEmpty {
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
