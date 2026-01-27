//
//  QuickshareInfoView.swift
//  Droppy
//
//  Quickshare extension configuration view
//

import SwiftUI

struct QuickshareInfoView: View {
    @AppStorage(AppPreferenceKey.showQuickshareInMenuBar) private var showInMenuBar = PreferenceDefault.showQuickshareInMenuBar
    @AppStorage(AppPreferenceKey.showQuickshareInSidebar) private var showInSidebar = PreferenceDefault.showQuickshareInSidebar
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
                    // 1. Explanation + Screenshot
                    featuresSection
                    
                    // 2. Menu Bar Toggle
                    settingsSection
                    
                    // 3. Files List (at bottom)
                    if !manager.items.isEmpty {
                        managerSection
                    }
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
            // Icon from website
            CachedAsyncImage(url: QuickshareExtension.iconURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                    Image(systemName: "drop.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.cyan)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.cyan.opacity(0.2), radius: 8, y: 4)
            
            HStack(alignment: .center, spacing: 10) {
                Text("Droppy Quickshare")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                
                if !manager.items.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(manager.items.count)")
                            .font(.system(size: 12, weight: .bold))
                        Text("shared file\(manager.items.count == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
                }
            }
            
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
        VStack(spacing: 8) {
            // Menu bar toggle
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
            
            // Settings sidebar toggle
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show in Settings Sidebar")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("Quick access to file management from Settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                 
                Spacer()
                
                Toggle("", isOn: $showInSidebar)
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
    }
    
    private var managerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Clean section header
            HStack {
                Text("Shared Files")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !manager.items.isEmpty {
                    Text("\(manager.items.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 4)
            
            // File list or empty state
            if manager.items.isEmpty {
                // Empty State
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("No shared files")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                // File List - spacing 8 to match clipboard
                VStack(spacing: 8) {
                    ForEach(manager.items) { item in
                        itemRow(for: item)
                    }
                }
            }
        }
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
                featureRow(icon: "square.grid.2x2", text: "Quick access via basket actions")
            }
            
            // Screenshot
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/images/quickshare-screenshot.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            } placeholder: {
                EmptyView()
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
