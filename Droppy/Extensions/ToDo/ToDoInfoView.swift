//
//  ToDoInfoView.swift
//  Droppy
//
//  Settings and installation view for Todo extension
//

import SwiftUI

struct ToDoInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground

    @AppStorage(AppPreferenceKey.todoInstalled) private var isInstalled = PreferenceDefault.todoInstalled
    @AppStorage(AppPreferenceKey.todoAutoCleanupHours) private var autoCleanupHours = PreferenceDefault.todoAutoCleanupHours
    @AppStorage(AppPreferenceKey.todoSyncCalendarEnabled) private var syncCalendarEnabled = PreferenceDefault.todoSyncCalendarEnabled
    @AppStorage(AppPreferenceKey.todoSyncRemindersEnabled) private var syncRemindersEnabled = PreferenceDefault.todoSyncRemindersEnabled
    @AppStorage(AppPreferenceKey.todoShelfSplitViewEnabled) private var shelfSplitViewEnabled = PreferenceDefault.todoShelfSplitViewEnabled
    @AppStorage(AppPreferenceKey.todoShowTaskWeekNumber) private var showTaskWeekNumber = PreferenceDefault.todoShowTaskWeekNumber
    @AppStorage(AppPreferenceKey.todoShowTaskViewTimezone) private var showTaskViewTimezone = PreferenceDefault.todoShowTaskViewTimezone
    @State private var manager = ToDoManager.shared
    @State private var showReviewsSheet = false
    @State private var focusedCalendarIndex: Int? = nil
    @State private var focusedListIndex: Int? = nil

    // Stats passed from parent
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed)
            headerSection

            Divider()
                .padding(.horizontal, 24)

            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Features & Preview
                    featuresSection

                    // Settings
                    settingsSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)

            Divider()
                .padding(.horizontal, 24)

            // Footer (fixed)
            footerSection
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .todo)
        }
        .onAppear {
            if syncCalendarEnabled {
                manager.refreshCalendarListsNow()
                manager.syncExternalSourcesNow()
            }
            if syncRemindersEnabled {
                manager.refreshReminderListsNow()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            if let iconURL = ToDoExtension.iconURL {
                CachedAsyncImage(url: iconURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "checklist")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 64, height: 64)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
            } else {
                Image(systemName: "checklist")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 64, height: 64)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                    .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
            }

            Text("Reminders")
                .font(.title2.bold())

            // Stats Row
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)

                Button {
                    showReviewsSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption.weight(.medium))
                            Text("(\(r.ratingCount))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("–")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(DroppySelectableButtonStyle(isSelected: false))

                // Category Badge
                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.15)))
            }

            Text("Natural-language tasks, lists, and dates")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Community Extension Badge
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                Text("Community Extension")
                    .font(.caption.weight(.medium))
                Text("by")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Link("Valetivivek", destination: URL(string: "https://github.com/valetivivek")!)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.purple.opacity(0.12)))
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "text.bubble", text: "Natural-language task capture")
            featureRow(icon: "list.bullet.rectangle.portrait", text: "List support with list mentions")
            featureRow(icon: "calendar.badge.clock", text: "Date mentions like tomorrow and next Friday")
            featureRow(icon: "globe", text: "Multilingual task input")
            featureRow(icon: "timer", text: "Priority levels and auto-cleanup")

            // Screenshot (animated GIF, same behavior as other GIF-based extension views)
            if let screenshotURL = ToDoExtension.screenshotURL {
                if screenshotURL.pathExtension.lowercased() == "gif" {
                    AnimatedGIFView(url: screenshotURL.absoluteString)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                                .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                        )
                        .padding(.top, 8)
                } else {
                    CachedAsyncImage(url: screenshotURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                                    .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                            )
                    } placeholder: {
                        EmptyView()
                    }
                    .padding(.top, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                // Auto-cleanup hours setting
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-cleanup")
                            .font(.callout.weight(.medium))
                        Text("Remove completed tasks after")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $autoCleanupHours) {
                        Text("Instantly").tag(0)
                        Text("5 minutes").tag(-5)
                        Text("1 hour").tag(1)
                        Text("2 hours").tag(2)
                        Text("5 hours").tag(5)
                        Text("12 hours").tag(12)
                        Text("24 hours").tag(24)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                .padding(DroppySpacing.md)

                Divider()
                    .padding(.horizontal, DroppySpacing.md)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Calendar sync")
                            .font(.callout.weight(.medium))
                        Text("Show upcoming calendar events in the task overview.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { syncCalendarEnabled },
                        set: { newValue in
                            syncCalendarEnabled = newValue
                            manager.setCalendarSyncEnabled(newValue)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                .padding(.horizontal, DroppySpacing.md)
                .padding(.vertical, 12)

                Divider()
                    .padding(.horizontal, DroppySpacing.md)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Reminders sync")
                        .font(.callout.weight(.medium))
                        Text("Two-way sync with Apple Reminders")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { syncRemindersEnabled },
                        set: { newValue in
                            syncRemindersEnabled = newValue
                            manager.setRemindersSyncEnabled(newValue)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                .padding(.horizontal, DroppySpacing.md)
                .padding(.vertical, 12)

                Divider()
                    .padding(.horizontal, DroppySpacing.md)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Split details panel")
                            .font(.callout.weight(.medium))
                        Text("Show selected task/event details on the right side of shelf timeline.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { shelfSplitViewEnabled },
                        set: { newValue in
                            shelfSplitViewEnabled = newValue
                            manager.setShelfSplitViewEnabled(newValue)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                .padding(.horizontal, DroppySpacing.md)
                .padding(.vertical, 12)
                Divider()
                    .padding(.horizontal, DroppySpacing.md)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show week number")
                            .font(.callout.weight(.medium))
                        Text("Display the current week number in the shelf task timeline header.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $showTaskWeekNumber)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, DroppySpacing.md)
                .padding(.vertical, 12)

                Divider()
                    .padding(.horizontal, DroppySpacing.md)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show timezone in task view")
                            .font(.callout.weight(.medium))
                        Text("Append timezone abbreviation to timed tasks/events.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $showTaskViewTimezone)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, DroppySpacing.md)
                .padding(.vertical, 12)


                if syncCalendarEnabled {
                    Divider()
                        .padding(.horizontal, DroppySpacing.md)

                    calendarListsSection
                }

                if syncRemindersEnabled {
                    Divider()
                        .padding(.horizontal, DroppySpacing.md)

                    reminderListsSection
                }

                Divider()
                    .padding(.horizontal, DroppySpacing.md)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync behavior")
                            .font(.callout.weight(.medium))
                        Text("Automatically syncs in real time when Apple Reminders or Calendar events change.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(.horizontal, DroppySpacing.md)
                .padding(.vertical, 12)
            }
            .background(AdaptiveColors.overlayAuto(0.03))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .onChange(of: autoCleanupHours) { _, _ in
                manager.performCleanupNow()
            }
        }
    }

    private var calendarListsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar lists")
                        .font(.callout.weight(.medium))
                    Text("Choose which Apple Calendar calendars are shown.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                HStack(spacing: 6) {
                    Button {
                        manager.selectAllCalendarLists()
                    } label: {
                        Text("All")
                            .frame(minWidth: 34)
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))

                    Button {
                        manager.clearCalendarListsSelection()
                    } label: {
                        Text("None")
                            .frame(minWidth: 44)
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))
                }
            }
            .padding(.horizontal, DroppySpacing.md)
            .padding(.top, 12)

            if manager.availableCalendarLists.isEmpty {
                Text("No calendars found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DroppySpacing.md)
                    .padding(.bottom, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(manager.availableCalendarLists.enumerated()), id: \.element.id) { index, list in
                        Button {
                            manager.toggleCalendarListSelection(list.id)
                        } label: {
                            HStack(spacing: 10) {
                                reminderListBadge(colorHex: list.colorHex)
                                Text(list.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AdaptiveColors.primaryTextAuto.opacity(0.92))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: manager.isCalendarListSelected(list.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(manager.isCalendarListSelected(list.id) ? .blue : AdaptiveColors.secondaryTextAuto.opacity(0.4))
                            }
                            .padding(.horizontal, DroppySpacing.md)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(focusedCalendarIndex == index ? AdaptiveColors.overlayAuto(0.08) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)

                        if index < manager.availableCalendarLists.count - 1 {
                            Divider()
                                .padding(.leading, DroppySpacing.md + 28)
                                .padding(.trailing, DroppySpacing.md)
                        }
                    }
                }
                .onKeyPress(.downArrow) {
                    let count = manager.availableCalendarLists.count
                    guard count > 0 else { return .ignored }
                    withAnimation(DroppyAnimation.hover) {
                        if let current = focusedCalendarIndex {
                            focusedCalendarIndex = min(current + 1, count - 1)
                        } else {
                            focusedCalendarIndex = 0
                        }
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    let count = manager.availableCalendarLists.count
                    guard count > 0 else { return .ignored }
                    withAnimation(DroppyAnimation.hover) {
                        if let current = focusedCalendarIndex {
                            focusedCalendarIndex = max(current - 1, 0)
                        } else {
                            focusedCalendarIndex = count - 1
                        }
                    }
                    return .handled
                }
                .onKeyPress(.return) {
                    guard let index = focusedCalendarIndex,
                          index < manager.availableCalendarLists.count else { return .ignored }
                    let list = manager.availableCalendarLists[index]
                    manager.toggleCalendarListSelection(list.id)
                    return .handled
                }
                .focusable()
                .focusEffectDisabled()
            }
        }
    }

    private var reminderListsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminder lists")
                        .font(.callout.weight(.medium))
                    Text("Choose which Apple Reminders lists are shown in Reminders.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                HStack(spacing: 6) {
                    Button {
                        manager.selectAllReminderLists()
                    } label: {
                        Text("All")
                            .frame(minWidth: 34)
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))

                    Button {
                        manager.clearReminderListsSelection()
                    } label: {
                        Text("None")
                            .frame(minWidth: 44)
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))
                }
            }
            .padding(.horizontal, DroppySpacing.md)
            .padding(.top, 12)

            if manager.availableReminderLists.isEmpty {
                Text("No reminder lists found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DroppySpacing.md)
                    .padding(.bottom, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(manager.availableReminderLists.enumerated()), id: \.element.id) { index, list in
                        Button {
                            manager.toggleReminderListSelection(list.id)
                        } label: {
                            HStack(spacing: 10) {
                                reminderListBadge(colorHex: list.colorHex)
                                Text(list.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AdaptiveColors.primaryTextAuto.opacity(0.92))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: manager.isReminderListSelected(list.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(manager.isReminderListSelected(list.id) ? .blue : AdaptiveColors.secondaryTextAuto.opacity(0.4))
                            }
                            .padding(.horizontal, DroppySpacing.md)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(focusedListIndex == index ? AdaptiveColors.overlayAuto(0.08) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)

                        if index < manager.availableReminderLists.count - 1 {
                            Divider()
                                .padding(.leading, DroppySpacing.md + 28)
                                .padding(.trailing, DroppySpacing.md)
                        }
                    }
                }
                .onKeyPress(.downArrow) {
                    let count = manager.availableReminderLists.count
                    guard count > 0 else { return .ignored }
                    withAnimation(DroppyAnimation.hover) {
                        if let current = focusedListIndex {
                            focusedListIndex = min(current + 1, count - 1)
                        } else {
                            focusedListIndex = 0
                        }
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    let count = manager.availableReminderLists.count
                    guard count > 0 else { return .ignored }
                    withAnimation(DroppyAnimation.hover) {
                        if let current = focusedListIndex {
                            focusedListIndex = max(current - 1, 0)
                        } else {
                            focusedListIndex = count - 1
                        }
                    }
                    return .handled
                }
                .onKeyPress(.return) {
                    guard let index = focusedListIndex,
                          index < manager.availableReminderLists.count else { return .ignored }
                    let list = manager.availableReminderLists[index]
                    manager.toggleReminderListSelection(list.id)
                    return .handled
                }
                .focusable()
                .focusEffectDisabled()
            }
        }
    }

    @ViewBuilder
    private func reminderListBadge(colorHex: String?) -> some View {
        let tint = colorFromHex(colorHex) ?? AdaptiveColors.overlayAuto(0.65)
        ZStack {
            Circle()
                .fill(tint.opacity(0.2))
                .frame(width: 18, height: 18)
            Circle()
                .stroke(tint.opacity(0.55), lineWidth: 1)
                .frame(width: 18, height: 18)
            Image(systemName: "list.bullet")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint)
        }
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

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button("Close") { dismiss() }
                .buttonStyle(DroppyPillButtonStyle(size: .small))

            Spacer()

            if isInstalled {
                DisableExtensionButton(extensionType: .todo)
            } else {
                Button {
                    installExtension()
                } label: {
                    Text("action.install")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
            }
        }
        .padding(DroppySpacing.lg)
    }

    // MARK: - Actions

    private func installExtension() {
        isInstalled = true
        ExtensionType.todo.setRemoved(false)

        // Track installation
        Task {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "todo")
        }

        // Post notification
        NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.todo)
    }
}

// MARK: - Preview Component

/// A static preview of the Todo extension for the info view
struct ToDoPreviewView: View {
    var body: some View {
        VStack(spacing: 1) {
            // Sample task rows
            previewRow(title: "Review pull request", priority: .high, isCompleted: false)
            Divider().background(AdaptiveColors.overlayAuto(0.06)).padding(.horizontal, 24)
            
            previewRow(title: "Update documentation", priority: .medium, isCompleted: false)
            Divider().background(AdaptiveColors.overlayAuto(0.06)).padding(.horizontal, 24)
            
            previewRow(title: "Fix login bug", priority: .normal, isCompleted: true)
        }
        .padding(12)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
        )
    }

    private func previewRow(title: String, priority: ToDoPriority, isCompleted: Bool) -> some View {
        HStack(spacing: DroppySpacing.smd) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? Color(nsColor: NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.6, alpha: 1.0)) : priority.color)
                .font(.system(size: 16))

            Text(title)
                .font(.system(size: 13, weight: isCompleted ? .regular : .medium))
                .strikethrough(isCompleted)
                .foregroundColor(isCompleted ? .secondary : .white.opacity(0.9))
                .lineLimit(1)

            Spacer()

            if priority != .normal && !isCompleted {
                Image(systemName: priority.icon)
                    .foregroundColor(priority.color)
                    .font(.system(size: 10))
            }
        }
        .padding(.horizontal, DroppySpacing.md)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

#Preview {
    ToDoInfoView()
}
