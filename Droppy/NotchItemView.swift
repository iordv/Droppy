import SwiftUI
import UniformTypeIdentifiers

// MARK: - Notch Shelf Item Components
// Extracted from NotchShelfView.swift for faster incremental builds

struct NotchItemView: View {
    let item: DroppedItem
    let state: DroppyState
    @Binding var renamingItemId: UUID?
    let onRemove: () -> Void
    
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

    var body: some View {
        DraggableArea(
            items: {
                // If this item is selected, drag all selected items.
                // Otherwise, drag only this item.
                if state.selectedItems.contains(item.id) {
                    let selected = state.items.filter { state.selectedItems.contains($0.id) }
                    return selected.map { $0.url as NSURL }
                } else {
                    return [item.url as NSURL]
                }
            },
            onTap: { modifiers in
                // Handle Selection
                if modifiers.contains(.command) {
                    state.toggleSelection(item)
                } else if modifiers.contains(.shift) {
                    state.selectRange(to: item)
                } else {
                    state.deselectAll()
                    state.select(item)
                }
            },
            onRightClick: {
                // Select if not selected
                 if !state.selectedItems.contains(item.id) {
                    state.deselectAll()
                    state.select(item)
                }
            },
            onDragComplete: { [weak state] operation in
                guard let state = state else { return }
                // Auto-clean: remove only the dragged items, not everything
                let enableAutoClean = UserDefaults.standard.bool(forKey: "enableAutoClean")
                if enableAutoClean {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        // If this item was selected, remove all selected items
                        if state.selectedItems.contains(item.id) {
                            let idsToRemove = state.selectedItems
                            state.items.removeAll { idsToRemove.contains($0.id) }
                            state.selectedItems.removeAll()
                        } else {
                            // Otherwise just remove this single item
                            state.items.removeAll { $0.id == item.id }
                        }
                    }
                }
            },
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
                isCreatingZIP: isCreatingZIP,
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
                        // NOTE: Part of shelf UI - always solid black
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
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
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .onChange(of: state.poofingItemIds) { _, newIds in
                if newIds.contains(item.id) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPoofing = true
                    }
                    state.clearPoof(for: item.id)
                }
            }
            .onAppear {
                if state.poofingItemIds.contains(item.id) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
            
            Divider()
            
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
            .task {
                // INSTANT DISPLAY: Show fast icon immediately (zero lag)
                thumbnail = item.icon
                
                // ASYNC UPGRADE: Load high-quality QuickLook thumbnail in background
                // This may trigger Metal shader compilation on first use, but user sees icon instantly
                if let cached = ThumbnailCache.shared.cachedThumbnail(for: item) {
                    thumbnail = cached
                } else if let asyncThumbnail = await ThumbnailCache.shared.loadThumbnailAsync(for: item, size: CGSize(width: 120, height: 120)) {
                    // Smooth swap to better thumbnail
                    withAnimation(.easeInOut(duration: 0.15)) {
                        thumbnail = asyncThumbnail
                    }
                }
            }
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                
                await MainActor.run {
                    isCompressing = false
                    state.endFileOperation()
                    pendingConvertedItem = newItem
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPoofing = true
                    }
                }
            } catch {
                await MainActor.run {
                    isRemovingBackground = false
                    state.endFileOperation()
                    print("Background removal failed: \(error.localizedDescription)")
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(isHovering ? 0.2 : 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { mirroring in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovering = mirroring
            }
        }
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
    let isCreatingZIP: Bool
    @Binding var isPoofing: Bool
    @Binding var pendingConvertedItem: DroppedItem?
    @Binding var renamingItemId: UUID?
    @Binding var renamingText: String
    let onRename: () -> Void
    
    private var isSelected: Bool {
        state.selectedItems.contains(item.id)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail container
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .opacity((isConverting || isExtractingText || isCompressing || isCreatingZIP) ? 0.5 : 1.0)
                    }
                    .overlay {
                        if isConverting || isExtractingText || isCompressing || isCreatingZIP {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        }
                    }
                    .overlay {
                        // Magic processing animation for background removal - centered on thumbnail
                        // Check both local isRemovingBackground AND global processingItemIds for bulk operations
                        if isRemovingBackground || state.processingItemIds.contains(item.id) {
                            MagicProcessingOverlay()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                        }
                    }
                
                // Remove button on hover
                if isHovering && !isPoofing && renamingItemId != item.id {
                    Button(action: onRemove) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                Text(item.name)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                    .lineLimit(1)
                    .frame(width: 68)
                    .padding(.horizontal, 4)
                    .background(
                        isSelected ?
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.blue) :
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.clear)
                    )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHovering && !isSelected ? Color.white.opacity(0.1) : Color.clear)
        )
        .poofEffect(isPoofing: $isPoofing) {
            // Replace item when poof completes
            if let newItem = pendingConvertedItem {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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

