import SwiftUI
import UniformTypeIdentifiers

// MARK: - Notch Shelf Item Components
// Extracted from NotchShelfView.swift for faster incremental builds

struct NotchItemView: View {
    let item: DroppedItem
    let state: DroppyState
    @Binding var renamingItemId: UUID?
    let onRemove: () -> Void
    
    @AppStorage(AppPreferenceKey.enablePowerFolders) private var enablePowerFolders = PreferenceDefault.enablePowerFolders
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    @State private var isHoveringPopover = false
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
    
    // MARK: - Bulk Operation Helpers
    
    /// All selected items in the shelf
    private var selectedItems: [DroppedItem] {
        state.items.filter { state.selectedItems.contains($0.id) }
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
        return FileConverter.availableConversions(for: selectedItems.first?.fileType)
            .filter { validFormats.contains($0.format) }
    }
    
    private func chooseDestinationAndMove() {
        // Dispatch to main async to allow the menu to close and UI to settle
        DispatchQueue.main.async {
            // Ensure the app is active so the panel appears on top
            NSApp.activate(ignoringOtherApps: true)
            
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Move Here"
            panel.message = "Choose a destination to move the selected files."
            
            // Use runModal for a simpler blocking flow in this context, 
            // or begin with completion. runModal is often more reliable for "popup" utilities.
            if panel.runModal() == .OK, let url = panel.url {
                DestinationManager.shared.addDestination(url: url)
                moveFiles(to: url)
            }
        }
    }
    
    private func moveFiles(to destination: URL) {
        let itemsToMove = state.selectedItems.isEmpty ? [item] : state.items.filter { state.selectedItems.contains($0.id) }
        
        // Run file operations in background to prevent UI freezing (especially for NAS/Network drives)
        DispatchQueue.global(qos: .userInitiated).async {
            for item in itemsToMove {
                do {
                    let destURL = destination.appendingPathComponent(item.url.lastPathComponent)
                    var finalDestURL = destURL
                    var counter = 1
                    
                    // Check existence (this is fast usually, but good to be in bg for network drives)
                    while FileManager.default.fileExists(atPath: finalDestURL.path) {
                        let ext = destURL.pathExtension
                        let name = destURL.deletingPathExtension().lastPathComponent
                        let newName = "\(name) \(counter)" + (ext.isEmpty ? "" : ".\(ext)")
                        finalDestURL = destination.appendingPathComponent(newName)
                        counter += 1
                    }
                    
                    // Try primitive move first
                    try FileManager.default.moveItem(at: item.url, to: finalDestURL)
                    
                    // Update UI on Main Thread
                    DispatchQueue.main.async {
                        state.removeItem(item)
                    }
                } catch {
                    // Fallback copy+delete mechanism for cross-volume moves
                    do {
                        try FileManager.default.copyItem(at: item.url, to: destination.appendingPathComponent(item.url.lastPathComponent))
                        try FileManager.default.removeItem(at: item.url)
                        
                        DispatchQueue.main.async {
                            state.removeItem(item)
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

    var body: some View {
        // MARK: - Pre-defined closures to help compiler type-check
        // (Breaking up complex expression that was timing out)
        
        let itemsClosure: () -> [NSPasteboardWriting] = {
            if state.selectedItems.contains(item.id) {
                let selected = state.items.filter { state.selectedItems.contains($0.id) }
                return selected.map { $0.url as NSURL }
            } else {
                return [item.url as NSURL]
            }
        }
        
        let tapClosure: (NSEvent.ModifierFlags) -> Void = { modifiers in
            print("📌 onTap callback triggered for item: \(item.url.lastPathComponent)")
            if modifiers.contains(.command) {
                state.toggleSelection(item)
            } else if modifiers.contains(.shift) {
                state.selectRange(to: item)
            } else {
                state.deselectAll()
                state.select(item)
            }
            print("📌 Selection now contains: \(state.selectedItems.count) items")
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
            if !state.selectedItems.contains(item.id) {
                state.deselectAll()
                state.select(item)
            }
        }
        
        let dragStartClosure: () -> Void = {
            hoverTask?.cancel()
            hoverTask = nil
            showFolderPreview = false
            isDraggingSelf = true
        }
        
        let dragCompleteClosure: (NSDragOperation) -> Void = { [weak state] operation in
            isDraggingSelf = false
            guard let state = state else { return }
            let enableAutoClean = UserDefaults.standard.bool(forKey: "enableAutoClean")
            if enableAutoClean {
                withAnimation(DroppyAnimation.state) {
                    if state.selectedItems.contains(item.id) {
                        let itemsToRemove = state.items.filter { state.selectedItems.contains($0.id) && !$0.isPinned }
                        for itemToRemove in itemsToRemove {
                            state.removeItem(itemToRemove)
                        }
                        state.selectedItems.removeAll()
                    } else if !item.isPinned {
                        state.removeItem(item)
                    }
                }
            }
        }
        
        let pinButtonClosure: (() -> Void)? = item.isDirectory ? {
            HapticFeedback.pin()
            state.togglePin(item)
        } : nil
        
        return DraggableArea(
            items: itemsClosure,
            onTap: tapClosure,
            onDoubleClick: doubleClickClosure,
            onRightClick: rightClickClosure,
            onDragStart: dragStartClosure,
            onDragComplete: dragCompleteClosure,
            onRemoveButton: item.isPinned ? nil : onRemove,
            onPinButton: pinButtonClosure,
            selectionSignature: state.selectedItems.hashValue
        ) {
            NotchItemContent(
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
                isPoofing: $isPoofing,
                pendingConvertedItem: $pendingConvertedItem,
                renamingItemId: $renamingItemId,
                renamingText: $renamingText,
                onRename: performRename,
                onUnzip: unzipFile
            )
            .offset(x: shakeOffset)
            .overlay(alignment: .center) {
                if isShakeAnimating {
                    ZStack {
                        // NOTE: Part of shelf UI - always solid black
                        RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                            .fill(Color.black)
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
            .background {
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ItemFramePreferenceKey.self,
                            value: [item.id: geo.frame(in: .named("shelfGrid"))]
                        )
                }
            }
            // Drop target for ANY folder - drop files INTO the folder
            // CRITICAL: Disable when this item is being dragged to prevent gesture conflict
            .dropDestination(for: URL.self) { urls, location in
                guard !isDraggingSelf && item.isDirectory else { return false }
                moveFilesToFolder(urls: urls, destination: item.url)
                return true
            } isTargeted: { targeted in
                guard !isDraggingSelf && item.isDirectory else { return }
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
                // Visual feedback when dropping files onto ANY folder (Dark overlay)
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 56, height: 56)
                        .offset(y: -14)
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
                        // Grace period before dismissal to allow reaching popover
                        hoverTask?.cancel()
                        hoverTask = Task {
                            // Grace period (0.3s to reach popover)
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            
                            // Check if we moved INTO the popover or back to the item
                            if !Task.isCancelled && !isHoveringPopover && !isHovering {
                                await MainActor.run {
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
                    hoverTask?.cancel()
                    hoverTask = Task {
                        try? await Task.sleep(nanoseconds: 150_000_000)  // 150ms to allow return to folder
                        if !Task.isCancelled && !isHoveringPopover && !isHovering {
                            showFolderPreview = false
                        }
                    }
                } else if hovering {
                    // Cancel any pending dismiss when entering popover
                    hoverTask?.cancel()
                    hoverTask = nil
                }
            }
            .onChange(of: state.poofingItemIds) { _, newIds in
                if newIds.contains(item.id) {
                    withAnimation(DroppyAnimation.state) {
                        isPoofing = true
                    }
                    state.clearPoof(for: item.id)
                }
            }
            .onAppear {
                if state.poofingItemIds.contains(item.id) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(DroppyAnimation.state) {
                            isPoofing = true
                        }
                        state.clearPoof(for: item.id)
                    }
                }
            }
            .contextMenu {
            Button {
                state.copyToClipboard()
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
                let itemsToShare = state.selectedItems.isEmpty
                    ? [item.url]
                    : state.items.filter { state.selectedItems.contains($0.id) }.map { $0.url }
                DroppyQuickshare.share(urls: itemsToShare)
            } label: {
                Label("Droppy Quickshare", systemImage: "drop.fill")
            }
            
            Button {
                // Bulk save: save all selected items
                if state.selectedItems.count > 1 && state.selectedItems.contains(item.id) {
                    for selectedItem in selectedItems {
                        selectedItem.saveToDownloads()
                    }
                } else {
                    item.saveToDownloads()
                }
            } label: {
                if state.selectedItems.count > 1 && state.selectedItems.contains(item.id) {
                    Label("Save All (\(state.selectedItems.count))", systemImage: "arrow.down.circle")
                } else {
                    Label("Save", systemImage: "arrow.down.circle")
                }
            }
            
            // Conversion submenu - show when single item OR all selected share common conversions
            let conversions = state.selectedItems.count > 1 ? commonConversions : FileConverter.availableConversions(for: item.fileType)
            if !conversions.isEmpty {
                Divider()
                
                Menu {
                    ForEach(conversions) { option in
                        Button {
                            if state.selectedItems.count > 1 && state.selectedItems.contains(item.id) {
                                convertAllSelected(to: option.format)
                            } else {
                                convertFile(to: option.format)
                            }
                        } label: {
                            Label(option.displayName, systemImage: option.icon)
                        }
                    }
                } label: {
                    if state.selectedItems.count > 1 && state.selectedItems.contains(item.id) {
                        Label("Convert All (\(state.selectedItems.count))...", systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label("Convert to...", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            
            // OCR Option - single item only
            if state.selectedItems.count <= 1 {
                if item.fileType?.conforms(to: .image) == true || item.fileType?.conforms(to: .pdf) == true {
                    Button {
                        extractText()
                    } label: {
                        Label("Extract Text", systemImage: "text.viewfinder")
                    }
                }
            }
            
            // Remove Background - show when single image OR all selected are images
            if (state.selectedItems.count <= 1 && item.isImage) || (state.selectedItems.count > 1 && allSelectedAreImages && state.selectedItems.contains(item.id)) {
                if AIInstallManager.shared.isInstalled {
                    Button {
                        if state.selectedItems.count > 1 {
                            removeBackgroundFromAllSelected()
                        } else {
                            removeBackground()
                        }
                    } label: {
                        if state.selectedItems.count > 1 {
                            Label("Remove Background (\(state.selectedItems.count))", systemImage: "person.and.background.dotted")
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
            
            // Create ZIP option
            Divider()
            
            // Compress option - show when single compressible OR all selected can compress
            let canShowCompress = (state.selectedItems.count <= 1 && FileCompressor.canCompress(fileType: item.fileType)) ||
                                  (state.selectedItems.count > 1 && allSelectedCanCompress && state.selectedItems.contains(item.id))
            if canShowCompress {
                let isMultiSelect = state.selectedItems.count > 1 && state.selectedItems.contains(item.id)
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
                            Label("Compress All (\(state.selectedItems.count))", systemImage: "arrow.down.right.and.arrow.up.left")
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
                            Label("Compress All (\(state.selectedItems.count))", systemImage: "arrow.down.right.and.arrow.up.left")
                        } else {
                            Label("Compress", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                    }
                    .disabled(isCompressing)
                }
            }
            
            Button {
                createZIPFromSelection()
            } label: {
                Label("Create ZIP", systemImage: "doc.zipper")
            }
            .disabled(isCreatingZIP)
            
            // Rename option (single item only)
            if state.selectedItems.count <= 1 {
                Button {
                    startRenaming()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
            
            // Pin/Unpin option for folders
            if item.isDirectory && state.selectedItems.count <= 1 {
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
            
            Divider()
            
            // Hide delete button for pinned folders - must unpin first
            if !item.isPinned {
                Button(role: .destructive, action: {
                     if state.selectedItems.contains(item.id) {
                         state.removeSelectedItems()
                     } else {
                         onRemove()
                     }
                }) {
                    Label("Remove from Shelf", systemImage: "xmark")
                }
            }
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
            .animation(DroppyAnimation.hoverBouncy, value: isHovering)
        } // DraggableArea closes here
    }
    
    // MARK: - OCR
    
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
    
    // MARK: - Conversion
    
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
                let requiredApp = FileConverter.requiredAppForPDFConversion(fileType: item.fileType) ?? "Keynote, Pages, Numbers, or LibreOffice"
                await DroppyAlertController.shared.showError(
                    title: "Conversion Failed",
                    message: "Could not convert \(item.name) to PDF. Please install \(requiredApp) (free from App Store) or LibreOffice."
                )
            }
        }
    }
    
    // MARK: - ZIP Creation
    
    private func createZIPFromSelection() {
        guard !isCreatingZIP else { return }
        
        // Determine items to include: selected items or just this item
        let itemsToZip: [DroppedItem]
        if state.selectedItems.isEmpty || (state.selectedItems.count == 1 && state.selectedItems.contains(item.id)) {
            itemsToZip = [item]
        } else {
            itemsToZip = state.items.filter { state.selectedItems.contains($0.id) }
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
                    // Update state immediately (animation deferred to poof effect)
                    state.replaceItems(itemsToZip, with: newItem)
                    // Auto-start renaming the new zip file (flag stays true)
                    renamingItemId = newItem.id
                    // Trigger poof animation after view has appeared
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
                // No explicit mode means request Target Size (for images)
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
                    // Clean up after slight delay to ensure poof is seen
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        await MainActor.run {
                            state.replaceItem(item, with: newItem)
                            isPoofing = false
                        }
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
                        withAnimation { shakeOffset = 0 }
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        withAnimation { isShakeAnimating = false }
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
                        state.replaceItem(selectedItem, with: newItem)
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
                        state.replaceItem(selectedItem, with: newItem)
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
        guard ["zip", "tar", "gz", "bz2", "xz", "7z"].contains(ext) else { return }
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
                            state.replaceItem(item, with: newItem)
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
                        state.replaceItem(selectedItem, with: newItem)
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
        // Set the text to filename without extension for easier editing
        state.beginFileOperation()
        state.isRenaming = true
        renamingItemId = item.id
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
                state.replaceItem(item, with: renamedItem)
            }
        } else {
            print("Rename: Failed - renamed() returned nil")
        }
        renamingItemId = nil
        state.isRenaming = false
        state.endFileOperation()
    }
}

// MARK: - Helper Views

struct NotchControlButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(DroppyCircleButtonStyle(size: 32))
    }
}

// MARK: - Preferences for Marquee Selection
struct ItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}



// MARK: - Notch Item Content
private struct NotchItemContent: View {
    let item: DroppedItem
    let state: DroppyState
    let onRemove: () -> Void
    let thumbnail: NSImage?
    let isHovering: Bool
    let isConverting: Bool
    let isExtractingText: Bool
    let isRemovingBackground: Bool
    let isCompressing: Bool
    let isUnzipping: Bool
    let isCreatingZIP: Bool
    @Binding var isPoofing: Bool
    @Binding var pendingConvertedItem: DroppedItem?
    @Binding var renamingItemId: UUID?
    @Binding var renamingText: String
    let onRename: () -> Void
    let onUnzip: () -> Void
    
    private var isSelected: Bool {
        state.selectedItems.contains(item.id)
    }
    
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
                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            // AUTO-TINT for Pinned Folders: Blue -> Yellow (+180 deg)
                            .hueRotation(item.isPinned && item.isDirectory ? .degrees(180) : .degrees(0))
                    }
                }
                .frame(width: 48, height: 48)
                // NO clipShape - keep exact Finder icon shapes
                // Subtle gray highlight when selected (like Finder)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                            .fill(Color.white.opacity(0.15))
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
                                .fill(item.isPinned ? Color.orange : Color.white.opacity(0.9))
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
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 64)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: DroppyRadius.xs, style: .continuous)
                                .fill(Color.accentColor)
                        }
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
                    state.replaceItem(item, with: newItem)
                }
                pendingConvertedItem = nil
            }
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
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        // Static dotted blue outline (no animation to save CPU)
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
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
        DispatchQueue.main.async {
            // CRITICAL: Make the window key first so it can receive keyboard input
            textField.window?.makeKeyAndOrderFront(nil)
            textField.window?.makeFirstResponder(textField)
            textField.selectText(nil)
            textField.currentEditor()?.selectedRange = NSRange(location: 0, length: textField.stringValue.count)
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

