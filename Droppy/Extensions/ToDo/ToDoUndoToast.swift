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
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.8))
            
            Text("Task deleted")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {
                HapticFeedback.medium.perform()
                onUndo()
            } label: {
                Text("Undo")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
        .frame(maxWidth: 300)
    }
}
