//
//  QuickshareMenuContent.swift
//  Droppy
//
//  Menu bar content for Droppy Quickshare
//

import SwiftUI
import UniformTypeIdentifiers

struct QuickshareMenuContent: View {
    // Observe QuickshareManager for recent items
    @Bindable private var manager = QuickshareManager.shared
    @State private var copiedItemId: UUID? = nil
    
    var body: some View {
        Button {
            DroppyQuickshare.share(urls: getClipboardURLs())
        } label: {
            Label("Upload from Clipboard", systemImage: "clipboard")
        }
        .disabled(getClipboardURLs().isEmpty)
        
        Button {
            selectAndUploadFile()
        } label: {
            Label("Select File to Upload...", systemImage: "doc.badge.plus")
        }
        
        Divider()
        
        if !manager.items.isEmpty {
            Text("Recent Uploads")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ForEach(manager.items.prefix(5)) { item in
                Button {
                    manager.copyToClipboard(item)
                    // Haptic feedback?
                } label: {
                    HStack {
                        // Truncate filename nicely
                        Text(item.filename)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if item.itemCount > 1 {
                             Text("\(item.itemCount)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            
            Divider()
        }
        
        Button {
            QuickshareManagerWindowController.show()
        } label: {
            Label("Manage Uploads...", systemImage: "list.bullet")
        }
        

    }
    
    // MARK: - Helpers
    
    private func getClipboardURLs() -> [URL] {
        guard let items = NSPasteboard.general.pasteboardItems else { return [] }
        var urls: [URL] = []
        
        for item in items {
            // Check for file URLs
            if let string = item.string(forType: .fileURL), let url = URL(string: string) {
                urls.append(url)
            }
        }
        return urls
    }
    
    private func selectAndUploadFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false // 0x0.st usually for files, but we support zipping folders elsewhere? 
        // BasketQuickActionsBar handles multiple files by zipping. DroppyQuickshare.share takes [URL].
        // Let's allow multiple selection
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true // We can zip directories
        
        panel.begin { response in
            if response == .OK {
                DroppyQuickshare.share(urls: panel.urls)
            }
        }
    }
}
