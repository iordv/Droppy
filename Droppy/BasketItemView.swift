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
    let state: BasketState
    @Binding var renamingItemId: UUID?
    let onRemove: () -> Void
    var layoutMode: BasketItemLayout = .grid
    var listRowWidth: CGFloat? = nil  // CRITICAL: Fixed width for list mode to constrain text
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.enableNotchShelf) private var enableNotchShelf = PreferenceDefault.enableNotchShelf
    @AppStorage(AppPreferenceKey.enablePowerFolders) private var enablePowerFolders = PreferenceDefault.enablePowerFolders
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    @State private var isConverting = false
    @State private var isExtractingText = false
    @State private var isCreatingZIP = false
    @State private var isCompressing = false
    @State private var isUnzipping = false
    @State private var isRemovingBackground = false
    @State private var isPoofing = false
    @State private var pendingConvertedItem: DroppedItem?
    // Removed local isRenaming
    @State private var renamingText = ""
    
    // Feedback State
    @State private var shakeOffset: CGFloat = 0
    @State private var isShakeAnimating = false
    @State private var isDropTargeted = false  // For pinned folder drop zone
    @State private var isDraggingSelf = false   // Track when THIS item is being dragged
    @State private var showFolderPreview = false  // Delayed folder preview popover
    @State private var hoverTask: Task<Void, Never>?  // Task for delayed hover show
    @State private var dismissTask: Task<Void, Never>?  // Task for delayed hover dismiss (to reach popover)
    @State private var isHoveringPopover = false  // Track if cursor is over popover content
    @State private var cachedAvailableApps: [(name: String, icon: NSImage, url: URL)] = []
    @State private var cachedSharingServices: [NSSharingService] = []
    
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

    /// Approximate available width for filename in list rows.
    private var listNameWidth: CGFloat {
        let baseWidth = listRowWidth ?? 320
        return max(120, baseWidth - 150)
    }
    
    var body: some View {
        draggableItemContent
        .animation(DroppyAnimation.hoverBouncy, value: isHovering)
        .background(GeometryReader { geo in
            Color.clear.preference(
                key: ItemFramePreferenceKey.self,
                value: [item.id: geo.frame(in: .named("basketContainer"))]
            )
        })
        .popover(isPresented: renamePopoverPresented, arrowEdge: .top) {
            RenameTooltipPopover(
                text: $renamingText,
                title: String(localized: "action.edit"),
                placeholder: item.name,
                onSave: performRename,
                onCancel: {
                    renamePopoverPresented.wrappedValue = false
                }
            )
        }
    }

    private var renamePopoverPresented: Binding<Bool> {
        Binding(
            get: { renamingItemId == item.id },
            set: { isPresented in
                if !isPresented {
                    renamingItemId = nil
                    state.isRenaming = false
                    state.endFileOperation()
                }
            }
        )
    }

    @ViewBuilder
    private var draggableItemContent: some View {
        // MARK: - Pre-defined closures to help compiler type-check
        // (Breaking up complex expression that was timing out)
        
        let itemsClosure: () -> [NSPasteboardWriting] = {
            if state.selectedBasketItems.contains(item.id) {
                let selected = state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
                return selected.map { $0.url as NSURL }
            } else {
                return [item.url as NSURL]
            }
        }
        
        let tapClosure: (NSEvent.ModifierFlags) -> Void = { modifiers in
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            let cleanModifiers = modifiers.intersection(.deviceIndependentFlagsMask)
            if cleanModifiers.contains(.shift) {
                state.selectBasketRange(to: item, additive: cleanModifiers.contains(.command))
            } else if cleanModifiers.contains(.command) {
                state.toggleBasketSelection(item)
            } else {
                state.deselectAllBasket()
                state.selectBasket(item)
            }
        }
        
        let doubleClickClosure: () -> Void = {
            hoverTask?.cancel()
            hoverTask = nil
            showFolderPreview = false
            
            let ext = item.url.pathExtension.lowercased()
            if ["zip", "tar", "gz", "bz2", "xz", "7z"].contains(ext) {
                unzipFile()
                return
            }
            NSWorkspace.shared.open(item.url)
        }
        
        let rightClickClosure: () -> Void = {
            hoverTask?.cancel()
            hoverTask = nil
            showFolderPreview = false
            if !state.selectedBasketItems.contains(item.id) {
                state.deselectAllBasket()
                state.selectBasket(item)
            }
        }
        
        let dragStartClosure: () -> Void = {
            hoverTask?.cancel()
            hoverTask = nil
            showFolderPreview = false
            isDraggingSelf = true
            DragMonitor.shared.setSuppressBasketRevealForCurrentDrag(true)
        }
        
        let dragCompleteClosure: (NSDragOperation) -> Void = { [weak state] operation in
            isDraggingSelf = false
            DragMonitor.shared.setSuppressBasketRevealForCurrentDrag(false)
            guard let state = state else { return }
            let enableAutoClean = UserDefaults.standard.bool(forKey: "enableAutoClean")
            if enableAutoClean {
                withAnimation(DroppyAnimation.state) {
                    if state.selectedBasketItems.contains(item.id) {
                        let itemsToRemove = state.basketItems.filter { state.selectedBasketItems.contains($0.id) && !$0.isPinned }
                        for itemToRemove in itemsToRemove {
                            state.removeBasketItem(itemToRemove)
                        }
                        state.selectedBasketItems.removeAll()
                    } else if !item.isPinned {
                        state.removeBasketItem(item)
                    }
                }
            }
        }
        
        // Button callbacks - ONLY for grid mode which has visible X/pin buttons
        let removeButtonClosure: (() -> Void)? = layoutMode == .grid && !item.isPinned ? onRemove : nil
        let pinButtonClosure: (() -> Void)? = layoutMode == .grid && item.isDirectory ? {
            HapticFeedback.pin()
            state.togglePin(item)
        } : nil

        DraggableArea(
            items: itemsClosure,
            onTap: tapClosure,
            onDoubleClick: doubleClickClosure,
            onRightClick: rightClickClosure,
            onDragStart: dragStartClosure,
            onDragComplete: dragCompleteClosure,
            onRemoveButton: removeButtonClosure,
            onPinButton: pinButtonClosure,
            selectionSignature: state.selectedBasketItems.hashValue
        ) {
            Group {
                if layoutMode == .list {
                    // List row layout
                    HStack(spacing: 12) {
                        // Squircle thumbnail with activity overlay
                        ZStack {
                            Group {
                                if let thumb = thumbnail {
                                    // QuickLook preview thumbnail
                                    Image(nsImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    // Native macOS icon (folders, zip, dmg, etc.) - matches grid view
                                    RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                                        .fill(AdaptiveColors.overlayAuto(0.08))
                                        .overlay(
                                            Image(nsImage: ThumbnailCache.shared.cachedIcon(forPath: item.url.path))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 24, height: 24)
                                                // AUTO-TINT for Pinned Folders: Blue -> Yellow (+180 deg)
                                                .hueRotation(item.isPinned && item.isDirectory ? .degrees(180) : .degrees(0))
                                        )
                                }
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
                            
                            // Activity indicator overlay
                            if isConverting || isCompressing || isRemovingBackground || isExtractingText || isCreatingZIP {
                                RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
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
                                RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
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
                                            // List layout uses an inline checkmark instead of `.poofEffect`,
                                            // so apply the pending replacement here before ending the effect.
                                            if let newItem = pendingConvertedItem {
                                                withAnimation(DroppyAnimation.state) {
                                                    state.replaceBasketItem(item, with: newItem)
                                                }
                                                pendingConvertedItem = nil
                                            }
                                            withAnimation(DroppyAnimation.easeOut) {
                                                isPoofing = false
                                            }
                                        }
                                    }
                            }
                        }
                        
                        // Name and size
                        VStack(alignment: .leading, spacing: 2) {
                            SubtleScrollingText(
                                text: item.name,
                                font: .system(size: 13, weight: .medium),
                                foregroundStyle: AnyShapeStyle(isSelected ? .white : AdaptiveColors.primaryTextAuto),
                                maxWidth: listNameWidth,
                                lineLimit: 1,
                                alignment: .leading,
                                externallyHovered: isHovering
                            )
                            
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
                                    .foregroundStyle(isSelected ? .white.opacity(0.9) : AdaptiveColors.secondaryTextAuto.opacity(0.9))
                            } else {
                                Text(listFileSize)
                                    .font(.system(size: 11))
                                    .foregroundStyle(isSelected ? .white.opacity(0.9) : AdaptiveColors.secondaryTextAuto.opacity(0.9))
                            }
                        }
                        // Text container: MUST truncate, never expand
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clipped()  // CRITICAL: Force text truncation
                        
                        // File extension or folder badge - FIXED width, never shrink
                        Group {
                            if item.isDirectory {
                                Text("FOLDER")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(isSelected ? .white.opacity(0.85) : AdaptiveColors.secondaryTextAuto)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AdaptiveColors.overlayAuto(0.1)))
                            } else if !item.url.pathExtension.isEmpty {
                                Text(item.url.pathExtension.uppercased())
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(isSelected ? .white.opacity(0.85) : AdaptiveColors.secondaryTextAuto)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AdaptiveColors.overlayAuto(0.1)))
                            }
                        }
                        .fixedSize()  // Badge never shrinks
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    // CRITICAL: Fixed width inside DraggableArea to constrain text (matches ClipboardItemRow pattern)
                    .frame(width: listRowWidth)
                    .background(
                        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                            .fill(isSelected
                                  ? Color.blue.opacity(isHovering ? 1.0 : 0.8)
                                  : AdaptiveColors.overlayAuto(isHovering ? 0.18 : 0.12))
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
                        isUnzipping: isUnzipping,
                        isCreatingZIP: isCreatingZIP,
                        isSelected: isSelected,
                        renamingItemId: $renamingItemId,
                        isPoofing: $isPoofing,
                        pendingConvertedItem: $pendingConvertedItem,
                        onUnzip: unzipFile
                    )
                    .offset(x: shakeOffset)
                    .overlay(alignment: .center) {
                        if isShakeAnimating {
                            ZStack {
                                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                                    .fill(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
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
        }
        // Drop target for pinned folders - drop files INTO the folder
        // CRITICAL: Disable when this item is being dragged to prevent gesture conflict
        .dropDestination(for: URL.self) { urls, location in
            guard !isDraggingSelf && enablePowerFolders && item.isPinned && item.isDirectory else { return false }
            moveFilesToFolder(urls: urls, destination: item.url)
            return true
        } isTargeted: { targeted in
            guard !isDraggingSelf && enablePowerFolders && item.isPinned && item.isDirectory else { return }
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
                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
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
                    // Cancel any pending dismiss when returning to folder
                    dismissTask?.cancel()
                    dismissTask = nil
                    
                    hoverTask = Task {
                        try? await Task.sleep(nanoseconds: 800_000_000)  // 0.8s delay
                        if !Task.isCancelled && !isDropTargeted && !state.isInteractionBlocked {
                            showFolderPreview = true
                        }
                    }
                } else {
                    // Cancel pending show task
                    hoverTask?.cancel()
                    hoverTask = nil
                    
                    // Delayed dismiss - give user time to reach the popover
                    if showFolderPreview {
                        dismissTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3s grace period
                            // Only dismiss if cursor hasn't moved to the popover
                            if !Task.isCancelled && !isHoveringPopover && !isHovering {
                                showFolderPreview = false
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: state.isInteractionBlocked) { _, blocked in
            if blocked {
                hoverTask?.cancel()
                hoverTask = nil
                dismissTask?.cancel()
                dismissTask = nil
                showFolderPreview = false
                isHovering = false
            }
        }
        .popover(isPresented: $showFolderPreview, arrowEdge: .bottom) {
            FolderPreviewPopover(
                folderURL: item.url,
                isPinned: item.isPinned,
                isHovering: $isHoveringPopover
            )
        }
        .onChange(of: isHoveringPopover) { _, hovering in
            // When cursor leaves the popover, dismiss after grace period (if not back on folder)
            if !hovering && showFolderPreview {
                dismissTask?.cancel()
                dismissTask = Task {
                    try? await Task.sleep(nanoseconds: 150_000_000)  // 150ms to allow return to folder
                    if !Task.isCancelled && !isHoveringPopover && !isHovering {
                        showFolderPreview = false
                    }
                }
            } else if hovering {
                // Cancel any pending dismiss when entering popover
                dismissTask?.cancel()
                dismissTask = nil
            }
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
            refreshContextMenuCache()
        }
        .onChange(of: item.url) { _, _ in
            refreshContextMenuCache()
            thumbnail = nil
        }
        .contextMenu {
            contextMenuContent()
        }
        .task(id: item.url) {
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
    
    // MARK: - Reorder Mode Content

    @ViewBuilder
    private var basketItemContent: some View {
        if layoutMode == .list {
            // List row layout
            HStack(spacing: 12) {
                // Squircle thumbnail with activity overlay
                ZStack {
                    Group {
                        if let thumb = thumbnail {
                            // QuickLook preview thumbnail
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            // Native macOS icon (folders, zip, dmg, etc.) - matches grid view
                            RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                                .fill(AdaptiveColors.overlayAuto(0.08))
                                .overlay(
                                    Image(nsImage: ThumbnailCache.shared.cachedIcon(forPath: item.url.path))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        // AUTO-TINT for Pinned Folders: Blue -> Yellow (+180 deg)
                                        .hueRotation(item.isPinned && item.isDirectory ? .degrees(180) : .degrees(0))
                                )
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
                    
                    // Activity indicator overlay
                    if isConverting || isCompressing || isRemovingBackground || isExtractingText || isCreatingZIP {
                        RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
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
                        RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
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
                
                // Name and size
                VStack(alignment: .leading, spacing: 2) {
                    SubtleScrollingText(
                        text: item.name,
                        font: .system(size: 13, weight: .medium),
                        foregroundStyle: AnyShapeStyle(isSelected ? .white : AdaptiveColors.primaryTextAuto),
                        maxWidth: listNameWidth,
                        lineLimit: 1,
                        alignment: .leading,
                        externallyHovered: isHovering
                    )
                    
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
                            .foregroundStyle(isSelected ? .white.opacity(0.9) : AdaptiveColors.secondaryTextAuto.opacity(0.9))
                    } else {
                        Text(listFileSize)
                            .font(.system(size: 11))
                            .foregroundStyle(isSelected ? .white.opacity(0.9) : AdaptiveColors.secondaryTextAuto.opacity(0.9))
                    }
                }
                // Text container: MUST truncate, never expand
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()  // CRITICAL: Force text truncation
                
                // File extension or folder badge - FIXED width, never shrink
                Group {
                    if item.isDirectory {
                        Text("FOLDER")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isSelected ? .white.opacity(0.85) : AdaptiveColors.secondaryTextAuto)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AdaptiveColors.overlayAuto(0.1)))
                    } else if !item.url.pathExtension.isEmpty {
                        Text(item.url.pathExtension.uppercased())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isSelected ? .white.opacity(0.85) : AdaptiveColors.secondaryTextAuto)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AdaptiveColors.overlayAuto(0.1)))
                    }
                }
                .fixedSize()  // Badge never shrinks
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // CRITICAL: Fixed width inside DraggableArea to constrain text (matches ClipboardItemRow pattern)
            .frame(width: listRowWidth)
            .background(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .fill(isSelected 
                          ? Color.blue.opacity(isHovering ? 1.0 : 0.8)
                          : AdaptiveColors.overlayAuto(isHovering ? 0.18 : 0.12))
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
                isUnzipping: isUnzipping,
                isCreatingZIP: isCreatingZIP,
                isSelected: isSelected,
                renamingItemId: $renamingItemId,
                isPoofing: $isPoofing,
                pendingConvertedItem: $pendingConvertedItem,
                onUnzip: unzipFile
            )
            .offset(x: shakeOffset)
            .overlay(alignment: .center) {
                if isShakeAnimating {
                    ZStack {
                        RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                            .fill(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
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
        let availableApps = cachedAvailableApps
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
            ForEach(cachedSharingServices, id: \.title) { service in
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
        if !ExtensionType.quickshare.isRemoved {
            Button {
                let itemsToShare = state.selectedBasketItems.isEmpty
                    ? [item.url]
                    : state.basketItems.filter { state.selectedBasketItems.contains($0.id) }.map { $0.url }
                DroppyQuickshare.share(urls: itemsToShare)
            } label: {
                Label("Droppy Quickshare", systemImage: "drop.fill")
            }
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
        
        // Unzip option - only for archive files
        let archiveExtensions = ["zip", "tar", "gz", "bz2", "xz", "7z"]
        let itemExt = item.url.pathExtension.lowercased()
        if archiveExtensions.contains(itemExt) && state.selectedBasketItems.count <= 1 {
            Button {
                unzipFile()
            } label: {
                Label("Unzip", systemImage: "arrow.up.bin")
            }
            .disabled(isUnzipping)
        }
        
        // Create Folder option - for non-archive files
        if !archiveExtensions.contains(itemExt) && !item.isDirectory {
            Button {
                createFolderForSelection()
            } label: {
                if state.selectedBasketItems.count > 1 && state.selectedBasketItems.contains(item.id) {
                    Label("Create Folder (\(state.selectedBasketItems.count))", systemImage: "folder.badge.plus")
                } else {
                    Label("Create Folder", systemImage: "folder.badge.plus")
                }
            }
        }
        
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
                // Handle multi-selection: move all selected items if this item is selected
                let itemsToMove = state.selectedBasketItems.contains(item.id) 
                    ? state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
                    : [item]
                
                for moveItem in itemsToMove {
                    DroppyState.shared.addItem(moveItem)
                    state.removeBasketItemForTransfer(moveItem)  // Transfer-safe: don't delete file
                }
                state.deselectAllBasket()
            } label: {
                if state.selectedBasketItems.count > 1 && state.selectedBasketItems.contains(item.id) {
                    Label("Move to Shelf (\(state.selectedBasketItems.count))", systemImage: "arrow.up.to.line")
                } else {
                    Label("Move to Shelf", systemImage: "arrow.up.to.line")
                }
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

    private func refreshContextMenuCache() {
        cachedAvailableApps = item.getAvailableApplications()
        cachedSharingServices = sharingServicesForItems([item.url])
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
                        state.removeBasketItem(item, allowPinnedRemoval: true)
                    }
                } catch {
                    // Fallback copy+delete mechanism
                    do {
                        try FileManager.default.copyItem(at: item.url, to: destination.appendingPathComponent(item.url.lastPathComponent))
                        try FileManager.default.removeItem(at: item.url)
                        
                        DispatchQueue.main.async {
                            state.removeBasketItem(item, allowPinnedRemoval: true)
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
    
    /// Moves or copies external files (from drag) into a folder
    /// Respects "Protect Originals" setting: copies when ON, moves when OFF
    private func moveFilesToFolder(urls: [URL], destination: URL) {
        // Read preference on main thread before dispatching
        let protectOriginals = UserDefaults.standard.bool(forKey: AppPreferenceKey.alwaysCopyOnDrag)
        
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
                    
                    if protectOriginals {
                        // Copy file into folder (safe - source remains)
                        try FileManager.default.copyItem(at: url, to: finalDestURL)
                        print("📁 Copied \(url.lastPathComponent) into \(destination.lastPathComponent)")
                    } else {
                        // Move file into folder (source deleted)
                        try FileManager.default.moveItem(at: url, to: finalDestURL)
                        print("📁 Moved \(url.lastPathComponent) into \(destination.lastPathComponent)")
                    }
                } catch {
                    print("❌ Failed to \(protectOriginals ? "copy" : "move") file into folder: \(error.localizedDescription)")
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
                    OCRWindowController.shared.presentExtractedText(text)
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
    
    /// Unzip an archive file, replacing it with the extracted folder
    private func unzipFile() {
        let ext = item.url.pathExtension.lowercased()
        // Extraction command below uses zip-specific flags.
        guard ext == "zip" else { return }
        guard !isUnzipping else { return }
        
        isUnzipping = true
        state.beginFileOperation()
        HapticFeedback.tap()
        
        Task {
            let destFolder = item.url.deletingPathExtension()
            var finalDestFolder = destFolder
            var counter = 1
            
            // Handle name collisions
            while FileManager.default.fileExists(atPath: finalDestFolder.path) {
                finalDestFolder = destFolder.deletingLastPathComponent()
                    .appendingPathComponent("\(destFolder.lastPathComponent) \(counter)")
                counter += 1
            }
            
            do {
                // Use ditto for extraction (handles zip, tar, and more)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-x", "-k", item.url.path, finalDestFolder.path]
                
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    let newItem = DroppedItem(url: finalDestFolder)
                    
                    await MainActor.run {
                        withAnimation(DroppyAnimation.state) {
                            state.replaceBasketItem(item, with: newItem)
                        }
                        HapticFeedback.drop()
                    }
                } else {
                    print("❌ Unzip failed with status: \(process.terminationStatus)")
                    await MainActor.run { HapticFeedback.error() }
                }
            } catch {
                print("❌ Unzip error: \(error.localizedDescription)")
                await MainActor.run { HapticFeedback.error() }
            }
            
            await MainActor.run {
                isUnzipping = false
                state.endFileOperation()
            }
        }
    }
    
    /// Create a folder for the selected files and move them into it
    private func createFolderForSelection() {
        let fm = FileManager.default
        HapticFeedback.tap()
        
        // Get items to process
        let itemsToProcess: [DroppedItem]
        if state.selectedBasketItems.count > 1 && state.selectedBasketItems.contains(item.id) {
            itemsToProcess = state.basketItems.filter { state.selectedBasketItems.contains($0.id) }
        } else {
            itemsToProcess = [item]
        }
        
        guard !itemsToProcess.isEmpty else { return }
        
        // Determine folder name
        let folderName: String
        if itemsToProcess.count == 1 {
            // Single file: use file name without extension
            folderName = itemsToProcess[0].url.deletingPathExtension().lastPathComponent
        } else {
            // Multiple files: use "New Folder"
            folderName = "New Folder"
        }
        
        // Get parent directory from first item
        let parentDir = itemsToProcess[0].url.deletingLastPathComponent()
        var folderURL = parentDir.appendingPathComponent(folderName)
        
        // Handle name collisions
        var counter = 1
        while fm.fileExists(atPath: folderURL.path) {
            folderURL = parentDir.appendingPathComponent("\(folderName) \(counter)")
            counter += 1
        }
        
        do {
            // Create the folder
            try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
            // Move all items into the folder
            for fileItem in itemsToProcess {
                let destURL = folderURL.appendingPathComponent(fileItem.url.lastPathComponent)
                try fm.moveItem(at: fileItem.url, to: destURL)
            }
            
            // Create new DroppedItem for the folder
            let newFolderItem = DroppedItem(url: folderURL)
            
            // Replace items in basket with the new folder (atomic operation like ZIP creation)
            withAnimation(DroppyAnimation.state) {
                state.replaceBasketItems(itemsToProcess, with: newFolderItem)
            }
            
            state.deselectAllBasket()
            HapticFeedback.drop()
            
            // Auto-start renaming the new folder (like ZIP creation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                renamingItemId = newFolderItem.id
                state.isRenaming = true
            }
        } catch {
            print("❌ Create folder error: \(error.localizedDescription)")
            HapticFeedback.error()
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
        renamingText = item.url.deletingPathExtension().lastPathComponent
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
    let state: BasketState
    let onRemove: () -> Void
    let thumbnail: NSImage?
    let isHovering: Bool
    let isConverting: Bool
    let isExtractingText: Bool
    let isRemovingBackground: Bool
    let isCompressing: Bool
    let isUnzipping: Bool
    let isCreatingZIP: Bool
    let isSelected: Bool
    @Binding var renamingItemId: UUID?
    @Binding var isPoofing: Bool
    @Binding var pendingConvertedItem: DroppedItem?
    let onUnzip: () -> Void
    
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
                            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xs, style: .continuous))
                    } else {
                        // Native icon (folders, dmg, zip, etc): keep original shape
                        Image(nsImage: ThumbnailCache.shared.cachedIcon(forPath: item.url.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            // AUTO-TINT for Pinned Folders: Blue -> Yellow (+180 deg)
                            .hueRotation(item.isPinned && item.isDirectory ? .degrees(180) : .degrees(0))
                    }
                }
                .frame(width: 48, height: 48)
                // NO clipShape - native icons have their own shapes (folders, dmg, zip, etc.)
                // Subtle gray highlight when selected (like Finder)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                            .fill(AdaptiveColors.overlayAuto(0.15))
                            .padding(-4)
                    }
                }
                .opacity((isConverting || isExtractingText || isCompressing || isUnzipping || isCreatingZIP) ? 0.5 : 1.0)
                // Selection and processing overlays on icon only
                .overlay {
                    if isConverting || isExtractingText || isCompressing || isUnzipping || isCreatingZIP {
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
                            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xs, style: .continuous))
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
                
                // Pin toggle button for folders on hover
                if isHovering && !isPoofing && item.isDirectory && renamingItemId != item.id {
                    Button {
                        HapticFeedback.pin()
                        state.togglePin(item)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(item.isPinned ? Color.orange : AdaptiveColors.overlayAuto(0.9))
                                .frame(width: 18, height: 18)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            
                            Image(systemName: item.isPinned ? "pin.slash.fill" : "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(item.isPinned ? .white : .orange)
                        }
                    }
                    .buttonStyle(.borderless)
                    .offset(x: 4, y: 54) // Bottom-right of icon
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // FINDER-STYLE: Label with pill selection background and subtle scroll for long names
            SubtleScrollingText(
                text: item.name,
                font: .system(size: 11),
                foregroundStyle: AnyShapeStyle(isSelected ? .white : AdaptiveColors.primaryTextAuto),
                maxWidth: 64,
                lineLimit: 1,
                alignment: .center,
                externallyHovered: isHovering
            )
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: DroppyRadius.xs, style: .continuous)
                        .fill(Color.accentColor)
                }
            }
        }
        .padding(.vertical, 2)
        .id(item.id)
        // Double-click to unzip archive files
        .onTapGesture(count: 2) {
            let ext = item.url.pathExtension.lowercased()
            if ["zip", "tar", "gz", "bz2", "xz", "7z"].contains(ext) {
                onUnzip()
            }
        }
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
        textField.font = .systemFont(ofSize: 14, weight: .medium)
        textField.alignment = .left
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

private struct RenameTooltipPopover: View {
    @Binding var text: String
    let title: String
    let placeholder: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
            
            AutoSelectTextField(
                text: $text,
                onSubmit: onSave,
                onCancel: onCancel
            )
            .font(.system(size: 14, weight: .medium))
            .droppyTextInputChrome()
            .accessibilityLabel(Text(placeholder))
            
            HStack(spacing: 10) {
                Button {
                    onCancel()
                } label: {
                    Text(String(localized: "action.cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                Button {
                    onSave()
                } label: {
                    Text(String(localized: "action.save"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                .disabled(trimmedText.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 260)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AdaptiveColors.panelBackgroundAuto.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AdaptiveColors.subtleBorderAuto.opacity(0.9), lineWidth: 1)
                )
        }
    }
}
