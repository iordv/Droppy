//
//  WindowSnapInfoView.swift
//  Droppy
//
//  Window Snap extension info sheet with pointer-first controls + shortcut configuration
//

import SwiftUI
import AppKit

private enum WindowSnapModifierOption: CaseIterable, Identifiable {
    case command
    case option
    case control
    case shift
    case function

    var id: String { title }

    var title: String {
        switch self {
        case .command: return "Cmd"
        case .option: return "Opt"
        case .control: return "Ctrl"
        case .shift: return "Shift"
        case .function: return "Fn"
        }
    }

    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        case .function: return "fn"
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .command: return .command
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        case .function: return .function
        }
    }
}

@MainActor
struct WindowSnapInfoView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.windowSnapPointerModeEnabled) private var pointerModeEnabled = PreferenceDefault.windowSnapPointerModeEnabled
    @AppStorage(AppPreferenceKey.windowSnapMoveModifierMask) private var moveModifierMask = Int(PreferenceDefault.windowSnapMoveModifierMask)
    @AppStorage(AppPreferenceKey.windowSnapResizeModifierMask) private var resizeModifierMask = Int(PreferenceDefault.windowSnapResizeModifierMask)
    @AppStorage(AppPreferenceKey.windowSnapBringToFrontWhenHandling) private var bringToFrontWhenHandling = PreferenceDefault.windowSnapBringToFrontWhenHandling
    @AppStorage(AppPreferenceKey.windowSnapResizeMode) private var resizeModeRaw = PreferenceDefault.windowSnapResizeMode

    @State private var shortcuts: [SnapAction: SavedShortcut] = [:]
    @State private var recordingAction: SnapAction?
    @State private var recordMonitor: Any?
    @State private var isHoveringShortcut: [SnapAction: Bool] = [:]
    @State private var runningApps: [NSRunningApplication] = []
    @State private var excludedBundleIDs: Set<String> = []
    @State private var appSearchQuery = ""

    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    @Environment(\.dismiss) private var dismiss
    @State private var showReviewsSheet = false

    private let manager = WindowSnapManager.shared

    private var resizeMode: WindowSnapResizeMode {
        WindowSnapResizeMode(rawValue: resizeModeRaw) ?? .closestCorner
    }

    private var hasMoveModifier: Bool {
        !modifiers(from: moveModifierMask).isEmpty
    }

    private var hasResizeModifier: Bool {
        !modifiers(from: resizeModifierMask).isEmpty
    }

    private var modifiersConflict: Bool {
        let move = modifiers(from: moveModifierMask)
        let resize = modifiers(from: resizeModifierMask)
        return !move.isEmpty && move == resize
    }

    private var accessibilityGranted: Bool {
        PermissionManager.shared.isAccessibilityGranted
    }

    private var filteredRunningApps: [NSRunningApplication] {
        let trimmed = appSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return runningApps
            .filter { app in
                guard let bundleID = app.bundleIdentifier,
                      bundleID != Bundle.main.bundleIdentifier,
                      !bundleID.isEmpty,
                      app.activationPolicy == .regular else {
                    return false
                }

                guard !trimmed.isEmpty else { return true }
                let name = app.localizedName?.lowercased() ?? ""
                return name.contains(trimmed) || bundleID.lowercased().contains(trimmed)
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()
                .padding(.horizontal, 24)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    generalContent
                    excludesContent
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 560)

            Divider()
                .padding(.horizontal, 24)

            buttonSection
        }
        .frame(width: 500)
        .fixedSize(horizontal: true, vertical: true)
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .onAppear {
            loadShortcuts()
            refreshRunningApps()
            loadExcludedApps()
        }
        .onChange(of: pointerModeEnabled) { _, _ in manager.refreshConfiguration() }
        .onChange(of: moveModifierMask) { _, _ in manager.refreshConfiguration() }
        .onChange(of: resizeModifierMask) { _, _ in manager.refreshConfiguration() }
        .onChange(of: bringToFrontWhenHandling) { _, _ in manager.refreshConfiguration() }
        .onChange(of: resizeModeRaw) { _, _ in manager.refreshConfiguration() }
        .onDisappear {
            stopRecording()
        }
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .windowSnap)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/window-snap.jpg")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "rectangle.split.2x2")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .shadow(color: Color.cyan.opacity(0.3), radius: 8, y: 4)

            Text("Window Snap")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
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

                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.15)))
            }

            Text("Pointer-first + keyboard window management")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureSummaryCard
            pointerControlCard
            shortcutSection
        }
    }

    private var featureSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Snap windows with keyboard shortcuts, or drag/move/resize them from anywhere using modifiers.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "keyboard", text: "Configurable keyboard shortcuts")
                featureRow(icon: "cursorarrow.motionlines", text: "Pointer-first move and resize handling")
                featureRow(icon: "rectangle.split.2x2", text: "Live snap zones with edge/corner previews")
                featureRow(icon: "display", text: "Multi-monitor support")
            }
        }
    }

    private var pointerControlCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $pointerModeEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pointer-first Mode")
                    Text("Hold modifiers while dragging to move/resize windows from anywhere")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if pointerModeEnabled {
                Divider()

                modifierSelectorGrid(
                    title: "Move",
                    subtitle: "Hold while dragging to move windows",
                    maskRaw: $moveModifierMask
                )

                modifierSelectorGrid(
                    title: "Resize",
                    subtitle: "Hold while dragging to resize windows",
                    maskRaw: $resizeModifierMask
                )

                if !hasMoveModifier || !hasResizeModifier {
                    Text("Move and Resize each need at least one modifier key.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if modifiersConflict {
                    Text("Move and Resize use the same modifiers now. Set different combos to avoid conflicts.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Toggle(isOn: $bringToFrontWhenHandling) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bring Window To Front")
                        Text("Activate the target app window before handling")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Resizing Mode")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        SettingsSegmentButton(
                            icon: "arrow.down.forward",
                            label: "Classic",
                            isSelected: resizeMode == .classic,
                            tileWidth: 120,
                            tileHeight: 48
                        ) {
                            resizeModeRaw = WindowSnapResizeMode.classic.rawValue
                        }

                        SettingsSegmentButton(
                            icon: "arrow.up.backward.and.arrow.down.forward",
                            label: "Closest Corner",
                            isSelected: resizeMode == .closestCorner,
                            tileWidth: 140,
                            tileHeight: 48
                        ) {
                            resizeModeRaw = WindowSnapResizeMode.closestCorner.rawValue
                        }
                    }
                }

                Divider()

                accessibilityRow
            }
        }
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }

    private func modifierSelectorGrid(title: String, subtitle: String, maskRaw: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(WindowSnapModifierOption.allCases) { option in
                    SettingsSegmentButtonWithContent(
                        label: option.title,
                        isSelected: isModifierSelected(option, maskRaw: maskRaw.wrappedValue),
                        tileWidth: 72,
                        tileHeight: 44
                    ) {
                        toggleModifier(option, maskRaw: maskRaw)
                    } content: {
                        Group {
                            if option == .function {
                                Text(option.symbol.uppercased())
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            } else {
                            Text(option.symbol)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundStyle(isModifierSelected(option, maskRaw: maskRaw.wrappedValue) ? Color.blue : Color.secondary)
                    }
                }
            }
        }
    }

    private var accessibilityRow: some View {
        HStack(spacing: 10) {
            Text("Accessibility")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 6) {
                Circle()
                    .fill(accessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(accessibilityGranted ? "Enabled" : "Needed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(accessibilityGranted ? .green : .orange)
            }

            Spacer()

            Button {
                PermissionManager.shared.openAccessibilitySettings()
            } label: {
                Text("Open Accessibility Settings")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(width: 24)

            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }

    private var excludesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Excluded Apps")
                    .font(.headline)
                Text("Window Snap pointer handling is ignored for these apps. Keyboard shortcuts still work.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !excludedBundleIDs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Currently Excluded")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(excludedBundleIDs).sorted(), id: \.self) { bundleID in
                        HStack {
                            Text(appDisplayName(bundleID: bundleID))
                                .font(.callout)
                            Spacer()
                            Button {
                                setExcluded(bundleID, excluded: false)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AdaptiveColors.buttonBackgroundAuto)
                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Running Apps")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        refreshRunningApps()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(DroppyCircleButtonStyle(size: 26))
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Search apps…", text: $appSearchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))

                    if !appSearchQuery.isEmpty {
                        Button {
                            appSearchQuery = ""
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .buttonStyle(DroppyCircleButtonStyle(size: 20))
                    }
                }
                .droppyTextInputChrome(
                    cornerRadius: DroppyRadius.large,
                    horizontalPadding: 10,
                    verticalPadding: 8
                )

                VStack(spacing: 8) {
                    ForEach(filteredRunningApps, id: \.processIdentifier) { app in
                        runningAppRow(app)
                    }
                }
            }
        }
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }

    private func runningAppRow(_ app: NSRunningApplication) -> some View {
        let bundleID = app.bundleIdentifier ?? ""
        let isExcluded = excludedBundleIDs.contains(bundleID)

        return HStack(spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(AdaptiveColors.buttonBackgroundAuto)
                    .frame(width: 18, height: 18)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(app.localizedName ?? bundleID)
                    .font(.callout)
                Text(bundleID)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                setExcluded(bundleID, excluded: !isExcluded)
            } label: {
                Text(isExcluded ? "Excluded" : "Exclude")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isExcluded ? .green : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isExcluded ? Color.green.opacity(0.15) : AdaptiveColors.buttonBackgroundAuto)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }

    private var shortcutSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    loadDefaults()
                } label: {
                    Text("Load Defaults")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(SnapAction.allCases.filter { $0 != .restore }) { action in
                    shortcutRow(for: action)
                }
            }
        }
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }

    private func shortcutRow(for action: SnapAction) -> some View {
        HStack(spacing: 8) {
            Image(systemName: action.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(width: 20)

            Text(action.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Button {
                if recordingAction == action {
                    stopRecording()
                } else {
                    startRecording(for: action)
                }
            } label: {
                HStack(spacing: 4) {
                    if recordingAction == action {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("…")
                            .font(.system(size: 11, weight: .medium))
                    } else if let shortcut = shortcuts[action] {
                        Text(shortcut.description)
                            .font(.system(size: 11, weight: .semibold))
                    } else {
                        Text("Click")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(recordingAction == action ? .primary : (shortcuts[action] != nil ? .primary : .secondary))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(recordingAction == action ? Color.red.opacity(isHoveringShortcut[action] == true ? 1.0 : 0.85) : (isHoveringShortcut[action] == true ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
                )
            }
            .buttonStyle(DroppySelectableButtonStyle(isSelected: shortcuts[action] != nil))
            .onHover { hovering in
                withAnimation(DroppyAnimation.hoverQuick) {
                    isHoveringShortcut[action] = hovering
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }

    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))

            Spacer()

            Button {
                removeDefaults()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 32))
            .help("Reset Shortcuts")

            DisableExtensionButton(extensionType: .windowSnap)
        }
        .padding(DroppySpacing.lg)
    }

    // MARK: - Modifier Helpers

    private func modifiers(from maskRaw: Int) -> NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: UInt(max(maskRaw, 0))).intersection([.command, .option, .control, .shift, .function])
    }

    private func isModifierSelected(_ option: WindowSnapModifierOption, maskRaw: Int) -> Bool {
        modifiers(from: maskRaw).contains(option.flag)
    }

    private func toggleModifier(_ option: WindowSnapModifierOption, maskRaw: Binding<Int>) {
        var flags = modifiers(from: maskRaw.wrappedValue)
        if flags.contains(option.flag) {
            flags.remove(option.flag)
        } else {
            flags.insert(option.flag)
        }
        maskRaw.wrappedValue = Int(flags.rawValue)
    }

    // MARK: - Excludes

    private func loadExcludedApps() {
        excludedBundleIDs = manager.excludedAppBundleIDs
    }

    private func setExcluded(_ bundleID: String, excluded: Bool) {
        manager.updateExcludedApp(bundleID, excluded: excluded)
        loadExcludedApps()
    }

    private func refreshRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
    }

    private func appDisplayName(bundleID: String) -> String {
        let runningName = runningApps.first(where: { $0.bundleIdentifier == bundleID })?.localizedName
        if let runningName, !runningName.isEmpty {
            return runningName
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                     bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }

        return bundleID
    }

    // MARK: - Recording

    private func startRecording(for action: SnapAction) {
        stopRecording()
        recordingAction = action
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 54 || event.keyCode == 55 || event.keyCode == 56 ||
               event.keyCode == 58 || event.keyCode == 59 || event.keyCode == 60 ||
               event.keyCode == 61 || event.keyCode == 62 {
                return nil
            }

            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
            let shortcut = SavedShortcut(keyCode: Int(event.keyCode), modifiers: flags.rawValue)
            saveShortcut(shortcut, for: action)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        recordingAction = nil
        if let monitor = recordMonitor {
            NSEvent.removeMonitor(monitor)
            recordMonitor = nil
        }
    }

    private func loadShortcuts() {
        shortcuts = WindowSnapManager.shared.shortcuts
    }

    private func saveShortcut(_ shortcut: SavedShortcut, for action: SnapAction) {
        shortcuts[action] = shortcut
        Task { @MainActor in
            WindowSnapManager.shared.setShortcut(shortcut, for: action)
        }
    }

    private func loadDefaults() {
        Task { @MainActor in
            WindowSnapManager.shared.loadDefaults()
            loadShortcuts()
        }
    }

    private func removeDefaults() {
        Task { @MainActor in
            WindowSnapManager.shared.removeDefaults()
            loadShortcuts()
        }
    }
}
