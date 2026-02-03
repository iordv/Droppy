//
//  ReorderableGrid.swift
//  Droppy
//
//  iPhone-style drag-to-rearrange for grid layouts.
//  Items animate apart to make room during drag.
//

import SwiftUI

// MARK: - Reorderable ForEach

/// A ForEach that supports drag-to-rearrange with animated item displacement.
/// Items push apart during drag to show where the dragged item will land.
struct ReorderableForEach<Item: Identifiable, Content: View>: View {
    @Binding var items: [Item]
    let columns: Int
    let itemSize: CGSize
    let spacing: CGFloat
    let content: (Item) -> Content
    
    // Drag state
    @State private var draggingItem: Item.ID?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartPosition: CGPoint = .zero
    @State private var hasStartedDrag = false
    
    // Layout tracking
    @State private var itemPositions: [Item.ID: CGPoint] = [:]
    
    init(
        _ items: Binding<[Item]>,
        columns: Int,
        itemSize: CGSize,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self._items = items
        self.columns = columns
        self.itemSize = itemSize
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Layout items manually with computed positions
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .frame(width: itemSize.width, height: itemSize.height)
                    .offset(offsetFor(item: item, at: index))
                    .zIndex(item.id == draggingItem ? 100 : 0)
                    .scaleEffect(item.id == draggingItem ? 1.05 : 1.0)
                    .shadow(
                        color: item.id == draggingItem ? .black.opacity(0.3) : .clear,
                        radius: item.id == draggingItem ? 8 : 0
                    )
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                if draggingItem == nil {
                                    // Start drag
                                    draggingItem = item.id
                                    dragStartPosition = positionFor(index: index)
                                    hasStartedDrag = true
                                    HapticFeedback.impact(.medium)
                                }
                                
                                if draggingItem == item.id {
                                    dragOffset = value.translation
                                    
                                    // Calculate target index based on drag position
                                    let currentPos = CGPoint(
                                        x: dragStartPosition.x + dragOffset.width,
                                        y: dragStartPosition.y + dragOffset.height
                                    )
                                    let targetIndex = indexFor(position: currentPos)
                                    let currentIndex = items.firstIndex(where: { $0.id == item.id }) ?? index
                                    
                                    // Move item in array when crossing threshold
                                    if targetIndex != currentIndex && targetIndex >= 0 && targetIndex < items.count {
                                        withAnimation(DroppyAnimation.bouncy) {
                                            items.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: targetIndex > currentIndex ? targetIndex + 1 : targetIndex)
                                        }
                                        HapticFeedback.selection()
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(DroppyAnimation.bouncy) {
                                    draggingItem = nil
                                    dragOffset = .zero
                                    hasStartedDrag = false
                                }
                            }
                    )
                    .animation(item.id == draggingItem ? nil : DroppyAnimation.bouncy, value: items.map(\.id))
            }
        }
        .frame(
            width: CGFloat(columns) * itemSize.width + CGFloat(columns - 1) * spacing,
            height: ceil(CGFloat(items.count) / CGFloat(columns)) * itemSize.height + 
                   max(0, ceil(CGFloat(items.count) / CGFloat(columns)) - 1) * spacing,
            alignment: .topLeading
        )
    }
    
    // MARK: - Layout Helpers
    
    /// Calculate grid position for a given index
    private func positionFor(index: Int) -> CGPoint {
        let row = index / columns
        let col = index % columns
        return CGPoint(
            x: CGFloat(col) * (itemSize.width + spacing),
            y: CGFloat(row) * (itemSize.height + spacing)
        )
    }
    
    /// Calculate offset for an item (base position + drag offset if dragging)
    private func offsetFor(item: Item, at index: Int) -> CGSize {
        let basePosition = positionFor(index: index)
        
        if item.id == draggingItem {
            // Dragged item follows cursor
            return CGSize(
                width: basePosition.x + dragOffset.width,
                height: basePosition.y + dragOffset.height
            )
        } else {
            // Non-dragged items use their calculated position
            return CGSize(width: basePosition.x, height: basePosition.y)
        }
    }
    
    /// Calculate which index a position maps to (for determining drop target)
    private func indexFor(position: CGPoint) -> Int {
        let cellWidth = itemSize.width + spacing
        let cellHeight = itemSize.height + spacing
        
        // Calculate column and row (clamped to valid range)
        let col = max(0, min(columns - 1, Int((position.x + itemSize.width / 2) / cellWidth)))
        let row = max(0, Int((position.y + itemSize.height / 2) / cellHeight))
        
        let index = row * columns + col
        return max(0, min(items.count - 1, index))
    }
}

// MARK: - LazyVGrid Rearrangement Helper

/// View modifier that adds drag-to-rearrange to individual items in a LazyVGrid
struct ReorderableItemModifier<Item: Identifiable>: ViewModifier {
    let item: Item
    @Binding var items: [Item]
    @Binding var draggingItem: Item.ID?
    
    let columns: Int
    let itemSize: CGSize
    let spacing: CGFloat
    
    @State private var dragOffset: CGSize = .zero
    
    func body(content: Content) -> some View {
        content
            .zIndex(draggingItem == item.id ? 100 : 0)
            .scaleEffect(draggingItem == item.id ? 1.05 : 1.0)
            .shadow(
                color: draggingItem == item.id ? .black.opacity(0.3) : .clear,
                radius: draggingItem == item.id ? 8 : 0,
                y: 4
            )
            .offset(draggingItem == item.id ? dragOffset : .zero)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        if draggingItem == nil {
                            draggingItem = item.id
                            HapticFeedback.impact(.medium)
                        }
                        
                        if draggingItem == item.id {
                            dragOffset = value.translation
                            
                            // Calculate target position and reorder
                            let currentIndex = items.firstIndex(where: { $0.id == item.id }) ?? 0
                            let targetIndex = calculateTargetIndex(
                                from: currentIndex,
                                translation: value.translation
                            )
                            
                            if targetIndex != currentIndex {
                                withAnimation(DroppyAnimation.bouncy) {
                                    items.move(
                                        fromOffsets: IndexSet(integer: currentIndex),
                                        toOffset: targetIndex > currentIndex ? targetIndex + 1 : targetIndex
                                    )
                                }
                                HapticFeedback.selection()
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(DroppyAnimation.bouncy) {
                            draggingItem = nil
                            dragOffset = .zero
                        }
                    }
            )
            .animation(draggingItem == item.id ? nil : DroppyAnimation.bouncy, value: items.map(\.id))
    }
    
    private func calculateTargetIndex(from currentIndex: Int, translation: CGSize) -> Int {
        let cellWidth = itemSize.width + spacing
        let cellHeight = itemSize.height + spacing
        
        // Calculate how many cells we've moved
        let colOffset = Int(round(translation.width / cellWidth))
        let rowOffset = Int(round(translation.height / cellHeight))
        
        let currentRow = currentIndex / columns
        let currentCol = currentIndex % columns
        
        let targetCol = max(0, min(columns - 1, currentCol + colOffset))
        let targetRow = max(0, currentRow + rowOffset)
        
        let targetIndex = targetRow * columns + targetCol
        return max(0, min(items.count - 1, targetIndex))
    }
}

extension View {
    /// Make this item reorderable within a grid
    func reorderable<Item: Identifiable>(
        item: Item,
        in items: Binding<[Item]>,
        draggingItem: Binding<Item.ID?>,
        columns: Int,
        itemSize: CGSize,
        spacing: CGFloat = 12
    ) -> some View {
        modifier(ReorderableItemModifier(
            item: item,
            items: items,
            draggingItem: draggingItem,
            columns: columns,
            itemSize: itemSize,
            spacing: spacing
        ))
    }
}
