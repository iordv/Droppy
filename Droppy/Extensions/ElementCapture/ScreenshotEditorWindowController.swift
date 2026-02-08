//
//  ScreenshotEditorWindowController.swift
//  Droppy
//
//  Window controller for presenting the screenshot annotation editor
//

import SwiftUI
import AppKit

@MainActor
final class ScreenshotEditorWindowController {
    static let shared = ScreenshotEditorWindowController()
    
    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?
    
    private init() {}
    
    func show(with image: NSImage) {
        // Clean up any existing window
        cleanUp()
        
        // Calculate window size based on image aspect ratio
        let imageAspect = image.size.width / image.size.height
        let maxWidth: CGFloat = 800
        let maxHeight: CGFloat = 600
        
        var windowWidth = min(image.size.width + 80, maxWidth)
        var windowHeight = windowWidth / imageAspect + 60 // Extra for toolbar
        
        if windowHeight > maxHeight {
            windowHeight = maxHeight
            windowWidth = (maxHeight - 60) * imageAspect
        }
        
        windowWidth = max(windowWidth, 900)  // Must fit entire toolbar
        windowHeight = max(windowHeight, 500)
        
        let cornerRadius: CGFloat = 24
        
        // Create the editor view
        let editorView = ScreenshotEditorView(
            originalImage: image,
            onSave: { [weak self] annotatedImage in
                self?.saveAndClose(annotatedImage)
            },
            onCancel: { [weak self] in
                self?.dismiss()
            }
        )
        
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        
        // Create hosting view with layer clipping for proper rounded corners
        let hosting = NSHostingView(rootView: AnyView(editorView))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: windowWidth, height: windowHeight))
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = true
        hosting.layer?.cornerRadius = cornerRadius
        self.hostingView = hosting
        
        // Create resizable window with hidden titlebar
        let newWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: windowWidth, height: windowHeight)),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Hide titlebar but keep resize functionality
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.standardWindowButton(.closeButton)?.isHidden = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Size constraints for resizing - minWidth must fit entire toolbar
        newWindow.minSize = NSSize(width: 900, height: 400)
        newWindow.maxSize = NSSize(width: 1600, height: 1200)
        
        newWindow.contentView = hosting
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.level = .floating
        newWindow.isMovableByWindowBackground = false  // Disabled so canvas drawing doesn't move window
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Center on screen
        newWindow.center()
        
        // Show with animation
        AppKitMotion.prepareForPresent(newWindow, initialScale: 0.94)
        newWindow.makeKeyAndOrderFront(nil)
        AppKitMotion.animateIn(newWindow, initialScale: 0.94, duration: 0.2)
        
        self.window = newWindow
        
        // Close the preview window
        CapturePreviewWindowController.shared.dismiss()
    }
    
    private func saveAndClose(_ image: NSImage) {
        copyImageToPasteboard(image)
        
        // Play sound
        NSSound.beep()
        
        // Dismiss
        dismiss()
        
        // Show brief success toast via preview window
        CapturePreviewWindowController.shared.show(with: image)
    }
    
    private func copyImageToPasteboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            var wroteData = false
            
            if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                wroteData = pasteboard.setData(pngData, forType: .png) || wroteData
            }
            
            if let tiffData = bitmapRep.tiffRepresentation {
                wroteData = pasteboard.setData(tiffData, forType: .tiff) || wroteData
            }
            
            if !wroteData {
                pasteboard.writeObjects([image])
            }
            return
        }
        
        pasteboard.writeObjects([image])
    }
    
    func dismiss() {
        guard let window = window else { return }

        AppKitMotion.animateOut(window, targetScale: 0.97, duration: 0.16) { [weak self] in
            DispatchQueue.main.async {
                self?.cleanUp()
            }
        }
    }
    
    private func cleanUp() {
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
        hostingView = nil
    }
}
