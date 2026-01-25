//
//  QuickshareManagerView.swift
//  Droppy
//
//  SwiftUI view for managing Quickshare upload history
//  Matches ClipboardItemRow styling exactly
//

import SwiftUI
import Observation

struct QuickshareManagerView: View {
    let onDismiss: () -> Void
    
    @State private var showDeleteConfirmation: QuickshareItem? = nil
    @State private var copiedItemId: UUID? = nil
    
    // Store reference to trigger observation tracking
    @Bindable private var manager = QuickshareManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - native Droppy style with close button
            HStack {
                Image(systemName: "drop.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.cyan)
                
                Text("Quickshare")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(manager.items.count) file\(manager.items.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                
                // Close button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Subtle separator
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            
            if manager.items.isEmpty {
                // Empty state - native Droppy style
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.white.opacity(0.2))
                    
                    Text("No shared files")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text("Files you share via Quickshare will appear here")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // List of shared files - matches clipboard list styling
                ScrollView {
                    LazyVStack(spacing: 6) {
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
                                onOpenInBrowser: {
                                    if let url = URL(string: item.shareURL) {
                                        NSWorkspace.shared.open(url)
                                    }
                                },
                                onDelete: {
                                    showDeleteConfirmation = item
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 450, height: 500)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
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

// MARK: - Item Row (matches ClipboardItemRow exactly)

struct QuickshareItemRow: View {
    let item: QuickshareItem
    let isCopied: Bool
    let isDeleting: Bool
    let onCopy: () -> Void
    let onShare: () -> Void
    let onOpenInBrowser: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon/Thumbnail - circular like ClipboardItemRow
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: fileIcon)
                    .foregroundStyle(.white)
                    .font(.system(size: 12))
            }
            
            // Title and metadata
            VStack(alignment: .leading, spacing: 1) {
                Text(item.filename)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(item.formattedSize)
                        .font(.system(size: 10))
                    Text("•")
                    Text(item.expirationText)
                        .foregroundStyle(item.isExpired ? .red : .secondary)
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // URL preview on the right (like clipboard source app)
            Text(item.shortURL)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isCopied
                      ? Color.green.opacity(isHovering ? 0.4 : 0.3)
                      : Color.white.opacity(isHovering ? 0.18 : 0.12))
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(DroppyAnimation.hoverBouncy, value: isHovering)
        .onTapGesture {
            onCopy()
        }
        .contextMenu {
            Button(action: onCopy) {
                Label(isCopied ? "Copied!" : "Copy Link", systemImage: isCopied ? "checkmark" : "doc.on.doc")
            }
            
            Button(action: onOpenInBrowser) {
                Label("Open in Browser", systemImage: "safari")
            }
            
            Button(action: onShare) {
                Label("Share...", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete from Server", systemImage: "trash")
            }
            .disabled(isDeleting)
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
    QuickshareManagerView(onDismiss: {})
        .preferredColorScheme(.dark)
}
