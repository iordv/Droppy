//
//  QuickshareManagerWindowController.swift
//  Droppy
//
//  Window controller for presenting the Quickshare Manager
//  Matches native Droppy window style (borderless NSPanel, like Onboarding)
//

import AppKit
import SwiftUI

/// Window controller for the Quickshare Manager
final class QuickshareManagerWindowController: NSObject, NSWindowDelegate {
    static var shared: QuickshareManagerWindowController?
    
    private var window: NSPanel?
    
    /// Show the Quickshare Manager window
    static func show() {
        if let existing = shared, let window = existing.window, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        // Clear old reference if window was closed
        if shared?.window == nil {
            shared = nil
        }
        
        let controller = QuickshareManagerWindowController()
        shared = controller
        controller.showWindow()
    }
    
    private func showWindow() {
        // Use QuickshareInfoView (the new consolidated UI)
        let contentView = QuickshareInfoView(
            installCount: nil,
            rating: nil, // Stats optional in standalone manager
            onClose: {
                QuickshareManagerWindowController.hide()
            }
        )
        
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.setFrameSize(hostingView.fittingSize) // Use intrinsic size
        
        // Use NSPanel with borderless style (matches Onboarding/UpdateView exactly)
        let newWindow = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.contentView = hostingView
        
        // Center on main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = newWindow.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2
            newWindow.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            newWindow.center()
        }
        newWindow.level = .floating
        
        self.window = newWindow
        AppKitMotion.prepareForPresent(newWindow, initialScale: 0.9)
        
        // Bring to front and activate
        newWindow.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            newWindow.makeKeyAndOrderFront(nil)
        }
        AppKitMotion.animateIn(newWindow, initialScale: 0.9, duration: 0.24)
        
        HapticFeedback.expand()
    }
    
    /// Hide the Quickshare Manager window
    static func hide() {
        guard let panel = shared?.window else { return }

        AppKitMotion.animateOut(panel, targetScale: 0.96, duration: 0.18) {
            shared?.window = nil
            panel.orderOut(nil)
            AppKitMotion.resetPresentationState(panel)
            shared = nil
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        window = nil
        QuickshareManagerWindowController.shared = nil
    }
}
