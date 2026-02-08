//
//  SnapPreviewWindow.swift
//  Droppy
//
//  Magnet-style visual preview overlay for window snapping
//

import SwiftUI
import AppKit

/// Borderless overlay window that shows target snap zone
final class SnapPreviewWindow: NSWindow {
    static let shared = SnapPreviewWindow()
    
    private var fadeOutWorkItem: DispatchWorkItem?
    
    private init() {
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        // Configure as overlay
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Set up SwiftUI content
        contentView = NSHostingView(rootView: SnapPreviewView()
            )
    }
    
    /// Show preview at the given screen-coordinate frame (Y=0 at top)
    /// Converts to Cocoa coordinates (Y=0 at bottom) for NSWindow.
    /// Pass duration <= 0 to keep preview visible until hidePreview() is called.
    func showPreview(at screenFrame: CGRect, duration: TimeInterval = 0.15) {
        // Cancel any pending fade out
        fadeOutWorkItem?.cancel()
        fadeOutWorkItem = nil
        
        // Convert from screen coordinates (Y=0 at top) to Cocoa coordinates (Y=0 at bottom)
        let primaryScreen = NSScreen.screens.first
        let primaryHeight = primaryScreen?.frame.height ?? 0
        let cocoaY = primaryHeight - screenFrame.origin.y - screenFrame.height
        let cocoaFrame = CGRect(x: screenFrame.origin.x, y: cocoaY, width: screenFrame.width, height: screenFrame.height)
        
        // Position and size the window
        setFrame(cocoaFrame, display: true)

        // Only play present animation when transitioning from hidden -> visible.
        if !isVisible {
            AppKitMotion.prepareForPresent(self, initialScale: 1.0)
            orderFront(nil)
            AppKitMotion.animateIn(self, initialScale: 1.0, duration: 0.08)
        } else {
            orderFront(nil)
        }

        // Schedule fade-out only for timed previews (keyboard-triggered snap hints).
        guard duration > 0 else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.hidePreview()
        }
        fadeOutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }
    
    /// Hide the preview with snappy fade animation
    func hidePreview() {
        fadeOutWorkItem?.cancel()
        fadeOutWorkItem = nil

        guard isVisible else { return }
        AppKitMotion.animateOut(self, targetScale: 1.0, duration: 0.1) {
            self.orderOut(nil)
            AppKitMotion.resetPresentationState(self)
        }
    }
}

/// SwiftUI view for the preview rectangle
struct SnapPreviewView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
            .fill(Color.cyan.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .strokeBorder(Color.cyan.opacity(0.5), lineWidth: 2)
            )
            .padding(DroppySpacing.xs) // Small inset from window edge
    }
}
