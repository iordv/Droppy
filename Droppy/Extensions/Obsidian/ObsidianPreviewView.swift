//
//  ObsidianPreviewView.swift
//  Droppy
//
//  Static preview of the Obsidian extension for the extension store
//

import SwiftUI

struct ObsidianPreviewView: View {
    var body: some View {
        VStack(spacing: 8) {
            // Pinned note chips
            HStack(spacing: 6) {
                previewChip(name: "Daily Log", isSelected: true)
                previewChip(name: "Inbox", isSelected: false)
                previewChip(name: "Meeting Notes", isSelected: false)
            }

            // Quick panel mock
            VStack(spacing: 6) {
                // Heading picker
                HStack {
                    Image(systemName: "number")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("## Today's Tasks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Text input mock
                HStack {
                    Text("Buy groceries for dinner")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                )

                // Action buttons
                HStack(spacing: 6) {
                    previewButton(title: "Prepend", icon: "arrow.up.doc")
                    previewButton(title: "Append", icon: "arrow.down.doc", isHighlighted: true)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        }
        .padding(12)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
        )
    }

    private func previewChip(name: String, isSelected: Bool) -> some View {
        Text(name)
            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.purple.opacity(0.3) : AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .foregroundStyle(isSelected ? .white : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.purple.opacity(0.6) : AdaptiveColors.subtleBorderAuto,
                    lineWidth: 1
                )
            )
    }

    private func previewButton(title: String, icon: String, isHighlighted: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(title)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isHighlighted ? Color.purple.opacity(0.3) : AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .foregroundStyle(isHighlighted ? .white : .secondary)
        .clipShape(Capsule())
    }
}
