//
//  FloatingBasketWindowController.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Manages the floating basket window that appears during file drags
final class FloatingBasketWindowController: NSObject {
    /// The floating basket window
    var basketWindow: NSPanel?
    
    /// Shared instance
    static let shared = FloatingBasketWindowController()
    
    /// (Removed beta setting property)
    
    /// Prevent re-entrance
    private var isShowingOrHiding = false
    
    /// Initial basket position on screen (for determining expand direction)
    private var initialBasketOrigin: CGPoint = .zero
    
    /// Track if basket should expand upward (true) or downward (false)
    /// Set once when basket appears to avoid layout recalculations
    private(set) var shouldExpandUpward: Bool = true
    
    private override init() {
        super.init()
    }
    
    /// Called by DragMonitor when jiggle is detected
    func onJiggleDetected() {
        // Only move if visible AND not currently animating (show/hide) to prevent crash
        if let panel = basketWindow, panel.isVisible, !isShowingOrHiding {
            // If already visible, move it to new location
            moveBasketToMouse()
        } else if !isShowingOrHiding {
            showBasket()
        }
    }
    
    /// Called by DragMonitor when drag ends
    func onDragEnded() {
        guard basketWindow != nil, !isShowingOrHiding else { return }
        
        // Delay to allow drop operation to complete before checking
        // 300ms gives enough time for file URLs to be processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.basketWindow != nil else { return }
            // Only hide if basket is empty
            if DroppyState.shared.basketItems.isEmpty {
                self.hideBasket()
            }
        }
    }
    
    /// Moves the basket to the current mouse location
    private func moveBasketToMouse() {
        guard let panel = basketWindow else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 600
        
        // Update expand direction
        if let screen = NSScreen.main {
            let screenMidY = screen.frame.height / 2
            shouldExpandUpward = mouseLocation.y < screenMidY
        }
        
        // Center on mouse
        let xPosition = mouseLocation.x - windowWidth / 2
        let yPosition = mouseLocation.y - windowHeight / 2
        let newFrame = NSRect(x: xPosition, y: yPosition, width: windowWidth, height: windowHeight)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }
    
    /// Shows the basket near the current mouse location
    func showBasket() {
        guard basketWindow == nil, !isShowingOrHiding else { return }
        
        isShowingOrHiding = true
        
        let mouseLocation = NSEvent.mouseLocation
        // Use large window to accommodate dynamic SwiftUI content resizing
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 600
        
        // Store initial position for expand direction logic
        initialBasketOrigin = CGPoint(x: mouseLocation.x, y: mouseLocation.y)
        
        // Calculate expand direction once (basket expands upward if low on screen, downward if high)
        if let screen = NSScreen.main {
            let screenMidY = screen.frame.height / 2
            shouldExpandUpward = mouseLocation.y < screenMidY
        } else {
            shouldExpandUpward = true
        }
        
        // Position window so basket CENTER appears exactly at jiggle location
        let xPosition = mouseLocation.x - windowWidth / 2
        let yPosition = mouseLocation.y - windowHeight / 2
        
        let windowFrame = NSRect(x: xPosition, y: yPosition, width: windowWidth, height: windowHeight)
        
        // Use custom BasketPanel for floating utility window that can still accept text input
        let panel = BasketPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        
        // Create SwiftUI view
        let basketView = FloatingBasketView(state: DroppyState.shared)
        let hostingView = NSHostingView(rootView: basketView)
        
        // Create drag container
        let dragContainer = BasketDragContainer(frame: NSRect(origin: .zero, size: windowFrame.size))
        dragContainer.addSubview(hostingView)
        
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: dragContainer.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: dragContainer.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: dragContainer.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: dragContainer.trailingAnchor)
        ])
        
        panel.contentView = dragContainer
        
        // Reset notch hover
        DroppyState.shared.isMouseHovering = false
        DroppyState.shared.isDropTargeted = false
        DroppyState.shared.isBasketVisible = true
        
        // Start invisible for fade-in animation
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        // Smooth fade-in animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }
        
        basketWindow = panel
        isShowingOrHiding = false
    }
    
    /// Hides and closes the basket window with smooth animation
    func hideBasket() {
        guard let panel = basketWindow, !isShowingOrHiding else { return }
        
        isShowingOrHiding = true
        
        DroppyState.shared.isBasketVisible = false
        DroppyState.shared.isBasketTargeted = false
        
        // Smooth fade-out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.basketWindow = nil
            self?.isShowingOrHiding = false
        })
    }
}

// MARK: - Basket Drag Container

class BasketDragContainer: NSView {
    
    /// Track if a drop occurred during current drag session
    private var dropDidOccur = false
    
    private var filePromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        var types: [NSPasteboard.PasteboardType] = [.fileURL, .URL]
        types.append(contentsOf: NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        registerForDraggedTypes(types)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Reset flag at start of new drag
        dropDidOccur = false
        DroppyState.shared.isBasketTargeted = true
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        DroppyState.shared.isBasketTargeted = false
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        DroppyState.shared.isBasketTargeted = false
        
        // Only hide if NO drop occurred during this drag session
        // and basket is still empty
        if !dropDidOccur && DroppyState.shared.basketItems.isEmpty {
            FloatingBasketWindowController.shared.hideBasket()
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        DroppyState.shared.isBasketTargeted = false
        
        // Mark that a drop occurred - don't hide on drag end
        dropDidOccur = true
        
        let pasteboard = sender.draggingPasteboard
        
        // Handle File Promises
        if let promiseReceivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
           !promiseReceivers.isEmpty {
            
            let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: dropLocation, withIntermediateDirectories: true, attributes: nil)
            
            for receiver in promiseReceivers {
                receiver.receivePromisedFiles(atDestination: dropLocation, options: [:], operationQueue: filePromiseQueue) { fileURL, error in
                    guard error == nil else { return }
                    DispatchQueue.main.async {
                        DroppyState.shared.addBasketItems(from: [fileURL])
                    }
                }
            }
            return true
        }
        
        // Handle File URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            DroppyState.shared.addBasketItems(from: urls)
            return true
        }
        
        return false
    }
}

// MARK: - Custom Panel Class
class BasketPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    // Also allow it to be main if needed, but Key is most important for input
    override var canBecomeMain: Bool {
        return true
    }
}
