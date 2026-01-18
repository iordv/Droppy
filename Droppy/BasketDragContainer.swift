import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Basket Drag Container
// Extracted from FloatingBasketWindowController.swift for faster incremental builds

class BasketDragContainer: NSView {
    
    /// Track if a drop occurred during current drag session
    private var dropDidOccur = false
    
    /// AirDrop zone width (must match FloatingBasketView.airDropZoneWidth)
    private let airDropZoneWidth: CGFloat = 90
    
    /// Base width constants (must match FloatingBasketView)
    private let itemWidth: CGFloat = 76
    private let itemSpacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 24
    private let columnsPerRow: Int = 4
    
    /// Whether AirDrop zone is enabled
    /// CRITICAL: Must use object(forKey:) with nil-coalescing to true, matching @AppStorage default
    /// Using bool(forKey:) alone returns false when key doesn't exist, causing Issue #62
    private var isAirDropZoneEnabled: Bool {
        (UserDefaults.standard.object(forKey: "enableAirDropZone") as? Bool) ?? true
    }
    
    /// Whether AirDrop zone should be shown (enabled AND basket is empty)
    private var showAirDropZone: Bool {
        isAirDropZoneEnabled && DroppyState.shared.basketItems.isEmpty
    }
    
    /// Calculate base width (without AirDrop zone)
    private var baseWidth: CGFloat {
        if DroppyState.shared.basketItems.isEmpty {
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
    
    // CRITICAL: Enable periodic updates so zone targeting works even when mouse is stationary
    // Without this, draggingUpdated() is not called when the user pauses during a drag,
    // causing the AirDrop zone to appear unresponsive on some hardware.
    // See: Knowledge Item - Split Zone Containers v7.7.5 Fix
    override func wantsPeriodicDraggingUpdates() -> Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
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
        let result = point.x >= airDropLeftEdge && point.x <= basketRightEdge
        
        // Debug logging for Issue #62
        if result {
            print("📡 AirDrop Zone HIT: point.x=\(Int(point.x)) zone=[\(Int(airDropLeftEdge))...\(Int(basketRightEdge))]")
        }
        
        return result
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
            
            // Debug logging for Issue #62 - help diagnose zone detection issues
            let windowCenterX = bounds.width / 2
            let basketRightEdge = windowCenterX + currentBasketWidth / 2
            let airDropLeftEdge = basketRightEdge - airDropZoneWidth
            let basketLeftEdge = windowCenterX - currentBasketWidth / 2
            print("🎯 Zone: point.x=\(Int(point.x)) basket=[\(Int(basketLeftEdge))...\(Int(airDropLeftEdge))] airdrop=[\(Int(airDropLeftEdge))...\(Int(basketRightEdge))] isAirDrop=\(isOverAirDrop) isBasket=\(isOverBasket)")
            
            // Synchronous update for responsive feedback
            DroppyState.shared.isAirDropZoneTargeted = isOverAirDrop
            DroppyState.shared.isBasketTargeted = isOverBasket
        } else {
            DroppyState.shared.isBasketTargeted = true
            DroppyState.shared.isAirDropZoneTargeted = false
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Reset flag at start of new drag
        dropDidOccur = false
        updateZoneTargeting(for: sender)
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Update targeting as cursor moves between zones
        updateZoneTargeting(for: sender)
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        DroppyState.shared.isBasketTargeted = false
        DroppyState.shared.isAirDropZoneTargeted = false
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        DroppyState.shared.isBasketTargeted = false
        DroppyState.shared.isAirDropZoneTargeted = false
        
        // Don't hide during file operations
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        
        // Only hide if NO drop occurred during this drag session
        // and basket is still empty
        if !dropDidOccur && DroppyState.shared.basketItems.isEmpty {
            FloatingBasketWindowController.shared.hideBasket()
        }
    }
    
    /// Handle AirDrop sharing for dropped files
    private func handleAirDropShare(_ pasteboard: NSPasteboard) -> Bool {
        // Try to read all file URLs from pasteboard
        var urls: [URL] = []
        
        // Method 1: Read objects
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
            FloatingBasketWindowController.shared.hideBasket()
            return true
        }
        
        // Log why AirDrop can't perform
        print("📡 AirDrop: canPerform returned false - check if AirDrop is enabled in System Settings > General > AirDrop")
        return false
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let point = convert(sender.draggingLocation, from: nil)
        
        DroppyState.shared.isBasketTargeted = false
        DroppyState.shared.isAirDropZoneTargeted = false
        
        // Mark that a drop occurred - don't hide on drag end
        dropDidOccur = true
        
        let pasteboard = sender.draggingPasteboard
        
        // Check if drop is in AirDrop zone
        if isPointInAirDropZone(point) {
            return handleAirDropShare(pasteboard)
        }
        
        // Normal basket behavior below...
        
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
