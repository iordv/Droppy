//
//  DraggableArea.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    let selectionSignature: Int // Force update
    
    init(
        items: @escaping () -> [NSPasteboardWriting],
        onTap: @escaping (NSEvent.ModifierFlags) -> Void,
        onDoubleClick: @escaping () -> Void = {},
        onRightClick: @escaping () -> Void,
        onDragStart: (() -> Void)? = nil,  // Default to nil for backward compatibility
        onDragComplete: ((NSDragOperation) -> Void)? = nil,
        selectionSignature: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.items = items
        self.onTap = onTap
        self.onDoubleClick = onDoubleClick
        self.onRightClick = onRightClick
        self.onDragStart = onDragStart
        self.onDragComplete = onDragComplete
        self.selectionSignature = selectionSignature
        self.content = content()
    }
    
    func makeNSView(context: Context) -> DraggableAreaView<Content> {
        return DraggableAreaView(rootView: content, items: items, onTap: onTap, onDoubleClick: onDoubleClick, onRightClick: onRightClick, onDragStart: onDragStart, onDragComplete: onDragComplete)
    }
    
    func updateNSView(_ nsView: DraggableAreaView<Content>, context: Context) {
        // CRITICAL: Skip updating the hosting view content when a context menu is open
        // Updating rootView causes SwiftUI to recreate the view, dismissing the menu
        // Exclude Droppy's own windows (BasketPanel, ClipboardPanel, NotchWindow) which are at high levels
        let hasActiveMenu = NSApp.windows.contains { window in
            guard window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue else { return false }
            // Exclude our own app windows
            let className = NSStringFromClass(type(of: window))
            if className.contains("BasketPanel") ||
               className.contains("ClipboardPanel") ||
               className.contains("NotchWindow") ||
               className.contains("NSHosting") ||
               className.contains("Popover") ||
               className.contains("Tooltip") {
                return false
            }
            return true
        }
        guard !hasActiveMenu else { return }
        
        nsView.update(rootView: content, items: items, onTap: onTap, onDoubleClick: onDoubleClick, onRightClick: onRightClick, onDragStart: onDragStart, onDragComplete: onDragComplete)
    }
}

class DraggableAreaView<Content: View>: NSView, NSDraggingSource {
    var items: () -> [NSPasteboardWriting]
    var onTap: (NSEvent.ModifierFlags) -> Void
    var onDoubleClick: () -> Void
    var onRightClick: () -> Void
    var onDragStart: (() -> Void)?
    var onDragComplete: ((NSDragOperation) -> Void)?
    
    private var hostingView: NSHostingView<Content>
    private var mouseDownEvent: NSEvent?
    
    /// CRITICAL: Retain drag preview images for the duration of the drag session.
    /// Without this, Core Animation may try to release images that ARC has already deallocated,
    /// causing crashes in RB::SurfacePool::collect / release_image.
    private var dragSessionImages: [NSImage] = []
    
    init(rootView: Content, items: @escaping () -> [NSPasteboardWriting], onTap: @escaping (NSEvent.ModifierFlags) -> Void, onDoubleClick: @escaping () -> Void, onRightClick: @escaping () -> Void, onDragStart: (() -> Void)?, onDragComplete: ((NSDragOperation) -> Void)?) {
        self.items = items
        self.onTap = onTap
        self.onDoubleClick = onDoubleClick
        self.onRightClick = onRightClick
        self.onDragStart = onDragStart
        self.onDragComplete = onDragComplete
        self.hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        
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
    
    func update(rootView: Content, items: @escaping () -> [NSPasteboardWriting], onTap: @escaping (NSEvent.ModifierFlags) -> Void, onDoubleClick: @escaping () -> Void, onRightClick: @escaping () -> Void, onDragStart: (() -> Void)?, onDragComplete: ((NSDragOperation) -> Void)?) {
        self.hostingView.rootView = rootView
        self.items = items
        self.onTap = onTap
        self.onDoubleClick = onDoubleClick
        self.onRightClick = onRightClick
        self.onDragStart = onDragStart
        self.onDragComplete = onDragComplete
    }
    
    override func mouseDown(with event: NSEvent) {
        self.mouseDownEvent = event
    }
    
    override func mouseUp(with event: NSEvent) {
        // If we get here without a drag starting, treat as click
        if let mouseDown = mouseDownEvent {
            if abs(event.locationInWindow.x - mouseDown.locationInWindow.x) < 5 &&
               abs(event.locationInWindow.y - mouseDown.locationInWindow.y) < 5 {
                
                if event.clickCount == 2 {
                    onDoubleClick()
                } else {
                    // Use NSEvent.modifierFlags class property for reliable detection in non-activating panels
                    onTap(NSEvent.modifierFlags)
                }
            }
        }
        mouseDownEvent = nil
    }
    
    override func rightMouseDown(with event: NSEvent) {
        // Handle right click - defer state changes to avoid view recreation lag
        // The onRightClick handler should use async if it modifies state that causes view recreation
        onRightClick()
        
        // Block hover effects while menu is open to prevent visual glitches
        DroppyState.shared.isInteractionBlocked = true
        
        // CRITICAL: Call super SYNCHRONOUSLY for instant menu appearance
        // The previous async dispatch was causing the 500ms lag
        super.rightMouseDown(with: event)
        
        // Menu has closed at this point - unblock interactions immediately
        // Use minimal delay just to ensure menu window is fully deallocated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            DroppyState.shared.isInteractionBlocked = false
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let mouseDown = mouseDownEvent else { return }
        
        // Simple threshold check
        let dragThreshold: CGFloat = 3.0
        let draggedDistance = hypot(event.locationInWindow.x - mouseDown.locationInWindow.x,
                                    event.locationInWindow.y - mouseDown.locationInWindow.y)
        
        if draggedDistance < dragThreshold {
            return
        }
        
        let pasteboardItems = items()
        guard !pasteboardItems.isEmpty else { return }
        
        // Clear any images from previous drag session
        dragSessionImages.removeAll()
        
        let draggingItems = pasteboardItems.enumerated().compactMap { [weak self] (index, writer) -> NSDraggingItem? in
            guard let self = self else { return nil }
            let dragItem = NSDraggingItem(pasteboardWriter: writer)
            
            // Use fast cached icons instead of loading full images (PERFORMANCE CRITICAL)
            var usedImage: NSImage?
            let frameSize = CGSize(width: 64, height: 64)
            
            if let url = writer as? NSURL, let path = url.path {
                // Use cached icon for instant performance
                usedImage = ThumbnailCache.shared.cachedIcon(forPath: path)
                usedImage?.size = frameSize
            } else {
                // Fallback to view snapshot for non-file items
                if let bitmap = self.hostingView.bitmapImageRepForCachingDisplay(in: self.hostingView.bounds),
                   let cgImage = bitmap.cgImage {
                    usedImage = NSImage(cgImage: cgImage, size: self.hostingView.bounds.size)
                }
            }
            
            guard let validImage = usedImage else { return nil }
            
            // CRITICAL: Retain the image for the drag session duration
            self.dragSessionImages.append(validImage)
            
            // Calculate frame centered on the view, with offset for multiple items
            let center = CGPoint(x: self.hostingView.bounds.midX, y: self.hostingView.bounds.midY)
            // Offset for stack effect (up and to the left/right)
            // Using slight randomness or fixed step
            let offset = CGFloat(index) * 3.0
            
            let origin = CGPoint(
                x: center.x - (frameSize.width / 2) + offset,
                y: center.y - (frameSize.height / 2) + offset
            )
            
            let dragFrame = NSRect(origin: origin, size: frameSize)
            dragItem.setDraggingFrame(dragFrame, contents: validImage)
            
            return dragItem
        }
        
        guard !draggingItems.isEmpty else { return }
        
        onDragStart?()
        beginDraggingSession(with: draggingItems, event: mouseDown, source: self)
        self.mouseDownEvent = nil
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
            // Check if drop location is inside the basket window
            if let basketWindow = FloatingBasketWindowController.shared.basketWindow {
                let basketFrame = basketWindow.frame
                if basketFrame.contains(screenPoint) {
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
