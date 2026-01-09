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
    
    // MARK: - Position Calculation (v5.2)
    
    /// Calculates the basket position based on the user's snap position preference
    private func calculateBasketPosition() -> NSRect {
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 600
        let snapPosition = UserDefaults.standard.string(forKey: "basketSnapPosition") ?? "mouse"
        
        guard let screen = NSScreen.main else {
            // Fallback to mouse position
            let mouseLocation = NSEvent.mouseLocation
            return NSRect(x: mouseLocation.x - windowWidth/2, y: mouseLocation.y - windowHeight/2, width: windowWidth, height: windowHeight)
        }
        
        let padding: CGFloat = 40 // Distance from screen edge
        
        switch snapPosition {
        case "left":
            // Snap to left edge, vertically centered
            return NSRect(
                x: screen.frame.minX + padding,
                y: (screen.frame.height - windowHeight) / 2 + screen.frame.minY,
                width: windowWidth,
                height: windowHeight
            )
        case "right":
            // Snap to right edge, vertically centered
            return NSRect(
                x: screen.frame.maxX - windowWidth - padding,
                y: (screen.frame.height - windowHeight) / 2 + screen.frame.minY,
                width: windowWidth,
                height: windowHeight
            )
        case "bottom-center":
            // Snap to bottom center
            return NSRect(
                x: (screen.frame.width - windowWidth) / 2 + screen.frame.minX,
                y: screen.frame.minY + padding,
                width: windowWidth,
                height: windowHeight
            )
        default: // "mouse"
            // Follow mouse (original behavior)
            let mouseLocation = NSEvent.mouseLocation
            return NSRect(
                x: mouseLocation.x - windowWidth/2,
                y: mouseLocation.y - windowHeight/2,
                width: windowWidth,
                height: windowHeight
            )
        }
    }
    
    /// Moves the basket to the calculated position (based on snap setting)
    private func moveBasketToMouse() {
        guard let panel = basketWindow else { return }
        
        let snapPosition = UserDefaults.standard.string(forKey: "basketSnapPosition") ?? "mouse"
        
        // For fixed snap positions, don't move on subsequent jiggles
        // Only move if mode is "mouse" (follow cursor)
        guard snapPosition == "mouse" else { return }
        
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
        DroppyState.shared.isBasketVisible = true
        
        // Start invisible for fade-in animation
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
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
        
        isShowingOrHiding = true
        
        DroppyState.shared.isBasketVisible = false
        DroppyState.shared.isBasketTargeted = false
        
        // Stop keyboard monitoring
        stopKeyboardMonitor()
        
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
