//
//  ToDoUndoToast.swift
//  Droppy
//
//  Transient toast notification for undoing actions
//

import SwiftUI

struct ToDoUndoToast: View {
    var onUndo: () -> Void
    var onDismiss: () -> Void
    var useAdaptiveColors: Bool = true
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.fill")
                .font(.system(size: 11))
                .foregroundStyle(
                    useAdaptiveColors
                        ? AdaptiveColors.secondaryTextAuto.opacity(0.85)
                        : .white.opacity(0.8)
                )
            
            Text("task_deleted")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(useAdaptiveColors ? AdaptiveColors.primaryTextAuto : .white)
            
            Spacer()
            
            Button {
                HapticFeedback.medium.perform()
                onUndo()
            } label: {
                Text("undo")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(
                        useAdaptiveColors
                            ? AdaptiveColors.secondaryTextAuto.opacity(0.5)
                            : .white.opacity(0.4)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 36)
        .background(
            Capsule()
                .fill(AdaptiveColors.buttonBackgroundAuto.opacity(0.95))
        )
        .overlay(
            Capsule()
                .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
        .frame(maxWidth: 300)
    }
}

struct ToDoCleanupToast: View {
    let count: Int
    var onDismiss: () -> Void
    var useAdaptiveColors: Bool = true
    
    private var message: String {
        String.localizedStringWithFormat(String(localized: "tasks_cleaned_up %lld"), Int64(count))
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.green.opacity(0.95))
            
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(
                    useAdaptiveColors
                        ? AdaptiveColors.primaryTextAuto.opacity(0.9)
                        : .white.opacity(0.9)
                )
                .lineLimit(1)
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(
                        useAdaptiveColors
                            ? AdaptiveColors.secondaryTextAuto.opacity(0.55)
                            : .white.opacity(0.45)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.16))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.green.opacity(0.35), lineWidth: 1)
        )
    }
}
