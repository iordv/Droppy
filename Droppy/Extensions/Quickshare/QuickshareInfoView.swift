//
//  QuickshareInfoView.swift
//  Droppy
//
//  Quickshare extension configuration view
//

import SwiftUI

struct QuickshareInfoView: View {
    @AppStorage(AppPreferenceKey.showQuickshareInMenuBar) private var showInMenuBar = PreferenceDefault.showQuickshareInMenuBar
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @Environment(\.dismiss) private var dismiss
    
    // For list observation
    @Bindable private var manager = QuickshareManager.shared
    
    @State private var showDeleteConfirmation: QuickshareItem? = nil
    @State private var copiedItemId: UUID? = nil
    @State private var showReviewsSheet = false
    
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    // Optional closure for when used in a standalone window
    var onClose: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Settings Toggle
                    settingsSection
                    
                    if !manager.items.isEmpty {
                        Divider()
                    }
                    
                    // Manager UI (Status + List)
                    managerSection
                    
                    Divider()
                    
                    // Features
                    featuresSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons
            buttonSection
        }
        .frame(width: 540)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .quickshare)
        }
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
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "drop.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.4), radius: 4, y: 0)
            }
            .shadow(color: Color.cyan.opacity(0.2), radius: 8, y: 4)
            
            Text("Droppy Quickshare")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            // Stats row
            HStack(spacing: 12) {
                // Installs
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
                // Rating
                Button {
                    showReviewsSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption.weight(.medium))
                            Text("(\(r.ratingCount))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("–")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(DroppySelectableButtonStyle(isSelected: false))
                
                // Category badge
                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.15))
                    )
            }
            
            Text("Quickly upload and share files via 0x0.st")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var settingsSection: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show in Menu Bar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("Show Quickshare submenu in Droppy menu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
             
            Spacer()
            
            Toggle("", isOn: $showInMenuBar)
                .toggleStyle(SwitchToggleStyle(tint: .cyan))
                .labelsHidden()
        }
        .padding(12)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var managerSection: some View {
        VStack(spacing: 0) {
            // Status Header
            HStack(alignment: .center, spacing: 12) {
                let statusIcon = manager.items.isEmpty ? "tray" : "tray.full.fill"
                let statusColor: Color = manager.items.isEmpty ? .secondary : .cyan
                let statusText = manager.items.isEmpty
                    ? "No shared files yet"
                    : "You have \(manager.items.count) shared file\(manager.items.count == 1 ? "" : "s")"
                
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.system(size: 14))
                    .frame(width: 22)
                
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.04)) // Subtle header bg
            
            // File List
            if !manager.items.isEmpty {
                Divider()
                    .overlay(Color.white.opacity(0.08))
                
                VStack(spacing: 0) {
                    ForEach(Array(manager.items.enumerated()), id: \.element.id) { index, item in
                        itemRow(for: item)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            // Alternating row background for subtle striping? Or just interaction highlight?
                            // Let's keep it clean
                        
                        if index < manager.items.count - 1 {
                             Divider()
                                .padding(.leading, 50) // Indent divider past icon
                                .overlay(Color.white.opacity(0.05))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // Previous statusCard helper removed as it's merged above
    
    private func itemRow(for item: QuickshareItem) -> some View {
        // We use QuickshareItemRow content directly here or wrapper
        // Since QuickshareItemRow has its own background styling in some implementations, 
        // we might need to adjust it to fit the "list" style.
        // Assuming QuickshareItemRow is what was used before.
        // If QuickshareItemRow has padding/background, it might mismatch.
        // I'll assume QuickshareItemRow is the row CONTENT.
        // If it has a background, this container might look layered.
        // Let's rely on standard row.
        
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
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share screenshots, recordings, and files instantly with short, expiring links. No account required.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "timer", text: "Files expire automatically (30-365 days base on size)")
                featureRow(icon: "link", text: "Instant short links copied to clipboard")
                featureRow(icon: "archivebox", text: "Auto-zips multiple files or folders")
                featureRow(icon: "list.bullet", text: "Built-in history and file management")
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                if let onClose = onClose {
                    onClose()
                } else {
                    dismiss()
                }
            } label: {
                Text("Close")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            // Core extension
            DisableExtensionButton(extensionType: .quickshare)
        }
        .padding(16)
    }
    
    // MARK: - Actions
    
    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { showDeleteConfirmation != nil },
            set: { if !$0 { showDeleteConfirmation = nil } }
        )
    }
    
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
