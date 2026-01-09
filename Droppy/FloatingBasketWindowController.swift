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
    
    /// Keyboard monitor for spacebar Quick Look
    private var keyboardMonitor: Any?
    
    // MARK: - Auto-Hide Peek Mode (v5.3)
    
    /// Whether basket is currently in peek mode (collapsed at edge)
    private(set) var isInPeekMode: Bool = false
    
    /// Work item for delayed auto-hide (0.5 second delay)
    private var hideDelayWorkItem: DispatchWorkItem?
    
    /// Mouse tracking monitor for hover detection
    private var mouseTrackingMonitor: Any?
    
    /// Stored full-size basket position for restoration
    private var fullSizeFrame: NSRect = .zero
    
    /// Peek sliver size in pixels - how much of the window stays on screen
    /// With 3D tilt + 0.85 scale, we need less visible area
    private let peekSize: CGFloat = 200
    
    private override init() {
        super.init()
    }
    
    /// Called by DragMonitor when jiggle is detected
    func onJiggleDetected() {
        // Only move if visible AND not currently animating (show/hide)
        if let panel = basketWindow, panel.isVisible, !isShowingOrHiding {
            moveBasketToMouse()
        } else if !isShowingOrHiding {
            // Either basketWindow is nil or it's hidden - show it
            showBasket()
        }
    }
    
    /// Called by DragMonitor when drag ends
    func onDragEnded() {
        guard basketWindow != nil, !isShowingOrHiding else { return }
        
        // Don't hide during file operations
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        
        // Delay to allow drop operation to complete before checking
        // 300ms gives enough time for file URLs to be processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.basketWindow != nil else { return }
            // Don't hide during file operations (check again after delay)
            guard !DroppyState.shared.isFileOperationInProgress else { return }
            // Only hide if basket is empty
            if DroppyState.shared.basketItems.isEmpty {
                self.hideBasket()
            }
        }
    }
    
    // MARK: - Position Calculation
    
    /// Calculates the basket position centered on mouse
    private func calculateBasketPosition() -> NSRect {
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 600
        let mouseLocation = NSEvent.mouseLocation
        
        return NSRect(
            x: mouseLocation.x - windowWidth/2,
            y: mouseLocation.y - windowHeight/2,
            width: windowWidth,
            height: windowHeight
        )
    }
    
    /// Moves the basket to follow mouse on subsequent jiggles
    private func moveBasketToMouse() {
        guard let panel = basketWindow else { return }
        
        // Don't move if in auto-hide mode and peek mode is active
        if isAutoHideEnabled && isInPeekMode { return }
        
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
        
        // Avoid starting a new animation if we are already at or near the target frame
        // This prevents piling up _NSWindowTransformAnimation objects
        let currentFrame = panel.frame
        let deltaX = abs(currentFrame.origin.x - newFrame.origin.x)
        let deltaY = abs(currentFrame.origin.y - newFrame.origin.y)
        if deltaX < 1.0 && deltaY < 1.0 { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4 // Slower for "woosh"
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }, completionHandler: nil)
        
        panel.orderFrontRegardless()
    }
    
    /// Shows the basket near the current mouse location
    func showBasket() {
        guard !isShowingOrHiding else { return }
        
        // Defensive check: reclaim orphan window OR reuse existing hidden window
        if let panel = basketWindow ?? NSApp.windows.first(where: { $0 is BasketPanel }) as? NSPanel {
            basketWindow = panel
            panel.animator().alphaValue = 1.0 // Ensure visible
            moveBasketToMouse()
            return
        }

        isShowingOrHiding = true
        
        // Calculate window position based on snap preference (v5.2)
        let windowFrame = calculateBasketPosition()
        
        // Store initial position for expand direction logic
        let mouseLocation = NSEvent.mouseLocation
        initialBasketOrigin = CGPoint(x: mouseLocation.x, y: mouseLocation.y)
        
        // Calculate expand direction once (basket expands upward if low on screen, downward if high)
        if let screen = NSScreen.main {
            let screenMidY = screen.frame.height / 2
            // Use actual window position for expand direction
            shouldExpandUpward = windowFrame.midY < screenMidY
        } else {
            shouldExpandUpward = true
        }

        
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
        // Position just above Clipboard Manager (.popUpMenu = 101)
        panel.level = NSWindow.Level(Int(NSWindow.Level.popUpMenu.rawValue) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        
        // CRITICAL: Prevent AppKit from injecting its own unstable transform animations
        panel.animationBehavior = .none
        // Ensure manual memory management is stable
        panel.isReleasedWhenClosed = false
        
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
        
        // Validate basket items before showing (remove ghost files)
        DroppyState.shared.validateBasketItems()
        DroppyState.shared.isBasketVisible = true
        
        // Start invisible for fade-in animation
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey() // Make key window so keyboard shortcuts work
        
        // Smooth fade-in animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }, completionHandler: nil)
        
        basketWindow = panel
        isShowingOrHiding = false
        
        // Start keyboard monitor for Quick Look preview
        startKeyboardMonitor()
        
        // Start mouse tracking for auto-hide peek mode
        startMouseTrackingMonitor()
    }
    
    /// Starts keyboard monitor for spacebar Quick Look
    private func startKeyboardMonitor() {
        stopKeyboardMonitor() // Clean up any existing
        
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.basketWindow?.isVisible == true,
                  !DroppyState.shared.basketItems.isEmpty else {
                return event
            }
            
            // Spacebar triggers Quick Look
            if event.keyCode == 49 {
                QuickLookHelper.shared.previewSelectedBasketItems()
                return nil // Consume the event
            }
            return event
        }
    }
    
    /// Stops the keyboard monitor
    private func stopKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }
    
    /// Hides and closes the basket window with smooth animation
    func hideBasket() {
        guard let panel = basketWindow, !isShowingOrHiding else { return }
        
        // Block hiding during file operations UNLESS basket is empty (user cleared it manually)
        if DroppyState.shared.isFileOperationInProgress && !DroppyState.shared.basketItems.isEmpty {
            return 
        }
        
        isShowingOrHiding = true
        
        DroppyState.shared.isBasketVisible = false
        DroppyState.shared.isBasketTargeted = false
        
        // Stop keyboard monitoring
        stopKeyboardMonitor()
        
        // Stop mouse tracking
        stopMouseTrackingMonitor()
        
        // Reset peek mode
        isInPeekMode = false
        
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
    
    // MARK: - Auto-Hide Peek Mode Methods (v5.3)
    
    /// Checks if auto-hide mode is enabled
    private var isAutoHideEnabled: Bool {
        UserDefaults.standard.bool(forKey: "enableBasketAutoHide")
    }
    
    /// Gets the configured edge for auto-hide
    private var autoHideEdge: String {
        UserDefaults.standard.string(forKey: "basketAutoHideEdge") ?? "right"
    }
    
    /// Starts mouse tracking for auto-hide behavior
    func startMouseTrackingMonitor() {
        guard isAutoHideEnabled else { return }
        stopMouseTrackingMonitor() // Clean up existing
        
        mouseTrackingMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.handleMouseMovement()
        }
        
        // Also add local monitor for when basket window is focused
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMovement()
            return event
        }
    }
    
    /// Stops mouse tracking monitor
    private func stopMouseTrackingMonitor() {
        if let monitor = mouseTrackingMonitor {
            NSEvent.removeMonitor(monitor)
            mouseTrackingMonitor = nil
        }
    }
    
    /// Handles mouse movement for auto-hide logic
    private func handleMouseMovement() {
        guard let panel = basketWindow, panel.isVisible, !isShowingOrHiding else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let currentFrame = panel.frame
        
        // Add a small margin for comfortable hover detection
        let hoverFrame = currentFrame.insetBy(dx: -10, dy: -10)
        let isMouseOverBasket = hoverFrame.contains(mouseLocation)
        
        if isMouseOverBasket {
            // Mouse is over basket - cancel any pending hide and reveal if peeking
            cancelHideTimer()
            if isInPeekMode {
                revealFromEdge()
            }
        } else {
            // Skip auto-hide logic during file operations
            guard !DroppyState.shared.isFileOperationInProgress else { return }
            
            // Mouse left basket - start hide timer if not already peeking
            if !isInPeekMode && !DroppyState.shared.basketItems.isEmpty {
                startHideTimer()
            }
        }
    }
    
    /// Starts the delayed hide timer (0.5 second delay)
    func startHideTimer() {
        guard isAutoHideEnabled, !isInPeekMode else { return }
        
        // Don't start hide timer during file operations (zip, compress, convert, rename)
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        
        cancelHideTimer()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.slideToEdge()
        }
        hideDelayWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    /// Cancels any pending hide timer
    func cancelHideTimer() {
        hideDelayWorkItem?.cancel()
        hideDelayWorkItem = nil
    }
    
    /// Slides the basket to the configured edge in peek mode
    func slideToEdge() {
        guard let panel = basketWindow, !isInPeekMode, !isShowingOrHiding else { return }
        
        // Don't slide away during file operations
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        
        guard let screen = NSScreen.main else { return }
        guard let contentView = panel.contentView else { return }
        
        // Enable layer backing
        contentView.wantsLayer = true
        guard let layer = contentView.layer else { return }
        
        // Store current position for restoration
        fullSizeFrame = panel.frame
        
        // Calculate peek position based on edge - vertically centered
        var peekFrame = panel.frame
        let basketWidth = panel.frame.width
        let basketHeight = panel.frame.height
        let verticalCenter = screen.frame.minY + (screen.frame.height - basketHeight) / 2
        
        // Calculate transform for Stage Manager-style tilt
        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 800.0 // Perspective
        let angle: CGFloat = 0.18 // ~10 degrees, subtle
        
        switch autoHideEdge {
        case "left":
            peekFrame.origin.x = screen.frame.minX - basketWidth + peekSize
            peekFrame.origin.y = verticalCenter
            transform = CATransform3DRotate(transform, angle, 0, 1, 0)
        case "right":
            peekFrame.origin.x = screen.frame.maxX - peekSize
            peekFrame.origin.y = verticalCenter
            transform = CATransform3DRotate(transform, -angle, 0, 1, 0)
        case "bottom":
            peekFrame.origin.y = screen.frame.minY - basketHeight + peekSize
            transform = CATransform3DRotate(transform, angle, 1, 0, 0)
        default:
            peekFrame.origin.x = screen.frame.maxX - peekSize
            peekFrame.origin.y = verticalCenter
            transform = CATransform3DRotate(transform, -angle, 0, 1, 0)
        }
        
        // Scale down slightly
        transform = CATransform3DScale(transform, 0.92, 0.92, 1.0)
        
        isInPeekMode = true
        
        // Ensure layer is optimized for animation
        layer.drawsAsynchronously = true
        layer.shouldRasterize = true
        layer.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // Apple-style spring curve (aggressive ease-out with slight overshoot feel)
        let springCurve = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
        
        // Unified animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.55
            context.timingFunction = springCurve
            context.allowsImplicitAnimation = true
            
            panel.animator().setFrame(peekFrame, display: true)
            layer.transform = transform
        } completionHandler: {
            // Reset rasterization after animation to save memory
            layer.shouldRasterize = false
        }
    }
    
    /// Reveals the basket from peek mode back to full size
    func revealFromEdge() {
        guard let panel = basketWindow, isInPeekMode else { return }
        guard fullSizeFrame.width > 0 else { return }
        guard let contentView = panel.contentView, let layer = contentView.layer else { return }
        
        isInPeekMode = false
        
        // Pre-warm layer for immediate response
        layer.drawsAsynchronously = true
        layer.shouldRasterize = true
        layer.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // Very snappy curve for instant feel
        let revealCurve = CAMediaTimingFunction(controlPoints: 0.0, 0.0, 0.2, 1.0)
        
        // Shorter duration for responsive reveal
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = revealCurve
            context.allowsImplicitAnimation = true
            
            panel.animator().setFrame(fullSizeFrame, display: true)
            layer.transform = CATransform3DIdentity
        } completionHandler: {
            layer.shouldRasterize = false
        }
    }
    
    /// Called when cursor enters the basket area (from FloatingBasketView)
    func onBasketHoverEnter() {
        guard isAutoHideEnabled else { return }
        cancelHideTimer()
        if isInPeekMode {
            revealFromEdge()
        }
    }
    
    /// Called when cursor exits the basket area (from FloatingBasketView)
    func onBasketHoverExit() {
        guard isAutoHideEnabled, !DroppyState.shared.basketItems.isEmpty else { return }
        
        // Don't trigger hide during file operations
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        
        if !isInPeekMode {
            startHideTimer()
        }
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
        
        var types: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .URL,
            .string,
            // Email types for Mail.app
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeMessageTransfer"),
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeAutomator"),
            NSPasteboard.PasteboardType("com.apple.mail.message"),
            NSPasteboard.PasteboardType(UTType.emailMessage.identifier)
        ]
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
        
        // Don't hide during file operations
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        
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
        
        // Handle Mail.app emails directly via AppleScript
        let mailTypes: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeMessageTransfer"),
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeAutomator")
        ]
        let isMailAppEmail = mailTypes.contains(where: { pasteboard.types?.contains($0) ?? false })
        
        if isMailAppEmail {
            print("📧 Basket: Mail.app email detected, using AppleScript to export...")
            
            Task { @MainActor in
                let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
                
                let savedFiles = await MailHelper.shared.exportSelectedEmails(to: dropLocation)
                
                if !savedFiles.isEmpty {
                    DroppyState.shared.addBasketItems(from: savedFiles)
                } else {
                    print("📧 Basket: No emails exported")
                }
            }
            return true
        }
        
        // Handle File Promises (e.g. from Outlook, Photos)
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
        
        // Handle plain text drops - create a .txt file
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            // Create a temp directory for text files
            let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: dropLocation, withIntermediateDirectories: true, attributes: nil)
            
            // Generate a timestamped filename
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
            let timestamp = formatter.string(from: Date())
            let filename = "Text \(timestamp).txt"
            let fileURL = dropLocation.appendingPathComponent(filename)
            
            do {
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
                DroppyState.shared.addBasketItems(from: [fileURL])
                return true
            } catch {
                print("Error saving text file: \(error)")
                return false
            }
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
