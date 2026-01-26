import SwiftUI
import UniformTypeIdentifiers

// MARK: - Basket Item Components
// Extracted from FloatingBasketView.swift for faster incremental builds

/// Layout mode for basket items
enum BasketItemLayout {
    case grid   // Standard grid card layout
    case list   // Compact list row layout
}

struct BasketItemView: View {
    let item: DroppedItem
    let state: DroppyState
    @Binding var renamingItemId: UUID?
    let onRemove: () -> Void
    var layoutMode: BasketItemLayout = .grid
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.enableNotchShelf) private var enableNotchShelf = PreferenceDefault.enableNotchShelf
    @AppStorage(AppPreferenceKey.enablePowerFolders) private var enablePowerFolders = PreferenceDefault.enablePowerFolders
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    @State private var isConverting = false
    @State private var isExtractingText = false
    @State private var isCreatingZIP = false
    @State private var isCompressing = false
    @State private var isRemovingBackground = false
    @State private var isPoofing = false
    @State private var pendingConvertedItem: DroppedItem?
    // Removed local isRenaming
    @State private var renamingText = ""
    
    // Feedback State
    @State private var shakeOffset: CGFloat = 0
    @State private var isShakeAnimating = false
    @State private var isDropTargeted = false  // For pinned folder drop zone
    @State private var showFolderPreview = false  // Delayed folder preview popover
    @State private var hoverTask: Task<Void, Never>?  // Task for delayed hover
    
    private var isSelected: Bool {
        state.selectedBasketItems.contains(item.id)
    }
    
    /// All selected items in the basket
    private var selectedItems: [DroppedItem] {
        state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
    }
    
    /// Whether ALL selected items are images (for bulk Remove BG)
    private var allSelectedAreImages: Bool {
        guard !selectedItems.isEmpty else { return false }
        return selectedItems.allSatisfy { $0.isImage }
    }
    
    /// Whether ALL selected items can be compressed
    private var allSelectedCanCompress: Bool {
        guard !selectedItems.isEmpty else { return false }
        return selectedItems.allSatisfy { FileCompressor.canCompress(fileType: $0.fileType) }
    }
    
    /// Whether ALL selected items are images (for consistent image menu)
    private var allSelectedAreImageFiles: Bool {
        guard !selectedItems.isEmpty else { return false }
        return selectedItems.allSatisfy { $0.fileType?.conforms(to: .image) == true }
    }
    
    /// Common conversions available for ALL selected items
    private var commonConversions: [ConversionOption] {
        guard !selectedItems.isEmpty else { return [] }
        var common: Set<ConversionFormat>? = nil
        for item in selectedItems {
            let formats = Set(FileConverter.availableConversions(for: item.fileType).map { $0.format })
            if common == nil {
                common = formats
            } else {
                common = common!.intersection(formats)
            }
        }
        guard let validFormats = common, !validFormats.isEmpty else { return [] }
        // Return full ConversionOptions for the common formats
        return FileConverter.availableConversions(for: selectedItems.first?.fileType)
            .filter { validFormats.contains($0.format) }
    }
    
    /// Whether ALL selected items support OCR (images or PDFs)
    private var allSelectedSupportOCR: Bool {
        guard !selectedItems.isEmpty else { return false }
        return selectedItems.allSatisfy {
            $0.fileType?.conforms(to: .image) == true || $0.fileType?.conforms(to: .pdf) == true
        }
    }
    
    /// File size for list layout
    private var listFileSize: String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: item.url.path)
            if let size = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {}
        return "—"
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
                } else if modifiers.contains(.shift) {
                    state.selectBasketRange(to: item)
                } else {
                    state.deselectAllBasket()
                    state.selectBasket(item)
                }
            },
            onRightClick: {
                // Cancel folder preview preventing overlap with context menu
                hoverTask?.cancel()
                hoverTask = nil
                showFolderPreview = false
                
                if !state.selectedBasketItems.contains(item.id) {
                    state.deselectAllBasket()
                    state.selectBasket(item)
                }
            },
            onDragStart: {
                // Dismiss tooltip immediately when drag starts
                hoverTask?.cancel()
                hoverTask = nil
                showFolderPreview = false
            },
            onDragComplete: { [weak state] operation in
                guard let state = state else { return }
                // Auto-clean: remove only the dragged items, not everything (skip pinned items)
                let enableAutoClean = UserDefaults.standard.bool(forKey: "enableAutoClean")
                if enableAutoClean {
                    withAnimation(DroppyAnimation.state) {
                        // If this item was selected, remove all selected non-pinned items
                        if state.selectedBasketItems.contains(item.id) {
                            // Get items to remove (non-pinned selected items)
                            let itemsToRemove = state.basketItems.filter { state.selectedBasketItems.contains($0.id) && !$0.isPinned }
                            for itemToRemove in itemsToRemove {
                                state.removeBasketItem(itemToRemove)
                            }
                            state.selectedBasketItems.removeAll()
                        } else if !item.isPinned {
                            // Otherwise just remove this single item (if not pinned)
                            state.removeBasketItem(item)
                        }
                    }
                }
            },
            selectionSignature: state.selectedBasketItems.hashValue
        ) {
            Group {
                if layoutMode == .list {
                    // List row layout
                    HStack(spacing: 12) {
                        // Circular thumbnail with activity overlay
                        ZStack {
                            Group {
                                if let thumb = thumbnail {
                                    // QuickLook preview thumbnail
                                    Image(nsImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    // Native macOS icon (folders, zip, dmg, etc.) - matches grid view
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 24, height: 24)
                                        )
                                }
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            
                            // Activity indicator overlay
                            if isConverting || isCompressing || isRemovingBackground || isExtractingText || isCreatingZIP {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .tint(.white)
                                    )
                            }
                            
                            // Poof overlay
                            if isPoofing {
                                Circle()
                                    .fill(Color.green.opacity(0.8))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.white)
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                    .onAppear {
                                        // Auto-fade after 1.5 seconds
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            withAnimation(DroppyAnimation.easeOut) {
                                                isPoofing = false
                                            }
                                        }
                                    }
                            }
                        }
                        
                        // Name and size (with renaming support)
                        VStack(alignment: .leading, spacing: 2) {
                            if renamingItemId == item.id {
                                // Auto-select rename text field
                                AutoSelectTextField(
                                    text: $renamingText,
                                    onSubmit: performRename,
                                    onCancel: {
                                        renamingItemId = nil
                                        state.isRenaming = false
                                        state.endFileOperation()
                                    }
                                )
                                .font(.system(size: 13, weight: .medium))
                                .frame(height: 20)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.15)))
                                .onAppear {
                                    renamingText = item.url.deletingPathExtension().lastPathComponent
                                }
                            } else {
                                Text(item.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(isSelected ? .white : .white.opacity(0.9))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            
                            // Status text or file size (use white text on blue selection)
                            if isConverting {
                                Text("Converting...")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .orange.opacity(0.8))
                            } else if isCompressing {
                                Text("Compressing...")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .blue.opacity(0.8))
                            } else if isRemovingBackground {
                                Text("Removing BG...")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .purple.opacity(0.8))
                            } else if isExtractingText {
                                Text("Extracting text...")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .green.opacity(0.8))
                            } else if isCreatingZIP {
                                Text("Creating ZIP...")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .cyan.opacity(0.8))
                            } else if item.isDirectory {
                                Text(item.isPinned ? "Pinned Folder" : "Folder")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                            } else {
                                Text(listFileSize)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Spacer(minLength: 8)
                        
                        // File extension or folder badge
                        if item.isDirectory {
                            Text("FOLDER")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        } else if !item.url.pathExtension.isEmpty {
                            Text(item.url.pathExtension.uppercased())
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                    }
                    .frame(maxWidth: .infinity)  // Prevent horizontal expansion - matches ClipboardItemRow
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isSelected 
                                  ? Color.blue.opacity(isHovering ? 1.0 : 0.8)
                                  : Color.white.opacity(isHovering ? 0.18 : 0.12))
                    )
                    .scaleEffect(isHovering && !isSelected ? 1.02 : 1.0)
                } else {
                    // Grid card layout (original)
                    BasketItemContent(
                        item: item,
                        state: state,
                        onRemove: onRemove,
                        thumbnail: thumbnail,
                        isHovering: isHovering,
                        isConverting: isConverting,
                        isExtractingText: isExtractingText,
                        isRemovingBackground: isRemovingBackground,
                        isCompressing: isCompressing,
                        isCreatingZIP: isCreatingZIP,
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
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                }
            }
            // Drop target for pinned folders - drop files INTO the folder
            .dropDestination(for: URL.self) { urls, location in
                guard enablePowerFolders && item.isPinned && item.isDirectory else { return false }
                moveFilesToFolder(urls: urls, destination: item.url)
                return true
            } isTargeted: { targeted in
                guard enablePowerFolders && item.isPinned && item.isDirectory else { return }
                withAnimation(DroppyAnimation.easeOut) {
                    isDropTargeted = targeted
                }
                // Cancel folder preview when drop is happening
                if targeted {
                    hoverTask?.cancel()
                    showFolderPreview = false
                }
            }
            .overlay {
                // Visual feedback when dropping files onto pinned folder
                if isDropTargeted && item.isPinned {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.yellow, lineWidth: 3)
                        .frame(width: 60, height: 60)
                        .offset(y: -12)
                }
            }
            .onHover { hovering in
                // CRITICAL: Ignore interaction if blocked (e.g. context menu open)
                guard !state.isInteractionBlocked else { return }
                
                // Haptic feedback on hover start
                if hovering {
                    HapticFeedback.pop()
                }
                
                // Direct state update - animation handled by view-level modifier
                isHovering = hovering
                
                // Delayed folder preview for ALL folders (not just pinned)
                if item.isDirectory {
                    if hovering && !isDropTargeted {
                        hoverTask = Task {
                            try? await Task.sleep(nanoseconds: 800_000_000)  // 0.8s delay
                            if !Task.isCancelled && !isDropTargeted && !state.isInteractionBlocked {
                                showFolderPreview = true
                            }
                        }
                    } else {
                        // Clean dismiss - cancel pending task and hide popover
                        hoverTask?.cancel()
                        hoverTask = nil
                        showFolderPreview = false
                    }
                }
            }
            .onChange(of: state.isInteractionBlocked) { _, blocked in
                if blocked {
                    hoverTask?.cancel()
                    hoverTask = nil
                    showFolderPreview = false
                    isHovering = false
                }
            }
            .popover(isPresented: $showFolderPreview, arrowEdge: .bottom) {
                FolderPreviewPopover(folderURL: item.url)
            }
            .onChange(of: state.poofingItemIds) { _, newIds in
                // Trigger local poof animation when this item is marked for poof (from bulk operations)
                if newIds.contains(item.id) {
                    withAnimation(DroppyAnimation.state) {
                        isPoofing = true
                    }
                    // Clear the poof state after triggering
                    state.clearPoof(for: item.id)
                }
            }
            .onAppear {
                // Check if this item was created with poof pending (from bulk operations)
                if state.poofingItemIds.contains(item.id) {
                    // Small delay to ensure view is fully rendered before animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(DroppyAnimation.state) {
                            isPoofing = true
                        }
                        state.clearPoof(for: item.id)
                    }
                }
            }
            .contextMenu {
                contextMenuContent()
            }
            .task {
                // ASYNC: Load QuickLook thumbnail (if available)
                if let cached = ThumbnailCache.shared.cachedThumbnail(for: item) {
                    thumbnail = cached
                } else if let asyncThumbnail = await ThumbnailCache.shared.loadThumbnailAsync(for: item, size: CGSize(width: 120, height: 120)) {
                    withAnimation(DroppyAnimation.hover) {
                        thumbnail = asyncThumbnail
                    }
                }
            }
        }
        .animation(DroppyAnimation.hoverBouncy, value: isHovering)
        .background(GeometryReader { geo in
            Color.clear.preference(
                key: ItemFramePreferenceKey.self,
                value: [item.id: geo.frame(in: .named("basketContainer"))]
            )
        })
    }
    
    // MARK: - Context Menu Content
    @ViewBuilder
    private func contextMenuContent() -> some View {
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
                        Label {
                            Text(app.name)
                        } icon: {
                            Image(nsImage: app.icon)
                        }
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
        
        // Droppy Quickshare - upload and get shareable link
        Button {
            let itemsToShare = state.selectedBasketItems.isEmpty
                ? [item.url]
                : state.basketItems.filter { state.selectedBasketItems.contains($0.id) }.map { $0.url }
            DroppyQuickshare.share(urls: itemsToShare)
        } label: {
            Label("Droppy Quickshare", systemImage: "drop.fill")
        }
        
        Button {
            // Bulk save: save all selected items
            if state.selectedBasketItems.count > 1 && state.selectedBasketItems.contains(item.id) {
                for selectedItem in selectedItems {
                    selectedItem.saveToDownloads()
                }
            } else {
                item.saveToDownloads()
            }
        } label: {
            if state.selectedBasketItems.count > 1 && state.selectedBasketItems.contains(item.id) {
                Label("Save All (\(state.selectedBasketItems.count))", systemImage: "arrow.down.circle")
            } else {
                Label("Save", systemImage: "arrow.down.circle")
            }
        }
        
        // Conversion submenu - show when single item OR all selected share common conversions
        let conversions = state.selectedBasketItems.count > 1 ? commonConversions : FileConverter.availableConversions(for: item.fileType)
        if !conversions.isEmpty {
            Divider()
            
            Menu {
                ForEach(conversions) { option in
                    Button {
                        if state.selectedBasketItems.count > 1 && state.selectedBasketItems.contains(item.id) {
                            convertAllSelected(to: option.format)
                        } else {
                            convertFile(to: option.format)
                        }
                    } label: {
                        Label(option.displayName, systemImage: option.icon)
                    }
                }
            } label: {
                if state.selectedBasketItems.count > 1 && state.selectedBasketItems.contains(item.id) {
                    Label("Convert All (\(state.selectedBasketItems.count))...", systemImage: "arrow.triangle.2.circlepath")
                } else {
                    Label("Convert to...", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        }
        
        // OCR Option - single item only (too complex for bulk)
        if state.selectedBasketItems.count <= 1 {
            if item.fileType?.conforms(to: .image) == true || item.fileType?.conforms(to: .pdf) == true {
                Button {
                    extractText()
                } label: {
                    Label("Extract Text", systemImage: "text.viewfinder")
                }
            }
        }
        
        // Remove Background - show when single image OR all selected are images
        if (state.selectedBasketItems.count <= 1 && item.isImage) || (state.selectedBasketItems.count > 1 && allSelectedAreImages && state.selectedBasketItems.contains(item.id)) {
            if AIInstallManager.shared.isInstalled {
                Button {
                    if state.selectedBasketItems.count > 1 {
                        removeBackgroundFromAllSelected()
                    } else {
                        removeBackground()
                    }
                } label: {
                    if state.selectedBasketItems.count > 1 {
                        Label("Remove Background (\(state.selectedBasketItems.count))", systemImage: "person.and.background.dotted")
                    } else {
                        Label("Remove Background", systemImage: "person.and.background.dotted")
                    }
                }
                .disabled(isRemovingBackground)
            } else {
                Button {
                    // No action - just informational
                } label: {
                    Label("Remove Background (Settings > Extensions)", systemImage: "person.and.background.dotted")
                }
                .disabled(true)
            }
        }
        
        Divider()
        
        // Compress option - show when single compressible OR all selected can compress
        let canShowCompress = (state.selectedBasketItems.count <= 1 && FileCompressor.canCompress(fileType: item.fileType)) ||
        (state.selectedBasketItems.count > 1 && allSelectedCanCompress && state.selectedBasketItems.contains(item.id))
        if canShowCompress {
            let isMultiSelect = state.selectedBasketItems.count > 1 && state.selectedBasketItems.contains(item.id)
            let isImageCompress = isMultiSelect ? allSelectedAreImageFiles : (item.fileType?.conforms(to: .image) == true)
            let isVideoCompress = !isMultiSelect && (item.fileType?.conforms(to: .movie) == true || item.fileType?.conforms(to: .video) == true)
            
            if isImageCompress || isVideoCompress {
                // Images and Videos: Show menu with Target Size option
                // For videos, Target Size only available when FFmpeg extension is installed
                let showVideoTargetSize = isVideoCompress && FileCompressor.isVideoTargetSizeAvailable
                let showImageTargetSize = isImageCompress
                
                Menu {
                    Button("Auto (Medium)") {
                        if isMultiSelect {
                            compressAllSelected(mode: .preset(.medium))
                        } else {
                            compressFile(mode: .preset(.medium))
                        }
                    }
                    if !isMultiSelect && (showImageTargetSize || showVideoTargetSize) {
                        Button("Target Size...") {
                            compressFile(mode: nil)
                        }
                    }
                } label: {
                    if isMultiSelect {
                        Label("Compress All (\(state.selectedBasketItems.count))", systemImage: "arrow.down.right.and.arrow.up.left")
                    } else {
                        Label("Compress", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                }
                .disabled(isCompressing)
            } else {
                // PDFs: Simple button (target size not supported)
                Button {
                    if isMultiSelect {
                        compressAllSelected(mode: .preset(.medium))
                    } else {
                        compressFile(mode: .preset(.medium))
                    }
                } label: {
                    if isMultiSelect {
                        Label("Compress All (\(state.selectedBasketItems.count))", systemImage: "arrow.down.right.and.arrow.up.left")
                    } else {
                        Label("Compress", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
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
        
        // Pin/Unpin option for folders
        if item.isDirectory && state.selectedBasketItems.count <= 1 {
            Button {
                state.togglePin(item)
            } label: {
                if item.isPinned {
                    Label("Unpin Folder", systemImage: "pin.slash")
                } else {
                    Label("Pin Folder", systemImage: "pin")
                }
            }
        }
        
        // Move to Shelf (only when shelf is enabled)
        if enableNotchShelf {
            Button {
                state.addItem(item)
                state.removeBasketItemForTransfer(item)  // Transfer-safe: don't delete file
            } label: {
                Label("Move to Shelf", systemImage: "arrow.up.to.line")
            }
        }
        
        
        // Hide delete button for pinned folders - must unpin first
        if !item.isPinned {
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
    
    /// Moves external files (from drag) into a pinned folder
    /// Only COPIES files - never deletes source (safe operation)
    private func moveFilesToFolder(urls: [URL], destination: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            for url in urls {
                // Skip if trying to drop a folder into itself
                guard url != destination else { continue }
                
                // Skip if file is already inside this folder (parent is destination)
                let parent = url.deletingLastPathComponent().standardizedFileURL
                let dest = destination.standardizedFileURL
                if parent == dest {
                    print("📁 File already in folder, skipping: \(url.lastPathComponent)")
                    continue
                }
                
                do {
                    let destURL = destination.appendingPathComponent(url.lastPathComponent)
                    var finalDestURL = destURL
                    var counter = 1
                    
                    while FileManager.default.fileExists(atPath: finalDestURL.path) {
                        let ext = destURL.pathExtension
                        let name = destURL.deletingPathExtension().lastPathComponent
                        let newName = "\(name) \(counter)" + (ext.isEmpty ? "" : ".\(ext)")
                        finalDestURL = destination.appendingPathComponent(newName)
                        counter += 1
                    }
                    
                    // Copy file into folder (don't move - safer for drag operations)
                    try FileManager.default.copyItem(at: url, to: finalDestURL)
                    print("📁 Copied \(url.lastPathComponent) into \(destination.lastPathComponent)")
                } catch {
                    print("❌ Failed to copy file into folder: \(error.localizedDescription)")
                }
            }
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
                
                // Smart Export: auto-save converted file if enabled
                _ = await MainActor.run {
                    SmartExportManager.shared.saveFile(convertedURL, for: .conversion)
                }
                
                await MainActor.run {
                    isConverting = false
                    state.endFileOperation()
                    pendingConvertedItem = newItem
                    // Trigger poof animation
                    withAnimation(DroppyAnimation.state) {
                        isPoofing = true
                    }
                }
            } else {
                await MainActor.run {
                    isConverting = false
                    state.endFileOperation()
                }
                print("Conversion failed")
                let requiredApp = FileConverter.requiredAppForPDFConversion(fileType: item.fileType) ?? "Keynote, Pages, Numbers, or LibreOffice"
                await DroppyAlertController.shared.showError(
                    title: "Conversion Failed",
                    message: "Could not convert \(item.name) to PDF. Please install \(requiredApp) (free from App Store) or LibreOffice."
                )
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
                    // Trigger poof animation for successful extraction
                    withAnimation(DroppyAnimation.state) {
                        isPoofing = true
                    }
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
                    // Update state immediately (animation deferred to poof effect)
                    state.replaceBasketItems(itemsToZip, with: newItem)
                    
                    // Delay setting rename ID to ensure new item's view is created
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        // Auto-start renaming the new zip file
                        renamingItemId = newItem.id
                        state.isRenaming = true
                    }
                    
                    // Trigger poof animation after view has appeared
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        state.triggerPoof(for: newItem.id)
                    }
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
                
                // Smart Export: auto-save to folder if enabled
                _ = await MainActor.run {
                    SmartExportManager.shared.saveFile(compressedURL, for: .compression)
                }
                
                await MainActor.run {
                    isCompressing = false
                    state.endFileOperation()
                    pendingConvertedItem = newItem
                    withAnimation(DroppyAnimation.state) {
                        isPoofing = true
                    }
                }
            } else {
                await MainActor.run {
                    isCompressing = false
                    state.endFileOperation()
                    // Trigger Feedback: Shake + Shield
                    withAnimation(DroppyAnimation.stateEmphasis) {
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
    
    
    
    // MARK: - Background Removal
    
    private func removeBackground() {
        guard !isRemovingBackground else { return }
        isRemovingBackground = true
        state.beginFileOperation()
        
        Task {
            do {
                let outputURL = try await item.removeBackground()
                // Mark as temporary for cleanup when removed
                let newItem = DroppedItem(url: outputURL, isTemporary: true)
                
                await MainActor.run {
                    isRemovingBackground = false
                    state.endFileOperation()
                    pendingConvertedItem = newItem
                    withAnimation(DroppyAnimation.state) {
                        isPoofing = true
                    }
                }
            } catch {
                await MainActor.run {
                    isRemovingBackground = false
                    state.endFileOperation()
                    print("Background removal failed: \(error.localizedDescription)")
                    // Trigger shake animation for failure feedback
                    withAnimation(DroppyAnimation.stateEmphasis) {
                        isShakeAnimating = true
                    }
                    Task {
                        for _ in 0..<3 {
                            withAnimation(.linear(duration: 0.05)) { shakeOffset = -4 }
                            try? await Task.sleep(nanoseconds: 50_000_000)
                            withAnimation(.linear(duration: 0.05)) { shakeOffset = 4 }
                            try? await Task.sleep(nanoseconds: 50_000_000)
                        }
                        withAnimation(.spring(response: 0.3)) { shakeOffset = 0 }
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        withAnimation(DroppyAnimation.viewChange) { isShakeAnimating = false }
                    }
                }
            }
        }
    }
    
    // MARK: - Bulk Operations
    
    /// Convert all selected items to the specified format
    private func convertAllSelected(to format: ConversionFormat) {
        guard !isConverting else { return }
        isConverting = true
        state.beginFileOperation()
        
        Task {
            for selectedItem in selectedItems {
                if let convertedURL = await FileConverter.convert(selectedItem.url, to: format) {
                    let newItem = DroppedItem(url: convertedURL, isTemporary: true)
                    
                    // Smart Export: auto-save converted file if enabled
                    _ = await MainActor.run {
                        SmartExportManager.shared.saveFile(convertedURL, for: .conversion)
                    }
                    
                    await MainActor.run {
                        state.replaceBasketItem(selectedItem, with: newItem)
                        // Trigger poof animation for this specific item
                        state.triggerPoof(for: newItem.id)
                    }
                }
            }
            
            await MainActor.run {
                isConverting = false
                state.endFileOperation()
            }
        }
    }
    
    /// Compress all selected items
    private func compressAllSelected(mode: CompressionMode) {
        guard !isCompressing else { return }
        isCompressing = true
        state.beginFileOperation()
        
        Task {
            for selectedItem in selectedItems {
                if let compressedURL = await FileCompressor.shared.compress(url: selectedItem.url, mode: mode) {
                    let newItem = DroppedItem(url: compressedURL, isTemporary: true)
                    
                    // Smart Export: auto-save to folder if enabled
                    _ = await MainActor.run {
                        SmartExportManager.shared.saveFile(compressedURL, for: .compression)
                    }
                    
                    await MainActor.run {
                        state.replaceBasketItem(selectedItem, with: newItem)
                        // Trigger poof animation for this specific item
                        state.triggerPoof(for: newItem.id)
                    }
                }
            }
            
            await MainActor.run {
                isCompressing = false
                state.endFileOperation()
            }
        }
    }
    
    /// Remove background from all selected images
    private func removeBackgroundFromAllSelected() {
        guard !isRemovingBackground else { return }
        isRemovingBackground = true
        state.beginFileOperation()
        
        // Mark ALL selected items as processing to show spinners simultaneously
        let imagesToProcess = selectedItems.filter { $0.isImage }
        for item in imagesToProcess {
            state.beginProcessing(for: item.id)
        }
        
        Task {
            for selectedItem in imagesToProcess {
                do {
                    let outputURL = try await selectedItem.removeBackground()
                    let newItem = DroppedItem(url: outputURL, isTemporary: true)
                    await MainActor.run {
                        // End processing for old item, replace with new
                        state.endProcessing(for: selectedItem.id)
                        state.replaceBasketItem(selectedItem, with: newItem)
                        // Trigger poof animation for this specific item
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            state.triggerPoof(for: newItem.id)
                        }
                    }
                } catch {
                    await MainActor.run {
                        // End processing even on failure
                        state.endProcessing(for: selectedItem.id)
                    }
                    print("Background removal failed for \(selectedItem.name): \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isRemovingBackground = false
                state.endFileOperation()
            }
        }
    }
    
    // MARK: - Rename
    
    private func startRenaming() {
        // Use async to ensure context menu is fully closed before showing rename field
        state.beginFileOperation()
        state.isRenaming = true
        DispatchQueue.main.async {
            renamingItemId = item.id
        }
    }
    
    private func performRename() {
        let trimmedName = renamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("Rename: Empty name, cancelling")
            renamingItemId = nil
            state.isRenaming = false
            state.endFileOperation()
            return
        }
        
        print("Rename: Attempting to rename '\(item.name)' to '\(trimmedName)'")
        
        if let renamedItem = item.renamed(to: trimmedName) {
            print("Rename: Success! New item: \(renamedItem.name)")
            withAnimation(DroppyAnimation.state) {
                state.replaceBasketItem(item, with: renamedItem)
            }
        } else {
            print("Rename: Failed - renamed() returned nil")
        }
        renamingItemId = nil
        state.isRenaming = false
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
    let isRemovingBackground: Bool
    let isCompressing: Bool
    let isCreatingZIP: Bool
    let isSelected: Bool
    @Binding var isPoofing: Bool
    @Binding var pendingConvertedItem: DroppedItem?
    @Binding var renamingItemId: UUID?
    @Binding var renamingText: String
    let onRename: () -> Void
    
    // Extracted to fix compiler timeout on complex ternary
    private var containerFillColor: Color {
        // NATIVE: No container fill - just the icon
        return Color.clear
    }
    
    private var containerStrokeColor: Color {
        // NATIVE: Blue outline only when selected
        if isSelected { return Color.accentColor }
        return Color.clear
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // FINDER-STYLE: QuickLook previews preserve aspect ratio, native icons keep shape
                Group {
                    if let thumbnail = thumbnail {
                        // QuickLook preview: preserve aspect ratio like Finder
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    } else {
                        // Native icon (folders, dmg, zip, etc): keep original shape
                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .frame(width: 48, height: 48)
                // NO clipShape - native icons have their own shapes (folders, dmg, zip, etc.)
                // Subtle gray highlight when selected (like Finder)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                            .padding(-4)
                    }
                }
                .opacity((isConverting || isExtractingText || isCompressing || isCreatingZIP) ? 0.5 : 1.0)
                // Selection and processing overlays on icon only
                .overlay {
                    if isConverting || isExtractingText || isCompressing || isCreatingZIP {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                    }
                }
                .overlay {
                    // Magic processing animation for background removal
                    if isRemovingBackground || state.processingItemIds.contains(item.id) {
                        MagicProcessingOverlay()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .transition(.opacity.animation(DroppyAnimation.viewChange))
                    }
                }
                .frame(width: 56, height: 56)
                .padding(.top, 6) // Make room for X button above
                
                // Remove button on hover - hidden for pinned folders
                if isHovering && !isPoofing && renamingItemId != item.id && !item.isPinned {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white, .gray.opacity(0.8))
                    }
                    .buttonStyle(.borderless)
                    .offset(x: 4, y: 2) // Keep within bounds
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Filename or rename text field
            if renamingItemId == item.id {
                RenameTextField(
                    text: $renamingText,
                    isRenaming: Binding(
                        get: { renamingItemId == item.id },
                        set: { if !$0 { 
                            renamingItemId = nil
                            state.isRenaming = false
                            state.endFileOperation()
                        } }
                    ),
                    onRename: onRename
                )
                .onAppear {
                    renamingText = item.url.deletingPathExtension().lastPathComponent
                }
            } else {
                // FINDER-STYLE: Label with pill selection background
                Text(item.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.accentColor)
                        }
                    }
                    .frame(width: 64)
            }
        }
        .padding(.vertical, 2)
        .id(item.id)
        .poofEffect(isPoofing: $isPoofing) {
            if let newItem = pendingConvertedItem {
                withAnimation(DroppyAnimation.state) {
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

// MARK: - Rename Text Field with Auto-Select and Static Dotted Border
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
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        // Static dotted blue outline (no animation to save CPU)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    Color.accentColor.opacity(0.8),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        dash: [3, 3],
                        dashPhase: 0
                    )
                )
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
