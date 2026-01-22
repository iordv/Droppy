//
//  ShelfView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

/// The main shelf view that displays dropped items and handles new drops
/// Now supports stacked item display for items dropped together
struct ShelfView: View {
    /// Reference to the app state
    @Bindable var state: DroppyState
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage("enableStackedView") private var enableStackedView = true
    
    /// Whether the shelf has any content (stacks or power folders)
    private var hasContent: Bool {
        !state.shelfStacks.isEmpty || !state.shelfPowerFolders.isEmpty
    }
    
    var body: some View {
        ZStack {
            if hasContent {
                stackedItemsScrollView
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .dropDestination(for: URL.self) { urls, _ in
            withAnimation(DroppyAnimation.transition) {
                state.addItems(from: urls)
            }
            return true
        }
    }
    
    // MARK: - Stacked Items Scroll View
    
    private var stackedItemsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                // Power Folders first (always distinct, never stacked)
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
                                state.shelfPowerFolders.removeAll { $0.id == folder.id }
                            }
                        }
                    )
                    .transition(.stackDrop)
                }
                
                // Stacks
                ForEach(state.shelfStacks) { stack in
                    stackView(for: stack)
                        .transition(.stackDrop)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .compositingGroup() // Unity Standard for jitter-free animation
        }
        .animation(DroppyAnimation.transition, value: state.shelfStacks.count)
        .animation(DroppyAnimation.transition, value: state.shelfPowerFolders.count)
    }
    
    // MARK: - Stack View
    
    @ViewBuilder
    private func stackView(for stack: ItemStack) -> some View {
        if stack.isExpanded {
            // Expanded stack showing all items
            ExpandedStackView(
                stack: stack,
                state: state,
                onCollapse: {
                    withAnimation(ItemStack.collapseAnimation) {
                        state.collapseStack(stack.id)
                    }
                },
                onRemoveItem: { item in
                    withAnimation(DroppyAnimation.state) {
                        state.removeItem(item)
                    }
                }
            )
        } else if stack.isSingleItem, let item = stack.coverItem {
            // Single items render as normal DroppedItemView
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
        } else {
            // Multi-item stacks show as collapsed pile
            StackedItemView(
                stack: stack,
                state: state,
                onExpand: {
                    withAnimation(ItemStack.expandAnimation) {
                        state.expandStack(stack.id)
                    }
                },
                onRemove: {
                    withAnimation(DroppyAnimation.state) {
                        state.removeStack(stack.id)
                    }
                }
            )
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
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

