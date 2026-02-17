//
//  FilePromiseDropView.swift
//  Droppy
//
//  AppKit view that properly handles file promises from Photos.app
//  Used to wrap SwiftUI views that need file promise support
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - File Promise Drop View

/// An AppKit NSView that properly handles NSFilePromiseReceiver for Photos.app compatibility
/// Wraps any SwiftUI content and provides a callback with resolved file URLs
class FilePromiseDropNSView: NSView {
    
    var onFilesReceived: (([URL]) -> Void)?
    var onTargetingChanged: ((Bool) -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    
    private let filePromiseQueue = OperationQueue()
    private var trackingArea: NSTrackingArea?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragTypes()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragTypes()
    }
    
    private func setupDragTypes() {
        var types: [NSPasteboard.PasteboardType] = [
            .fileURL,
            NSPasteboard.PasteboardType(UTType.fileURL.identifier)
        ]
        
        // Add file promise types (critical for Photos.app)
        types.append(contentsOf: NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        
        registerForDraggedTypes(types)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]
        let newTrackingArea = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }
    
    // MARK: - NSDraggingDestination
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onTargetingChanged?(true)
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetingChanged?(false)
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        onTargetingChanged?(false)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // Ensure hover/target visuals are released immediately after drop begins.
        onTargetingChanged?(false)
        onHoverChanged?(false)

        let pasteboard = sender.draggingPasteboard
        var urls: [URL] = []
        
        // Method 1: Try direct file URLs first (fastest)
        if let readUrls = pasteboard.readObjects(forClasses: [NSURL.self], 
            options: [.urlReadingFileURLsOnly: true]) as? [URL], !readUrls.isEmpty {
            urls = readUrls
        }
        
        // Method 2: Handle file promises (Photos.app, etc.)
        if urls.isEmpty {
            if let promiseReceivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
               !promiseReceivers.isEmpty {
                
                print("📦 FilePromiseDrop: Receiving \(promiseReceivers.count) file promises…")
                
                // Create temp directory for promised files
                let dropLocation = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("DroppyQuickAction-\(UUID().uuidString)")
                try? FileManager.default.createDirectory(at: dropLocation, withIntermediateDirectories: true)
                
                let group = DispatchGroup()
                var receivedURLs: [URL] = []
                let urlsLock = NSLock()
                
                for receiver in promiseReceivers {
                    group.enter()
                    
                    receiver.receivePromisedFiles(atDestination: dropLocation, options: [:], operationQueue: filePromiseQueue) { fileURL, error in
                        defer { group.leave() }
                        
                        if let error = error {
                            print("📦 FilePromiseDrop: Promise failed: \(error.localizedDescription)")
                            return
                        }
                        
                        urlsLock.lock()
                        receivedURLs.append(fileURL)
                        urlsLock.unlock()
                        print("📦 FilePromiseDrop: Received \(fileURL.lastPathComponent)")
                    }
                }
                
                // Wait for all promises and call back with results
                group.notify(queue: .main) { [weak self] in
                    if !receivedURLs.isEmpty {
                        HapticFeedback.drop()
                        self?.onFilesReceived?(receivedURLs)
                    } else {
                        print("📦 FilePromiseDrop: No files received from promises")
                    }
                }
                
                return true
            }
        }
        
        // Direct URLs - call immediately
        if !urls.isEmpty {
            HapticFeedback.drop()
            onFilesReceived?(urls)
            return true
        }
        
        return false
    }
}

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

// MARK: - SwiftUI Representable

/// SwiftUI wrapper for FilePromiseDropNSView
struct FilePromiseDropTarget<Content: View>: NSViewRepresentable {
    let content: Content
    let onFilesReceived: ([URL]) -> Void
    let onHoverChanged: ((Bool) -> Void)?
    @Binding var isTargeted: Bool
    
    init(
        isTargeted: Binding<Bool>,
        onFilesReceived: @escaping ([URL]) -> Void,
        onHoverChanged: ((Bool) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._isTargeted = isTargeted
        self.onFilesReceived = onFilesReceived
        self.onHoverChanged = onHoverChanged
        self.content = content()
    }
    
    func makeNSView(context: Context) -> NSView {
        let dropView = FilePromiseDropNSView()
        dropView.onFilesReceived = onFilesReceived
        dropView.onHoverChanged = onHoverChanged
        dropView.onTargetingChanged = { targeted in
            DispatchQueue.main.async {
                self.isTargeted = targeted
            }
        }
        
        // Embed SwiftUI content
        let hostingView = PassthroughHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        dropView.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: dropView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: dropView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: dropView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: dropView.trailingAnchor)
        ])
        
        return dropView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update hosting view content if needed
        if let dropView = nsView as? FilePromiseDropNSView,
           let hostingView = dropView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

// MARK: - View Extension for Easy Usage

extension View {
    /// Adds file promise drop support (Photos.app, etc.)
    /// Uses AppKit's NSFilePromiseReceiver for reliable file promise handling
    func onFilePromiseDrop(isTargeted: Binding<Bool>, perform action: @escaping ([URL]) -> Void) -> some View {
        FilePromiseDropTarget(isTargeted: isTargeted, onFilesReceived: action) {
            self
        }
    }
}
