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
    
    var body: some View {
        VStack(spacing: 12) {
            // Header: Input (Capsule Style)
            HStack(spacing: 8) {
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
                        .background(Color.white.opacity(0.1))
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
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "action.set_priority"))
                .accessibilityValue(manager.newItemPriority.rawValue)
                .accessibilityHint("Cycles through high, medium, and normal priority")

                // Text Input
                TextField(String(localized: "add_task_placeholder"), text: Bindable(manager).newItemText)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 100) // Constraint for layout engine
                    .font(.system(size: 14))
                    .focused($isInputFocused)
                    .onSubmit {
                        submitTask()
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
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.6))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
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
                        ForEach(manager.sortedItems) { item in
                            ToDoRow(item: item, manager: manager)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            
                            // Subtle separator
                            if item.id != manager.sortedItems.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 32)
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.showUndoToast)
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func submitTask() {
        HapticFeedback.drop()
        manager.addItem(title: manager.newItemText, priority: manager.newItemPriority)
        // Keep focus
        isInputFocused = true
    }
}

struct ToDoRow: View {
    let item: ToDoItem
    let manager: ToDoManager
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        HStack(spacing: DroppySpacing.smd) {
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
            // Title - color based on priority
            Text(item.title)
                .font(.system(size: 13, weight: item.isCompleted ? .regular : .medium))
                .strikethrough(item.isCompleted)
                .foregroundColor(item.isCompleted ? .secondary : (item.priority == .normal ? .primary : item.priority.color))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Stats / Controls
            HStack(spacing: 8) {
                // Priority Indicator (only if not normal or completed)
                if item.priority != .normal && !item.isCompleted {
                    Image(systemName: item.priority.icon)
                        .foregroundColor(item.priority.color)
                        .font(.caption)
                }
                
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
        .padding(.horizontal, DroppySpacing.md)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.white.opacity(0.08) : Color.clear)
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
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "action.edit"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                TextField(String(localized: "task_title"), text: $editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .onSubmit {
                        if !editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            manager.updateTitle(for: item, to: editText)
                            isEditing = false
                        }
                    }
                
                HStack(spacing: 12) {
                    Button {
                        isEditing = false
                    } label: {
                        Text(String(localized: "action.cancel"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        manager.updateTitle(for: item, to: editText)
                        isEditing = false
                    } label: {
                        Text(String(localized: "action.save"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.blue.opacity(0.4) : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
            .frame(width: 260)
        }
        .contextMenu {
            Button(String(localized: "action.edit")) {
                editText = item.title
                isEditing = true
            }
            .keyboardShortcut("e", modifiers: [.command])
            
            Divider()
            
            Button("priority.high") {
                HapticFeedback.medium.perform()
                manager.updatePriority(for: item, to: .high)
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("priority.medium") {
                HapticFeedback.medium.perform()
                manager.updatePriority(for: item, to: .medium)
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("priority.normal") {
                HapticFeedback.medium.perform()
                manager.updatePriority(for: item, to: .normal)
            }
            .keyboardShortcut("3", modifiers: [.command])

            Divider()

            Button("action.delete", role: .destructive) {
                HapticFeedback.delete()
                manager.removeItem(item)
            }
        }
    }
}
