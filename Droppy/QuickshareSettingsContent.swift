//
//  QuickshareSettingsContent.swift
//  Droppy
//
//  Quickshare settings section for the Settings sidebar
//  Provides file management directly in Settings when enabled
//

import SwiftUI

/// Settings content view for managing Quickshare files
/// Shown in Settings sidebar when "Show in Settings Sidebar" is enabled
struct QuickshareSettingsContent: View {
    @AppStorage(AppPreferenceKey.showQuickshareInMenuBar) private var showInMenuBar = PreferenceDefault.showQuickshareInMenuBar
    @AppStorage(AppPreferenceKey.showQuickshareInSidebar) private var showInSidebar = PreferenceDefault.showQuickshareInSidebar
    
    @Bindable private var manager = QuickshareManager.shared
    
    @State private var showDeleteConfirmation: QuickshareItem? = nil
    @State private var copiedItemId: UUID? = nil
    
    var body: some View {
        Group {
            // MARK: - Settings Section
            Section {
                // Menu bar toggle
                Toggle(isOn: $showInMenuBar) {
                    VStack(alignment: .leading) {
                        Text("Show in Menu Bar")
                        Text("Show Quickshare submenu in Droppy menu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.teal)
                
                // Sidebar toggle
                Toggle(isOn: $showInSidebar) {
                    VStack(alignment: .leading) {
                        Text("Show in Settings Sidebar")
                        Text("Quick access to file management from Settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.teal)
            } header: {
                Text("Settings")
            }
            
            // MARK: - Shared Files Section
            Section {
                if manager.items.isEmpty {
                    // Empty state
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text("No shared files yet")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("Share files via the basket's Quickshare action")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    // File list
                    ForEach(manager.items) { item in
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
                }
            } header: {
                HStack {
                    Text("Shared Files")
                    Spacer()
                    if !manager.items.isEmpty {
                        Text("\(manager.items.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // MARK: - About Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share screenshots, recordings, and files instantly with short, expiring links. No account required.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "server.rack")
                                .foregroundStyle(.cyan)
                                .frame(width: 16)
                            Text("Powered by 0x0.st – anonymous file hosting")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "externaldrive.fill")
                                .foregroundStyle(.cyan)
                                .frame(width: 16)
                            Text("Maximum file size: 512 MB")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .foregroundStyle(.cyan)
                                .frame(width: 16)
                            Text("Files expire automatically (30-365 days based on size)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("About Quickshare")
            }
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
    
    // MARK: - Alert Binding
    
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

#Preview {
    Form {
        QuickshareSettingsContent()
    }
    .frame(width: 500)
    .preferredColorScheme(.dark)
}
