//
//  ToDoManager.swift
//  Droppy
//
//  Manages to-do items, persistence, and logic
//

import SwiftUI
import UniformTypeIdentifiers
import EventKit
import AppKit



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

enum ToDoExternalSource: String, Codable {
    case calendar
    case reminders
}

struct ToDoItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var priority: ToDoPriority
    var dueDate: Date?
    var externalSource: ToDoExternalSource?
    var externalIdentifier: String?
    var externalListIdentifier: String?
    var externalListTitle: String?
    var externalListColorHex: String?
    var createdAt: Date
    var completedAt: Date?
    var isCompleted: Bool
    
    static func == (lhs: ToDoItem, rhs: ToDoItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.isCompleted == rhs.isCompleted &&
        lhs.title == rhs.title &&
        lhs.priority == rhs.priority &&
        lhs.dueDate == rhs.dueDate &&
        lhs.externalSource == rhs.externalSource &&
        lhs.externalIdentifier == rhs.externalIdentifier &&
        lhs.externalListIdentifier == rhs.externalListIdentifier &&
        lhs.externalListTitle == rhs.externalListTitle &&
        lhs.externalListColorHex == rhs.externalListColorHex
    }
}

struct ToDoReminderListOption: Identifiable, Equatable {
    let id: String
    let title: String
    let colorHex: String?
}

@Observable
final class ToDoManager {
    static let shared = ToDoManager()
    
    // MARK: - State
    
    var items: [ToDoItem] = []
    var isVisible: Bool = false
    var isShelfListExpanded: Bool = false
    var isInteractingWithPopover: Bool = false
    var isEditingText: Bool = false
    var availableReminderLists: [ToDoReminderListOption] = []
    var selectedReminderListIDs: Set<String> = []
    
    // State for the input field
    var newItemText: String = ""
    var newItemPriority: ToDoPriority = .normal
    var newItemDueDate: Date?
    var newItemReminderListID: String?

    var isUserEditingTodo: Bool {
        isVisible || isShelfListExpanded || isEditingText || isInteractingWithPopover
    }
    


    
    // Undo buffer (supports multiple rapid deletes)
    var deletedItems: [ToDoItem] = []
    var showUndoToast: Bool = false
    var undoTimer: Timer?
    
    // Cleanup feedback
    var showCleanupToast: Bool = false
    var cleanupCount: Int = 0
    var cleanupToastTimer: Timer?
    
    private let fileName = "todo_items.json"
    private let eventStore = EKEventStore()
    private var cleanupTimer: Timer?
    private var externalSyncTimer: Timer?
    private var eventStoreObserver: NSObjectProtocol?
    private var eventStoreSyncDebounceWorkItem: DispatchWorkItem?
    private let remindersSelectedListsKey = AppPreferenceKey.todoSyncRemindersListIDs
    
    // MARK: - Lifecycle
    
    private init() {
        loadItems()
        loadSelectedReminderListIDs()
        setupCleanupTimer()
        setupExternalSyncTimer()
        observeEventStoreChanges()
        
        // Initial cleanup on launch
        cleanupOldItems()
        syncExternalSourcesNow()
    }
    
    deinit {
        cleanupTimer?.invalidate()
        externalSyncTimer?.invalidate()
        if let eventStoreObserver {
            NotificationCenter.default.removeObserver(eventStoreObserver)
        }
        eventStoreSyncDebounceWorkItem?.cancel()
        undoTimer?.invalidate()
        cleanupToastTimer?.invalidate()
    }
    
    // MARK: - Actions
    
    func toggleVisibility() {
        withAnimation(.smooth) {
            isVisible.toggle()
        }
        if isVisible {
            // Run cleanup when opening
            cleanupOldItems()
            syncExternalSourcesNow()
        } else {
            isShelfListExpanded = false
        }
    }
    
    func hide() {
        withAnimation(.smooth) {
            isVisible = false
        }
        isShelfListExpanded = false
    }
    
    func addItem(title: String, priority: ToDoPriority, dueDate: Date? = nil, reminderListID: String? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let selectedList = reminderListID.flatMap { reminderListOption(withID: $0) }

        let newItem = ToDoItem(
            title: trimmed,
            priority: priority,
            dueDate: dueDate,
            externalSource: nil,
            externalIdentifier: nil,
            externalListIdentifier: selectedList?.id,
            externalListTitle: selectedList?.title,
            externalListColorHex: selectedList?.colorHex,
            createdAt: Date(),
            completedAt: nil,
            isCompleted: false
        )
        
        withAnimation(.smooth) {
            items.insert(newItem, at: 0)
        }
        
        saveItems()

        if isRemindersSyncEnabled {
            syncNewItemToReminders(itemID: newItem.id, preferredListID: reminderListID)
        }
        
        // Reset input
        newItemText = ""
        newItemPriority = .normal
        newItemDueDate = nil
        newItemReminderListID = nil
    }

    // MARK: - External Sync (Reminders)

    var isRemindersSyncEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.todoSyncRemindersEnabled,
            default: PreferenceDefault.todoSyncRemindersEnabled
        )
    }

    var isCalendarSyncEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.todoSyncCalendarEnabled,
            default: PreferenceDefault.todoSyncCalendarEnabled
        )
    }

    func setRemindersSyncEnabled(_ enabled: Bool) {
        Task {
            if enabled {
                let granted = await requestRemindersAccess()
                await MainActor.run {
                    UserDefaults.standard.set(granted, forKey: AppPreferenceKey.todoSyncRemindersEnabled)
                    if granted {
                        self.refreshReminderListsNow()
                        self.syncExternalSourcesNow()
                    } else {
                        self.availableReminderLists = []
                        self.removeExternalItems(for: .reminders)
                        self.openRemindersPrivacySettings()
                    }
                }
            } else {
                await MainActor.run {
                    UserDefaults.standard.set(false, forKey: AppPreferenceKey.todoSyncRemindersEnabled)
                    self.availableReminderLists = []
                    self.removeExternalItems(for: .reminders)
                }
            }
        }
    }

    func setCalendarSyncEnabled(_ enabled: Bool) {
        Task { @MainActor in
            if enabled {
                let granted = await requestCalendarAccess()
                UserDefaults.standard.set(granted, forKey: AppPreferenceKey.todoSyncCalendarEnabled)
                if granted {
                    self.syncExternalSourcesNow()
                } else {
                    self.removeExternalItems(for: .calendar)
                    openCalendarPrivacySettings()
                }
            } else {
                UserDefaults.standard.set(false, forKey: AppPreferenceKey.todoSyncCalendarEnabled)
                self.removeExternalItems(for: .calendar)
            }
        }
    }

    func refreshReminderListsNow() {
        Task {
            await refreshReminderLists()
        }
    }

    func isReminderListSelected(_ listID: String) -> Bool {
        selectedReminderListIDs.contains(listID)
    }

    func reminderLists(matching query: String) -> [ToDoReminderListOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return availableReminderLists
        }

        let normalizedQuery = Self.normalizeSearchToken(trimmed)
        let prefixMatches = availableReminderLists.filter {
            Self.normalizeSearchToken($0.title).hasPrefix(normalizedQuery)
        }
        if !prefixMatches.isEmpty {
            return prefixMatches
        }
        return availableReminderLists.filter {
            Self.normalizeSearchToken($0.title).contains(normalizedQuery)
        }
    }

    func resolveReminderList(matching query: String) -> ToDoReminderListOption? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedQuery = Self.normalizeSearchToken(trimmed)
        if let exact = availableReminderLists.first(where: {
            Self.normalizeSearchToken($0.title) == normalizedQuery
        }) {
            return exact
        }
        if let prefix = availableReminderLists.first(where: {
            Self.normalizeSearchToken($0.title).hasPrefix(normalizedQuery)
        }) {
            return prefix
        }
        return availableReminderLists.first(where: {
            Self.normalizeSearchToken($0.title).contains(normalizedQuery)
        })
    }

    func toggleReminderListSelection(_ listID: String) {
        if selectedReminderListIDs.contains(listID) {
            selectedReminderListIDs.remove(listID)
        } else {
            selectedReminderListIDs.insert(listID)
        }
        saveSelectedReminderListIDs()
        syncExternalSourcesNow()
    }

    func selectAllReminderLists() {
        selectedReminderListIDs = Set(availableReminderLists.map(\.id))
        saveSelectedReminderListIDs()
        syncExternalSourcesNow()
    }

    func clearReminderListsSelection() {
        selectedReminderListIDs.removeAll()
        saveSelectedReminderListIDs()
        syncExternalSourcesNow()
    }

    func syncExternalSourcesNow() {
        Task {
            await syncExternalSources()
        }
    }

    private func setupExternalSyncTimer() {
        // Refresh external sources periodically while app runs.
        externalSyncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.syncExternalSourcesNow()
        }
    }

    private func observeEventStoreChanges() {
        eventStoreObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            guard self.isRemindersSyncEnabled || self.isCalendarSyncEnabled else { return }
            self.eventStoreSyncDebounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.syncExternalSourcesNow()
            }
            self.eventStoreSyncDebounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
        }
    }

    private func syncExternalSources() async {
        var reminderPayloads: [ExternalTaskPayload] = []
        var calendarPayloads: [ExternalTaskPayload] = []

        if isRemindersSyncEnabled {
            let granted = await requestRemindersAccess()
            if granted {
                await refreshReminderLists()
                reminderPayloads = await fetchReminders()
            } else {
                await MainActor.run {
                    UserDefaults.standard.set(false, forKey: AppPreferenceKey.todoSyncRemindersEnabled)
                    self.availableReminderLists = []
                }
            }
        }

        if isCalendarSyncEnabled {
            let granted = await requestCalendarAccess()
            if granted {
                calendarPayloads = await fetchCalendarEvents()
            } else {
                await MainActor.run {
                    UserDefaults.standard.set(false, forKey: AppPreferenceKey.todoSyncCalendarEnabled)
                }
            }
        }

        await MainActor.run {
            applyExternalSync(reminderPayloads: reminderPayloads, calendarPayloads: calendarPayloads)
        }
    }

    private func requestRemindersAccess() async -> Bool {
        await MainActor.run {
            // Ensure the app is frontmost so macOS can present the privacy prompt.
            NSApp.activate(ignoringOtherApps: true)
        }

        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess:
                return true
            case .writeOnly, .denied, .restricted:
                return false
            case .notDetermined:
                break
            @unknown default:
                return false
            }
        } else {
            switch status {
            case .authorized:
                return true
            case .fullAccess:
                return true
            case .writeOnly:
                return false
            case .denied, .restricted:
                return false
            case .notDetermined:
                break
            @unknown default:
                return false
            }
        }

        do {
            return try await eventStore.requestFullAccessToReminders()
        } catch {
            return false
        }
    }

    @MainActor
    private func openRemindersPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    private func requestCalendarAccess() async -> Bool {
        // Ensure the app is active so macOS can present the privacy prompt.
        NSApp.activate(ignoringOtherApps: true)

        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess:
            return true
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .writeOnly, .notDetermined:
            do {
                if try await eventStore.requestFullAccessToEvents() {
                    return true
                }
            } catch {
                return EKEventStore.authorizationStatus(for: .event) == .fullAccess
            }
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        @unknown default:
            return false
        }
    }

    @MainActor
    private func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func refreshReminderLists() async {
        guard isRemindersSyncEnabled else {
            await MainActor.run {
                availableReminderLists = []
            }
            return
        }

        let status = EKEventStore.authorizationStatus(for: .reminder)
        let hasAccess: Bool
        if #available(macOS 14.0, *) {
            hasAccess = status == .fullAccess
        } else {
            hasAccess = status == .authorized
        }
        guard hasAccess else {
            await MainActor.run {
                availableReminderLists = []
            }
            return
        }

        let options = eventStore
            .calendars(for: .reminder)
            .map { calendar in
                ToDoReminderListOption(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    colorHex: Self.hexColor(from: calendar.cgColor)
                )
            }
            .sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }

        await MainActor.run {
            availableReminderLists = options
            let availableIDs = Set(options.map(\.id))
            let hasStoredSelection = UserDefaults.standard.object(forKey: remindersSelectedListsKey) != nil
            if !hasStoredSelection {
                selectedReminderListIDs = availableIDs
                saveSelectedReminderListIDs()
            } else {
                let prunedSelection = selectedReminderListIDs.intersection(availableIDs)
                if prunedSelection != selectedReminderListIDs {
                    selectedReminderListIDs = prunedSelection
                    saveSelectedReminderListIDs()
                }
            }
        }
    }

    private func fetchReminders() async -> [ExternalTaskPayload] {
        let selectedIDs = selectedReminderListIDs
        guard !selectedIDs.isEmpty else { return [] }
        let selectedCalendars = eventStore
            .calendars(for: .reminder)
            .filter { selectedIDs.contains($0.calendarIdentifier) }
        guard !selectedCalendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForReminders(in: selectedCalendars)

        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        return reminders.compactMap { reminder in
            guard !reminder.isCompleted else { return nil }
            let title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return ExternalTaskPayload(
                source: .reminders,
                identifier: reminder.calendarItemIdentifier,
                title: title,
                dueDate: reminder.dueDateComponents?.date,
                isCompleted: reminder.isCompleted,
                listIdentifier: reminder.calendar.calendarIdentifier,
                listTitle: reminder.calendar.title,
                listColorHex: Self.hexColor(from: reminder.calendar.cgColor)
            )
        }
    }

    private func fetchCalendarEvents() async -> [ExternalTaskPayload] {
        let calendars = eventStore.calendars(for: .event)
        guard !calendars.isEmpty else { return [] }

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(30 * 24 * 60 * 60)
        let predicate = eventStore.predicateForEvents(withStart: now, end: end, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        var seenIDs = Set<String>()
        return events.compactMap { event in
            guard event.endDate >= now else { return nil }
            if event.status == .canceled { return nil }

            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }

            let identifier = Self.calendarOccurrenceIdentifier(for: event)
            guard seenIDs.insert(identifier).inserted else { return nil }

            return ExternalTaskPayload(
                source: .calendar,
                identifier: identifier,
                title: title,
                dueDate: event.startDate,
                isCompleted: false,
                listIdentifier: event.calendar.calendarIdentifier,
                listTitle: event.calendar.title,
                listColorHex: Self.hexColor(from: event.calendar.cgColor)
            )
        }
    }

    private func applyExternalSync(reminderPayloads: [ExternalTaskPayload], calendarPayloads: [ExternalTaskPayload]) {
        let remindersEnabled = isRemindersSyncEnabled
        let calendarEnabled = isCalendarSyncEnabled

        var payloadByKey: [String: ExternalTaskPayload] = [:]
        for payload in (reminderPayloads + calendarPayloads) {
            payloadByKey["\(payload.source.rawValue)::\(payload.identifier)"] = payload
        }

        for index in items.indices {
            guard let source = items[index].externalSource, let externalID = items[index].externalIdentifier else { continue }
            let keepSource = (source == .reminders && remindersEnabled) || (source == .calendar && calendarEnabled)
            guard keepSource else { continue }

            let key = "\(source.rawValue)::\(externalID)"
            if let payload = payloadByKey.removeValue(forKey: key) {
                items[index].title = payload.title
                items[index].dueDate = payload.dueDate
                items[index].isCompleted = payload.isCompleted
                items[index].completedAt = payload.isCompleted ? (items[index].completedAt ?? Date()) : nil
                items[index].externalListIdentifier = payload.listIdentifier
                items[index].externalListTitle = payload.listTitle
                items[index].externalListColorHex = payload.listColorHex
            }
        }

        for payload in payloadByKey.values {
            let item = ToDoItem(
                title: payload.title,
                priority: .normal,
                dueDate: payload.dueDate,
                externalSource: payload.source,
                externalIdentifier: payload.identifier,
                externalListIdentifier: payload.listIdentifier,
                externalListTitle: payload.listTitle,
                externalListColorHex: payload.listColorHex,
                createdAt: Date(),
                completedAt: payload.isCompleted ? Date() : nil,
                isCompleted: payload.isCompleted
            )
            items.insert(item, at: 0)
        }

        // Remove stale external items from enabled sources when they no longer exist upstream.
        let activeKeys = Set((reminderPayloads + calendarPayloads).map { "\($0.source.rawValue)::\($0.identifier)" })
        items.removeAll { item in
            guard let source = item.externalSource, let externalID = item.externalIdentifier else { return false }
            let sourceEnabled = (source == .reminders && remindersEnabled) || (source == .calendar && calendarEnabled)
            guard sourceEnabled else { return false }
            let key = "\(source.rawValue)::\(externalID)"
            return !activeKeys.contains(key)
        }

        if !remindersEnabled {
            removeExternalItems(for: .reminders)
        }
        if !calendarEnabled {
            removeExternalItems(for: .calendar)
        }

        saveItems()
    }

    private func removeExternalItems(for source: ToDoExternalSource) {
        withAnimation(.smooth) {
            items.removeAll { $0.externalSource == source }
        }
        saveItems()
    }

    private struct ExternalTaskPayload {
        let source: ToDoExternalSource
        let identifier: String
        let title: String
        let dueDate: Date?
        let isCompleted: Bool
        let listIdentifier: String?
        let listTitle: String?
        let listColorHex: String?
    }
    
    func toggleCompletion(for item: ToDoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard items[index].externalSource != .calendar else { return }
        
        withAnimation(.smooth) {
            items[index].isCompleted.toggle()
            if items[index].isCompleted {
                items[index].completedAt = Date()
            } else {
                items[index].completedAt = nil
            }
        }

        let updated = items[index]
        
        saveItems()
        syncExternalCompletion(for: updated)

        // If auto-cleanup is configured for immediate removal, clean right away.
        if updated.isCompleted {
            cleanupOldItems()
        }
    }
    
    func updatePriority(for item: ToDoItem, to priority: ToDoPriority) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard items[index].externalSource != .calendar else { return }
        withAnimation {
            items[index].priority = priority
        }
        saveItems()
    }
    
    func updateTitle(for item: ToDoItem, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard items[index].externalSource != .calendar else { return }
        withAnimation(.smooth) {
            items[index].title = trimmed
        }
        saveItems()

        syncExternalTitle(for: items[index])
    }

    func updateDueDate(for item: ToDoItem, to dueDate: Date?) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard items[index].externalSource != .calendar else { return }
        withAnimation(.smooth) {
            items[index].dueDate = dueDate
        }
        saveItems()

        syncExternalDueDate(for: items[index])
    }

    func updateReminderList(for item: ToDoItem, to reminderListID: String?) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard items[index].externalSource != .calendar else { return }

        let selectedList = reminderListID.flatMap { reminderListOption(withID: $0) }
        withAnimation(.smooth) {
            items[index].externalListIdentifier = selectedList?.id
            items[index].externalListTitle = selectedList?.title
            items[index].externalListColorHex = selectedList?.colorHex
        }
        saveItems()

        guard isRemindersSyncEnabled else { return }

        if items[index].externalSource == .reminders, let externalID = items[index].externalIdentifier {
            moveExternalReminderToList(reminderIdentifier: externalID, reminderListID: reminderListID)
        } else if reminderListID != nil {
            syncNewItemToReminders(itemID: items[index].id, preferredListID: reminderListID)
        }
    }
    
    func removeItem(_ item: ToDoItem) {
        guard item.externalSource != .calendar else { return }
        // If this task is synced from Apple apps, delete the upstream item too.
        // Keep undo local-only to avoid stale external identifiers re-disappearing on next sync.
        deleteExternalBacking(for: item)
        var deletedSnapshot = item
        if item.externalSource != nil {
            deletedSnapshot.externalSource = nil
            deletedSnapshot.externalIdentifier = nil
            deletedSnapshot.externalListIdentifier = nil
            deletedSnapshot.externalListTitle = nil
            deletedSnapshot.externalListColorHex = nil
        }

        withAnimation(.smooth) {
            items.removeAll { $0.id == item.id }
            deletedItems.append(deletedSnapshot)
            showUndoToast = true
        }
        saveItems()
        
        // Reset auto-dismiss timer on each deletion.
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            withAnimation {
                self?.showUndoToast = false
                self?.deletedItems.removeAll()
            }
        }
    }
    

    
    func restoreLastDeletedItem() {
        guard let item = deletedItems.popLast() else { return }
        
        withAnimation(.smooth) {
            items.append(item)
            if deletedItems.isEmpty {
                showUndoToast = false
            }
        }
        
        if deletedItems.isEmpty {
            undoTimer?.invalidate()
        }
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

    private func loadSelectedReminderListIDs() {
        guard let raw = UserDefaults.standard.string(forKey: remindersSelectedListsKey),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            selectedReminderListIDs = []
            return
        }
        selectedReminderListIDs = Set(decoded)
    }

    private func saveSelectedReminderListIDs() {
        let payload = Array(selectedReminderListIDs).sorted()
        guard let data = try? JSONEncoder().encode(payload),
              let raw = String(data: data, encoding: .utf8) else {
            return
        }
        UserDefaults.standard.set(raw, forKey: remindersSelectedListsKey)
    }
    
    // MARK: - Cleanup
    
    private func setupCleanupTimer() {
        // Run every minute so short cleanup intervals (e.g. 5 minutes) are respected.
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.cleanupOldItems()
        }
    }
    
    private var autoCleanupHours: Int {
        UserDefaults.standard.preference(AppPreferenceKey.todoAutoCleanupHours, default: PreferenceDefault.todoAutoCleanupHours)
    }

    private var cleanupInterval: TimeInterval {
        switch autoCleanupHours {
        case 0:
            return 0 // Instantly
        case -5:
            return 5 * 60 // 5 minutes
        case let hours where hours > 0:
            return TimeInterval(hours * 60 * 60)
        default:
            return TimeInterval(PreferenceDefault.todoAutoCleanupHours * 60 * 60)
        }
    }

    private func cleanupOldItems() {
        let now = Date()

        let originalCount = items.count

        withAnimation {
            items.removeAll { item in
                guard item.isCompleted, let completedAt = item.completedAt else { return false }
                return now.timeIntervalSince(completedAt) > cleanupInterval
            }
        }
        
        let removedCount = originalCount - items.count
        if removedCount > 0 {
            saveItems()
            
            cleanupCount = removedCount
            withAnimation(.smooth) {
                showCleanupToast = true
            }
            
            cleanupToastTimer?.invalidate()
            cleanupToastTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
                withAnimation(.smooth) {
                    self?.showCleanupToast = false
                }
            }
        }
    }

    func performCleanupNow() {
        cleanupOldItems()
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
            

            
            // Exception: no-date + high priority always floats to the top.
            let lhsNoDateHigh = $0.dueDate == nil && $0.priority == .high
            let rhsNoDateHigh = $1.dueDate == nil && $1.priority == .high
            if lhsNoDateHigh != rhsNoDateHigh {
                return lhsNoDateHigh
            }

            // Then sort by due date: dated tasks first, earlier dates first.
            switch ($0.dueDate, $1.dueDate) {
            case let (lhs?, rhs?):
                if lhs != rhs { return lhs < rhs }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            // Fallback to Priority (High -> Medium -> Normal).
            if $0.priority != $1.priority {
                return rank($0.priority) > rank($1.priority)
            }
            
            // Fallback to Date
            return $0.createdAt > $1.createdAt
        }
    }

    var upcomingCalendarItems: [ToDoItem] {
        sortedItems.filter { $0.externalSource == .calendar && !$0.isCompleted }
    }

    var overviewTaskItems: [ToDoItem] {
        sortedItems.filter { !($0.externalSource == .calendar && !$0.isCompleted) }
    }
    
    private func rank(_ p: ToDoPriority) -> Int {
        switch p {
        case .high: return 3
        case .medium: return 2
        case .normal: return 1
        }
    }

    private func syncExternalTitle(for item: ToDoItem) {
        guard let source = item.externalSource, let identifier = item.externalIdentifier else { return }
        guard source == .reminders else { return }
        do {
            guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
            reminder.title = item.title
            try eventStore.save(reminder, commit: true)
        } catch {
            print("ToDoManager: Failed to sync title to \(source): \(error)")
        }
    }

    private func syncExternalDueDate(for item: ToDoItem) {
        guard let source = item.externalSource, let identifier = item.externalIdentifier else { return }
        guard source == .reminders else { return }
        do {
            guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
            if let date = item.dueDate {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: date
                )
            } else {
                reminder.dueDateComponents = nil
            }
            try eventStore.save(reminder, commit: true)
        } catch {
            print("ToDoManager: Failed to sync due date to \(source): \(error)")
        }
    }

    private func syncExternalCompletion(for item: ToDoItem) {
        guard let source = item.externalSource, let identifier = item.externalIdentifier else { return }
        guard source == .reminders else { return }
        do {
            guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
            reminder.isCompleted = item.isCompleted
            reminder.completionDate = item.isCompleted ? Date() : nil
            try eventStore.save(reminder, commit: true)
        } catch {
            print("ToDoManager: Failed to sync completion to \(source): \(error)")
        }
    }

    private func deleteExternalBacking(for item: ToDoItem) {
        guard let source = item.externalSource, let identifier = item.externalIdentifier else { return }
        guard source == .reminders else { return }

        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(macOS 14.0, *) {
            guard status == .fullAccess || status == .writeOnly else { return }
        } else {
            guard status == .authorized else { return }
        }
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        do {
            try eventStore.remove(reminder, commit: true)
        } catch {
            print("ToDoManager: Failed to delete reminder for removed task: \(error)")
        }
    }

    private func moveExternalReminderToList(reminderIdentifier: String, reminderListID: String?) {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(macOS 14.0, *) {
            guard status == .fullAccess || status == .writeOnly else { return }
        } else {
            guard status == .authorized else { return }
        }
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder else { return }

        let targetCalendar: EKCalendar? = {
            if let reminderListID {
                return eventStore.calendars(for: .reminder).first(where: { $0.calendarIdentifier == reminderListID })
            }
            return eventStore.defaultCalendarForNewReminders()
        }()

        guard let targetCalendar else { return }
        reminder.calendar = targetCalendar

        do {
            try eventStore.save(reminder, commit: true)
            syncExternalSourcesNow()
        } catch {
            print("ToDoManager: Failed to move reminder to list: \(error)")
        }
    }

    private func syncNewItemToReminders(itemID: UUID, preferredListID: String?) {
        Task {
            let granted = await requestRemindersAccess()
            guard granted else { return }

            let itemSnapshot: ToDoItem? = await MainActor.run { [weak self] in
                self?.items.first(where: { $0.id == itemID })
            }
            guard let itemSnapshot else { return }

            let calendars = eventStore.calendars(for: .reminder)
            guard !calendars.isEmpty else { return }

            let targetCalendar: EKCalendar? = {
                if let preferredListID,
                   let preferred = calendars.first(where: { $0.calendarIdentifier == preferredListID }) {
                    return preferred
                }
                if let selectedDefaultID = selectedReminderListIDs.first,
                   let selectedDefault = calendars.first(where: { $0.calendarIdentifier == selectedDefaultID }) {
                    return selectedDefault
                }
                return eventStore.defaultCalendarForNewReminders() ?? calendars.first
            }()

            guard let targetCalendar else { return }

            let reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = targetCalendar
            reminder.title = itemSnapshot.title
            reminder.priority = priorityForReminder(itemSnapshot.priority)

            if let dueDate = itemSnapshot.dueDate {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: dueDate
                )
            }

            do {
                try eventStore.save(reminder, commit: true)
                await MainActor.run {
                    guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
                    items[index].externalSource = .reminders
                    items[index].externalIdentifier = reminder.calendarItemIdentifier
                    items[index].externalListIdentifier = targetCalendar.calendarIdentifier
                    items[index].externalListTitle = targetCalendar.title
                    items[index].externalListColorHex = Self.hexColor(from: targetCalendar.cgColor)
                    saveItems()
                }
            } catch {
                print("ToDoManager: Failed to sync new task to reminders: \(error)")
            }
        }
    }

    private func priorityForReminder(_ priority: ToDoPriority) -> Int {
        switch priority {
        case .high: return 1
        case .medium: return 5
        case .normal: return 0
        }
    }

    private func reminderListOption(withID id: String) -> ToDoReminderListOption? {
        availableReminderLists.first(where: { $0.id == id })
    }

    private static func normalizeSearchToken(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func hexColor(from cgColor: CGColor?) -> String? {
        guard let cgColor,
              let nsColor = NSColor(cgColor: cgColor)?.usingColorSpace(.deviceRGB) else {
            return nil
        }
        let red = Int(round(nsColor.redComponent * 255))
        let green = Int(round(nsColor.greenComponent * 255))
        let blue = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private static func calendarOccurrenceIdentifier(for event: EKEvent) -> String {
        let baseID = event.eventIdentifier ?? event.calendarItemIdentifier
        let start = Int(event.startDate.timeIntervalSince1970)
        return "\(baseID)::\(start)"
    }
}

struct ToDoInputParseResult {
    let title: String
    let dueDate: Date?
    let reminderListQuery: String?
}

enum ToDoInputIntelligence {
    static func parseTaskDraft(_ rawText: String, now: Date = Date()) -> ToDoInputParseResult {
        let trimmedRaw = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRaw.isEmpty else {
            return ToDoInputParseResult(title: "", dueDate: nil, reminderListQuery: nil)
        }

        let tokenMatches = listMentionTokenMatches(in: trimmedRaw)
        let mentionMatch = activeMentionMatch(in: trimmedRaw)
        let dueExtraction = extractDueDate(from: trimmedRaw, now: now)

        var rangesToRemove: [Range<String.Index>] = dueExtraction.ranges + tokenMatches.map(\.fullRange)
        if let mentionRange = mentionMatch?.fullRange {
            rangesToRemove.append(mentionRange)
        }

        let cleaned = cleanupTitle(removing: rangesToRemove, from: trimmedRaw)
        let finalTitle = cleaned.isEmpty ? trimmedRaw : cleaned

        return ToDoInputParseResult(
            title: finalTitle,
            dueDate: dueExtraction.date,
            reminderListQuery: tokenMatches.last?.query ?? mentionMatch?.query.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func activeListMentionQuery(in text: String) -> String? {
        activeMentionMatch(in: text)?.query
    }

    static func listMentionTokenRanges(in text: String) -> [Range<String.Index>] {
        listMentionTokenMatches(in: text).map(\.fullRange)
    }

    static func lastListMentionTokenQuery(in text: String) -> String? {
        listMentionTokenMatches(in: text).last?.query
    }

    static func detectedDateRanges(in text: String, now: Date = Date()) -> [Range<String.Index>] {
        extractDueDate(from: text, now: now).ranges
    }

    static func removingActiveListMention(from text: String) -> String {
        guard let match = activeMentionMatch(in: text) else {
            return text
        }
        var updated = text
        updated.removeSubrange(match.fullRange)
        return updated.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func applyListMentionToken(_ listTitle: String, to text: String) -> String {
        let tokenValue = mentionTokenValue(from: listTitle)
        let token = "@\(tokenValue)"
        let withoutActiveMention = removingActiveListMention(from: text)

        let cleaned = withoutActiveMention.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            return "\(token) "
        }
        if cleaned.hasSuffix(token) {
            return "\(cleaned) "
        }
        return "\(cleaned) \(token) "
    }

    private struct MentionMatch {
        let query: String
        let fullRange: Range<String.Index>
    }

    private struct MentionTokenMatch {
        let query: String
        let fullRange: Range<String.Index>
    }

    private struct DueDateExtraction {
        let date: Date?
        let ranges: [Range<String.Index>]
    }

    private static let relativeDayOffsets: [String: Int] = [
        "today": 0, "vandaag": 0, "aujourd'hui": 0, "aujourdhui": 0, "hoy": 0,
        "tomorrow": 1, "morgen": 1, "demain": 1, "mañana": 1, "manana": 1,
        "day after tomorrow": 2, "overmorgen": 2, "apres-demain": 2, "après-demain": 2, "pasado manana": 2, "pasado mañana": 2
    ]

    private static let weekdayMap: [String: Int] = [
        "sunday": 1, "sun": 1, "zondag": 1, "dimanche": 1, "domingo": 1,
        "monday": 2, "mon": 2, "maandag": 2, "lundi": 2, "lunes": 2,
        "tuesday": 3, "tue": 3, "dinsdag": 3, "mardi": 3, "martes": 3,
        "wednesday": 4, "wed": 4, "woensdag": 4, "mercredi": 4, "miercoles": 4, "miércoles": 4,
        "thursday": 5, "thu": 5, "donderdag": 5, "jeudi": 5, "jueves": 5,
        "friday": 6, "fri": 6, "vrijdag": 6, "vendredi": 6, "viernes": 6,
        "saturday": 7, "sat": 7, "zaterdag": 7, "samedi": 7, "sabado": 7, "sábado": 7
    ]

    private static let monthMap: [String: Int] = [
        "jan": 1, "january": 1, "januari": 1, "janvier": 1, "enero": 1,
        "feb": 2, "february": 2, "februari": 2, "fevrier": 2, "février": 2, "febrero": 2,
        "mar": 3, "march": 3, "maart": 3, "mars": 3, "marzo": 3,
        "apr": 4, "april": 4, "avr": 4, "avril": 4, "abril": 4,
        "may": 5, "mei": 5, "mai": 5, "mayo": 5,
        "jun": 6, "june": 6, "juni": 6, "juin": 6, "junio": 6,
        "jul": 7, "july": 7, "juli": 7, "juillet": 7, "julio": 7,
        "aug": 8, "august": 8, "augustus": 8, "aout": 8, "août": 8, "agosto": 8,
        "sep": 9, "sept": 9, "september": 9, "septembre": 9, "septiembre": 9,
        "oct": 10, "october": 10, "okt": 10, "oktober": 10, "octobre": 10, "octubre": 10,
        "nov": 11, "november": 11, "novembre": 11, "noviembre": 11,
        "dec": 12, "december": 12, "decembre": 12, "décembre": 12, "diciembre": 12
    ]

    private static func activeMentionMatch(in text: String) -> MentionMatch? {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let pattern = "(?:^|\\s)@([\\p{L}\\p{N}_-]*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        guard let result = regex.firstMatch(in: text, options: [], range: nsRange),
              let fullRange = Range(result.range, in: text),
              let queryRange = Range(result.range(at: 1), in: text) else {
            return nil
        }
        return MentionMatch(query: String(text[queryRange]), fullRange: fullRange)
    }

    private static func listMentionTokenMatches(in text: String) -> [MentionTokenMatch] {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let pattern = "(?:^|\\s)(@([\\p{L}\\p{N}_-]+))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard let fullRange = Range(match.range(at: 1), in: text),
                  let queryRange = Range(match.range(at: 2), in: text) else {
                return nil
            }
            let rawQuery = String(text[queryRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let query = decodeMentionTokenQuery(rawQuery)
            guard !query.isEmpty else { return nil }
            return MentionTokenMatch(query: query, fullRange: fullRange)
        }
    }

    private static func extractDueDate(from text: String, now: Date) -> DueDateExtraction {
        var workingDate: Date?
        var consumedRanges: [Range<String.Index>] = []
        let calendar = Calendar.current

        if let relative = matchRelativeDay(in: text) {
            workingDate = calendar.date(byAdding: .day, value: relative.offset, to: now)
            consumedRanges.append(relative.range)
        } else if let weekMatch = matchInWeeks(in: text, now: now) {
            workingDate = weekMatch.date
            consumedRanges.append(weekMatch.range)
        } else if let absolute = matchAbsoluteDate(in: text, now: now) {
            workingDate = absolute.date
            consumedRanges.append(absolute.range)
        } else if let weekday = matchWeekday(in: text, now: now) {
            workingDate = weekday.date
            consumedRanges.append(weekday.range)
        } else if let detected = detectDate(in: text) {
            workingDate = detected.date
            consumedRanges.append(detected.range)
        }

        if let time = matchTime(in: text) {
            consumedRanges.append(time.range)
            let base = workingDate ?? now
            var components = calendar.dateComponents([.year, .month, .day], from: base)
            components.hour = time.hour
            components.minute = time.minute
            components.second = 0
            if var resolved = calendar.date(from: components) {
                if workingDate == nil && resolved < now {
                    resolved = calendar.date(byAdding: .day, value: 1, to: resolved) ?? resolved
                }
                workingDate = resolved
            }
        }

        return DueDateExtraction(date: workingDate, ranges: mergedRanges(consumedRanges))
    }

    private static func matchRelativeDay(in text: String) -> (offset: Int, range: Range<String.Index>)? {
        for (phrase, offset) in relativeDayOffsets.sorted(by: { $0.key.count > $1.key.count }) {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b"
            if let range = firstMatchRange(pattern: pattern, in: text) {
                return (offset, range)
            }
        }
        return nil
    }

    private static func matchInWeeks(in text: String, now: Date) -> (date: Date, range: Range<String.Index>)? {
        let pattern = "\\b(?:in|over|dans|en)\\s+(\\d{1,2})\\s+(?:weeks?|weken?|semaines?|semanas?)(?:\\s+([\\p{L}]+))?\\b"
        guard let result = firstMatch(pattern: pattern, in: text),
              let fullRange = Range(result.range, in: text),
              let countRange = Range(result.range(at: 1), in: text),
              let count = Int(String(text[countRange])) else {
            return nil
        }

        let calendar = Calendar.current
        let base = calendar.date(byAdding: .weekOfYear, value: count, to: now) ?? now
        var resolved = base
        if result.range(at: 2).location != NSNotFound,
           let weekdayTokenRange = Range(result.range(at: 2), in: text),
           let weekday = weekdayMap[normalizeToken(String(text[weekdayTokenRange]))] {
            resolved = nextWeekday(weekday, from: base, includeToday: true)
        }
        return (resolved, fullRange)
    }

    private static func matchAbsoluteDate(in text: String, now: Date) -> (date: Date, range: Range<String.Index>)? {
        let calendar = Calendar.current

        let dayMonthPattern = "\\b([0-3]?\\d)\\s+([\\p{L}\\.]{3,})\\b"
        if let result = firstMatch(pattern: dayMonthPattern, in: text),
           let fullRange = Range(result.range, in: text),
           let dayRange = Range(result.range(at: 1), in: text),
           let monthRange = Range(result.range(at: 2), in: text),
           let day = Int(text[dayRange]) {
            let monthToken = normalizeToken(String(text[monthRange]).replacingOccurrences(of: ".", with: ""))
            if let month = monthMap[monthToken] {
                let nowComponents = calendar.dateComponents([.year], from: now)
                let currentYear = nowComponents.year ?? 2026
                var components = DateComponents(year: currentYear, month: month, day: day)
                if var date = calendar.date(from: components) {
                    if date < now {
                        components.year = currentYear + 1
                        date = calendar.date(from: components) ?? date
                    }
                    return (date, fullRange)
                }
            }
        }

        let numericPattern = "\\b([0-3]?\\d)[/\\.-]([01]?\\d)(?:[/\\.-](\\d{2,4}))?\\b"
        if let result = firstMatch(pattern: numericPattern, in: text),
           let fullRange = Range(result.range, in: text),
           let dayRange = Range(result.range(at: 1), in: text),
           let monthRange = Range(result.range(at: 2), in: text),
           let day = Int(text[dayRange]),
           let month = Int(text[monthRange]) {
            let nowYear = calendar.component(.year, from: now)
            var year = nowYear
            if result.range(at: 3).location != NSNotFound,
               let yearRange = Range(result.range(at: 3), in: text),
               let parsedYear = Int(text[yearRange]) {
                year = parsedYear < 100 ? (2000 + parsedYear) : parsedYear
            }
            var components = DateComponents(year: year, month: month, day: day)
            if var date = calendar.date(from: components) {
                if result.range(at: 3).location == NSNotFound, date < now {
                    components.year = year + 1
                    date = calendar.date(from: components) ?? date
                }
                return (date, fullRange)
            }
        }

        return nil
    }

    private static func matchWeekday(in text: String, now: Date) -> (date: Date, range: Range<String.Index>)? {
        let pattern = "\\b([\\p{L}]+)\\b"
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        for match in regex.matches(in: text, options: [], range: nsRange) {
            guard let fullRange = Range(match.range, in: text),
                  let weekdayRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            let weekdayToken = normalizeToken(String(text[weekdayRange]))
            if let weekday = weekdayMap[weekdayToken] {
                return (nextWeekday(weekday, from: now, includeToday: false), fullRange)
            }
        }
        return nil
    }

    private static func detectDate(in text: String) -> (date: Date, range: Range<String.Index>)? {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
              let match = detector.matches(in: text, options: [], range: nsRange).first,
              let date = match.date,
              let range = Range(match.range, in: text) else {
            return nil
        }
        return (date, range)
    }

    private static func matchTime(in text: String) -> (hour: Int, minute: Int, range: Range<String.Index>)? {
        let precisePattern = "\\b([01]?\\d|2[0-3])[:\\.]([0-5]\\d)\\b"
        if let result = firstMatch(pattern: precisePattern, in: text),
           let hourRange = Range(result.range(at: 1), in: text),
           let minuteRange = Range(result.range(at: 2), in: text),
           let fullRange = Range(result.range, in: text),
           let hour = Int(text[hourRange]),
           let minute = Int(text[minuteRange]) {
            return (hour, minute, fullRange)
        }

        let dutchPattern = "\\b([01]?\\d|2[0-3])\\s*u\\b"
        if let result = firstMatch(pattern: dutchPattern, in: text),
           let hourRange = Range(result.range(at: 1), in: text),
           let fullRange = Range(result.range, in: text),
           let hour = Int(text[hourRange]) {
            return (hour, 0, fullRange)
        }

        let meridiemPattern = "\\b([1-9]|1[0-2])\\s*(am|pm)\\b"
        if let result = firstMatch(pattern: meridiemPattern, in: text),
           let hourRange = Range(result.range(at: 1), in: text),
           let ampmRange = Range(result.range(at: 2), in: text),
           let fullRange = Range(result.range, in: text),
           var hour = Int(text[hourRange]) {
            let ampm = normalizeToken(String(text[ampmRange]))
            if ampm == "pm", hour < 12 { hour += 12 }
            if ampm == "am", hour == 12 { hour = 0 }
            return (hour, 0, fullRange)
        }

        return nil
    }

    private static func nextWeekday(_ weekday: Int, from date: Date, includeToday: Bool) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = weekday
        var candidate = calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents) ?? date
        if includeToday,
           calendar.component(.weekday, from: date) == weekday {
            candidate = date
        }
        return candidate
    }

    private static func cleanupTitle(removing ranges: [Range<String.Index>], from text: String) -> String {
        guard !ranges.isEmpty else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var cleaned = text
        for range in mergedRanges(ranges).sorted(by: { $0.lowerBound > $1.lowerBound }) {
            cleaned.removeSubrange(range)
        }

        cleaned = cleaned.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\s+[,\\-]+\\s*$", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\b(at|om|a|à|en|de|el)\\s*$", with: "", options: [.regularExpression, .caseInsensitive])
        return cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func mergedRanges(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        guard !ranges.isEmpty else { return [] }
        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }
        var merged: [Range<String.Index>] = [sorted[0]]
        for range in sorted.dropFirst() {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }

    private static func firstMatch(pattern: String, in text: String) -> NSTextCheckingResult? {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        return regex.firstMatch(in: text, options: [], range: nsRange)
    }

    private static func firstMatchRange(pattern: String, in text: String) -> Range<String.Index>? {
        guard let result = firstMatch(pattern: pattern, in: text) else { return nil }
        return Range(result.range, in: text)
    }

    private static func normalizeToken(_ token: String) -> String {
        token.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func mentionTokenValue(from listTitle: String) -> String {
        let collapsed = listTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = collapsed.unicodeScalars.filter { allowed.contains($0) }
        let cleaned = String(String.UnicodeScalarView(scalars))
        return cleaned.isEmpty ? "list" : cleaned
    }

    private static func decodeMentionTokenQuery(_ token: String) -> String {
        token
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ToDoReminderListMentionTooltip: View {
    let options: [ToDoReminderListOption]
    let selectedID: String?
    let onSelect: (ToDoReminderListOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reminder list")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AdaptiveColors.secondaryTextAuto)

            ForEach(options.prefix(6)) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(colorFromHex(option.colorHex) ?? AdaptiveColors.overlayAuto(0.45))
                        Text(option.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.primaryTextAuto)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if option.id == selectedID {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.blue.opacity(0.95))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(option.id == selectedID ? AdaptiveColors.overlayAuto(0.1) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AdaptiveColors.panelBackgroundAuto)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AdaptiveColors.subtleBorderAuto.opacity(0.9), lineWidth: 1)
                )
        )
    }

    private func colorFromHex(_ hex: String?) -> Color? {
        guard let hex else { return nil }
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }
}
