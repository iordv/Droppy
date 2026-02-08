//
//  ToDoShelfBar.swift
//  Droppy
//
//  Persistent todo input bar that integrates into the shelf
//  Shows at bottom of shelf when Todo extension is installed
//

import SwiftUI
import AppKit

struct ToDoShelfBar: View {
    static let hostHorizontalInset: CGFloat = 30
    static let hostBottomInset: CGFloat = 20

    var manager: ToDoManager
    @Binding var isListExpanded: Bool
    var notchHeight: CGFloat = 0  // Height of physical notch to clear
    var useAdaptiveForegroundsForTransparentNotch: Bool = false
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground

    @State private var inputText: String = ""
    @State private var inputPriority: ToDoPriority = .normal
    @State private var inputDueDate: Date?
    @State private var inputReminderListID: String?
    @State private var showingInputDueDatePicker = false
    @State private var isInputBarHovered = false
    @State private var activeListMentionQuery: String?
    @State private var showingMentionPicker = false

    private var useAdaptiveForegrounds: Bool {
        useTransparentBackground && useAdaptiveForegroundsForTransparentNotch
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
        static let listHeight: CGFloat = 180
        static let listTopPadding: CGFloat = 12
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
                        withAnimation {
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
                        withAnimation(.smooth(duration: 0.25)) {
                            manager.showCleanupToast = false
                        }
                    },
                    useAdaptiveColors: useAdaptiveForegrounds
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.35), value: isListExpanded)
        .animation(.smooth(duration: 0.35), value: manager.items.count)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.showUndoToast)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.showCleanupToast)
        .onAppear {
            if manager.isRemindersSyncEnabled || manager.isCalendarSyncEnabled {
                manager.syncExternalSourcesNow()
            }
            if manager.isRemindersSyncEnabled {
                manager.refreshReminderListsNow()
            }
        }
        .onChange(of: showingInputDueDatePicker) { _, showing in
            manager.isInteractingWithPopover = showing
        }
        .onChange(of: showingMentionPicker) { _, showing in
            manager.isInteractingWithPopover = showing
        }
        .onChange(of: isListExpanded) { _, expanded in
            manager.isShelfListExpanded = expanded
            NotchWindowController.shared.forceRecalculateAllWindowSizes()
            guard expanded else { return }
            if manager.isRemindersSyncEnabled || manager.isCalendarSyncEnabled {
                manager.syncExternalSourcesNow()
            }
        }
        .onDisappear {
            manager.isInteractingWithPopover = false
            manager.isEditingText = false
        }
        .onChange(of: inputText) { _, newValue in
            refreshListMentionState(for: newValue)
        }
        .onChange(of: manager.availableReminderLists) { _, _ in
            showingMentionPicker = shouldShowMentionTooltip
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
            withAnimation(.smooth(duration: 0.35)) {
                isListExpanded = nextExpanded
            }
            // Apply once more on the next runloop tick to catch any deferred layout pass.
            DispatchQueue.main.async {
                NotchWindowController.shared.forceRecalculateAllWindowSizes()
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
            if manager.items.isEmpty {
                // Empty state with notch clearance built-in
                emptyState
                    .padding(.top, emptyStateTopPadding)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    // CRITICAL FIX: Use VStack instead of LazyVStack to prevent NSGenericException layout loops during drag
                    VStack(alignment: .leading, spacing: 1) {
                        if !overviewTaskItems.isEmpty {
                            ForEach(Array(overviewTaskItems.enumerated()), id: \.element.id) { index, item in
                                TaskRow(
                                    item: item,
                                    manager: manager,
                                    reminderListOptions: reminderListMenuOptions,
                                    useAdaptiveForegrounds: useAdaptiveForegrounds
                                )
                                    .id("\(item.id)-\(item.isCompleted)-\(item.priority.rawValue)")

                                if index < overviewTaskItems.count - 1 {
                                    Divider()
                                        .background(useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.06) : Color.white.opacity(0.06))
                                        .padding(.horizontal, 24)
                                }
                            }
                        }

                        if !upcomingCalendarItems.isEmpty {
                            if !overviewTaskItems.isEmpty {
                                Divider()
                                    .background(useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.08) : Color.white.opacity(0.08))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 4)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Upcoming Events")
                                    .font(.system(size: 10, weight: .semibold))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(
                                useAdaptiveForegrounds
                                    ? AdaptiveColors.secondaryTextAuto.opacity(0.85)
                                    : .white.opacity(0.72)
                            )
                            .padding(.horizontal, 24)
                            .padding(.vertical, 4)

                            ForEach(Array(upcomingCalendarItems.enumerated()), id: \.element.id) { index, item in
                                TaskRow(
                                    item: item,
                                    manager: manager,
                                    reminderListOptions: reminderListMenuOptions,
                                    useAdaptiveForegrounds: useAdaptiveForegrounds
                                )
                                    .id("\(item.id)-\(item.isCompleted)-\(item.priority.rawValue)")

                                if index < upcomingCalendarItems.count - 1 {
                                    Divider()
                                        .background(useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.06) : Color.white.opacity(0.06))
                                        .padding(.horizontal, 24)
                                }
                            }
                        }
                    }
                    .padding(.top, Layout.listTopPadding)
                    .padding(.bottom, Layout.listBottomPadding)
                    .padding(.horizontal, Layout.listHorizontalPadding)
                }
                .frame(height: Layout.listHeight)
                .clipShape(Rectangle())
                .overlay(alignment: .bottom) {
                    if showsBottomListScrim {
                        bottomListScrim
                            .transition(.opacity)
                    }
                }
            }

            // Spacer between list and input bar
            Spacer()
                .frame(height: manager.items.isEmpty ? Layout.emptyListBottomSpacing : Layout.listBottomSpacing)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var emptyState: some View {
        VStack(spacing: DroppySpacing.xsm) {
            // Subtle icon with gradient
            ZStack {
                Circle()
                    .fill(useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.04) : Color.white.opacity(0.04))
                    .frame(width: 36, height: 36)
                Image(systemName: "checklist")
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
            Text("no_tasks_yet")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(0.75) : .white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: Layout.emptyStateHeight, alignment: .center) // Fixed height for consistent layout
    }

    private var bottomListScrim: some View {
        LinearGradient(
            colors: useTransparentBackground
                ? [
                    Color.clear,
                    (useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.03) : Color.white.opacity(0.03)),
                    (useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.07) : Color.white.opacity(0.07))
                ]
                : [
                    Color.clear,
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.24)
                ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 6)
        .compositingGroup()
        .mask(
            LinearGradient(
                colors: [.clear, .white],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .allowsHitTesting(false)
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



// MARK: - Task Row

private struct TaskRow: View {
    let item: ToDoItem
    let manager: ToDoManager
    let reminderListOptions: [ToDoReminderListOption]
    let useAdaptiveForegrounds: Bool
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
                        ? calendarEventTint.opacity(isHovering ? 0.16 : 0.1)
                        : (isHovering
                            ? (useAdaptiveForegrounds ? AdaptiveColors.hoverBackgroundAuto.opacity(0.65) : Color.white.opacity(0.12))
                            : Color.clear)
                )
        )
        .onHover { hovering in
            if hovering { HapticFeedback.hover() }
            isHovering = hovering
        }
        .animation(DroppyAnimation.hoverQuick, value: isHovering)
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
        colorFromHex(item.externalListColorHex) ?? .blue
    }
}

private extension ToDoShelfBar {
    var showsBottomListScrim: Bool {
        isListExpanded && manager.sortedItems.count > 4
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

    var overviewTaskItems: [ToDoItem] {
        manager.overviewTaskItems
    }

    var upcomingCalendarItems: [ToDoItem] {
        manager.upcomingCalendarItems
    }
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
            return Layout.emptyStateHeight + undoClearance + spacingToInput + collapsedHeight
        }

        let spacingToInput = Layout.listBottomSpacing
        return Layout.listHeight + spacingToInput + collapsedHeight
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
