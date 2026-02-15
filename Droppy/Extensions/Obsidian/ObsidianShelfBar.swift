//
//  ObsidianShelfBar.swift
//  Droppy
//
//  Shelf bar showing pinned note chips and expandable quick panel / full editor
//

import SwiftUI
import UniformTypeIdentifiers

struct ObsidianShelfBar: View {
    static let hostHorizontalInset: CGFloat = 30
    static let hostBottomInset: CGFloat = 20

    var manager: ObsidianManager
    @Binding var isQuickPanelExpanded: Bool
    var notchHeight: CGFloat = 0
    var isExternalWithNotchStyle: Bool = false

    @State private var isChipBarHovered: Bool = false

    private enum Layout {
        static let sidebarWidth: CGFloat = 200
        static let splitViewHeight: CGFloat = 340
        static let quickPanelContentHeight: CGFloat = 132
        static let chipBarVisibleHeight: CGFloat = 28
        static let stackSpacing: CGFloat = 6
        static let noteRowVerticalPadding: CGFloat = 6
    }

    private var contentPadding: EdgeInsets {
        NotchLayoutConstants.contentEdgeInsets(notchHeight: notchHeight, isExternalWithNotchStyle: isExternalWithNotchStyle)
    }

    // MARK: - Height Calculator

    static func expandedHeight(
        isQuickPanelExpanded: Bool,
        isFullEditorExpanded: Bool,
        notchHeight: CGFloat = 0
    ) -> CGFloat {
        let contentInsets = NotchLayoutConstants.contentEdgeInsets(notchHeight: notchHeight)
        let contentHeight: CGFloat
        if isFullEditorExpanded {
            contentHeight = Layout.splitViewHeight
        } else if isQuickPanelExpanded {
            contentHeight = Layout.quickPanelContentHeight + Layout.stackSpacing + Layout.chipBarVisibleHeight
        } else {
            contentHeight = Layout.chipBarVisibleHeight
        }
        return contentInsets.top + contentHeight + contentInsets.bottom
    }

    // MARK: - Body

    var body: some View {
        Group {
            if manager.isFullEditorExpanded {
                splitEditorView
                    .notchTransitionBlurOnly()
            } else {
                VStack(spacing: 6) {
                    if isQuickPanelExpanded, manager.selectedNote != nil {
                        ObsidianQuickPanel(manager: manager)
                            .notchTransitionBlurOnly()
                    }
                    chipBar
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(contentPadding)
        .animation(DroppyAnimation.smoothContent, value: isQuickPanelExpanded)
        .animation(DroppyAnimation.smoothContent, value: manager.isFullEditorExpanded)
        .animation(DroppyAnimation.smoothContent, value: manager.pinnedNotes.count)
    }

    // MARK: - Split Editor View

    private var splitEditorView: some View {
        HStack(spacing: 0) {
            sidebarColumn
                .frame(width: Layout.sidebarWidth)
                .frame(maxHeight: .infinity, alignment: .top)

            // Subtle vertical divider
            Color.white.opacity(0.08)
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            ObsidianFullEditor(manager: manager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Layout.splitViewHeight)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Sidebar

    private var sidebarColumn: some View {
        VStack(spacing: 0) {
            // Header
            sidebarHeader
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 6)

            // Pinned notes list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(manager.pinnedNotes) { note in
                        sidebarNoteRow(note)
                    }

                    addNoteRow
                }
                .padding(.horizontal, 6)
            }
        }
        .background(Color.white.opacity(0.04))
    }

    private var sidebarHeader: some View {
        HStack {
            Text("Notes")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Button {
                withAnimation(DroppyAnimation.smooth) {
                    manager.isFullEditorExpanded = false
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
    }

    private func sidebarNoteRow(_ note: PinnedNote) -> some View {
        let isSelected = manager.selectedNoteID == note.id
        let exists = manager.noteExists(note)

        return Button {
            withAnimation(DroppyAnimation.smooth(duration: 0.18)) {
                manager.selectNote(note)
            }
        } label: {
            HStack(spacing: 6) {
                // Icon
                Group {
                    if note.isDaily {
                        Image(systemName: "calendar")
                    } else if !exists {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Image(systemName: "doc.text")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                .frame(width: 14)

                // Title
                Text(note.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, Layout.noteRowVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: DroppyRadius.sm, style: .continuous)
                    .fill(isSelected ? Color.purple.opacity(0.3) : Color.clear)
            )
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.purple.opacity(0.9))
                    .frame(width: 2.5, height: isSelected ? 18 : 2.5)
                    .opacity(isSelected ? 0.9 : 0.0)
                    .animation(DroppyAnimation.smooth(duration: 0.2), value: isSelected)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove from shelf") {
                manager.removePinnedNote(note)
            }
            if let heading = note.defaultHeading {
                Button("Clear default heading (\(heading))") {
                    manager.updateDefaultHeading(for: note.id, heading: nil)
                }
            }
        }
    }

    private var addNoteRow: some View {
        Button {
            openNotePicker()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 14)
                Text("Pin Note")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 8)
            .padding(.vertical, Layout.noteRowVerticalPadding)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chip Bar

    private var chipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if manager.vaultStatus == .notConfigured || manager.vaultPath.isEmpty {
                    setupChip
                } else {
                    ForEach(manager.pinnedNotes) { note in
                        noteChip(note)
                    }

                    // Add note button
                    addNoteChip
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: Layout.chipBarVisibleHeight)
    }

    private var setupChip: some View {
        Button {
            openVaultPicker()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 11))
                Text("Set up Obsidian")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.2))
            .foregroundStyle(.white.opacity(0.9))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(Color.purple.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func noteChip(_ note: PinnedNote) -> some View {
        let isSelected = manager.selectedNoteID == note.id
        let exists = manager.noteExists(note)

        return Button {
            withAnimation(DroppyAnimation.smooth) {
                if isSelected {
                    manager.deselectNote()
                    isQuickPanelExpanded = false
                } else {
                    manager.selectNote(note)
                    isQuickPanelExpanded = true
                }
            }
        } label: {
            HStack(spacing: 4) {
                if note.isDaily {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                } else if !exists {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
                Text(note.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.purple.opacity(0.3) : Color.white.opacity(0.10))
            .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.purple.opacity(0.6) : Color.white.opacity(0.15),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove from shelf") {
                manager.removePinnedNote(note)
            }
            if let heading = note.defaultHeading {
                Button("Clear default heading (\(heading))") {
                    manager.updateDefaultHeading(for: note.id, heading: nil)
                }
            }
        }
    }

    private var addNoteChip: some View {
        Button {
            openNotePicker()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.10))
                .foregroundStyle(.white.opacity(0.5))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - File Pickers

    private func openVaultPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select your Obsidian vault folder"
        panel.prompt = "Select Vault"

        if panel.runModal() == .OK, let url = panel.url {
            manager.setVaultPath(url.path)
        }
    }

    private func openNotePicker() {
        guard !manager.vaultPath.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]
        panel.directoryURL = URL(fileURLWithPath: manager.vaultPath)
        panel.message = "Select a note to pin"
        panel.prompt = "Pin Note"

        if panel.runModal() == .OK, let url = panel.url {
            manager.addPinnedNote(fileURL: url)
        }
    }
}
