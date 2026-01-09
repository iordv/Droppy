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
    let onRightClick: () -> Void
    let selectionSignature: Int // Force update
    
    init(
        items: @escaping () -> [NSPasteboardWriting],
        onTap: @escaping (NSEvent.ModifierFlags) -> Void,
        onRightClick: @escaping () -> Void,
        selectionSignature: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.items = items
        self.onTap = onTap
        self.onRightClick = onRightClick
        self.selectionSignature = selectionSignature
        self.content = content()
    }
    
    func makeNSView(context: Context) -> DraggableAreaView<Content> {
        return DraggableAreaView(rootView: content, items: items, onTap: onTap, onRightClick: onRightClick)
    }
    
    func updateNSView(_ nsView: DraggableAreaView<Content>, context: Context) {
        nsView.update(rootView: content, items: items, onTap: onTap, onRightClick: onRightClick)
    }
}

class DraggableAreaView<Content: View>: NSView, NSDraggingSource {
    var items: () -> [NSPasteboardWriting]
    var onTap: (NSEvent.ModifierFlags) -> Void
    var onRightClick: () -> Void
    
    private var hostingView: NSHostingView<Content>
    private var mouseDownEvent: NSEvent?
    
    /// CRITICAL: Retain drag preview images for the duration of the drag session.
    /// Without this, Core Animation may try to release images that ARC has already deallocated,
    /// causing crashes in RB::SurfacePool::collect / release_image.
    private var dragSessionImages: [NSImage] = []
    
    init(rootView: Content, items: @escaping () -> [NSPasteboardWriting], onTap: @escaping (NSEvent.ModifierFlags) -> Void, onRightClick: @escaping () -> Void) {
        self.items = items
        self.onTap = onTap
        self.onRightClick = onRightClick
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
    
    func update(rootView: Content, items: @escaping () -> [NSPasteboardWriting], onTap: @escaping (NSEvent.ModifierFlags) -> Void, onRightClick: @escaping () -> Void) {
        self.hostingView.rootView = rootView
        self.items = items
        self.onTap = onTap
        self.onRightClick = onRightClick
    }
    
    override func mouseDown(with event: NSEvent) {
        self.mouseDownEvent = event
    }
    
    override func mouseUp(with event: NSEvent) {
        // If we get here without a drag starting, treat as click
        if let mouseDown = mouseDownEvent {
            if abs(event.locationInWindow.x - mouseDown.locationInWindow.x) < 5 &&
               abs(event.locationInWindow.y - mouseDown.locationInWindow.y) < 5 {
                // Use NSEvent.modifierFlags class property for reliable detection in non-activating panels
                onTap(NSEvent.modifierFlags)
            }
        }
        mouseDownEvent = nil
    }
    
    override func rightMouseDown(with event: NSEvent) {
        // Handle right click manually if needed, or pass through
        // But for our use case we want to catch it for selection logic
        super.rightMouseDown(with: event)
        onRightClick()
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
        
        beginDraggingSession(with: draggingItems, event: mouseDown, source: self)
        self.mouseDownEvent = nil
    }
    
    // MARK: - NSDraggingSource
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .every
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Release retained images now that drag session is complete
        dragSessionImages.removeAll()
    }
}
