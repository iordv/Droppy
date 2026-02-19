import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Basket Drag Container
// Extracted from FloatingBasketWindowController.swift for faster incremental builds

class BasketDragContainer: NSView {
    
    /// Per-basket state (for multi-basket support - each container adds to its own basket)
    var basketState: BasketState
    
    /// Owning basket controller (weak to avoid retain cycles)
    weak var controller: FloatingBasketWindowController?
    
    /// Track if a drop occurred during current drag session
    private var dropDidOccur = false
    
    /// AirDrop zone width (must match FloatingBasketView.airDropZoneWidth)
    private let airDropZoneWidth: CGFloat = 90
    
    /// Track if current drag is valid (for Power Folders restriction)
    private var currentDragIsValid: Bool = true

    
    /// Base width constants (must match FloatingBasketView)
    private let itemWidth: CGFloat = 76
    private let itemSpacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 24
    private let columnsPerRow: Int = 4
    
    /// AirDrop zone is always enabled (v9.x+ simplification)
    private var isAirDropZoneEnabled: Bool {
        true
    }
    
    /// Whether AirDrop zone should be shown (always enabled, shown when basket is empty)
    private var showAirDropZone: Bool {
        basketState.items.isEmpty
    }
    
    /// Calculate base width (without AirDrop zone)
    private var baseWidth: CGFloat {
        if basketState.items.isEmpty {
            return 200
        } else {
            return CGFloat(columnsPerRow) * itemWidth + CGFloat(columnsPerRow - 1) * itemSpacing + horizontalPadding * 2
        }
    }
    
    /// Calculate current basket width
    private var currentBasketWidth: CGFloat {
        baseWidth + (showAirDropZone ? airDropZoneWidth : 0)
    }
    
    private var filePromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    init(frame frameRect: NSRect, basketState: BasketState, controller: FloatingBasketWindowController? = nil) {
        self.basketState = basketState
        self.controller = controller
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
    
    // MARK: - Efficient Mouse Tracking (v8.4.3 Lag Fix)
    // Replaces expensive global/local NSEvent monitoring in FloatingBasketWindowController
    
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        // Track enter/exit for auto-hide logic
        // Track mouseMoved for hover effects if needed (but SwiftUI handles that)
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]
        
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // Mouse entered basket: prevent auto-hide
        controller?.cancelHideTimer()
        
        // If peeking, reveal
        if controller?.isInPeekMode == true {
            controller?.revealFromEdge()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // Mouse exited basket: start auto-hide
        // Only if not dragging something
        controller?.onBasketHoverExit()
    }
    

    
    required init?(coder: NSCoder) {
        // Initialize required properties before calling super
        self.basketState = BasketState()
        self.controller = nil
        super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Check if point is in the AirDrop zone (right side of basket)
    private func isPointInAirDropZone(_ point: NSPoint) -> Bool {
        guard showAirDropZone else { return false }
        
        // Calculate zone boundaries based on window center and basket width
        let windowCenterX = bounds.width / 2
        let basketRightEdge = windowCenterX + currentBasketWidth / 2
        let airDropLeftEdge = basketRightEdge - airDropZoneWidth
        
        // Point is in AirDrop zone if it's within basket bounds AND in the right portion
        return point.x >= airDropLeftEdge && point.x <= basketRightEdge
    }
    
    /// Check if point is in the main basket zone (left side)
    private func isPointInBasketZone(_ point: NSPoint) -> Bool {
        let windowCenterX = bounds.width / 2
        let basketLeftEdge = windowCenterX - currentBasketWidth / 2
        
        if showAirDropZone {
            let basketRightEdge = windowCenterX + currentBasketWidth / 2
            let airDropLeftEdge = basketRightEdge - airDropZoneWidth
            // Main basket is the left portion (not including AirDrop zone)
            return point.x >= basketLeftEdge && point.x < airDropLeftEdge
        } else {
            let basketRightEdge = windowCenterX + currentBasketWidth / 2
            return point.x >= basketLeftEdge && point.x <= basketRightEdge
        }
    }
    
    /// Update zone targeting state based on cursor position
    private func updateZoneTargeting(for sender: NSDraggingInfo) {
        let point = convert(sender.draggingLocation, from: nil)
        
        if showAirDropZone {
            let isOverAirDrop = isPointInAirDropZone(point)
            let isOverBasket = isPointInBasketZone(point)

            // Avoid redundant state writes while dragging to reduce update churn.
            if basketState.isAirDropZoneTargeted != isOverAirDrop {
                basketState.isAirDropZoneTargeted = isOverAirDrop
            }
            if basketState.isTargeted != isOverBasket {
                basketState.isTargeted = isOverBasket
            }
        } else {
            if !basketState.isTargeted {
                basketState.isTargeted = true
            }
            if basketState.isAirDropZoneTargeted {
                basketState.isAirDropZoneTargeted = false
            }
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Reset flag at start of new drag
        dropDidOccur = false
        currentDragIsValid = true
        
        // Check Power Folders restriction
        // CRITICAL: Use object() ?? true to match @AppStorage default
        let powerFoldersEnabled = (UserDefaults.standard.object(forKey: "enablePowerFolders") as? Bool) ?? true
        
        if !powerFoldersEnabled {
            let pasteboard = sender.draggingPasteboard
            // Only read URLs if we need to check for folders
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
                // Check if any URL is a directory
                // We use a quick check on the first few items to avoid stalling the UI on massive drops
                let hasFolder = urls.prefix(10).contains { url in
                    var isDir: ObjCBool = false
                    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
                }
                
                if hasFolder {
                    print("🚫 Basket: Rejected folder drop (Power Folders disabled)")
                    currentDragIsValid = false
                    return []
                }
            }
        }
        
        updateZoneTargeting(for: sender)
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Respect validity check from draggingEntered
        if !currentDragIsValid { return [] }
        
        // Update targeting as cursor moves between zones
        updateZoneTargeting(for: sender)
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        basketState.isTargeted = false
        basketState.isAirDropZoneTargeted = false
        basketState.isQuickActionsTargeted = false
        basketState.hoveredQuickAction = nil
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        basketState.isTargeted = false
        basketState.isAirDropZoneTargeted = false
        basketState.isQuickActionsTargeted = false
        basketState.hoveredQuickAction = nil
        
        // Don't hide during file operations
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        
        // Only hide if NO drop occurred during this drag session
        // and basket is still empty
        if !dropDidOccur && basketState.items.isEmpty {
            controller?.hideBasket()
        }
    }
    
    /// Handle AirDrop sharing for dropped files
    /// Supports both direct file URLs and file promises (Photos.app, etc.)
    private func handleAirDropShare(_ pasteboard: NSPasteboard) -> Bool {
        // Try to read all file URLs from pasteboard
        var urls: [URL] = []
        
        // Method 1: Read objects (direct file URLs)
        if let readUrls = pasteboard.readObjects(forClasses: [NSURL.self], 
            options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            urls = readUrls
        }
        
        // Method 2: Fallback - read from pasteboardItems
        if urls.isEmpty, let items = pasteboard.pasteboardItems {
            for item in items {
                if let urlString = item.string(forType: .fileURL),
                   let url = URL(string: urlString) {
                    urls.append(url)
                }
            }
        }
        
        // Method 3: Handle file promises (Photos.app uses these)
        // If no direct URLs found, try file promises
        if urls.isEmpty {
            if let promiseReceivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
               !promiseReceivers.isEmpty {
                
                print("📡 AirDrop: Receiving file promises from Photos.app…")
                
                // Create a temp location for promised files
                let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("DroppyAirDrop-\(UUID().uuidString)")
                try? FileManager.default.createDirectory(at: dropLocation, withIntermediateDirectories: true)
                
                // Process promises asynchronously, then trigger AirDrop
                let group = DispatchGroup()
                var receivedURLs: [URL] = []
                let urlsLock = NSLock()
                
                for receiver in promiseReceivers {
                    group.enter()
                    receiver.receivePromisedFiles(atDestination: dropLocation, options: [:], operationQueue: filePromiseQueue) { fileURL, error in
                        defer { group.leave() }
                        
                        if let error = error {
                            print("📡 AirDrop: File promise failed: \(error.localizedDescription)")
                            return
                        }
                        
                        urlsLock.lock()
                        receivedURLs.append(fileURL)
                        urlsLock.unlock()
                        print("📡 AirDrop: Received \(fileURL.lastPathComponent)")
                    }
                }
                
                // Wait for promises and trigger AirDrop
                group.notify(queue: .main) {
                    if !receivedURLs.isEmpty {
                        if let airDropService = NSSharingService(named: .sendViaAirDrop),
                           airDropService.canPerform(withItems: receivedURLs) {
                            airDropService.perform(withItems: receivedURLs)
                            self.controller?.hideBasket()
                        } else {
                            print("📡 AirDrop: Cannot perform with promised files")
                            Task {
                                await DroppyAlertController.shared.showError(
                                    title: "AirDrop Failed",
                                    message: "Could not share via AirDrop. Check that AirDrop is enabled."
                                )
                            }
                        }
                    } else {
                        print("📡 AirDrop: No files received from promises")
                        Task {
                            await DroppyAlertController.shared.showError(
                                title: "AirDrop Failed",
                                message: "Could not receive file from Photos. If using iCloud Photos, ensure the image is downloaded locally first."
                            )
                        }
                    }
                }
                return true // Return immediately, AirDrop triggers async
            }
        }
        
        guard !urls.isEmpty else {
            print("📡 AirDrop: No file URLs found in pasteboard")
            return false
        }
        
        print("📡 AirDrop: Sharing \(urls.count) file(s)")
        for url in urls {
            let exists = FileManager.default.fileExists(atPath: url.path)
            print("📡 AirDrop: File: \(url.lastPathComponent) exists=\(exists)")
        }
        
        guard let airDropService = NSSharingService(named: .sendViaAirDrop) else {
            print("📡 AirDrop: Service not available - check if AirDrop is enabled")
            return false
        }
        
        if airDropService.canPerform(withItems: urls) {
            airDropService.perform(withItems: urls)
            // Hide basket immediately after triggering AirDrop
            controller?.hideBasket()
            return true
        }
        
        // Log why AirDrop can't perform
        print("📡 AirDrop: canPerform returned false - check if AirDrop is enabled in System Settings > General > AirDrop")
        return false
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // Respect validity check
        if !currentDragIsValid { return false }
        
        let point = convert(sender.draggingLocation, from: nil)
        
        basketState.isTargeted = false
        basketState.isAirDropZoneTargeted = false
        basketState.isQuickActionsTargeted = false
        basketState.hoveredQuickAction = nil
        
        // Mark that a drop occurred - don't hide on drag end
        dropDidOccur = true
        
        let pasteboard = sender.draggingPasteboard
        
        // Check if drop is in AirDrop zone
        if isPointInAirDropZone(point) {
            return handleAirDropShare(pasteboard)
        }
        
        // Normal basket behavior below…
        
        // Handle Mail.app emails directly via AppleScript
        let mailTypes: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeMessageTransfer"),
            NSPasteboard.PasteboardType("com.apple.mail.PasteboardTypeAutomator")
        ]
        let isMailAppEmail = mailTypes.contains(where: { pasteboard.types?.contains($0) ?? false })
        
        if isMailAppEmail {
            print("📧 Basket: Mail.app email detected, using AppleScript to export…")
            
            Task { @MainActor in
                let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
                
                let savedFiles = await MailHelper.shared.exportSelectedEmails(to: dropLocation)
                
                if !savedFiles.isEmpty {
                    basketState.addItems(from: savedFiles)
                } else {
                    print("📧 Basket: No emails exported")
                }
            }
            return true
        }
        
        // Handle File Promises (e.g. from Outlook, Photos)
        // Photos.app uses file promises - the actual file is delivered asynchronously
        // This can timeout for iCloud photos that need downloading
        if let promiseReceivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
           !promiseReceivers.isEmpty {
            
            let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: dropLocation, withIntermediateDirectories: true, attributes: nil)
            
            // Track success/failure for user feedback
            let totalCount = promiseReceivers.count
            var successCount = 0
            var errorCount = 0
            let completionLock = NSLock()
            
            // CRITICAL: Mark file operation in progress BEFORE async delivery
            // This prevents the basket from hiding while waiting for Photos.app to deliver files
            DispatchQueue.main.async {
                DroppyState.shared.beginFileOperation()
            }
            
            for receiver in promiseReceivers {
                // Log the file types being received for debugging
                print("📦 Basket: Receiving file promise from \(receiver.fileTypes)")
                
                receiver.receivePromisedFiles(atDestination: dropLocation, options: [:], operationQueue: filePromiseQueue) { fileURL, error in
                    completionLock.lock()
                    
                    if let error = error {
                        errorCount += 1
                        print("📦 Basket: File promise failed: \(error.localizedDescription)")
                        
                        // Show feedback on last item if all failed
                        if errorCount + successCount == totalCount && errorCount > 0 && successCount == 0 {
                            DispatchQueue.main.async {
                                // End file operation before showing error
                                DroppyState.shared.endFileOperation()
                                Task {
                                    await DroppyAlertController.shared.showError(
                                        title: "Drop Failed",
                                        message: "Could not receive file from Photos. If using iCloud Photos, ensure the image is downloaded locally first."
                                    )
                                }
                            }
                        }
                        // End file operation if this is the last promise (all failed or mixed)
                        else if errorCount + successCount == totalCount {
                            DispatchQueue.main.async {
                                DroppyState.shared.endFileOperation()
                            }
                        }
                        completionLock.unlock()
                        return
                    }
                    
                    successCount += 1
                    let isLastPromise = (errorCount + successCount == totalCount)
                    completionLock.unlock()
                    
                    print("📦 Basket: Successfully received \(fileURL.lastPathComponent)")
                    DispatchQueue.main.async { [weak self] in
                        self?.basketState.addItems(from: [fileURL])
                        // End file operation after last promise completes
                        if isLastPromise {
                            DroppyState.shared.endFileOperation()
                        }
                    }
                }
            }
            return true
        }
        
        // Handle File URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            basketState.addItems(from: urls)
            return true
        }
        
        // Handle text/URL drops.
        // Web links become .webloc items; plain text remains .txt.
        let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DroppyDrops-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dropLocation, withIntermediateDirectories: true, attributes: nil)
        let droppedFiles = DroppyLinkSupport.createTextOrLinkFiles(from: pasteboard, in: dropLocation)
        if !droppedFiles.isEmpty {
            basketState.addItems(from: droppedFiles)
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
