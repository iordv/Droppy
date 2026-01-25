//
//  QuickshareManagerView.swift
//  Droppy
//
//  SwiftUI view for managing Quickshare upload history
//  Matches UpdateView styling exactly (adapts to dark/transparent mode)
//

import SwiftUI
import Observation

struct QuickshareManagerView: View {
    let onDismiss: () -> Void
    
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    
    @State private var showDeleteConfirmation: QuickshareItem? = nil
    @State private var copiedItemId: UUID? = nil
    
    // Store reference to trigger observation tracking
    @Bindable private var manager = QuickshareManager.shared
    
    var body: some View {
        mainContent
            .frame(width: 380)
            .fixedSize(horizontal: true, vertical: true)
            .background(backgroundStyle)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .alert("Delete from Server?", isPresented: deleteAlertBinding) {
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
    
    // MARK: - Subviews
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
                .padding(.horizontal, 24)
            
            statusCard
            
            if !manager.items.isEmpty {
                Divider()
                    .padding(.horizontal, 20)
                
                fileList
            }
            
            Divider()
                .padding(.horizontal, 20)
            
            actionButtons
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "drop.fill")
                .font(.system(size: 60))
                .foregroundStyle(.cyan)
            
            Text("Droppy Quickshare")
                .font(.title2.bold())
                .foregroundStyle(.primary)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
    }
    
    private var statusCard: some View {
        let statusIcon = manager.items.isEmpty ? "tray" : "tray.full.fill"
        let statusColor: Color = manager.items.isEmpty ? .secondary : .cyan
        let statusText = manager.items.isEmpty
            ? "No shared files yet"
            : "You have \(manager.items.count) shared file\(manager.items.count == 1 ? "" : "s")"
        
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.system(size: 14))
                    .frame(width: 22)
                
                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.02))
        }
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var fileList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(manager.items) { item in
                    itemRow(for: item)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: 250)
    }
    
    private func itemRow(for item: QuickshareItem) -> some View {
        QuickshareItemRow(
            item: item,
            isCopied: copiedItemId == item.id,
            isDeleting: manager.isDeletingItem == item.id,
            onCopy: { copyItem(item) },
            onShare: { shareItem(item) },
            onOpenInBrowser: { openInBrowser(item) },
            onDelete: { showDeleteConfirmation = item }
        )
    }
    
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Spacer()
            
            Button {
                onDismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
        }
        .padding(16)
    }
    
    @ViewBuilder
    private var backgroundStyle: some View {
        if useTransparentBackground {
            Rectangle().fill(.ultraThinMaterial)
        } else {
            Color.black
        }
    }
    
    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { showDeleteConfirmation != nil },
            set: { if !$0 { showDeleteConfirmation = nil } }
        )
    }
    
    // MARK: - Actions
    
    private func copyItem(_ item: QuickshareItem) {
        manager.copyToClipboard(item)
        copiedItemId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedItemId == item.id {
                copiedItemId = nil
            }
        }
    }
    
    private func shareItem(_ item: QuickshareItem) {
        guard let url = URL(string: item.shareURL) else { return }
        let picker = NSSharingServicePicker(items: [url])
        
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        }
    }
    
    private func openInBrowser(_ item: QuickshareItem) {
        if let url = URL(string: item.shareURL) {
            NSWorkspace.shared.open(url)
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
        rowContent
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(rowBackground)
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
    
    private var rowContent: some View {
        HStack(spacing: 10) {
            // Thumbnail preview - circular like ClipboardItemRow
            thumbnailView
            
            // Title and metadata
            VStack(alignment: .leading, spacing: 1) {
                Text(item.filename)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    // Show item count for multi-file zips
                    if item.itemCount > 1 {
                        Text("\(item.itemCount) files")
                        Text("•")
                    }
                    Text(item.formattedSize)
                    Text("•")
                    Text(item.expirationText)
                        .foregroundStyle(item.isExpired ? .red : .secondary)
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // URL preview on the right
            Text(item.shortURL)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
    
    private var thumbnailView: some View {
        ZStack {
            // Stacked appearance for multi-file zips
            if item.itemCount > 1 {
                // Back cards (offset to show stacking)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 28, height: 28)
                    .offset(x: 3, y: -3)
                
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 28, height: 28)
                    .offset(x: 1.5, y: -1.5)
            }
            
            // Main thumbnail
            if let thumbnail = item.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                // Fallback to system icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: fileIcon)
                        .foregroundStyle(.white)
                        .font(.system(size: 14))
                }
            }
        }
        .frame(width: 36, height: 36) // Slightly larger to accommodate stacking
    }
    
    private var rowBackground: some View {
        Capsule()
            .fill(isCopied
                  ? Color.green.opacity(isHovering ? 0.4 : 0.3)
                  : Color.white.opacity(isHovering ? 0.18 : 0.12))
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
