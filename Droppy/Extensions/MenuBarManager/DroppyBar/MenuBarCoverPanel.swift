//
//  MenuBarCoverPanel.swift
//  Droppy
//
//  Creates an overlay window that covers (hides) selected menu bar items
//  This allows us to "hide" items by drawing over them at the menu bar level
//

import SwiftUI
import AppKit

/// A panel that overlays the menu bar to visually hide selected items
@MainActor
class MenuBarCoverPanel: NSPanel {
    
    /// The items currently being covered (hidden)
    private var coveredItems: [MenuBarItem] = []
    
    /// Timer to update cover positions as items may move
    private var updateTimer: Timer?
    
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Critical: Position above menu bar items
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresHidden]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true // Let clicks pass through to what's underneath
        self.isReleasedWhenClosed = false
        
        print("[MenuBarCoverPanel] Initialized")
    }
    
    /// Update the cover to hide the specified items
    func updateCover(for items: [MenuBarItem]) {
        self.coveredItems = items
        
        guard !items.isEmpty else {
            orderOut(nil)
            return
        }
        
        // Get the menu bar screen
        guard let screen = NSScreen.main else { return }
        
        // Calculate the union of all item frames
        var coverRegions: [NSRect] = []
        
        for item in items {
            // Convert from CoreGraphics coordinates (top-left origin) to AppKit (bottom-left origin)
            let cgFrame = item.frame
            let appKitY = screen.frame.height - cgFrame.origin.y - cgFrame.height
            let frame = NSRect(
                x: cgFrame.origin.x,
                y: appKitY,
                width: cgFrame.width,
                height: cgFrame.height
            )
            coverRegions.append(frame)
        }
        
        // Create the cover view
        let coverView = MenuBarCoverView(regions: coverRegions, screen: screen)
        
        // Size the panel to cover the entire menu bar area
        let menuBarHeight: CGFloat = 37 // Standard menu bar height + buffer
        let panelFrame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - menuBarHeight,
            width: screen.frame.width,
            height: menuBarHeight
        )
        
        setFrame(panelFrame, display: false)
        contentView = NSHostingView(rootView: coverView)
        
        orderFrontRegardless()
        
        print("[MenuBarCoverPanel] Covering \(items.count) items")
    }
    
    /// Start auto-updating the cover positions
    func startAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCover()
            }
        }
    }
    
    /// Stop auto-updating
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// Refresh the cover based on current item positions
    private func refreshCover() {
        // Get fresh positions for currently covered items
        let allItems = MenuBarItem.getMenuBarItems()
        let ownerNames = Set(coveredItems.map { $0.ownerName })
        
        // Find updated positions for our covered items
        let updatedItems = allItems.filter { ownerNames.contains($0.ownerName) }
        
        // Deduplicate by owner
        var seen = Set<String>()
        let uniqueItems = updatedItems.filter { item in
            if seen.contains(item.ownerName) { return false }
            seen.insert(item.ownerName)
            return true
        }
        
        updateCover(for: uniqueItems)
    }
    
    /// Clear the cover (show all items)
    func clearCover() {
        coveredItems = []
        orderOut(nil)
        print("[MenuBarCoverPanel] Cover cleared")
    }
}

/// SwiftUI view that draws covers over specific regions
struct MenuBarCoverView: View {
    let regions: [NSRect]
    let screen: NSScreen
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw cover rectangles for each region
                ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
                    // Convert region to local coordinates
                    let localX = region.origin.x - screen.frame.origin.x
                    let localY = geometry.size.height - (region.origin.y - (screen.frame.maxY - geometry.size.height)) - region.height
                    
                    // Sample the menu bar background color and use it
                    menuBarBackgroundColor()
                        .frame(width: region.width + 4, height: region.height + 2)
                        .position(
                            x: localX + region.width / 2,
                            y: localY + region.height / 2
                        )
                }
            }
        }
        .ignoresSafeArea()
    }
    
    /// Get the appropriate menu bar background color
    private func menuBarBackgroundColor() -> Color {
        // Match the menu bar appearance
        // In dark mode, menu bar is dark; in light mode, it's light
        if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return Color(nsColor: NSColor(white: 0.2, alpha: 1.0))
        } else {
            return Color(nsColor: NSColor(white: 0.95, alpha: 1.0))
        }
    }
}
