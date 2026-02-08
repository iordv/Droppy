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
        
        AppKitMotion.prepareForPresent(newWindow, initialScale: 0.9)
        
        // Show - use deferred makeKey to avoid NotchWindow conflicts
        newWindow.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            newWindow.makeKeyAndOrderFront(nil)
        }
        AppKitMotion.animateIn(newWindow, initialScale: 0.9, duration: 0.24)
        
        self.window = newWindow
    }

    func presentExtractedText(_ text: String) {
        let shouldAutoCopy = UserDefaults.standard.preference(
            AppPreferenceKey.ocrAutoCopyExtractedText,
            default: PreferenceDefault.ocrAutoCopyExtractedText
        )
        let hasVisibleText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if shouldAutoCopy && hasVisibleText {
            close()
            TextCopyFeedback.copyOCRText(text)
        } else {
            show(with: text)
        }
    }
    
    func close() {
        guard let panel = window else { return }

        AppKitMotion.animateOut(panel, targetScale: 0.96, duration: 0.15) { [weak self] in
            panel.close()
            AppKitMotion.resetPresentationState(panel)
            self?.window = nil
        }
    }
}
