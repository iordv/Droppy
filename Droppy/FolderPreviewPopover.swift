//
//  FolderPreviewPopover.swift
//  Droppy
//
//  Shows a preview of folder contents when hovering over a pinned folder.
//  Supports selection (cmd+click, shift+click) and dragging items to shelf/basket.
//

import SwiftUI
import UniformTypeIdentifiers

/// Item representation for folder contents
struct FolderItem: Identifiable, Equatable {
    let id: String  // URL path for uniqueness
    let url: URL
    let name: String
    let icon: NSImage
    let isDirectory: Bool
    
    static func == (lhs: FolderItem, rhs: FolderItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Popover that shows the contents of a folder
/// Supports selection and dragging items to shelf/basket
struct FolderPreviewPopover: View {
    let folderURL: URL
    let isPinned: Bool
    @Binding var isHovering: Bool
    let maxItems: Int = 8
    
    // Pre-loaded content to avoid dynamic layout during popover animation
    private let contents: [FolderItem]
    private let totalCount: Int
    
    init(folderURL: URL, isPinned: Bool = false, isHovering: Binding<Bool> = .constant(false)) {
        self.folderURL = folderURL
        self.isPinned = isPinned
        self._isHovering = isHovering
        
        // Load contents synchronously during init to avoid layout changes
        let fm = FileManager.default
        if let urls = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            self.totalCount = urls.count
            
            // Sort: folders first, then by name
            let sorted = urls.sorted { url1, url2 in
                let isDir1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let isDir2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir1 != isDir2 { return isDir1 }
                return url1.lastPathComponent.localizedCaseInsensitiveCompare(url2.lastPathComponent) == .orderedAscending
            }
            
            self.contents = Array(sorted.prefix(maxItems).map { url in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                return FolderItem(
                    id: url.path,
                    url: url,
                    name: url.lastPathComponent,
                    icon: icon,
                    isDirectory: isDir
                )
            })
        } else {
            self.contents = []
            self.totalCount = 0
        }
    }
    
    @State private var hoveredItem: String?
    @State private var selectedItems: Set<String> = []
    @State private var lastClickedItem: String?  // For shift+click range selection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: folderURL.path))
                    .resizable()
                    .frame(width: 20, height: 20)
                
                Text(folderURL.lastPathComponent)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Text("\(totalCount) items")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            if contents.isEmpty {
                Text("Empty folder")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                // File list with selection and drag support
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(contents) { item in
                            FolderItemRow(
                                item: item,
                                isHovered: hoveredItem == item.id,
                                isSelected: selectedItems.contains(item.id),
                                onHover: { isHovering in
                                    hoveredItem = isHovering ? item.id : nil
                                },
                                onTap: { modifiers in
                                    handleSelection(item: item, modifiers: modifiers)
                                },
                                onDoubleTap: {
                                    NSWorkspace.shared.open(item.url)
                                },
                                dragItems: {
                                    // If this item is selected, drag all selected items
                                    if selectedItems.contains(item.id) {
                                        return contents.filter { selectedItems.contains($0.id) }.map { $0.url }
                                    } else {
                                        return [item.url]
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                }
                .scrollDisabled(true) // We limit items anyway
            }
            
            // Selection info (if items selected)
            if !selectedItems.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack(spacing: 4) {
                    Text("\(selectedItems.count) selected")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Button {
                        addSelectedToBasket()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10))
                            Text("Add to Basket")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .onHover { isHovering in
                        if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Footer: Open Folder button
            Button {
                NSWorkspace.shared.open(folderURL)
            } label: {
                HStack(spacing: 4) {
                    Text("Open Folder")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovering in
                if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .frame(width: 220)
        .background(
            // Use standard material background
            Material.regular
        )
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .droppyFloatingShadow()
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    /// Handle item selection with modifier keys
    private func handleSelection(item: FolderItem, modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.command) {
            // Cmd+click: Toggle selection
            if selectedItems.contains(item.id) {
                selectedItems.remove(item.id)
            } else {
                selectedItems.insert(item.id)
            }
            lastClickedItem = item.id
        } else if modifiers.contains(.shift), let lastId = lastClickedItem {
            // Shift+click: Range selection
            guard let lastIndex = contents.firstIndex(where: { $0.id == lastId }),
                  let currentIndex = contents.firstIndex(where: { $0.id == item.id }) else {
                selectedItems = [item.id]
                lastClickedItem = item.id
                return
            }
            
            let range = min(lastIndex, currentIndex)...max(lastIndex, currentIndex)
            for i in range {
                selectedItems.insert(contents[i].id)
            }
        } else {
            // Regular click: Select only this item
            selectedItems = [item.id]
            lastClickedItem = item.id
        }
        
        HapticFeedback.light.perform()
    }
    
    /// Add selected items to basket
    private func addSelectedToBasket() {
        let urls = contents.filter { selectedItems.contains($0.id) }.map { $0.url }
        DroppyState.shared.addBasketItems(from: urls)
        selectedItems.removeAll()
        HapticFeedback.pop()
    }
}

/// Individual row in the folder preview with drag support
/// Uses AppKit event handling to ensure clicks work reliably
struct FolderItemRow: View {
    let item: FolderItem
    let isHovered: Bool
    let isSelected: Bool
    let onHover: (Bool) -> Void
    let onTap: (NSEvent.ModifierFlags) -> Void
    let onDoubleTap: () -> Void
    let dragItems: () -> [URL]
    
    var body: some View {
        FolderItemRowContent(
            item: item,
            isHovered: isHovered,
            isSelected: isSelected,
            onHover: onHover,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            dragItems: dragItems
        )
        .frame(height: 28)  // Fixed height for proper NSView layout
    }
}

/// AppKit-backed row that properly handles clicks before drag
struct FolderItemRowContent: NSViewRepresentable {
    let item: FolderItem
    let isHovered: Bool
    let isSelected: Bool
    let onHover: (Bool) -> Void
    let onTap: (NSEvent.ModifierFlags) -> Void
    let onDoubleTap: () -> Void
    let dragItems: () -> [URL]
    
    func makeNSView(context: Context) -> FolderItemNSView {
        let view = FolderItemNSView()
        view.configure(
            item: item,
            isSelected: isSelected,
            isHovered: isHovered,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onHover: onHover,
            dragItems: dragItems
        )
        return view
    }
    
    func updateNSView(_ nsView: FolderItemNSView, context: Context) {
        nsView.configure(
            item: item,
            isSelected: isSelected,
            isHovered: isHovered,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onHover: onHover,
            dragItems: dragItems
        )
        nsView.needsDisplay = true
    }
}

/// AppKit NSView for folder item row with proper click and drag handling
class FolderItemNSView: NSView {
    private var item: FolderItem?
    private var isSelected = false
    private var isHovered = false
    private var onTap: ((NSEvent.ModifierFlags) -> Void)?
    private var onDoubleTap: (() -> Void)?
    private var onHoverCallback: ((Bool) -> Void)?
    private var dragItems: (() -> [URL])?
    private var mouseDownEvent: NSEvent?
    private var trackingArea: NSTrackingArea?
    
    // UI elements
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let chevronView = NSImageView()
    private let backgroundView = NSView()
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        wantsLayer = true
        
        // Background
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 4
        addSubview(backgroundView)
        
        // Icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)
        
        // Name label
        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.maximumNumberOfLines = 1
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.drawsBackground = false
        addSubview(nameLabel)
        
        // Chevron for directories
        chevronView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevronView.contentTintColor = .secondaryLabelColor.withAlphaComponent(0.5)
        chevronView.imageScaling = .scaleProportionallyDown
        addSubview(chevronView)
    }
    
    func configure(
        item: FolderItem,
        isSelected: Bool,
        isHovered: Bool,
        onTap: @escaping (NSEvent.ModifierFlags) -> Void,
        onDoubleTap: @escaping () -> Void,
        onHover: @escaping (Bool) -> Void,
        dragItems: @escaping () -> [URL]
    ) {
        self.item = item
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
        self.onHoverCallback = onHover
        self.dragItems = dragItems
        
        // Update UI
        iconView.image = item.icon
        nameLabel.stringValue = item.name
        chevronView.isHidden = !item.isDirectory
        
        // Update background color
        if isSelected {
            backgroundView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
        } else if isHovered {
            backgroundView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        } else {
            backgroundView.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 28)
    }
    
    override func layout() {
        super.layout()
        
        let padding: CGFloat = 10
        let iconSize: CGFloat = 16
        let chevronSize: CGFloat = 10
        
        backgroundView.frame = bounds
        iconView.frame = NSRect(x: padding, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)
        
        let nameX = padding + iconSize + 8
        let chevronWidth = (item?.isDirectory == true) ? chevronSize + 8 : 0
        let nameWidth = bounds.width - nameX - padding - chevronWidth
        nameLabel.frame = NSRect(x: nameX, y: (bounds.height - 16) / 2, width: max(0, nameWidth), height: 16)
        
        if item?.isDirectory == true {
            chevronView.frame = NSRect(x: bounds.width - padding - chevronSize, y: (bounds.height - chevronSize) / 2, width: chevronSize, height: chevronSize)
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        onHoverCallback?(true)
    }
    
    override func mouseExited(with event: NSEvent) {
        onHoverCallback?(false)
    }
    
    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let mouseDown = mouseDownEvent else { return }
        
        // Check if we actually clicked (didn't drag)
        let dragThreshold: CGFloat = 3
        if abs(event.locationInWindow.x - mouseDown.locationInWindow.x) < dragThreshold &&
           abs(event.locationInWindow.y - mouseDown.locationInWindow.y) < dragThreshold {
            
            if event.clickCount == 2 {
                onDoubleTap?()
            } else {
                onTap?(NSEvent.modifierFlags)
            }
        }
        mouseDownEvent = nil
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let mouseDown = mouseDownEvent, let urls = dragItems?() else { return }
        
        // Simple threshold check
        let dragThreshold: CGFloat = 3
        let dx = event.locationInWindow.x - mouseDown.locationInWindow.x
        let dy = event.locationInWindow.y - mouseDown.locationInWindow.y
        if hypot(dx, dy) < dragThreshold { return }
        
        mouseDownEvent = nil  // Prevent click after drag
        
        // Create drag items
        let draggingItems = urls.compactMap { url -> NSDraggingItem? in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 32, height: 32)
            item.setDraggingFrame(NSRect(x: 0, y: 0, width: 32, height: 32), contents: icon)
            return item
        }
        
        guard !draggingItems.isEmpty else { return }
        
        beginDraggingSession(with: draggingItems, event: mouseDown, source: self)
    }
}

extension FolderItemNSView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .outsideApplication ? .copy : [.copy, .move]
    }
}

/// Drag preview showing dragged items
struct DragPreviewView: View {
    let items: [URL]
    
    var body: some View {
        HStack(spacing: 4) {
            if let first = items.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                    .resizable()
                    .frame(width: 32, height: 32)
            }
            
            if items.count > 1 {
                Text("+\(items.count - 1)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
        .padding(8)
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    FolderPreviewPopover(folderURL: URL(fileURLWithPath: NSHomeDirectory()), isPinned: true)
        .padding()
        .background(Color.black)
}
