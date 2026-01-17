import AppKit

/// Handles macOS Services for Finder integration
/// Services appear in Finder's right-click menu automatically
class ServiceProvider: NSObject {
    
    /// Called when user selects "Add to Droppy Shelf" from Finder context menu
    @objc func addToShelf(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handleFiles(from: pboard, target: "shelf")
    }
    
    /// Called when user selects "Add to Droppy Basket" from Finder context menu
    @objc func addToBasket(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handleFiles(from: pboard, target: "basket")
    }
    
    private func handleFiles(from pboard: NSPasteboard, target: String) {
        // Get file URLs from pasteboard
        guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return
        }
        
        // Filter to valid file URLs
        let fileURLs = urls.filter { $0.isFileURL }
        guard !fileURLs.isEmpty else { return }
        
        // Add files to Droppy
        DispatchQueue.main.async {
            let state = DroppyState.shared
            
            if target == "shelf" {
                state.addItems(from: fileURLs)
                // Show the shelf on main display (Services are triggered externally, not from a specific notch)
                NotchWindowController.shared.setupNotchWindow()
                if let mainDisplayID = NSScreen.main?.displayID {
                    state.expandShelf(for: mainDisplayID)
                }
            } else {
                state.addBasketItems(from: fileURLs)
                // Show the basket
                FloatingBasketWindowController.shared.showBasket()
            }
        }
    }
}
