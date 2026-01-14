import SwiftUI
import UniformTypeIdentifiers
import LinkPresentation

struct ClipboardManagerView: View {
    @ObservedObject var manager = ClipboardManager.shared
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @State private var selectedItems: Set<UUID> = []
    @State private var isResetHovering = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var renamingItemId: UUID?
    @State private var renamingText: String = ""
    
    @State private var isSearchHovering = false
    @State private var dashPhase: CGFloat = 0
    
    // Search State
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @FocusState private var isSearchFocused: Bool
    
    // Range selection anchor for Shift+Click
    @State private var lastClickedItemId: UUID?
    
    // Cached sorted/filtered history (updated only when needed)
    @State private var cachedSortedHistory: [ClipboardItem] = []
    
    /// Helper to get selected items as array, respecting visual order
    private var selectedItemsArray: [ClipboardItem] {
        cachedSortedHistory.filter { selectedItems.contains($0.id) }
    }
    
    /// Alias for cached history (compatibility)
    private var sortedHistory: [ClipboardItem] {
        cachedSortedHistory
    }
    
    /// Recompute sorted history (called only when history or search changes)
    private func updateSortedHistory() {
        let historySnapshot = manager.history
        let searchSnapshot = searchText
        
        // Filter if search is active
        let filtered: [ClipboardItem]
        if searchSnapshot.isEmpty {
            filtered = historySnapshot
        } else {
            filtered = historySnapshot.filter { item in
                // PERFORMANCE: Limit content search to first 10K chars for large text
                let contentPreview = String((item.content ?? "").prefix(10000))
                return item.title.localizedCaseInsensitiveContains(searchSnapshot) ||
                contentPreview.localizedCaseInsensitiveContains(searchSnapshot) ||
                (item.sourceApp ?? "").localizedCaseInsensitiveContains(searchSnapshot)
            }
        }
        
        // Sort: favorites first
        let favorites = filtered.filter { $0.isFavorite }
        let others = filtered.filter { !$0.isFavorite }
        cachedSortedHistory = favorites + others
    }
    
    // Actions passed from Controller
    var onPaste: (ClipboardItem) -> Void
    var onClose: () -> Void
    var onReset: () -> Void
    
    var body: some View {
        mainContentView
            .overlay(alignment: .bottom) { feedbackToastView }
            .onAppear { 
                updateSortedHistory()
                handleOnAppear() 
            }
            .onChange(of: manager.history) { _, new in 
                updateSortedHistory()
                handleHistoryChange(new) 
            }
            .onChange(of: searchText) { _, _ in
                updateSortedHistory()
            }
    }
    
    private var mainContentView: some View {
        ZStack {
            NavigationSplitView {
                // Sidebar with entries list
                entriesListView
                    .frame(minWidth: 400)
                    .background(Color.clear)
                    .toolbar {
                        // Search button in sidebar, left of collapse button
                        ToolbarItem(placement: .automatic) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isSearchVisible.toggle()
                                    if !isSearchVisible {
                                        searchText = ""
                                        isSearchFocused = false
                                    } else {
                                        isSearchFocused = true
                                    }
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .keyboardShortcut("f", modifiers: .command)
                            .help("Search (⌘F)")
                        }
                    }
            } detail: {
                // Detail view with preview pane
                previewPane
            }
        }
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .frame(minWidth: 1040, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity)
        .background(pasteShortcutButton)
        .background(navigationShortcutButtons)
    }
    
    private var pasteShortcutButton: some View {
        Button("") {
            for item in selectedItemsArray {
                onPaste(item)
            }
        }
            .keyboardShortcut(.return, modifiers: []) // 1. Return -> Paste
            .keyboardShortcut(.return, modifiers: .command) // 2. Cmd+Return -> Paste (Bonus)
            .opacity(0)
    }
    
    @ViewBuilder
    private var navigationShortcutButtons: some View {
        VStack {
            Button("") { navigateSelection(direction: -1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("") { navigateSelection(direction: 1) }.keyboardShortcut(.downArrow, modifiers: [])
            Button("") { deleteSelectedItems() }.keyboardShortcut(.delete, modifiers: [])
            Button("") { deleteSelectedItems() }.keyboardShortcut(KeyEquivalent("\u{08}"), modifiers: []) // Backspace
            Button("") { deleteSelectedItems() }.keyboardShortcut("d", modifiers: .command) // Cmd+D
            
            // 3. Command+C -> Copy Selected to Clipboard
            Button("") { copySelectedToClipboard() }.keyboardShortcut("c", modifiers: .command)
            
            // 4. Command+V -> Paste Selected Item (same as Return)
            Button("") {
                for item in selectedItemsArray {
                    onPaste(item)
                }
            }.keyboardShortcut("v", modifiers: .command)
            
            // 5. Command+A -> Select All
            Button("") {
                selectedItems = Set(sortedHistory.map { $0.id })
            }.keyboardShortcut("a", modifiers: .command)
        }
        .opacity(0)
    }
    
    private func handleOnAppear() {
        if selectedItems.isEmpty, let first = sortedHistory.first {
            selectedItems.insert(first.id)
        }
    }
    
    private func handleHistoryChange(_ new: [ClipboardItem]) {
        // Remove any selected items that no longer exist
        selectedItems = selectedItems.filter { id in new.contains { $0.id == id } }
        
        // Re-calculate sorted history based on the new data
        let currentSorted = new.filter { $0.isFavorite } + new.filter { !$0.isFavorite }
        
        if selectedItems.isEmpty, let first = currentSorted.first {
            selectedItems.insert(first.id)
        }
    }
    
    @ViewBuilder
    private var feedbackToastView: some View {
        if manager.showPasteFeedback {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Copied to Clipboard & Pasting...")
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private func navigateSelection(direction: Int) {
        // Find current "anchor" item for navigation using VISUAL sorted order
        guard let firstSelected = selectedItems.first,
              let currentItem = sortedHistory.first(where: { $0.id == firstSelected }),
              let index = sortedHistory.firstIndex(where: { $0.id == currentItem.id }) else {
            if let first = sortedHistory.first {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedItems = [first.id]
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy?.scrollTo(first.id, anchor: .center)
                }
            }
            return
        }
        
        let newIndex = index + direction
        if newIndex >= 0 && newIndex < sortedHistory.count {
            let newId = sortedHistory[newIndex].id
            // Silky smooth scrolling - instant selection, fluid scroll
            selectedItems = [newId]
            withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.22)) {
                scrollProxy?.scrollTo(newId, anchor: .center)
            }
        }
    }
    
    private func deleteSelectedItems() {
        guard !selectedItems.isEmpty else { return }
        
        // Find next item to select after deletion
        let itemsToDelete = selectedItemsArray
        let remainingItems = manager.history.filter { !selectedItems.contains($0.id) }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            for item in itemsToDelete {
                manager.delete(item: item)
            }
            if let first = remainingItems.first {
                selectedItems = [first.id]
            } else {
                selectedItems = []
            }
        }
    }
    
    var entriesListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Search Bar - Styled exactly like RenameTextField from FloatingBasketView
            if isSearchVisible {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    
                    TextField("Search history...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .focused($isSearchFocused)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    // Reset animation state so it triggers every time the view appears
                    dashPhase = 0
                    // Animate the marching ants
                    withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                        dashPhase = 6
                    }
                }
                .onChange(of: isSearchVisible) { _, visible in
                   if visible {
                       dashPhase = 0
                       withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                           dashPhase = 6
                       }
                   }
                }
            }
            
            if !manager.hasAccessibilityPermission {
                accessibilityWarning
            }
            
            if manager.history.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "scissors")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Clipboard is empty")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(sortedHistory) { item in
                                DraggableArea(
                                    items: {
                                        // If this item is selected, drag all selected
                                        if selectedItems.contains(item.id) {
                                            return selectedItemsArray.flatMap { clipboardItemToPasteboardWritings($0) }
                                        }
                                        return clipboardItemToPasteboardWritings(item)
                                    },
                                    onTap: { modifiers in
                                        if modifiers.contains(.shift) {
                                            // Shift+Click: range selection
                                            if let anchorId = lastClickedItemId,
                                               let anchorIndex = sortedHistory.firstIndex(where: { $0.id == anchorId }),
                                               let clickedIndex = sortedHistory.firstIndex(where: { $0.id == item.id }) {
                                                let range = min(anchorIndex, clickedIndex)...max(anchorIndex, clickedIndex)
                                                for i in range {
                                                    selectedItems.insert(sortedHistory[i].id)
                                                }
                                            } else {
                                                selectedItems = [item.id]
                                                lastClickedItemId = item.id
                                            }
                                        } else if modifiers.contains(.command) {
                                            // Cmd+Click: toggle selection
                                            if selectedItems.contains(item.id) {
                                                selectedItems.remove(item.id)
                                            } else {
                                                selectedItems.insert(item.id)
                                            }
                                            lastClickedItemId = item.id
                                        } else {
                                            // Normal click: select only this
                                            selectedItems = [item.id]
                                            lastClickedItemId = item.id
                                        }
                                    },
                                    onRightClick: {
                                        // Select if not already selected
                                        if !selectedItems.contains(item.id) {
                                            selectedItems = [item.id]
                                        }
                                    }
                                ) {
                                    ClipboardItemRow(
                                        item: item, 
                                        isSelected: selectedItems.contains(item.id),
                                        isRenaming: renamingItemId == item.id,
                                        renamingText: $renamingText,
                                        onRename: {
                                            manager.rename(item: item, to: renamingText)
                                            renamingItemId = nil
                                        },
                                        onCancelRename: {
                                            renamingItemId = nil
                                        }
                                    )
                                }
                                .id(item.id)
                                .contextMenu {
                                    if selectedItems.count > 1 {
                                        // Multi-select context menu
                                        Button {
                                            for item in selectedItemsArray {
                                                onPaste(item)
                                            }
                                        } label: {
                                            Label("Paste All (\(selectedItems.count))", systemImage: "doc.on.clipboard")
                                        }
                                        Button {
                                            copySelectedToClipboard()
                                        } label: {
                                            Label("Copy All (\(selectedItems.count))", systemImage: "doc.on.doc")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            deleteSelectedItems()
                                        } label: {
                                            Label("Delete \(selectedItems.count) Items", systemImage: "trash")
                                        }
                                    } else {
                                        // Single item context menu
                                        Button { onPaste(item) } label: {
                                            Label("Paste", systemImage: "doc.on.clipboard")
                                        }
                                        Button {
                                            let willBeFavorite = !item.isFavorite
                                            manager.toggleFavorite(item)
                                            // Scroll to the item after it moves to favorites section
                                            if willBeFavorite {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                    withAnimation(.easeInOut(duration: 0.4)) {
                                                        scrollProxy?.scrollTo(item.id, anchor: .top)
                                                    }
                                                }
                                            }
                                        } label: {
                                            Label(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: item.isFavorite ? "star.slash" : "star")
                                        }
                                        Divider()
                                        
                                        // Move to Shelf/Basket
                                        Button {
                                            moveItemToShelf(item)
                                        } label: {
                                            Label("Move to Shelf", systemImage: "arrow.up.to.line")
                                        }
                                        Button {
                                            moveItemToBasket(item)
                                        } label: {
                                            Label("Move to Basket", systemImage: "tray.and.arrow.down")
                                        }
                                        
                                        Divider()
                                        Button {
                                            renamingText = item.title
                                            renamingItemId = item.id
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                manager.delete(item: item)
                                                selectedItems.remove(item.id)
                                                if selectedItems.isEmpty, let first = manager.history.first {
                                                    selectedItems.insert(first.id)
                                                }
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        // Animation for list changes (favorites, add/remove)
                        // PERFORMANCE: ID-only Hashable makes this comparison fast
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sortedHistory)
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                }
            } // Close else

        }
        .frame(width: 400)
        .frame(maxHeight: .infinity) // Sidebar takes full height, but width fixed
    }
    
    var accessibilityWarning: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                Text("Accessibility Needed")
                    .fontWeight(.bold)
            }
            .font(.caption)
            
            Text("Droppy needs permission to paste into other apps.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            Button(action: openAccessibilitySettings) {
                Text("Open Settings")
                    .font(.caption.bold())
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    /// Converts a ClipboardItem to a temp file URL for drag operations
    /// This ensures dragged items can be dropped as actual files
    private func clipboardItemToPasteboardWritings(_ item: ClipboardItem) -> [NSPasteboardWriting] {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DroppyClipboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Use a short unique suffix from UUID to prevent filename collisions when
        // multiple items with the same title are dragged together
        let uniqueSuffix = String(item.id.uuidString.prefix(8))
        
        switch item.type {
        case .text:
            if let content = item.content {
                // Create a .txt file with unique suffix
                let fileName = sanitizeFileName(item.title) + "_\(uniqueSuffix).txt"
                let fileURL = tempDir.appendingPathComponent(fileName)
                do {
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                    return [fileURL as NSURL]
                } catch {
                    return [content as NSString]
                }
            }
        case .url:
            if let content = item.content {
                // Create a .webloc file for URLs with unique suffix
                let fileName = sanitizeFileName(item.title) + "_\(uniqueSuffix).webloc"
                let fileURL = tempDir.appendingPathComponent(fileName)
                let plist = ["URL": content]
                do {
                    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                    try data.write(to: fileURL)
                    return [fileURL as NSURL]
                } catch {
                    return [content as NSString]
                }
            }
        case .file:
            if let path = item.content {
                return [URL(fileURLWithPath: path) as NSURL]
            }
        case .image:
            if let data = item.loadImageData() {
                // Determine format and create appropriate file with unique suffix
                let fileName = sanitizeFileName(item.title) + "_\(uniqueSuffix)"
                let fileURL: URL
                
                // Check if it's PNG or use PNG as default
                if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
                    fileURL = tempDir.appendingPathComponent(fileName + ".png")
                } else if data.starts(with: [0xFF, 0xD8, 0xFF]) {
                    fileURL = tempDir.appendingPathComponent(fileName + ".jpg")
                } else {
                    // Convert to PNG for unknown formats
                    fileURL = tempDir.appendingPathComponent(fileName + ".png")
                }
                
                do {
                    try data.write(to: fileURL)
                    return [fileURL as NSURL]
                } catch {
                    if let image = NSImage(data: data) {
                        return [image]
                    }
                }
            }
        case .color:
            break
        }
        return []
    }
    
    /// Sanitize filename for safe filesystem use
    private func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var sanitized = name.components(separatedBy: invalid).joined(separator: "_")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.isEmpty { sanitized = "clipboard_item" }
        if sanitized.count > 50 { sanitized = String(sanitized.prefix(50)) }
        return sanitized
    }
    
    /// Copy all selected items to system clipboard
    private func copySelectedToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        var strings: [String] = []
        var urls: [URL] = []
        
        for item in selectedItemsArray {
            switch item.type {
            case .text, .url:
                if let content = item.content {
                    strings.append(content)
                }
            case .file:
                if let path = item.content {
                    urls.append(URL(fileURLWithPath: path))
                }
            case .image:
                if let data = item.loadImageData(), let image = NSImage(data: data) {
                    pasteboard.writeObjects([image])
                }
            case .color:
                break
            }
        }
        
        if !strings.isEmpty {
            pasteboard.setString(strings.joined(separator: "\n"), forType: .string)
        }
        if !urls.isEmpty {
            pasteboard.writeObjects(urls as [NSURL])
        }
    }
    
    /// Moves clipboard item to the Floating Basket
    private func moveItemToBasket(_ item: ClipboardItem) {
        guard let fileURL = clipboardItemToTempFile(item) else { return }
        let droppedItem = DroppedItem(url: fileURL, isTemporary: true)
        DroppyState.shared.addBasketItem(droppedItem)
        // Show the basket so user sees the item
        FloatingBasketWindowController.shared.showBasket()
    }
    
    /// Moves clipboard item to the Shelf
    private func moveItemToShelf(_ item: ClipboardItem) {
        guard let fileURL = clipboardItemToTempFile(item) else { return }
        let droppedItem = DroppedItem(url: fileURL, isTemporary: true)
        DroppyState.shared.addItem(droppedItem)
    }
    
    /// Converts a ClipboardItem to a temp file and returns its URL
    private func clipboardItemToTempFile(_ item: ClipboardItem) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DroppyClipboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let uniqueSuffix = String(item.id.uuidString.prefix(8))
        
        switch item.type {
        case .text:
            if let content = item.content {
                let fileName = sanitizeFileName(item.title) + "_\(uniqueSuffix).txt"
                let fileURL = tempDir.appendingPathComponent(fileName)
                do {
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                    return fileURL
                } catch { return nil }
            }
        case .url:
            if let content = item.content {
                let fileName = sanitizeFileName(item.title) + "_\(uniqueSuffix).webloc"
                let fileURL = tempDir.appendingPathComponent(fileName)
                let plist = ["URL": content]
                do {
                    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                    try data.write(to: fileURL)
                    return fileURL
                } catch { return nil }
            }
        case .file:
            if let path = item.content {
                return URL(fileURLWithPath: path)
            }
        case .image:
            if let data = item.loadImageData() {
                let fileName = sanitizeFileName(item.title) + "_\(uniqueSuffix)"
                let fileURL: URL
                
                if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
                    fileURL = tempDir.appendingPathComponent(fileName + ".png")
                } else if data.starts(with: [0xFF, 0xD8, 0xFF]) {
                    fileURL = tempDir.appendingPathComponent(fileName + ".jpg")
                } else {
                    fileURL = tempDir.appendingPathComponent(fileName + ".png")
                }
                
                do {
                    try data.write(to: fileURL)
                    return fileURL
                } catch { return nil }
            }
        case .color:
            return nil
        }
        return nil
    }
    
    var previewPane: some View {
        VStack(spacing: 0) {
            // Draggable header area for window repositioning (top right)
            HStack {
                Spacer()
            }
            .frame(height: 40)
            .background(WindowDragArea())
            .contentShape(Rectangle())
            
            if selectedItems.count > 1 {
                // Multi-select stacked preview
                MultiSelectPreviewView(
                    items: selectedItemsArray,
                    onPasteAll: {
                        for item in selectedItemsArray {
                            onPaste(item)
                        }
                    },
                    onCopyAll: copySelectedToClipboard,
                    onDeleteAll: deleteSelectedItems
                )
            } else if let firstId = selectedItems.first,
                      let item = manager.history.first(where: { $0.id == firstId }) {
                ClipboardPreviewView(
                    item: item, 
                    scrollProxy: scrollProxy,
                    onPaste: { onPaste(item) },
                    onDelete: { deleteSelectedItems() }
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Select an item to preview")
                        .font(.system(size: 14, weight: .medium)) // Matched font weight
                        .foregroundStyle(.secondary)
                }
            }
        }

        .frame(minWidth: 504, maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isRenaming: Bool
    @Binding var renamingText: String
    let onRename: () -> Void
    let onCancelRename: () -> Void
    
    @State private var isHovering = false
    @State private var dashPhase: CGFloat = 0
    @State private var cachedThumbnail: NSImage? // Async-loaded thumbnail
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon/Thumbnail - smaller and shows real image for images
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                // Show cached thumbnail for images, icon for others
                if item.type == .image, let thumbnail = cachedThumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Image(systemName: iconName(for: item.type))
                        .foregroundStyle(.white)
                        .font(.system(size: 12))
                }
            }
            .task(id: item.id) {
                // Load thumbnail asynchronously
                if item.type == .image && cachedThumbnail == nil {
                    // Run on background thread to avoid blocking UI
                    let thumbnail = ThumbnailCache.shared.thumbnail(for: item)
                    await MainActor.run {
                        cachedThumbnail = thumbnail
                    }
                }
            }
            
            // Title or rename field
            if isRenaming {
                ClipboardRenameTextField(
                    text: $renamingText,
                    onSubmit: onRename,
                    onCancel: onCancelRename
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if let app = item.sourceApp {
                            Text(app)
                                .font(.system(size: 10))
                        }
                        Text(item.date, style: .time)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Status icons (key + star)
            HStack(spacing: 4) {
                if item.isConcealed && !isRenaming {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 9))
                }
                if item.isFavorite && !isRenaming {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 9))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected 
                      ? Color.blue.opacity(isHovering ? 1.0 : 0.8) 
                      : Color.white.opacity(isHovering ? 0.15 : 0.08))
        )
        .foregroundStyle(isSelected ? .white : .primary)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .overlay {
            if isRenaming {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        Color.accentColor.opacity(0.8),
                        style: StrokeStyle(
                            lineWidth: 1.5,
                            lineCap: .round,
                            dash: [4, 4],
                            dashPhase: dashPhase
                        )
                    )
                    .onAppear {
                        dashPhase = 0
                        withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                            dashPhase = 8
                        }
                    }
                    .onChange(of: isRenaming) { _, renaming in
                        if renaming {
                            dashPhase = 0
                            withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                                dashPhase = 8
                            }
                        }
                    }
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    func iconName(for type: ClipboardType) -> String {
        switch type {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc"
        case .url: return "link"
        case .color: return "paintpalette"
        }
    }
}

// MARK: - Clipboard Rename TextField
private struct ClipboardRenameTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = true
        textField.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        textField.textColor = .white
        textField.font = .systemFont(ofSize: 11, weight: .medium)
        textField.alignment = .left
        textField.focusRingType = .none
        textField.stringValue = text
        textField.wantsLayer = true
        textField.layer?.cornerRadius = 6 // Match basket corner radius
        
        // Add left padding to the text field content if possible, or handle via frame
        // For NSTextField we can adjust its frame or use a custom cell, but 
        // let's keep it simple and just ensure font and background match.
        
        // Auto-focus and select text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = textField.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(textField)
            textField.selectText(nil)
            if let editor = textField.currentEditor() {
                editor.selectedRange = NSRange(location: 0, length: textField.stringValue.count)
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: ClipboardRenameTextField
        
        init(_ parent: ClipboardRenameTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false
        }
    }
}

struct ClipboardPreviewView: View {
    let item: ClipboardItem
    var scrollProxy: ScrollViewProxy?
    let onPaste: () -> Void
    let onDelete: () -> Void
    
    @ObservedObject private var manager = ClipboardManager.shared
    

    @State private var isPasteHovering = false
    @State private var isCopyHovering = false
    @State private var isStarHovering = false
    @State private var isTrashHovering = false
    @State private var starAnimationTrigger = false
    @State private var isDownloadHovering = false
    @State private var isSavingFile = false
    @State private var showSaveSuccess = false
    @State private var showCopySuccess = false
    
    // Animation Namespace
    @Namespace private var animationNamespace
    
    // Content Editing State
    @State private var isEditing = false
    @State private var editedContent = ""
    @State private var isEditHovering = false
    @State private var isSaveHovering = false
    @State private var isCancelHovering = false
    @State private var dashPhase: CGFloat = 0
    @State private var isExtractingText = false
    
    // Cached Preview Content
    @State private var cachedImage: NSImage?
    @State private var cachedAttributedText: AttributedString?
    @State private var isLoadingPreview = false
    
    // Link Preview State
    @State private var linkPreviewTitle: String?
    @State private var linkPreviewDescription: String?
    @State private var linkPreviewImage: NSImage?
    @State private var linkPreviewIcon: NSImage?
    @State private var isLoadingLinkPreview = false
    @State private var isDirectImageLink = false
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        if let str = item.content {
            NSPasteboard.general.setString(str, forType: .string)
        } else if let imgData = item.loadImageData() {
            NSPasteboard.general.setData(imgData, forType: .tiff)
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showCopySuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopySuccess = false
            }
        }
    }
    
    private func saveToFile() {
        isSavingFile = true
        
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let fileName: String
        let fileExtension: String
        
        switch item.type {
        case .image:
            fileName = item.customTitle ?? "Image_\(Int(Date().timeIntervalSince1970))"
            fileExtension = "png"
        case .text, .url:
            fileName = item.customTitle ?? "Text_\(Int(Date().timeIntervalSince1970))"
            fileExtension = "txt"
        case .file:
            if let path = item.content {
                let url = URL(fileURLWithPath: path)
                fileName = url.deletingPathExtension().lastPathComponent
                fileExtension = url.pathExtension
            } else {
                fileName = "File_\(Int(Date().timeIntervalSince1970))"
                fileExtension = ""
            }
        case .color:
            fileName = "Color_\(Int(Date().timeIntervalSince1970))"
            fileExtension = "txt"
        }
        
        var destinationURL = downloads.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
        
        // Handle collisions
        var counter = 1
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            destinationURL = downloads.appendingPathComponent("\(fileName)_\(counter)").appendingPathExtension(fileExtension)
            counter += 1
        }
        
        do {
            switch item.type {
            case .image:
                if let data = item.loadImageData(),
                   let nsImage = NSImage(data: data),
                   let tiffData = nsImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try pngData.write(to: destinationURL)
                }
            case .text, .url, .color:
                if let content = item.content {
                    try content.write(to: destinationURL, atomically: true, encoding: .utf8)
                }
            case .file:
                if let path = item.content {
                    let sourceURL = URL(fileURLWithPath: path)
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                }
            }
            
            // Success Feedback
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showSaveSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSaveSuccess = false
                }
            }
        } catch {
            print("Direct save error: \(error.localizedDescription)")
        }
        
        isSavingFile = false
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Content Preview
            VStack {
                switch item.type {
                case .text:
                    if isEditing {
                        TextEditor(text: $editedContent)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(.white)
                            .padding(12)
                            .onAppear {
                                dashPhase = 0
                                withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                                    dashPhase = 6
                                }
                            }
                    } else {
                        ScrollView {
                            if let attributed = cachedAttributedText {
                                Text(attributed)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            } else if isLoadingPreview {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding()
                            } else {
                                // Truncate very long content for performance
                                let content = item.content ?? ""
                                let maxPreviewLength = 50000
                                let truncatedContent = content.count > maxPreviewLength 
                                    ? String(content.prefix(maxPreviewLength)) + "\n\n[Content truncated - \(content.count) characters total]"
                                    : content
                                
                                Text(truncatedContent)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    
                case .url:
                    if isEditing {
                        TextEditor(text: $editedContent)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(.white)
                            .padding(12)
                    } else {
                        URLPreviewCard(
                            item: item,
                            isLoading: isLoadingLinkPreview,
                            isDirectImage: isDirectImageLink,
                            title: linkPreviewTitle,
                            description: linkPreviewDescription,
                            image: linkPreviewImage,
                            icon: linkPreviewIcon
                        )
                        .padding(.vertical)
                    }
                    
                case .image:
                    if let nsImg = cachedImage {
                        ZStack(alignment: .bottomTrailing) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            
                            // OCR Button
                            Button {
                                guard !isExtractingText else { return }
                                isExtractingText = true
                                Task {
                                    do {
                                        let text = try await OCRService.shared.performOCR(on: nsImg)
                                        await MainActor.run {
                                            isExtractingText = false
                                            OCRWindowController.shared.show(with: text)
                                        }
                                    } catch {
                                        await MainActor.run {
                                            isExtractingText = false
                                            // Handle error if needed, for now just reset state
                                            print("OCR Error: \(error)")
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if isExtractingText {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(.white)
                                            .frame(width: 12, height: 12)
                                    } else {
                                        Image(systemName: "text.viewfinder")
                                    }
                                    Text(isExtractingText ? "Extracting..." : "Extract Text")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .background(Color.black.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                        }
                    } else if isLoadingPreview {
                        ProgressView()
                            .padding()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }
                    
                case .file:
                    if let path = item.content {
                        VStack(spacing: 12) {
                            Image(nsImage: ThumbnailCache.shared.cachedIcon(forPath: path))
                                .resizable()
                                .frame(width: 64, height: 64)
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                default:
                     Text("Preview not available")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEditing ? Color.black.opacity(0.3) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        Color.accentColor.opacity(isEditing ? 0.8 : 0),
                        style: StrokeStyle(
                            lineWidth: 1.5,
                            lineCap: .round,
                            dash: [3, 3],
                            dashPhase: dashPhase
                        )
                    )
            )
            .animation(.easeInOut(duration: 0.3), value: isEditing)
            .onChange(of: isEditing) { _, editing in
                if editing {
                    dashPhase = 0
                    withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                        dashPhase = 6
                    }
                }
            }
            
            // Metadata Footer
            HStack {
                if let app = item.sourceApp {
                    Label(app, systemImage: "app")
                }
                Spacer()
                Text(item.date, style: .date)
                Text(item.date, style: .time)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            
            // Action Buttons
            HStack(spacing: 12) {
                // Main Paste Button
                if !isEditing {
                    Button(action: onPaste) {
                        Text("Paste")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(isPasteHovering ? 1.0 : 0.8))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .matchedGeometryEffect(id: "PrimaryAction", in: animationNamespace)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isPasteHovering = hovering
                        }
                    }
                    
                    // Copy Button
                    Button(action: copyToClipboard) {
                        ZStack {
                            if showCopySuccess {
                                Image(systemName: "checkmark")
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Text("Copy")
                                    .fontWeight(.medium)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: 70)
                        .padding(.vertical, 12)
                        .background(showCopySuccess ? Color.green.opacity(0.15) : Color.blue.opacity(isCopyHovering ? 1.0 : 0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(showCopySuccess ? Color.green.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .matchedGeometryEffect(id: "SecondaryAction", in: animationNamespace)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .onHover { hovering in
                        if !showCopySuccess {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                isCopyHovering = hovering
                            }
                        }
                    }
                    
                    // Save to File Button
                    Button(action: saveToFile) {
                        ZStack {
                            if showSaveSuccess {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.green)
                                    .transition(.scale.combined(with: .opacity))
                            } else if isSavingFile {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 18, weight: .medium))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .foregroundStyle(showSaveSuccess ? .green : (isDownloadHovering ? .white : .secondary))
                        .frame(width: 44, height: 44)
                        .background(showSaveSuccess ? Color.green.opacity(0.15) : (isDownloadHovering ? Color.white.opacity(0.15) : Color.clear))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(showSaveSuccess ? Color.green.opacity(0.5) : (isDownloadHovering ? Color.white.opacity(0.3) : Color.white.opacity(0.1)), lineWidth: 1)
                        )
                        .scaleEffect(isDownloadHovering || showSaveSuccess ? 1.08 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .help("Save to Downloads")
                    .disabled(isSavingFile || showSaveSuccess)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .onHover { hovering in
                        if !showSaveSuccess {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                isDownloadHovering = hovering
                            }
                        }
                    }
                }
                
                // Favorite Button - Always visible, slides naturally
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        starAnimationTrigger.toggle()
                    }
                    let willBeFavorite = !item.isFavorite
                    manager.toggleFavorite(item)
                    // Scroll to the item after it moves to favorites section
                    if willBeFavorite {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                scrollProxy?.scrollTo(item.id, anchor: .top)
                            }
                        }
                    }
                } label: {
                    ZStack {
                        // Background glow when favorited
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.yellow.opacity(item.isFavorite ? 0.2 : 0))
                            .blur(radius: 8)
                            .scaleEffect(item.isFavorite ? 1.2 : 0.8)
                        
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(item.isFavorite ? .yellow : (isStarHovering ? .yellow.opacity(0.7) : .secondary))
                            .symbolEffect(.bounce, value: starAnimationTrigger)
                    }
                    .frame(width: 44, height: 44)
                    .background(isStarHovering ? Color.yellow.opacity(0.1) : Color.clear)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isStarHovering ? Color.yellow.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .scaleEffect(isStarHovering ? 1.08 : 1.0)
                }
                .buttonStyle(.plain)
                .help("Toggle Favorite")
                .onHover { hovering in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isStarHovering = hovering
                    }
                }
                
                // Edit Button (Text/URL only)
                if !isEditing && (item.type == .text || item.type == .url) {
                    Button {
                        editedContent = item.content ?? ""
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isEditing = true
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isEditHovering ? .white : .secondary)
                            .frame(width: 44, height: 44)
                            .background(isEditHovering ? Color.white.opacity(0.15) : Color.clear)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isEditHovering ? Color.white.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .scaleEffect(isEditHovering ? 1.08 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .help("Edit Content")
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isEditHovering = hovering
                        }
                    }
                }
                
                // Edit Mode Actions
                if isEditing {
                    // Save
                    Button {
                        manager.updateItemContent(item, newContent: editedContent)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isEditing = false
                        }
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .frame(width: 70)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(isSaveHovering ? 1.0 : 0.8))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .matchedGeometryEffect(id: "PrimaryAction", in: animationNamespace)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .onHover { h in withAnimation { isSaveHovering = h } }
                    
                    // Cancel
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isEditing = false
                        }
                    } label: {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .frame(width: 70)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(isCancelHovering ? 1.0 : 0.8))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .matchedGeometryEffect(id: "SecondaryAction", in: animationNamespace)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .onHover { h in withAnimation { isCancelHovering = h } }
                }
                
                // Delete Button
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isTrashHovering ? .red : .red.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(isTrashHovering ? Color.red.opacity(0.15) : Color.clear)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isTrashHovering ? Color.red.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .scaleEffect(isTrashHovering ? 1.08 : 1.0)
                        .shadow(color: isTrashHovering ? .red.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .help("Delete (Backspace)")
                .onHover { hovering in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isTrashHovering = hovering
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .onDisappear {
            // Release cached images when view disappears to free memory
            cachedImage = nil
            cachedAttributedText = nil
            linkPreviewImage = nil
            linkPreviewIcon = nil
        }
        .task(id: item.id) {
            // Asynchronously load and process preview content
            isLoadingPreview = true
            
            // Clear previous cache immediately to avoid flicker or wrong previews
            cachedImage = nil
            cachedAttributedText = nil
            linkPreviewTitle = nil
            linkPreviewImage = nil
            isDirectImageLink = false
            
            switch item.type {
            case .image:
                if let data = item.loadImageData() {
                    cachedImage = await Task.detached(priority: .userInitiated) {
                        NSImage(data: data)
                    }.value
                }
                
            case .text:
                if let rtfData = item.rtfData {
                    cachedAttributedText = await Task.detached(priority: .userInitiated) {
                        try? rtfToAttributedString(rtfData)
                    }.value
                }
                
            case .url:
                // Fetch link preview
                if let urlString = item.content {
                    isLoadingLinkPreview = true
                    
                    // Clear previous states
                    linkPreviewTitle = nil
                    linkPreviewDescription = nil
                    linkPreviewImage = nil
                    linkPreviewIcon = nil
                    isDirectImageLink = false
                    
                    // Check if it's a direct image link
                    if LinkPreviewService.shared.isDirectImageURL(urlString) {
                        isDirectImageLink = true
                        linkPreviewImage = await LinkPreviewService.shared.fetchImagePreview(for: urlString)
                    } else {
                        // Fetch website metadata
                        if let metadata = await LinkPreviewService.shared.fetchMetadata(for: urlString) {
                            linkPreviewTitle = metadata.title
                            linkPreviewDescription = metadata.description
                            
                            if let imageData = metadata.image {
                                linkPreviewImage = NSImage(data: imageData)
                            }
                            
                            if let iconData = metadata.icon {
                                linkPreviewIcon = NSImage(data: iconData)
                            }
                            
                            // If still no image but it's an image link we missed
                            if linkPreviewImage == nil && LinkPreviewService.shared.isDirectImageURL(urlString) {
                                linkPreviewImage = await LinkPreviewService.shared.fetchImagePreview(for: urlString)
                            }
                        }
                    }
                    
                    isLoadingLinkPreview = false
                }
                
            default: break
            }
            
            isLoadingPreview = false
        }
    }
}

// MARK: - RTF Helper
nonisolated private func rtfToAttributedString(_ data: Data) throws -> AttributedString {
    let nsAttr = try NSAttributedString(
        data: data,
        options: [.documentType: NSAttributedString.DocumentType.rtf],
        documentAttributes: nil
    )
    
    // PERFORMANCE: Limit to 50K characters to prevent CPU spike with huge text
    let maxPreviewLength = 50000
    let isTruncated = nsAttr.length > maxPreviewLength
    
    // Create a mutable copy, truncated if necessary
    let mutable: NSMutableAttributedString
    if isTruncated {
        let truncatedRange = NSRange(location: 0, length: maxPreviewLength)
        mutable = NSMutableAttributedString(attributedString: nsAttr.attributedSubstring(from: truncatedRange))
        // Add truncation notice
        let truncationNotice = NSAttributedString(
            string: "\n\n[Content truncated - \(nsAttr.length) characters total]",
            attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 12)]
        )
        mutable.append(truncationNotice)
    } else {
        mutable = NSMutableAttributedString(attributedString: nsAttr)
    }
    
    // Scale font size up if it's too small (often RTF is 11pt/12pt)
    mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
        if let font = value as? NSFont {
            if font.pointSize < 14 {
                 // Creating a new font with the same descriptor but larger size
                 if let newFont = NSFont(descriptor: font.fontDescriptor, size: 14) {
                     mutable.addAttribute(.font, value: newFont, range: range)
                 }
            }
        }
    }
    
    // Force white color for visibility on dark background
    // We remove existing foreground color and enforce white
    mutable.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
        mutable.addAttribute(.foregroundColor, value: NSColor.white, range: range)
    }
    
    // Remove background color to ensure transparency (avoid White on White)
    mutable.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
        if value != nil {
            mutable.removeAttribute(.backgroundColor, range: range)
        }
    }
    
    return AttributedString(mutable)
}


// MARK: - Multi-Select Preview View

struct MultiSelectPreviewView: View {
    let items: [ClipboardItem]
    let onPasteAll: () -> Void
    let onCopyAll: () -> Void
    let onDeleteAll: () -> Void
    
    @State private var isPasteHovering = false
    @State private var isCopyHovering = false
    @State private var isDeleteHovering = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Stacked cards preview
            ZStack {
                ForEach(Array(items.prefix(5).enumerated().reversed()), id: \.element.id) { index, item in
                    StackedCardView(item: item, index: index, totalCount: min(items.count, 5))
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
            }
            .frame(height: 180)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: items.count)
            
            // Selection count badge
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
                
                Text("\(items.count) items selected")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            Spacer()
            
            // Bulk action buttons
            HStack(spacing: 12) {
                // Paste All Button
                Button(action: onPasteAll) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste All")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(isPasteHovering ? 1.0 : 0.8))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isPasteHovering = hovering
                    }
                }
                
                // Copy All Button
                Button(action: onCopyAll) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy All")
                    }
                    .fontWeight(.medium)
                    .frame(width: 110)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(isCopyHovering ? 0.2 : 0.1))
                    .foregroundStyle(.white)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isCopyHovering = hovering
                    }
                }
                
                // Delete All Button
                Button(action: onDeleteAll) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isDeleteHovering ? .red : .red.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(isDeleteHovering ? Color.red.opacity(0.15) : Color.clear)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isDeleteHovering ? Color.red.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .scaleEffect(isDeleteHovering ? 1.08 : 1.0)
                        .shadow(color: isDeleteHovering ? .red.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isDeleteHovering = hovering
                    }
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Stacked Card View

struct StackedCardView: View {
    let item: ClipboardItem
    let index: Int
    let totalCount: Int
    
    private var offset: CGFloat {
        CGFloat(index) * 8
    }
    
    private var rotation: Double {
        Double(index - totalCount / 2) * 3.0
    }
    
    private var scale: CGFloat {
        1.0 - CGFloat(index) * 0.05
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName(for: item.type))
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
            
            // Title
            Text(item.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 100)
        }
        .padding(16)
        .frame(width: 130, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .scaleEffect(scale)
        .offset(x: offset, y: -offset)
        .rotationEffect(.degrees(rotation))
        .zIndex(Double(totalCount - index))
    }
    
    private func iconName(for type: ClipboardType) -> String {
        switch type {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc"
        case .url: return "link"
        case .color: return "paintpalette"
        }
    }
}

// MARK: - Window Drag Area
/// An NSViewRepresentable that enables window dragging when used as a background
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragNSView {
        return WindowDragNSView()
    }
    
    func updateNSView(_ nsView: WindowDragNSView, context: Context) {}
}
class WindowDragNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        // Consumed
    }
}

// MARK: - URL Preview Components

struct URLPreviewCard: View {
    let item: ClipboardItem
    let isLoading: Bool
    let isDirectImage: Bool
    let title: String?
    let description: String?
    let image: NSImage?
    let icon: NSImage?
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.regular)
                    Text("Fetching preview...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else {
                VStack(spacing: 0) {
                    // Main Image Area
                    ZStack {
                        if let previewImage = image {
                            Image(nsImage: previewImage)
                                .resizable()
                                .aspectRatio(contentMode: isDirectImage ? .fit : .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: isDirectImage ? 260 : 180)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: isDirectImage ? 200 : 120)
                                .overlay {
                                    Image(systemName: isDirectImage ? "photo" : "link")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary.opacity(0.3))
                                }
                        }
                    }
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    MetadataInfoStrip(
                        item: item,
                        isDirectImage: isDirectImage,
                        title: title,
                        description: description,
                        icon: icon
                    )
                }
                .contentShape(Rectangle())
                .onHover { hovering in
                    isHovering = hovering
                }
                .onTapGesture {
                    if let urlString = item.content, let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                        ClipboardWindowController.shared.close()
                    }
                }
                .opacity(isHovering ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
                .help("Click to open link")
                
                // Raw URL at the bottom
                Text(item.content ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.blue.opacity(0.8))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }
}

struct MetadataInfoStrip: View {
    let item: ClipboardItem
    let isDirectImage: Bool
    let title: String?
    let description: String?
    let icon: NSImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // Favicon/Icon
                Group {
                    if let icon = icon {
                        Image(nsImage: icon)
                            .resizable()
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                            .background(Color.white.opacity(0.05))
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    if let title = title {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    } else if isDirectImage, let url = URL(string: item.content ?? "") {
                        Text(url.lastPathComponent)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    
                    Text(description ?? "No description")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .padding(.bottom, 4)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Domain Area
            HStack {
                if let urlString = item.content,
                   let domain = LinkPreviewService.shared.extractDomain(from: urlString) {
                    Label(domain, systemImage: "link")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Type Badge
                URLTypeBadge(isDirectImage: isDirectImage)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct URLTypeBadge: View {
    let isDirectImage: Bool
    
    var body: some View {
        Text(isDirectImage ? "Image Link" : "Website")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
}
