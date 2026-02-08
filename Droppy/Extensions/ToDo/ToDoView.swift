//
//  ToDoView.swift
//  Droppy
//
//  Main UI for To-do Extension
//

import SwiftUI


struct ToDoView: View {
    @State private var manager = ToDoManager.shared
    @FocusState private var isInputFocused: Bool
    @State private var showingNewDueDatePicker = false
    @State private var activeListMentionQuery: String?
    @State private var showingMentionPicker = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header: Input (Capsule Style)
            HStack(spacing: 10) {
                // Back to Shelf
                Button(action: {
                    withAnimation {
                        manager.isVisible = false
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(AdaptiveColors.overlayAuto(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Back to Shelf")
                
                // Priority Toggle (Glowing Dot)
                Button {
                    HapticFeedback.medium.perform()
                    withAnimation {
                         switch manager.newItemPriority {
                         case .normal: manager.newItemPriority = .high
                         case .high: manager.newItemPriority = .medium
                         case .medium: manager.newItemPriority = .normal
                         }
                    }
                } label: {
                    ZStack {
                        Color.clear.frame(width: 30, height: 30)
                        
                        Circle()
                            .fill(manager.newItemPriority.color)
                            .frame(width: 10, height: 10)
                            .shadow(color: manager.newItemPriority.color.opacity(0.8), radius: 6, x: 0, y: 0)
                            .overlay(
                                Circle().stroke(AdaptiveColors.overlayAuto(0.2), lineWidth: 1)
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "action.set_priority"))
                .accessibilityValue(manager.newItemPriority.rawValue)
                .accessibilityHint("Cycles through high, medium, and normal priority")

                // Text Input
                ToDoStableTextField(
                    text: Binding(
                        get: { manager.newItemText },
                        set: { manager.newItemText = $0 }
                    ),
                    placeholder: String(localized: "add_task_placeholder"),
                    onSubmit: submitTask,
                    onEditingChanged: { editing in
                        manager.isEditingText = editing
                        isInputFocused = editing
                    },
                    highlightSpansProvider: { text in
                        let dateSpans = ToDoInputIntelligence.detectedDateRanges(in: text).map {
                            ToDoTextHighlightSpan(range: $0, style: .detectedDate)
                        }
                        let tokenSpans = ToDoInputIntelligence.listMentionTokenRanges(in: text).map {
                            ToDoTextHighlightSpan(range: $0, style: .listMentionToken)
                        }
                        return dateSpans + tokenSpans
                    }
                )
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .droppyTextInputChrome(horizontalPadding: 10, verticalPadding: 6)
                .popover(isPresented: $showingMentionPicker, arrowEdge: .bottom) {
                    ToDoReminderListMentionTooltip(
                        options: mentionOptions,
                        selectedID: manager.newItemReminderListID,
                        onSelect: applyMentionSelection
                    )
                }
                .onChange(of: manager.newItemText) { _, newValue in
                    refreshListMentionState(for: newValue)
                }

                ToDoDueDateCircleButtonView(hasDueDate: manager.newItemDueDate != nil) {
                    showingNewDueDatePicker.toggle()
                }
                .help(manager.newItemDueDate == nil ? "Set due date" : "Edit due date")
                .popover(isPresented: $showingNewDueDatePicker) {
                    ToDoDueDatePopoverContentView(
                        dueDate: Bindable(manager).newItemDueDate,
                        primaryButtonTitle: "Done",
                        onPrimary: { showingNewDueDatePicker = false },
                        setInteractingPopover: { manager.isInteractingWithPopover = $0 }
                    )
                }
                
                // Submit Button
                Button(action: submitTask) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .disabled(manager.newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel(String(localized: "action.add_task"))
            }

            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 42)
            .background(
                Capsule()
                    .fill(AdaptiveColors.buttonBackgroundAuto.opacity(0.95))
            )
            .overlay(
                Capsule()
                    .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
            )
            .padding(.horizontal, 12)
            // Removed negative top padding causing clipping

            // List
            if manager.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("no_tasks_yet")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Text("type_above_hint")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        if !overviewTaskItems.isEmpty {
                            ForEach(Array(overviewTaskItems.enumerated()), id: \.element.id) { index, item in
                                ToDoRow(
                                    item: item,
                                    manager: manager,
                                    reminderListOptions: reminderListMenuOptions
                                )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .scale(scale: 0.98).combined(with: .opacity)
                                    ))

                                if index < overviewTaskItems.count - 1 {
                                    Divider()
                                        .background(AdaptiveColors.overlayAuto(0.06))
                                        .padding(.horizontal, 24)
                                }
                            }
                        }

                        if !upcomingCalendarItems.isEmpty {
                            if !overviewTaskItems.isEmpty {
                                Divider()
                                    .background(AdaptiveColors.overlayAuto(0.08))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 4)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Upcoming Events")
                                    .font(.system(size: 11, weight: .semibold))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(AdaptiveColors.secondaryTextAuto.opacity(0.85))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 4)

                            ForEach(Array(upcomingCalendarItems.enumerated()), id: \.element.id) { index, item in
                                ToDoRow(
                                    item: item,
                                    manager: manager,
                                    reminderListOptions: reminderListMenuOptions
                                )
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .scale(scale: 0.98).combined(with: .opacity)
                                    ))

                                if index < upcomingCalendarItems.count - 1 {
                                    Divider()
                                        .background(AdaptiveColors.overlayAuto(0.06))
                                        .padding(.horizontal, 24)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    // Extra padding at bottom to prevent clipping by the undo toast or just general breathing room
                    .padding(.bottom, 20)
                }
            }
        }
        .padding(.top, 42) // Increased safe area padding to prevent clipping
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if manager.showUndoToast {
                ToDoUndoToast(
                    onUndo: {
                        manager.restoreLastDeletedItem()
                    },
                    onDismiss: {
                        withAnimation {
                            manager.showUndoToast = false
                        }
                    }
                )
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if manager.showCleanupToast {
                ToDoCleanupToast(count: manager.cleanupCount) {
                    withAnimation(.smooth(duration: 0.25)) {
                        manager.showCleanupToast = false
                    }
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.showUndoToast)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.showCleanupToast)
        .onChange(of: isInputFocused) { _, focused in
            manager.isEditingText = focused
        }
        .onChange(of: showingNewDueDatePicker) { _, showing in
            manager.isInteractingWithPopover = showing
        }
        .onChange(of: showingMentionPicker) { _, showing in
            manager.isInteractingWithPopover = showing
        }
        .onChange(of: manager.availableReminderLists) { _, _ in
            showingMentionPicker = shouldShowMentionTooltip
        }
        .onAppear {
            manager.isVisible = true
            isInputFocused = true
            if manager.isRemindersSyncEnabled || manager.isCalendarSyncEnabled {
                manager.syncExternalSourcesNow()
            }
            if manager.isRemindersSyncEnabled {
                manager.refreshReminderListsNow()
            }
        }
        .onDisappear {
            manager.isVisible = false
            manager.isEditingText = false
            manager.isInteractingWithPopover = false
        }
    }
    
    private func submitTask() {
        let parsed = ToDoInputIntelligence.parseTaskDraft(manager.newItemText)
        let title = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let resolvedDueDate = parsed.dueDate ?? manager.newItemDueDate
        let resolvedReminderListID = resolveReminderListID(from: parsed.reminderListQuery)

        HapticFeedback.drop()
        manager.addItem(
            title: title,
            priority: manager.newItemPriority,
            dueDate: resolvedDueDate,
            reminderListID: resolvedReminderListID
        )
        activeListMentionQuery = nil
        showingMentionPicker = false
        // Keep focus
        isInputFocused = true
    }

    private var mentionOptions: [ToDoReminderListOption] {
        guard manager.isRemindersSyncEnabled, let query = activeListMentionQuery else { return [] }
        return manager.reminderLists(matching: query)
    }

    private var shouldShowMentionTooltip: Bool {
        !mentionOptions.isEmpty
    }

    private func refreshListMentionState(for text: String) {
        activeListMentionQuery = ToDoInputIntelligence.activeListMentionQuery(in: text)
        if let tokenQuery = ToDoInputIntelligence.lastListMentionTokenQuery(in: text),
           let tokenListID = manager.resolveReminderList(matching: tokenQuery)?.id {
            manager.newItemReminderListID = tokenListID
        } else if !text.contains("@") {
            manager.newItemReminderListID = nil
        }
        guard manager.isRemindersSyncEnabled, activeListMentionQuery != nil else {
            showingMentionPicker = false
            return
        }
        if manager.availableReminderLists.isEmpty {
            manager.refreshReminderListsNow()
        }
        showingMentionPicker = shouldShowMentionTooltip
    }

    private func applyMentionSelection(_ option: ToDoReminderListOption) {
        manager.newItemReminderListID = option.id
        manager.newItemText = ToDoInputIntelligence.applyListMentionToken(option.title, to: manager.newItemText)
        activeListMentionQuery = nil
        showingMentionPicker = false
    }

    private func resolveReminderListID(from parsedQuery: String?) -> String? {
        if let explicit = manager.newItemReminderListID {
            return explicit
        }
        guard let parsedQuery else { return nil }
        return manager.resolveReminderList(matching: parsedQuery)?.id
    }

    private var reminderListMenuOptions: [ToDoReminderListOption] {
        guard manager.isRemindersSyncEnabled else { return [] }
        return manager.availableReminderLists
    }

    private var overviewTaskItems: [ToDoItem] {
        manager.overviewTaskItems
    }

    private var upcomingCalendarItems: [ToDoItem] {
        manager.upcomingCalendarItems
    }
}

private struct ToDoDueDateCircleButtonView: View {
    var hasDueDate: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "clock")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(hasDueDate ? Color.blue : AdaptiveColors.overlayAuto(0.65))
                .frame(width: 28, height: 28, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ToDoDueDatePopoverContentView: View {
    @Binding var dueDate: Date?
    var primaryButtonTitle: String? = "Done"
    var onPrimary: (() -> Void)? = nil
    var isEmbedded: Bool = false
    var setInteractingPopover: ((Bool) -> Void)? = nil
    @State private var manualTimeText: String = ""
    @State private var isEditingTimeText = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Due date")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AdaptiveColors.secondaryTextAuto)

            HStack(spacing: 8) {
                quickPresetButton("Today") { setPreset(daysFromToday: 0) }
                quickPresetButton("Tomorrow") { setPreset(daysFromToday: 1) }
                quickPresetButton("+1 Week") { setPreset(daysFromToday: 7) }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                stepButton("chevron.left") { shiftDays(-1) }
                Text(resolvedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.primaryTextAuto)
                    .lineLimit(1)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)
                stepButton("chevron.right") { shiftDays(1) }
            }
            .padding(.horizontal, 6)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AdaptiveColors.buttonBackgroundAuto.opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1)
            )

            HStack(spacing: 8) {
                stepButton("minus") { shiftMinutes(-15) }
                TextField("HH:mm", text: $manualTimeText, onEditingChanged: { editing in
                    isEditingTimeText = editing
                    if editing && manualTimeText.isEmpty {
                        manualTimeText = formatTime(resolvedDate)
                    }
                    if !editing {
                        applyTypedTime()
                    }
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .monospacedDigit()
                .foregroundStyle(AdaptiveColors.primaryTextAuto)
                .frame(maxWidth: .infinity, alignment: .center)
                .onSubmit {
                    applyTypedTime()
                }
                stepButton("plus") { shiftMinutes(15) }
                Button {
                    dueDate = nil
                } label: {
                    ZStack {
                        Circle()
                            .fill(AdaptiveColors.buttonBackgroundAuto.opacity(0.95))
                            .overlay(
                                Circle().stroke(AdaptiveColors.overlayAuto(0.16), lineWidth: 1)
                            )
                            .frame(width: 22, height: 22)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                    }
                }
                .buttonStyle(.plain)
                .disabled(dueDate == nil)
                .opacity(dueDate == nil ? 0.45 : 1.0)
                .help("Clear due date")
                .accessibilityLabel("Clear due date")
            }
            .padding(.horizontal, 6)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AdaptiveColors.buttonBackgroundAuto.opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1)
            )

            HStack(spacing: 10) {
                Spacer(minLength: 0)
                if let primaryButtonTitle {
                    Button(primaryButtonTitle) {
                        onPrimary?()
                    }
                    .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                }
            }
        }
        .padding(isEmbedded ? 0 : 14)
        .frame(width: isEmbedded ? nil : 260)
        .background {
            if !isEmbedded {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AdaptiveColors.panelBackgroundAuto)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AdaptiveColors.subtleBorderAuto.opacity(0.9), lineWidth: 1)
                    )
            }
        }
        .onAppear {
            manualTimeText = formatTime(resolvedDate)
            setInteractingPopover?(true)
        }
        .onChange(of: dueDate) { _, newValue in
            guard !isEditingTimeText else { return }
            manualTimeText = formatTime(newValue ?? Date())
        }
        .onDisappear {
            setInteractingPopover?(false)
        }
    }

    private var resolvedDate: Date {
        dueDate ?? Date()
    }

    private func quickPresetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AdaptiveColors.primaryTextAuto)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .background(
                    Capsule()
                        .fill(AdaptiveColors.hoverBackgroundAuto.opacity(0.78))
                )
                .overlay(
                    Capsule()
                        .stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func stepButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(AdaptiveColors.hoverBackgroundAuto.opacity(0.7))
                )
        }
        .buttonStyle(.plain)
    }

    private func setPreset(daysFromToday: Int) {
        let calendar = Calendar.current
        let now = Date()
        let targetDay = calendar.date(byAdding: .day, value: daysFromToday, to: now) ?? now
        let timeSource = dueDate ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeSource)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        let updated = calendar.date(from: components) ?? targetDay
        dueDate = updated
        manualTimeText = formatTime(updated)
    }

    private func shiftDays(_ value: Int) {
        let base = dueDate ?? Date()
        let updated = Calendar.current.date(byAdding: .day, value: value, to: base) ?? base
        dueDate = updated
        manualTimeText = formatTime(updated)
    }

    private func shiftMinutes(_ value: Int) {
        let base = dueDate ?? Date()
        let updated = Calendar.current.date(byAdding: .minute, value: value, to: base) ?? base
        dueDate = updated
        manualTimeText = formatTime(updated)
    }

    private func applyTypedTime() {
        let trimmed = manualTimeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            manualTimeText = formatTime(resolvedDate)
            return
        }
        guard let (hour, minute) = parseTime(trimmed) else {
            manualTimeText = formatTime(resolvedDate)
            return
        }

        let base = dueDate ?? Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: base)
        components.hour = hour
        components.minute = minute
        if let updated = Calendar.current.date(from: components) {
            dueDate = updated
            manualTimeText = formatTime(updated)
        } else {
            manualTimeText = formatTime(base)
        }
    }

    private func parseTime(_ input: String) -> (Int, Int)? {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: ":")
            .uppercased()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

        for format in ["HH:mm", "H:mm", "HHmm", "Hmm", "H", "h:mm a", "h:mma", "ha"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: normalized) {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                if let hour = comps.hour, let minute = comps.minute {
                    return (hour, minute)
                }
            }
        }
        return nil
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct ToDoRow: View {
    let item: ToDoItem
    let manager: ToDoManager
    let reminderListOptions: [ToDoReminderListOption]
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editText = ""
    @State private var editDueDate: Date?

    var body: some View {
        HStack(spacing: DroppySpacing.smd) {
            if isCalendarEvent {
                ZStack {
                    Circle()
                        .fill(calendarEventTint.opacity(0.2))
                        .frame(width: 18, height: 18)
                    Image(systemName: "calendar")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(calendarEventTint.opacity(0.95))
                }
                .frame(width: 24, height: 24)
                .help("Calendar event")
            } else {
                // Checkbox
                Button(action: {
                    HapticFeedback.medium.perform()
                    manager.toggleCompletion(for: item)
                }) {
                    ZStack {
                        // Hit area
                        Color.clear.frame(width: 24, height: 24)

                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isCompleted ? Color(nsColor: NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.6, alpha: 1.0)) : (item.priority == .normal ? .secondary : item.priority.color))
                            .font(.system(size: 16))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isCompleted ? String(localized: "action.mark_incomplete") : String(localized: "action.mark_complete"))
                .accessibilityHint("Toggles completion for \(item.title)")
            }
            // Title - color based on priority
            Text(item.title)
                .font(.system(size: 13, weight: isCalendarEvent ? .semibold : (item.isCompleted ? .regular : .medium)))
                .strikethrough(item.isCompleted)
                .foregroundColor(
                    item.isCompleted
                        ? .secondary
                        : (isCalendarEvent ? calendarEventTint : (item.priority == .normal ? .primary : item.priority.color))
                )
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Stats / Controls
            HStack(spacing: 8) {
                if item.externalSource != nil {
                    HStack(spacing: 4) {
                        if isCalendarEvent {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(calendarEventTint.opacity(0.95))
                                .help(externalIconHelp)
                        } else {
                            Image(systemName: "applelogo")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.secondaryTextAuto.opacity(0.85))
                                .help(externalIconHelp)
                        }
                        if let reminderListColor {
                            Image(systemName: "list.bullet.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(reminderListColor.opacity(0.9))
                                .help(reminderListHelp)
                        }
                    }
                }

                if let dueDate = item.dueDate, !item.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: isCalendarEvent ? "clock" : "calendar")
                        if dueDateHasTime(dueDate) && !isCalendarEvent {
                            Image(systemName: "bell.fill")
                        }
                        Text(formattedDueDateText(dueDate))
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        isCalendarEvent
                            ? calendarEventTint.opacity(0.92)
                            : AdaptiveColors.secondaryTextAuto.opacity(0.92)
                    )
                }

                // Priority Indicator (only if not normal or completed)
                if item.priority != .normal && !item.isCompleted && !isCalendarEvent {
                    Image(systemName: item.priority.icon)
                        .foregroundColor(item.priority.color)
                        .font(.caption)
                }

                if !isCalendarEvent {
                    Button(action: {
                        HapticFeedback.delete()
                        manager.removeItem(item)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(isHovering ? .red.opacity(0.8) : .secondary.opacity(0.3))
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering ? 1.0 : 0.0) // Keep layout space, fade in
                    .animation(.easeInOut(duration: 0.2), value: isHovering)
                    .accessibilityLabel(String(localized: "action.delete_task"))
                }
            }
        }
        .padding(.horizontal, DroppySpacing.md)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isCalendarEvent
                        ? calendarEventTint.opacity(isHovering ? 0.14 : 0.08)
                        : (isHovering ? AdaptiveColors.overlayAuto(0.08) : Color.clear)
                )
        )
        .padding(.horizontal, DroppySpacing.sm)
        // Removed vertical padding of 2
        .onHover { hovering in
            if hovering { HapticFeedback.hover() }
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $isEditing) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "action.edit"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                
                TextField(String(localized: "task_title"), text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AdaptiveColors.primaryTextAuto)
                    .droppyTextInputChrome(
                        backgroundOpacity: 1.0,
                        borderOpacity: 1.0,
                        useAdaptiveColors: true
                    )
                    .onSubmit {
                        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        manager.updateTitle(for: item, to: trimmed)
                        manager.updateDueDate(for: item, to: editDueDate)
                        isEditing = false
                    }

                ToDoDueDatePopoverContentView(
                    dueDate: $editDueDate,
                    primaryButtonTitle: nil,
                    onPrimary: nil,
                    isEmbedded: true,
                    setInteractingPopover: { manager.isInteractingWithPopover = $0 }
                )
                
                HStack(spacing: 10) {
                    Button {
                        isEditing = false
                    } label: {
                        Text(String(localized: "action.cancel"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))
                    
                    Button {
                        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        manager.updateTitle(for: item, to: trimmed)
                        manager.updateDueDate(for: item, to: editDueDate)
                        isEditing = false
                    } label: {
                        Text(String(localized: "action.save"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                    .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(14)
            .frame(width: 260)
        }
        .onChange(of: isEditing) { _, presented in
            manager.isInteractingWithPopover = presented
        }
        .onDisappear {
            manager.isInteractingWithPopover = false
        }
        .contextMenu {
            if isCalendarEvent {
                Label("Calendar events are read-only", systemImage: "calendar.badge.clock")
                if let listTitle = item.externalListTitle, !listTitle.isEmpty {
                    Label(listTitle, systemImage: "calendar")
                }
            } else {
                Button {
                    editText = item.title
                    editDueDate = item.dueDate
                    isEditing = true
                } label: {
                    Label(String(localized: "action.edit"), systemImage: "pencil")
                }
                .keyboardShortcut("e", modifiers: [.command])
                Divider()

                // Priority changing
                Button {
                    HapticFeedback.medium.perform()
                    manager.updatePriority(for: item, to: .high)
                } label: {
                    Label(String(localized: "priority.high"), systemImage: "exclamationmark.circle.fill")
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button {
                    HapticFeedback.medium.perform()
                    manager.updatePriority(for: item, to: .medium)
                } label: {
                    Label(String(localized: "priority.medium"), systemImage: "exclamationmark.circle")
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button {
                    HapticFeedback.medium.perform()
                    manager.updatePriority(for: item, to: .normal)
                } label: {
                    Label(String(localized: "priority.normal"), systemImage: "circle")
                }
                .keyboardShortcut("3", modifiers: [.command])

                if !reminderListOptions.isEmpty {
                    Divider()
                    Menu {
                        ForEach(reminderListOptions) { list in
                            Button {
                                HapticFeedback.medium.perform()
                                manager.updateReminderList(for: item, to: list.id)
                            } label: {
                                Label(
                                    list.title,
                                    systemImage: item.externalListIdentifier == list.id ? "checkmark.circle.fill" : "circle"
                                )
                            }
                        }

                        Divider()
                        Button {
                            HapticFeedback.medium.perform()
                            manager.updateReminderList(for: item, to: nil)
                        } label: {
                            Label(
                                "Default List",
                                systemImage: item.externalListIdentifier == nil ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    } label: {
                        Label("Reminder List", systemImage: "list.bullet.rectangle")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    HapticFeedback.delete()
                    manager.removeItem(item)
                } label: {
                    Label(String(localized: "action.delete"), systemImage: "trash")
                }
            }
        }
    }

    private var externalIconHelp: String {
        switch item.externalSource {
        case .calendar:
            return "Synced from Apple Calendar"
        case .reminders:
            return "Synced from Apple Reminders"
        case .none:
            return ""
        }
    }

    private var reminderListColor: Color? {
        guard !isCalendarEvent else { return nil }
        return colorFromHex(item.externalListColorHex)
    }

    private var reminderListHelp: String {
        if let title = item.externalListTitle, !title.isEmpty {
            return "Apple Reminders list: \(title)"
        }
        return "Apple Reminders list"
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

    private func dueDateHasTime(_ date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
    }

    private func formattedDueDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        if dueDateHasTime(date) {
            formatter.setLocalizedDateFormatFromTemplate("d MMM HH:mm")
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        }
        return formatter.string(from: date)
    }

    private var isCalendarEvent: Bool {
        item.externalSource == .calendar
    }

    private var calendarEventTint: Color {
        colorFromHex(item.externalListColorHex) ?? Color.blue
    }
}
