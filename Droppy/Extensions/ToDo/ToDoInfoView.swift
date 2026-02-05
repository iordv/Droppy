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
    @State private var showReviewsSheet = false

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
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .todo)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: "checklist")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 64, height: 64)
                .background(Color.blue.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)

            Text("To-do")
                .font(.title2.bold())

            // Stats Row
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
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

            Text("Quick task capture and checklist")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "checkmark.circle.fill", text: "Quick task capture from the shelf")
            featureRow(icon: "list.bullet", text: "Priority levels with color coding")
            featureRow(icon: "timer", text: "Auto-cleanup of completed tasks")
            featureRow(icon: "keyboard", text: "Keyboard shortcuts for power users")

            // Preview
            ToDoPreviewView()
                .padding(.top, 8)
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
                        Text("1 hour").tag(1)
                        Text("2 hours").tag(2)
                        Text("5 hours").tag(5)
                        Text("12 hours").tag(12)
                        Text("24 hours").tag(24)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)
                }
                .padding(DroppySpacing.md)
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
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
            Divider().background(Color.white.opacity(0.1)).padding(.leading, 32)
            
            previewRow(title: "Update documentation", priority: .medium, isCompleted: false)
            Divider().background(Color.white.opacity(0.1)).padding(.leading, 32)
            
            previewRow(title: "Fix login bug", priority: .normal, isCompleted: true)
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
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
                .foregroundColor(isCompleted ? .secondary : (priority == .normal ? .primary : priority.color))
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
