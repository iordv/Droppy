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
        contentView = NSHostingView(rootView: SnapPreviewView())
    }
    
    /// Show preview at the given screen-coordinate frame (Y=0 at top)
    /// Converts to Cocoa coordinates (Y=0 at bottom) for NSWindow
    func showPreview(at screenFrame: CGRect, duration: TimeInterval = 0.15) {
        // Cancel any pending fade out
        fadeOutWorkItem?.cancel()
        
        // Convert from screen coordinates (Y=0 at top) to Cocoa coordinates (Y=0 at bottom)
        let primaryScreen = NSScreen.screens.first
        let primaryHeight = primaryScreen?.frame.height ?? 0
        let cocoaY = primaryHeight - screenFrame.origin.y - screenFrame.height
        let cocoaFrame = CGRect(x: screenFrame.origin.x, y: cocoaY, width: screenFrame.width, height: screenFrame.height)
        
        // Position and size the window
        setFrame(cocoaFrame, display: true)
        
        // Snappy fade in
        alphaValue = 0
        orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.05
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
        
        // Schedule fade out
        let workItem = DispatchWorkItem { [weak self] in
            self?.hidePreview()
        }
        fadeOutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }
    
    /// Hide the preview with snappy fade animation
    func hidePreview() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}

/// SwiftUI view for the preview rectangle
struct SnapPreviewView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.blue.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.5), lineWidth: 2)
            )
            .padding(4) // Small inset from window edge
    }
}
