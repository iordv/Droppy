//
//  FolderPreviewPopover.swift
//  Droppy
//
//  Shows a preview of folder contents when hovering over a pinned folder.
//  Uses a delay to avoid interfering with drag-and-drop operations.
//

import SwiftUI

/// Popover that shows the contents of a folder
/// Uses fixed height to prevent NSPopover animation crashes
struct FolderPreviewPopover: View {
    let folderURL: URL
    let maxItems: Int = 8
    
    // Pre-loaded content to avoid dynamic layout during popover animation
    private let contents: [(name: String, icon: NSImage, isDirectory: Bool)]
    private let totalCount: Int
    
    init(folderURL: URL) {
        self.folderURL = folderURL
        
        // Load contents synchronously during init to avoid layout changes
        let fm = FileManager.default
        if let urls = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            self.totalCount = urls.count
            
            // Sort: folders first, then by name
            let sorted = urls.sorted { url1, url2 in
                let isDir1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let isDir2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir1 != isDir2 { return isDir1 }
                return url1.lastPathComponent.localizedCaseInsensitiveCompare(url2.lastPathComponent) == .orderedAscending
            }
            
            self.contents = Array(sorted.prefix(maxItems).map { url in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                return (name: url.lastPathComponent, icon: icon, isDirectory: isDir)
            })
        } else {
            self.contents = []
            self.totalCount = 0
        }
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 14))
                Text(folderURL.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.bottom, 2)
            
            Divider()
            
            if contents.isEmpty {
                Text("Empty folder")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                // File list
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(contents.prefix(maxItems), id: \.name) { item in
                        HStack(spacing: 6) {
                            Image(nsImage: item.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                            
                            Text(item.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            if item.isDirectory {
                                Image(systemName: "folder")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if totalCount > maxItems {
                        Text("+\(totalCount - maxItems) more")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 180)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

#Preview {
    FolderPreviewPopover(folderURL: URL(fileURLWithPath: NSHomeDirectory()))
        .padding()
        .background(Color.black)
}
