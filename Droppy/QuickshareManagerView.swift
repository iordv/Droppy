//
//  QuickshareManagerView.swift
//  Droppy
//
//  SwiftUI view for managing Quickshare upload history
//

import SwiftUI

struct QuickshareManagerView: View {
    @State private var manager = QuickshareManager.shared
    @State private var showDeleteConfirmation: QuickshareItem? = nil
    @State private var copiedItemId: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "drop.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.blue)
                
                Text("Quickshare Manager")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(manager.items.count) file\(manager.items.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if manager.items.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.tertiary)
                    
                    Text("No shared files")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text("Files you share via Quickshare will appear here")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            } else {
                // List of shared files
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(manager.items) { item in
                            QuickshareItemRow(
                                item: item,
                                isCopied: copiedItemId == item.id,
                                isDeleting: manager.isDeletingItem == item.id,
                                onCopy: {
                                    manager.copyToClipboard(item)
                                    copiedItemId = item.id
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        if copiedItemId == item.id {
                                            copiedItemId = nil
                                        }
                                    }
                                },
                                onShare: {
                                    shareItem(item)
                                },
                                onDelete: {
                                    showDeleteConfirmation = item
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .frame(width: 400, height: 450)
        .alert("Delete from Server?", isPresented: Binding(
            get: { showDeleteConfirmation != nil },
            set: { if !$0 { showDeleteConfirmation = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                showDeleteConfirmation = nil
            }
            Button("Delete", role: .destructive) {
                if let item = showDeleteConfirmation {
                    Task {
                        _ = await manager.deleteFromServer(item)
                    }
                }
                showDeleteConfirmation = nil
            }
        } message: {
            if let item = showDeleteConfirmation {
                Text("This will permanently delete \"\(item.filename)\" from the 0x0.st server. The link will stop working.")
            }
        }
    }
    
    private func shareItem(_ item: QuickshareItem) {
        guard let url = URL(string: item.shareURL) else { return }
        let picker = NSSharingServicePicker(items: [url])
        
        // Find the app's key window to anchor the picker
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        }
    }
}

// MARK: - Item Row

struct QuickshareItemRow: View {
    let item: QuickshareItem
    let isCopied: Bool
    let isDeleting: Bool
    let onCopy: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // File icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: fileIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
            }
            
            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(item.formattedSize)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text(item.expirationText)
                        .font(.system(size: 11))
                        .foregroundStyle(item.isExpired ? .red : .secondary)
                }
            }
            
            Spacer()
            
            // Action buttons (visible on hover or always on touch)
            if isHovering || isDeleting {
                HStack(spacing: 8) {
                    // Copy button
                    Button(action: onCopy) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isCopied ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy link")
                    
                    // Share button
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Share")
                    
                    // Delete button
                    Button(action: onDelete) {
                        if isDeleting {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isDeleting)
                    .help("Delete from server")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                // URL preview when not hovering
                Text(item.shortURL)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onCopy()
        }
    }
    
    private var fileIcon: String {
        let ext = (item.filename as NSString).pathExtension.lowercased()
        switch ext {
        case "zip": return "doc.zipper"
        case "pdf": return "doc.text"
        case "jpg", "jpeg", "png", "gif", "webp", "heic": return "photo"
        case "mp4", "mov", "avi", "mkv": return "film"
        case "mp3", "wav", "aac", "m4a": return "music.note"
        default: return "doc"
        }
    }
}

#Preview {
    QuickshareManagerView()
}
