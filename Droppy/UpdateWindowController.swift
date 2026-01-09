//
//  UpdateWindowController.swift
//  Droppy
//
//  Created by Jordy Spruit on 04/01/2026.
//

import Cocoa
import SwiftUI

class UpdateWindowController: NSObject, NSWindowDelegate {
    static let shared = UpdateWindowController()
    
    /// The update window
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    /// Shows the update window, creating it if necessary
    func showWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // If window already exists, just bring it to front
            if let window = self.window {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                return
            }
            
            // Create the SwiftUI view
            let updateView = UpdateView()
            let hostingView = NSHostingView(rootView: updateView)
            
            // Compact window size - height determined by content
            let windowWidth: CGFloat = 400
            let windowHeight: CGFloat = 150 // Initial size, will adjust to content
            
            // Create the window - IDENTICAL style to SettingsWindowController
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            newWindow.center()
            newWindow.title = "Check for Updates"
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .visible
            
            // Configure background and appearance - IDENTICAL to SettingsWindowController
            // NOTE: Do NOT use isMovableByWindowBackground to avoid buttons/entries triggering window drag
            newWindow.isMovableByWindowBackground = false
            newWindow.backgroundColor = .clear
            newWindow.isOpaque = false
            newWindow.hasShadow = true
            newWindow.isReleasedWhenClosed = false
            
            newWindow.delegate = self
            newWindow.contentView = hostingView
            
            self.window = newWindow
            
            // Bring to front and activate
            // Use orderFront first, then async makeKey to ensure NotchWindow's canBecomeKey updates
            newWindow.orderFront(nil)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                newWindow.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    func closeWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.window?.close()
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
