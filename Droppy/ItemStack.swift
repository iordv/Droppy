//
//  ItemStack.swift
//  Droppy
//
//  Created by Jordy Spruit on 22/01/2026.
//

import SwiftUI

// MARK: - Item Stack Model

/// Represents a stack of items dropped together
/// Stacks group files that were dropped in a single operation, displaying them
/// as a visual pile that can be expanded to show individual items.
struct ItemStack: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    var items: [DroppedItem]
    var isExpanded: Bool = false
    
    /// If true, always renders as a stack even with only 1 item (for tracked folders)
    var forceStackAppearance: Bool = false
    
    /// The "cover" item shown when collapsed (first item in the stack)
    var coverItem: DroppedItem? { items.first }
    
    /// Stack count for badge display
    var count: Int { items.count }
    
    /// Whether this is a single-item stack (renders as individual item, not pile)
    /// Tracked folder stacks always appear as stacks (forceStackAppearance)
    var isSingleItem: Bool { items.count == 1 && !forceStackAppearance }
    
    /// Whether the stack is empty
    var isEmpty: Bool { items.isEmpty }
    
    /// All item IDs in this stack (for selection operations)
    var itemIds: Set<UUID> { Set(items.map { $0.id }) }
    
    // MARK: - Initialization
    
    init(items: [DroppedItem]) {
        self.id = UUID()
        self.createdAt = Date()
        self.items = items
    }
    
    /// Creates a stack with a single item
    init(item: DroppedItem) {
        self.init(items: [item])
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ItemStack, rhs: ItemStack) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Mutations
    
    /// Removes an item from the stack by ID
    mutating func removeItem(withId itemId: UUID) {
        items.removeAll { $0.id == itemId }
    }
    
    /// Removes an item from the stack
    mutating func removeItem(_ item: DroppedItem) {
        removeItem(withId: item.id)
    }
    
    /// Adds an item to the stack
    mutating func addItem(_ item: DroppedItem) {
        items.append(item)
    }
    
    /// Cleans up all temporary files in the stack
    func cleanupTemporaryFiles() {
        for item in items {
            item.cleanupIfTemporary()
        }
    }
}

// MARK: - Stack Animations

extension ItemStack {
    /// Animation for stack expansion (items fanning out)
    static let expandAnimation: Animation = .spring(response: 0.45, dampingFraction: 0.8)
    
    /// Animation for stack collapse
    static let collapseAnimation: Animation = .spring(response: 0.3, dampingFraction: 0.95)
    
    /// Animation for hover peek (quick response)
    static let peekAnimation: Animation = .spring(response: 0.25, dampingFraction: 0.7)
    
    /// Stagger delay between items during expansion
    static func staggerDelay(for index: Int) -> Double {
        Double(index) * 0.035 // 35ms between each item
    }
}

// MARK: - Stack Transition

extension AnyTransition {
    /// Transition for stack appearing/disappearing (symmetric bounce in/out)
    static var stackDrop: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.6)
                .combined(with: .opacity)
                .animation(.spring(response: 0.4, dampingFraction: 0.8)),
            removal: .scale(scale: 0.6)
                .combined(with: .opacity)
                .combined(with: .offset(y: 10))
                .animation(.spring(response: 0.3, dampingFraction: 0.9))
        )
    }
    
    /// Transition for items expanding from stack
    static func stackExpand(index: Int) -> AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.7)
                .combined(with: .offset(y: -15))
                .combined(with: .opacity)
                .animation(ItemStack.expandAnimation.delay(ItemStack.staggerDelay(for: index))),
            removal: .scale(scale: 0.7)
                .combined(with: .offset(y: 10))
                .combined(with: .opacity)
                .animation(.spring(response: 0.25, dampingFraction: 0.9))
        )
    }
}
