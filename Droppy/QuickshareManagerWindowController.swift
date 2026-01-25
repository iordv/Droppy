//
//  QuickshareManagerWindowController.swift
//  Droppy
//
//  Window controller for presenting the Quickshare Manager
//  Matches native Droppy window style (borderless, black, spring animation)
//

import AppKit
import SwiftUI

/// Window controller for the Quickshare Manager
final class QuickshareManagerWindowController: NSObject, NSWindowDelegate {
    static var shared: QuickshareManagerWindowController?
    
    private var window: NSWindow?
    
    /// Show the Quickshare Manager window
    static func show() {
        if let existing = shared, let window = existing.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let controller = QuickshareManagerWindowController()
        shared = controller
        controller.showWindow()
    }
    
    private func showWindow() {
        let contentView = QuickshareManagerView()
            .preferredColorScheme(.dark)
        let hostingView = NSHostingView(rootView: contentView)
        
        let windowWidth: CGFloat = 420
        let windowHeight: CGFloat = 480
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.center()
        newWindow.title = "Quickshare"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .visible
        
        // Configure background and appearance (matches SettingsWindowController)
        newWindow.isMovableByWindowBackground = false
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 350, height: 300)
        
        newWindow.delegate = self
        newWindow.contentView = hostingView
        
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
        
        // PREMIUM: CASpringAnimation for true spring physics with overshoot
        if let layer = newWindow.contentView?.layer {
            // Fade in
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 0
            fadeAnim.toValue = 1
            fadeAnim.duration = 0.12
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
            scaleAnim.stiffness = 420
            scaleAnim.damping = 22
            scaleAnim.initialVelocity = 10
            scaleAnim.duration = scaleAnim.settlingDuration
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            layer.add(scaleAnim, forKey: "scaleSpring")
            layer.transform = CATransform3DIdentity
        }
        
        // Fade window alpha
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            newWindow.animator().alphaValue = 1.0
        })
        
        HapticFeedback.expand()
    }
    
    /// Hide the Quickshare Manager window
    static func hide() {
        shared?.window?.close()
        shared = nil
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        window = nil
        QuickshareManagerWindowController.shared = nil
    }
}
