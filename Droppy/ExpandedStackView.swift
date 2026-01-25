//
//  ExpandedStackView.swift
//  Droppy
//
//  Created by Jordy Spruit on 22/01/2026.
//

import SwiftUI

// MARK: - Expanded Stack View

/// Shows an expanded stack with all items in a grid layout
/// Includes collapse button and allows interaction with individual items
struct ExpandedStackView: View {
    let stack: ItemStack
    @Bindable var state: DroppyState
    let onCollapse: () -> Void
    let onRemoveItem: (DroppedItem) -> Void
    
    @State private var isHeaderHovering = false
    
    private let gridSpacing: CGFloat = 8
    private let itemWidth: CGFloat = 70
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with item count and collapse button
            expandedHeader
            
            // Items grid with staggered appearance
            itemsGrid
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .clipped() // Clip content during transitions to prevent overflow
        .compositingGroup() // Unity Standard for smooth animation
    }
    
    // MARK: - Header
    
    private var expandedHeader: some View {
        HStack(spacing: 8) {
            // Item count
            Text("\(stack.count) items")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Select all button
            Button {
                withAnimation(DroppyAnimation.state) {
                    state.selectAllInStack(stack.id)
                }
            } label: {
                Text("Select All")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            // Collapse button
            Button {
                withAnimation(ItemStack.collapseAnimation) {
                    onCollapse()
                }
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 24))
        }
        .padding(.horizontal, 4)
        .onHover { isHeaderHovering = $0 }
    }
    
    // MARK: - Items Grid
    
    private var itemsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: itemWidth), spacing: gridSpacing)],
            spacing: gridSpacing
        ) {
            ForEach(Array(stack.items.enumerated()), id: \.element.id) { index, item in
                ExpandedStackItemView(
                    item: item,
                    isSelected: state.selectedItems.contains(item.id),
                    onSelect: {
                        withAnimation(DroppyAnimation.state) {
                            state.toggleSelection(item)
                        }
                    },
                    onRemove: {
                        withAnimation(DroppyAnimation.state) {
                            onRemoveItem(item)
                        }
                    }
                )
                .transition(.stackExpand(index: index))
            }
        }
        .animation(ItemStack.expandAnimation, value: stack.items.count)
    }
}

// MARK: - Expanded Stack Item View

/// Individual item view within an expanded stack
/// Simplified version of DroppedItemView for stack context
struct ExpandedStackItemView: View {
    let item: DroppedItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovering = false
    @State private var thumbnail: NSImage?
    
    private let itemSize: CGFloat = 70
    private let thumbnailSize: CGFloat = 48
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                    
                    Group {
                        if let thumb = thumbnail {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(nsImage: item.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    
                    // Selection checkmark
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                            .background(Circle().fill(.white).padding(2))
                            .offset(x: 20, y: -20)
                    }
                    
                    // Remove button on hover
                    if isHovering && !isSelected {
                        Button {
                            onRemove()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(DroppyDestructiveCircleButtonStyle(size: 14))
                        .offset(x: 20, y: -20)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: thumbnailSize + 12, height: thumbnailSize + 12)
                
                // Filename
                Text(item.name)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.primary)
                    .frame(width: itemSize - 4)
            }
        }
        .buttonStyle(DroppySelectableButtonStyle(isSelected: isSelected))
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(DroppyAnimation.hover, value: isHovering)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button {
                item.openFile()
            } label: {
                Label("Open", systemImage: "arrow.up.forward.square")
            }
            
            Button {
                item.revealInFinder()
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            
            Divider()
            
            Button {
                item.copyToClipboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "xmark")
            }
        }
        .task {
            // Load thumbnail asynchronously - NO animation to prevent lag with many items
            if let cached = ThumbnailCache.shared.cachedThumbnail(for: item) {
                thumbnail = cached
            } else if let asyncThumb = await ThumbnailCache.shared.loadThumbnailAsync(for: item) {
                // Direct state update without animation for performance
                thumbnail = asyncThumb
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ExpandedStackView(
            stack: ItemStack(items: [
                DroppedItem(url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Safari.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Notes.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Calendar.app"))
            ]),
            state: DroppyState.shared,
            onCollapse: {},
            onRemoveItem: { _ in }
        )
    }
    .padding(40)
    .background(Color.black.opacity(0.8))
}
