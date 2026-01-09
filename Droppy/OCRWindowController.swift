//
//  OCRWindowController.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import AppKit
import SwiftUI

final class OCRWindowController: NSObject {
    static let shared = OCRWindowController()
    
    private(set) var window: NSPanel?
    
    private override init() {
        super.init()
    }
    
    func show(with text: String) {
        // If window already exists, close and recreate to ensure clean state
        close()
        
        let contentView = OCRResultView(text: text) { [weak self] in
            self?.close()
        }
        let hostingView = NSHostingView(rootView: contentView)
        
        let newWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newWindow.center()
        newWindow.title = "Extracted Text"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .visible
        
        newWindow.isMovableByWindowBackground = false
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .screenSaver
        newWindow.hidesOnDeactivate = false
        
        newWindow.contentView = hostingView
        
        // Fade in - use deferred makeKey to avoid NotchWindow conflicts
        newWindow.alphaValue = 0
        newWindow.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            newWindow.makeKeyAndOrderFront(nil)
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            newWindow.animator().alphaValue = 1.0
        }
        
        self.window = newWindow
    }
    
    func close() {
        guard let panel = window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.close()
            self?.window = nil
        })
    }
}
