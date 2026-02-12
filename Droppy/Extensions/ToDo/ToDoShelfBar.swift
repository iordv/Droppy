//
//  ToDoShelfBar.swift
//  Droppy
//
//  Persistent todo input bar that integrates into the shelf
//  Shows at bottom of shelf when Todo extension is installed
//

import SwiftUI
import AppKit

private struct TimelineSectionOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [Date: CGFloat] = [:]

    static func reduce(value: inout [Date: CGFloat], nextValue: () -> [Date: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct TimelineRowRenderID: Hashable {
    let id: UUID
    let isCompleted: Bool
    let priority: ToDoPriority
}

extension Notification.Name {
    static let todoShelfNavigateTimeline = Notification.Name("ToDoShelfNavigateTimeline")
}

struct ToDoShelfBar: View {
    static let hostHorizontalInset: CGFloat = 30
    static let hostBottomInset: CGFloat = 20

    var manager: ToDoManager
    @Binding var isListExpanded: Bool
    var notchHeight: CGFloat = 0  // Height of physical notch to clear
    var useAdaptiveForegroundsForTransparentNotch: Bool = false
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.todoShelfSplitViewEnabled) private var isSplitViewEnabled = PreferenceDefault.todoShelfSplitViewEnabled
    @AppStorage(AppPreferenceKey.todoShowTaskWeekNumber) private var showTaskWeekNumber = PreferenceDefault.todoShowTaskWeekNumber
    @AppStorage(AppPreferenceKey.todoShowTaskViewTimezone) private var showTaskViewTimezone = PreferenceDefault.todoShowTaskViewTimezone

    @State private var inputText: String = ""
    @State private var inputPriority: ToDoPriority = .normal
    @State private var inputDueDate: Date?
    @State private var inputReminderListID: String?
    @State private var showingInputDueDatePicker = false
    @State private var isInputBarHovered = false
    @State private var activeListMentionQuery: String?
    @State private var showingMentionPicker = false
    @State private var selectedTimelineItemID: UUID?
    @State private var detailDraftSourceID: UUID?
    @State private var detailTitleDraft = ""
    @State private var detailDueDateDraft: Date?
    @State private var showingDetailDueDatePicker = false
    @State private var selectedStripDayStart = Calendar.current.startOfDay(for: Date())
    @State private var stripWindowStartDay = Calendar.current.startOfDay(for: Date())
    @State private var timelineScrollTargetDay: Date?
    @State private var timelineScrollTargetItemID: TimelineRowRenderID?
    @State private var suppressStripSelectionFromScroll = false
    @State private var stripScrollSyncWorkItem: DispatchWorkItem?
    @State private var splitToggleInteractionWorkItem: DispatchWorkItem?
    @FocusState private var isDetailTitleFieldFocused: Bool

    private var useAdaptiveForegrounds: Bool {
        useTransparentBackground && useAdaptiveForegroundsForTransparentNotch
    }

    private var timelineColumnHorizontalPadding: CGFloat {
        isSplitViewEnabled ? 10 : Layout.listHorizontalPadding
    }

    private enum Layout {
        static let internalBottomPadding: CGFloat = 0
        static let inputBarHeight: CGFloat = 36
        static let inputHorizontalPadding: CGFloat = 4
        static let leadingSlotWidth: CGFloat = 64
        static let trailingSlotWidth: CGFloat = 70
        static let sideControlHeight: CGFloat = 28
        static let roundControlFrame: CGFloat = 28
        static let textHorizontalInset: CGFloat = 2
        static let textFieldHeight: CGFloat = 26
        static let sideControlContentPadding: CGFloat = 4
        static let listBottomSpacing: CGFloat = 8
        static let emptyListBottomSpacing: CGFloat = 0
        static let listHeight: CGFloat = 250
        static let timelineHeaderHeight: CGFloat = 84
        static let timelineContentTopSpacing: CGFloat = 8
        static let listTopPadding: CGFloat = 18
        static let listBottomPadding: CGFloat = 8
        static let listHorizontalPadding: CGFloat = inputHorizontalPadding
        static let emptyStateHeight: CGFloat = 80
        static let undoToastBottomPadding: CGFloat = 56
        static let undoToastTopPadding: CGFloat = 8
        static let undoToastEmptyStateClearance: CGFloat = 38
    }

    var body: some View {
        VStack(spacing: 0) {
            // Task list (expandable) - appears above input bar
            if isListExpanded {
                taskListSection
                    .notchTransitionBlurOnly()
            }

            // Input bar (always visible)
            inputBar
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, Layout.internalBottomPadding)
        .overlay(alignment: undoToastAlignment) {
            if manager.showUndoToast {
                ToDoUndoToast(
                    onUndo: {
                        manager.restoreLastDeletedItem()
                    },
                    onDismiss: {
                        withAnimation(DroppyAnimation.viewChange) {
                            manager.showUndoToast = false
                        }
                    },
                    useAdaptiveColors: useAdaptiveForegrounds
                )
                .padding(undoToastPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if manager.showCleanupToast {
                ToDoCleanupToast(
                    count: manager.cleanupCount,
                    onDismiss: {
                        withAnimation(DroppyAnimation.smooth(duration: 0.25)) {
                            manager.showCleanupToast = false
                        }
                    },
                    useAdaptiveColors: useAdaptiveForegrounds
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(DroppyAnimation.smoothContent, value: isListExpanded)
        .animation(DroppyAnimation.smoothContent, value: manager.items.count)
        .animation(DroppyAnimation.transition, value: manager.showUndoToast)
        .animation(DroppyAnimation.transition, value: manager.showCleanupToast)
        .onAppear {
            manager.setShelfSplitViewEnabled(isSplitViewEnabled)
            stripWindowStartDay = selectedStripDayStart
            if manager.isRemindersSyncEnabled || manager.isCalendarSyncEnabled {
                manager.syncExternalSourcesNow(minimumInterval: 1.5)
            }
            if manager.isRemindersSyncEnabled {
                manager.refreshReminderListsNow()
            }
            syncTimelineSelection()
            syncDetailDraftFromSelection()
        }
        .onChange(of: showingInputDueDatePicker) { _, showing in
            manager.isInteractingWithPopover = showing
        }
        .onChange(of: showingMentionPicker) { _, showing in
            manager.isInteractingWithPopover = showing
        }
        .onChange(of: isListExpanded) { _, expanded in
            manager.isShelfListExpanded = expanded
            NotchWindowController.shared.recalculateAllWindowSizesCoalesced()
            guard expanded else { return }
            let today = Calendar.current.startOfDay(for: Date())
            selectedStripDayStart = today
            ensureSelectedDayVisibleInStrip()
            // Always reopen timeline from today/top so the view never appears
            // offset too low from the previously scrolled position.
            selectedTimelineItemID = nil
            timelineScrollTargetDay = today
            timelineScrollTargetItemID = nil
            syncTimelineSelection()
            syncDetailDraftFromSelection()
            if manager.isRemindersSyncEnabled || manager.isCalendarSyncEnabled {
                manager.syncExternalSourcesNow(minimumInterval: 1.5)
            }
        }
        .onDisappear {
            stripScrollSyncWorkItem?.cancel()
            splitToggleInteractionWorkItem?.cancel()
            manager.isInteractingWithPopover = false
            manager.isEditingText = false
        }
        .onChange(of: inputText) { _, newValue in
            refreshListMentionState(for: newValue)
        }
        .onChange(of: manager.availableReminderLists) { _, _ in
            showingMentionPicker = shouldShowMentionTooltip
        }
        .onChange(of: showingDetailDueDatePicker) { _, showing in
            manager.isInteractingWithPopover = showing
        }
        .onChange(of: isSplitViewEnabled) { _, _ in
            manager.setShelfSplitViewEnabled(isSplitViewEnabled)
            syncTimelineSelection()
            syncDetailDraftFromSelection()
            NotchWindowController.shared.recalculateAllWindowSizesCoalesced()
        }
        .onChange(of: timelineSelectionSignature) { _, _ in
            syncTimelineSelection()
            syncDetailDraftFromSelection()
            alignSelectedStripDayWithTimeline()
        }
        .onChange(of: selectedTimelineItemID) { _, _ in
            isDetailTitleFieldFocused = false
            syncDetailDraftFromSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoShelfNavigateTimeline)) { note in
            guard isListExpanded,
                  !manager.isEditingText,
                  !isDetailTitleFieldFocused,
                  !manager.isInteractingWithPopover else { return }
            guard let step = note.userInfo?["step"] as? Int else { return }
            navigateTimelineSelection(step: step)
        }
        .onChange(of: detailTitleDraft) { _, newValue in
            guard isSplitViewEnabled, let item = selectedTimelineItem, !isCalendarEvent(item) else { return }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != item.title else { return }
            manager.updateTitle(for: item, to: trimmed)
        }
        .onChange(of: detailDueDateDraft) { _, newValue in
            guard isSplitViewEnabled, let item = selectedTimelineItem, !isCalendarEvent(item) else { return }
            guard item.dueDate != newValue else { return }
            manager.updateDueDate(for: item, to: newValue)
        }

    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 0) {
            // Priority indicator (left)
            priorityControl
                .frame(width: Layout.leadingSlotWidth)

            // Text input (center)
            textField
                .padding(.horizontal, Layout.textHorizontalInset)

            // Task count + list toggle (right)
            listToggle
                .frame(width: Layout.trailingSlotWidth)
        }
        .padding(.horizontal, Layout.inputHorizontalPadding)
        .frame(height: Layout.inputBarHeight)
        .background(
            Capsule()
                .fill(
                    useAdaptiveForegrounds
                        ? AdaptiveColors.buttonBackgroundAuto.opacity(0.95)
                        : Color.white.opacity(0.12)
                )
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    useAdaptiveForegrounds
                        ? AdaptiveColors.subtleBorderAuto.opacity(isInputBarHovered ? 1.4 : 1.0)
                        : Color.white.opacity(isInputBarHovered ? 0.2 : 0.14),
                    lineWidth: 1
                )
        )
        .frame(maxWidth: .infinity)
        .onHover { hovering in
            isInputBarHovered = hovering
        }
        .animation(DroppyAnimation.hoverQuick, value: isInputBarHovered)
    }

    private var priorityControl: some View {
        HStack(spacing: 0) {
            priorityDot
                .frame(width: Layout.sideControlHeight, height: Layout.sideControlHeight)
            ToDoDueDateCircleButtonLocal(
                tint: inputPriority.color.opacity(inputPriority == .normal ? 0.3 : 0.6)
            ) {
                showingInputDueDatePicker.toggle()
            }
            .help(inputDueDate == nil ? "Set due date" : "Edit due date")
            .popover(isPresented: $showingInputDueDatePicker) {
                ToDoDueDatePopoverContentLocal(
                    dueDate: $inputDueDate,
                    primaryButtonTitle: "Done",
                    onPrimary: { showingInputDueDatePicker = false },
                    setInteractingPopover: { manager.isInteractingWithPopover = $0 }
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.sideControlContentPadding)
        .frame(maxWidth: .infinity)
        .frame(height: Layout.sideControlHeight)
    }

    private var priorityDot: some View {
        Button {
            HapticFeedback.medium.perform()
            cyclePriority()
        } label: {
            ZStack {
                // Hit area
                Circle()
                    .fill(Color.clear)
                    .frame(width: Layout.roundControlFrame, height: Layout.roundControlFrame)

                // Outer ring (subtle, shows priority)
                Circle()
                    .strokeBorder(inputPriority.color.opacity(inputPriority == .normal ? 0.3 : 0.6), lineWidth: 1.5)
                    .frame(width: 18, height: 18)

                // Inner filled circle - larger and more visible for high/medium priority
                Circle()
                    .fill(inputPriority.color)
                    .frame(width: priorityDotSize, height: priorityDotSize)
                    .shadow(color: inputPriority == .normal ? .clear : inputPriority.color.opacity(0.5), radius: 4)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(priorityHelpText)
        .accessibilityLabel(String(localized: "action.set_priority"))
        .accessibilityValue(priorityAccessibilityValue)
        .animation(DroppyAnimation.bounce, value: inputPriority)
    }

    private var priorityDotSize: CGFloat {
        switch inputPriority {
        case .normal: return 6
        case .medium: return 10
        case .high: return 12
        }
    }

    private var priorityHelpText: String {
        switch inputPriority {
        case .normal: return String(localized: "priority.help.normal")
        case .medium: return String(localized: "priority.help.medium")
        case .high: return String(localized: "priority.help.high")
        }
    }

    private var priorityAccessibilityValue: String {
        switch inputPriority {
        case .normal: return String(localized: "priority.normal")
        case .medium: return String(localized: "priority.medium")
        case .high: return String(localized: "priority.high")
        }
    }

    private var textField: some View {
        ToDoStableTextField(
            text: $inputText,
            placeholder: String(localized: "add_task_placeholder"),
            onSubmit: submitTask,
            onEditingChanged: { isEditing in
                manager.isEditingText = isEditing
            },
            useAdaptiveColors: useAdaptiveForegrounds,
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Layout.textFieldHeight, alignment: .center)
            .popover(isPresented: $showingMentionPicker, arrowEdge: .bottom) {
                ToDoReminderListMentionTooltip(
                    options: mentionOptions,
                    selectedID: inputReminderListID,
                    onSelect: applyMentionSelection
                )
            }
    }

    private var listToggle: some View {
        Button {
            HapticFeedback.medium.perform()
            let nextExpanded = !isListExpanded
            // Keep the window-size source of truth in sync BEFORE animating the visual expansion,
            // so physical-notch layouts stay top-pinned without a one-frame top gap.
            manager.isShelfListExpanded = nextExpanded
            NotchWindowController.shared.forceRecalculateAllWindowSizes()
            withAnimation(DroppyAnimation.smoothContent) {
                isListExpanded = nextExpanded
            }
        } label: {
            HStack(spacing: DroppySpacing.xs) {
                // Task count badge
                if incompleteCount > 0 {
                    Text(incompleteCountLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        // Keep badge numbers white for strong contrast on the blue pill,
                        // including external transparent-notch mode.
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .frame(minWidth: 19)
                        .background(Capsule().fill(Color.blue.opacity(0.9)))
                        .transition(.scale.combined(with: .opacity))
                }

                Image(systemName: isListExpanded ? "chevron.down" : "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 12, height: 12)
                    .foregroundStyle(
                        isListExpanded
                            ? .white
                            : (useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto : .white.opacity(0.6))
                    )
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, Layout.sideControlContentPadding)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.sideControlHeight)
            .background(
                Capsule()
                    .fill(
                        isListExpanded
                            ? Color.blue.opacity(0.8)
                            : (useAdaptiveForegrounds ? AdaptiveColors.buttonBackgroundAuto : Color.white.opacity(0.12))
                    )
            )
        }
        .buttonStyle(.plain)
        .help(String(localized: isListExpanded ? "action.hide_tasks" : "action.show_tasks"))
        .accessibilityLabel(String(localized: isListExpanded ? "action.hide_tasks" : "action.show_tasks"))
        .animation(DroppyAnimation.state, value: isListExpanded)
        .animation(DroppyAnimation.state, value: incompleteCount)
    }

    // MARK: - Task List

    private var taskListSection: some View {
        VStack(spacing: 0) {
            timelineToolbar
                .padding(.top, 0)
                .padding(.horizontal, timelineColumnHorizontalPadding)
                .zIndex(2)

            if timelineVisibleItems.isEmpty {
                emptyTimelineState
                    .padding(.top, emptyStateTopPadding)
            } else if isSplitViewEnabled {
                timelineSplitView
                    .padding(.top, Layout.timelineContentTopSpacing)
            } else {
                timelineScrollableColumn
                    .padding(.top, Layout.timelineContentTopSpacing)
                    .frame(height: Layout.listHeight)
                    .clipShape(Rectangle())
            }

            Spacer()
                .frame(height: timelineVisibleItems.isEmpty ? Layout.emptyListBottomSpacing : Layout.listBottomSpacing)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var timelineToolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(timelineModeTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        useAdaptiveForegrounds
                            ? AdaptiveColors.secondaryTextAuto.opacity(0.9)
                            : .white.opacity(0.74)
                    )
                    .contentTransition(.interpolate)
                    .animation(DroppyAnimation.state, value: timelineModeTitle)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                useAdaptiveForegrounds
                                    ? AdaptiveColors.overlayAuto(0.08)
                                    : Color.white.opacity(0.08)
                            )
                    )

                if showTaskWeekNumber {
                    Text("W\(visibleStripWeekNumber)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(
                            useAdaptiveForegrounds
                                ? AdaptiveColors.secondaryTextAuto.opacity(0.88)
                                : .white.opacity(0.68)
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    useAdaptiveForegrounds
                                        ? AdaptiveColors.overlayAuto(0.08)
                                        : Color.white.opacity(0.08)
                                )
                        )
                }

                Spacer(minLength: 0)

                Button {
                    HapticFeedback.medium.perform()
                    beginSplitToggleInteractionHold()
                    isSplitViewEnabled.toggle()
                    manager.setShelfSplitViewEnabled(isSplitViewEnabled)
                    NotchWindowController.shared.recalculateAllWindowSizesCoalesced()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                useAdaptiveForegrounds
                                    ? AdaptiveColors.overlayAuto(isSplitViewEnabled ? 0.14 : 0.08)
                                    : Color.white.opacity(isSplitViewEnabled ? 0.14 : 0.08)
                            )

                        Image(systemName: isSplitViewEnabled ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(
                                isSplitViewEnabled
                                    ? Color.blue.opacity(0.95)
                                    : (useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.88) : .white.opacity(0.62))
                            )
                    }
                    .frame(width: 30, height: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help(isSplitViewEnabled ? "Disable split details" : "Enable split details")
            }
            .padding(.top, -topToolbarLift)

            nativeDayStrip
        }
    }

    private var nativeDayStrip: some View {
        let calendar = Calendar.current
        let stripStart = stripWindowStartDay

        return HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: stripStart) ?? stripStart
                let dayStart = calendar.startOfDay(for: day)
                let isSelectedDay = calendar.isDate(dayStart, inSameDayAs: selectedStripDayStart)

                Button {
                    HapticFeedback.tap()
                    selectedStripDayStart = dayStart
                    ensureSelectedDayVisibleInStrip()
                    timelineScrollTargetDay = dayStart
                } label: {
                    HStack(spacing: 6) {
                        Text(day, format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                useAdaptiveForegrounds
                                    ? AdaptiveColors.primaryTextAuto.opacity(isSelectedDay ? 0.95 : 0.84)
                                    : .white.opacity(isSelectedDay ? 0.9 : 0.75)
                            )
                            .contentTransition(.interpolate)
                            .animation(DroppyAnimation.state, value: stripWindowStartDay)

                        Text(day, format: .dateTime.day())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                isSelectedDay
                                    ? .white
                                    : (useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto.opacity(0.92) : .white.opacity(0.88))
                            )
                            .contentTransition(.numericText(value: Double(Calendar.current.component(.day, from: day))))
                            .animation(DroppyAnimation.state, value: stripWindowStartDay)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(
                                        isSelectedDay
                                            ? Color.red.opacity(0.95)
                                            : Color.clear
                                    )
                            )
                    }
                    .frame(height: 24)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 18, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.predictedEndTranslation.width
                    let vertical = value.predictedEndTranslation.height
                    guard abs(horizontal) > abs(vertical), abs(horizontal) > 40 else { return }
                    if horizontal < 0 {
                        shiftDisplayedWeek(by: 1)
                    } else {
                        shiftDisplayedWeek(by: -1)
                    }
                }
        )
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    useAdaptiveForegrounds
                        ? AdaptiveColors.overlayAuto(0.05)
                        : Color.white.opacity(0.04)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(
                    useAdaptiveForegrounds
                        ? AdaptiveColors.overlayAuto(0.1)
                        : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    private var timelineScrollableColumn: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(timelineDaySections) { section in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formattedDayHeader(for: section.dayStart))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(
                                    useAdaptiveForegrounds
                                        ? AdaptiveColors.secondaryTextAuto.opacity(0.82)
                                        : .white.opacity(0.62)
                                )
                                .contentTransition(.interpolate)
                                .animation(DroppyAnimation.state, value: section.dayStart)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 2)
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(
                                            key: TimelineSectionOffsetPreferenceKey.self,
                                            value: [section.dayStart: proxy.frame(in: .named("timeline-scroll")).minY]
                                        )
                                    }
                                )

                            ForEach(section.items, id: \.id) { item in
                                ShelfTimelineRow(
                                    item: item,
                                    manager: manager,
                                    isSelected: isSplitViewEnabled && selectedTimelineItemID == item.id,
                                    allowCompactDetailsPopover: !isSplitViewEnabled,
                                    useAdaptiveForegrounds: useAdaptiveForegrounds,
                                    timeLabel: formattedTimelineTimeLabel(for: item),
                                    detailDateLabel: item.dueDate.map { formattedDetailDate(for: $0) },
                                    onSelect: {
                                        isDetailTitleFieldFocused = false
                                        selectedTimelineItemID = item.id
                                    },
                                    onToggleCompletion: {
                                        manager.toggleCompletion(for: item)
                                    },
                                    onDelete: {
                                        manager.removeItem(item)
                                        DispatchQueue.main.async {
                                            syncTimelineSelection()
                                            syncDetailDraftFromSelection()
                                        }
                                    }
                                )
                                .id(
                                    TimelineRowRenderID(
                                        id: item.id,
                                        isCompleted: item.isCompleted,
                                        priority: item.priority
                                    )
                                )
                            }
                        }
                        .id(section.dayStart)
                    }
                }
                .padding(.top, Layout.listTopPadding)
                .padding(.bottom, Layout.listBottomPadding)
                .padding(.horizontal, timelineColumnHorizontalPadding)
            }
            .coordinateSpace(name: "timeline-scroll")
            .onPreferenceChange(TimelineSectionOffsetPreferenceKey.self) { offsets in
                updateStripSelectionFromScroll(offsets)
            }
            .onChange(of: timelineScrollTargetDay) { _, targetDay in
                guard let targetDay, let resolvedDay = resolvedTimelineScrollDay(for: targetDay) else { return }
                suspendStripSelectionSyncDuringProgrammaticScroll()
                withAnimation(DroppyAnimation.smoothContent) {
                    proxy.scrollTo(resolvedDay, anchor: .top)
                }
            }
            .onChange(of: timelineScrollTargetItemID) { _, targetItemID in
                guard let targetItemID else { return }
                suspendStripSelectionSyncDuringProgrammaticScroll()
                withAnimation(DroppyAnimation.smoothContent) {
                    proxy.scrollTo(targetItemID, anchor: .center)
                }
            }
            .onChange(of: timelineDaySectionSignature) { _, _ in
                guard let targetDay = timelineScrollTargetDay,
                      let resolvedDay = resolvedTimelineScrollDay(for: targetDay) else { return }
                DispatchQueue.main.async {
                    withAnimation(DroppyAnimation.smoothContent) {
                        proxy.scrollTo(resolvedDay, anchor: .top)
                    }
                }
            }
            .onAppear {
                if timelineScrollTargetDay == nil {
                    timelineScrollTargetDay = selectedStripDayStart
                }
            }
            .background(
                ToDoShelfScrollViewResolver { scrollView in
                    // Prevent macOS keyboard focus ring around timeline list.
                    scrollView.focusRingType = .none
                    scrollView.contentView.focusRingType = .none
                    scrollView.documentView?.focusRingType = .none
                }
            )
        }
    }

    private var timelineSplitView: some View {
        HStack(spacing: 0) {
            timelineScrollableColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            timelineDetailPane
                .frame(width: 300)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(height: Layout.listHeight)
        .clipShape(Rectangle())
    }

    private var timelineDetailPane: some View {
        Group {
            if let item = selectedTimelineItem {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: isCalendarEvent(item) ? "calendar.badge.clock" : "checklist")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                isCalendarEvent(item)
                                    ? calendarTint(for: item).opacity(0.95)
                                    : (useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto : .white.opacity(0.8))
                            )
                        Text(isCalendarEvent(item) ? "Event Details" : "Task Details")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.9) : .white.opacity(0.72))
                            .contentTransition(.interpolate)
                            .animation(DroppyAnimation.state, value: isCalendarEvent(item))
                        Spacer(minLength: 0)
                    }

                    if isCalendarEvent(item) {
                        Text(item.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto : .white.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.interpolate)
                            .animation(DroppyAnimation.state, value: item.id)

                        if let dueDate = item.dueDate {
                            Text(formattedDetailDate(for: dueDate))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.85) : .white.opacity(0.64))
                                .contentTransition(.interpolate)
                                .animation(DroppyAnimation.state, value: dueDate.timeIntervalSinceReferenceDate)
                        }

                        if let listTitle = item.externalListTitle, !listTitle.isEmpty {
                            Label(listTitle, systemImage: "calendar")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(calendarTint(for: item).opacity(0.95))
                        }

                        Label("Read-only (Apple Calendar)", systemImage: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.78) : .white.opacity(0.6))

                        Spacer(minLength: 0)
                    } else {
                        TextField("Task title", text: $detailTitleDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto : .white.opacity(0.95))
                            .focused($isDetailTitleFieldFocused)
                            // SwiftUI/AppKit nudges NSTextField text up slightly in edit mode.
                            // Keep perceived baseline stable between display and editing states.
                            .offset(y: isDetailTitleFieldFocused ? 1 : 0)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(height: 24, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(useAdaptiveForegrounds ? AdaptiveColors.buttonBackgroundAuto.opacity(0.95) : Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.16) : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                            )

                        HStack(spacing: 6) {
                            priorityChip(.high, title: "High", item: item)
                            priorityChip(.medium, title: "Medium", item: item)
                            priorityChip(.normal, title: "Normal", item: item)
                        }

                        HStack(spacing: 8) {
                            Label(detailDueDateDraft == nil ? "No due date" : formattedDetailDate(for: detailDueDateDraft ?? Date()), systemImage: "calendar")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.88) : .white.opacity(0.7))
                                .contentTransition(.interpolate)
                                .animation(DroppyAnimation.state, value: detailDueDateDraft?.timeIntervalSinceReferenceDate ?? -1)

                            Spacer(minLength: 0)

                            Button(detailDueDateDraft == nil ? "Add Date" : "Edit Date") {
                                showingDetailDueDatePicker = true
                            }
                            .buttonStyle(DroppyPillButtonStyle(size: .small))
                            .contentTransition(.interpolate)
                            .animation(DroppyAnimation.state, value: detailDueDateDraft == nil)
                            .popover(isPresented: $showingDetailDueDatePicker) {
                                ToDoDueDatePopoverContentLocal(
                                    dueDate: Binding(
                                        get: { detailDueDateDraft },
                                        set: { detailDueDateDraft = $0 }
                                    ),
                                    primaryButtonTitle: "Done",
                                    onPrimary: { showingDetailDueDatePicker = false },
                                    setInteractingPopover: { manager.isInteractingWithPopover = $0 }
                                )
                            }
                        }

                        HStack(spacing: 8) {
                            Button {
                                manager.toggleCompletion(for: item)
                            } label: {
                                Text(item.isCompleted ? "Mark Pending" : "Mark Complete")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(DroppyPillButtonStyle(size: .small))

                            Button(role: .destructive) {
                                manager.removeItem(item)
                                DispatchQueue.main.async {
                                    syncTimelineSelection()
                                    syncDetailDraftFromSelection()
                                }
                            } label: {
                                Text("Delete")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(DroppyAccentButtonStyle(color: .red, size: .small))
                        }

                        Spacer(minLength: 0)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.08) : Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.12) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.6) : .white.opacity(0.45))
                    Text("Select an item")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.72) : .white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.06) : Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.12) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
            }
        }
    }

    private func priorityChip(_ priority: ToDoPriority, title: String, item: ToDoItem) -> some View {
        Button {
            manager.updatePriority(for: item, to: priority)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    item.priority == priority
                        ? .white
                        : (useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.9) : .white.opacity(0.75))
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            item.priority == priority
                                ? priority.color.opacity(0.85)
                                : (useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.1) : Color.white.opacity(0.08))
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyTimelineState: some View {
        VStack(spacing: DroppySpacing.xsm) {
            ZStack {
                Circle()
                    .fill(useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.04) : Color.white.opacity(0.04))
                    .frame(width: 36, height: 36)
                Image(systemName: timelineEmptyIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: useAdaptiveForegrounds
                                ? [AdaptiveColors.secondaryTextAuto.opacity(0.55), AdaptiveColors.secondaryTextAuto.opacity(0.28)]
                                : [.white.opacity(0.3), .white.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            Text(timelineEmptyLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.75) : .white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: Layout.emptyStateHeight, alignment: .center)
    }

    private var reminderListMenuOptions: [ToDoReminderListOption] {
        guard manager.isRemindersSyncEnabled else { return [] }
        return manager.availableReminderLists
    }

    // MARK: - Actions

    private func cyclePriority() {
        withAnimation(DroppyAnimation.bounce) {
            switch inputPriority {
            case .normal: inputPriority = .high
            case .high: inputPriority = .medium
            case .medium: inputPriority = .normal
            }
        }
    }

    private func beginSplitToggleInteractionHold() {
        splitToggleInteractionWorkItem?.cancel()
        let wasAlreadyInteracting = manager.isInteractingWithPopover
        manager.isInteractingWithPopover = true

        let workItem = DispatchWorkItem {
            if !wasAlreadyInteracting {
                manager.isInteractingWithPopover = false
            }
        }
        splitToggleInteractionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }

    private func submitTask() {
        let parsed = ToDoInputIntelligence.parseTaskDraft(inputText)
        let trimmed = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let resolvedDueDate = parsed.dueDate ?? inputDueDate
        let resolvedReminderListID = resolveReminderListID(from: parsed.reminderListQuery)

        HapticFeedback.drop()

        withAnimation(DroppyAnimation.itemInsertion) {
            manager.addItem(
                title: trimmed,
                priority: inputPriority,
                dueDate: resolvedDueDate,
                reminderListID: resolvedReminderListID
            )
        }

        // Reset with animation
        withAnimation(DroppyAnimation.state) {
            inputText = ""
            inputPriority = .normal
            inputDueDate = nil
            inputReminderListID = nil
            activeListMentionQuery = nil
            showingMentionPicker = false
        }
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
            inputReminderListID = tokenListID
        } else if !text.contains("@") {
            inputReminderListID = nil
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
        inputReminderListID = option.id
        inputText = ToDoInputIntelligence.applyListMentionToken(option.title, to: inputText)
        activeListMentionQuery = nil
        showingMentionPicker = false
    }

    private func resolveReminderListID(from parsedQuery: String?) -> String? {
        if let explicit = inputReminderListID {
            return explicit
        }
        guard let parsedQuery else { return nil }
        return manager.resolveReminderList(matching: parsedQuery)?.id
    }
}


enum ToDoTextHighlightStyle {
    case detectedDate
    case listMentionToken
}

struct ToDoTextHighlightSpan {
    let range: Range<String.Index>
    let style: ToDoTextHighlightStyle
}

private extension NSAttributedString.Key {
    static let toDoBadgeColor = NSAttributedString.Key("toDoBadgeColor")
}

private final class ToDoRoundedBadgeLayoutManager: NSLayoutManager {
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

        guard let storage = textStorage else { return }
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)

        storage.enumerateAttribute(.toDoBadgeColor, in: charRange) { value, range, _ in
            guard let color = value as? NSColor else { return }
            let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let visible = NSIntersectionRange(glyphRange, glyphsToShow)
            guard visible.length > 0 else { return }

            for container in self.textContainers {
                self.enumerateEnclosingRects(
                    forGlyphRange: visible,
                    withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                    in: container
                ) { rect, _ in
                    var badgeRect = rect.offsetBy(dx: origin.x, dy: origin.y)
                    badgeRect = badgeRect.insetBy(dx: -4, dy: -1)
                    // Clamp left edge so the badge is never cut off at the field boundary
                    if badgeRect.origin.x < origin.x {
                        let overflow = origin.x - badgeRect.origin.x
                        badgeRect.origin.x = origin.x
                        badgeRect.size.width -= overflow
                    }
                    let radius = min(badgeRect.height / 2.0, 8)
                    let path = NSBezierPath(roundedRect: badgeRect, xRadius: radius, yRadius: radius)
                    color.setFill()
                    path.fill()
                }
            }
        }
    }
}

struct ToDoStableTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onEditingChanged: (Bool) -> Void
    var useAdaptiveColors: Bool = false
    var highlightSpansProvider: ((String) -> [ToDoTextHighlightSpan])? = nil

    fileprivate var resolvedPrimaryTextColor: NSColor {
        if useAdaptiveColors {
            return NSColor.labelColor.withAlphaComponent(0.92)
        }
        return NSColor.white.withAlphaComponent(0.9)
    }

    fileprivate var resolvedPlaceholderTextColor: NSColor {
        if useAdaptiveColors {
            return NSColor.secondaryLabelColor.withAlphaComponent(0.82)
        }
        return NSColor.white.withAlphaComponent(0.5)
    }

    fileprivate var resolvedUnderlineColor: NSColor {
        if useAdaptiveColors {
            return NSColor.secondaryLabelColor.withAlphaComponent(0.85)
        }
        return NSColor.white.withAlphaComponent(0.6)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: "")
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 13, weight: .medium)
        textField.textColor = resolvedPrimaryTextColor
        textField.cell?.lineBreakMode = .byTruncatingTail
        textField.cell?.usesSingleLineMode = true
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.allowsEditingTextAttributes = true
        textField.delegate = context.coordinator
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: resolvedPlaceholderTextColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ]
        )
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.textColor = resolvedPrimaryTextColor
        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: resolvedPlaceholderTextColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ]
        )
        context.coordinator.syncEditorAppearance(on: nsView)
        context.coordinator.applyHighlight(to: nsView)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ToDoStableTextField
        private var isApplyingHighlight = false

        init(_ parent: ToDoStableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard !isApplyingHighlight else { return }
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
            applyHighlight(to: field)
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            if let field = notification.object as? NSTextField,
               let editor = field.currentEditor() as? NSTextView {
                installRoundedBadgeLayoutManagerIfNeeded(on: editor)
                syncEditorAppearance(on: field)
            }
            parent.onEditingChanged(true)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.onEditingChanged(false)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }

        func applyHighlight(to field: NSTextField) {
            guard let provider = parent.highlightSpansProvider else { return }
            let text = field.stringValue
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: parent.resolvedPrimaryTextColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ]

            guard !text.isEmpty else {
                syncEditorAppearance(on: field)
                return
            }

            let attributed = NSMutableAttributedString(string: text)
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            attributed.setAttributes(baseAttributes, range: fullRange)

            let spans = provider(text)
            for span in spans {
                let nsRange = NSRange(span.range, in: text)
                if nsRange.location != NSNotFound, nsRange.length > 0 {
                    switch span.style {
                    case .detectedDate:
                        attributed.addAttributes([
                            .foregroundColor: parent.useAdaptiveColors
                                ? parent.resolvedPrimaryTextColor
                                : NSColor.white.withAlphaComponent(0.95),
                            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                            .underlineStyle: NSUnderlineStyle.single.rawValue,
                            .underlineColor: parent.resolvedUnderlineColor
                        ], range: nsRange)
                    case .listMentionToken:
                        attributed.addAttributes([
                            .foregroundColor: parent.useAdaptiveColors
                                ? parent.resolvedPrimaryTextColor
                                : NSColor.white.withAlphaComponent(0.95),
                            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                            .underlineStyle: NSUnderlineStyle.single.rawValue,
                            .underlineColor: parent.resolvedUnderlineColor
                        ], range: nsRange)
                    }
                }
            }

            isApplyingHighlight = true
            if let editor = field.currentEditor() as? NSTextView {
                installRoundedBadgeLayoutManagerIfNeeded(on: editor)
                let selectedRange = editor.selectedRange()
                editor.textStorage?.setAttributedString(attributed)
                editor.selectedRange = selectedRange
                syncEditorAppearance(on: field)
            } else {
                field.attributedStringValue = attributed
            }
            isApplyingHighlight = false
        }

        func syncEditorAppearance(on field: NSTextField) {
            guard let editor = field.currentEditor() as? NSTextView else { return }

            let textColor = parent.resolvedPrimaryTextColor
            editor.textColor = textColor
            editor.insertionPointColor = textColor

            var typingAttributes = editor.typingAttributes
            typingAttributes[.foregroundColor] = textColor
            typingAttributes[.font] = NSFont.systemFont(ofSize: 13, weight: .medium)
            editor.typingAttributes = typingAttributes
        }

        private func installRoundedBadgeLayoutManagerIfNeeded(on editor: NSTextView) {
            guard let storage = editor.textStorage,
                  let existingLayout = editor.layoutManager else {
                return
            }

            if existingLayout is ToDoRoundedBadgeLayoutManager {
                return
            }

            let containers = existingLayout.textContainers
            storage.removeLayoutManager(existingLayout)

            let roundedLayout = ToDoRoundedBadgeLayoutManager()
            roundedLayout.allowsNonContiguousLayout = existingLayout.allowsNonContiguousLayout
            storage.addLayoutManager(roundedLayout)

            for container in containers {
                roundedLayout.addTextContainer(container)
            }
        }
    }
}

private struct ToDoShelfScrollViewResolver: NSViewRepresentable {
    let onResolve: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            resolveScrollView(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            resolveScrollView(from: nsView)
        }
    }

    private func resolveScrollView(from view: NSView) {
        var current: NSView? = view
        while let candidate = current {
            if let scroll = candidate.enclosingScrollView {
                onResolve(scroll)
                return
            }
            current = candidate.superview
        }
    }
}

private struct ToDoDueDateCircleButtonLocal: View {
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear
                    .frame(width: 28, height: 28)

                Image(systemName: "clock")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(tint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ToDoDueDatePopoverContentLocal: View {
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
                TextField(timePlaceholder, text: $manualTimeText, onEditingChanged: { editing in
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
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: date)
    }

    private var timePlaceholder: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: Date())
    }
}



// MARK: - Task Row

private struct ShelfTimelineRow: View {
    let item: ToDoItem
    let manager: ToDoManager
    let isSelected: Bool
    let allowCompactDetailsPopover: Bool
    let useAdaptiveForegrounds: Bool
    let timeLabel: String
    let detailDateLabel: String?
    let onSelect: () -> Void
    let onToggleCompletion: () -> Void
    let onDelete: () -> Void
    @State private var isShowingInfoPopover = false
    @State private var isEditing = false
    @State private var editText = ""
    @State private var editDueDate: Date?

    var body: some View {
        HStack(spacing: 8) {
            if isCalendarEvent {
                Circle()
                    .fill(calendarTint.opacity(0.95))
                    .frame(width: 7, height: 7)
                    .frame(width: 18, height: 18)
            } else {
                Button {
                    HapticFeedback.medium.perform()
                    onToggleCompletion()
                } label: {
                    Image(systemName: "circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(item.priority.color.opacity(0.9))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(
                        isCalendarEvent
                            ? calendarTint.opacity(0.95)
                            : (useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto.opacity(0.95) : .white.opacity(0.92))
                    )

                HStack(spacing: 5) {
                    Text(timeLabel)
                        .font(.system(size: 10, weight: .medium))
                    if let sourceLabel {
                        Text("•")
                            .font(.system(size: 9, weight: .bold))
                        Text(sourceLabel)
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.82) : .white.opacity(0.6))
                .contentTransition(.interpolate)
                .animation(DroppyAnimation.state, value: timeLabel)
            }

            Spacer(minLength: 0)

            if !isCalendarEvent {
                Button {
                    HapticFeedback.delete()
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.74) : .white.opacity(0.4))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(rowBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(rowBorderColor, lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
        .modifier(
            CompactTimelineDetailsModifier(
                enabled: allowCompactDetailsPopover,
                item: item,
                manager: manager,
                isShowingInfoPopover: $isShowingInfoPopover,
                isEditing: $isEditing,
                editText: $editText,
                editDueDate: $editDueDate,
                infoPopover: compactInfoPopover,
                editPopover: compactEditPopover,
                onSelect: onSelect
            )
        )
    }

    private var sourceLabel: String? {
        switch item.externalSource {
        case .calendar:
            return "Calendar"
        case .reminders:
            return "Reminders"
        case .none:
            return nil
        }
    }

    private var isCalendarEvent: Bool {
        item.externalSource == .calendar
    }

    private var rowBackgroundColor: Color {
        if isSelected {
            return useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.14) : Color.white.opacity(0.16)
        }
        if isCalendarEvent {
            return calendarTint.opacity(0.12)
        }
        return useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.08) : Color.white.opacity(0.06)
    }

    private var rowBorderColor: Color {
        if isSelected {
            return Color.blue.opacity(0.65)
        }
        if isCalendarEvent {
            return calendarTint.opacity(0.25)
        }
        return useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.12) : Color.white.opacity(0.1)
    }

    private var calendarTint: Color {
        guard let hex = item.externalListColorHex else { return .blue }
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return .blue }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    private var compactInfoPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(calendarTint)
                Text("Event Details")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto : .white.opacity(0.95))
                Spacer(minLength: 0)
            }

            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto : .white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)

            if let detailDateLabel {
                Label(detailDateLabel, systemImage: "clock")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.86) : .white.opacity(0.72))
            }

            if let listTitle = item.externalListTitle, !listTitle.isEmpty {
                Label(listTitle, systemImage: "calendar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(calendarTint.opacity(0.95))
            }

            Label("Read-only (Apple Calendar)", systemImage: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.8) : .white.opacity(0.62))
        }
        .padding(12)
        .frame(width: 300)
    }

    private var compactEditPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Task")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AdaptiveColors.secondaryTextAuto)

            TextField("Task title", text: $editText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AdaptiveColors.primaryTextAuto)
                .droppyTextInputChrome(
                    backgroundOpacity: 1.0,
                    borderOpacity: 1.0,
                    useAdaptiveColors: true
                )
                .onSubmit {
                    saveTaskEdits()
                }

            ToDoDueDatePopoverContentLocal(
                dueDate: $editDueDate,
                primaryButtonTitle: nil,
                onPrimary: nil,
                isEmbedded: true,
                setInteractingPopover: { manager.isInteractingWithPopover = $0 }
            )

            HStack(spacing: 10) {
                Button("Cancel") {
                    isEditing = false
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))

                Button("Save") {
                    saveTaskEdits()
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .frame(width: 260)
    }

    private func saveTaskEdits() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        manager.updateTitle(for: item, to: trimmed)
        manager.updateDueDate(for: item, to: editDueDate)
        isEditing = false
    }
}

private struct CompactTimelineDetailsModifier<InfoPopover: View, EditPopover: View>: ViewModifier {
    let enabled: Bool
    let item: ToDoItem
    let manager: ToDoManager
    @Binding var isShowingInfoPopover: Bool
    @Binding var isEditing: Bool
    @Binding var editText: String
    @Binding var editDueDate: Date?
    let infoPopover: InfoPopover
    let editPopover: EditPopover
    let onSelect: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .onTapGesture(count: 2) {
                    onSelect()
                    HapticFeedback.tap()
                    if item.externalSource == .calendar {
                        isEditing = false
                        isShowingInfoPopover = true
                    } else {
                        isShowingInfoPopover = false
                        editText = item.title
                        editDueDate = item.dueDate
                        isEditing = true
                    }
                }
                .popover(
                    isPresented: $isShowingInfoPopover,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .top
                ) {
                    infoPopover
                }
                .popover(isPresented: $isEditing) {
                    editPopover
                }
                .onChange(of: isShowingInfoPopover) { _, _ in
                    manager.isInteractingWithPopover = isShowingInfoPopover || isEditing
                }
                .onChange(of: isEditing) { _, _ in
                    manager.isInteractingWithPopover = isShowingInfoPopover || isEditing
                }
                .onDisappear {
                    manager.isInteractingWithPopover = false
                }
        } else {
            content
        }
    }
}

private struct TaskRow: View {
    let item: ToDoItem
    let manager: ToDoManager
    let reminderListOptions: [ToDoReminderListOption]
    let useAdaptiveForegrounds: Bool
    @State private var isHovering = false
    @State private var isShowingInfoPopover = false
    @State private var isEditing = false
    @State private var editText = ""
    @State private var editDueDate: Date?

    var body: some View {
        HStack(spacing: DroppySpacing.smd) {
            if isCalendarEvent {
                ZStack {
                    Circle()
                        .fill(calendarEventTint.opacity(0.2))
                        .frame(width: 16, height: 16)
                    Image(systemName: "calendar")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(calendarEventTint.opacity(0.95))
                }
                .frame(width: 28, height: 28)
                .help("Calendar event")
            } else {
                // Checkbox - premium circular toggle with smooth animations
                Button {
                    HapticFeedback.medium.perform()
                    withAnimation(DroppyAnimation.stateEmphasis) {
                        manager.toggleCompletion(for: item)
                    }
                } label: {
                    ZStack {
                        // Invisible hit area for reliable clicking
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 28, height: 28)

                        // Outer ring
                        Circle()
                            .stroke(checkboxBorderColor, lineWidth: 1.5)
                            .frame(width: 16, height: 16)

                        // Fill circle when completed - with subtle glow
                        if item.isCompleted {
                            Circle()
                                .fill(Color.green.opacity(0.85))
                                .frame(width: 16, height: 16)
                                .shadow(color: Color.green.opacity(0.3), radius: 4)

                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        } else if isHovering {
                            // Subtle fill on hover to indicate clickability
                            Circle()
                                .fill(useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.08) : Color.white.opacity(0.08))
                                .frame(width: 14, height: 14)
                        }
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isCompleted ? String(localized: "action.mark_incomplete") : String(localized: "action.mark_complete"))
                .animation(DroppyAnimation.bounce, value: item.isCompleted)
                .animation(DroppyAnimation.hoverQuick, value: isHovering)
            }

            // Title with strikethrough animation - color based on priority
            Text(item.title)
                .font(.system(size: 13, weight: isCalendarEvent ? .semibold : (item.isCompleted ? .regular : .medium)))
                .strikethrough(
                    item.isCompleted,
                    color: useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.45) : .white.opacity(0.4)
                )
                .foregroundStyle(
                    item.isCompleted
                        ? (useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.55) : .white.opacity(0.35))
                        : (isCalendarEvent
                            ? calendarEventTint.opacity(0.95)
                            : (useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto.opacity(0.95) : .white.opacity(0.9)))
                )
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(DroppyAnimation.state, value: item.isCompleted)

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
                            .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.85) : .white.opacity(0.48))
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
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(
                    isCalendarEvent
                        ? calendarEventTint.opacity(0.92)
                        : (useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.92) : .white.opacity(0.7))
                )
            }

            // Priority indicator (only for non-normal, non-completed)
            if item.priority != .normal && !item.isCompleted && !isCalendarEvent {
                Circle()
                    .fill(item.priority.color)
                    .frame(width: 6, height: 6)
                    .shadow(color: item.priority.color.opacity(0.4), radius: 2)
                    .transition(.scale.combined(with: .opacity))
            }

            if !isCalendarEvent {
                // Delete button with expanded hit area
                Button {
                    HapticFeedback.delete()
                    withAnimation(DroppyAnimation.itemInsertion) {
                        manager.removeItem(item)
                    }
                } label: {
                    ZStack {
                        // Invisible hit area
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 28, height: 28)

                        Circle()
                            .fill(isHovering ? Color.red.opacity(0.15) : Color.clear)
                            .frame(width: 20, height: 20)

                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(
                                isHovering
                                    ? .red
                                    : (useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.75) : .white.opacity(0.25))
                            )
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0.5)
                .accessibilityLabel(String(localized: "action.delete_task"))
                .animation(DroppyAnimation.hoverQuick, value: isHovering)
            }
        }
        .padding(.horizontal, DroppySpacing.md)
        .padding(.vertical, 6)
        .contentShape(Rectangle()) // Full width hit testing
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isCalendarEvent
                        ? calendarEventTint.opacity(isHovering ? 0.065 : 0.035)
                        : (isHovering
                            ? (useAdaptiveForegrounds ? AdaptiveColors.hoverBackgroundAuto.opacity(0.65) : Color.white.opacity(0.12))
                            : Color.clear)
                )
                .overlay {
                    if isCalendarEvent {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(calendarEventTint.opacity(isHovering ? 0.14 : 0.08), lineWidth: 0.8)
                    }
                }
        )
        .onHover { hovering in
            if hovering { HapticFeedback.hover() }
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            if isCalendarEvent {
                HapticFeedback.tap()
                isEditing = false
                isShowingInfoPopover = true
            } else {
                HapticFeedback.tap()
                hideInfoPopover()
                editText = item.title
                editDueDate = item.dueDate
                isEditing = true
            }
        }
        .animation(DroppyAnimation.hoverQuick, value: isHovering)
        .popover(
            isPresented: $isShowingInfoPopover,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            hoverInfoPopoverContent
                .allowsHitTesting(false)
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

                ToDoDueDatePopoverContentLocal(
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
            if presented {
                hideInfoPopover()
            }
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

                Button {
                    HapticFeedback.medium.perform()
                    withAnimation(DroppyAnimation.state) {
                        manager.updatePriority(for: item, to: .high)
                    }
                } label: {
                    Label(String(localized: "priority.high"), systemImage: "exclamationmark.circle.fill")
                }
                Button {
                    HapticFeedback.medium.perform()
                    withAnimation(DroppyAnimation.state) {
                        manager.updatePriority(for: item, to: .medium)
                    }
                } label: {
                    Label(String(localized: "priority.medium"), systemImage: "exclamationmark.circle")
                }
                Button {
                    HapticFeedback.medium.perform()
                    withAnimation(DroppyAnimation.state) {
                        manager.updatePriority(for: item, to: .normal)
                    }
                } label: {
                    Label(String(localized: "priority.normal"), systemImage: "circle")
                }

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
                    withAnimation(DroppyAnimation.itemInsertion) {
                        manager.removeItem(item)
                    }
                } label: {
                    Label(String(localized: "action.delete"), systemImage: "trash")
                }
            }
        }
    }

    private var checkboxBorderColor: Color {
        if item.isCompleted {
            return Color.green.opacity(0.8)
        }
        if item.priority == .normal {
            return useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.5) : .white.opacity(0.3)
        }
        return item.priority.color.opacity(0.7)
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

    private var hoverInfoPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isCalendarEvent ? "calendar.badge.clock" : "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isCalendarEvent ? calendarEventTint : (useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto : .white.opacity(0.9)))
                Text(isCalendarEvent ? "Event Details" : "Task Details")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto : .white.opacity(0.95))
                Spacer(minLength: 0)
            }

            Divider()
                .background(useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.12) : Color.white.opacity(0.12))

            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto : .white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)

            infoDetailRow(icon: "square.stack.3d.up", label: "Source", value: sourceDetailsLabel)

            if let listTitle = item.externalListTitle, !listTitle.isEmpty {
                infoDetailRow(icon: "list.bullet", label: "List", value: listTitle)
            }

            if let dueDate = item.dueDate {
                infoDetailRow(icon: "clock", label: "Due", value: formattedFullDueDateText(dueDate))
            }

            if !isCalendarEvent {
                infoDetailRow(icon: "flag", label: "Priority", value: item.priority.rawValue.capitalized)
                infoDetailRow(icon: item.isCompleted ? "checkmark.circle.fill" : "circle", label: "Status", value: item.isCompleted ? "Completed" : "Pending")
            } else {
                infoDetailRow(icon: "lock.fill", label: "Access", value: "Read-only")
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    @ViewBuilder
    private func infoDetailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.8) : .white.opacity(0.6))
                .frame(width: 12)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.85) : .white.opacity(0.68))
                .frame(width: 46, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto.opacity(0.95) : .white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var sourceDetailsLabel: String {
        switch item.externalSource {
        case .calendar:
            return "Apple Calendar"
        case .reminders:
            return "Apple Reminders"
        case .none:
            return "Local Task"
        }
    }

    private func hideInfoPopover() {
        isShowingInfoPopover = false
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
            formatter.setLocalizedDateFormatFromTemplate("d MMM jm")
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        }
        return formatter.string(from: date)
    }

    private func formattedFullDueDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        if dueDateHasTime(date) {
            formatter.setLocalizedDateFormatFromTemplate("EEE d MMM yyyy jm")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("EEE d MMM yyyy")
        }
        return formatter.string(from: date)
    }

    private var isCalendarEvent: Bool {
        item.externalSource == .calendar
    }

    private var calendarEventTint: Color {
        colorFromHex(item.externalListColorHex) ?? .blue
    }
}

private extension ToDoShelfBar {
    struct TimelineDaySection: Identifiable {
        let dayStart: Date
        let items: [ToDoItem]
        var id: Date { dayStart }
    }

    enum TimelineContentMode {
        case tasksOnly
        case calendarOnly
        case combined
    }

    var timelineContentMode: TimelineContentMode {
        if manager.isCalendarSyncEnabled && hasVisibleTaskItems {
            return .combined
        }
        if manager.isCalendarSyncEnabled {
            return .calendarOnly
        }
        return .tasksOnly
    }

    var timelineModeTitle: String {
        switch timelineContentMode {
        case .tasksOnly:
            return "Tasks"
        case .calendarOnly:
            return "Calendar"
        case .combined:
            return "Tasks + Calendar"
        }
    }

    var timelineEmptyLabel: String {
        switch timelineContentMode {
        case .tasksOnly:
            return "No tasks for the next days"
        case .calendarOnly:
            return "No calendar events scheduled"
        case .combined:
            return "No tasks or events scheduled"
        }
    }

    var timelineEmptyIcon: String {
        switch timelineContentMode {
        case .tasksOnly:
            return "checklist"
        case .calendarOnly:
            return "calendar"
        case .combined:
            return "calendar.badge.clock"
        }
    }

    var timelineVisibleItems: [ToDoItem] {
        let activeItems = manager.sortedItems.filter { !$0.isCompleted }
        switch timelineContentMode {
        case .tasksOnly:
            return activeItems.filter { $0.externalSource != .calendar }
        case .calendarOnly:
            return activeItems.filter { $0.externalSource == .calendar }
        case .combined:
            return activeItems
        }
    }

    var timelineDaySections: [TimelineDaySection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let maxVisibleDays = 120
        let baselineDays = 10

        var undatedItems: [ToDoItem] = []
        var datedMap: [Date: [ToDoItem]] = [:]
        for item in timelineVisibleItems {
            guard let dueDate = item.dueDate else {
                undatedItems.append(item)
                continue
            }
            let rawDay = calendar.startOfDay(for: dueDate)
            let effectiveDay = rawDay < today ? today : rawDay
            datedMap[effectiveDay, default: []].append(item)
        }

        let farthestDay = datedMap.keys.max() ?? today
        let baselineEnd = calendar.date(byAdding: .day, value: baselineDays, to: today) ?? today
        let endDay = max(farthestDay, baselineEnd)
        let dayDistance = calendar.dateComponents([.day], from: today, to: endDay).day ?? baselineDays
        let renderDays = min(max(dayDistance, baselineDays), maxVisibleDays)

        var sections: [TimelineDaySection] = []
        for offset in 0...renderDays {
            let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            var dayItems = datedMap[day] ?? []
            dayItems.sort { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (left?, right?):
                    if left != right { return left < right }
                case (.none, .some):
                    return true
                case (.some, .none):
                    return false
                case (.none, .none):
                    break
                }
                return lhs.createdAt > rhs.createdAt
            }

            if calendar.isDate(day, inSameDayAs: today) && !undatedItems.isEmpty {
                dayItems = undatedItems + dayItems
            }

            if !dayItems.isEmpty || offset <= 2 {
                sections.append(TimelineDaySection(dayStart: day, items: dayItems))
            }
        }

        if sections.isEmpty {
            sections.append(TimelineDaySection(dayStart: today, items: undatedItems))
        }
        return sections
    }

    var timelineSelectionSignature: Int {
        var hasher = Hasher()
        hasher.combine(timelineVisibleItems.count)
        for item in timelineVisibleItems {
            hasher.combine(item.id)
            hasher.combine(item.isCompleted)
            hasher.combine(item.priority.rawValue)
            hasher.combine(item.dueDate?.timeIntervalSince1970 ?? 0)
        }
        return hasher.finalize()
    }

    var timelineDaySectionSignature: Int {
        var hasher = Hasher()
        hasher.combine(timelineDaySections.count)
        for section in timelineDaySections {
            hasher.combine(section.dayStart.timeIntervalSince1970)
            hasher.combine(section.items.count)
            if let first = section.items.first?.id {
                hasher.combine(first)
            }
            if let last = section.items.last?.id {
                hasher.combine(last)
            }
        }
        return hasher.finalize()
    }

    var hasVisibleTaskItems: Bool {
        manager.sortedItems.contains { item in
            !item.isCompleted && item.externalSource != .calendar
        }
    }

    var selectedTimelineItem: ToDoItem? {
        guard let selectedTimelineItemID else { return nil }
        return timelineVisibleItems.first(where: { $0.id == selectedTimelineItemID })
    }

    func syncTimelineSelection() {
        guard isSplitViewEnabled else {
            selectedTimelineItemID = nil
            return
        }

        let currentIDs = Set(timelineVisibleItems.map(\.id))
        if let selectedTimelineItemID, currentIDs.contains(selectedTimelineItemID) {
            return
        }
        selectedTimelineItemID = timelineVisibleItems.first?.id
    }

    func alignSelectedStripDayWithTimeline() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if !timelineDaySections.isEmpty,
           !timelineDaySections.contains(where: { calendar.isDate($0.dayStart, inSameDayAs: selectedStripDayStart) }) {
            selectedStripDayStart = today
            stripWindowStartDay = today
            timelineScrollTargetDay = today
            timelineScrollTargetItemID = nil
        }
        ensureSelectedDayVisibleInStrip()
    }

    func resolvedTimelineScrollDay(for targetDay: Date) -> Date? {
        guard !timelineDaySections.isEmpty else { return nil }
        let calendar = Calendar.current
        let desired = calendar.startOfDay(for: targetDay)

        if let exact = timelineDaySections.first(where: { calendar.isDate($0.dayStart, inSameDayAs: desired) }) {
            return exact.dayStart
        }
        if let next = timelineDaySections
            .map(\.dayStart)
            .sorted()
            .first(where: { $0 > desired }) {
            return next
        }
        return timelineDaySections.map(\.dayStart).sorted().last
    }

    func ensureSelectedDayVisibleInStrip() {
        let calendar = Calendar.current
        let stripEnd = calendar.date(byAdding: .day, value: 6, to: stripWindowStartDay) ?? stripWindowStartDay
        if selectedStripDayStart < stripWindowStartDay || selectedStripDayStart > stripEnd {
            stripWindowStartDay = selectedStripDayStart
        }
    }

    func updateStripSelectionFromScroll(_ offsets: [Date: CGFloat]) {
        guard !suppressStripSelectionFromScroll else { return }
        guard !offsets.isEmpty else { return }

        // Prefer the last header at/above top edge; else the next one below top.
        let topAnchor: CGFloat = 8
        var nearestAbove: (day: Date, offset: CGFloat)?
        var nearestBelow: (day: Date, offset: CGFloat)?
        for (day, offset) in offsets {
            if offset <= topAnchor {
                if nearestAbove == nil || offset > nearestAbove!.offset {
                    nearestAbove = (day, offset)
                }
            } else if nearestBelow == nil || offset < nearestBelow!.offset {
                nearestBelow = (day, offset)
            }
        }
        guard let candidate = nearestAbove?.day ?? nearestBelow?.day else { return }

        if candidate != selectedStripDayStart {
            selectedStripDayStart = candidate
            ensureSelectedDayVisibleInStrip()
        }
    }

    func suspendStripSelectionSyncDuringProgrammaticScroll(duration: TimeInterval = 0.32) {
        stripScrollSyncWorkItem?.cancel()
        suppressStripSelectionFromScroll = true
        let workItem = DispatchWorkItem {
            suppressStripSelectionFromScroll = false
        }
        stripScrollSyncWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    func timelineDayStart(for item: ToDoItem) -> Date {
        let calendar = Calendar.current
        if let dueDate = item.dueDate {
            return calendar.startOfDay(for: dueDate)
        }
        return calendar.startOfDay(for: Date())
    }

    func shiftDisplayedWeek(by weeks: Int) {
        guard weeks != 0 else { return }
        let calendar = Calendar.current
        let dayOffset = weeks * 7

        if let shiftedStart = calendar.date(byAdding: .day, value: dayOffset, to: stripWindowStartDay) {
            stripWindowStartDay = calendar.startOfDay(for: shiftedStart)
        }

        let shiftedSelected = calendar.date(byAdding: .day, value: dayOffset, to: selectedStripDayStart) ?? stripWindowStartDay
        selectedStripDayStart = calendar.startOfDay(for: shiftedSelected)
        timelineScrollTargetItemID = nil
        timelineScrollTargetDay = selectedStripDayStart
        HapticFeedback.tap()
    }

    func navigateTimelineSelection(step: Int) {
        guard step != 0, !timelineVisibleItems.isEmpty else { return }

        let nextIndex: Int
        if let selectedTimelineItemID,
           let currentIndex = timelineVisibleItems.firstIndex(where: { $0.id == selectedTimelineItemID }) {
            let target = currentIndex + step
            nextIndex = min(max(target, 0), timelineVisibleItems.count - 1)
            if nextIndex == currentIndex {
                return
            }
        } else {
            nextIndex = step > 0 ? 0 : timelineVisibleItems.count - 1
        }

        let nextItem = timelineVisibleItems[nextIndex]
        selectedTimelineItemID = nextItem.id

        let dayStart = timelineDayStart(for: nextItem)
        selectedStripDayStart = dayStart
        ensureSelectedDayVisibleInStrip()
        timelineScrollTargetDay = dayStart
        timelineScrollTargetItemID = TimelineRowRenderID(
            id: nextItem.id,
            isCompleted: nextItem.isCompleted,
            priority: nextItem.priority
        )
    }

    func syncDetailDraftFromSelection() {
        guard isSplitViewEnabled else {
            detailDraftSourceID = nil
            detailTitleDraft = ""
            detailDueDateDraft = nil
            return
        }

        guard let item = selectedTimelineItem else {
            detailDraftSourceID = nil
            detailTitleDraft = ""
            detailDueDateDraft = nil
            return
        }

        if detailDraftSourceID != item.id || detailTitleDraft != item.title || detailDueDateDraft != item.dueDate {
            detailDraftSourceID = item.id
            detailTitleDraft = item.title
            detailDueDateDraft = item.dueDate
        }
    }

    func isCalendarEvent(_ item: ToDoItem) -> Bool {
        item.externalSource == .calendar
    }

    func calendarTint(for item: ToDoItem) -> Color {
        colorFromHex(item.externalListColorHex) ?? .blue
    }

    func colorFromHex(_ hex: String?) -> Color? {
        guard let hex else { return nil }
        let trimmed = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    func formattedTimelineTimeLabel(for item: ToDoItem) -> String {
        guard let dueDate = item.dueDate else { return "Any time" }
        if !dueDateHasTime(dueDate) {
            return "All day"
        }
        return Self.timelineTimeFormatter.string(from: dueDate) + timezoneSuffix(for: dueDate)
    }

    func formattedDayHeader(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return "Today"
        }
        if calendar.isDateInTomorrow(day) {
            return "Tomorrow"
        }

        return Self.timelineDayHeaderFormatter.string(from: day)
    }

    func formattedDetailDate(for date: Date) -> String {
        if dueDateHasTime(date) {
            return Self.detailDateTimeFormatter.string(from: date) + timezoneSuffix(for: date)
        } else {
            return Self.detailDateFormatter.string(from: date)
        }
    }

    func timezoneSuffix(for date: Date) -> String {
        guard showTaskViewTimezone,
              let abbreviation = TimeZone.autoupdatingCurrent.abbreviation(for: date) else {
            return ""
        }
        return " \(abbreviation)"
    }

    func dueDateHasTime(_ date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
    }

    var incompleteCount: Int {
        manager.items.reduce(0) { count, item in
            guard !item.isCompleted else { return count }
            guard item.externalSource != .calendar else { return count }
            return count + 1
        }
    }

    var incompleteCountLabel: String {
        incompleteCount > 99 ? "99+" : "\(incompleteCount)"
    }

    var shouldLiftUndoToast: Bool {
        isListExpanded && manager.items.isEmpty && manager.showUndoToast
    }

    var undoToastAlignment: Alignment {
        shouldLiftUndoToast ? .top : .bottom
    }

    var undoToastPadding: EdgeInsets {
        if shouldLiftUndoToast {
            return EdgeInsets(top: Layout.undoToastTopPadding, leading: 0, bottom: 0, trailing: 0)
        }
        return EdgeInsets(top: 0, leading: 0, bottom: Layout.undoToastBottomPadding, trailing: 0)
    }

    var emptyStateTopPadding: CGFloat {
        let undoInset = shouldLiftUndoToast ? Layout.undoToastEmptyStateClearance : 0
        return undoInset
    }

    var topToolbarLift: CGFloat {
        guard notchHeight > 0 else { return 0 }
        if isSplitViewEnabled {
            // In split view, left/right toolbar controls sit outside the physical notch area,
            // so we can safely lift them higher for tighter top alignment.
            return min(44, notchHeight * 1.12)
        }
        return min(28, notchHeight * 0.72)
    }

    var visibleStripWeekNumber: Int {
        Calendar.current.component(.weekOfYear, from: stripWindowStartDay)
    }

    private static let timelineTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter
    }()

    private static let timelineDayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter
    }()

    private static let detailDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM yyyy jm")
        return formatter
    }()

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM yyyy")
        return formatter
    }()
}

// MARK: - Height Calculator

extension ToDoShelfBar {
    /// Returns the height this bar needs when expanded
    static func expandedHeight(isListExpanded: Bool, itemCount: Int, notchHeight: CGFloat = 0, showsUndoToast: Bool = false) -> CGFloat {
        // Includes the host view bottom inset used in NotchShelfView so content sizing stays in sync.
        let totalBottomInset = Layout.internalBottomPadding + hostBottomInset
        let collapsedHeight = Layout.inputBarHeight + totalBottomInset

        if !isListExpanded {
            return collapsedHeight
        }

        if itemCount == 0 {
            let spacingToInput = Layout.emptyListBottomSpacing
            let undoClearance: CGFloat = showsUndoToast ? Layout.undoToastEmptyStateClearance : 0
            return Layout.timelineHeaderHeight + Layout.emptyStateHeight + undoClearance + spacingToInput + collapsedHeight
        }

        let spacingToInput = Layout.listBottomSpacing
        return Layout.timelineHeaderHeight + Layout.listHeight + spacingToInput + collapsedHeight
    }
}

#Preview {
    ZStack {
        Color.black
        ToDoShelfBar(
            manager: ToDoManager.shared,
            isListExpanded: .constant(true),
            notchHeight: 38  // Typical notch height for preview
        )
        .frame(width: 350)
        .padding()
    }
}
