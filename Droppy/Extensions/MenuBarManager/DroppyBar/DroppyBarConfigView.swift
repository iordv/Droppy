//
//  DroppyBarConfigView.swift
//  Droppy
//
//  Configuration view for selecting which menu bar icons to show in Droppy Bar.
//

import SwiftUI
import AppKit

/// Configuration sheet for Droppy Bar
struct DroppyBarConfigView: View {
    let onDismiss: () -> Void
    
    @State private var menuBarItems: [MenuBarItem] = []
    @State private var selectedOwnerNames: Set<String> = []
    @State private var isLoading = true
    
    private var itemStore: DroppyBarItemStore {
        MenuBarManager.shared.getDroppyBarItemStore()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Configure Droppy Bar")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    saveSelection()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Instructions
            Text("Toggle items to show them in the Droppy Bar.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
            
            // Debug info
            Text("Selected: \(selectedOwnerNames.count) items")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
            
            // Item list
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Scanning menu bar...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if menuBarItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("No menu bar items found")
                        .font(.callout)
                    Text("Make sure screen recording is enabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(menuBarItems) { item in
                        HStack(spacing: 12) {
                            // Icon
                            if let app = item.owningApplication, let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "menubar.rectangle")
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Name
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.ownerName)
                                    .font(.body)
                                    .lineLimit(1)
                                Text("Window ID: \(item.windowID)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            
                            Spacer()
                            
                            // Toggle
                            Toggle("", isOn: Binding(
                                get: { selectedOwnerNames.contains(item.ownerName) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedOwnerNames.insert(item.ownerName)
                                    } else {
                                        selectedOwnerNames.remove(item.ownerName)
                                    }
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(width: 450, height: 500)
        .onAppear {
            loadMenuBarItems()
        }
    }
    
    private func loadMenuBarItems() {
        isLoading = true
        
        Task { @MainActor in
            // Get all menu bar items
            let allItems = MenuBarItem.getMenuBarItems(onScreenOnly: false, activeSpaceOnly: true)
            
            print("[DroppyBarConfig] Raw items: \(allItems.count)")
            for item in allItems {
                print("  - \(item.ownerName) (bundle: \(item.owningApplication?.bundleIdentifier ?? "nil"))")
            }
            
            // Filter out our own controls and deduplicate by ownerName
            var seenOwners: Set<String> = []
            menuBarItems = allItems.filter { item in
                // Skip Droppy's own items
                guard !item.ownerName.contains("Droppy") else { return false }
                
                // Skip duplicates
                guard !seenOwners.contains(item.ownerName) else { return false }
                seenOwners.insert(item.ownerName)
                
                return true
            }
            
            // Load current selection
            selectedOwnerNames = itemStore.enabledOwnerNames
            
            isLoading = false
            print("[DroppyBarConfig] Showing \(menuBarItems.count) unique items")
        }
    }
    
    private func saveSelection() {
        print("[DroppyBarConfig] Saving \(selectedOwnerNames.count) items: \(selectedOwnerNames)")
        
        // Clear existing items
        itemStore.clearAll()
        
        // Add selected items
        var position = 0
        for item in menuBarItems where selectedOwnerNames.contains(item.ownerName) {
            let droppyItem = DroppyBarItem(
                ownerName: item.ownerName,
                bundleIdentifier: item.owningApplication?.bundleIdentifier,
                displayName: item.displayName,
                position: position
            )
            itemStore.addItem(droppyItem)
            position += 1
        }
    }
}

#Preview {
    DroppyBarConfigView(onDismiss: {})
}
