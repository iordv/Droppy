//
//  ToDoManager.swift
//  Droppy
//
//  Manages to-do items, persistence, and logic
//

import SwiftUI
import UniformTypeIdentifiers



enum ToDoPriority: String, Codable, CaseIterable, Identifiable {
    case high
    case medium
    case normal
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .high: return Color(nsColor: NSColor(calibratedRed: 1.0, green: 0.41, blue: 0.38, alpha: 1.0)) // Pastel Red
        case .medium: return Color(nsColor: NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.2, alpha: 1.0)) // Pastel Orange/Gold
        case .normal: return Color(nsColor: NSColor(calibratedWhite: 0.6, alpha: 1.0)) // Soft Gray
        }
    }
    
    var icon: String {
        switch self {
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark.circle"
        case .normal: return "circle"
        }
    }
}

struct ToDoItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var priority: ToDoPriority
    var createdAt: Date
    var completedAt: Date?
    var isCompleted: Bool
    var sortOrder: Int? // Optional for backward compatibility
    
    static func == (lhs: ToDoItem, rhs: ToDoItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.isCompleted == rhs.isCompleted &&
        lhs.title == rhs.title &&
        lhs.priority == rhs.priority &&
        lhs.sortOrder == rhs.sortOrder
    }
}

@Observable
final class ToDoManager {
    static let shared = ToDoManager()
    
    // MARK: - State
    
    var items: [ToDoItem] = []
    var isVisible: Bool = false
    
    // State for the input field
    var newItemText: String = ""
    var newItemPriority: ToDoPriority = .normal
    


    
    // Undo buffer
    var lastDeletedItem: ToDoItem?
    var showUndoToast: Bool = false
    var undoTimer: Timer?
    
    private let fileName = "todo_items.json"
    private var cleanupTimer: Timer?
    
    // MARK: - Lifecycle
    
    private init() {
        loadItems()
        setupCleanupTimer()
        
        // Initial cleanup on launch
        cleanupOldItems()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Actions
    
    func toggleVisibility() {
        withAnimation(.smooth) {
            isVisible.toggle()
        }
        if isVisible {
            // Run cleanup when opening
            cleanupOldItems()
        }
    }
    
    func hide() {
        withAnimation(.smooth) {
            isVisible = false
        }
    }
    
    func addItem(title: String, priority: ToDoPriority) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newItem = ToDoItem(
            title: trimmed,
            priority: priority,
            createdAt: Date(),
            completedAt: nil,
            isCompleted: false
        )
        
        // Add to top (lowest sort order)
        let minSortOrder = items.compactMap { $0.sortOrder }.min() ?? 0
        var newItemWithOrder = newItem
        newItemWithOrder.sortOrder = minSortOrder - 1
        
        withAnimation(.smooth) {
            items.insert(newItemWithOrder, at: 0)
        }
        
        saveItems()
        
        // Reset input
        newItemText = ""
        newItemPriority = .normal
    }
    
    func toggleCompletion(for item: ToDoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        withAnimation(.smooth) {
            items[index].isCompleted.toggle()
            if items[index].isCompleted {
                items[index].completedAt = Date()
            } else {
                items[index].completedAt = nil
            }
        }
        
        saveItems()
    }
    
    func updatePriority(for item: ToDoItem, to priority: ToDoPriority) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation {
            items[index].priority = priority
        }
        saveItems()
    }
    
    func removeItem(_ item: ToDoItem) {
        // Store for undo
        lastDeletedItem = item
        
        withAnimation(.smooth) {
            items.removeAll { $0.id == item.id }
            showUndoToast = true
        }
        saveItems()
        
        // Auto-dismiss toast
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            withAnimation {
                self?.showUndoToast = false
                self?.lastDeletedItem = nil
            }
        }
    }
    

    
    func restoreLastDeletedItem() {
        guard let item = lastDeletedItem else { return }
        
        withAnimation(.smooth) {
            // Insert back at original position if possible, or top
            // Since we sort anyway, appending or inserting at 0 is fine
            // But let's try to be smart? No, sort logic handles it.
            items.append(item)
            showUndoToast = false
            lastDeletedItem = nil
        }
        
        undoTimer?.invalidate()
        saveItems()
    }
    
    // MARK: - Persistence
    
    private var dataFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Droppy")
            .appendingPathComponent(fileName)
    }
    
    private func saveItems() {
        guard let url = dataFileURL else { return }
        
        do {
            // Ensure directory exists
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            let data = try JSONEncoder().encode(items)
            try data.write(to: url)
        } catch {
            print("ToDoManager: Failed to save items: \(error)")
        }
    }
    
    // Public exposure for DropDelegate to commit changes
    func commitCurrentState() {
        saveItems()
    }
    
    private func loadItems() {
        guard let url = dataFileURL else { return }
        
        do {
            let data = try Data(contentsOf: url)
            items = try JSONDecoder().decode([ToDoItem].self, from: data)
        } catch {
            // File might not exist yet, that's fine
            print("ToDoManager: No saved items loaded: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    private func setupCleanupTimer() {
        // Run every 10 minutes
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.cleanupOldItems()
        }
    }
    
    private var autoCleanupHours: Int {
        UserDefaults.standard.preference(AppPreferenceKey.todoAutoCleanupHours, default: PreferenceDefault.todoAutoCleanupHours)
    }

    private func cleanupOldItems() {
        let now = Date()
        let cleanupInterval: TimeInterval = TimeInterval(autoCleanupHours * 60 * 60)

        let originalCount = items.count

        withAnimation {
            items.removeAll { item in
                guard item.isCompleted, let completedAt = item.completedAt else { return false }
                return now.timeIntervalSince(completedAt) > cleanupInterval
            }
        }
        
        if items.count != originalCount {
            saveItems()
            print("ToDoManager: Cleaned up \(originalCount - items.count) old items")
        }
    }
    
    // MARK: - Computed Properties for View
    
    var sortedItems: [ToDoItem] {
        items.sorted {
            // Always put completed items at the bottom
            if $0.isCompleted != $1.isCompleted {
                return !$0.isCompleted
            }
            
            // If both are completed, sort by completion date (newest first)
            if $0.isCompleted {
                return ($0.completedAt ?? Date()) > ($1.completedAt ?? Date())
            }
            
            // If both are incomplete, check for manual sort order
            if let order1 = $0.sortOrder, let order2 = $1.sortOrder {
                if order1 != order2 {
                    return order1 < order2
                }
            }
            
            // Fallback to Priority (High -> Medium -> Normal)
            if $0.priority != $1.priority {
                return rank($0.priority) > rank($1.priority)
            }
            
            // Fallback to Date
            return $0.createdAt > $1.createdAt
        }
    }
    
    private func rank(_ p: ToDoPriority) -> Int {
        switch p {
        case .high: return 3
        case .medium: return 2
        case .normal: return 1
        }
    }
}
