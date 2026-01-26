//
//  StackedItemView.swift
//  Droppy
//
//  Created by Jordy Spruit on 22/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers

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
    
    /// Count label like "4 Files" or "3 Photos" for the expand button
    private var countLabel: String {
        let count = stack.count
        
        // Determine the type label based on file types
        let allImages = stack.items.allSatisfy { $0.fileType?.conforms(to: .image) == true }
        let allDocuments = stack.items.allSatisfy { 
            $0.fileType?.conforms(to: .pdf) == true || 
            $0.fileType?.conforms(to: .text) == true ||
            $0.fileType?.conforms(to: .presentation) == true ||
            $0.fileType?.conforms(to: .spreadsheet) == true
        }
        
        let typeLabel: String
        if allImages {
            typeLabel = count == 1 ? "Photo" : "Photos"
        } else if allDocuments {
            typeLabel = count == 1 ? "Doc" : "Docs"
        } else {
            typeLabel = count == 1 ? "File" : "Files"
        }
        
        return "\(count) \(typeLabel)"
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
        Button(action: {
            HapticFeedback.pop()
            withAnimation(ItemStack.expandAnimation) {
                onExpand()
            }
        }) {
            VStack(spacing: 6) {
                // 56x56 icon container matching Collapse button
                ZStack {
                    // Glass background matching basket style
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // Subtle border
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isHovering ? 0.2 : 0.1), lineWidth: 1)
                    
                    // Expand icon
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(width: 56, height: 56)
                
                // Count label like "4 Files" - matching Collapse text style
                Text(countLabel)
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
        // .contextMenu {
        //     contextMenuContent
        // }
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

