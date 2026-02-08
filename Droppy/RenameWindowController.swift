import Cocoa
import SwiftUI

class RenameWindowController: NSObject, NSWindowDelegate {
    static let shared = RenameWindowController()
    
    var window: NSPanel!
    private var onRename: ((String) -> Void)?
    
    private override init() {
        super.init()
        setupWindow()
    }
    
    private func setupWindow() {
        // Create the window (panel)
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView], // Frameless appearance
            backing: .buffered,
            defer: false
        )
        
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Visual styling
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        
        // Delegate for lifecycle management
        window.delegate = self
    }
    
    func show(itemTitle: String, onRename: @escaping (String) -> Void) {
        self.onRename = onRename
        
        // Create the view
        let renameView = RenameWindowView(
            text: itemTitle,
            originalText: itemTitle,
            onRename: { [weak self] newText in
                self?.submit(newText)
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        
        // Host it
        window.contentView = NSHostingView(rootView: renameView)
        
        // Center on screen
        window.center()
        
        AppKitMotion.prepareForPresent(window, initialScale: 0.9)
        
        // Show and activate
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        AppKitMotion.animateIn(window, initialScale: 0.9, duration: 0.22)
        
        // PREMIUM: Haptic confirms rename window opened
        HapticFeedback.expand()
    }
    
    private func submit(_ text: String) {
        onRename?(text)
        close()
    }
    
    func close() {
        guard window.isVisible else {
            onRename = nil
            DispatchQueue.main.async { [weak self] in
                self?.window.contentView = nil
            }
            return
        }

        AppKitMotion.animateOut(window, targetScale: 0.97, duration: 0.12) { [weak self] in
            guard let self else { return }
            self.window.orderOut(nil)
            AppKitMotion.resetPresentationState(self.window)
            self.onRename = nil
            DispatchQueue.main.async {
                self.window.contentView = nil
            }
        }
    }
    
    // REMOVED: Auto-close on resign key
    // Keeping the rename window open when it loses focus allows the clipboard to stay visible
    // and prevents accidental data loss. User must explicitly Cancel or Save.
    // func windowDidResignKey(_ notification: Notification) {
    //     close()
    // }
}
