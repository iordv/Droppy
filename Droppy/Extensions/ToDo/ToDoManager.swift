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
import ObjectiveC.runtime



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
    var externalParentIdentifier: String? = nil
    var externalListIdentifier: String?
    var externalListTitle: String?
    var externalListColorHex: String?
    var externalMeetingURL: String? = nil
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
        lhs.externalParentIdentifier == rhs.externalParentIdentifier &&
        lhs.externalListIdentifier == rhs.externalListIdentifier &&
        lhs.externalListTitle == rhs.externalListTitle &&
        lhs.externalListColorHex == rhs.externalListColorHex &&
        lhs.externalMeetingURL == rhs.externalMeetingURL
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
    
    var items: [ToDoItem] = [] {
        didSet {
            // Keep sorted view data in sync during the same mutation transaction
            // so insert/remove transitions animate reliably.
            sortedItemsCache = nil
            itemPartitionCache = nil
            activeTimelineCountsCache = nil
            reminderHierarchyDepthCache = nil
        }
    }
    var isVisible: Bool = false
    var isShelfListExpanded: Bool = false
    var isInteractingWithPopover: Bool = false
    var isEditingText: Bool = false
    var availableReminderLists: [ToDoReminderListOption] = [] {
        didSet {
            reminderListSearchIndex = availableReminderLists.map { option in
                (option: option, normalizedTitle: Self.normalizeSearchToken(option.title))
            }
        }
    }
    var selectedReminderListIDs: Set<String> = []
    var availableCalendarLists: [ToDoReminderListOption] = []
    var selectedCalendarListIDs: Set<String> = []
    
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
    var hideUndatedRemindersChangeToken: Int = 0
    
    private let fileName = "todo_items.json"
    private let eventStore = EKEventStore()
    private var calendarAccessConfirmedInSession = false
    private var remindersAccessConfirmedInSession = false
    private var cleanupTimer: Timer?
    private var externalSyncTimer: Timer?
    private var lastExternalSyncRequestAt: Date?
    private var isExternalSyncInFlight = false
    private var hasPendingExternalSync = false
    private var eventStoreObserver: NSObjectProtocol?
    private var appDidBecomeActiveObserver: NSObjectProtocol?
    private var workspaceDidWakeObserver: NSObjectProtocol?
    private var openRefreshWorkItem: DispatchWorkItem?
    private var eventStoreSyncDebounceWorkItem: DispatchWorkItem?
    private var dueSoonNotificationRefreshWorkItem: DispatchWorkItem?
    private var dueSoonNotificationTimer: Timer?
    private var dueSoonDeliveredTokens: Set<String> = []
    private var persistenceWorkItem: DispatchWorkItem?
    private let persistenceQueue = DispatchQueue(label: "app.getdroppy.todo.persistence", qos: .utility)
    private var sortedItemsCache: [ToDoItem]?
    private var itemPartitionCache: ItemPartitionCache?
    private var activeTimelineCountsCache: (taskItems: Int, calendarItems: Int)?
    private var reminderHierarchyDepthCache: [UUID: Int]?
    private var reminderListSearchIndex: [(option: ToDoReminderListOption, normalizedTitle: String)] = []
    private var isRefreshingReminderLists = false
    private var isRefreshingCalendarLists = false
    private let remindersSelectedListsKey = AppPreferenceKey.todoSyncRemindersListIDs
    private let defaultReminderListKey = AppPreferenceKey.todoDefaultReminderListID
    private let quickOpenShortcutKey = AppPreferenceKey.todoQuickOpenShortcut
    private let calendarSelectedListsKey = AppPreferenceKey.todoSyncCalendarListIDs
    private let dueSoonLeadTimes: [TimeInterval] = [15 * 60, 60]
    @ObservationIgnored
    private var quickOpenHotKey: GlobalHotKey?
    @ObservationIgnored
    private var storedQuickOpenShortcut: SavedShortcut?

    private enum PermissionRequestSource {
        case userInteraction
        case backgroundSync
    }
    
    // MARK: - Lifecycle
    
    private init() {
        loadItems()
        loadSelectedReminderListIDs()
        loadSelectedCalendarListIDs()
        loadQuickOpenShortcut()
        reloadQuickOpenShortcutMonitoring()
        setupCleanupTimer()
        setupExternalSyncTimer()
        observeEventStoreChanges()
        observeAppActivity()
        
        // Initial cleanup on launch
        cleanupOldItems()
        syncExternalSourcesNow()
        scheduleDueSoonNotificationsRefresh(debounce: 0)
    }
    
    deinit {
        cleanupTimer?.invalidate()
        externalSyncTimer?.invalidate()
        if let eventStoreObserver {
            NotificationCenter.default.removeObserver(eventStoreObserver)
        }
        if let appDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(appDidBecomeActiveObserver)
        }
        if let workspaceDidWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceDidWakeObserver)
        }
        openRefreshWorkItem?.cancel()
        eventStoreSyncDebounceWorkItem?.cancel()
        dueSoonNotificationRefreshWorkItem?.cancel()
        dueSoonNotificationTimer?.invalidate()
        persistenceWorkItem?.cancel()
        undoTimer?.invalidate()
        cleanupToastTimer?.invalidate()
        quickOpenHotKey = nil
    }
    
    // MARK: - Actions
    
    func toggleVisibility() {
        withAnimation(.smooth) {
            isVisible.toggle()
        }
        if isVisible {
            // Defer heavier refresh work so opening transition remains responsive.
            openRefreshWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.cleanupOldItems()
                self.syncExternalSourcesNow(minimumInterval: 1.5)
            }
            openRefreshWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
        } else {
            openRefreshWorkItem?.cancel()
            isShelfListExpanded = false
        }
    }
    
    func hide() {
        openRefreshWorkItem?.cancel()
        withAnimation(.smooth) {
            isVisible = false
        }
        isShelfListExpanded = false
    }

    var quickOpenShortcut: SavedShortcut? {
        storedQuickOpenShortcut
    }

    func setQuickOpenShortcut(_ shortcut: SavedShortcut?) {
        let sanitized = shortcut.map(Self.sanitizedShortcut)
        guard sanitized != storedQuickOpenShortcut else { return }

        storedQuickOpenShortcut = sanitized
        if let sanitized,
           let encoded = try? JSONEncoder().encode(sanitized) {
            UserDefaults.standard.set(encoded, forKey: quickOpenShortcutKey)
        } else {
            UserDefaults.standard.removeObject(forKey: quickOpenShortcutKey)
        }

        reloadQuickOpenShortcutMonitoring()
        NotificationCenter.default.post(name: .todoQuickOpenShortcutChanged, object: nil)
    }
    
    func addItem(title: String, priority: ToDoPriority, dueDate: Date? = nil, reminderListID: String? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalizedListID = reminderListID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitListID = (normalizedListID?.isEmpty == false) ? normalizedListID : nil
        let effectiveReminderListID = explicitListID ?? preferredReminderListIDForNewTasks()
        let selectedList = effectiveReminderListID.flatMap { reminderListOption(withID: $0) }

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
            syncNewItemToReminders(itemID: newItem.id, preferredListID: effectiveReminderListID)
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

    var isShelfSplitViewEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.todoShelfSplitViewEnabled,
            default: PreferenceDefault.todoShelfSplitViewEnabled
        )
    }

    var isDueSoonNotificationsEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.todoDueSoonNotificationsEnabled,
            default: PreferenceDefault.todoDueSoonNotificationsEnabled
        )
    }

    var isDueSoonNotificationChimeEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.todoDueSoonNotificationsChimeEnabled,
            default: PreferenceDefault.todoDueSoonNotificationsChimeEnabled
        )
    }

    var isHideUndatedRemindersEnabled: Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.todoHideUndatedReminders,
            default: PreferenceDefault.todoHideUndatedReminders
        )
    }

    var defaultReminderListID: String? {
        let stored = UserDefaults.standard.preference(
            defaultReminderListKey,
            default: PreferenceDefault.todoDefaultReminderListID
        )
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    func preferredReminderListIDForNewTasks() -> String? {
        defaultReminderListID
    }

    func setShelfSplitViewEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: AppPreferenceKey.todoShelfSplitViewEnabled)
    }

    func setDueSoonNotificationsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: AppPreferenceKey.todoDueSoonNotificationsEnabled)
        if !enabled {
            clearDueSoonNotifications()
        }
        scheduleDueSoonNotificationsRefresh(debounce: 0)
    }

    func setDueSoonNotificationChimeEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: AppPreferenceKey.todoDueSoonNotificationsChimeEnabled)
        scheduleDueSoonNotificationsRefresh(debounce: 0)
    }

    func setHideUndatedRemindersEnabled(_ enabled: Bool) {
        guard isHideUndatedRemindersEnabled != enabled else { return }
        UserDefaults.standard.set(enabled, forKey: AppPreferenceKey.todoHideUndatedReminders)
        itemPartitionCache = nil
        activeTimelineCountsCache = nil
        hideUndatedRemindersChangeToken += 1
    }

    func setDefaultReminderListID(_ listID: String?) {
        let normalized = listID?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextStoredValue = normalized.isEmpty ? "" : normalized
        let currentStoredValue = UserDefaults.standard.preference(
            defaultReminderListKey,
            default: PreferenceDefault.todoDefaultReminderListID
        )
        var didUpdateSelection = false
        if !nextStoredValue.isEmpty && !selectedReminderListIDs.contains(nextStoredValue) {
            selectedReminderListIDs.insert(nextStoredValue)
            saveSelectedReminderListIDs()
            didUpdateSelection = true
        }
        if currentStoredValue != nextStoredValue {
            UserDefaults.standard.set(nextStoredValue, forKey: defaultReminderListKey)
        }
        if didUpdateSelection {
            syncExternalSourcesNow()
        }
    }

    func setRemindersSyncEnabled(_ enabled: Bool) {
        Task { @MainActor in
            if enabled {
                let granted = await requestRemindersAccess(source: .userInteraction)
                UserDefaults.standard.set(granted, forKey: AppPreferenceKey.todoSyncRemindersEnabled)
                if granted {
                    self.refreshReminderListsNow()
                    self.syncExternalSourcesNow()
                } else {
                    self.availableReminderLists = []
                    self.removeExternalItems(for: .reminders)
                    if shouldOpenRemindersPrivacySettings() {
                        self.openRemindersPrivacySettings()
                    }
                }
            } else {
                UserDefaults.standard.set(false, forKey: AppPreferenceKey.todoSyncRemindersEnabled)
                self.availableReminderLists = []
                self.removeExternalItems(for: .reminders)
                self.remindersAccessConfirmedInSession = false
            }
        }
    }

    func setCalendarSyncEnabled(_ enabled: Bool) {
        Task { @MainActor in
            if enabled {
                let granted = await requestCalendarAccess(source: .userInteraction)
                UserDefaults.standard.set(granted, forKey: AppPreferenceKey.todoSyncCalendarEnabled)
                if granted {
                    self.refreshCalendarListsNow()
                    self.syncExternalSourcesNow()
                } else {
                    self.availableCalendarLists = []
                    self.removeExternalItems(for: .calendar)
                    if shouldOpenCalendarPrivacySettings() {
                        openCalendarPrivacySettings()
                    }
                }
            } else {
                UserDefaults.standard.set(false, forKey: AppPreferenceKey.todoSyncCalendarEnabled)
                self.availableCalendarLists = []
                self.removeExternalItems(for: .calendar)
                self.calendarAccessConfirmedInSession = false
            }
        }
    }

    func refreshReminderListsNow() {
        guard !isRefreshingReminderLists else { return }
        isRefreshingReminderLists = true
        Task { [weak self] in
            guard let self else { return }
            await refreshReminderLists()
            await MainActor.run {
                self.isRefreshingReminderLists = false
            }
        }
    }

    func refreshCalendarListsNow() {
        guard !isRefreshingCalendarLists else { return }
        isRefreshingCalendarLists = true
        Task { [weak self] in
            guard let self else { return }
            await refreshCalendarLists()
            await MainActor.run {
                self.isRefreshingCalendarLists = false
            }
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
        let prefixMatches = reminderListSearchIndex.compactMap { entry in
            entry.normalizedTitle.hasPrefix(normalizedQuery) ? entry.option : nil
        }
        if !prefixMatches.isEmpty {
            return prefixMatches
        }
        return reminderListSearchIndex.compactMap { entry in
            entry.normalizedTitle.contains(normalizedQuery) ? entry.option : nil
        }
    }

    func resolveReminderList(matching query: String) -> ToDoReminderListOption? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedQuery = Self.normalizeSearchToken(trimmed)
        if let exact = reminderListSearchIndex.first(where: {
            $0.normalizedTitle == normalizedQuery
        }) {
            return exact.option
        }
        if let prefix = reminderListSearchIndex.first(where: {
            $0.normalizedTitle.hasPrefix(normalizedQuery)
        }) {
            return prefix.option
        }
        return reminderListSearchIndex.first(where: { $0.normalizedTitle.contains(normalizedQuery) })?.option
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

    func isCalendarListSelected(_ listID: String) -> Bool {
        selectedCalendarListIDs.contains(listID)
    }

    func toggleCalendarListSelection(_ listID: String) {
        if selectedCalendarListIDs.contains(listID) {
            selectedCalendarListIDs.remove(listID)
        } else {
            selectedCalendarListIDs.insert(listID)
        }
        saveSelectedCalendarListIDs()
        syncExternalSourcesNow()
    }

    func selectAllCalendarLists() {
        selectedCalendarListIDs = Set(availableCalendarLists.map(\.id))
        saveSelectedCalendarListIDs()
        syncExternalSourcesNow()
    }

    func clearCalendarListsSelection() {
        selectedCalendarListIDs.removeAll()
        saveSelectedCalendarListIDs()
        syncExternalSourcesNow()
    }

    func syncExternalSourcesNow(minimumInterval: TimeInterval = 0) {
        if minimumInterval > 0,
           let lastRequest = lastExternalSyncRequestAt,
           Date().timeIntervalSince(lastRequest) < minimumInterval {
            return
        }
        lastExternalSyncRequestAt = Date()
        if isExternalSyncInFlight {
            hasPendingExternalSync = true
            return
        }
        isExternalSyncInFlight = true
        Task {
            await syncExternalSources()
            await MainActor.run {
                self.isExternalSyncInFlight = false
                if self.hasPendingExternalSync {
                    self.hasPendingExternalSync = false
                    self.syncExternalSourcesNow(minimumInterval: 1.0)
                }
            }
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

    private func observeAppActivity() {
        appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleDueSoonNotificationsRefresh(debounce: 0)
        }

        workspaceDidWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleDueSoonNotificationsRefresh(debounce: 0)
        }
    }

    private func syncExternalSources() async {
        var reminderPayloads: [ExternalTaskPayload] = []
        var calendarPayloads: [ExternalTaskPayload] = []

        if isRemindersSyncEnabled {
            let granted = await requestRemindersAccess(source: .backgroundSync)
            if granted {
                await refreshReminderLists()
                reminderPayloads = await fetchReminders()
            } else {
                await MainActor.run {
                    UserDefaults.standard.set(false, forKey: AppPreferenceKey.todoSyncRemindersEnabled)
                    self.availableReminderLists = []
                    self.remindersAccessConfirmedInSession = false
                }
            }
        }

        if isCalendarSyncEnabled {
            let granted = await requestCalendarAccess(source: .backgroundSync)
            if granted {
                await refreshCalendarLists()
                calendarPayloads = await fetchCalendarEvents()
            } else {
                await MainActor.run {
                    UserDefaults.standard.set(false, forKey: AppPreferenceKey.todoSyncCalendarEnabled)
                    self.calendarAccessConfirmedInSession = false
                    self.availableCalendarLists = []
                }
            }
        }

        await MainActor.run {
            applyExternalSync(reminderPayloads: reminderPayloads, calendarPayloads: calendarPayloads)
        }
    }

    @MainActor
    private func requestRemindersAccess(source: PermissionRequestSource) async -> Bool {
        if remindersAccessConfirmedInSession {
            return true
        }

        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        switch currentStatus {
        case .fullAccess:
            remindersAccessConfirmedInSession = true
            return true
        case .denied, .restricted:
            remindersAccessConfirmedInSession = false
            return false
        case .writeOnly, .notDetermined:
            let granted = await requestRemindersFullAccessWithRetry(source: source)
            remindersAccessConfirmedInSession = granted
            if granted {
                eventStore.reset()
            }
            return granted
        @unknown default:
            remindersAccessConfirmedInSession = false
            return false
        }
    }

    @MainActor
    private func openRemindersPrivacySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.Privacy.Reminders",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        for raw in candidates {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    @MainActor
    private func requestCalendarAccess(source: PermissionRequestSource) async -> Bool {
        if calendarAccessConfirmedInSession {
            return true
        }

        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        switch currentStatus {
        case .fullAccess:
            calendarAccessConfirmedInSession = true
            return true
        case .denied, .restricted:
            calendarAccessConfirmedInSession = false
            return false
        case .writeOnly, .notDetermined:
            let granted = await requestCalendarFullAccessWithRetry(source: source)
            calendarAccessConfirmedInSession = granted
            if granted {
                eventStore.reset()
            }
            return granted
        @unknown default:
            calendarAccessConfirmedInSession = false
            return false
        }
    }

    @MainActor
    private func openCalendarPrivacySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.Privacy.Calendars",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        for raw in candidates {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    @MainActor
    private func shouldUseForegroundPermissionPrompt(for source: PermissionRequestSource) -> Bool {
        guard source == .userInteraction else { return false }
        guard NSApp.isActive else { return false }
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return false }
        guard frontmost.processIdentifier == ProcessInfo.processInfo.processIdentifier else { return false }
        return NSApp.keyWindow != nil || NSApp.mainWindow != nil
    }

    @MainActor
    private func requestCalendarFullAccessWithRetry(source: PermissionRequestSource) async -> Bool {
        for attempt in 0..<2 {
            let statusBefore = EKEventStore.authorizationStatus(for: .event)
            print("ToDoManager: Calendar auth attempt \(attempt + 1), status before request: \(authorizationStatusName(statusBefore))")

            let shouldPrepareForegroundPrompt = shouldUseForegroundPermissionPrompt(for: source)
            let previousPolicy = NSApp.activationPolicy()
            let switchedToRegular = shouldPrepareForegroundPrompt && previousPolicy != .regular
            if switchedToRegular {
                _ = NSApp.setActivationPolicy(.regular)
            }

            defer {
                if switchedToRegular {
                    _ = NSApp.setActivationPolicy(previousPolicy)
                }
            }

            if shouldPrepareForegroundPrompt {
                // Give AppKit one frame after policy changes before requesting permission.
                try? await Task.sleep(nanoseconds: 120_000_000)
            }

            let permissionStore = EKEventStore()
            let fullGranted = await requestCalendarFullAccess(using: permissionStore)
            if fullGranted {
                print("ToDoManager: Calendar full access granted by EventKit request")
                return true
            }

            eventStore.reset()
            let statusAfterRequest = EKEventStore.authorizationStatus(for: .event)
            print("ToDoManager: Calendar auth status after request: \(authorizationStatusName(statusAfterRequest))")
            if statusAfterRequest == .fullAccess {
                return true
            }

            // Some systems stay in `.notDetermined` after full-access request without presenting
            // the privacy sheet. Probe write-only once to force a TCC transition, then retry full.
            if statusAfterRequest == .notDetermined && attempt == 0 {
                _ = await requestCalendarWriteOnlyAccess(using: permissionStore)
                eventStore.reset()
                let statusAfterWriteOnly = EKEventStore.authorizationStatus(for: .event)
                print("ToDoManager: Calendar auth status after write-only probe: \(authorizationStatusName(statusAfterWriteOnly))")

                if statusAfterWriteOnly == .fullAccess {
                    return true
                }

                if statusAfterWriteOnly == .writeOnly {
                    let escalated = await requestCalendarFullAccess(using: permissionStore)
                    if escalated {
                        print("ToDoManager: Calendar full access granted after write-only probe")
                        return true
                    }
                    eventStore.reset()
                    let statusAfterEscalation = EKEventStore.authorizationStatus(for: .event)
                    print("ToDoManager: Calendar auth status after full-access escalation: \(authorizationStatusName(statusAfterEscalation))")
                    if statusAfterEscalation == .fullAccess {
                        return true
                    }
                }
            }

            if statusAfterRequest == .denied || statusAfterRequest == .restricted || statusAfterRequest == .writeOnly {
                return false
            }
            // Keep trying once if status is still .notDetermined.
            if statusAfterRequest != .notDetermined {
                return false
            }

            if attempt == 1 {
                return false
            }
        }
        return false
    }

    @MainActor
    private func requestRemindersFullAccessWithRetry(source: PermissionRequestSource) async -> Bool {
        for attempt in 0..<2 {
            let statusBefore = EKEventStore.authorizationStatus(for: .reminder)
            print("ToDoManager: Reminders auth attempt \(attempt + 1), status before request: \(authorizationStatusName(statusBefore))")

            let shouldPrepareForegroundPrompt = shouldUseForegroundPermissionPrompt(for: source)
            let previousPolicy = NSApp.activationPolicy()
            let switchedToRegular = shouldPrepareForegroundPrompt && previousPolicy != .regular
            if switchedToRegular {
                _ = NSApp.setActivationPolicy(.regular)
            }

            defer {
                if switchedToRegular {
                    _ = NSApp.setActivationPolicy(previousPolicy)
                }
            }

            if shouldPrepareForegroundPrompt {
                // Give AppKit one frame after policy changes before requesting permission.
                try? await Task.sleep(nanoseconds: 120_000_000)
            }

            let permissionStore = EKEventStore()
            let granted = await requestRemindersFullAccess(using: permissionStore)
            if granted {
                print("ToDoManager: Reminders full access granted by EventKit request")
                return true
            }

            eventStore.reset()
            let statusAfterRequest = EKEventStore.authorizationStatus(for: .reminder)
            print("ToDoManager: Reminders auth status after request: \(authorizationStatusName(statusAfterRequest))")
            if statusAfterRequest == .fullAccess {
                return true
            }
            if statusAfterRequest == .denied || statusAfterRequest == .restricted || statusAfterRequest == .writeOnly {
                return false
            }
            // Keep trying once if status is still .notDetermined.
            if statusAfterRequest != .notDetermined {
                return false
            }

            if attempt == 1 {
                return false
            }
        }
        return false
    }

    private func shouldOpenRemindersPrivacySettings() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .denied, .restricted, .writeOnly:
            return true
        default:
            return false
        }
    }

    private func shouldOpenCalendarPrivacySettings() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .denied, .restricted, .writeOnly:
            return true
        default:
            return false
        }
    }

    private func authorizationStatusName(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .fullAccess:
            return "fullAccess"
        case .writeOnly:
            return "writeOnly"
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }

    @MainActor
    private func requestCalendarFullAccess(using store: EKEventStore) async -> Bool {
        await withCheckedContinuation { continuation in
            store.requestFullAccessToEvents { granted, error in
                if let error {
                    print("ToDoManager: requestFullAccessToEvents failed: \(error)")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    @MainActor
    private func requestCalendarWriteOnlyAccess(using store: EKEventStore) async -> Bool {
        await withCheckedContinuation { continuation in
            store.requestWriteOnlyAccessToEvents { granted, error in
                if let error {
                    print("ToDoManager: requestWriteOnlyAccessToEvents failed: \(error)")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    @MainActor
    private func requestRemindersFullAccess(using store: EKEventStore) async -> Bool {
        await withCheckedContinuation { continuation in
            store.requestFullAccessToReminders { granted, error in
                if let error {
                    print("ToDoManager: requestFullAccessToReminders failed: \(error)")
                }
                continuation.resume(returning: granted)
            }
        }
    }

    private func refreshReminderLists() async {
        guard isRemindersSyncEnabled else {
            await MainActor.run {
                availableReminderLists = []
            }
            return
        }

        let status = EKEventStore.authorizationStatus(for: .reminder)
        let hasAccess = status == .fullAccess
        guard hasAccess else {
            await MainActor.run {
                availableReminderLists = []
            }
            return
        }

        let readStore = EKEventStore()
        let options = readStore
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

            if let defaultReminderListID, !availableIDs.contains(defaultReminderListID) {
                setDefaultReminderListID(nil)
            }
        }
    }

    private func fetchReminders() async -> [ExternalTaskPayload] {
        let readStore = EKEventStore()
        let allCalendars = readStore.calendars(for: .reminder)
        guard !allCalendars.isEmpty else { return [] }

        let selectedIDs = selectedReminderListIDs
        let selectedCalendars = allCalendars.filter { selectedIDs.contains($0.calendarIdentifier) }
        guard !selectedCalendars.isEmpty else { return [] }

        let predicate = readStore.predicateForReminders(in: selectedCalendars)

        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            readStore.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        var parentAliasLookup: [String: String] = [:]
        parentAliasLookup.reserveCapacity(reminders.count * 10)
        for reminder in reminders {
            let canonicalID = reminder.calendarItemIdentifier
            for alias in Self.reminderIdentifierAliases(for: reminder) {
                parentAliasLookup[alias] = canonicalID
            }
            for objectAlias in Self.reminderObjectIdentifierAliases(for: reminder) {
                parentAliasLookup[objectAlias] = canonicalID
            }
        }

        var parentReferenceCount = 0
        var resolvedParentCount = 0
        let payloads: [ExternalTaskPayload] = reminders.compactMap { reminder in
            guard !reminder.isCompleted else { return nil }
            let title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let canonicalID = reminder.calendarItemIdentifier
            let parentReference = Self.reminderParentReference(for: reminder)
            if parentReference != nil {
                parentReferenceCount += 1
            }
            let resolvedParentID: String? = {
                guard let parentReference else { return nil }
                switch parentReference {
                case .string(let reference):
                    for candidate in Self.expandedIdentifierAliases(from: reference) {
                        if let resolved = parentAliasLookup[candidate] {
                            return resolved
                        }
                    }
                    return nil
                case .object(let reference):
                    for candidate in Self.identifierAliases(from: reference) {
                        if let resolved = parentAliasLookup[candidate] {
                            return resolved
                        }
                    }
                    return nil
                }
            }()
            if resolvedParentID != nil {
                resolvedParentCount += 1
            }
            let parentID = (resolvedParentID == canonicalID) ? nil : resolvedParentID
            return ExternalTaskPayload(
                source: .reminders,
                identifier: canonicalID,
                parentIdentifier: parentID,
                title: title,
                dueDate: reminder.dueDateComponents?.date,
                isCompleted: reminder.isCompleted,
                listIdentifier: reminder.calendar.calendarIdentifier,
                listTitle: reminder.calendar.title,
                listColorHex: Self.hexColor(from: reminder.calendar.cgColor),
                meetingURL: nil
            )
        }
        if parentReferenceCount > 0 && resolvedParentCount == 0 {
            print("ToDoManager: Found \(parentReferenceCount) reminder parent references, but none resolved to reminder identifiers.")
        }
        return payloads
    }

    private func fetchCalendarEvents() async -> [ExternalTaskPayload] {
        let readStore = EKEventStore()
        let allCalendars = readStore.calendars(for: .event)
        let selectedIDs = selectedCalendarListIDs
        let calendars = allCalendars.filter { selectedIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(30 * 24 * 60 * 60)
        let predicate = readStore.predicateForEvents(withStart: now, end: end, calendars: calendars)
        let events: [EKEvent] = readStore.events(matching: predicate)

        var seenIDs = Set<String>()
        let payloads: [ExternalTaskPayload] = events.compactMap { (event: EKEvent) -> ExternalTaskPayload? in
            guard event.endDate >= now else { return nil }
            if event.status == .canceled { return nil }

            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }

            let identifier = Self.calendarOccurrenceIdentifier(for: event)
            guard seenIDs.insert(identifier).inserted else { return nil }

            return ExternalTaskPayload(
                source: .calendar,
                identifier: identifier,
                parentIdentifier: nil,
                title: title,
                dueDate: event.startDate,
                isCompleted: false,
                listIdentifier: event.calendar.calendarIdentifier,
                listTitle: event.calendar.title,
                listColorHex: Self.hexColor(from: event.calendar.cgColor),
                meetingURL: Self.calendarMeetingURL(for: event)
            )
        }
        return payloads
    }

    private func applyExternalSync(reminderPayloads: [ExternalTaskPayload], calendarPayloads: [ExternalTaskPayload]) {
        let remindersEnabled = isRemindersSyncEnabled
        let calendarEnabled = isCalendarSyncEnabled
        let now = Date()
        var didMutateItems = false

        var payloadByKey: [String: ExternalTaskPayload] = [:]
        payloadByKey.reserveCapacity(reminderPayloads.count + calendarPayloads.count)
        for payload in (reminderPayloads + calendarPayloads) {
            payloadByKey["\(payload.source.rawValue)::\(payload.identifier)"] = payload
        }

        for index in items.indices {
            guard let source = items[index].externalSource, let externalID = items[index].externalIdentifier else { continue }
            let keepSource = (source == .reminders && remindersEnabled) || (source == .calendar && calendarEnabled)
            guard keepSource else { continue }

            let key = "\(source.rawValue)::\(externalID)"
            if let payload = payloadByKey.removeValue(forKey: key) {
                var current = items[index]
                var changed = false

                if current.title != payload.title {
                    current.title = payload.title
                    changed = true
                }
                if current.dueDate != payload.dueDate {
                    current.dueDate = payload.dueDate
                    changed = true
                }
                if current.isCompleted != payload.isCompleted {
                    current.isCompleted = payload.isCompleted
                    changed = true
                }
                if current.externalParentIdentifier != payload.parentIdentifier {
                    current.externalParentIdentifier = payload.parentIdentifier
                    changed = true
                }

                let nextCompletedAt = payload.isCompleted ? (current.completedAt ?? now) : nil
                if current.completedAt != nextCompletedAt {
                    current.completedAt = nextCompletedAt
                    changed = true
                }
                if current.externalListIdentifier != payload.listIdentifier {
                    current.externalListIdentifier = payload.listIdentifier
                    changed = true
                }
                if current.externalListTitle != payload.listTitle {
                    current.externalListTitle = payload.listTitle
                    changed = true
                }
                if current.externalListColorHex != payload.listColorHex {
                    current.externalListColorHex = payload.listColorHex
                    changed = true
                }
                if current.externalMeetingURL != payload.meetingURL {
                    current.externalMeetingURL = payload.meetingURL
                    changed = true
                }

                if changed {
                    items[index] = current
                    didMutateItems = true
                }
            }
        }

        for payload in payloadByKey.values {
            let item = ToDoItem(
                title: payload.title,
                priority: .normal,
                dueDate: payload.dueDate,
                externalSource: payload.source,
                externalIdentifier: payload.identifier,
                externalParentIdentifier: payload.parentIdentifier,
                externalListIdentifier: payload.listIdentifier,
                externalListTitle: payload.listTitle,
                externalListColorHex: payload.listColorHex,
                externalMeetingURL: payload.meetingURL,
                createdAt: now,
                completedAt: payload.isCompleted ? now : nil,
                isCompleted: payload.isCompleted
            )
            items.insert(item, at: 0)
            didMutateItems = true
        }

        // Remove stale external items from enabled sources when they no longer exist upstream.
        let activeKeys = Set((reminderPayloads + calendarPayloads).map { "\($0.source.rawValue)::\($0.identifier)" })
        let beforePruneCount = items.count
        items.removeAll { item in
            guard let source = item.externalSource, let externalID = item.externalIdentifier else { return false }
            let sourceEnabled = (source == .reminders && remindersEnabled) || (source == .calendar && calendarEnabled)
            guard sourceEnabled else { return false }
            let key = "\(source.rawValue)::\(externalID)"
            return !activeKeys.contains(key)
        }
        if items.count != beforePruneCount {
            didMutateItems = true
        }

        if !remindersEnabled {
            didMutateItems = removeExternalItems(for: .reminders, persist: false) || didMutateItems
        }
        if !calendarEnabled {
            didMutateItems = removeExternalItems(for: .calendar, persist: false) || didMutateItems
        }

        if didMutateItems {
            saveItems()
        }
    }

    @discardableResult
    private func removeExternalItems(for source: ToDoExternalSource, persist: Bool = true) -> Bool {
        let beforeCount = items.count
        withAnimation(.smooth) {
            items.removeAll { $0.externalSource == source }
        }
        let changed = items.count != beforeCount
        if changed && persist {
            saveItems()
        }
        return changed
    }

    private struct ExternalTaskPayload {
        let source: ToDoExternalSource
        let identifier: String
        let parentIdentifier: String?
        let title: String
        let dueDate: Date?
        let isCompleted: Bool
        let listIdentifier: String?
        let listTitle: String?
        let listColorHex: String?
        let meetingURL: String?
    }

    private struct DueSoonNotificationCandidate {
        let stableIdentity: String
        let title: String
        let source: ToDoExternalSource?
        let dueDate: Date
        let listTitle: String?
    }

    private struct DueSoonNotificationEntry {
        let token: String
        let candidate: DueSoonNotificationCandidate
        let leadTime: TimeInterval
        let fireDate: Date
    }

    private func scheduleDueSoonNotificationsRefresh(debounce: TimeInterval = 0.25) {
        dueSoonNotificationRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshDueSoonNotificationsNow()
        }
        dueSoonNotificationRefreshWorkItem = workItem
        if debounce <= 0 {
            DispatchQueue.main.async(execute: workItem)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: workItem)
        }
    }

    private func refreshDueSoonNotificationsNow() {
        dueSoonNotificationRefreshWorkItem = nil

        dueSoonNotificationTimer?.invalidate()
        dueSoonNotificationTimer = nil

        guard isDueSoonNotificationsEnabled else { return }

        let shouldUseChime = isDueSoonNotificationChimeEnabled
        let now = Date()
        let candidates = items.compactMap { item -> DueSoonNotificationCandidate? in
            guard !item.isCompleted else { return nil }
            guard let dueDate = item.dueDate else { return nil }
            guard dueDate > now else { return nil }
            guard hasExplicitDueTime(dueDate) else { return nil }

            let stableIdentity: String
            if let source = item.externalSource,
               let externalIdentifier = item.externalIdentifier,
               !externalIdentifier.isEmpty {
                stableIdentity = "\(source.rawValue)::\(externalIdentifier)"
            } else {
                stableIdentity = "local::\(item.id.uuidString)"
            }

            return DueSoonNotificationCandidate(
                stableIdentity: stableIdentity,
                title: item.title,
                source: item.externalSource,
                dueDate: dueDate,
                listTitle: item.externalListTitle
            )
        }
        let entries = dueSoonEntries(from: candidates)
        let activeTokens = Set(entries.map(\.token))
        dueSoonDeliveredTokens = dueSoonDeliveredTokens.intersection(activeTokens)

        let dueNow = entries
            .filter { $0.fireDate <= now }
            .filter { !dueSoonDeliveredTokens.contains($0.token) }
            .sorted { $0.fireDate < $1.fireDate }

        // When refresh runs late (sleep/wake, heavy sync), multiple lead-times for the
        // same event can be overdue at once. Emit only the most recent missed alert.
        let dueNowCollapsed = collapseOverdueDueSoonEntries(dueNow)

        for entry in dueNowCollapsed {
            dueSoonDeliveredTokens.insert(entry.token)
            NotificationHUDManager.shared.showDueSoonNotification(
                title: entry.candidate.title,
                subtitle: dueSoonNotificationSubtitle(for: entry.candidate, leadTime: entry.leadTime),
                body: dueSoonNotificationBody(for: entry.candidate),
                playChime: shouldUseChime
            )
        }

        guard let nextEntry = entries
            .filter({ $0.fireDate > now && !dueSoonDeliveredTokens.contains($0.token) })
            .min(by: { $0.fireDate < $1.fireDate }) else {
            return
        }

        let delay = max(0.05, nextEntry.fireDate.timeIntervalSince(now))
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.refreshDueSoonNotificationsNow()
        }
        dueSoonNotificationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func dueSoonEntries(from candidates: [DueSoonNotificationCandidate]) -> [DueSoonNotificationEntry] {
        var entries: [DueSoonNotificationEntry] = []
        entries.reserveCapacity(candidates.count * dueSoonLeadTimes.count)

        for candidate in candidates {
            for leadTime in dueSoonLeadTimes {
                let fireDate = candidate.dueDate.addingTimeInterval(-leadTime)
                let dueStamp = Int(candidate.dueDate.timeIntervalSince1970)
                let token = "\(candidate.stableIdentity)_\(dueStamp)_\(Int(leadTime))"
                entries.append(
                    DueSoonNotificationEntry(
                        token: token,
                        candidate: candidate,
                        leadTime: leadTime,
                        fireDate: fireDate
                    )
                )
            }
        }
        return entries
    }

    private func collapseOverdueDueSoonEntries(
        _ entries: [DueSoonNotificationEntry]
    ) -> [DueSoonNotificationEntry] {
        var latestByOccurrence: [String: DueSoonNotificationEntry] = [:]
        latestByOccurrence.reserveCapacity(entries.count)

        for entry in entries {
            let dueStamp = Int(entry.candidate.dueDate.timeIntervalSince1970)
            let key = "\(entry.candidate.stableIdentity)_\(dueStamp)"

            if let existing = latestByOccurrence[key] {
                if entry.fireDate > existing.fireDate {
                    latestByOccurrence[key] = entry
                }
            } else {
                latestByOccurrence[key] = entry
            }
        }

        return latestByOccurrence.values.sorted { $0.fireDate < $1.fireDate }
    }

    private func dueSoonNotificationSubtitle(
        for candidate: DueSoonNotificationCandidate,
        leadTime: TimeInterval
    ) -> String {
        let isCalendarEvent = candidate.source == .calendar
        if leadTime >= 15 * 60 {
            return isCalendarEvent ? "Event starts in 15 minutes" : "Due in 15 minutes"
        }
        return isCalendarEvent ? "Event starts in 1 minute" : "Due in 1 minute"
    }

    private func dueSoonNotificationBody(for candidate: DueSoonNotificationCandidate) -> String {
        let dueStamp = candidate.dueDate.formatted(date: .abbreviated, time: .shortened)
        let sourceTitle = candidate.source == .calendar ? "Calendar" : "Task"
        if let listTitle = candidate.listTitle, !listTitle.isEmpty {
            return "\(sourceTitle) at \(dueStamp) • \(listTitle)"
        }
        return "\(sourceTitle) at \(dueStamp)"
    }

    private func clearDueSoonNotifications() {
        dueSoonNotificationRefreshWorkItem?.cancel()
        dueSoonNotificationRefreshWorkItem = nil
        dueSoonNotificationTimer?.invalidate()
        dueSoonNotificationTimer = nil
        dueSoonDeliveredTokens.removeAll()
    }

    private func hasExplicitDueTime(_ date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0 || (components.second ?? 0) != 0
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
        DispatchQueue.global(qos: .utility).async {
            Self.deleteExternalBackingSnapshot(item)
        }
        var deletedSnapshot = item
        if item.externalSource != nil {
            deletedSnapshot.externalSource = nil
            deletedSnapshot.externalIdentifier = nil
            deletedSnapshot.externalListIdentifier = nil
            deletedSnapshot.externalListTitle = nil
            deletedSnapshot.externalListColorHex = nil
            deletedSnapshot.externalMeetingURL = nil
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
        sortedItemsCache = nil
        scheduleDueSoonNotificationsRefresh()

        let snapshot = items
        persistenceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [url] in
            do {
                let directory = url.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                print("ToDoManager: Failed to save items: \(error)")
            }
        }
        persistenceWorkItem = workItem
        persistenceQueue.asyncAfter(deadline: .now() + 0.08, execute: workItem)
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
            sortedItemsCache = nil
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

    private func loadQuickOpenShortcut() {
        guard let data = UserDefaults.standard.data(forKey: quickOpenShortcutKey),
              let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) else {
            storedQuickOpenShortcut = nil
            return
        }
        storedQuickOpenShortcut = Self.sanitizedShortcut(decoded)
    }

    private func reloadQuickOpenShortcutMonitoring() {
        quickOpenHotKey = nil
        guard let shortcut = storedQuickOpenShortcut else { return }

        quickOpenHotKey = GlobalHotKey(
            keyCode: shortcut.keyCode,
            modifiers: shortcut.modifiers,
            enableIOHIDFallback: false
        ) { [weak self] in
            self?.handleQuickOpenShortcutTriggered()
        }
    }

    private func handleQuickOpenShortcutTriggered() {
        let todoInstalled = UserDefaults.standard.preference(
            AppPreferenceKey.todoInstalled,
            default: PreferenceDefault.todoInstalled
        )
        let shelfEnabled = UserDefaults.standard.preference(
            AppPreferenceKey.enableNotchShelf,
            default: PreferenceDefault.enableNotchShelf
        )
        let canOpenShelfTodo = todoInstalled && !ExtensionType.todo.isRemoved && shelfEnabled
        guard canOpenShelfTodo else {
            SettingsWindowController.shared.showSettings(openingExtension: .todo)
            return
        }

        let targetDisplayID = DroppyState.shared.expandedDisplayID
            ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })?.displayID
            ?? NSScreen.main?.displayID
        guard let targetDisplayID else {
            SettingsWindowController.shared.showSettings(openingExtension: .todo)
            return
        }

        withAnimation(DroppyAnimation.interactive) {
            DroppyState.shared.expandShelf(for: targetDisplayID)
        }

        NotificationCenter.default.post(
            name: .todoQuickOpenRequested,
            object: nil,
            userInfo: ["displayID": NSNumber(value: targetDisplayID)]
        )
    }

    private func saveSelectedReminderListIDs() {
        let payload = Array(selectedReminderListIDs).sorted()
        guard let data = try? JSONEncoder().encode(payload),
              let raw = String(data: data, encoding: .utf8) else {
            return
        }
        UserDefaults.standard.set(raw, forKey: remindersSelectedListsKey)
    }

    private func refreshCalendarLists() async {
        guard isCalendarSyncEnabled else {
            await MainActor.run {
                availableCalendarLists = []
            }
            return
        }

        let status = EKEventStore.authorizationStatus(for: .event)
        let hasAccess = status == .fullAccess || status == .writeOnly
        guard hasAccess else {
            await MainActor.run {
                availableCalendarLists = []
            }
            return
        }

        let readStore = EKEventStore()
        let options = readStore
            .calendars(for: .event)
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
            availableCalendarLists = options
            let availableIDs = Set(options.map(\.id))
            let hasStoredSelection = UserDefaults.standard.object(forKey: calendarSelectedListsKey) != nil
            if !hasStoredSelection {
                selectedCalendarListIDs = availableIDs
                saveSelectedCalendarListIDs()
            } else {
                let prunedSelection = selectedCalendarListIDs.intersection(availableIDs)
                if prunedSelection != selectedCalendarListIDs {
                    selectedCalendarListIDs = prunedSelection
                    saveSelectedCalendarListIDs()
                }
            }
        }
    }

    private func loadSelectedCalendarListIDs() {
        guard let raw = UserDefaults.standard.string(forKey: calendarSelectedListsKey),
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            selectedCalendarListIDs = []
            return
        }
        selectedCalendarListIDs = Set(decoded)
    }

    private func saveSelectedCalendarListIDs() {
        let payload = Array(selectedCalendarListIDs).sorted()
        guard let data = try? JSONEncoder().encode(payload),
              let raw = String(data: data, encoding: .utf8) else {
            return
        }
        UserDefaults.standard.set(raw, forKey: calendarSelectedListsKey)
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
        if let sortedItemsCache {
            return sortedItemsCache
        }

        let now = Date()
        let baseSorted = items.sorted {
            // Always put completed items at the bottom
            isItemOrderedBefore($0, $1, now: now)
        }
        let sorted = applyingReminderHierarchy(to: baseSorted)
        sortedItemsCache = sorted
        return sorted
    }

    func reminderHierarchyDepth(for item: ToDoItem) -> Int {
        if let reminderHierarchyDepthCache,
           let depth = reminderHierarchyDepthCache[item.id] {
            return depth
        }
        let computedDepths = computeReminderHierarchyDepthMap()
        reminderHierarchyDepthCache = computedDepths
        return computedDepths[item.id] ?? 0
    }

    var upcomingCalendarItems: [ToDoItem] {
        partitionedItems.upcomingCalendarItems
    }

    var overviewTaskItems: [ToDoItem] {
        partitionedItems.overviewTaskItems
    }
    
    var upcomingCalendarItemsAnimationSignature: Int {
        partitionedItems.upcomingCalendarItemsSignature
    }

    var overviewTaskItemsAnimationSignature: Int {
        partitionedItems.overviewTaskItemsSignature
    }

    var shelfTimelineItemCount: Int {
        let counts = activeTimelineCounts
        let taskItemsCount = counts.taskItems
        let calendarItemsCount = counts.calendarItems

        if isCalendarSyncEnabled {
            // Keep a combined shelf whenever there are visible task/reminder items.
            if taskItemsCount > 0 {
                return calendarItemsCount + taskItemsCount
            }
            return calendarItemsCount
        }
        return taskItemsCount
    }

    private var activeTimelineCounts: (taskItems: Int, calendarItems: Int) {
        if let activeTimelineCountsCache {
            return activeTimelineCountsCache
        }

        let sourceItems = sortedItems
        let remindersByExternalID = reminderItemsByExternalID(in: sourceItems)
        var taskItems = 0
        var calendarItems = 0
        for item in sourceItems where !item.isCompleted {
            if shouldHideUndatedReminder(item, remindersByExternalID: remindersByExternalID) {
                continue
            }
            if item.externalSource == .calendar {
                calendarItems += 1
            } else {
                taskItems += 1
            }
        }

        let counts = (taskItems: taskItems, calendarItems: calendarItems)
        activeTimelineCountsCache = counts
        return counts
    }
    
    private func rank(_ p: ToDoPriority) -> Int {
        switch p {
        case .high: return 3
        case .medium: return 2
        case .normal: return 1
        }
    }

    private func isItemOrderedBefore(_ lhs: ToDoItem, _ rhs: ToDoItem, now: Date) -> Bool {
        // Always put completed items at the bottom
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }

        // If both are completed, sort by completion date (newest first)
        if lhs.isCompleted {
            return (lhs.completedAt ?? now) > (rhs.completedAt ?? now)
        }

        // Exception: no-date + high priority always floats to the top.
        let lhsNoDateHigh = lhs.dueDate == nil && lhs.priority == .high
        let rhsNoDateHigh = rhs.dueDate == nil && rhs.priority == .high
        if lhsNoDateHigh != rhsNoDateHigh {
            return lhsNoDateHigh
        }

        // Then sort by due date: dated tasks first, earlier dates first.
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?):
            if left != right { return left < right }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        // Fallback to Priority (High -> Medium -> Normal).
        if lhs.priority != rhs.priority {
            return rank(lhs.priority) > rank(rhs.priority)
        }

        // Fallback to Date
        return lhs.createdAt > rhs.createdAt
    }

    private func applyingReminderHierarchy(to orderedItems: [ToDoItem]) -> [ToDoItem] {
        let reminderItems = orderedItems.filter { $0.externalSource == .reminders }
        guard !reminderItems.isEmpty else { return orderedItems }

        let remindersByExternalID = Dictionary(
            reminderItems.compactMap { item -> (String, ToDoItem)? in
                guard let externalID = item.externalIdentifier else { return nil }
                return (externalID, item)
            },
            uniquingKeysWith: { first, _ in first }
        )
        guard !remindersByExternalID.isEmpty else { return orderedItems }

        let baseIndexByItemID = Dictionary(
            uniqueKeysWithValues: orderedItems.enumerated().map { ($1.id, $0) }
        )
        var childrenByParentExternalID: [String: [ToDoItem]] = [:]
        for item in reminderItems {
            guard let parentExternalID = item.externalParentIdentifier,
                  let parent = remindersByExternalID[parentExternalID],
                  parent.isCompleted == item.isCompleted else { continue }
            childrenByParentExternalID[parentExternalID, default: []].append(item)
        }

        for parentExternalID in childrenByParentExternalID.keys {
            childrenByParentExternalID[parentExternalID]?.sort { lhs, rhs in
                (baseIndexByItemID[lhs.id] ?? .max) < (baseIndexByItemID[rhs.id] ?? .max)
            }
        }

        var flattened: [ToDoItem] = []
        flattened.reserveCapacity(orderedItems.count)
        var emittedItemIDs = Set<UUID>()

        func emit(_ item: ToDoItem) {
            guard emittedItemIDs.insert(item.id).inserted else { return }
            flattened.append(item)
            guard let externalID = item.externalIdentifier else { return }
            for child in childrenByParentExternalID[externalID] ?? [] {
                emit(child)
            }
        }

        for item in orderedItems {
            let parentExistsInSet = item.externalSource == .reminders &&
                item.externalParentIdentifier.flatMap { remindersByExternalID[$0] } != nil
            if parentExistsInSet {
                continue
            }
            emit(item)
        }

        if flattened.count != orderedItems.count {
            for item in orderedItems where !emittedItemIDs.contains(item.id) {
                emit(item)
            }
        }

        return flattened
    }

    private func computeReminderHierarchyDepthMap() -> [UUID: Int] {
        let remindersByExternalID = Dictionary(
            items.compactMap { item -> (String, ToDoItem)? in
                guard item.externalSource == .reminders,
                      let externalID = item.externalIdentifier else { return nil }
                return (externalID, item)
            },
            uniquingKeysWith: { first, _ in first }
        )
        guard !remindersByExternalID.isEmpty else { return [:] }

        var depthByItemID: [UUID: Int] = [:]
        depthByItemID.reserveCapacity(items.count)

        for item in items {
            guard item.externalSource == .reminders else {
                depthByItemID[item.id] = 0
                continue
            }
            guard let parentExternalID = item.externalParentIdentifier,
                  !parentExternalID.isEmpty else {
                depthByItemID[item.id] = 0
                continue
            }

            var depth = 0
            var currentParentExternalID: String? = parentExternalID
            var visited = Set<String>()
            while let parentID = currentParentExternalID,
                  let parent = remindersByExternalID[parentID],
                  visited.insert(parentID).inserted,
                  parent.isCompleted == item.isCompleted,
                  depth < 4 {
                depth += 1
                currentParentExternalID = parent.externalParentIdentifier
            }
            depthByItemID[item.id] = depth
        }

        return depthByItemID
    }

    private struct ItemPartitionCache {
        let upcomingCalendarItems: [ToDoItem]
        let overviewTaskItems: [ToDoItem]
        let upcomingCalendarItemsSignature: Int
        let overviewTaskItemsSignature: Int
    }

    private var partitionedItems: ItemPartitionCache {
        if let itemPartitionCache {
            return itemPartitionCache
        }

        let sourceItems = sortedItems
        let remindersByExternalID = reminderItemsByExternalID(in: sourceItems)
        var upcoming: [ToDoItem] = []
        var overview: [ToDoItem] = []
        upcoming.reserveCapacity(sourceItems.count)
        overview.reserveCapacity(sourceItems.count)

        for item in sourceItems {
            if shouldHideUndatedReminder(item, remindersByExternalID: remindersByExternalID) {
                continue
            }
            if item.externalSource == .calendar && !item.isCompleted {
                upcoming.append(item)
            } else {
                overview.append(item)
            }
        }

        let cache = ItemPartitionCache(
            upcomingCalendarItems: upcoming,
            overviewTaskItems: overview,
            upcomingCalendarItemsSignature: animationSignature(for: upcoming),
            overviewTaskItemsSignature: animationSignature(for: overview)
        )
        itemPartitionCache = cache
        return cache
    }

    private func animationSignature(for items: [ToDoItem]) -> Int {
        var hasher = Hasher()
        hasher.combine(items.count)
        for item in items {
            hasher.combine(item.id)
        }
        return hasher.finalize()
    }

    func reminderItemsByExternalID(in sourceItems: [ToDoItem]) -> [String: ToDoItem] {
        Dictionary(
            sourceItems.compactMap { item -> (String, ToDoItem)? in
                guard item.externalSource == .reminders,
                      let externalID = item.externalIdentifier else { return nil }
                return (externalID, item)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func effectiveDueDate(
        for item: ToDoItem,
        remindersByExternalID: [String: ToDoItem]
    ) -> Date? {
        if let dueDate = item.dueDate {
            return dueDate
        }
        guard item.externalSource == .reminders else { return nil }

        var currentParentExternalID = item.externalParentIdentifier
        var visited = Set<String>()
        while let parentExternalID = currentParentExternalID,
              !parentExternalID.isEmpty,
              visited.insert(parentExternalID).inserted,
              let parent = remindersByExternalID[parentExternalID],
              parent.isCompleted == item.isCompleted {
            if let parentDueDate = parent.dueDate {
                return parentDueDate
            }
            currentParentExternalID = parent.externalParentIdentifier
        }
        return nil
    }

    private func shouldHideUndatedReminder(
        _ item: ToDoItem,
        remindersByExternalID: [String: ToDoItem]
    ) -> Bool {
        guard isHideUndatedRemindersEnabled,
              item.externalSource == .reminders else {
            return false
        }
        return effectiveDueDate(for: item, remindersByExternalID: remindersByExternalID) == nil
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

    private static func deleteExternalBackingSnapshot(_ item: ToDoItem) {
        guard let source = item.externalSource, let identifier = item.externalIdentifier else { return }
        guard source == .reminders else { return }

        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .fullAccess || status == .writeOnly else { return }
        let store = EKEventStore()
        guard let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        do {
            try store.remove(reminder, commit: true)
        } catch {
            print("ToDoManager: Failed to delete reminder for removed task: \(error)")
        }
    }

    private func moveExternalReminderToList(reminderIdentifier: String, reminderListID: String?) {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .fullAccess || status == .writeOnly else { return }
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
            let granted = await requestRemindersAccess(source: .userInteraction)
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
                if let configuredDefaultID = defaultReminderListID,
                   let configuredDefault = calendars.first(where: { $0.calendarIdentifier == configuredDefaultID }) {
                    return configuredDefault
                }
                if let selectedDefault = calendars.first(where: {
                    selectedReminderListIDs.contains($0.calendarIdentifier)
                }) {
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
                    items[index].externalParentIdentifier = nil
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

    private enum ReminderParentReference {
        case string(String)
        case object(Any)
    }

    private nonisolated static let reminderParentReferenceKeys = [
        // Some system builds expose this identifier directly.
        "parentCalendarItemIdentifier",
        // On current macOS SDKs this is typically EKObjectID-backed.
        "parentID"
    ]

    private nonisolated static func reminderParentReference(for reminder: EKReminder) -> ReminderParentReference? {
        for key in reminderParentReferenceKeys {
            guard let rawValue = valueIfResponds(reminder, key: key) else { continue }
            if let normalized = normalizedIdentifierString(rawValue) {
                return normalized == "0" ? nil : .string(normalized)
            }
            if !identifierAliases(from: rawValue).isEmpty {
                return .object(rawValue)
            }
        }
        return nil
    }

    private nonisolated static func reminderIdentifierAliases(for reminder: EKReminder) -> Set<String> {
        var aliases: Set<String> = []
        aliases.formUnion(identifierAliases(from: reminder.calendarItemIdentifier))
        aliases.formUnion(identifierAliases(from: reminder.calendarItemExternalIdentifier))
        aliases.formUnion(identifierAliases(from: valueIfResponds(reminder, key: "UUID")))
        aliases.formUnion(identifierAliases(from: valueIfResponds(reminder, key: "reminderIdentifier")))
        return aliases
    }

    private nonisolated static func reminderObjectIdentifierAliases(for reminder: EKReminder) -> Set<String> {
        // Keep this intentionally narrow. Probing CADObjectID can assert inside EventKit.
        let candidateKeys = ["objectID"]
        var aliases: Set<String> = []
        aliases.reserveCapacity(candidateKeys.count)

        for key in candidateKeys {
            guard let rawValue = valueIfResponds(reminder, key: key) else {
                continue
            }
            aliases.formUnion(identifierAliases(from: rawValue))
        }
        return aliases
    }

    private nonisolated static func valueIfResponds(_ object: NSObject, key: String) -> Any? {
        let selector = NSSelectorFromString(key)
        guard object.responds(to: selector) else { return nil }
        // `perform(_:)` is only safe for object returns. Ignore scalar-return selectors.
        guard selectorReturnsObject(type(of: object), selector: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue()
    }

    private nonisolated static func selectorReturnsObject(_ cls: AnyClass, selector: Selector) -> Bool {
        guard let method = class_getInstanceMethod(cls, selector) else {
            return false
        }
        let returnTypePointer = method_copyReturnType(method)
        defer { free(returnTypePointer) }
        let returnType = String(cString: returnTypePointer)
        return returnType.hasPrefix("@")
    }

    private nonisolated static func normalizedIdentifierString(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let rawString = value as? String {
            let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed.lowercased()
        }
        if let rawString = value as? NSString {
            let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed.lowercased()
        }
        if let url = value as? URL {
            let absolute = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
            return absolute.isEmpty ? nil : absolute.lowercased()
        }
        if let url = value as? NSURL {
            let absolute = (url.absoluteString ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return absolute.isEmpty ? nil : absolute.lowercased()
        }
        if let uuid = value as? UUID {
            return uuid.uuidString.lowercased()
        }
        if let uuid = value as? NSUUID {
            return uuid.uuidString.lowercased()
        }
        if let number = value as? NSNumber {
            let numeric = number.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return numeric.isEmpty ? nil : numeric
        }
        return nil
    }

    private nonisolated static func identifierAliases(
        from value: Any?,
        depth: Int = 1
    ) -> Set<String> {
        guard let value else { return [] }

        var aliases: Set<String> = []
        if let normalized = normalizedIdentifierString(value) {
            aliases.formUnion(expandedIdentifierAliases(from: normalized))
        }

        guard depth > 0, let object = value as? NSObject else {
            return aliases
        }

        // Keep this strict: probing some private selectors (e.g. CADObjectID)
        // can trigger assertions inside EventKit on the main thread.
        let className = NSStringFromClass(type(of: object))
        let selectorKeys: [String]
        if className.contains("EKObjectID") || className.contains("CADObjectID") {
            selectorKeys = ["stringRepresentation", "URIRepresentation"]
        } else {
            selectorKeys = []
        }

        for key in selectorKeys {
            guard let nested = valueIfResponds(object, key: key) else { continue }
            aliases.formUnion(identifierAliases(from: nested, depth: depth - 1))
        }
        return aliases
    }

    private nonisolated static func expandedIdentifierAliases(from rawAlias: String) -> Set<String> {
        let alias = rawAlias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !alias.isEmpty else { return [] }

        var aliases: Set<String> = [alias]
        if alias.hasPrefix("x-apple-reminder://") {
            let stripped = String(alias.dropFirst("x-apple-reminder://".count))
            if !stripped.isEmpty {
                aliases.insert(stripped)
            }
        }
        if let lastPath = alias.split(separator: "/").last, !lastPath.isEmpty {
            aliases.insert(String(lastPath))
        }
        return aliases
    }

    private nonisolated static let shortcutAllowedModifierMask: UInt =
        (UInt(1) << 17) | // command
        (UInt(1) << 18) | // shift
        (UInt(1) << 19) | // option
        (UInt(1) << 20)   // control

    private nonisolated static func sanitizedShortcut(_ shortcut: SavedShortcut) -> SavedShortcut {
        SavedShortcut(
            keyCode: shortcut.keyCode,
            modifiers: shortcut.modifiers & shortcutAllowedModifierMask
        )
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

    private nonisolated static let meetingLinkDetector: NSDataDetector? =
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    private static func calendarMeetingURL(for event: EKEvent) -> String? {
        var candidates: [URL] = []
        if let eventURL = event.url {
            candidates.append(resolvedMeetingCandidate(from: eventURL))
        }
        if let location = event.location {
            candidates.append(contentsOf: detectedMeetingLinks(in: location))
        }
        if let notes = event.notes {
            candidates.append(contentsOf: detectedMeetingLinks(in: notes))
        }

        var deduped: [URL] = []
        var seen: Set<String> = []
        for candidate in candidates where isSupportedMeetingURL(candidate) {
            let key = candidate.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            guard seen.insert(key).inserted else { continue }
            deduped.append(candidate)
        }

        if let teamsURL = deduped.first(where: { isTeamsMeetingURL($0) }) {
            return teamsURL.absoluteString
        }
        if let fallback = deduped.first {
            return fallback.absoluteString
        }
        return nil
    }

    private nonisolated static func detectedMeetingLinks(in text: String) -> [URL] {
        guard let detector = meetingLinkDetector else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, options: [], range: range).compactMap {
            guard let detected = $0.url else { return nil }
            return resolvedMeetingCandidate(from: detected)
        }
    }

    private nonisolated static func resolvedMeetingCandidate(from url: URL) -> URL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return url
        }
        let redirectKeys = Set(["url", "u", "redirect", "target"])
        for item in queryItems {
            let key = item.name.lowercased()
            guard redirectKeys.contains(key),
                  let rawValue = item.value else {
                continue
            }
            let decoded = rawValue.removingPercentEncoding ?? rawValue
            guard let nested = URL(string: decoded),
                  isSupportedMeetingURL(nested) else {
                continue
            }
            return nested
        }
        return url
    }

    private nonisolated static func isSupportedMeetingURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "http" || scheme == "msteams"
    }

    private nonisolated static func isTeamsMeetingURL(_ url: URL) -> Bool {
        let absolute = url.absoluteString.lowercased()
        if absolute.contains("teams.microsoft.com/l/meetup-join") ||
            absolute.contains("teams.microsoft.com%2fl%2fmeetup-join") ||
            absolute.contains("msteams://") {
            return true
        }
        guard let host = url.host?.lowercased() else { return false }
        return host == "teams.microsoft.com" ||
            host.hasSuffix(".teams.microsoft.com") ||
            host == "teams.live.com" ||
            host.hasSuffix(".teams.live.com") ||
            host == "teams.office.com" ||
            host.hasSuffix(".teams.office.com") ||
            host == "gov.teams.microsoft.us" ||
            host == "dod.teams.microsoft.us" ||
            (host == "aka.ms" && absolute.contains("meetup-join"))
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
