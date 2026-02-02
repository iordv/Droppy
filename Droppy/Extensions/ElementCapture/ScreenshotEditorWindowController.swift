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
        
        windowWidth = max(windowWidth, 800)
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
        .preferredColorScheme(.dark)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        
        // Create hosting view with layer clipping for proper rounded corners
        let hosting = NSHostingView(rootView: AnyView(editorView))
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: windowWidth, height: windowHeight))
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = true
        hosting.layer?.cornerRadius = cornerRadius
        self.hostingView = hosting
        
        // Create borderless Droppy sheet window
        let newWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: windowWidth, height: windowHeight)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        newWindow.contentView = hosting
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true  // Window-level shadow (properly rounded)
        newWindow.level = .floating
        newWindow.isMovableByWindowBackground = false  // Disabled so canvas drawing doesn't move window
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Center on screen
        newWindow.center()
        
        // Show with animation
        newWindow.alphaValue = 0
        newWindow.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            newWindow.animator().alphaValue = 1
        }
        
        self.window = newWindow
        
        // Close the preview window
        CapturePreviewWindowController.shared.dismiss()
    }
    
    private func saveAndClose(_ image: NSImage) {
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        
        // Play sound
        NSSound.beep()
        
        // Dismiss
        dismiss()
        
        // Show brief success toast via preview window
        CapturePreviewWindowController.shared.show(with: image)
    }
    
    func dismiss() {
        guard let window = window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.cleanUp()
            }
        })
    }
    
    private func cleanUp() {
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
        hostingView = nil
    }
}
