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
    
    // MARK: - Layout Constants (matching grid slot: 64x80)
    
    // Individual card size - compact to fit 64pt grid columns
    private let cardWidth: CGFloat = 48
    private let cardHeight: CGFloat = 48
    private let cardCornerRadius: CGFloat = 10
    private let thumbnailSize: CGFloat = 40
    
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
                // Right click = just show context menu, don't select/highlight
            },
            onDragStart: nil,
            onDragComplete: nil,
            selectionSignature: state.selectedStacks.hashValue
        ) {
            // Stack content - Clean glass design matching collapse button
            VStack(spacing: 6) {
                // 56x56 icon container with count badge
                ZStack {
                    // Glass background matching basket style
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // Subtle border (stronger when selected)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.3 : (isHovering ? 0.2 : 0.1)), lineWidth: isSelected ? 2 : 1)
                    
                    // Blue selection glow
                    if isSelected || isDropTargeted {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.15))
                        
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.blue, lineWidth: 2)
                    }
                    
                    // Expand icon
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    
                    // Count badge (top-right)
                    if stack.count > 1 {
                        Text("\(stack.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.blue)
                                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            )
                            .offset(x: 22, y: -22)
                    }
                }
                .frame(width: 56, height: 56)
                
                // "Expand" text label
                Text("Expand")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .frame(width: 60)
            }
            .padding(2)
            .frame(width: 64, height: 80)  // Match grid slot exactly
            // Drop target visual feedback - scale up and blue glow when files dragged over
            .scaleEffect(isDropTargeted ? 1.08 : 1.0)
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
        // NOTE: Frame sizing is set inside the VStack content (.frame(width: 64, height: 80))
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
        // NATIVE: No container background - just pure icons
        .overlay(
            // Default gradient border (when not selected and not drop targeted)
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
                .opacity((isSelected || isDropTargeted) ? 0 : 1)
        )
        .overlay(
            // Blue border for selection OR drop target
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(Color.blue, lineWidth: 2)
                .opacity((isSelected || isDropTargeted) ? 1 : 0)
        )
        .background(
            // Blue glow effect for selection OR drop target
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color.blue.opacity((isSelected || isDropTargeted) ? 0.15 : 0))
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
        .animation(DroppyAnimation.bouncy, value: isDropTargeted)
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
        // Load thumbnails for first 4 items using batch concurrent loading
        let itemsToLoad = Array(stack.items.prefix(4))
        
        // Use batch preloading with callback to update state without animation
        // This prevents QuickLook overload and eliminates animation lag
        await ThumbnailCache.shared.preloadThumbnails(
            for: itemsToLoad,
            size: CGSize(width: 120, height: 120)
        ) { [self] id, thumb in
            // Direct state update - NO animation to prevent lag with many items
            thumbnails[id] = thumb
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

/// Premium collapse button that looks identical to stacked cards
/// Features converging card animation on hover to indicate "collapse back to stack"
/// Clean collapse button matching regular basket item styling
/// Features glass background and proper icon sizing
struct StackCollapseButton: View {
    let itemCount: Int
    let onCollapse: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            HapticFeedback.pop()
            onCollapse()
        }) {
            VStack(spacing: 6) {
                // 56x56 icon container matching regular items
                ZStack {
                    // Glass background matching basket style
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // Subtle border
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isHovering ? 0.2 : 0.1), lineWidth: 1)
                    
                    // Collapse icon
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(width: 56, height: 56)
                
                // "Collapse" text label
                Text("Collapse")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .frame(width: 60)
            }
            .padding(2)
            .frame(width: 64, height: 80)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                HapticFeedback.pop()
            }
        }
    }
}

