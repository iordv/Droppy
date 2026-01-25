//
//  QuickshareManagerWindowController.swift
//  Droppy
//
//  Window controller for presenting the Quickshare Manager
//

import AppKit
import SwiftUI

/// Window controller for the Quickshare Manager
final class QuickshareManagerWindowController: NSWindowController {
    static var shared: QuickshareManagerWindowController?
    
    /// Show the Quickshare Manager window
    static func show() {
        if let existing = shared {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hostingView = NSHostingView(rootView: QuickshareManagerView())
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Quickshare Manager"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .hidden
        
        // Set minimum size
        window.minSize = NSSize(width: 350, height: 300)
        
        let controller = QuickshareManagerWindowController(window: window)
        shared = controller
        
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Hide the Quickshare Manager window
    static func hide() {
        shared?.close()
        shared = nil
    }
    
    deinit {
        if QuickshareManagerWindowController.shared === self {
            QuickshareManagerWindowController.shared = nil
        }
    }
}
