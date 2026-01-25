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
        .preferredColorScheme(.dark)
        
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
        
        // PREMIUM: Start scaled down and invisible for spring animation
        newWindow.alphaValue = 0
        if let contentView = newWindow.contentView {
            contentView.wantsLayer = true
            contentView.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
            contentView.layer?.opacity = 0
        }
        
        // Bring to front and activate
        newWindow.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            newWindow.makeKeyAndOrderFront(nil)
        }
        
        // PREMIUM: CASpringAnimation for bouncy appear
        if let layer = newWindow.contentView?.layer {
            // Fade in
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 0
            fadeAnim.toValue = 1
            fadeAnim.duration = 0.25
            fadeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fadeAnim.fillMode = .forwards
            fadeAnim.isRemovedOnCompletion = false
            layer.add(fadeAnim, forKey: "fadeIn")
            layer.opacity = 1
            
            // Scale with spring overshoot
            let scaleAnim = CASpringAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.85
            scaleAnim.toValue = 1.0
            scaleAnim.mass = 1.0
            scaleAnim.stiffness = 250
            scaleAnim.damping = 22
            scaleAnim.initialVelocity = 6
            scaleAnim.duration = scaleAnim.settlingDuration
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            layer.add(scaleAnim, forKey: "scaleSpring")
            layer.transform = CATransform3DIdentity
        }
        
        // Fade window alpha
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            newWindow.animator().alphaValue = 1.0
        })
        
        HapticFeedback.expand()
    }
    
    /// Hide the Quickshare Manager window
    static func hide() {
        guard let panel = shared?.window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: {
            shared?.window = nil
            panel.orderOut(nil)
            shared = nil
        })
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        window = nil
        QuickshareManagerWindowController.shared = nil
    }
}
