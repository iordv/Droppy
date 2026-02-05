//
//  ToDoShelfBar.swift
//  Droppy
//
//  Persistent todo input bar that integrates into the shelf
//  Shows at bottom of shelf when Todo extension is installed
//

import SwiftUI
import UniformTypeIdentifiers

struct ToDoShelfBar: View {
    var manager: ToDoManager
    @Binding var isListExpanded: Bool
    var notchHeight: CGFloat = 0  // Height of physical notch to clear

    @State private var inputText: String = ""
    @State private var inputPriority: ToDoPriority = .normal
    @State private var isInputBarHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Task list (expandable) - appears above input bar
            if isListExpanded {
                taskListSection
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).combined(with: .opacity),
                        removal: .push(from: .top).combined(with: .opacity)
                    ))
            }

            // Input bar (always visible)
            inputBar
        }
        .padding(.bottom, 4)
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
                .padding(.bottom, 60) // Position above input bar
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DroppyAnimation.expandOpen, value: isListExpanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.showUndoToast)

    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: DroppySpacing.smd) {
            // Priority indicator (left)
            priorityDot

            // Text input (center)
            textField

            // Task count + list toggle (right)
            listToggle
        }
        .padding(.horizontal, DroppySpacing.smd)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    Color.white.opacity(isInputBarHovered ? 0.15 : 0.08),
                    lineWidth: 1
                )
        )
        .frame(maxWidth: .infinity)
        .onHover { hovering in
            isInputBarHovered = hovering
        }
        .animation(DroppyAnimation.hoverQuick, value: isInputBarHovered)
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
                    .frame(width: 28, height: 28)

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
        .accessibilityLabel("Set priority")
        .accessibilityValue(inputPriority.rawValue)
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

    private var textField: some View {
        // Use custom NSTextField wrapper to avoid SwiftUI TextField constraint warnings
        // SwiftUI's TextField has a known bug with floating-point precision during animations
        StableTextField(
            text: $inputText,
            placeholder: String(localized: "add_task_placeholder"),
            onSubmit: submitTask
        )
        .frame(height: 20)
    }

    private var listToggle: some View {
        Button {
            HapticFeedback.medium.perform()
            withAnimation(DroppyAnimation.expandOpen) {
                isListExpanded.toggle()
            }
        } label: {
            HStack(spacing: DroppySpacing.xs) {
                // Task count badge
                let incompleteCount = manager.items.filter { !$0.isCompleted }.count
                if incompleteCount > 0 {
                    Text("\(incompleteCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.9)))
                        .transition(.scale.combined(with: .opacity))
                }

                Image(systemName: isListExpanded ? "chevron.down" : "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isListExpanded ? .white : .white.opacity(0.6))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, DroppySpacing.smd)
            .padding(.vertical, DroppySpacing.xsm)
            .background(
                Capsule()
                    .fill(isListExpanded ? Color.blue.opacity(0.8) : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .help(isListExpanded ? "Hide task list" : "Show task list")
        .accessibilityLabel(isListExpanded ? "Hide tasks" : "Show tasks")
        .animation(DroppyAnimation.state, value: isListExpanded)
        .animation(DroppyAnimation.state, value: manager.items.filter { !$0.isCompleted }.count)
    }

    // MARK: - Task List

    private var taskListSection: some View {
        VStack(spacing: 0) {
            if manager.items.isEmpty {
                // Empty state with notch clearance built-in
                emptyState
                    .padding(.top, notchHeight > 0 ? notchHeight + 4 : 0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    // CRITICAL FIX: Use VStack instead of LazyVStack to prevent NSGenericException layout loops during drag
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(manager.sortedItems, id: \.id) { item in
                            TaskRow(item: item, manager: manager)
                                .id("\(item.id)-\(item.isCompleted)-\(item.priority.rawValue)")
                            
                            // Subtle separator
                            if item.id != manager.sortedItems.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 32)
                            }
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .padding(.horizontal, 8)
                }
                .frame(height: 180)
            }

            // Spacer between list and input bar
            Spacer()
                .frame(height: 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DroppySpacing.xsm) {
            // Subtle icon with gradient
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 36, height: 36)
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            Text("no_tasks_yet")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80) // Fixed height for consistent layout
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
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        HapticFeedback.drop()

        withAnimation(DroppyAnimation.itemInsertion) {
            manager.addItem(title: trimmed, priority: inputPriority)
        }

        // Reset with animation
        withAnimation(DroppyAnimation.state) {
            inputText = ""
            inputPriority = .normal
        }
    }
}



// MARK: - Task Row

private struct TaskRow: View {
    let item: ToDoItem
    let manager: ToDoManager
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: DroppySpacing.smd) {
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
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 14, height: 14)
                    }
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isCompleted ? String(localized: "action.mark_incomplete") : String(localized: "action.mark_complete"))
            .animation(DroppyAnimation.bounce, value: item.isCompleted)
            .animation(DroppyAnimation.hoverQuick, value: isHovering)

            // Title with strikethrough animation - color based on priority
            Text(item.title)
                .font(.system(size: 13, weight: item.isCompleted ? .regular : .medium))
                .strikethrough(item.isCompleted, color: .white.opacity(0.4))
                .foregroundStyle(item.isCompleted ? .white.opacity(0.35) : (item.priority == .normal ? .white.opacity(0.9) : item.priority.color))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(DroppyAnimation.state, value: item.isCompleted)

            // Priority indicator (only for non-normal, non-completed)
            if item.priority != .normal && !item.isCompleted {
                Circle()
                    .fill(item.priority.color)
                    .frame(width: 6, height: 6)
                    .shadow(color: item.priority.color.opacity(0.4), radius: 2)
                    .transition(.scale.combined(with: .opacity))
            }

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
                        .foregroundStyle(isHovering ? .red : .white.opacity(0.25))
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.5)
            .accessibilityLabel(String(localized: "action.delete_task"))
            .animation(DroppyAnimation.hoverQuick, value: isHovering)
        }
        .padding(.horizontal, DroppySpacing.md)
        .padding(.vertical, 6)
        .contentShape(Rectangle()) // Full width hit testing
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.white.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            if hovering { HapticFeedback.hover() }
            isHovering = hovering
        }
        .animation(DroppyAnimation.hoverQuick, value: isHovering)
        .contextMenu {
            Button("priority.high") {
                HapticFeedback.medium.perform()
                withAnimation(DroppyAnimation.state) {
                    manager.updatePriority(for: item, to: .high)
                }
            }
            Button("priority.medium") {
                HapticFeedback.medium.perform()
                withAnimation(DroppyAnimation.state) {
                    manager.updatePriority(for: item, to: .medium)
                }
            }
            Button("priority.normal") {
                HapticFeedback.medium.perform()
                withAnimation(DroppyAnimation.state) {
                    manager.updatePriority(for: item, to: .normal)
                }
            }
            Divider()
            Button("action.delete", role: .destructive) {
                HapticFeedback.delete()
                withAnimation(DroppyAnimation.itemInsertion) {
                    manager.removeItem(item)
                }
            }
        }
    }

    private var checkboxBorderColor: Color {
        if item.isCompleted {
            return Color.green.opacity(0.8)
        }
        return item.priority == .normal ? .white.opacity(0.3) : item.priority.color.opacity(0.7)
    }

    private var backgroundColor: Color {
        if isHovering {
            return Color.white.opacity(0.08)
        }
        return Color.white.opacity(0.04)
    }
}

// MARK: - Stable TextField (NSViewRepresentable)

/// Custom NSTextField subclass that returns a fixed intrinsic content size
/// This prevents SwiftUI's layout system from causing constraint warnings during animations
private class FixedSizeTextField: NSTextField {
    override var intrinsicContentSize: NSSize {
        // Return a fixed size to prevent layout thrashing during animations
        return NSSize(width: NSView.noIntrinsicMetric, height: 20)
    }
}

/// Custom NSTextField wrapper that avoids SwiftUI's TextField constraint warnings
/// SwiftUI's TextField has a bug where floating-point precision issues during animations
/// cause spurious "min <= max" constraint warnings. This wrapper uses AppKit directly
/// with a fixed intrinsic content size.
private struct StableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = FixedSizeTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        textField.textColor = NSColor.white.withAlphaComponent(0.9)
        textField.backgroundColor = .clear
        textField.isBordered = false
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.cell?.isScrollable = true
        textField.cell?.wraps = false
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false
        // Completely disable content size priorities to prevent ANY constraint conflicts
        textField.setContentHuggingPriority(.init(1), for: .horizontal)
        textField.setContentHuggingPriority(.init(1), for: .vertical)
        textField.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        textField.setContentCompressionResistancePriority(.init(1), for: .vertical)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: StableTextField

        init(_ parent: StableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

// MARK: - Height Calculator

extension ToDoShelfBar {
    /// Returns the height this bar needs when expanded
    static func expandedHeight(isListExpanded: Bool, itemCount: Int, notchHeight: CGFloat = 0) -> CGFloat {
        // Input bar height
        let inputBarHeight: CGFloat = 32

        if !isListExpanded {
            return inputBarHeight
        }

        // Separator: 1pt line + 4pt bottom padding
        let separatorHeight: CGFloat = 5
        
        // CRITICAL FIX: Add safe bottom padding to prevent clipping when window corner radius is large
        // This ensures the input bar always sits comfortably above the window edge
        let safeBottomPadding: CGFloat = 12

        // Empty state
        if itemCount == 0 {
            let emptyStateHeight: CGFloat = 80
            let notchPadding: CGFloat = notchHeight > 0 ? notchHeight + 4 : 0
            return inputBarHeight + emptyStateHeight + separatorHeight + notchPadding + safeBottomPadding
        }

        // Task list - fixed height of 180 (scrollable when content exceeds)
        let listHeight: CGFloat = 180

        return inputBarHeight + listHeight + separatorHeight + safeBottomPadding
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
