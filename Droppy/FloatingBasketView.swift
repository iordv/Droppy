import UniformTypeIdentifiers
//
//  FloatingBasketView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

// Use a wrapper function to silence the deprecation warning
// The deprecated API is the ONLY way to properly show share services in SwiftUI context menus
@available(macOS, deprecated: 13.0, message: "NSSharingService.sharingServices is deprecated but required for context menu integration")
private func sharingServicesForItems(_ items: [Any]) -> [NSSharingService] {
    NSSharingService.sharingServices(forItems: items)
}

/// A floating basket view that appears during file drags as an alternative drop zone
struct FloatingBasketView: View {
    @Bindable var state: DroppyState
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @AppStorage("showClipboardButton") private var showClipboardButton = false
    @AppStorage("enableNotchShelf") private var enableNotchShelf = true
    
    @State private var dashPhase: CGFloat = 0
    
    // Drag-to-select state
    @State private var isDragSelecting = false
    @State private var dragSelectionStart: CGPoint = .zero
    @State private var dragSelectionCurrent: CGPoint = .zero
    
    // Global rename state
    @State private var renamingItemId: UUID?
    
    private let cornerRadius: CGFloat = 24
    
    // Each item is 76pt wide + 8pt spacing between = 84pt per item
    // For 4 items: 4 * 76 + 3 * 8 = 304 + 24 = 328, plus 24pt padding each side = 376
    private let itemWidth: CGFloat = 76
    private let itemSpacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 24
    private let columnsPerRow: Int = 4
    
    private var currentHeight: CGFloat {
        if state.basketItems.isEmpty {
            return 130
        } else {
            let rowCount = ceil(Double(state.basketItems.count) / Double(columnsPerRow))
            // 96pt per item height + 8pt spacing + header area
            return max(1, rowCount) * (96 + itemSpacing) + 72
        }
    }
    
    private var currentWidth: CGFloat {
        if state.basketItems.isEmpty {
            return 200
        } else {
            // Width for exactly 4 items: 4 * itemWidth + 3 * spacing + padding
            return CGFloat(columnsPerRow) * itemWidth + CGFloat(columnsPerRow - 1) * itemSpacing + horizontalPadding * 2
        }
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
    @State private var isCloseButtonHovering = false
    @State private var headerFrame: CGRect = .zero
    
    
    var body: some View {
        ZStack {
            Color.clear
            
            VStack(spacing: 12) {
            // Main Basket Content
            ZStack {
                    // Background (extracted to reduce type-checker complexity)
                    basketBackground
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)

                    
                    // Content
                    if state.basketItems.isEmpty {
                        emptyContent
                    } else {
                        itemsContent
                    }
                    
                    // Selection rectangle overlay
                    if isDragSelecting {
                        Rectangle()
                            .fill(Color.blue.opacity(0.2))
                            .overlay(
                                Rectangle()
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                            .frame(width: selectionRect.width, height: selectionRect.height)
                            .position(x: selectionRect.midX, y: selectionRect.midY)
                    }
                }
                .frame(width: currentWidth, height: currentHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .scaleEffect(state.isBasketTargeted ? 1.03 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isBasketTargeted)
                // Use same spring animation as shelf for row expansion
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.basketItems.count)
                .coordinateSpace(name: "basketContainer")
                .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
                    self.itemFrames = frames
                }
                .gesture(
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
                )
                // Removed .onTapGesture from here to prevent swallowing touches on children
                .onAppear {
                    withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                        dashPhase -= 280 // Multiple of 14 (6+8) for smooth loop
                    }
                }
                .onChange(of: state.basketItems.count) { oldCount, newCount in
                    if newCount == 0 {
                        FloatingBasketWindowController.shared.hideBasket()
                    }
                }
            } // Close VStack
        } // Close ZStack
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
            }
            .keyboardShortcut("a", modifiers: .command)
            .opacity(0)
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
    private var basketBackground: some View {
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
                            dashPhase: dashPhase
                        )
                    )
                    .padding(12)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    private var emptyContent: some View {
        VStack(spacing: 12) {
            Image(systemName: state.isBasketTargeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(state.isBasketTargeted ? .blue : .primary.opacity(0.7))
                .symbolEffect(.bounce, value: state.isBasketTargeted)
            
            Text(state.isBasketTargeted ? "Drop!" : "Drop files here")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(state.isBasketTargeted ? .primary : .secondary)
        }
        .allowsHitTesting(false) // Don't block drag gestures
    }
    
    private var itemsContent: some View {
        return VStack(spacing: 8) {
            // Header
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
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
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
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isClipboardButtonHovering = isHovering
                        }
                    }
                }
                
                // Close button
                Button {
                    closeBasket()
                } label: {
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isCloseButtonHovering ? .primary : .secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(isCloseButtonHovering ? 0.2 : 0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isCloseButtonHovering = isHovering
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 22)

            .background(WindowDragHandle()) // Allow dragging by header
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
            
            // Items grid - wrapped in ZStack with background tap handler for deselection
            ZStack {
                // Background tap handler - catches clicks on empty areas
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        state.deselectAllBasket()
                        // If rename was active, end the file operation lock
                        if renamingItemId != nil {
                            state.endFileOperation()
                        }
                        renamingItemId = nil
                    }
                
                // Items grid using LazyVGrid for efficient rendering
                let columns = Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnsPerRow)
                
                LazyVGrid(columns: columns, spacing: itemSpacing) {
                    ForEach(state.basketItems) { item in
                        BasketItemView(item: item, state: state, renamingItemId: $renamingItemId) {
                            state.removeBasketItem(item)
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 16)
        }
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
        for item in itemsToMove {
            state.removeBasketItem(item)
            state.addItem(item)
        }
        state.deselectAllBasket()
        
        // Hide basket if empty after move
        if state.basketItems.isEmpty {
            FloatingBasketWindowController.shared.hideBasket()
        }
    }
    
    private func closeBasket() {
        state.clearBasket()
        FloatingBasketWindowController.shared.hideBasket()
    }
}

// MARK: - Basket Item View (matching NotchItemView functionality)

struct BasketItemView: View {
    let item: DroppedItem
    let state: DroppyState
    @Binding var renamingItemId: UUID?
    let onRemove: () -> Void
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @AppStorage("enableNotchShelf") private var enableNotchShelf = true
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    @State private var isConverting = false
    @State private var isExtractingText = false
    @State private var isCreatingZIP = false
    @State private var isCompressing = false
    @State private var isPoofing = false
    @State private var pendingConvertedItem: DroppedItem?
    // Removed local isRenaming
    @State private var renamingText = ""
    
    // Feedback State
    @State private var shakeOffset: CGFloat = 0
    @State private var isShakeAnimating = false
    
    private var isSelected: Bool {
        state.selectedBasketItems.contains(item.id)
    }
    
    var body: some View {
        DraggableArea(
            items: {
                // If this item is selected, drag all selected items
                if state.selectedBasketItems.contains(item.id) {
                    let selected = state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
                    return selected.map { $0.url as NSURL }
                } else {
                    return [item.url as NSURL]
                }
            },
            onTap: { modifiers in
                if modifiers.contains(.command) {
                    state.toggleBasketSelection(item)
                } else {
                    state.deselectAllBasket()
                    state.selectedBasketItems.insert(item.id)
                }
            },
            onRightClick: {
                if !state.selectedBasketItems.contains(item.id) {
                    state.deselectAllBasket()
                    state.selectedBasketItems.insert(item.id)
                }
            },
            selectionSignature: state.selectedBasketItems.hashValue
        ) {
            BasketItemContent(
                item: item,
                state: state,
                onRemove: onRemove,
                thumbnail: thumbnail,
                isHovering: isHovering,
                isConverting: isConverting,
                isExtractingText: isExtractingText,
                isSelected: isSelected,
                isPoofing: $isPoofing,
                pendingConvertedItem: $pendingConvertedItem,
                renamingItemId: $renamingItemId,
                renamingText: $renamingText,
                onRename: performRename
            )
            .offset(x: shakeOffset)
            .overlay(alignment: .center) {
                if isShakeAnimating {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
                            .frame(width: 44, height: 44)
                            .shadow(radius: 4)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 76, height: 96)
            .onHover { hovering in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHovering = hovering
                }
            }
            .contextMenu {
                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                
                Button {
                    item.openFile()
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.square")
                }
                
                // Move To...
                Menu {
                    // Saved Destinations
                    ForEach(DestinationManager.shared.destinations) { dest in
                        Button {
                            moveFiles(to: dest.url)
                        } label: {
                            Label(dest.name, systemImage: "externaldrive")
                        }
                    }
                    
                    if !DestinationManager.shared.destinations.isEmpty {
                        Divider()
                    }
                    
                    Button {
                        chooseDestinationAndMove()
                    } label: {
                        Label("Choose Folder...", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Label("Move to...", systemImage: "arrow.right.doc.on.clipboard")
                }
                
                // Open With submenu
                let availableApps = item.getAvailableApplications()
                if !availableApps.isEmpty {
                    Menu {
                        ForEach(availableApps, id: \.url) { app in
                            Button {
                                item.openWith(applicationURL: app.url)
                            } label: {
                                Label(app.name, image: NSImage.Name(app.name))
                            }
                        }
                    } label: {
                        Label("Open With...", systemImage: "square.and.arrow.up.on.square")
                    }
                }
                
                // Share submenu - positions correctly relative to context menu
                Menu {
                    ForEach(sharingServicesForItems([item.url]), id: \.title) { service in
                        Button {
                            service.perform(withItems: [item.url])
                        } label: {
                            Label {
                                Text(service.title)
                            } icon: {
                                Image(nsImage: service.image)
                            }
                        }
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    item.saveToDownloads()
                } label: {
                    Label("Save", systemImage: "arrow.down.circle")
                }
                
                // Conversion and OCR only for single selection
                if state.selectedBasketItems.count <= 1 {
                    // Conversion submenu
                    let conversions = FileConverter.availableConversions(for: item.fileType)
                    if !conversions.isEmpty {
                        Divider()
                        
                        Menu {
                            ForEach(conversions) { option in
                                Button {
                                    convertFile(to: option.format)
                                } label: {
                                    Label(option.displayName, systemImage: option.icon)
                                }
                            }
                        } label: {
                            Label("Convert to...", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    
                    // OCR Option
                    if item.fileType?.conforms(to: .image) == true || item.fileType?.conforms(to: .pdf) == true {
                        Button {
                            extractText()
                        } label: {
                            Label("Extract Text", systemImage: "text.viewfinder")
                        }
                    }
                }
                
                Divider()
                
                // Compress option - only show for compressible file types
                // Compress option - only show for compressible file types
                if FileCompressor.canCompress(fileType: item.fileType) {
                    if item.fileType?.conforms(to: .image) == true {
                        Menu {
                            Button("Auto (Medium)") {
                                compressFile(mode: .preset(.medium))
                            }
                            Button("Target Size...") {
                                compressFile(mode: nil)
                            }
                        } label: {
                            Label("Compress", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                        .disabled(isCompressing)
                    } else {
                        Button {
                            compressFile(mode: .preset(.medium))
                        } label: {
                            Label("Compress", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                        .disabled(isCompressing)
                    }
                }
                
                // Create ZIP option
                Button {
                    createZIPFromSelection()
                } label: {
                    Label("Create ZIP", systemImage: "doc.zipper")
                }
                .disabled(isCreatingZIP)
                
                Divider()
                
                // Rename option (single item only)
                if state.selectedBasketItems.count <= 1 {
                    Button {
                        startRenaming()
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                }
                
                // Move to Shelf (only when shelf is enabled)
                if enableNotchShelf {
                    Button {
                        state.addItem(item)
                        state.removeBasketItem(item)
                    } label: {
                        Label("Move to Shelf", systemImage: "arrow.up.to.line")
                    }
                }
                
                Divider()
                
                Button(role: .destructive) {
                    if state.selectedBasketItems.contains(item.id) {
                        removeSelectedItems()
                    } else {
                        onRemove()
                    }
                } label: {
                    Label("Remove from Basket", systemImage: "xmark")
                }
            }
            .task {
                // Use cached thumbnail if available, otherwise load async
                if let cached = ThumbnailCache.shared.cachedThumbnail(for: item) {
                    thumbnail = cached
                } else {
                    thumbnail = await ThumbnailCache.shared.loadThumbnailAsync(for: item, size: CGSize(width: 120, height: 120))
                }
            }
        }
        .background(GeometryReader { geo in
            Color.clear.preference(
                key: ItemFramePreferenceKey.self,
                value: [item.id: geo.frame(in: .named("basketContainer"))]
            )
        })
    }
    
    // MARK: - Actions
    
    private func chooseDestinationAndMove() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Move Here"
            panel.message = "Choose a destination to move the selected files."
            
            if panel.runModal() == .OK, let url = panel.url {
                 DestinationManager.shared.addDestination(url: url)
                 moveFiles(to: url)
            }
        }
    }
    
    private func moveFiles(to destination: URL) {
        let itemsToMove = state.selectedBasketItems.isEmpty ? [item] : state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
        
        DispatchQueue.global(qos: .userInitiated).async {
            for item in itemsToMove {
                do {
                    let destURL = destination.appendingPathComponent(item.url.lastPathComponent)
                    var finalDestURL = destURL
                    var counter = 1
                    while FileManager.default.fileExists(atPath: finalDestURL.path) {
                        let ext = destURL.pathExtension
                        let name = destURL.deletingPathExtension().lastPathComponent
                        let newName = "\(name) \(counter)" + (ext.isEmpty ? "" : ".\(ext)")
                        finalDestURL = destination.appendingPathComponent(newName)
                        counter += 1
                    }
                    
                    try FileManager.default.moveItem(at: item.url, to: finalDestURL)
                    
                    DispatchQueue.main.async {
                        state.removeBasketItem(item)
                    }
                } catch {
                    // Fallback copy+delete mechanism
                    do {
                        try FileManager.default.copyItem(at: item.url, to: destination.appendingPathComponent(item.url.lastPathComponent))
                        try FileManager.default.removeItem(at: item.url)
                        
                        DispatchQueue.main.async {
                            state.removeBasketItem(item)
                        }
                    } catch {
                        let errorDescription = error.localizedDescription
                        let itemName = item.name
                        DispatchQueue.main.async {
                            print("Failed to move file: \(errorDescription)")
                            Task {
                                await DroppyAlertController.shared.showError(
                                    title: "Move Failed",
                                    message: "Could not move \(itemName): \(errorDescription)"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func copyToClipboard() {
        let itemsToCopy = state.selectedBasketItems.isEmpty
            ? [item]
            : state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(itemsToCopy.map { $0.url as NSURL })
    }
    
    private func removeSelectedItems() {
        let toRemove = state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
        for i in toRemove {
            state.removeBasketItem(i)
        }
    }
    
    private func convertFile(to format: ConversionFormat) {
        guard !isConverting else { return }
        isConverting = true
        state.beginFileOperation()
        
        Task {
            if let convertedURL = await FileConverter.convert(item.url, to: format) {
                // Create new DroppedItem from converted file (marked as temporary for cleanup)
                let newItem = DroppedItem(url: convertedURL, isTemporary: true)
                
                await MainActor.run {
                    isConverting = false
                    state.endFileOperation()
                    pendingConvertedItem = newItem
                    // Trigger poof animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPoofing = true
                    }
                }
            } else {
                await MainActor.run {
                    isConverting = false
                    state.endFileOperation()
                }
                print("Conversion failed")
            }
        }
    }
    
    private func extractText() {
        guard !isExtractingText else { return }
        isExtractingText = true
        state.beginFileOperation()
        
        Task {
            do {
                let text = try await OCRService.shared.extractText(from: item.url)
                await MainActor.run {
                    isExtractingText = false
                    state.endFileOperation()
                    OCRWindowController.shared.show(with: text)
                }
            } catch {
                await MainActor.run {
                    isExtractingText = false
                    state.endFileOperation()
                    OCRWindowController.shared.show(with: "Error extracting text: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - ZIP Creation
    
    private func createZIPFromSelection() {
        guard !isCreatingZIP else { return }
        
        // Determine items to include: selected items or just this item
        let itemsToZip: [DroppedItem]
        if state.selectedBasketItems.isEmpty || (state.selectedBasketItems.count == 1 && state.selectedBasketItems.contains(item.id)) {
            itemsToZip = [item]
        } else {
            itemsToZip = state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
        }
        
        isCreatingZIP = true
        state.beginFileOperation()
        
        Task {
            // Generate archive name based on item count
            let archiveName = itemsToZip.count == 1 
                ? itemsToZip[0].url.deletingPathExtension().lastPathComponent
                : "Archive (\(itemsToZip.count) items)"
            
            if let zipURL = await FileConverter.createZIP(from: itemsToZip, archiveName: archiveName) {
                // Mark ZIP as temporary for cleanup when removed
                let newItem = DroppedItem(url: zipURL, isTemporary: true)
                
                await MainActor.run {
                    isCreatingZIP = false
                    // Keep isFileOperationInProgress = true since we auto-start renaming
                    // The flag will be reset when rename completes or is cancelled
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        state.replaceBasketItems(itemsToZip, with: newItem)
                    }
                    // Auto-start renaming the new zip file (flag stays true)
                    renamingItemId = newItem.id
                }
            } else {
                await MainActor.run {
                    isCreatingZIP = false
                    state.endFileOperation()
                }
                print("ZIP creation failed")
            }
        }
    }
    
    // MARK: - Compression
    
    private func compressFile(mode explicitMode: CompressionMode? = nil) {
        guard !isCompressing else { return }
        isCompressing = true
        state.beginFileOperation()
        
        Task {
            // Determine compression mode
            let mode: CompressionMode
            
            if let explicit = explicitMode {
                mode = explicit
            } else {
                // No explicit mode means request Target Size
                guard let currentSize = FileCompressor.fileSize(url: item.url) else {
                    await MainActor.run {
                        isCompressing = false
                        state.endFileOperation()
                    }
                    return
                }
                
                guard let targetBytes = await TargetSizeDialogController.shared.show(
                    currentSize: currentSize,
                    fileName: item.name
                ) else {
                    // User cancelled
                    await MainActor.run {
                        isCompressing = false
                        state.endFileOperation()
                    }
                    return
                }
                
                mode = .targetSize(bytes: targetBytes)
            }
            
            if let compressedURL = await FileCompressor.shared.compress(url: item.url, mode: mode) {
                // Mark compressed file as temporary for cleanup when removed
                let newItem = DroppedItem(url: compressedURL, isTemporary: true)
                
                await MainActor.run {
                    isCompressing = false
                    state.endFileOperation()
                    pendingConvertedItem = newItem
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPoofing = true
                    }
                }
            } else {
                await MainActor.run {
                    isCompressing = false
                    state.endFileOperation()
                    // Trigger Feedback: Shake + Shield
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        isShakeAnimating = true
                    }
                    
                    // Shake animation sequence
                    Task {
                        for _ in 0..<3 {
                            withAnimation(.linear(duration: 0.05)) { shakeOffset = -4 }
                            try? await Task.sleep(nanoseconds: 50_000_000)
                            withAnimation(.linear(duration: 0.05)) { shakeOffset = 4 }
                            try? await Task.sleep(nanoseconds: 50_000_000)
                        }
                        withAnimation { shakeOffset = 0 }
                        
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        withAnimation { isShakeAnimating = false }
                    }
                }
                print("Compression failed or no size reduction (Size Guard)")
            }
        }
    }
    
    // MARK: - Rename
    
    private func startRenaming() {
        // Use async to ensure context menu is fully closed before showing rename field
        state.beginFileOperation()
        DispatchQueue.main.async {
            renamingItemId = item.id
        }
    }
    
    private func performRename() {
        let trimmedName = renamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("Rename: Empty name, cancelling")
            renamingItemId = nil
            state.endFileOperation()
            return
        }
        
        print("Rename: Attempting to rename '\(item.name)' to '\(trimmedName)'")
        
        if let renamedItem = item.renamed(to: trimmedName) {
            print("Rename: Success! New item: \(renamedItem.name)")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                state.replaceBasketItem(item, with: renamedItem)
            }
        } else {
            print("Rename: Failed - renamed() returned nil")
        }
        renamingItemId = nil
        state.endFileOperation()
    }
}



// MARK: - Basket Item Content
private struct BasketItemContent: View {
    let item: DroppedItem
    let state: DroppyState
    let onRemove: () -> Void
    let thumbnail: NSImage?
    let isHovering: Bool
    let isConverting: Bool
    let isExtractingText: Bool
    let isSelected: Bool
    @Binding var isPoofing: Bool
    @Binding var pendingConvertedItem: DroppedItem?
    @Binding var renamingItemId: UUID?
    @Binding var renamingText: String
    let onRename: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail container
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
                    .frame(width: 60, height: 60)
                    .overlay {
                        Group {
                            if let thumbnail = thumbnail {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Image(nsImage: item.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .opacity((isConverting || isExtractingText) ? 0.5 : 1.0)
                    }
                    .overlay {
                        if isConverting || isExtractingText {
                            ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                        }
                    }
                
                // Remove button on hover
                if isHovering && !isPoofing && renamingItemId != item.id {
                    Button(action: onRemove) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red.opacity(0.9))
                                .frame(width: 20, height: 20)
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Filename or rename text field
            if renamingItemId == item.id {
                RenameTextField(
                    text: $renamingText,
                    // Pass a binding derived from the ID check
                    isRenaming: Binding(
                        get: { renamingItemId == item.id },
                        set: { if !$0 { 
                            renamingItemId = nil
                            state.endFileOperation()
                        } }
                    ),
                    onRename: onRename
                )
                .onAppear {
                    renamingText = item.url.deletingPathExtension().lastPathComponent
                }
            } else {
                Text(item.name)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : .primary.opacity(0.85))
                    .lineLimit(1)
                    .frame(width: 68)
                    .padding(.horizontal, 4)
                    .background(
                        isSelected ?
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.blue) :
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.clear)
                    )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering && !isSelected ? Color.white.opacity(0.1) : Color.clear)
        )
        .poofEffect(isPoofing: $isPoofing) {
            // Replace item when poof completes
            if let newItem = pendingConvertedItem {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    state.replaceBasketItem(item, with: newItem)
                }
                pendingConvertedItem = nil
            }
        }
    }
}

// MARK: - Window Drag Handler
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        return DraggableView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class DraggableView: NSView {
        override func mouseDown(with event: NSEvent) {
            self.window?.performDrag(with: event)
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
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        // Animated dotted blue outline
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
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
