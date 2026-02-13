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
    private var escapeMonitor: Any?
    private var globalEscapeMonitor: Any?

    var currentWindowNumber: Int? { window?.windowNumber }
    
    private init() {}

    private struct EditorWindowSizing {
        let initialSize: NSSize
        let minSize: NSSize
        let maxSize: NSSize
        let targetScreen: NSScreen?
    }
    
    func show(with image: NSImage) {
        // Clean up any existing window
        cleanUp()

        let sizing = calculateWindowSizing(for: image)
        let windowWidth = sizing.initialSize.width
        let windowHeight = sizing.initialSize.height
        
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
        
        // Size constraints are screen-aware so the editor can open larger by default
        // while still fitting on smaller displays.
        newWindow.minSize = sizing.minSize
        newWindow.maxSize = sizing.maxSize
        
        newWindow.contentView = hosting
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.level = .floating
        newWindow.isMovableByWindowBackground = false  // Disabled so canvas drawing doesn't move window
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Center on the active screen (mouse display) so multi-monitor setups feel natural.
        if let targetScreen = sizing.targetScreen {
            let visibleFrame = targetScreen.visibleFrame
            let origin = NSPoint(
                x: visibleFrame.midX - windowWidth / 2,
                y: visibleFrame.midY - windowHeight / 2
            )
            newWindow.setFrameOrigin(origin)
        } else {
            newWindow.center()
        }
        
        // Show with animation
        AppKitMotion.prepareForPresent(newWindow, initialScale: 0.94)
        newWindow.makeKeyAndOrderFront(nil)
        AppKitMotion.animateIn(newWindow, initialScale: 0.94, duration: 0.2)
        
        self.window = newWindow
        installEscapeMonitors()
        
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

        // Prefer the image's existing representation to avoid rep re-resolution drift.
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData) {
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            var wroteData = false
            
            if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                wroteData = pasteboard.setData(pngData, forType: .png) || wroteData
            }
            
            wroteData = pasteboard.setData(tiffData, forType: .tiff) || wroteData
            
            if wroteData {
                return
            }
        }
        
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
        removeEscapeMonitors()

        AppKitMotion.animateOut(window, targetScale: 0.97, duration: 0.16) { [weak self] in
            DispatchQueue.main.async {
                self?.cleanUp()
            }
        }
    }
    
    private func cleanUp() {
        removeEscapeMonitors()
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
        hostingView = nil
    }

    private func installEscapeMonitors() {
        removeEscapeMonitors()

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            guard let self = self, let window = self.window, window.isVisible else { return event }
            guard !self.isTextInputActive(in: window) else { return event }
            self.dismiss()
            return nil
        }

        globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor [weak self] in
                guard let self = self, let window = self.window, window.isVisible else { return }
                guard !self.isTextInputActive(in: window) else { return }
                self.dismiss()
            }
        }
    }

    private func removeEscapeMonitors() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
        if let monitor = globalEscapeMonitor {
            NSEvent.removeMonitor(monitor)
            globalEscapeMonitor = nil
        }
    }

    private func isTextInputActive(in window: NSWindow) -> Bool {
        window.firstResponder is NSTextView
    }

    private func calculateWindowSizing(for image: NSImage) -> EditorWindowSizing {
        let targetScreen = activeScreenForPresentation()
        let visibleFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1512, height: 982)

        let safeImageWidth = max(image.size.width, 1)
        let safeImageHeight = max(image.size.height, 1)
        let imageAspect = safeImageWidth / safeImageHeight

        // Keep a margin from screen edges so shadows/resize handles remain visible.
        let screenPadding: CGFloat = 28
        let toolbarHeight: CGFloat = 110

        let maxWidth = max(visibleFrame.width - screenPadding * 2, 320)
        let maxHeight = max(visibleFrame.height - screenPadding * 2, 260)

        // Default to a large, readable window while respecting capture dimensions.
        let preferredWidth = min(maxWidth, max(safeImageWidth + 80, maxWidth * 0.72))
        var windowWidth = preferredWidth
        var windowHeight = windowWidth / imageAspect + toolbarHeight

        // If height overflows, fit by height and recompute width from aspect ratio.
        if windowHeight > maxHeight {
            windowHeight = maxHeight
            windowWidth = min(maxWidth, (maxHeight - toolbarHeight) * imageAspect)
        }

        // Keep an ergonomic minimum size, but never exceed max bounds.
        let minWidth = min(maxWidth, max(760, maxWidth * 0.55))
        let minHeight = min(maxHeight, max(460, maxHeight * 0.50))

        windowWidth = min(maxWidth, max(windowWidth, minWidth))
        windowHeight = min(maxHeight, max(windowHeight, minHeight))

        let maxSize = NSSize(
            width: maxWidth,
            height: maxHeight
        )

        return EditorWindowSizing(
            initialSize: NSSize(width: windowWidth, height: windowHeight),
            minSize: NSSize(width: minWidth, height: minHeight),
            maxSize: maxSize,
            targetScreen: targetScreen
        )
    }

    private func activeScreenForPresentation() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first
    }
}
