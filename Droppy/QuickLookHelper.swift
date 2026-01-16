import AppKit
import Quartz

/// Singleton helper for showing Quick Look previews
class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookHelper()
    
    private var previewItems: [URL] = []
    private weak var sourceWindow: NSWindow?
    
    private override init() {
        super.init()
    }
    
    /// Show Quick Look preview for the given file URLs (or toggle if visible)
    func preview(urls: [URL], from window: NSWindow? = nil) {
        guard !urls.isEmpty else { return }
        
        previewItems = urls
        sourceWindow = window
        
        DispatchQueue.main.async { [self] in
            guard let panel = QLPreviewPanel.shared() else { return }
            
            // Always set data source and delegate (they may have been cleared)
            panel.dataSource = self
            panel.delegate = self
            
            if panel.isVisible {
                // Panel is visible - just reload with new data
                panel.reloadData()
            } else {
                // Show the panel
                panel.makeKeyAndOrderFront(nil)
                // Force reload after display to ensure items are loaded
                DispatchQueue.main.async {
                    panel.reloadData()
                }
            }
        }
    }
    
    /// Toggle the Quick Look panel visibility
    func toggle() {
        DispatchQueue.main.async { [self] in
            guard let panel = QLPreviewPanel.shared() else { return }
            
            if panel.isVisible {
                panel.orderOut(nil)
            } else if !self.previewItems.isEmpty {
                panel.dataSource = self
                panel.delegate = self
                panel.makeKeyAndOrderFront(nil)
                // Force reload after display
                DispatchQueue.main.async {
                    panel.reloadData()
                }
            }
        }
    }
    
    /// Toggle preview for selected items from the shelf
    func togglePreviewSelectedShelfItems() {
        // If panel is visible, close it
        if let panel = QLPreviewPanel.shared(), panel.isVisible {
            panel.orderOut(nil)
            return
        }
        
        let selectedItems = DroppyState.shared.items.filter { 
            DroppyState.shared.selectedItems.contains($0.id) 
        }
        
        if selectedItems.isEmpty {
            // If nothing selected, preview first item
            if let first = DroppyState.shared.items.first {
                preview(urls: [first.url])
            }
        } else {
            preview(urls: selectedItems.map { $0.url })
        }
    }
    
    /// Toggle preview for selected items from the basket
    func togglePreviewSelectedBasketItems() {
        // If panel is visible, close it
        if let panel = QLPreviewPanel.shared(), panel.isVisible {
            panel.orderOut(nil)
            return
        }
        
        let selectedItems = DroppyState.shared.basketItems.filter { 
            DroppyState.shared.selectedBasketItems.contains($0.id) 
        }
        
        if selectedItems.isEmpty {
            // If nothing selected, preview first item
            if let first = DroppyState.shared.basketItems.first {
                preview(urls: [first.url])
            }
        } else {
            preview(urls: selectedItems.map { $0.url })
        }
    }
    
    /// Preview selected items from the shelf (non-toggle for backwards compat)
    func previewSelectedShelfItems() {
        togglePreviewSelectedShelfItems()
    }
    
    /// Preview selected items from the basket (non-toggle for backwards compat)
    func previewSelectedBasketItems() {
        togglePreviewSelectedBasketItems()
    }
    
    // MARK: - QLPreviewPanelDataSource
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return previewItems.count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        return previewItems[index] as NSURL
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: (any QLPreviewItem)!) -> NSRect {
        // Return the source window's frame for animation
        return sourceWindow?.frame ?? .zero
    }
}
