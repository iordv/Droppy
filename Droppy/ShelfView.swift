//
//  ShelfView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

/// The main shelf view that displays dropped items and handles new drops
/// Items display as individual tiles (stacks feature removed)
struct ShelfView: View {
    /// Reference to the app state
    @Bindable var state: DroppyState
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    
    /// Whether the shelf has any content (items or power folders)
    private var hasContent: Bool {
        !state.shelfItems.isEmpty || !state.shelfPowerFolders.isEmpty
    }
    
    var body: some View {
        ZStack {
            if hasContent {
                itemsScrollView
            } else {
                emptyStateView
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard hasContent else { return }
            state.deselectAll()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .dropDestination(for: URL.self) { urls, _ in
            withAnimation(DroppyAnimation.transition) {
                state.addItems(from: urls)
            }
            return true
        }
    }
    
    // MARK: - Items Scroll View
    
    private var itemsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                // Power Folders first
                ForEach(state.shelfPowerFolders) { folder in
                    DroppedItemView(
                        item: folder,
                        isSelected: state.selectedItems.contains(folder.id),
                        onSelect: {
                            withAnimation(DroppyAnimation.state) {
                                state.toggleSelection(folder)
                            }
                        },
                        onRemove: {
                            withAnimation(DroppyAnimation.state) {
                                state.removeItem(folder)
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Regular items
                ForEach(state.shelfItems) { item in
                    DroppedItemView(
                        item: item,
                        isSelected: state.selectedItems.contains(item.id),
                        onSelect: {
                            withAnimation(DroppyAnimation.state) {
                                state.toggleSelection(item)
                            }
                        },
                        onRemove: {
                            withAnimation(DroppyAnimation.state) {
                                state.removeItem(item)
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .compositingGroup()
        }
        .animation(DroppyAnimation.transition, value: state.shelfItems.count)
        .animation(DroppyAnimation.transition, value: state.shelfPowerFolders.count)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: DroppyRadius.xxl + 2, style: .continuous)
                    .fill(Color(NSColor.labelColor).opacity(0.05))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("Shelf is empty")
                    .font(.system(size: 13, weight: .semibold))
                
                Text("Drop files or folders here")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ShelfView(state: DroppyState.shared)
        .frame(width: 400, height: 150)
}
