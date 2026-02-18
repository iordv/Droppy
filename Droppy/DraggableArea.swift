//
//  DraggableArea.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import QuickLookThumbnailing
import AVKit

/// A wrapper view that intercepts mouse events to handle custom dragging and clicking, 
/// and provides a snapshot of the content for the drag image.
struct DraggableArea<Content: View>: NSViewRepresentable {
    let content: Content
    let items: () -> [NSPasteboardWriting]
    let onTap: (NSEvent.ModifierFlags) -> Void
    let onDoubleClick: () -> Void
    let onRightClick: () -> Void
    let onDragStart: (() -> Void)?
    let onDragComplete: ((NSDragOperation) -> Void)?  // Called when drag ends successfully
    let onRemoveButton: (() -> Void)?  // Called when X button is clicked
    let onPinButton: (() -> Void)?  // Called when pin button is clicked
    let selectionSignature: Int // Force update
    
    init(
        items: @escaping () -> [NSPasteboardWriting],
        onTap: @escaping (NSEvent.ModifierFlags) -> Void,
        onDoubleClick: @escaping () -> Void = {},
        onRightClick: @escaping () -> Void,
        onDragStart: (() -> Void)? = nil,
        onDragComplete: ((NSDragOperation) -> Void)? = nil,
        onRemoveButton: (() -> Void)? = nil,
        onPinButton: (() -> Void)? = nil,
        selectionSignature: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.items = items
        self.onTap = onTap
        self.onDoubleClick = onDoubleClick
        self.onRightClick = onRightClick
        self.onDragStart = onDragStart
        self.onDragComplete = onDragComplete
        self.onRemoveButton = onRemoveButton
        self.onPinButton = onPinButton
        self.selectionSignature = selectionSignature
        self.content = content()
    }
    
    func makeNSView(context: Context) -> DraggableAreaView<Content> {
        return DraggableAreaView(rootView: content, items: items, onTap: onTap, onDoubleClick: onDoubleClick, onRightClick: onRightClick, onDragStart: onDragStart, onDragComplete: onDragComplete, onRemoveButton: onRemoveButton, onPinButton: onPinButton)
    }
    
    func updateNSView(_ nsView: DraggableAreaView<Content>, context: Context) {
        // Skip content updates only while THIS draggable view is actively presenting
        // its context menu, or while an actual AppKit menu window is visible.
        // This avoids re-hosting the view while submenus are tracking.
        guard !nsView.isPresentingContextMenu, !nsView.isAnyMenuWindowVisible else { return }
        
        nsView.update(rootView: content, items: items, onTap: onTap, onDoubleClick: onDoubleClick, onRightClick: onRightClick, onDragStart: onDragStart, onDragComplete: onDragComplete, onRemoveButton: onRemoveButton, onPinButton: onPinButton)
    }
}

class DraggableAreaView<Content: View>: NSView, NSDraggingSource {
    var items: () -> [NSPasteboardWriting]
    var onTap: (NSEvent.ModifierFlags) -> Void
    var onDoubleClick: () -> Void
    var onRightClick: () -> Void
    var onDragStart: (() -> Void)?
    var onDragComplete: ((NSDragOperation) -> Void)?
    var onRemoveButton: (() -> Void)?
    var onPinButton: (() -> Void)?
    
    private var hostingView: NSHostingView<Content>
    private var mouseDownEvent: NSEvent?
    private var mouseDownModifierFlags: NSEvent.ModifierFlags = []
    fileprivate private(set) var isPresentingContextMenu = false
    fileprivate var isAnyMenuWindowVisible: Bool {
        hasVisibleMenuWindow()
    }
    
    /// CRITICAL: Retain drag preview images for the duration of the drag session.
    /// Without this, Core Animation may try to release images that ARC has already deallocated,
    /// causing crashes in RB::SurfacePool::collect / release_image.
    private var dragSessionImages: [NSImage] = []
    
    init(rootView: Content, items: @escaping () -> [NSPasteboardWriting], onTap: @escaping (NSEvent.ModifierFlags) -> Void, onDoubleClick: @escaping () -> Void, onRightClick: @escaping () -> Void, onDragStart: (() -> Void)?, onDragComplete: ((NSDragOperation) -> Void)?, onRemoveButton: (() -> Void)?, onPinButton: (() -> Void)?) {
        self.items = items
        self.onTap = onTap
        self.onDoubleClick = onDoubleClick
        self.onRightClick = onRightClick
        self.onDragStart = onDragStart
        self.onDragComplete = onDragComplete
        self.onRemoveButton = onRemoveButton
        self.onPinButton = onPinButton
        self.hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        
        // CRITICAL: Set low compression resistance so fixed frames are respected
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// CRITICAL: Report the hosting view's intrinsic size to SwiftUI
    /// Without this, the NSView may size incorrectly in LazyVGrid
    override var intrinsicContentSize: NSSize {
        return hostingView.intrinsicContentSize
    }
    
    func update(rootView: Content, items: @escaping () -> [NSPasteboardWriting], onTap: @escaping (NSEvent.ModifierFlags) -> Void, onDoubleClick: @escaping () -> Void, onRightClick: @escaping () -> Void, onDragStart: (() -> Void)?, onDragComplete: ((NSDragOperation) -> Void)?, onRemoveButton: (() -> Void)?, onPinButton: (() -> Void)?) {
        self.hostingView.rootView = rootView
        self.items = items
        self.onTap = onTap
        self.onDoubleClick = onDoubleClick
        self.onRightClick = onRightClick
        self.onDragStart = onDragStart
        self.onDragComplete = onDragComplete
        self.onRemoveButton = onRemoveButton
        self.onPinButton = onPinButton
    }
    
    // CRITICAL: Override hitTest to intercept ALL left-clicks for selection/drag
    // Button clicks are handled in mouseUp via zone detection and direct callbacks
    // Right-clicks pass through to SwiftUI for context menus
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        
        // For right-clicks, let them pass through to the hosting view for context menus
        if let event = NSApp.currentEvent, event.type == .rightMouseDown {
            let convertedPoint = convert(point, to: hostingView)
            return hostingView.hitTest(convertedPoint) ?? self
        }
        
        // For all left-clicks, intercept here for selection/drag/button zone detection
        return self
    }
    
    override func mouseDown(with event: NSEvent) {
        self.mouseDownEvent = event
        let liveModifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let sessionFlags = NSEvent.ModifierFlags(
            rawValue: NSEvent.ModifierFlags.RawValue(
                CGEventSource.flagsState(.combinedSessionState).rawValue
            )
        ).intersection(.deviceIndependentFlagsMask)
        self.mouseDownModifierFlags = event.modifierFlags
            .union(liveModifiers)
            .union(sessionFlags)
            .intersection(.deviceIndependentFlagsMask)
    }
    
    override func mouseUp(with event: NSEvent) {
        // If we get here without a drag starting, treat as click
        if let mouseDown = mouseDownEvent {
            let dx = abs(event.locationInWindow.x - mouseDown.locationInWindow.x)
            let dy = abs(event.locationInWindow.y - mouseDown.locationInWindow.y)
            if dx < 6 && dy < 6 {
                if event.clickCount == 2 {
                    onDoubleClick()
                } else {
                    // Check if click is in a button zone
                    let clickPoint = convert(event.locationInWindow, from: nil)
                    // Increased zone size for better hit detection (covers 28x28 area)
                    let buttonZoneSize: CGFloat = 28
                    
                    // X button zone: top-right corner (NSView coords: y=maxY is top)
                    let xButtonZone = NSRect(
                        x: bounds.maxX - buttonZoneSize,
                        y: bounds.maxY - buttonZoneSize,
                        width: buttonZoneSize,
                        height: buttonZoneSize
                    )
                    
                    // Pin button zone: bottom-right of ICON area
                    // Pin button is at SwiftUI offset(y: 54) from ZStack top (with 6pt top padding)
                    // In NSView coords: y = bounds.height - 54 - 9 (half button) ≈ height - 63
                    // For ~89pt content: center at ~26pt from bottom
                    // Center the 28pt zone on the button center
                    let pinCenterY = bounds.height - 54 - 9  // Approximate center of pin button
                    let pinButtonZone = NSRect(
                        x: bounds.maxX - buttonZoneSize,
                        y: pinCenterY - buttonZoneSize / 2,  // Center zone on button
                        width: buttonZoneSize,
                        height: buttonZoneSize
                    )
                    
                    if xButtonZone.contains(clickPoint), let onRemove = onRemoveButton {
                        onRemove()
                    } else if pinButtonZone.contains(clickPoint), let onPin = onPinButton {
                        onPin()
                    } else {
                        // Include event, live, and global session flags to keep Cmd/Shift taps
                        // reliable in non-activating panels.
                        let sessionFlags = NSEvent.ModifierFlags(
                            rawValue: NSEvent.ModifierFlags.RawValue(
                                CGEventSource.flagsState(.combinedSessionState).rawValue
                            )
                        ).intersection(.deviceIndependentFlagsMask)
                        let clickModifiers = mouseDownModifierFlags
                            .union(event.modifierFlags)
                            .union(NSEvent.modifierFlags)
                            .union(sessionFlags)
                            .intersection(.deviceIndependentFlagsMask)
                        onTap(clickModifiers)
                    }
                }
            }
        }
        mouseDownEvent = nil
        mouseDownModifierFlags = []
    }
    
    override func rightMouseDown(with event: NSEvent) {
        isPresentingContextMenu = true
        
        // Handle right click - defer state changes to avoid view recreation lag
        // The onRightClick handler should use async if it modifies state that causes view recreation
        onRightClick()
        
        // Block hover effects while menu is open to prevent visual glitches
        DroppyState.shared.isInteractionBlocked = true
        
        // CRITICAL: Call super SYNCHRONOUSLY for instant menu appearance
        // The previous async dispatch was causing the 500ms lag
        super.rightMouseDown(with: event)
        
        // Keep interactions blocked until the menu window is really gone.
        // This prevents view re-hosting while a submenu is open (flicker).
        waitForContextMenuDismissal()
    }

    private func waitForContextMenuDismissal(attempt: Int = 0) {
        guard isPresentingContextMenu else { return }

        // Give AppKit one cycle to instantiate the menu window.
        if attempt == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                self?.waitForContextMenuDismissal(attempt: 1)
            }
            return
        }

        let maxAttempts = 200
        if hasVisibleMenuWindow(), attempt < maxAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
                self?.waitForContextMenuDismissal(attempt: attempt + 1)
            }
            return
        }

        DroppyState.shared.isInteractionBlocked = false
        isPresentingContextMenu = false
    }

    private func hasVisibleMenuWindow() -> Bool {
        NSApp.windows.contains { window in
            guard window.isVisible else { return false }
            guard window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue else { return false }
            return NSStringFromClass(type(of: window)).lowercased().contains("menu")
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let mouseDown = mouseDownEvent else { return }
        
        // Simple threshold check
        let dragThreshold: CGFloat = 6.0
        let draggedDistance = hypot(event.locationInWindow.x - mouseDown.locationInWindow.x,
                                    event.locationInWindow.y - mouseDown.locationInWindow.y)
        
        if draggedDistance < dragThreshold {
            return
        }
        
        let pasteboardItems = items()
        guard !pasteboardItems.isEmpty else { return }
        
        // Clear any images from previous drag session
        dragSessionImages.removeAll()
        
        let bulkDragThreshold = 20
        let isBulkDrag = pasteboardItems.count > bulkDragThreshold
        let maxStackDepth = 10
        let bulkDragImage: NSImage? = {
            guard isBulkDrag else { return nil }
            let frameSize = CGSize(width: 64, height: 64)
            let baseSize = CGSize(width: 56, height: 56)

            let baseImage: NSImage = {
                guard let firstURLWriter = pasteboardItems.first(where: { $0 is NSURL }) as? NSURL,
                      let firstURL = firstURLWriter as URL? else {
                    let fallback = (DroppedItem.placeholderIcon.copy() as? NSImage) ?? DroppedItem.placeholderIcon
                    fallback.isTemplate = false
                    fallback.size = baseSize
                    return fallback
                }

                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: firstURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    let isPinnedInAnyBasket = FloatingBasketWindowController.basketsWithItems.contains { basket in
                        basket.basketState.items.contains(where: { $0.url == firstURL && $0.isPinned })
                    }
                    let isPinned = DroppyState.shared.items.contains(where: { $0.url == firstURL && $0.isPinned }) ||
                                   isPinnedInAnyBasket
                    return ThumbnailCache.shared.renderFolderIcon(size: baseSize.width, isPinned: isPinned)
                }

                return ThumbnailCache.shared.getCachedThumbnail(for: firstURL, size: baseSize)
                    ?? ThumbnailCache.shared.cachedIcon(forPath: firstURL.path)
            }()

            let image = NSImage(size: frameSize)
            image.lockFocus()
            NSColor.clear.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: frameSize)).fill()
            let drawRect = NSRect(
                x: (frameSize.width - baseSize.width) / 2,
                y: (frameSize.height - baseSize.height) / 2,
                width: baseSize.width,
                height: baseSize.height
            )
            baseImage.draw(
                in: drawRect,
                from: NSRect(origin: .zero, size: baseImage.size),
                operation: .sourceOver,
                fraction: 1.0
            )
            image.unlockFocus()
            image.isTemplate = false
            return image
        }()
        let draggingItems = pasteboardItems.enumerated().compactMap { [weak self] (index, writer) -> NSDraggingItem? in
            guard let self = self else { return nil }
            let dragItem = NSDraggingItem(pasteboardWriter: writer)
            
            // Use fast cached icons instead of loading full images (PERFORMANCE CRITICAL)
            var usedImage: NSImage?
            let frameSize = CGSize(width: 64, height: 64)
            
            if let url = writer as? NSURL, let fileURL = url as URL? {
                if isBulkDrag, let bulkImage = bulkDragImage {
                    usedImage = bulkImage
                } else {
                    // Check if this is a folder (use custom FolderIcon for visual consistency)
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        // Folder: Check if it's pinned on shelf or in any basket instance.
                        let isPinnedInAnyBasket = FloatingBasketWindowController.basketsWithItems.contains { basket in
                            basket.basketState.items.contains(where: { $0.url == fileURL && $0.isPinned })
                        }
                        let isPinned = DroppyState.shared.items.contains(where: { $0.url == fileURL && $0.isPinned }) ||
                                       isPinnedInAnyBasket
                        usedImage = ThumbnailCache.shared.renderFolderIcon(size: frameSize.width, isPinned: isPinned)
                    } else {
                        // File: Try to get cached THUMBNAIL first (for PDFs, videos, images, etc.)
                        // If no cached thumbnail exists, fall back to icon for instant performance
                        usedImage = ThumbnailCache.shared.getCachedThumbnail(for: fileURL)
                            ?? ThumbnailCache.shared.cachedIcon(forPath: fileURL.path)
                    }
                    usedImage?.size = frameSize
                }
            } else {
                // Fallback to view snapshot for non-file items
                if let bitmap = self.hostingView.bitmapImageRepForCachingDisplay(in: self.hostingView.bounds),
                   let cgImage = bitmap.cgImage {
                    usedImage = NSImage(cgImage: cgImage, size: self.hostingView.bounds.size)
                }
            }
            
            guard let validImage = usedImage else { return nil }
            validImage.isTemplate = false
            
            // CRITICAL: Retain the image for the drag session duration
            self.dragSessionImages.append(validImage)
            
            // Calculate frame positioned bottom-right of cursor using SSOT constants
            // The drag frame origin should position the image so it appears bottom-right of cursor
            // We use the mouse down location to calculate where to place the frame
            let mouseInView = self.convert(mouseDown.locationInWindow, from: nil)
            let baseOffset = DroppySpacing.dragCursorOffset
            let stackDepth = min(index, maxStackDepth)
            let stackOffset = CGFloat(stackDepth) * DroppySpacing.dragStackOffset
            
            // Position frame so image appears to the RIGHT and BELOW the cursor
            // Origin = mouse position + offset (right/down in view coords)
            let origin = CGPoint(
                x: mouseInView.x + baseOffset + stackOffset,
                y: mouseInView.y - frameSize.height - baseOffset - stackOffset
            )
            
            let dragFrame = NSRect(origin: origin, size: frameSize)
            dragItem.setDraggingFrame(dragFrame, contents: validImage)
            
            return dragItem
        }
        
        guard !draggingItems.isEmpty else { return }
        
        onDragStart?()
        beginDraggingSession(with: draggingItems, event: mouseDown, source: self)
        self.mouseDownEvent = nil
        self.mouseDownModifierFlags = []
    }
    
    // MARK: - NSDraggingSource
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Default: Copy only (prevents same-volume moves which confuse users)
        // User can opt into .every via the "Allow Move" setting for macOS default behavior
        let alwaysCopy = UserDefaults.standard.preference(
            AppPreferenceKey.alwaysCopyOnDrag,
            default: PreferenceDefault.alwaysCopyOnDrag
        )
        return alwaysCopy ? .copy : .every
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Release retained images now that drag session is complete
        dragSessionImages.removeAll()
        
        // Call completion callback if drag was successful (for auto-clean feature)
        // BUT skip if files were dropped back into a Droppy container (basket or shelf)
        // This prevents items from disappearing when just reorganizing within Droppy
        if operation != [] {
            // Check if drop location is inside any visible basket window.
            for basket in FloatingBasketWindowController.visibleBaskets {
                if let basketFrame = basket.basketWindow?.frame, basketFrame.contains(screenPoint) {
                    return // Internal basket drop - don't auto-clean
                }
            }
            
            // Check if drop location is inside any NotchWindow (shelf)
            for window in NSApp.windows {
                if window is NotchWindow, window.frame.contains(screenPoint) {
                    return // Internal shelf drop - don't auto-clean
                }
            }
            
            onDragComplete?(operation)
        }
    }
}
