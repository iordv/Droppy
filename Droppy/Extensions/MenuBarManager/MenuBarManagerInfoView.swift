//
//  MenuBarManagerInfoView.swift
//  Droppy
//
//  Menu Bar Manager configuration view
//

import SwiftUI
import UniformTypeIdentifiers

struct MenuBarManagerInfoView: View {
    private enum PlacementLane: Hashable {
        case visible
        case hidden
        case alwaysHidden
        case floatingBar
    }

    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @ObservedObject private var manager = MenuBarManager.shared
    @ObservedObject private var floatingBarManager = MenuBarFloatingBarManager.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    @State private var showReviewsSheet = false
    @State private var hiddenSectionWasVisibleBeforeSettings = false
    @State private var alwaysHiddenSectionWasVisibleBeforeSettings = false
    @State private var alwaysHiddenSectionWasEnabledBeforeSettings = false
    @State private var wasLockedVisibleBeforeSettings = false
    @State private var activeDropPlacement: PlacementLane?
    @State private var draggingPlacementItemID: String?
    @State private var draggingPlacementItemSnapshot: MenuBarFloatingItemSnapshot?
    @State private var mouseUpEventMonitor: Any?
    @State private var didEnterSettingsInspectionMode = false
    @State private var didAttemptStatsLoad = false
    @State private var resolvedInstallCount: Int?
    @State private var resolvedRating: AnalyticsService.ExtensionRating?
    @State private var isRescanOverlayVisible = false
    @State private var rescanOverlayTimeoutTask: Task<Void, Never>?
    @State private var rescanOverlayHideTask: Task<Void, Never>?
    @State private var rescanOverlayShownAt: Date?

    private var panelHeight: CGFloat {
        let availableHeight = NSScreen.main?.visibleFrame.height ?? 800
        return min(760, max(520, availableHeight - 120))
    }
    
    /// Use ExtensionType.isRemoved as single source of truth
    private var isActive: Bool {
        !ExtensionType.menuBarManager.isRemoved && manager.isEnabled
    }

    private var displayInstallCountText: String {
        if AnalyticsService.shared.isDisabled { return "–" }
        if let count = installCount ?? resolvedInstallCount {
            return "\(count)"
        }
        return "–"
    }

    private var displayRating: AnalyticsService.ExtensionRating? {
        rating ?? resolvedRating
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed, non-scrolling)
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Features section
                    featuresSection
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Usage instructions (when enabled)
                    if isActive {
                        usageSection
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Settings section
                        settingsSection
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons (fixed, non-scrolling)
            buttonSection
        }
        .frame(width: 450, height: panelHeight)
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .menuBarManager)
        }
        .onAppear {
            loadStatsIfNeeded()
            didEnterSettingsInspectionMode = false
            guard isActive else { return }
            installMouseUpEventMonitor()
            floatingBarManager.start()
            let hiddenSection = manager.section(withName: .hidden)
            let alwaysHiddenSection = manager.section(withName: .alwaysHidden)
            hiddenSectionWasVisibleBeforeSettings = hiddenSection?.isHidden == false
            alwaysHiddenSectionWasVisibleBeforeSettings = alwaysHiddenSection?.isHidden == false
            alwaysHiddenSectionWasEnabledBeforeSettings = manager.isSectionEnabled(.alwaysHidden)
            wasLockedVisibleBeforeSettings = manager.isLockedVisible
            manager.isLockedVisible = true
            DispatchQueue.main.async {
                manager.showAllSectionsForSettingsInspection()
                floatingBarManager.enterSettingsInspectionMode()
                didEnterSettingsInspectionMode = true
            }
        }
        .onDisappear {
            stopRescanFeedback(animated: false)
            removeMouseUpEventMonitor()
            draggingPlacementItemID = nil
            draggingPlacementItemSnapshot = nil
            guard didEnterSettingsInspectionMode else { return }
            floatingBarManager.exitSettingsInspectionMode()
            manager.isLockedVisible = wasLockedVisibleBeforeSettings
            let shouldEnableAlwaysHiddenOnRestore =
                alwaysHiddenSectionWasEnabledBeforeSettings
                || !floatingBarManager.alwaysHiddenItemIDs.isEmpty
            manager.restoreSectionVisibilityAfterSettings(
                hiddenWasVisible: hiddenSectionWasVisibleBeforeSettings,
                alwaysHiddenWasVisible: alwaysHiddenSectionWasVisibleBeforeSettings,
                alwaysHiddenWasEnabled: shouldEnableAlwaysHiddenOnRestore
            )
        }
        .onReceive(floatingBarManager.$scannedItems) { _ in
            if isRescanOverlayVisible {
                finishRescanFeedback()
            }
        }
    }

    private func loadStatsIfNeeded() {
        guard !didAttemptStatsLoad else { return }
        guard !AnalyticsService.shared.isDisabled else { return }
        guard installCount == nil || rating == nil else { return }

        didAttemptStatsLoad = true

        Task {
            var fetchedCount: Int?
            var fetchedRating: AnalyticsService.ExtensionRating?

            if installCount == nil, let counts = try? await AnalyticsService.shared.fetchExtensionCounts() {
                fetchedCount = counts["menuBarManager"]
            }
            if rating == nil, let ratings = try? await AnalyticsService.shared.fetchExtensionRatings() {
                fetchedRating = ratings["menuBarManager"]
            }

            await MainActor.run {
                if installCount == nil {
                    resolvedInstallCount = fetchedCount
                }
                if rating == nil {
                    resolvedRating = fetchedRating
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon from remote URL
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/menubarmanager.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
            
            Text("Menu Bar Manager")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            // Stats row
            HStack(spacing: 12) {
                // Installs
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text(displayInstallCountText)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
                // Rating (clickable)
                Button {
                    showReviewsSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        if let r = displayRating, r.ratingCount > 0 {
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
                .buttonStyle(.plain)
                
                // Category badge
                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    )
            }
            
            Text("Clean up your menu bar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Core Actions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 7) {
                featureRow(
                    icon: "eye.fill",
                    title: "Toggle hidden icons",
                    detail: "Click the eye icon to show or hide hidden menu bar items."
                )
                featureRow(
                    icon: "arrow.left.arrow.right",
                    title: "Rearrange quickly",
                    detail: "Hold ⌘ and drag icons to move them across sections."
                )
                featureRow(
                    icon: "rectangle.bottomthird.inset.filled",
                    title: "Pin to Floating Bar",
                    detail: "Keep selected always-hidden icons accessible from the bar."
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }
    
    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Group {
                if NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                } else {
                    Text("|")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(.blue)
            .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.green)
                Text("Quick Start")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 7) {
                instructionRow(step: "1", text: "Click the eye icon to reveal or collapse hidden icons.")
                instructionRow(step: "2", text: "Hold ⌘ and drag icons left of the separator to hide them.")
                instructionRow(step: "3", text: "Use Menu Bar Layout below to move items into Floating Bar.")
            }
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Right-click the eye icon for more options")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            
            // Hover to show toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show on Hover")
                        .font(.callout)
                    Text("Automatically show icons when hovering over the menu bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $manager.showOnHover)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            
            // Hover delay slider (only visible when hover is enabled)
            if manager.showOnHover {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Hover Delay")
                            .font(.callout)
                        Spacer()
                        Text(String(format: "%.1fs", manager.showOnHoverDelay))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $manager.showOnHoverDelay, in: 0.0...2.0, step: 0.1)
                        .sliderHaptics(value: manager.showOnHoverDelay, range: 0.0...2.0)
                        .controlSize(.small)
                    
                    // Modifier key picker
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Require Modifier Key")
                                .font(.callout)
                            Text("Hold this key while hovering to reveal icons")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $manager.hoverModifierKey) {
                            ForEach(HoverModifierKey.allCases) { key in
                                Text(key.displayName).tag(key)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 120)
                    }
                }
                .padding(.leading, 4)
            }
            
            Divider()
            
            // Rehide is always timed
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Hide Delay")
                            .font(.callout)
                        Text("Automatically hide after revealing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(manager.autoHideDelay == 0 ? "Off" : String(format: "%.1fs", manager.autoHideDelay))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $manager.autoHideDelay, in: 0.0...5.0, step: 0.5)
                    .sliderHaptics(value: manager.autoHideDelay, range: 0.0...5.0)
                    .controlSize(.small)
            }
            
            Divider()
            
            // Separator is required
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Separator")
                        .font(.callout)
                    Text("Required for hiding and revealing menu bar icons")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Always On")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Icon picker
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Toggle Icon")
                        .font(.callout)
                    Spacer()
                    Toggle("Gradient", isOn: $manager.useGradientIcon)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    Text("Gradient")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Icon options in a grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                    ForEach(MBMIconSet.allCases) { iconSet in
                        iconOption(iconSet)
                    }
                }
            }
            
            Divider()
            
            // Item spacing
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu Bar Spacing")
                            .font(.callout)
                        Text("Adjust spacing between all menu bar items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(manager.itemSpacingOffset > 0 ? "+" : "")\(manager.itemSpacingOffset)pt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                
                HStack {
                    Slider(value: Binding(
                        get: { Double(manager.itemSpacingOffset) },
                        set: { manager.itemSpacingOffset = Int($0) }
                    ), in: -8...8, step: 1)
                        .sliderHaptics(value: Double(manager.itemSpacingOffset), range: -8...8)
                        .controlSize(.small)
                    
                    Button {
                        Task {
                            await manager.applyItemSpacing()
                        }
                    } label: {
                        if manager.isApplyingSpacing {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 50)
                        } else {
                            Text("Apply")
                        }
                    }
                    .droppyAccentButton(color: .blue, size: .small)
                    .disabled(manager.isApplyingSpacing)
                }
            }

            Divider()

            alwaysHiddenFloatingBarSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }

    private var alwaysHiddenFloatingBarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Menu Bar Layout")
                        .font(.callout)
                    Text("Drag icons between rows to place them in Visible, Hidden, Always Hidden, or Floating Bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                permissionTile(
                    label: "Accessibility",
                    isGranted: permissionManager.isAccessibilityGranted,
                    requestSymbol: "hand.raised",
                    requestAction: {
                        floatingBarManager.requestAccessibilityPermission()
                    }
                )

                permissionTile(
                    label: "Screen Rec",
                    isGranted: permissionManager.isScreenRecordingGranted,
                    requestSymbol: "record.circle",
                    requestAction: {
                        floatingBarManager.requestScreenRecordingPermission()
                    }
                )

                SettingsSegmentButtonWithContent(
                    label: "Rescan",
                    isSelected: false,
                    tileWidth: 92,
                    tileHeight: 42,
                    action: {
                        beginRescanFeedback()
                        Task { @MainActor in
                            await Task.yield()
                            floatingBarManager.rescan(force: true, refreshIcons: true)
                        }
                    }
                ) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.overlayAuto(0.6))
                }

                SettingsSegmentButtonWithContent(
                    label: "Floating Bar",
                    isSelected: floatingBarManager.isFeatureEnabled,
                    tileWidth: 92,
                    tileHeight: 42,
                    action: {
                        floatingBarManager.isFeatureEnabled.toggle()
                        if floatingBarManager.isFeatureEnabled {
                            floatingBarManager.rescan(force: true)
                        }
                    }
                ) {
                    Image(systemName: "rectangle.bottomthird.inset.filled")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            floatingBarManager.isFeatureEnabled
                            ? Color.blue
                            : AdaptiveColors.overlayAuto(0.6)
                        )
                }
            }

            if !permissionManager.isAccessibilityGranted {
                Text("Grant Accessibility to discover and trigger menu bar items from the Floating Bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let lanes = floatingBarManager.settingsLaneItems()
                let hasDetectedItems =
                    !lanes.visible.isEmpty
                    || !lanes.hidden.isEmpty
                    || !lanes.alwaysHidden.isEmpty
                    || !lanes.floatingBar.isEmpty
                if !hasDetectedItems {
                    Text("No menu bar icons detected yet. Click “Rescan”.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ZStack {
                        VStack(alignment: .leading, spacing: 12) {
                            placementLane(
                                title: "Visible",
                                lane: .visible,
                                items: lanes.visible
                            )
                            placementLane(
                                title: "Hidden",
                                lane: .hidden,
                                items: lanes.hidden
                            )
                            placementLane(
                                title: "Always Hidden",
                                lane: .alwaysHidden,
                                items: lanes.alwaysHidden
                            )
                            placementLane(
                                title: "Floating Bar",
                                lane: .floatingBar,
                                items: lanes.floatingBar
                            )
                        }
                        .allowsHitTesting(!isRescanOverlayVisible)

                        if isRescanOverlayVisible {
                            rescanSectionsOverlay
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, 2)
                    .animation(.easeInOut(duration: 0.16), value: isRescanOverlayVisible)
                }
            }
        }
    }

    private var rescanSectionsOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.15), lineWidth: 1)
                )

            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Scanning all menu bar icons…")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        useTransparentBackground
                        ? AnyShapeStyle(.ultraThinMaterial)
                        : AdaptiveColors.panelBackgroundOpaqueStyle
                    )
            )
            .overlay(
                Capsule()
                    .stroke(AdaptiveColors.overlayAuto(0.14), lineWidth: 1)
            )
        }
        .padding(6)
    }

    @ViewBuilder
    private func permissionTile(
        label: String,
        isGranted: Bool,
        requestSymbol: String,
        requestAction: @escaping () -> Void
    ) -> some View {
        if isGranted {
            grantedPermissionStatusTile(label: label)
        } else {
            SettingsSegmentButtonWithContent(
                label: label,
                isSelected: false,
                tileWidth: 92,
                tileHeight: 42,
                action: requestAction
            ) {
                Image(systemName: requestSymbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.overlayAuto(0.6))
            }
        }
    }

    private func grantedPermissionStatusTile(label: String) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.2),
                            Color.green.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(Color.green.opacity(0.75), lineWidth: 1.4)
                )
                .overlay {
                    Text("Granted")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.green.opacity(0.95))
                }
                .frame(width: 92, height: 42)

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 92)
        }
        .frame(width: 92, height: 72, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) permission granted")
    }

    private func placementLane(
        title: String,
        lane: PlacementLane,
        items: [MenuBarFloatingItemSnapshot]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text("\(items.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    if items.isEmpty {
                        Text("Drop icons here")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(items) { item in
                            draggablePlacementItemChip(item)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        useTransparentBackground
                        ? AnyShapeStyle(.ultraThinMaterial)
                        : AdaptiveColors.panelBackgroundOpaqueStyle
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        AdaptiveColors.overlayAuto(useTransparentBackground ? 0.2 : 0.1),
                        lineWidth: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        activeDropPlacement == lane ? Color.blue.opacity(0.55) : Color.clear,
                        lineWidth: activeDropPlacement == lane ? 1.2 : 0
                    )
            )
            .onDrop(of: [.text], isTargeted: dropTargetBinding(for: lane)) { providers in
                handlePlacementDrop(providers: providers, to: lane)
            }
        }
    }

    private func draggablePlacementItemChip(_ item: MenuBarFloatingItemSnapshot) -> some View {
        let nonHideableReason = floatingBarManager.nonHideableReason(for: item)
        let isNonHideable = nonHideableReason != nil
        let currentPlacement = floatingBarManager.placement(for: item)
        let isBlockedInVisibleLane = isNonHideable && currentPlacement == .visible
        let canDrag = !isBlockedInVisibleLane
        let isDragging = draggingPlacementItemID == item.id
        let helpText: String = {
            let base = "\(item.displayName) (\(item.ownerBundleID))"
            if let nonHideableReason {
                return "\(base)\n\(nonHideableReason)"
            }
            return base
        }()

        let chip = placementItemChipContent(
            item: item,
            isDimmed: isBlockedInVisibleLane,
            showLockBadge: isBlockedInVisibleLane,
            isDragging: isDragging,
            helpText: helpText
        )

        if !canDrag {
            return AnyView(chip)
        }

        return AnyView(
            chip.onDrag {
                draggingPlacementItemID = item.id
                draggingPlacementItemSnapshot = item
                return NSItemProvider(object: item.id as NSString)
            }
        )
    }

    private func placementItemChipContent(
        item: MenuBarFloatingItemSnapshot,
        isDimmed: Bool,
        showLockBadge: Bool,
        isDragging: Bool,
        helpText: String
    ) -> some View {
        let iconSize = MenuBarFloatingIconLayout.nativeIconSize(for: item)

        return placementIconView(for: item)
            .frame(width: iconSize.width, height: iconSize.height)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .opacity(isDimmed ? 0.45 : 1)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isDragging ? Color.blue.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        Color.clear,
                        lineWidth: 0
                    )
            )
            .overlay(alignment: .bottomTrailing) {
                if showLockBadge {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(2)
                        .background(
                            Circle()
                                .fill(
                                    useTransparentBackground
                                    ? AnyShapeStyle(.ultraThinMaterial)
                                    : AdaptiveColors.panelBackgroundOpaqueStyle
                                )
                        )
                        .offset(x: 4, y: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .help(helpText)
    }

    @ViewBuilder
    private func placementIconView(for item: MenuBarFloatingItemSnapshot) -> some View {
        if let icon = resolvedIcon(for: item) {
            if MenuBarFloatingIconRendering.shouldUseTemplateTint(for: icon) {
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .interpolation(.high)
                    .antialiased(true)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AdaptiveColors.primaryTextAuto)
            } else {
                Image(nsImage: icon)
                    .renderingMode(.original)
                    .interpolation(.high)
                    .antialiased(true)
                    .resizable()
                    .scaledToFit()
            }
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    private func dropTargetBinding(for lane: PlacementLane) -> Binding<Bool> {
        Binding(
            get: { activeDropPlacement == lane },
            set: { isTargeted in
                if isTargeted {
                    activeDropPlacement = lane
                } else if activeDropPlacement == lane {
                    activeDropPlacement = nil
                }
            }
        )
    }

    private func handlePlacementDrop(
        providers: [NSItemProvider],
        to lane: PlacementLane
    ) -> Bool {
        let draggedSnapshot = draggingPlacementItemSnapshot
        draggingPlacementItemID = nil
        activeDropPlacement = nil

        if let draggedSnapshot {
            let immediateItem = resolveDroppedPlacementItem(
                itemID: draggedSnapshot.id,
                fallback: draggedSnapshot
            ) ?? draggedSnapshot
            applyDroppedPlacement(immediateItem, to: lane)
            draggingPlacementItemSnapshot = nil
            return true
        }

        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            draggingPlacementItemSnapshot = nil
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let itemID = object as? String else { return }
            DispatchQueue.main.async {
                guard let item = resolveDroppedPlacementItem(itemID: itemID, fallback: draggedSnapshot) ?? draggedSnapshot else {
                    draggingPlacementItemSnapshot = nil
                    return
                }
                applyDroppedPlacement(item, to: lane)
                draggingPlacementItemSnapshot = nil
            }
        }

        return true
    }

    private func applyDroppedPlacement(
        _ item: MenuBarFloatingItemSnapshot,
        to lane: PlacementLane
    ) {
        if lane != .visible,
           floatingBarManager.nonHideableReason(for: item) != nil {
            return
        }
        switch lane {
        case .visible:
            floatingBarManager.setPlacement(.visible, for: item)
            floatingBarManager.setFloatingBarInclusion(false, for: item)
        case .hidden:
            floatingBarManager.setPlacement(.hidden, for: item)
            floatingBarManager.setFloatingBarInclusion(false, for: item)
        case .alwaysHidden:
            floatingBarManager.setPlacement(.floating, for: item)
            floatingBarManager.setFloatingBarInclusion(false, for: item)
        case .floatingBar:
            floatingBarManager.setPlacement(.floating, for: item)
            floatingBarManager.setFloatingBarInclusion(true, for: item)
        }
    }

    private func resolveDroppedPlacementItem(
        itemID: String,
        fallback: MenuBarFloatingItemSnapshot?
    ) -> MenuBarFloatingItemSnapshot? {
        let items = floatingBarManager.settingsItems
        if let exact = items.first(where: { $0.id == itemID }) {
            return exact
        }
        guard let fallback else { return nil }

        let sameOwner = items.filter { $0.ownerBundleID == fallback.ownerBundleID }
        guard !sameOwner.isEmpty else { return nil }

        if let fallbackIdentifier = fallback.axIdentifier,
           let byIdentifier = sameOwner.first(where: { $0.axIdentifier == fallbackIdentifier }) {
            return byIdentifier
        }

        if let fallbackIndex = fallback.statusItemIndex,
           let byIndex = sameOwner.first(where: { $0.statusItemIndex == fallbackIndex }) {
            return byIndex
        }

        let fallbackDetail = stableSettingsTextToken(fallback.detail)
        if let fallbackDetail {
            let detailMatches = sameOwner.filter { stableSettingsTextToken($0.detail) == fallbackDetail }
            if let bestDetailMatch = nearestByQuartzDistance(from: fallback, in: detailMatches) {
                return bestDetailMatch
            }
        }

        let fallbackTitle = stableSettingsTextToken(fallback.title)
        if let fallbackTitle {
            let titleMatches = sameOwner.filter { stableSettingsTextToken($0.title) == fallbackTitle }
            if let bestTitleMatch = nearestByQuartzDistance(from: fallback, in: titleMatches) {
                return bestTitleMatch
            }
        }

        return nearestByQuartzDistance(from: fallback, in: sameOwner)
    }

    private func nearestByQuartzDistance(
        from fallback: MenuBarFloatingItemSnapshot,
        in candidates: [MenuBarFloatingItemSnapshot]
    ) -> MenuBarFloatingItemSnapshot? {
        guard !candidates.isEmpty else { return nil }
        return candidates.min { lhs, rhs in
            let lhsDistance = abs(lhs.quartzFrame.midX - fallback.quartzFrame.midX)
            let rhsDistance = abs(rhs.quartzFrame.midX - fallback.quartzFrame.midX)
            return lhsDistance < rhsDistance
        }
    }

    private func stableSettingsTextToken(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        let token = trimmed
            .split(separator: ",", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let token, !token.isEmpty {
            return token
        }
        return trimmed.lowercased()
    }

    private func installMouseUpEventMonitor() {
        guard mouseUpEventMonitor == nil else { return }
        mouseUpEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { event in
            self.draggingPlacementItemID = nil
            self.draggingPlacementItemSnapshot = nil
            return event
        }
    }

    private func removeMouseUpEventMonitor() {
        guard let mouseUpEventMonitor else { return }
        NSEvent.removeMonitor(mouseUpEventMonitor)
        self.mouseUpEventMonitor = nil
    }

    private func resolvedIcon(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
        item.icon
    }
    
    private func iconOption(_ iconSet: MBMIconSet) -> some View {
        let isSelected = manager.iconSet == iconSet
        
        return Button {
            manager.iconSet = iconSet
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Image(systemName: iconSet.visibleSymbol)
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: iconSet.hiddenSymbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(iconSet.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.blue : AdaptiveColors.overlayAuto(0.1), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private func instructionRow(step: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step)
                .font(.caption.weight(.bold))
                .foregroundStyle(.blue)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.blue.opacity(0.18)))
            
            Text(text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var buttonSection: some View {
        HStack(spacing: 8) {
            Button("Close") { dismiss() }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            if isActive {
                DisableExtensionButton(extensionType: .menuBarManager)
            } else {
                Button {
                    enableMenuBarManager()
                } label: {
                    Text("Enable")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
            }
        }
        .padding(DroppySpacing.lg)
    }

    private func beginRescanFeedback() {
        rescanOverlayTimeoutTask?.cancel()
        rescanOverlayTimeoutTask = nil
        rescanOverlayHideTask?.cancel()
        rescanOverlayHideTask = nil
        rescanOverlayShownAt = Date()
        withAnimation(.easeInOut(duration: 0.16)) {
            isRescanOverlayVisible = true
        }
        rescanOverlayTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if isRescanOverlayVisible {
                stopRescanFeedback(animated: true)
            }
        }
    }

    private func finishRescanFeedback() {
        let minimumVisibleDuration: TimeInterval = 0.6
        let shownAt = rescanOverlayShownAt ?? Date()
        let elapsed = Date().timeIntervalSince(shownAt)
        let remaining = max(0, minimumVisibleDuration - elapsed)

        guard remaining > 0 else {
            stopRescanFeedback(animated: true)
            return
        }

        rescanOverlayHideTask?.cancel()
        rescanOverlayHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            if isRescanOverlayVisible {
                stopRescanFeedback(animated: true)
            }
        }
    }

    private func stopRescanFeedback(animated: Bool) {
        rescanOverlayTimeoutTask?.cancel()
        rescanOverlayTimeoutTask = nil
        rescanOverlayHideTask?.cancel()
        rescanOverlayHideTask = nil
        rescanOverlayShownAt = nil
        if animated {
            withAnimation(.easeInOut(duration: 0.16)) {
                isRescanOverlayVisible = false
            }
        } else {
            isRescanOverlayVisible = false
        }
    }

    private func enableMenuBarManager() {
        ExtensionType.menuBarManager.setRemoved(false)
        if manager.isEnabled {
            manager.enable()
        } else {
            manager.isEnabled = true
        }
        AnalyticsService.shared.trackExtensionActivation(extensionId: "menuBarManager")
        NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.menuBarManager)
    }
}
