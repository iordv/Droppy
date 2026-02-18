//
//  MenuBarManagerInfoView.swift
//  Droppy
//
//  Menu Bar Manager configuration view
//

import SwiftUI
import UniformTypeIdentifiers

struct MenuBarManagerInfoView: View {
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
    @State private var activeDropPlacement: MenuBarFloatingPlacement?
    @State private var hoveredPlacementItemID: String?
    @State private var draggingPlacementItemID: String?
    @State private var draggingPlacementItemSnapshot: MenuBarFloatingItemSnapshot?
    @State private var mouseDownEventMonitor: Any?
    @State private var mouseUpEventMonitor: Any?
    @State private var didEnterSettingsInspectionMode = false

    private var panelHeight: CGFloat {
        let availableHeight = NSScreen.main?.visibleFrame.height ?? 800
        return min(760, max(520, availableHeight - 120))
    }
    
    /// Use ExtensionType.isRemoved as single source of truth
    private var isActive: Bool {
        !ExtensionType.menuBarManager.isRemoved && manager.isEnabled
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
            didEnterSettingsInspectionMode = false
            guard isActive else { return }
            installMouseDownEventMonitor()
            installMouseUpEventMonitor()
            floatingBarManager.start()
            let hiddenSection = manager.section(withName: .hidden)
            let alwaysHiddenSection = manager.section(withName: .alwaysHidden)
            hiddenSectionWasVisibleBeforeSettings = hiddenSection?.isHidden == false
            alwaysHiddenSectionWasVisibleBeforeSettings = alwaysHiddenSection?.isHidden == false
            alwaysHiddenSectionWasEnabledBeforeSettings = manager.isSectionEnabled(.alwaysHidden)
            wasLockedVisibleBeforeSettings = manager.isLockedVisible
            manager.isLockedVisible = true
            manager.showAllSectionsForSettingsInspection()
            floatingBarManager.enterSettingsInspectionMode()
            didEnterSettingsInspectionMode = true
        }
        .onDisappear {
            removeMouseDownEventMonitor()
            removeMouseUpEventMonitor()
            hoveredPlacementItemID = nil
            draggingPlacementItemID = nil
            draggingPlacementItemSnapshot = nil
            guard didEnterSettingsInspectionMode else { return }
            floatingBarManager.exitSettingsInspectionMode()
            manager.isLockedVisible = wasLockedVisibleBeforeSettings
            let shouldEnableAlwaysHiddenOnRestore =
                alwaysHiddenSectionWasEnabledBeforeSettings
                || (floatingBarManager.isFeatureEnabled && !floatingBarManager.alwaysHiddenItemIDs.isEmpty)
            manager.restoreSectionVisibilityAfterSettings(
                hiddenWasVisible: hiddenSectionWasVisibleBeforeSettings,
                alwaysHiddenWasVisible: alwaysHiddenSectionWasVisibleBeforeSettings,
                alwaysHiddenWasEnabled: shouldEnableAlwaysHiddenOnRestore
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                floatingBarManager.rescan(force: true)
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
                    Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Hide unused menu bar icons and reveal them with a click. Keep your menu bar clean and organized.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "eye.fill", text: "Eye icon toggles visibility")
                featureRow(icon: "line.vertical", text: "Separator line shows when icons are hidden")
                featureRow(icon: "hand.raised.fill", text: "Drag icons left of the separator to hide")
                featureRow(icon: "arrow.left.arrow.right", text: "Rearrange by holding ⌘ and dragging")
                featureRow(icon: "rectangle.bottomthird.inset.filled", text: "Pin always-hidden icons to the Floating Bar (Alpha)")
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Group {
                if NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                } else {
                    Text("|")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(.blue)
            .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Menu Bar Manager is active")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                instructionRow(step: "1", text: "Look for the eye icon in your menu bar")
                instructionRow(step: "2", text: "Click it to hide icons — a separator line ( | ) will appear")
                instructionRow(step: "3", text: "Hold ⌘ and drag icons LEFT of the separator to hide them")
                instructionRow(step: "4", text: "In settings, mark icons as Always Hidden to move them into the Floating Bar (Alpha)")
            }
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Right-click the eye icon for more options")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
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
            
            // Rehide strategy
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rehide Behavior")
                            .font(.callout)
                        Text(manager.rehideStrategy.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $manager.rehideStrategy) {
                        ForEach(RehideStrategy.allCases) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 120)
                }
                
                // Show auto-hide delay only for timed strategy
                if manager.rehideStrategy == .timed {
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
                    Text(
                        floatingBarManager.isFeatureEnabled
                        ? "Drag icons between rows to place them in Visible, Hidden, or Floating Bar."
                        : "Drag icons between rows to place them in Visible or Hidden. Enable Floating Bar (Alpha) to use the Floating Bar row."
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                SettingsSegmentButtonWithContent(
                    label: "Accessibility",
                    isSelected: permissionManager.isAccessibilityGranted,
                    tileWidth: 92,
                    tileHeight: 42,
                    action: {
                        floatingBarManager.requestAccessibilityPermission()
                    }
                ) {
                    Image(systemName: permissionManager.isAccessibilityGranted ? "hand.raised.fill" : "hand.raised")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            permissionManager.isAccessibilityGranted
                            ? Color.blue
                            : AdaptiveColors.overlayAuto(0.6)
                        )
                }

                SettingsSegmentButtonWithContent(
                    label: "Screen Rec",
                    isSelected: permissionManager.isScreenRecordingGranted,
                    tileWidth: 92,
                    tileHeight: 42,
                    action: {
                        floatingBarManager.requestScreenRecordingPermission()
                    }
                ) {
                    Image(systemName: permissionManager.isScreenRecordingGranted ? "record.circle.fill" : "record.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            permissionManager.isScreenRecordingGranted
                            ? Color.blue
                            : AdaptiveColors.overlayAuto(0.6)
                        )
                }

                SettingsSegmentButtonWithContent(
                    label: "Rescan",
                    isSelected: false,
                    tileWidth: 92,
                    tileHeight: 42,
                    action: {
                        floatingBarManager.rescan(force: true)
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
            } else if floatingBarManager.settingsItems.isEmpty {
                Text("No right-side menu bar icons detected yet. Click “Rescan”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    placementLane(
                        title: "Visible",
                        placement: .visible,
                        items: floatingBarManager.settingsItems(for: .visible)
                    )
                    placementLane(
                        title: "Hidden",
                        placement: .hidden,
                        items: floatingBarManager.settingsItems(for: .hidden)
                    )
                    if floatingBarManager.isFeatureEnabled {
                        placementLane(
                            title: "Floating Bar",
                            placement: .floating,
                            items: floatingBarManager.settingsItems(for: .floating)
                        )
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func placementLane(
        title: String,
        placement: MenuBarFloatingPlacement,
        items: [MenuBarFloatingItemSnapshot]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    if placement == .floating {
                        Text("ALPHA")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.orange.opacity(0.14))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.orange.opacity(0.35), lineWidth: 0.8)
                            )
                    }
                }
                Spacer()
                Text("\(items.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
                        activeDropPlacement == placement ? Color.blue.opacity(0.55) : Color.clear,
                        lineWidth: activeDropPlacement == placement ? 1.2 : 0
                    )
            )
            .onDrop(of: [.text], isTargeted: dropTargetBinding(for: placement)) { providers in
                handlePlacementDrop(providers: providers, to: placement)
            }
        }
    }

    private func draggablePlacementItemChip(_ item: MenuBarFloatingItemSnapshot) -> some View {
        let nonHideableReason = floatingBarManager.nonHideableReason(for: item)
        let isNonHideable = nonHideableReason != nil
        let currentPlacement = floatingBarManager.placement(for: item)
        let isBlockedInVisibleLane = isNonHideable && currentPlacement == .visible
        let canDrag = !isBlockedInVisibleLane
        let isHovered = hoveredPlacementItemID == item.id && draggingPlacementItemID == nil
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
            isHovered: isHovered,
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
                hoveredPlacementItemID = nil
                return NSItemProvider(object: item.id as NSString)
            }
        )
    }

    private func placementItemChipContent(
        item: MenuBarFloatingItemSnapshot,
        isDimmed: Bool,
        showLockBadge: Bool,
        isHovered: Bool,
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
                        isHovered
                        ? AdaptiveColors.overlayAuto(0.35)
                        : Color.clear,
                        lineWidth: isHovered ? 1 : 0
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
            .onHover { hovering in
                if hovering {
                    guard draggingPlacementItemID == nil else { return }
                    hoveredPlacementItemID = item.id
                } else if hoveredPlacementItemID == item.id {
                    hoveredPlacementItemID = nil
                }
            }
    }

    @ViewBuilder
    private func placementIconView(for item: MenuBarFloatingItemSnapshot) -> some View {
        if let icon = resolvedIcon(for: item) {
            if icon.isTemplate {
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .interpolation(.high)
                    .antialiased(true)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
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

    private func dropTargetBinding(for placement: MenuBarFloatingPlacement) -> Binding<Bool> {
        Binding(
            get: { activeDropPlacement == placement },
            set: { isTargeted in
                if isTargeted {
                    activeDropPlacement = placement
                } else if activeDropPlacement == placement {
                    activeDropPlacement = nil
                }
            }
        )
    }

    private func handlePlacementDrop(
        providers: [NSItemProvider],
        to placement: MenuBarFloatingPlacement
    ) -> Bool {
        let draggedSnapshot = draggingPlacementItemSnapshot
        draggingPlacementItemID = nil
        hoveredPlacementItemID = nil
        activeDropPlacement = nil

        if let draggedSnapshot {
            let immediateItem = resolveDroppedPlacementItem(
                itemID: draggedSnapshot.id,
                fallback: draggedSnapshot
            ) ?? draggedSnapshot
            applyDroppedPlacement(immediateItem, to: placement)
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
                applyDroppedPlacement(item, to: placement)
                draggingPlacementItemSnapshot = nil
            }
        }

        return true
    }

    private func applyDroppedPlacement(
        _ item: MenuBarFloatingItemSnapshot,
        to placement: MenuBarFloatingPlacement
    ) {
        if placement != .visible,
           floatingBarManager.nonHideableReason(for: item) != nil {
            return
        }
        floatingBarManager.setPlacement(placement, for: item)
    }

    private func resolveDroppedPlacementItem(
        itemID: String,
        fallback: MenuBarFloatingItemSnapshot?
    ) -> MenuBarFloatingItemSnapshot? {
        if let exact = floatingBarManager.settingsItems.first(where: { $0.id == itemID }) {
            return exact
        }
        guard let fallback else { return nil }

        let items = floatingBarManager.settingsItems
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
            self.hoveredPlacementItemID = nil
            return event
        }
    }

    private func installMouseDownEventMonitor() {
        guard mouseDownEventMonitor == nil else { return }
        mouseDownEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged]) { event in
            // Dismiss hover popovers immediately so drag-and-drop stays responsive.
            self.hoveredPlacementItemID = nil
            return event
        }
    }

    private func removeMouseUpEventMonitor() {
        guard let mouseUpEventMonitor else { return }
        NSEvent.removeMonitor(mouseUpEventMonitor)
        self.mouseUpEventMonitor = nil
    }

    private func removeMouseDownEventMonitor() {
        guard let mouseDownEventMonitor else { return }
        NSEvent.removeMonitor(mouseDownEventMonitor)
        self.mouseDownEventMonitor = nil
    }

    private func resolvedIcon(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
        item.icon ?? MenuBarFloatingFallbackIconProvider.icon(for: item)
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
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.blue : AdaptiveColors.overlayAuto(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func instructionRow(step: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var buttonSection: some View {
        HStack {
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
