//
//  ObsidianSettingsView.swift
//  Droppy
//
//  Settings and installation view for Obsidian extension
//

import SwiftUI
import UniformTypeIdentifiers

struct ObsidianInfoView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppPreferenceKey.obsidianInstalled) private var isInstalled = PreferenceDefault.obsidianInstalled
    @AppStorage(AppPreferenceKey.obsidianEnabled) private var isEnabled = PreferenceDefault.obsidianEnabled
    @AppStorage(AppPreferenceKey.obsidianUseCLI) private var useCLI = PreferenceDefault.obsidianUseCLI
    @State private var manager = ObsidianManager.shared
    @State private var shortcut: SavedShortcut?
    @State private var headingsForNotes: [UUID: [String]] = [:]

    // Stats passed from parent
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()
                .padding(.horizontal, 24)

            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    featuresSection

                    if isInstalled {
                        settingsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)

            Divider()
                .padding(.horizontal, 24)

            // Footer
            footerSection
        }
        .frame(width: 450)
        .onAppear {
            loadShortcut()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "book.pages")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.95))
                .frame(width: 64, height: 64)
                .background(Color.purple.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Obsidian")
                    .font(.system(size: 18, weight: .bold))
                Text("Quick notes & append")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label("Productivity", systemImage: "square.grid.2x2")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.purple)
                }
            }

            Spacer()
        }
        .padding(DroppySpacing.lg)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Features")
                .font(.system(size: 14, weight: .semibold))

            ForEach(ObsidianExtension.features, id: \.text) { feature in
                HStack(spacing: 10) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.purple)
                        .frame(width: 24)
                    Text(feature.text)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 14, weight: .semibold))

            // Vault path
            vaultPathRow

            // Pinned notes
            pinnedNotesSection

            // CLI toggle
            cliToggleRow

            // Global hotkey
            hotkeyRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var vaultPathRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vault Path")
                .font(.system(size: 12, weight: .medium))

            HStack {
                HStack(spacing: 6) {
                    statusIndicator
                    Text(manager.vaultPath.isEmpty ? "Not configured" : manager.vaultPath)
                        .font(.system(size: 12))
                        .foregroundStyle(manager.vaultPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AdaptiveColors.buttonBackgroundAuto)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))

                Button("Browse") {
                    pickVault()
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .purple, size: .small))
            }
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(vaultStatusColor)
            .frame(width: 8, height: 8)
    }

    private var vaultStatusColor: Color {
        switch manager.vaultStatus {
        case .valid: return .green
        case .invalid, .cliUnavailable: return .red
        case .notConfigured: return .gray
        }
    }

    private var pinnedNotesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Pinned Notes")
                    .font(.system(size: 12, weight: .medium))
                Spacer()

                if !manager.pinnedNotes.contains(where: { $0.isDaily }) {
                    Button {
                        manager.addDailyNote()
                    } label: {
                        Label("Add Daily", systemImage: "calendar.badge.plus")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.purple)
                }

                Button {
                    pickNote()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            if manager.pinnedNotes.isEmpty {
                Text("No pinned notes yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(manager.pinnedNotes) { note in
                        pinnedNoteRow(note)
                    }
                }
            }
        }
    }

    private func pinnedNoteRow(_ note: PinnedNote) -> some View {
        HStack(spacing: 8) {
            Image(systemName: note.isDaily ? "calendar" : "doc.text")
                .font(.system(size: 12))
                .foregroundStyle(note.isDaily ? .purple : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if let heading = note.defaultHeading {
                    Text(heading)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Heading picker for this note
            if let headings = headingsForNotes[note.id], !headings.isEmpty {
                Menu {
                    Button("None") {
                        manager.updateDefaultHeading(for: note.id, heading: nil)
                    }
                    Divider()
                    ForEach(headings, id: \.self) { heading in
                        Button(heading) {
                            manager.updateDefaultHeading(for: note.id, heading: heading)
                        }
                    }
                } label: {
                    Image(systemName: "number")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Button {
                manager.removePinnedNote(note)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
        .task {
            let headings = await manager.getHeadings(note)
            headingsForNotes[note.id] = headings
        }
    }

    private var cliToggleRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $useCLI) {
                Text("Use Obsidian CLI")
                    .font(.system(size: 12, weight: .medium))
            }
            .toggleStyle(.switch)

            if useCLI && !FileManager.default.isExecutableFile(atPath: "/Applications/Obsidian.app/Contents/MacOS/obsidian") {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    Text("Obsidian.app not found — install from obsidian.md")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var hotkeyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Global Hotkey")
                .font(.system(size: 12, weight: .medium))
            KeyShortcutRecorder(shortcut: $shortcut)
                .onChange(of: shortcut) { _, newValue in
                    manager.updateShortcut(newValue)
                }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            if isInstalled {
                Button {
                    isInstalled = false
                    ExtensionType.obsidian.setRemoved(true)
                    manager.cleanup()
                    NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.obsidian)
                    dismiss()
                } label: {
                    Text("Uninstall")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .red, size: .small))
            }

            Spacer()

            if !isInstalled {
                Button {
                    installExtension()
                } label: {
                    Text("Install")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .purple, size: .small))
            }
        }
        .padding(DroppySpacing.lg)
    }

    // MARK: - Actions

    private func installExtension() {
        isInstalled = true
        ExtensionType.obsidian.setRemoved(false)

        Task {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "obsidian")
        }

        NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.obsidian)
    }

    private func pickVault() {
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

    private func pickNote() {
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

    private func loadShortcut() {
        guard let data = UserDefaults.standard.data(forKey: AppPreferenceKey.obsidianShortcut),
              let saved = try? JSONDecoder().decode(SavedShortcut.self, from: data) else { return }
        shortcut = saved
    }
}
