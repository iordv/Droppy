//
//  QuickshareMenuContent.swift
//  Droppy
//
//  Menu bar content for Droppy Quickshare
//

import SwiftUI

struct QuickshareMenuContent: View {
    // Observe QuickshareManager for recent items
    @Bindable private var manager = QuickshareManager.shared
    @State private var clipboardURLs: [URL] = []
    
    /// When enabled, "Manage Uploads" opens Settings to Quickshare tab instead of standalone window
    @AppStorage(AppPreferenceKey.showQuickshareInSidebar) private var showQuickshareInSidebar = PreferenceDefault.showQuickshareInSidebar
    
    var body: some View {
        Group {
            Button {
                DroppyQuickshare.share(urls: clipboardURLs)
            } label: {
                Label("Upload from Clipboard", systemImage: "clipboard")
            }
            .disabled(clipboardURLs.isEmpty)
            
            Button {
                selectAndUploadFile()
            } label: {
                Label("Select File to Upload…", systemImage: "doc.badge.plus")
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
                if showQuickshareInSidebar {
                    // Open Settings to Quickshare tab
                    SettingsWindowController.shared.showSettings(tab: .quickshare)
                } else {
                    // Open standalone manager window
                    QuickshareManagerWindowController.show()
                }
            } label: {
                Label("Manage Uploads…", systemImage: "list.bullet")
            }
        }
        .onAppear {
            clipboardURLs = getClipboardURLs()
        }
    }
    
    // MARK: - Helpers
    
    private func getClipboardURLs() -> [URL] {
        guard let items = NSPasteboard.general.pasteboardItems else { return [] }
        var urls: [URL] = []
        var seen: Set<String> = []
        
        for item in items {
            // Check for file URLs
            if let string = item.string(forType: .fileURL), let url = URL(string: string) {
                appendUnique(url, to: &urls, seen: &seen)
            }

            if let string = item.string(forType: .URL),
               let url = parseWebURL(from: string) {
                appendUnique(url, to: &urls, seen: &seen)
            } else if let string = item.string(forType: .string),
                      let url = parseWebURL(from: string) {
                appendUnique(url, to: &urls, seen: &seen)
            }
        }
        return urls
    }

    private func appendUnique(_ url: URL, to urls: inout [URL], seen: inout Set<String>) {
        let key = url.isFileURL ? url.standardizedFileURL.path : url.absoluteString
        guard !key.isEmpty, !seen.contains(key) else { return }
        seen.insert(key)
        urls.append(url)
    }

    private func parseWebURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
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
