//
//  StackedItemView.swift
//  Droppy
//
//  Created by Jordy Spruit on 22/01/2026.
//

import SwiftUI

// MARK: - Stacked Item View

/// Premium stacked card display matching clipboard's StackedCardView aesthetic
/// Features hover peek animation, haptic feedback, and buttery-smooth interactions
struct StackedItemView: View {
    let stack: ItemStack
    let state: DroppyState
    let onExpand: () -> Void
    let onRemove: () -> Void
    
    // MARK: - State
    
    @State private var isHovering = false
    @State private var peekProgress: CGFloat = 0  // 0 = collapsed, 1 = peeked
    @State private var thumbnails: [UUID: NSImage] = [:]
    @State private var isDropTargeted = false  // For drag-into-stack visual feedback
    
    /// Whether this stack is currently selected
    private var isSelected: Bool {
        state.selectedStacks.contains(stack.id)
    }
    
    // MARK: - Layout Constants (matching grid slot: 76x96)
    
    // Individual card size - matching DroppedItemView exactly (64x64 with 16pt radius)
    private let cardWidth: CGFloat = 64
    private let cardHeight: CGFloat = 64
    private let cardCornerRadius: CGFloat = 16
    private let thumbnailSize: CGFloat = 48
    
    // Clipboard-style stacking formula
    private func cardOffset(for index: Int) -> CGFloat {
        CGFloat(index) * 4  // Tighter stacking
    }
    
    private func cardRotation(for index: Int, total: Int) -> Double {
        Double(index - total / 2) * 2.0  // Subtle fan
    }
    
    private func cardScale(for index: Int) -> CGFloat {
        1.0 - CGFloat(index) * 0.03
    }
    
    // Hover peek: cards spread apart
    private func peekedOffset(for index: Int) -> CGFloat {
        cardOffset(for: index) + (CGFloat(index) * 3 * peekProgress)
    }
    
    private func peekedRotation(for index: Int, total: Int) -> Double {
        cardRotation(for: index, total: total) + (Double(index - total / 2) * 1.0 * Double(peekProgress))
    }
    
    // MARK: - Body
    
    var body: some View {
        DraggableArea(
            items: {
                // If this stack is selected, drag all URLs from all selected stacks
                if state.selectedStacks.contains(stack.id) {
                    var urls: [NSURL] = []
                    for selectedStackId in state.selectedStacks {
                        if let selectedStack = state.shelfStacks.first(where: { $0.id == selectedStackId }) {
                            urls.append(contentsOf: selectedStack.items.map { $0.url as NSURL })
                        }
                    }
                    return urls
                } else {
                    // Not selected - drag all items from this stack only
                    return stack.items.map { $0.url as NSURL }
                }
            },
            onTap: { modifiers in
                HapticFeedback.pop()
                
                if modifiers.contains(.command) {
                    // Cmd+click = toggle selection
                    withAnimation(DroppyAnimation.bouncy) {
                        state.toggleStackSelection(stack)
                    }
                } else if modifiers.contains(.shift) {
                    // Shift+click = add to selection
                    withAnimation(DroppyAnimation.bouncy) {
                        if !state.selectedStacks.contains(stack.id) {
                            state.selectedStacks.insert(stack.id)
                            state.selectedItems.formUnion(stack.itemIds)
                        }
                    }
                } else {
                    // Normal click = select this stack only (deselect others) then expand
                    state.deselectAll()
                    withAnimation(ItemStack.expandAnimation) {
                        onExpand()
                    }
                }
            },
            onDoubleClick: {
                // Double click = expand stack
                HapticFeedback.pop()
                withAnimation(ItemStack.expandAnimation) {
                    onExpand()
                }
            },
            onRightClick: {
                // Right click = select if not selected, show context menu
                if !state.selectedStacks.contains(stack.id) {
                    state.deselectAll()
                    state.selectedStacks.insert(stack.id)
                    state.selectedItems.formUnion(stack.itemIds)
                }
            },
            onDragStart: nil,
            onDragComplete: nil,
            selectionSignature: state.selectedStacks.hashValue
        ) {
            // Stack content with drop destination
            ZStack {
                // Stacked cards (up to 3 visible, rendered back to front)
                let visibleItems = Array(stack.items.prefix(3))
                let totalCount = visibleItems.count
                
                ForEach(Array(visibleItems.enumerated().reversed()), id: \.element.id) { index, item in
                    stackedCard(for: item, at: index, total: totalCount)
                }
                
                // Count badge (only show for 2+ items)
                if stack.count > 1 {
                    countBadge
                }
            }
            .frame(width: 76, height: 96)  // Match grid slot exactly
            // Drop target visual feedback - scale up and glow when files dragged over
            .scaleEffect(isDropTargeted ? 1.08 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(Color.green, lineWidth: 3)
                    .opacity(isDropTargeted ? 1 : 0)
                    .padding(6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(Color.green.opacity(isDropTargeted ? 0.15 : 0))
                    .padding(6)
            )
            .animation(DroppyAnimation.bouncy, value: isDropTargeted)
            // Drop destination - drag files INTO this stack
            .dropDestination(for: URL.self) { urls, location in
                // Prevent dropping this stack onto itself
                if state.selectedStacks.contains(stack.id) {
                    return false
                }
                
                // Filter out URLs that are already in this stack
                let existingURLs = Set(stack.items.map { $0.url })
                let newURLs = urls.filter { !existingURLs.contains($0) }
                
                guard !newURLs.isEmpty else { return false }
                
                // Add each new URL to this stack
                withAnimation(DroppyAnimation.bouncy) {
                    for url in newURLs {
                        let newItem = DroppedItem(url: url)
                        state.addItemToStack(newItem, stackId: stack.id)
                    }
                }
                
                // Success haptic
                HapticFeedback.drop()
                return true
            } isTargeted: { targeted in
                withAnimation(DroppyAnimation.bouncy) {
                    isDropTargeted = targeted
                }
                // Haptic when drag enters
                if targeted {
                    HapticFeedback.pop()
                }
            }
        }
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .animation(ItemStack.peekAnimation, value: isHovering)
        .animation(ItemStack.peekAnimation, value: peekProgress)
        .animation(DroppyAnimation.bouncy, value: isSelected)
        .onHover { hovering in
            guard !state.isInteractionBlocked else { return }
            
            // Direct state updates - animations handled by view-level modifiers above
            isHovering = hovering
            
            if hovering {
                HapticFeedback.pop()
                peekProgress = 1.0
            } else {
                peekProgress = 0.0
            }
        }
        .contextMenu {
            contextMenuContent
        }
        .task {
            await loadThumbnails()
        }
    }
    
    // MARK: - Stacked Card
    
    private func stackedCard(for item: DroppedItem, at index: Int, total: Int) -> some View {
        // Just thumbnail centered in card (no filename for stacked view)
        ZStack {
            if let thumb = thumbnails[item.id] {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: thumbnailSize - 4, height: thumbnailSize - 4)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            // Default gradient border (when not selected)
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
                .opacity(isSelected ? 0 : 1)
        )
        .overlay(
            // Selection border (when selected)
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(Color.blue, lineWidth: 2)
                .opacity(isSelected ? 1 : 0)
        )
        .background(
            // Selection glow effect
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color.blue.opacity(isSelected ? 0.15 : 0))
        )
        .shadow(
            color: .black.opacity(0.2 - Double(index) * 0.03),
            radius: 8 - CGFloat(index) * 1.5,
            x: 0,
            y: 4 + CGFloat(index)
        )
        .scaleEffect(cardScale(for: index))
        .offset(x: peekedOffset(for: index) * 0.4, y: -peekedOffset(for: index))
        .rotationEffect(.degrees(peekedRotation(for: index, total: total)))
        .zIndex(Double(total - index))
        .animation(DroppyAnimation.bouncy, value: isSelected)
    }
    
    // MARK: - Count Badge
    
    private var countBadge: some View {
        Text("\(stack.count)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.blue)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            )
            .offset(x: 28, y: -30)
            .zIndex(100)
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            HapticFeedback.pop()
            withAnimation(ItemStack.expandAnimation) {
                onExpand()
            }
        } label: {
            Label("Expand Stack", systemImage: "arrow.up.left.and.arrow.down.right")
        }
        
        Divider()
        
        Button {
            state.selectAllInStack(stack.id)
        } label: {
            Label("Select All (\(stack.count))", systemImage: "checkmark.circle")
        }
        
        Divider()
        
        Button(role: .destructive) {
            withAnimation(DroppyAnimation.state) {
                onRemove()
            }
        } label: {
            Label("Remove Stack", systemImage: "xmark")
        }
    }
    
    // MARK: - Thumbnail Loading
    
    private func loadThumbnails() async {
        // Load thumbnails for first 4 items asynchronously
        let itemsToLoad = Array(stack.items.prefix(4))
        
        for item in itemsToLoad {
            if let cached = ThumbnailCache.shared.cachedThumbnail(for: item) {
                await MainActor.run {
                    thumbnails[item.id] = cached
                }
            } else if let asyncThumb = await item.generateThumbnail() {
                await MainActor.run {
                    withAnimation(DroppyAnimation.hover) {
                        thumbnails[item.id] = asyncThumb
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 30) {
        // 2-item stack
        StackedItemView(
            stack: ItemStack(items: [
                DroppedItem(url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Safari.app"))
            ]),
            state: DroppyState.shared,
            onExpand: {},
            onRemove: {}
        )
        
        // 4-item stack
        StackedItemView(
            stack: ItemStack(items: [
                DroppedItem(url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Safari.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Notes.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Calendar.app"))
            ]),
            state: DroppyState.shared,
            onExpand: {},
            onRemove: {}
        )
        
        // Many items
        StackedItemView(
            stack: ItemStack(items: [
                DroppedItem(url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Safari.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Notes.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Calendar.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Messages.app")),
                DroppedItem(url: URL(fileURLWithPath: "/Applications/Mail.app"))
            ]),
            state: DroppyState.shared,
            onExpand: {},
            onRemove: {}
        )
    }
    .padding(50)
    .background(Color.black.opacity(0.85))
}

// MARK: - Stack Collapse Button

/// Premium collapse button with visual stacking effect
/// Shows mini cards converging to indicate "collapse back to stack"
struct StackCollapseButton: View {
    let itemCount: Int
    let onCollapse: () -> Void
    
    @State private var isHovering = false
    
    // Card dimensions (smaller to show multiple)
    private let miniCardSize: CGFloat = 28
    private let cardCornerRadius: CGFloat = 8
    
    var body: some View {
        Button(action: {
            HapticFeedback.pop()
            onCollapse()
        }) {
            VStack(spacing: 6) {
                // Card container matching NotchItemContent exactly
                ZStack {
                    // Stacked cards visual - shows cards converging
                    // Background card (furthest back)
                    miniCard(offset: isHovering ? 0 : 6, rotation: isHovering ? 0 : -6, opacity: 0.4)
                    
                    // Middle card
                    miniCard(offset: isHovering ? 0 : 3, rotation: isHovering ? 0 : 3, opacity: 0.6)
                    
                    // Front card with icon
                    ZStack {
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(width: miniCardSize, height: miniCardSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(isHovering ? 0.25 : 0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                
                // Label matching NotchItemContent filename styling
                Text("Collapse")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(isHovering ? 0.85 : 0.5))
                    .lineLimit(1)
            }
            .frame(width: 76, height: 96)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .animation(ItemStack.peekAnimation, value: isHovering)
        .onHover { hovering in
            if hovering {
                HapticFeedback.pop()
            }
            isHovering = hovering
        }
    }
    
    // Mini card for stacking visual
    private func miniCard(offset: CGFloat, rotation: Double, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(.ultraThinMaterial.opacity(opacity))
            .frame(width: miniCardSize, height: miniCardSize)
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .offset(x: offset * 0.5, y: -offset)
            .rotationEffect(.degrees(rotation))
            .animation(DroppyAnimation.hover, value: isHovering)
    }
}
