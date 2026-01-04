import SwiftUI
import UniformTypeIdentifiers
import LinkPresentation

struct ClipboardManagerView: View {
    @ObservedObject var manager = ClipboardManager.shared
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @State private var hoverLocation: CGPoint = .zero
    @State private var isBgHovering: Bool = false
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

    
    /// Helper to get selected items as array, respecting visual order
    private var selectedItemsArray: [ClipboardItem] {
        sortedHistory.filter { selectedItems.contains($0.id) }
    }
    
    /// History items sorted with favorites at the top and filtered by search
    private var sortedHistory: [ClipboardItem] {
        // First filter if search is active
        let filtered: [ClipboardItem]
        if searchText.isEmpty {
            filtered = manager.history
        } else {
            filtered = manager.history.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) || 
                (item.content ?? "").localizedCaseInsensitiveContains(searchText) || 
                (item.sourceApp ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        let favorites = filtered.filter { $0.isFavorite }
        let others = filtered.filter { !$0.isFavorite }
        return favorites + others
    }
    
    // Actions passed from Controller
    var onPaste: (ClipboardItem) -> Void
    var onClose: () -> Void
    var onReset: () -> Void
    
    var body: some View {
        mainContentView
            .overlay(alignment: .bottom) { feedbackToastView }
            .onAppear { handleOnAppear() }
            .onChange(of: manager.history) { _, new in handleHistoryChange(new) }
    }
    
    private var mainContentView: some View {
        HStack(spacing: 0) {
            sidebarView
            Divider().overlay(Color.white.opacity(0.1))
            previewPane
        }
        .frame(minWidth: 720, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity)
        .background(useTransparentBackground ? Color.clear : Color.black)
        .background {
            if useTransparentBackground {
                Color.clear
                    .liquidGlass(shape: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .overlay { HexagonDotsEffect(mouseLocation: hoverLocation, isHovering: isBgHovering, coordinateSpaceName: "clipboardContainer") }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        .coordinateSpace(name: "clipboardContainer")
        .background(pasteShortcutButton)
        .background(navigationShortcutButtons)
        .onContinuousHover(coordinateSpace: .named("clipboardContainer")) { phase in
            handleHover(phase)
        }
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
            
            // 3. Command+C -> Copy Selected to Clipboard
            Button("") { copySelectedToClipboard() }.keyboardShortcut("c", modifiers: .command)
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
    
    private func handleHover(_ phase: HoverPhase) {
        switch phase {
        case .active(let location):
            hoverLocation = location
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { isBgHovering = true }
        case .ended:
            withAnimation(.linear(duration: 0.2)) { isBgHovering = false }
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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
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
    
    var sidebarView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Draggable header area for window repositioning
            HStack {
                Text("Clipboard")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Search Toggle Button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isSearchVisible.toggle()
                        if !isSearchVisible {
                            searchText = "" // Clear on close
                            isSearchFocused = false
                        } else {
                            isSearchFocused = true
                        }
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSearchHovering ? .white : .secondary)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSearchHovering ? Color.white.opacity(0.1) : Color.clear)
                        )
                        .overlay(
                             RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: isSearchHovering ? 1 : 0)
                        )
                        .scaleEffect(isSearchHovering ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("f", modifiers: .command) // Cmd+F support
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isSearchHovering = hovering
                    }
                }
                
                // Reset Size Button - similar style to search
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isResetHovering ? .white : .secondary)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isResetHovering ? Color.white.opacity(0.1) : Color.clear)
                        )
                        .overlay(
                             RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: isResetHovering ? 1 : 0)
                        )
                        .scaleEffect(isResetHovering ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
                .help("Reset Window Size")
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isResetHovering = hovering
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 6)
            .background(WindowDragArea()) // Keep drag area behind
            .contentShape(Rectangle())
            
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                                        if modifiers.contains(.command) {
                                            // Cmd+Click: toggle selection
                                            if selectedItems.contains(item.id) {
                                                selectedItems.remove(item.id)
                                            } else {
                                                selectedItems.insert(item.id)
                                            }
                                        } else {
                                            // Normal click: select only this
                                            selectedItems = [item.id]
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
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sortedHistory)
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                }
            } // Close else

        }
        .frame(width: 300)
        .frame(maxHeight: .infinity) // Sidebar takes full height, but width fixed
        .background(Color.black.opacity(0.3)) // Slight separation for sidebar
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
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
        
        switch item.type {
        case .text:
            if let content = item.content {
                // Create a .txt file
                let fileName = sanitizeFileName(item.title) + ".txt"
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
                // Create a .webloc file for URLs
                let fileName = sanitizeFileName(item.title) + ".webloc"
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
            if let data = item.imageData {
                // Determine format and create appropriate file
                let fileName = sanitizeFileName(item.title)
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
                if let data = item.imageData, let image = NSImage(data: data) {
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

        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
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
    
    var body: some View {
        HStack {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName(for: item.type))
                    .foregroundStyle(.white)
                    .font(.system(size: 14))
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack {
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
                        .font(.system(size: 10))
                }
                if item.isFavorite && !isRenaming {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 10))
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.4) : (isHovering ? Color.white.opacity(0.12) : Color.white.opacity(0.06)))
        )
        .overlay {
            if isRenaming {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                            dashPhase = 8 // Matches dash: [4, 4] -> total 8
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
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovering = hovering
            }
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
    
    /// Get live item from manager to reflect immediate changes
    private var liveItem: ClipboardItem {
        manager.history.first(where: { $0.id == item.id }) ?? item
    }
    
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
    @State private var linkPreviewImage: NSImage?
    @State private var isLoadingLinkPreview = false
    @State private var isDirectImageLink = false
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        if let str = item.content {
            NSPasteboard.general.setString(str, forType: .string)
        } else if let imgData = item.imageData {
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
                if let data = item.imageData,
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
                                Text(liveItem.content ?? "")
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
                        VStack(spacing: 16) {
                            // Loading state
                            if isLoadingLinkPreview {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .controlSize(.regular)
                                    Text("Loading preview...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(height: 100)
                            }
                            // Direct image link - show the image
                            else if isDirectImageLink {
                                if let previewImage = linkPreviewImage {
                                    Image(nsImage: previewImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    // Failed to load image
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.secondary)
                                        Text("Image could not be loaded")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(height: 80)
                                }
                            }
                            // Website preview with metadata
                            else {
                                VStack(spacing: 12) {
                                    // Preview image (if available)
                                    if let previewImage = linkPreviewImage {
                                        Image(nsImage: previewImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(maxHeight: 140)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                    
                                    // Title and domain
                                    VStack(alignment: .leading, spacing: 6) {
                                        if let title = linkPreviewTitle {
                                            Text(title)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                                .lineLimit(2)
                                        }
                                        
                                        if let urlString = item.content,
                                           let domain = LinkPreviewService.shared.extractDomain(from: urlString) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "link")
                                                    .font(.caption2)
                                                Text(domain)
                                                    .font(.caption)
                                            }
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            
                            // Always show the full URL
                            Text(liveItem.content ?? "")
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(.blue)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    
                case .image:
                    if let nsImg = cachedImage {
                        ZStack(alignment: .bottomTrailing) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            
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
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
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
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isEditing ? Color.black.opacity(0.3) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .scaleEffect(isPasteHovering ? 1.02 : 1.0)
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
                        .background(showCopySuccess ? Color.green.opacity(0.15) : Color.white.opacity(isCopyHovering ? 0.2 : 0.1))
                        .foregroundStyle(showCopySuccess ? .green : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(showCopySuccess ? Color.green.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .scaleEffect(isCopyHovering || showCopySuccess ? 1.02 : 1.0)
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
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.yellow.opacity(liveItem.isFavorite ? 0.2 : 0))
                            .blur(radius: 8)
                            .scaleEffect(liveItem.isFavorite ? 1.2 : 0.8)
                        
                        Image(systemName: liveItem.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(liveItem.isFavorite ? .yellow : (isStarHovering ? .yellow.opacity(0.7) : .secondary))
                            .symbolEffect(.bounce, value: starAnimationTrigger)
                    }
                    .frame(width: 44, height: 44)
                    .background(isStarHovering ? Color.yellow.opacity(0.1) : Color.clear)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .scaleEffect(isSaveHovering ? 1.02 : 1.0)
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
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .scaleEffect(isCancelHovering ? 1.02 : 1.0)
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
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                if let data = item.imageData {
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
                    
                    // Check if it's a direct image link
                    if LinkPreviewService.shared.isDirectImageURL(urlString) {
                        isDirectImageLink = true
                        linkPreviewImage = await LinkPreviewService.shared.fetchImagePreview(for: urlString)
                    } else {
                        // Fetch website metadata
                        if let metadata = await LinkPreviewService.shared.fetchMetadata(for: urlString) {
                            linkPreviewTitle = metadata.title
                            
                            // Try to get image from metadata
                            if let imageProvider = metadata.imageProvider {
                                linkPreviewImage = await withCheckedContinuation { continuation in
                                    imageProvider.loadObject(ofClass: NSImage.self) { image, error in
                                        continuation.resume(returning: image as? NSImage)
                                    }
                                }
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
    
    // Create a mutable copy to adjust colors for dark mode
    let mutable = NSMutableAttributedString(attributedString: nsAttr)
    
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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .scaleEffect(isPasteHovering ? 1.02 : 1.0)
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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .scaleEffect(isCopyHovering ? 1.02 : 1.0)
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
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
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


