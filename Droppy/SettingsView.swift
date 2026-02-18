import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @AppStorage(AppPreferenceKey.showInMenuBar) private var showInMenuBar = PreferenceDefault.showInMenuBar
    @AppStorage(AppPreferenceKey.showInDock) private var showInDock = PreferenceDefault.showInDock
    @AppStorage(AppPreferenceKey.showQuickshareInMenuBar) private var showQuickshareInMenuBar = PreferenceDefault.showQuickshareInMenuBar
    @AppStorage(AppPreferenceKey.startAtLogin) private var startAtLogin = PreferenceDefault.startAtLogin
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.enableNotchShelf) private var enableNotchShelf = PreferenceDefault.enableNotchShelf
    @AppStorage(AppPreferenceKey.enableFloatingBasket) private var enableFloatingBasket = PreferenceDefault.enableFloatingBasket
    @AppStorage(AppPreferenceKey.enableBasketAutoHide) private var enableBasketAutoHide = PreferenceDefault.enableBasketAutoHide
    @AppStorage(AppPreferenceKey.enableAutoClean) private var enableAutoClean = PreferenceDefault.enableAutoClean
    @AppStorage(AppPreferenceKey.alwaysCopyOnDrag) private var alwaysCopyOnDrag = PreferenceDefault.alwaysCopyOnDrag
    @AppStorage(AppPreferenceKey.enablePowerFolders) private var enablePowerFolders = PreferenceDefault.enablePowerFolders
    @AppStorage(AppPreferenceKey.enableQuickActions) private var enableQuickActions = PreferenceDefault.enableQuickActions
    @AppStorage(AppPreferenceKey.quickActionsMailApp) private var quickActionsMailApp = PreferenceDefault.quickActionsMailApp
    @AppStorage(AppPreferenceKey.quickActionsCloudProvider) private var quickActionsCloudProvider = PreferenceDefault.quickActionsCloudProvider
    @AppStorage(AppPreferenceKey.basketAutoHideDelay) private var basketAutoHideDelay = PreferenceDefault.basketAutoHideDelay
    @AppStorage(AppPreferenceKey.instantBasketOnDrag) private var instantBasketOnDrag = PreferenceDefault.instantBasketOnDrag
    @AppStorage(AppPreferenceKey.instantBasketDelay) private var instantBasketDelay = PreferenceDefault.instantBasketDelay
    @AppStorage(AppPreferenceKey.basketJiggleSensitivity) private var basketJiggleSensitivity = PreferenceDefault.basketJiggleSensitivity
    @AppStorage(AppPreferenceKey.showClipboardButton) private var showClipboardButton = PreferenceDefault.showClipboardButton
    @AppStorage(AppPreferenceKey.enableMultiBasket) private var enableMultiBasket = PreferenceDefault.enableMultiBasket
    @AppStorage(AppPreferenceKey.hideNotchOnExternalDisplays) private var hideNotchOnExternalDisplays = PreferenceDefault.hideNotchOnExternalDisplays
    @AppStorage(AppPreferenceKey.hideNotchFromScreenshots) private var hideNotchFromScreenshots = PreferenceDefault.hideNotchFromScreenshots
    @AppStorage(AppPreferenceKey.enableRightClickHide) private var enableRightClickHide = PreferenceDefault.enableRightClickHide
    @AppStorage(AppPreferenceKey.hidePhysicalNotch) private var hidePhysicalNotch = PreferenceDefault.hidePhysicalNotch
    @AppStorage(AppPreferenceKey.hidePhysicalNotchOnExternals) private var hidePhysicalNotchOnExternals = PreferenceDefault.hidePhysicalNotchOnExternals
    @AppStorage(AppPreferenceKey.enableHapticFeedback) private var enableHapticFeedback = PreferenceDefault.enableHapticFeedback
    @AppStorage(AppPreferenceKey.useDynamicIslandStyle) private var useDynamicIslandStyle = PreferenceDefault.useDynamicIslandStyle
    @AppStorage(AppPreferenceKey.useDynamicIslandTransparent) private var useDynamicIslandTransparent = PreferenceDefault.useDynamicIslandTransparent
    @AppStorage(AppPreferenceKey.externalDisplayUseDynamicIsland) private var externalDisplayUseDynamicIsland = PreferenceDefault.externalDisplayUseDynamicIsland
    @AppStorage(AppPreferenceKey.showIdleNotchOnExternalDisplays) private var showIdleNotchOnExternalDisplays = PreferenceDefault.showIdleNotchOnExternalDisplays
    @AppStorage(AppPreferenceKey.externalDisplayAdvancedVisibilityEnabled) private var externalDisplayAdvancedVisibilityEnabled = PreferenceDefault.externalDisplayAdvancedVisibilityEnabled
    @AppStorage(AppPreferenceKey.externalDisplayVisibilityRules) private var externalDisplayVisibilityRules = PreferenceDefault.externalDisplayVisibilityRules
    @AppStorage(AppPreferenceKey.dynamicIslandHeightOffset) private var dynamicIslandHeightOffset = PreferenceDefault.dynamicIslandHeightOffset
    @AppStorage(AppPreferenceKey.notchWidthOffset) private var notchWidthOffset = PreferenceDefault.notchWidthOffset
    
    // HUD and Media Player settings
    @AppStorage(AppPreferenceKey.enableHUDReplacement) private var enableHUDReplacement = PreferenceDefault.enableHUDReplacement
    @AppStorage(AppPreferenceKey.enableVolumeHUDReplacement) private var enableVolumeHUDReplacement = PreferenceDefault.enableVolumeHUDReplacement
    @AppStorage(AppPreferenceKey.enableBrightnessHUDReplacement) private var enableBrightnessHUDReplacement = PreferenceDefault.enableBrightnessHUDReplacement
    @AppStorage(AppPreferenceKey.enableVolumeKeyFeedbackSound) private var enableVolumeKeyFeedbackSound = PreferenceDefault.enableVolumeKeyFeedbackSound
    @AppStorage(AppPreferenceKey.enableBatteryHUD) private var enableBatteryHUD = PreferenceDefault.enableBatteryHUD
    @AppStorage(AppPreferenceKey.enableCapsLockHUD) private var enableCapsLockHUD = PreferenceDefault.enableCapsLockHUD
    @AppStorage(AppPreferenceKey.enableAirPodsHUD) private var enableAirPodsHUD = PreferenceDefault.enableAirPodsHUD
    @AppStorage(AppPreferenceKey.enableLockScreenHUD) private var enableLockScreenHUD = PreferenceDefault.enableLockScreenHUD
    @AppStorage(AppPreferenceKey.enableDNDHUD) private var enableDNDHUD = PreferenceDefault.enableDNDHUD
    @AppStorage(AppPreferenceKey.enableUpdateHUD) private var enableUpdateHUD = PreferenceDefault.enableUpdateHUD
    @AppStorage(AppPreferenceKey.mediaControlTargetMode) private var mediaControlTargetMode = PreferenceDefault.mediaControlTargetMode
    @AppStorage(AppPreferenceKey.notificationHUDInstalled) private var isNotificationHUDInstalled = PreferenceDefault.notificationHUDInstalled
    @AppStorage(AppPreferenceKey.notificationHUDEnabled) private var enableNotificationHUD = PreferenceDefault.notificationHUDEnabled
    @AppStorage(AppPreferenceKey.notificationHUDShowPreview) private var notificationHUDShowPreview = PreferenceDefault.notificationHUDShowPreview
    @AppStorage(AppPreferenceKey.terminalNotchInstalled) private var isTerminalNotchInstalled = PreferenceDefault.terminalNotchInstalled
    @AppStorage(AppPreferenceKey.terminalNotchEnabled) private var enableTerminalNotch = PreferenceDefault.terminalNotchEnabled
    @AppStorage(AppPreferenceKey.terminalNotchExternalApp) private var terminalNotchExternalApp = PreferenceDefault.terminalNotchExternalApp
    @AppStorage(AppPreferenceKey.caffeineInstalled) private var isCaffeineInstalled = PreferenceDefault.caffeineInstalled
    @AppStorage(AppPreferenceKey.caffeineEnabled) private var enableCaffeine = PreferenceDefault.caffeineEnabled
    @AppStorage(AppPreferenceKey.caffeineMode) private var caffeineModeRaw = PreferenceDefault.caffeineMode
    @AppStorage(AppPreferenceKey.caffeineInstantlyExpandShelfOnHover) private var caffeineInstantlyExpandShelfOnHover = PreferenceDefault.caffeineInstantlyExpandShelfOnHover
    @AppStorage(AppPreferenceKey.cameraInstalled) private var isCameraInstalled = PreferenceDefault.cameraInstalled
    @AppStorage(AppPreferenceKey.cameraEnabled) private var enableCamera = PreferenceDefault.cameraEnabled
    @AppStorage(AppPreferenceKey.cameraPreferredDeviceID) private var cameraPreferredDeviceID = PreferenceDefault.cameraPreferredDeviceID
    @AppStorage(AppPreferenceKey.enableLockScreenMediaWidget) private var enableLockScreenMediaWidget = PreferenceDefault.enableLockScreenMediaWidget
    @AppStorage(AppPreferenceKey.showMediaPlayer) private var showMediaPlayer = PreferenceDefault.showMediaPlayer
    @AppStorage(AppPreferenceKey.showExternalMouseSwitchButton) private var showExternalMouseSwitchButton = PreferenceDefault.showExternalMouseSwitchButton
    @AppStorage(AppPreferenceKey.autoFadeMediaHUD) private var autoFadeMediaHUD = PreferenceDefault.autoFadeMediaHUD
    @AppStorage(AppPreferenceKey.debounceMediaChanges) private var debounceMediaChanges = PreferenceDefault.debounceMediaChanges
    @AppStorage(AppPreferenceKey.enableMediaAlbumArtGlow) private var enableMediaAlbumArtGlow = PreferenceDefault.enableMediaAlbumArtGlow
    @AppStorage(AppPreferenceKey.enableRealAudioVisualizer) private var enableRealAudioVisualizer = PreferenceDefault.enableRealAudioVisualizer
    @AppStorage(AppPreferenceKey.enableGradientVisualizer) private var enableGradientVisualizer = PreferenceDefault.enableGradientVisualizer
    @AppStorage(AppPreferenceKey.mediaSourceFilterEnabled) private var mediaSourceFilterEnabled = PreferenceDefault.mediaSourceFilterEnabled
    @AppStorage(AppPreferenceKey.mediaSourceAllowedBundles) private var mediaSourceAllowedBundles = PreferenceDefault.mediaSourceAllowedBundles
    @AppStorage(AppPreferenceKey.hideIncognitoBrowserMedia) private var hideIncognitoBrowserMedia = PreferenceDefault.hideIncognitoBrowserMedia
    @AppStorage(AppPreferenceKey.autoShrinkShelf) private var autoShrinkShelf = PreferenceDefault.autoShrinkShelf  // Legacy
    @AppStorage(AppPreferenceKey.autoShrinkDelay) private var autoShrinkDelay = PreferenceDefault.autoShrinkDelay  // Legacy
    @AppStorage(AppPreferenceKey.autoCollapseDelay) private var autoCollapseDelay = PreferenceDefault.autoCollapseDelay
    @AppStorage(AppPreferenceKey.autoCollapseShelf) private var autoCollapseShelf = PreferenceDefault.autoCollapseShelf
    @AppStorage(AppPreferenceKey.autoExpandShelf) private var autoExpandShelf = PreferenceDefault.autoExpandShelf
    @AppStorage(AppPreferenceKey.autoExpandOnMainMac) private var autoExpandOnMainMac = PreferenceDefault.autoExpandOnMainMac
    @AppStorage(AppPreferenceKey.autoExpandOnExternalDisplays) private var autoExpandOnExternalDisplays = PreferenceDefault.autoExpandOnExternalDisplays
    @AppStorage(AppPreferenceKey.autoExpandDelay) private var autoExpandDelay = PreferenceDefault.autoExpandDelay
    @AppStorage(AppPreferenceKey.autoOpenMediaHUDOnShelfExpand) private var autoOpenMediaHUDOnShelfExpand = PreferenceDefault.autoOpenMediaHUDOnShelfExpand
    @AppStorage(AppPreferenceKey.autoHideOnFullscreen) private var autoHideOnFullscreen = PreferenceDefault.autoHideOnFullscreen
    @AppStorage(AppPreferenceKey.hideMediaOnlyOnFullscreen) private var hideMediaOnlyOnFullscreen = PreferenceDefault.hideMediaOnlyOnFullscreen
    @AppStorage(AppPreferenceKey.enableFinderServices) private var enableFinderServices = PreferenceDefault.enableFinderServices
    @AppStorage(AppPreferenceKey.ocrAutoCopyExtractedText) private var ocrAutoCopyExtractedText = PreferenceDefault.ocrAutoCopyExtractedText
    @AppStorage(AppPreferenceKey.disableAnalytics) private var disableAnalytics = PreferenceDefault.disableAnalytics


    
    @State private var dashPhase: CGFloat = 0
    @State private var isHistoryLimitEditing: Bool = false
    @State private var isUpdateHovering = false
    @State private var showDNDAccessAlert = false  // Full Disk Access alert for Focus Mode HUD
    @State private var showMenuBarHiddenWarning = false  // Warning when hiding menu bar icon (Issue #57)
    @State private var showProtectOriginalsWarning = false  // Warning when disabling Protect Originals
    @State private var showStabilizeMediaWarning = false  // Warning when enabling Stabilize Media
    @State private var showAutoFocusSearchWarning = false  // Warning when enabling Auto-Focus Search
    @State private var showQuickActionsWarning = false  // Warning when enabling Quick Actions
    @State private var basketDragRevealShortcut: SavedShortcut?
    @State private var basketSwitcherShortcut: SavedShortcut?
    
    // Hover states for special buttons
    @State private var isCoffeeHovering = false
    @State private var isIntroHovering = false
    @State private var isHardResetHovering = false
    @State private var showHardResetConfirmation = false
    @State private var hardResetIncludeClipboard = false
    @State private var scrollOffset: CGFloat = 0
    
    
    /// Extension to open from deep link (e.g., droppy://extension/ai-bg)
    @State private var deepLinkedExtension: ExtensionType?
    @ObservedObject private var cameraManager = CameraManager.shared
    
    /// Detects if the BUILT-IN display has a physical notch.
    /// Uses auxiliary notch areas first because safeAreaInsets.top can be 0 on some notch Macs.
    private var hasPhysicalNotch: Bool {
        if let builtIn = NSScreen.builtIn {
            let hasAuxiliaryNotchAreas = builtIn.auxiliaryTopLeftArea != nil && builtIn.auxiliaryTopRightArea != nil
            if hasAuxiliaryNotchAreas {
                return true
            }
            return builtIn.safeAreaInsets.top > 0
        }

        // Fallback: check all screens in case the built-in helper is temporarily unavailable.
        return NSScreen.screens.contains { screen in
            guard screen.isBuiltIn else { return false }
            let hasAuxiliaryNotchAreas = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
            return hasAuxiliaryNotchAreas || screen.safeAreaInsets.top > 0
        }
    }

    private var externalScreens: [NSScreen] {
        NSScreen.screens.filter { !$0.isBuiltIn }
    }

    private func externalDisplayRuleMap() -> [String: Bool] {
        guard let data = externalDisplayVisibilityRules.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func isExternalDisplayVisible(_ displayID: CGDirectDisplayID) -> Bool {
        externalDisplayRuleMap()[String(displayID)] ?? true
    }

    private func setExternalDisplayVisible(_ displayID: CGDirectDisplayID, isVisible: Bool) {
        var rules = externalDisplayRuleMap()
        rules[String(displayID)] = isVisible
        if let data = try? JSONEncoder().encode(rules),
           let json = String(data: data, encoding: .utf8) {
            externalDisplayVisibilityRules = json
        }
    }
    
    private func loadBasketDragRevealShortcut() {
        guard let data = UserDefaults.standard.data(forKey: AppPreferenceKey.basketDragRevealShortcut),
              let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) else {
            basketDragRevealShortcut = nil
            return
        }
        basketDragRevealShortcut = sanitizeShortcut(decoded)
    }
    
    private func sanitizeShortcut(_ shortcut: SavedShortcut?) -> SavedShortcut? {
        guard let shortcut else { return nil }
        let allowedFlags = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)
            .intersection([.command, .shift, .option, .control])
        return SavedShortcut(keyCode: shortcut.keyCode, modifiers: allowedFlags.rawValue)
    }
    
    private func saveBasketDragRevealShortcut(_ shortcut: SavedShortcut?) {
        let sanitizedShortcut = sanitizeShortcut(shortcut)
        if let sanitizedShortcut, let encoded = try? JSONEncoder().encode(sanitizedShortcut) {
            UserDefaults.standard.set(encoded, forKey: AppPreferenceKey.basketDragRevealShortcut)
        } else {
            UserDefaults.standard.removeObject(forKey: AppPreferenceKey.basketDragRevealShortcut)
        }
        DragMonitor.shared.reloadShortcutConfiguration()
    }
    
    private func loadBasketSwitcherShortcut() {
        guard let data = UserDefaults.standard.data(forKey: AppPreferenceKey.basketSwitcherShortcut),
              let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) else {
            basketSwitcherShortcut = nil
            return
        }
        basketSwitcherShortcut = sanitizeShortcut(decoded)
    }
    
    private func saveBasketSwitcherShortcut(_ shortcut: SavedShortcut?) {
        let sanitizedShortcut = sanitizeShortcut(shortcut)
        if let sanitizedShortcut, let encoded = try? JSONEncoder().encode(sanitizedShortcut) {
            UserDefaults.standard.set(encoded, forKey: AppPreferenceKey.basketSwitcherShortcut)
        } else {
            UserDefaults.standard.removeObject(forKey: AppPreferenceKey.basketSwitcherShortcut)
        }
        // Reload the shortcut monitor to pick up new binding
        BasketSwitcherWindowController.shared.reloadShortcutConfiguration()
    }

    private func setMultiBasketMode(_ isEnabled: Bool) {
        guard enableMultiBasket != isEnabled else { return }
        enableMultiBasket = isEnabled
        if !isEnabled {
            FloatingBasketWindowController.enforceSingleBasketMode()
        }
        BasketSwitcherWindowController.shared.reloadShortcutConfiguration()
    }

    private func setDockIconVisibility(_ isVisible: Bool) {
        showInDock = isVisible
        AppVisibilityManager.applyDockVisibilityFromPreferences()
    }
    
    private var basketJiggleSensitivityLabel: String {
        switch basketJiggleSensitivity {
        case ..<2.0: return "Low"
        case ..<3.5: return "Balanced"
        case ..<4.5: return "High"
        default: return "Very High"
        }
    }

    private var selectedCaffeineMode: CaffeineMode {
        CaffeineMode(rawValue: caffeineModeRaw) ?? .both
    }

    private func setCaffeineMode(_ mode: CaffeineMode) {
        caffeineModeRaw = mode.rawValue
        if CaffeineManager.shared.isActive {
            CaffeineManager.shared.activate(duration: CaffeineManager.shared.currentDuration, mode: mode)
        }
    }
    
    private var isAnyMediaKeyHUDReplacementEnabled: Bool {
        enableHUDReplacement && (enableVolumeHUDReplacement || enableBrightnessHUDReplacement)
    }

    private var shouldKeepNotchWindowOpen: Bool {
        enableNotchShelf ||
        showIdleNotchOnExternalDisplays ||
        showMediaPlayer ||
        isAnyMediaKeyHUDReplacementEnabled ||
        (isNotificationHUDInstalled && enableNotificationHUD) ||
        enableBatteryHUD ||
        enableCapsLockHUD ||
        enableAirPodsHUD ||
        enableLockScreenHUD ||
        enableDNDHUD ||
        enableUpdateHUD
    }

    private func closeNotchWindowIfUnused() {
        if !shouldKeepNotchWindowOpen {
            NotchWindowController.shared.closeWindow()
        }
    }
    
    private func refreshMediaKeyInterceptorState() {
        let shouldRunInterceptor = MediaKeyInterceptor.shouldRunForCurrentPreferences()
        if shouldRunInterceptor {
            NotchWindowController.shared.setupNotchWindow()
        } else {
            closeNotchWindowIfUnused()
        }
        MediaKeyInterceptor.shared.refreshForCurrentPreferences()
    }

    private func setVolumeKeysEnabled(_ isEnabled: Bool) {
        enableVolumeHUDReplacement = isEnabled
        if !enableVolumeHUDReplacement && !enableBrightnessHUDReplacement {
            enableHUDReplacement = false
        }
        refreshMediaKeyInterceptorState()
    }

    private func setBrightnessKeysEnabled(_ isEnabled: Bool) {
        enableBrightnessHUDReplacement = isEnabled
        if !enableVolumeHUDReplacement && !enableBrightnessHUDReplacement {
            enableHUDReplacement = false
        }
        refreshMediaKeyInterceptorState()
    }

    private func toggleVolumeKeySoundFromPicker() {
        if enableVolumeHUDReplacement {
            enableVolumeKeyFeedbackSound.toggle()
        } else {
            enableVolumeHUDReplacement = true
            enableVolumeKeyFeedbackSound = true
            refreshMediaKeyInterceptorState()
        }
    }

    private func caffeineModeIcon(_ mode: CaffeineMode) -> String {
        switch mode {
        case .displayOnly:
            return "display"
        case .systemOnly:
            return "gearshape.2"
        case .both:
            return "bolt.fill"
        }
    }

    private func caffeineModeTileLabel(_ mode: CaffeineMode) -> String {
        switch mode {
        case .displayOnly:
            return "Display"
        case .systemOnly:
            return "System"
        case .both:
            return "Both"
        }
    }

    private var normalizedCameraPreferredDeviceID: String? {
        let trimmed = cameraPreferredDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var isCameraPreferredDeviceMissing: Bool {
        guard let selectedID = normalizedCameraPreferredDeviceID else { return false }
        return !cameraManager.availableCameraDevices.contains(where: { $0.id == selectedID })
    }

    private func selectNotchfaceCamera(_ deviceID: String?) {
        let normalized = deviceID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        cameraPreferredDeviceID = normalized
        cameraManager.setPreferredDeviceID(normalized.isEmpty ? nil : normalized)
    }

    private func cameraSourceTileLabel(for displayName: String) -> String {
        if displayName.localizedCaseInsensitiveContains("iphone") {
            return "iPhone"
        }
        if displayName.localizedCaseInsensitiveContains("facetime") {
            return "FaceTime"
        }

        let cleaned = displayName
            .replacingOccurrences(of: "Camera", with: "")
            .replacingOccurrences(of: "camera", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count > 12 {
            return String(cleaned.prefix(11)) + "…"
        }
        return cleaned.isEmpty ? "Camera" : cleaned
    }

    private var selectedNotchfaceCameraDisplayName: String {
        guard let selectedID = normalizedCameraPreferredDeviceID else {
            return "Auto (best available)"
        }
        return cameraManager.availableCameraDevices.first(where: { $0.id == selectedID })?.displayName ?? "Auto (best available)"
    }
    
    @ViewBuilder
    private func nativePickerRow<PickerContent: View>(
        title: String,
        subtitle: String,
        @ViewBuilder picker: () -> PickerContent
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(alignment: .center, spacing: 8) {
                picker()
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    @ViewBuilder
    private var basketSummonOptions: some View {
        if !instantBasketOnDrag {
            HStack(spacing: 8) {
                BasketSensitivityInfoButton()
                VStack(alignment: .leading) {
                    Text("Shake Sensitivity")
                    Text("How much movement is needed to summon the basket")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sensitivity")
                    Spacer()
                    Text(basketJiggleSensitivityLabel)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $basketJiggleSensitivity, in: 1.0...5.0, step: 1.0)
                    .sliderHaptics(value: basketJiggleSensitivity, range: 1.0...5.0)
            }
            .padding(.leading, 28)
        }
        
        HStack(spacing: 8) {
            BasketDragShortcutInfoButton()
            VStack(alignment: .leading) {
                Text("Drag Shortcut")
                Text("Press this while dragging to reveal the basket")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        
        HStack {
            Text("Shortcut")
                .frame(minWidth: 74, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
            Spacer()
            KeyShortcutRecorder(shortcut: Binding(
                get: { basketDragRevealShortcut },
                set: { newValue in
                    basketDragRevealShortcut = newValue
                    saveBasketDragRevealShortcut(newValue)
                }
            ))
            
            if basketDragRevealShortcut != nil {
                Button {
                    basketDragRevealShortcut = nil
                    saveBasketDragRevealShortcut(nil)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 32))
                .help("Reset Shortcut")
            }
        }
        .frame(maxWidth: .infinity)
        
        if basketDragRevealShortcut != nil {
            Text("With a drag shortcut set, automatic basket summon (shake and instant appear) is disabled.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
        }
    }

    @ViewBuilder
    private var externalDisplayAdvancedOptions: some View {
        if !externalScreens.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $externalDisplayAdvancedVisibilityEnabled) {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 6) {
                            Text("Per-Display")
                            Text("advanced")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AdaptiveColors.overlayAuto(0.08)))
                                .overlay(Capsule().stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1))
                        }
                        Text("Choose exactly which external displays show Droppy")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if externalDisplayAdvancedVisibilityEnabled {
                    VStack(spacing: 8) {
                        ForEach(externalScreens, id: \.displayID) { screen in
                            ExternalDisplayVisibilityRow(
                                screen: screen,
                                isVisible: Binding(
                                    get: { isExternalDisplayVisible(screen.displayID) },
                                    set: { setExternalDisplayVisible(screen.displayID, isVisible: $0) }
                                )
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var scrollOffsetReader: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geo.frame(in: .named("settingsScroll")).minY
                )
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    private var settingsForm: some View {
        Form {
            switch selectedTab {
            case .general:
                generalSettings
            case .shelf:
                shelfSettings
            case .basket:
                basketOnlySettings
            case .clipboard:
                clipboardSettings
            case .huds:
                hudSettings
            case .extensions:
                integrationsSettings
            case .quickshare:
                quickshareSettings
            case .accessibility:
                accessibilitySettings
            case .about:
                aboutSettings
            }
        }
        .formStyle(.grouped)
        .toggleStyle(CenteredSwitchToggleStyle())
        .scrollContentBackground(useTransparentBackground ? .visible : .hidden)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geo.frame(in: .global).minY
                    )
            }
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
    }
    
    private var topScrollScrim: some View {
        // Top blur scrim - only visible while scrolling
        VStack(spacing: 0) {
            Group {
                if useTransparentBackground {
                    // withinWindow is required to blur content inside this window
                    SettingsVisualEffectView(material: .headerView, blendingMode: .withinWindow)
                } else {
                    Rectangle()
                        .fill(AdaptiveColors.panelBackgroundAuto)
                }
            }
            .frame(height: 68)
            .frame(maxWidth: .infinity)
            // Fade the scrim into the content
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.55),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
            
            Spacer()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .opacity(scrollOffset < -6 ? 1 : 0)
        .animation(DroppyAnimation.hoverQuick, value: scrollOffset < -6)
        .zIndex(10)
    }
    
    private var settingsDetail: some View {
        ZStack(alignment: .top) {
            settingsForm
            
            // Blur/fade overlay at top - appears when scrolling
            VStack(spacing: 0) {
                Group {
                    if useTransparentBackground {
                        // Keep the root glass surface readable without stacking another blur pass.
                        Rectangle()
                            .fill(AdaptiveColors.overlayAuto(0.06))
                    } else {
                        // Match panel tone in opaque mode to avoid a dark strip in light mode
                        AdaptiveColors.panelBackgroundAuto
                    }
                }
                .frame(height: 80)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.4),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            // Only show while actually scrolling to avoid static top-edge artifacts.
            .opacity(scrollOffset < -6 ? 1 : 0)
            .animation(DroppyAnimation.hoverQuick, value: scrollOffset < -6)
        }
    }

    var body: some View {
        ZStack {
            NavigationSplitView {
                SettingsSidebar(selectedTab: $selectedTab)
                    .droppyTransparentBackground(useTransparentBackground)
            } detail: {
                settingsDetail
            }
        }
        .onTapGesture {
            isHistoryLimitEditing = false
        }
        // Apply blue accent color for toggles
        .tint(.droppyAccent)
        // Apply transparent material or solid black
        .droppyTransparentBackground(useTransparentBackground)
        // CRITICAL: Always use dark color scheme to ensure text is readable
        // In both solid black and transparent material modes, we need light text
        
        // Force complete view rebuild when transparency mode changes
        // This fixes the issue where background doesn't update immediately
        .id(useTransparentBackground)
        // Handle deep links to open specific extensions
        .onAppear {
            if enableHUDReplacement && !enableVolumeHUDReplacement && !enableBrightnessHUDReplacement {
                enableVolumeHUDReplacement = true
            }
            loadBasketDragRevealShortcut()
            loadBasketSwitcherShortcut()
            // Check if there's a pending tab to open (e.g., from menu bar "Manage Uploads")
            if let pendingTab = SettingsWindowController.shared.pendingTabToOpen {
                selectedTab = pendingTab
                SettingsWindowController.shared.clearPendingTab()
                // Resize window for this tab
                SettingsWindowController.shared.resizeForTab(isExtensions: pendingTab == .extensions)
            }
            // Check if there's a pending extension from a deep link
            else if let pending = SettingsWindowController.shared.pendingExtensionToOpen {
                selectedTab = .extensions
                SettingsWindowController.shared.clearPendingExtension()
                // Resize window for extensions tab
                SettingsWindowController.shared.resizeForTab(isExtensions: true)
                // Delay to allow card views to fully initialize before presenting sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    deepLinkedExtension = pending
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openExtensionFromDeepLink)) { notification in
            // Always navigate to Extensions tab
            selectedTab = .extensions
            // If a specific extension type was provided, open its sheet
            if let extensionType = notification.object as? ExtensionType {
                // Small delay to allow tab switch animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    deepLinkedExtension = extensionType
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSmartExportSettings)) { _ in
            // Navigate to General tab where Smart Export is located
            selectedTab = .general
        }
        .onChange(of: showIdleNotchOnExternalDisplays) { _, newValue in
            if newValue {
                NotchWindowController.shared.setupNotchWindow()
            } else {
                closeNotchWindowIfUnused()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            // Resize window when switching to/from extensions tab
            // Defer to next runloop to avoid NSHostingView reentrant layout
            DispatchQueue.main.async {
                SettingsWindowController.shared.resizeForTab(isExtensions: newTab == .extensions)
            }
        }
    }
    
    // MARK: - Sections
    
    // MARK: General Tab (Startup, Menu Bar, Core Settings)
    private var generalSettings: some View {
        Group {
            LicenseSettingsSection()

            // MARK: Startup
            Section {
                nativePickerRow(
                    title: "Startup & Visibility",
                    subtitle: "Choose whether Droppy starts at login and appears in Menu Bar or Dock"
                ) {
                    // Menu Bar Icon
                    SettingsSegmentButtonWithContent(
                        label: "Menu Bar Icon",
                        isSelected: showInMenuBar,
                        action: {
                            if showInMenuBar {
                                showMenuBarHiddenWarning = true
                            } else {
                                showInMenuBar = true
                            }
                        }
                    ) {
                        Image(systemName: "menubar.rectangle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(showInMenuBar ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                    }
                    .sheet(isPresented: $showMenuBarHiddenWarning) {
                        MenuBarHiddenSheet(
                            isPresented: $showMenuBarHiddenWarning,
                            onConfirm: {
                                showInMenuBar = false
                            }
                        )
                    }

                    // Dock Icon
                    SettingsSegmentButtonWithContent(
                        label: "Dock Icon",
                        isSelected: showInDock,
                        action: {
                            setDockIconVisibility(!showInDock)
                        }
                    ) {
                        Group {
                            if let dockSymbol = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "Dock Icon") {
                                Image(nsImage: dockSymbol)
                                    .renderingMode(.template)
                            } else {
                                Image(systemName: "macwindow.on.rectangle")
                            }
                        }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(showInDock ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                    }
                    
                    // Launch at Login
                    SettingsSegmentButtonWithContent(
                        label: "Launch at Login",
                        isSelected: startAtLogin,
                        action: {
                            startAtLogin.toggle()
                            LaunchAtLoginManager.setLaunchAtLogin(enabled: startAtLogin)
                        }
                    ) {
                        Image(systemName: "power")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(startAtLogin ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                    }
                }
            } header: {
                Text("Startup")
            }
            
            // MARK: Appearance
            Section {
                Toggle(isOn: $useTransparentBackground) {
                    VStack(alignment: .leading) {
                        Text("Transparent Background")
                        Text("Use glass effect for windows")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Appearance")
            }
            
            // MARK: Display Mode (Non-notch displays only)
            if !hasPhysicalNotch {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        nativePickerRow(
                            title: "Display Mode",
                            subtitle: "Choose how Droppy appears at the top of your screen"
                        ) {
                            SettingsSegmentButtonWithContent(
                                label: "Notch",
                                isSelected: !useDynamicIslandStyle,
                                action: { useDynamicIslandStyle = false }
                            ) {
                                UShape()
                                    .fill(!useDynamicIslandStyle ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 50, height: 16)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: useDynamicIslandStyle,
                                action: { useDynamicIslandStyle = true }
                            ) {
                                Capsule()
                                    .fill(useDynamicIslandStyle ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 40, height: 14)
                            }
                        }
                        
                        // Island Height Slider (only visible in Island mode)
                        if useDynamicIslandStyle || externalDisplayUseDynamicIsland {
                            Divider()
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Island Height")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(dynamicIslandHeightOffset == 0 ? "Standard" : (dynamicIslandHeightOffset < 0 ? "Compact" : "Tall"))
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "minus")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 12)
                                    
                                    Slider(
                                        value: $dynamicIslandHeightOffset,
                                        in: -10...10,
                                        step: 2
                                    )
                                    .tint(.blue)
                                    .onChange(of: dynamicIslandHeightOffset) { oldValue, newValue in
                                        // Haptic feedback + sound for premium slider feel
                                        let isEndpoint = newValue == -10 || newValue == 10
                                        if isEndpoint {
                                            HapticFeedback.sliderEndpoint()
                                        } else {
                                            HapticFeedback.sliderTick()
                                        }
                                        // Post notification to trigger immediate window update
                                        NotificationCenter.default.post(name: NSNotification.Name("DynamicIslandHeightChanged"), object: nil)
                                    }
                                    
                                    Image(systemName: "plus")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 12)
                                }
                            }
                        }

                    }
                    .padding(.vertical, 8)
                    .animation(DroppyAnimation.smoothContent, value: useDynamicIslandStyle)
                    
                    Toggle(isOn: $showIdleNotchOnExternalDisplays) {
                        VStack(alignment: .leading) {
                            Text("Show When Idle")
                            Text("Keep \(useDynamicIslandStyle ? "island" : "notch") visible when nothing is playing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Display Mode")
                }
            }
            
            // MARK: External Displays
            Section {
                HStack(spacing: 8) {
                    ExternalDisplayInfoButton()
                    Toggle(isOn: $hideNotchOnExternalDisplays) {
                        VStack(alignment: .leading) {
                            Text("Hide on External Displays")
                            Text("Disable notch shelf on external monitors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if !hideNotchOnExternalDisplays {
                    VStack(alignment: .leading, spacing: 8) {
                        nativePickerRow(
                            title: "External Display Style",
                            subtitle: "Choose how Droppy appears on connected external screens"
                        ) {
                            SettingsSegmentButtonWithContent(
                                label: "Notch",
                                isSelected: !externalDisplayUseDynamicIsland,
                                action: { externalDisplayUseDynamicIsland = false }
                            ) {
                                UShape()
                                    .fill(!externalDisplayUseDynamicIsland ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 44, height: 14)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: externalDisplayUseDynamicIsland,
                                action: { externalDisplayUseDynamicIsland = true }
                            ) {
                                Capsule()
                                    .fill(externalDisplayUseDynamicIsland ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 44, height: 14)
                            }
                        }
                        
                        // Island Height Slider (only visible when Island mode is selected)
                        if externalDisplayUseDynamicIsland {
                            Divider()
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Island Height")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(dynamicIslandHeightOffset == 0 ? "Standard" : (dynamicIslandHeightOffset < 0 ? "Compact" : "Tall"))
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "minus")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 12)
                                    
                                    Slider(
                                        value: $dynamicIslandHeightOffset,
                                        in: -10...10,
                                        step: 2
                                    )
                                    .tint(.blue)
                                    .onChange(of: dynamicIslandHeightOffset) { oldValue, newValue in
                                        // Haptic feedback + sound for premium slider feel
                                        let isEndpoint = newValue == -10 || newValue == 10
                                        if isEndpoint {
                                            HapticFeedback.sliderEndpoint()
                                        } else {
                                            HapticFeedback.sliderTick()
                                        }
                                        // Post notification to trigger immediate window update
                                        NotificationCenter.default.post(name: NSNotification.Name("DynamicIslandHeightChanged"), object: nil)
                                    }
                                    
                                    Image(systemName: "plus")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 12)
                                }
                            }
                            .animation(DroppyAnimation.smoothContent, value: externalDisplayUseDynamicIsland)
                        }
                    }
                    
                    Toggle(isOn: $showIdleNotchOnExternalDisplays) {
                        VStack(alignment: .leading) {
                            Text("Show When Idle")
                            Text("Keep \(externalDisplayUseDynamicIsland ? "island" : "notch") visible when nothing is playing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    externalDisplayAdvancedOptions
                }
            } header: {
                Text("External Displays")
            }
            
            Section {
                Toggle(isOn: $hidePhysicalNotch) {
                    VStack(alignment: .leading) {
                        Text("Hide Physical Notch")
                        Text("Draw a black bar to hide the notch and reclaim menu bar space in Notch mode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: hidePhysicalNotch) { _, newValue in
                    if newValue {
                        HideNotchManager.shared.enable()
                    } else {
                        HideNotchManager.shared.disable()
                    }
                }

                if hidePhysicalNotch && !externalScreens.isEmpty {
                    Toggle(isOn: $hidePhysicalNotchOnExternals) {
                        VStack(alignment: .leading) {
                            Text("Include External Displays")
                            Text("Also apply the black bar to external screens in Notch mode")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 20)
                    .onChange(of: hidePhysicalNotchOnExternals) { _, _ in
                        HideNotchManager.shared.refreshWindows()
                    }
                }
            } header: {
                Text("Physical Notch")
            } footer: {
                Text("Only applies while Droppy is using Notch style, not Dynamic Island style.")
            }

            // MARK: File Handling
            Section {
                nativePickerRow(
                    title: "File Actions",
                    subtitle: "Shared behavior for files dropped into Shelf and Basket"
                ) {
                    VStack(spacing: 6) {
                        SettingsSegmentButtonWithContent(
                            label: "Auto-Remove",
                            isSelected: enableAutoClean,
                            showsLabel: false,
                            action: { enableAutoClean.toggle() }
                        ) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(enableAutoClean ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                        }

                        HStack(spacing: 4) {
                            AutoCleanInfoButton()
                            Text("Auto-Remove")
                                .font(.system(size: 11, weight: enableAutoClean ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(enableAutoClean ? .primary : .secondary)
                        }
                        .frame(width: 108)
                    }

                    VStack(spacing: 6) {
                        SettingsSegmentButtonWithContent(
                            label: "Power Folders",
                            isSelected: enablePowerFolders,
                            showsLabel: false,
                            tileWidth: 122,
                            action: { enablePowerFolders.toggle() }
                        ) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(enablePowerFolders ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                        }

                        HStack(spacing: 4) {
                            PowerFoldersInfoButton()
                            Text("Power Folders")
                                .font(.system(size: 11, weight: enablePowerFolders ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(enablePowerFolders ? .primary : .secondary)
                        }
                        .frame(width: 122)
                    }

                    VStack(spacing: 6) {
                        SettingsSegmentButtonWithContent(
                            label: "Protect Originals",
                            isSelected: alwaysCopyOnDrag,
                            showsLabel: false,
                            tileWidth: 122,
                            action: {
                                if alwaysCopyOnDrag {
                                    showProtectOriginalsWarning = true
                                } else {
                                    alwaysCopyOnDrag = true
                                }
                            }
                        ) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(alwaysCopyOnDrag ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                        }

                        HStack(spacing: 4) {
                            AlwaysCopyInfoButton()
                            Text("Protect Originals")
                                .font(.system(size: 11, weight: alwaysCopyOnDrag ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(alwaysCopyOnDrag ? .primary : .secondary)
                        }
                        .frame(width: 122)
                    }
                    .sheet(isPresented: $showProtectOriginalsWarning) {
                        ProtectOriginalsWarningSheet(alwaysCopyOnDrag: $alwaysCopyOnDrag)
                    }
                }
            } header: {
                Text("File Handling")
            } footer: {
                Text("These settings apply to both Notch Shelf and Floating Basket.")
            }

            quickActionsSharedSection

            // MARK: Automation
            Section {
                Toggle(isOn: $ocrAutoCopyExtractedText) {
                    VStack(alignment: .leading) {
                        Text("Auto-Copy OCR Text")
                        Text("Skip the OCR result window and copy recognized text instantly")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SmartExportSettingsRow()
                TrackedFoldersSettingsRow()
            } header: {
                Text("Automation")
            }
        }
    }
    
    // MARK: Shelf Tab (Dedicated Shelf Settings)
    private var shelfSettings: some View {
        Group {
            // MARK: Notch Shelf
            Section {
                HStack(spacing: 8) {
                    NotchShelfInfoButton()
                    Toggle(isOn: $enableNotchShelf) {
                        VStack(alignment: .leading) {
                            Text("Notch Shelf")
                            Text("Drop zone at the top of your screen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableNotchShelf) { oldValue, newValue in
                    if newValue {
                        NotchWindowController.shared.setupNotchWindow()
                    } else {
                        closeNotchWindowIfUnused()
                    }
                }
                
                if enableNotchShelf {
                    NotchShelfPreview()
                }
            } header: {
                Text("Notch Shelf")
            }
            
            if enableNotchShelf && hasPhysicalNotch {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notch Width")
                            Spacer()
                            Text(
                                notchWidthOffset == 0
                                ? "Standard"
                                : String(format: "%+.0f pt", notchWidthOffset)
                            )
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        }
                        
                        Slider(value: $notchWidthOffset, in: -40...80, step: 2)
                            .sliderHaptics(value: notchWidthOffset, range: -40...80)
                            .onChange(of: notchWidthOffset) { _, _ in
                                NotchWindowController.shared.forceRecalculateAllWindowSizes()
                            }
                    }
                } header: {
                    Text("Notch Fit")
                } footer: {
                    Text("Adjust only if the built-in notch appears too narrow or too wide on your MacBook display.")
                }
            }
            
            // MARK: Shelf Behavior
            if enableNotchShelf {
                Section {
                    nativePickerRow(
                        title: "Shelf Behavior",
                        subtitle: "Control how the shelf expands, collapses, and opens media"
                    ) {
                        // Auto-Collapse
                        SettingsSegmentButtonWithContent(
                            label: "Auto-Collapse",
                            isSelected: autoCollapseShelf,
                            action: { autoCollapseShelf.toggle() }
                        ) {
                            Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(autoCollapseShelf ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                        }
                        
                        // Auto-Expand
                        SettingsSegmentButtonWithContent(
                            label: "Auto-Expand",
                            isSelected: autoExpandShelf,
                            action: { autoExpandShelf.toggle() }
                        ) {
                            Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(autoExpandShelf ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                        }
                        
                        // Auto-Open Media
                        SettingsSegmentButtonWithContent(
                            label: "Auto-Open Media",
                            isSelected: autoOpenMediaHUDOnShelfExpand,
                            tileWidth: 122,
                            action: { autoOpenMediaHUDOnShelfExpand.toggle() }
                        ) {
                            Image(systemName: "music.note")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(autoOpenMediaHUDOnShelfExpand ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                        }
                    }

                    // Full-width sliders appear when enabled
                    if autoCollapseShelf {
                        VStack(spacing: 4) {
                            HStack {
                                Text("Collapse Delay")
                                Spacer()
                                Text(String(format: "%.2fs", autoCollapseDelay))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $autoCollapseDelay, in: 0.1...2.0, step: 0.05)
                                .sliderHaptics(value: autoCollapseDelay, range: 0.1...2.0)
                        }
                    }
                    
                    if autoExpandShelf {
                        nativePickerRow(
                            title: "Auto-Expand Rules",
                            subtitle: "Fine-tune hover behavior for menu bar and external displays"
                        ) {
                            SettingsSegmentButtonWithContent(
                                label: "Main Mac Hover",
                                isSelected: autoExpandOnMainMac,
                                tileWidth: 128,
                                action: { autoExpandOnMainMac.toggle() }
                            ) {
                                Image(systemName: "laptopcomputer")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(autoExpandOnMainMac ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                            }

                            SettingsSegmentButtonWithContent(
                                label: "External Hover",
                                isSelected: autoExpandOnExternalDisplays,
                                tileWidth: 128,
                                action: { autoExpandOnExternalDisplays.toggle() }
                            ) {
                                Image(systemName: "display")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(autoExpandOnExternalDisplays ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                            }
                            .disabled(externalScreens.isEmpty)
                        }
                        
                        if externalScreens.isEmpty {
                            Text("Connect an external display to enable External Hover.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            HStack {
                                Text("Expand Delay")
                                Spacer()
                                Text(String(format: "%.2fs", autoExpandDelay))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $autoExpandDelay, in: 0.1...2.0, step: 0.05)
                                .sliderHaptics(value: autoExpandDelay, range: 0.1...2.0)
                        }
                    }
                } header: {
                    Text("Behavior")
                }
            }
        }
    }
    
    // MARK: Basket-Only Tab (Floating Basket Settings)
    private var basketOnlySettings: some View {
        Group {
            Section {
                HStack(spacing: 8) {
                    BasketGestureInfoButton()
                    Toggle(isOn: $enableFloatingBasket) {
                        VStack(alignment: .leading) {
                            Text("Floating Basket")
                            Text(instantBasketOnDrag 
                                ? "Appears instantly when dragging files anywhere. Drag right into Quick Actions to quickly share your files." 
                                : "Appears when you jiggle files anywhere on screen. Drag right into Quick Actions to quickly share your files.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableFloatingBasket) { oldValue, newValue in
                    if !newValue {
                        FloatingBasketWindowController.closeAllBaskets()
                    }
                    BasketSwitcherWindowController.shared.reloadShortcutConfiguration()
                }
                
                if enableFloatingBasket {
                    FloatingBasketPreview()
                }
            } header: {
                Text("Floating Basket")
            }
            
            if enableFloatingBasket {
                // MARK: Appearance Settings
                Section {
                    HStack(spacing: 8) {
                        InstantAppearInfoButton()
                        Toggle(isOn: $instantBasketOnDrag) {
                            VStack(alignment: .leading) {
                                Text("Instant Appear")
                                Text("Show basket immediately when dragging files")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if instantBasketOnDrag {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Delay")
                                Spacer()
                                Text(instantBasketDelay < 0.2 ? "Instant" : String(format: "%.1fs", instantBasketDelay))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $instantBasketDelay, in: 0.15...3.0, step: 0.1)
                                .sliderHaptics(value: instantBasketDelay, range: 0.15...3.0)
                        }
                        .padding(.leading, 28)
                    }
                    
                    basketSummonOptions
                } header: {
                    Text("Appearance")
                }
                
                // MARK: Auto-Hide Settings
                Section {
                    HStack(spacing: 8) {
                        JiggleToShowInfoButton()
                        Toggle(isOn: $enableBasketAutoHide) {
                            VStack(alignment: .leading) {
                                Text("Auto-Hide")
                                Text("Basket hides after delay when cursor leaves")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if enableBasketAutoHide {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Hide Delay")
                                Spacer()
                                Text(String(format: "%.1fs", basketAutoHideDelay))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $basketAutoHideDelay, in: 0.5...5.0, step: 0.5)
                            Text("Time before basket auto-hides when cursor leaves")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Auto-Hide")
                }
                
                // MARK: Multi-Basket
                Section {
                    nativePickerRow(
                        title: "Basket Mode",
                        subtitle: enableMultiBasket
                            ? "Jiggling while a basket is open spawns another basket"
                            : "Only one basket at a time"
                    ) {
                        SettingsSegmentButtonWithContent(
                            label: "Single Basket",
                            isSelected: !enableMultiBasket,
                            action: { setMultiBasketMode(false) }
                        ) {
                            Image(systemName: "tray")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(!enableMultiBasket ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                        }
                        
                        SettingsSegmentButtonWithContent(
                            label: "Multi-Basket",
                            isSelected: enableMultiBasket,
                            action: { setMultiBasketMode(true) }
                        ) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(enableMultiBasket ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                        }
                    }
                    
                    // Basket Switcher Shortcut (only shown when multi-basket enabled)
                    if enableMultiBasket {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Basket Switcher")
                                Text("Shortcut to show all baskets and switch between them")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            Spacer()
                            KeyShortcutRecorder(shortcut: Binding(
                                get: { basketSwitcherShortcut },
                                set: { newValue in
                                    basketSwitcherShortcut = newValue
                                    saveBasketSwitcherShortcut(newValue)
                                }
                            ))
                            
                            if basketSwitcherShortcut != nil {
                                Button {
                                    basketSwitcherShortcut = nil
                                    saveBasketSwitcherShortcut(nil)
                                } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                }
                                .buttonStyle(DroppyCircleButtonStyle(size: 32))
                                .help("Reset Shortcut")
                            }
                        }
                    }
                } header: {
                    Text("Multi-Basket")
                }

            }
        }
    }
    
    private var quickActionsSharedSection: some View {
        Section {
            HStack(spacing: 8) {
                QuickActionsInfoButton()
                Toggle(isOn: $enableQuickActions) {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 6) {
                            Text("Quick Actions")
                            Text("advanced")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AdaptiveColors.overlayAuto(0.08)))
                                .overlay(Capsule().stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1))
                        }
                        Text("Show quick action drop buttons under Shelf and Basket (AirDrop, Messages, Mail)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: enableQuickActions) { _, newValue in
                    if newValue {
                        showQuickActionsWarning = true
                    }
                }
                .sheet(isPresented: $showQuickActionsWarning) {
                    QuickActionsInfoSheet(enableQuickActions: $enableQuickActions)
                }
            }

            if enableQuickActions {
                nativePickerRow(
                    title: "Cloud Action",
                    subtitle: "Choose which provider powers Quickshare (Droppy Quickshare extension or iCloud Drive)"
                ) {
                    SettingsSegmentButton(
                        icon: QuickActionsCloudProvider.droppyQuickshare.icon,
                        label: QuickActionsCloudProvider.droppyQuickshare.title,
                        isSelected: quickActionsCloudProvider == QuickActionsCloudProvider.droppyQuickshare.rawValue,
                        action: { quickActionsCloudProvider = QuickActionsCloudProvider.droppyQuickshare.rawValue }
                    )

                    SettingsSegmentButton(
                        icon: QuickActionsCloudProvider.iCloudDrive.icon,
                        label: QuickActionsCloudProvider.iCloudDrive.title,
                        isSelected: quickActionsCloudProvider == QuickActionsCloudProvider.iCloudDrive.rawValue,
                        action: { selectICloudDriveCloudAction() }
                    )
                }

                nativePickerRow(
                    title: "Mail App",
                    subtitle: "Choose which app opens for the Mail quick action"
                ) {
                    SettingsSegmentButton(
                        icon: QuickActionsMailApp.systemDefault.icon,
                        label: QuickActionsMailApp.systemDefault.title,
                        isSelected: quickActionsMailApp == QuickActionsMailApp.systemDefault.rawValue,
                        action: { quickActionsMailApp = QuickActionsMailApp.systemDefault.rawValue }
                    )

                    SettingsSegmentButton(
                        icon: QuickActionsMailApp.appleMail.icon,
                        label: QuickActionsMailApp.appleMail.title,
                        isSelected: quickActionsMailApp == QuickActionsMailApp.appleMail.rawValue,
                        action: { quickActionsMailApp = QuickActionsMailApp.appleMail.rawValue }
                    )

                    SettingsSegmentButton(
                        icon: QuickActionsMailApp.outlook.icon,
                        label: QuickActionsMailApp.outlook.title,
                        isSelected: quickActionsMailApp == QuickActionsMailApp.outlook.rawValue,
                        action: { quickActionsMailApp = QuickActionsMailApp.outlook.rawValue }
                    )
                }

                if quickActionsMailApp == QuickActionsMailApp.outlook.rawValue &&
                    !MailHelper.isMailClientInstalled(.outlook) {
                    Text("Outlook is not installed. Droppy will fall back to the system Mail action.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Quick Actions")
        } footer: {
            Text("Shared setting: applies to both Notch Shelf and Floating Basket.")
        }
    }
    
    
    // MARK: Accessibility Tab (Extracted from various places)
    private var accessibilitySettings: some View {
        Group {
            Section {
                Toggle(isOn: $enableRightClickHide) {
                    VStack(alignment: .leading) {
                        Text("Right-Click to Hide")
                        Text("Show 'Hide Notch/Island' option in right-click menu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Toggle(isOn: $enableHapticFeedback) {
                    VStack(alignment: .leading) {
                        Text("Haptic Feedback")
                        Text("Get tactile feedback when dropping files or triggering actions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Interaction")
            } footer: {
                Text("Controls for pointer interaction and tactile feedback.")
            }

            Section {
                Toggle(isOn: $hideNotchFromScreenshots) {
                    VStack(alignment: .leading) {
                        Text("Hide from Screenshots")
                        Text("Exclude the notch area from screenshots and screen recordings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: hideNotchFromScreenshots) { _, _ in
                    NotchWindowController.shared.updateScreenshotVisibility()
                }
            } header: {
                Text("Screen Capture")
            } footer: {
                Text("Privacy and visual capture behavior for the notch area.")
            }
        }
    }
    // MARK: Features Tab (Shelf + Basket + Shared) - LEGACY, kept for reference
    private var featuresSettings: some View {
        Group {
            // MARK: Notch Shelf Section
            Section {
                HStack(spacing: 8) {
                    NotchShelfInfoButton()
                    Toggle(isOn: $enableNotchShelf) {
                        VStack(alignment: .leading) {
                            Text("Notch Shelf")
                            Text("Drop zone at the top of your screen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableNotchShelf) { oldValue, newValue in
                    if newValue {
                        NotchWindowController.shared.setupNotchWindow()
                    } else {
                        closeNotchWindowIfUnused()
                    }
                }
                
                if enableNotchShelf {
                    NotchShelfPreview()
                }
            } header: {
                Text("Notch Shelf")
            }
            
            // MARK: Display Style
            // Visual Style settings (from Appearance)
            Section {
                Toggle(isOn: $useTransparentBackground) {
                    VStack(alignment: .leading) {
                        Text("Transparent Background")
                        Text("Use glass effect for windows")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 8) {
                    ExternalDisplayInfoButton()
                    Toggle(isOn: $hideNotchOnExternalDisplays) {
                        VStack(alignment: .leading) {
                            Text("Hide on External Displays")
                            Text("Disable notch shelf on external monitors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Show external display mode picker when not hidden
                if !hideNotchOnExternalDisplays {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("External Display Style")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            SettingsSegmentButtonWithContent(
                                label: "Notch",
                                isSelected: !externalDisplayUseDynamicIsland,
                                action: { externalDisplayUseDynamicIsland = false }
                            ) {
                                UShape()
                                    .fill(!externalDisplayUseDynamicIsland ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 44, height: 14)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: externalDisplayUseDynamicIsland,
                                action: { externalDisplayUseDynamicIsland = true }
                            ) {
                                Capsule()
                                    .fill(externalDisplayUseDynamicIsland ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 44, height: 14)
                            }
                        }

                        externalDisplayAdvancedOptions
                    }
                }
            } header: {
                Text("Display")
            }
            
            // MARK: Display Mode (Non-notch displays only)
            if !hasPhysicalNotch {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Mode")
                            .font(.headline)
                        
                        Text("Choose how Droppy appears at the top of your screen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            SettingsSegmentButtonWithContent(
                                label: "Notch",
                                isSelected: !useDynamicIslandStyle,
                                action: { useDynamicIslandStyle = false }
                            ) {
                                UShape()
                                    .fill(!useDynamicIslandStyle ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 50, height: 16)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: useDynamicIslandStyle,
                                action: { useDynamicIslandStyle = true }
                            ) {
                                Capsule()
                                    .fill(useDynamicIslandStyle ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 40, height: 14)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Display Mode")
                }
            }
            
            // MARK: Shelf Behavior
            Section {
                // Auto-Collapse toggle with delay slider
                Toggle(isOn: $autoCollapseShelf) {
                    VStack(alignment: .leading) {
                        Text("Auto-Collapse")
                        Text("Shrink shelf when mouse leaves")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if autoCollapseShelf {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Collapse Delay")
                            Spacer()
                            Text(String(format: "%.2fs", autoCollapseDelay))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $autoCollapseDelay, in: 0.1...2.0, step: 0.05)
                            .sliderHaptics(value: autoCollapseDelay, range: 0.1...2.0)
                    }
                }
                
                // Auto-Expand can be toggled, with delay slider
                Toggle(isOn: $autoExpandShelf) {
                    VStack(alignment: .leading) {
                        Text("Auto-Expand")
                        Text("Expand shelf when hovering over notch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if autoExpandShelf {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Expand Delay")
                            Spacer()
                            Text(String(format: "%.2fs", autoExpandDelay))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $autoExpandDelay, in: 0.1...2.0, step: 0.05)
                            .sliderHaptics(value: autoExpandDelay, range: 0.1...2.0)
                    }
                }
            } header: {
                Text("Shelf Behavior")
            }
            
            // MARK: Shared Features
            Section {
                // Auto-Clean (affects Droppy UI only)
                HStack(spacing: 8) {
                    AutoCleanInfoButton()
                    Toggle(isOn: $enableAutoClean) {
                        VStack(alignment: .leading) {
                            Text("Auto-Remove")
                            Text("Clear items when dragged out of Droppy")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Power Folders (affects both shelf and basket)
                HStack(spacing: 8) {
                    PowerFoldersInfoButton()
                    Toggle(isOn: $enablePowerFolders) {
                        VStack(alignment: .leading) {
                            Text("Power Folders")
                            Text("Pin folders and drop files directly into them")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Smart Export (auto-save processed files)
                SmartExportSettingsRow()
                
                // Tracked Folders (watch folders for new files) - Advanced setting
                TrackedFoldersSettingsRow()
                
                // Always Copy (affects actual files on disk) - Advanced setting (at bottom)
                HStack(spacing: 8) {
                    AlwaysCopyInfoButton()
                    Toggle(isOn: $alwaysCopyOnDrag) {
                        VStack(alignment: .leading) {
                            HStack(alignment: .center, spacing: 6) {
                                Text("Protect Originals")
                                Text("advanced")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AdaptiveColors.overlayAuto(0.08)))
                                    .overlay(Capsule().stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1))
                            }
                            Text("Always copy, never move files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: alwaysCopyOnDrag) { _, newValue in
                        if !newValue {
                            // User is turning OFF protection - show warning
                            showProtectOriginalsWarning = true
                        }
                    }
                }
                .sheet(isPresented: $showProtectOriginalsWarning) {
                    ProtectOriginalsWarningSheet(alwaysCopyOnDrag: $alwaysCopyOnDrag)
                }
            } header: {
                Text("Shared Features")
            } footer: {
                Text("These features apply to both Notch Shelf and Floating Basket.")
            }
            
            // MARK: Floating Basket Section
            basketSections
            
            // MARK: Accessibility
            indicatorsSettings
        }
    }
    
    // Helper view for Basket sections (included in Features tab)
    @ViewBuilder
    private var basketSections: some View {
        Section {
            HStack(spacing: 8) {
                BasketGestureInfoButton()
                Toggle(isOn: $enableFloatingBasket) {
                    VStack(alignment: .leading) {
                        Text("Floating Basket")
                        Text(instantBasketOnDrag 
                            ? "Appears instantly when dragging files anywhere. Drag right into Quick Actions to quickly share your files." 
                            : "Appears when you jiggle files anywhere on screen. Drag right into Quick Actions to quickly share your files.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: enableFloatingBasket) { oldValue, newValue in
                if !newValue {
                    FloatingBasketWindowController.closeAllBaskets()
                }
                BasketSwitcherWindowController.shared.reloadShortcutConfiguration()
            }
            
            if enableFloatingBasket {
                FloatingBasketPreview()
            }
        } header: {
            Text("Floating Basket")
        }
        
        if enableFloatingBasket {
            // MARK: Appearance Settings
            Section {
                // Instant appear toggle
                HStack(spacing: 8) {
                    InstantAppearInfoButton()
                    Toggle(isOn: $instantBasketOnDrag) {
                        VStack(alignment: .leading) {
                            Text("Instant Appear")
                            Text("Show basket immediately when dragging files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Delay slider (only when instant appear is enabled)
                if instantBasketOnDrag {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Delay")
                            Spacer()
                            Text(instantBasketDelay < 0.2 ? "Instant" : String(format: "%.1fs", instantBasketDelay))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $instantBasketDelay, in: 0.15...3.0, step: 0.1)
                            .sliderHaptics(value: instantBasketDelay, range: 0.15...3.0)
                    }
                    .padding(.leading, 28)
                }
                
                basketSummonOptions
            } header: {
                Text("Basket Appearance")
            }
            
            // MARK: Auto-Hide Settings
            Section {
                HStack(spacing: 8) {
                    PeekModeInfoButton()
                    Toggle(isOn: $enableBasketAutoHide) {
                        VStack(alignment: .leading) {
                            Text("Auto-Hide")
                            Text("Basket hides after delay when cursor leaves")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if enableBasketAutoHide {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Hide Delay")
                            Spacer()
                            Text(String(format: "%.1fs", basketAutoHideDelay))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $basketAutoHideDelay, in: 0.5...5.0, step: 0.5)
                        Text("Time before basket auto-hides when cursor leaves")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Auto-Hide")
            }
            
            // MARK: Basket Advanced
            Section {
                HStack(spacing: 8) {
                    QuickActionsInfoButton()
                    Toggle(isOn: $enableQuickActions) {
                        VStack(alignment: .leading) {
                            HStack(alignment: .center, spacing: 6) {
                                Text("Quick Actions")
                                Text("advanced")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AdaptiveColors.overlayAuto(0.08)))
                                    .overlay(Capsule().stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1))
                            }
                            Text("Show quick action drop buttons under Shelf and Basket")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: enableQuickActions) { _, newValue in
                        if newValue {
                            showQuickActionsWarning = true
                        }
                    }
                    .sheet(isPresented: $showQuickActionsWarning) {
                        QuickActionsInfoSheet(enableQuickActions: $enableQuickActions)
                    }
                }
            } header: {
                Text("Basket Advanced")
            }
        }
    }
    
    // MARK: Basket Tab (kept for reference but not used in sidebar)
    private var basketSettings: some View {
        Group {
            // MARK: Floating Basket Section
            Section {
                HStack(spacing: 8) {
                    BasketGestureInfoButton()
                    Toggle(isOn: $enableFloatingBasket) {
                        VStack(alignment: .leading) {
                            Text("Floating Basket")
                            Text(instantBasketOnDrag 
                                ? "Appears instantly when dragging files anywhere" 
                                : "Appears when you jiggle files anywhere on screen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableFloatingBasket) { oldValue, newValue in
                    if !newValue {
                        FloatingBasketWindowController.closeAllBaskets()
                    }
                    BasketSwitcherWindowController.shared.reloadShortcutConfiguration()
                }
                
                if enableFloatingBasket {
                    FloatingBasketPreview()
                }
            } header: {
                Text("Floating Basket")
            }
            
            if enableFloatingBasket {
                // MARK: Appearance Settings
                Section {
                    // Instant appear toggle
                    HStack(spacing: 8) {
                        InstantAppearInfoButton()
                        Toggle(isOn: $instantBasketOnDrag) {
                            VStack(alignment: .leading) {
                                Text("Instant Appear")
                                Text("Show basket immediately when dragging files")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Delay slider (only when instant appear is enabled)
                    if instantBasketOnDrag {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Delay")
                                Spacer()
                                Text(instantBasketDelay < 0.2 ? "Instant" : String(format: "%.1fs", instantBasketDelay))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $instantBasketDelay, in: 0.15...3.0, step: 0.1)
                                .sliderHaptics(value: instantBasketDelay, range: 0.15...3.0)
                        }
                        .padding(.leading, 28)  // Align with toggle content
                    }
                    
                    basketSummonOptions
                } header: {
                    Text("Appearance")
                }
                
                // MARK: Auto-Hide Settings
                Section {
                    // Auto-hide with peek toggle
                    HStack(spacing: 8) {
                        PeekModeInfoButton()
                        Toggle(isOn: $enableBasketAutoHide) {
                            VStack(alignment: .leading) {
                                Text("Auto-Hide")
                                Text("Basket hides after delay when cursor leaves")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if enableBasketAutoHide {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Hide Delay")
                                Spacer()
                                Text(String(format: "%.1fs", basketAutoHideDelay))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $basketAutoHideDelay, in: 0.5...5.0, step: 0.5)
                            Text("Time before basket auto-hides when cursor leaves")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Auto-Hide")
                }
                
                // MARK: Advanced
                Section {
                    // Quick Actions (advanced feature - at bottom)
                    HStack(spacing: 8) {
                        QuickActionsInfoButton()
                        Toggle(isOn: $enableQuickActions) {
                            VStack(alignment: .leading) {
                                HStack(alignment: .center, spacing: 6) {
                                    Text("Quick Actions")
                                    Text("advanced")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(AdaptiveColors.overlayAuto(0.08)))
                                        .overlay(Capsule().stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1))
                                }
                                Text("Show quick action drop buttons under Shelf and Basket")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: enableQuickActions) { _, newValue in
                            if newValue {
                                // User is enabling - show explanation sheet
                                showQuickActionsWarning = true
                            }
                        }
                        .sheet(isPresented: $showQuickActionsWarning) {
                            QuickActionsInfoSheet(enableQuickActions: $enableQuickActions)
                        }
                    }
                } header: {
                    Text("Advanced")
                }
            }
        }
    }
    
    // MARK: HUDs Tab
    private var hudSettings: some View {
        Group {
            // MARK: Media Player (Now Playing) - TOP PRIORITY
            Section {
                // Media Player requires macOS 15.0+ due to MediaRemoteAdapter.framework
                if #available(macOS 15.0, *) {
                    // Main toggle - standard form factor
                    HStack(spacing: 12) {
                        MediaPlayerHUDIcon()
                        
                        Toggle(isOn: $showMediaPlayer) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text("Now Playing")
                                    SwipeGestureInfoButton()
                                }
                                Text("Show current song with album art")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: showMediaPlayer) { _, newValue in
                        if newValue {
                            NotchWindowController.shared.setupNotchWindow()
                        } else {
                            closeNotchWindowIfUnused()
                        }
                    }
                    
                    if showMediaPlayer {
                        // Advanced Auto-Fade settings (Issue #79)
                        AdvancedAutofadeSettingsRow()

                        Toggle(isOn: $showExternalMouseSwitchButton) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("External Mouse Switch Button")
                                Text("Show a left floating Media/Shelf toggle when an external mouse is connected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        nativePickerRow(
                            title: "Visualizer",
                            subtitle: "Pick the audio spectrum style for Now Playing"
                        ) {
                            SettingsSegmentButtonWithContent(
                                label: "Real Audio",
                                isSelected: enableRealAudioVisualizer
                            ) {
                                selectRealAudioVisualizerMode()
                            } content: {
                                VisualizerPreviewMono(isSelected: enableRealAudioVisualizer)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Gradient",
                                isSelected: enableGradientVisualizer
                            ) {
                                selectGradientVisualizerMode()
                            } content: {
                                VisualizerPreviewGradient(isSelected: enableGradientVisualizer)
                            }
                        }
                        .onAppear {
                            normalizeVisualizerModeIfNeeded()
                        }

                        Toggle(isOn: $enableMediaAlbumArtGlow) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Album Art Glow")
                                Text("Show ambient glow/shadow around album art in Now Playing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        nativePickerRow(
                            title: "In Fullscreen",
                            subtitle: "Choose what Droppy does while apps are fullscreen"
                        ) {
                            SettingsSegmentButton(
                                icon: "eye",
                                label: "Show",
                                isSelected: !autoHideOnFullscreen
                            ) {
                                autoHideOnFullscreen = false
                            }
                            
                            SettingsSegmentButton(
                                icon: "music.note",
                                label: "Hide Media",
                                isSelected: autoHideOnFullscreen && hideMediaOnlyOnFullscreen
                            ) {
                                autoHideOnFullscreen = true
                                hideMediaOnlyOnFullscreen = true
                            }
                            
                            SettingsSegmentButton(
                                icon: "eye.slash",
                                label: "Hide All",
                                isSelected: autoHideOnFullscreen && !hideMediaOnlyOnFullscreen
                            ) {
                                autoHideOnFullscreen = true
                                hideMediaOnlyOnFullscreen = false
                            }
                        }
                        
                        // Advanced options - standard toggles
                        Toggle(isOn: $debounceMediaChanges) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Stabilize Media")
                                    Text("advanced")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(AdaptiveColors.overlayAuto(0.08)))
                                        .overlay(Capsule().stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1))
                                }
                                Text("Prevent flickering from rapid song changes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: debounceMediaChanges) { _, newValue in
                            if newValue {
                                showStabilizeMediaWarning = true
                            }
                        }
                        .sheet(isPresented: $showStabilizeMediaWarning) {
                            StabilizeMediaInfoSheet(debounceMediaChanges: $debounceMediaChanges)
                        }

                        // Media Source Filter (inline list like Tracked Folders)
                        MediaSourceFilterSettingsRow(allowedBundles: $mediaSourceAllowedBundles, filterEnabled: $mediaSourceFilterEnabled)

                        // Hide Incognito/Private Browser Media
                        Toggle(isOn: $hideIncognitoBrowserMedia) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hide Incognito Media")
                                Text("Hide media from private browsing windows")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    // macOS 14 - feature not available
                    HStack(spacing: 12) {
                        NowPlayingIcon()
                            .opacity(0.5)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Now Playing")
                                .foregroundStyle(.secondary)
                            Text("Requires macOS 15")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } header: {
                Text("Media")
            }
            
            // MARK: System HUDs
            Section {
                // Volume & Brightness
                HStack(spacing: 12) {
                    VolumeHUDIcon()
                    
                    Toggle(isOn: $enableHUDReplacement) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Volume & Brightness")
                            Text("Replace system OSD")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableHUDReplacement) { _, newValue in
                    if newValue {
                        if !enableVolumeHUDReplacement && !enableBrightnessHUDReplacement {
                            enableVolumeHUDReplacement = true
                        }
                    }
                    refreshMediaKeyInterceptorState()
                }
                
                if enableHUDReplacement {
                    nativePickerRow(
                        title: "Key Handling",
                        subtitle: "Choose what Droppy handles for media keys"
                    ) {
                        SettingsSegmentButton(
                            icon: "speaker.wave.2.fill",
                            label: "Volume",
                            isSelected: enableVolumeHUDReplacement,
                            tileWidth: 84
                        ) {
                            setVolumeKeysEnabled(!enableVolumeHUDReplacement)
                        }

                        SettingsSegmentButton(
                            icon: "waveform.badge.plus",
                            label: "Key Sound",
                            isSelected: enableVolumeKeyFeedbackSound,
                            tileWidth: 84
                        ) {
                            toggleVolumeKeySoundFromPicker()
                        }
                        .opacity(enableVolumeHUDReplacement ? 1 : 0.55)

                        SettingsSegmentButton(
                            icon: "sun.max.fill",
                            label: "Brightness",
                            isSelected: enableBrightnessHUDReplacement,
                            tileWidth: 84
                        ) {
                            setBrightnessKeysEnabled(!enableBrightnessHUDReplacement)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .center, spacing: 6) {
                                Text("Media Key Target")
                                Text("beta")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.orange.opacity(0.95))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.orange.opacity(0.18)))
                                    .overlay(Capsule().stroke(Color.orange.opacity(0.45), lineWidth: 1))
                            }
                            Text("Choose whether volume and brightness follow your active display")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(alignment: .center, spacing: 8) {
                            SettingsSegmentButton(
                                icon: "laptopcomputer",
                                label: "Main MacBook",
                                isSelected: mediaControlTargetMode == "mainMacBook",
                                tileWidth: 130
                            ) {
                                mediaControlTargetMode = "mainMacBook"
                            }
                            
                            SettingsSegmentButton(
                                icon: "cursorarrow.rays",
                                label: "Active Display",
                                isSelected: mediaControlTargetMode == "activeDisplay",
                                tileWidth: 130
                            ) {
                                mediaControlTargetMode = "activeDisplay"
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                
                // Battery
                HStack(spacing: 12) {
                    BatteryHUDIcon()
                    
                    Toggle(isOn: $enableBatteryHUD) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Battery Status")
                            Text("Show when charging")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableBatteryHUD) { _, newValue in
                    if newValue {
                        NotchWindowController.shared.setupNotchWindow()
                    } else {
                        closeNotchWindowIfUnused()
                    }
                }
                
                // Caps Lock
                HStack(spacing: 12) {
                    CapsLockHUDIcon()
                    
                    Toggle(isOn: $enableCapsLockHUD) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Caps Lock")
                            Text("Show indicator")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableCapsLockHUD) { _, newValue in
                    if newValue {
                        NotchWindowController.shared.setupNotchWindow()
                    } else {
                        closeNotchWindowIfUnused()
                    }
                }
                
                // Lock Screen
                HStack(spacing: 12) {
                    LockScreenHUDIcon()
                    
                    Toggle(isOn: $enableLockScreenHUD) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lock Screen")
                            Text("Show lock/unlock animation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableLockScreenHUD) { _, newValue in
                    if newValue {
                        NotchWindowController.shared.setupNotchWindow()
                        LockScreenManager.shared.enable()
                    } else {
                        LockScreenManager.shared.disable()
                        closeNotchWindowIfUnused()
                    }
                }
                
                // Droppy Updates
                HStack(spacing: 12) {
                    UpdateHUDIcon()
                    
                    Toggle(isOn: $enableUpdateHUD) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Droppy Updates")
                            Text("Show when a new version is available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableUpdateHUD) { _, newValue in
                    if newValue {
                        NotchWindowController.shared.setupNotchWindow()
                    } else {
                        closeNotchWindowIfUnused()
                    }
                }
            } header: {
                Text("System")
            }
            
            // MARK: Extensions (Notify Me, Terminal Notch, Caffeine, Camera)
            Section {
                // Notify me! (Notification HUD Extension)
                HStack(spacing: 12) {
                    ExtensionIconView<NotificationHUDExtension>(definition: NotificationHUDExtension.self, size: 40)
                        .opacity(isNotificationHUDInstalled && enableNotificationHUD ? 1.0 : 0.5)
                    
                    if isNotificationHUDInstalled {
                        // Extension is installed - show on/off toggle
                        Toggle(isOn: $enableNotificationHUD) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notify me!")
                                Text("Show notifications in the notch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        // Extension is not installed - greyed out
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notify me!")
                                .foregroundStyle(.secondary)
                            Text("Enable in Extension Store")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .onChange(of: enableNotificationHUD) { _, newValue in
                    if newValue {
                        NotchWindowController.shared.setupNotchWindow()
                    } else {
                        closeNotchWindowIfUnused()
                    }
                }

                if isNotificationHUDInstalled && enableNotificationHUD {
                    nativePickerRow(
                        title: "Notification Preview",
                        subtitle: "Display body text in the Notify me! HUD"
                    ) {
                        SettingsSegmentButton(
                            icon: "eye",
                            label: "Preview On",
                            isSelected: notificationHUDShowPreview,
                            tileWidth: 82
                        ) {
                            notificationHUDShowPreview = true
                        }

                        SettingsSegmentButton(
                            icon: "eye.slash",
                            label: "Preview Off",
                            isSelected: !notificationHUDShowPreview,
                            tileWidth: 82
                        ) {
                            notificationHUDShowPreview = false
                        }
                    }
                }
                
                // Termi-Notch Extension
                if isTerminalNotchInstalled {
                    HStack(spacing: 12) {
                        ExtensionIconView<TermiNotchExtension>(definition: TermiNotchExtension.self, size: 40)
                            .opacity(enableTerminalNotch ? 1.0 : 0.5)
                        
                        // Extension is installed - show on/off toggle for HUD visibility
                        Toggle(isOn: $enableTerminalNotch) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Termi-Notch")
                                Text("Quick command bar in the shelf")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    nativePickerRow(
                        title: "Terminal App",
                        subtitle: "Used when opening the full terminal from Termi-Notch"
                    ) {
                        ForEach(TerminalNotchExternalApp.allCases) { app in
                            SettingsSegmentButton(
                                icon: app.icon,
                                label: app.title,
                                isSelected: terminalNotchExternalApp == app.rawValue,
                                tileWidth: 82
                            ) {
                                terminalNotchExternalApp = app.rawValue
                            }
                        }
                    }

                    let selectedTerminalApp = TerminalNotchExternalApp(rawValue: terminalNotchExternalApp) ?? .appleTerminal
                    if !selectedTerminalApp.isInstalled {
                        Text("\(selectedTerminalApp.title) is not installed. Droppy will fall back to Terminal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Extension is not installed - clickable card to open Extension Store
                    Button {
                        // Navigate to Extension Store with Termi-Notch selected
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenExtensionStore"),
                            object: nil,
                            userInfo: ["extension": TermiNotchExtension.id]
                        )
                    } label: {
                        HStack(spacing: 12) {
                            ExtensionIconView<TermiNotchExtension>(definition: TermiNotchExtension.self, size: 40)
                                .opacity(0.5)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Termi-Notch")
                                    .foregroundStyle(.secondary)
                                Text("Enable in Extension Store")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // Caffeine Extension
                if isCaffeineInstalled {
                    HStack(spacing: 12) {
                        ExtensionIconView<CaffeineExtension>(definition: CaffeineExtension.self, size: 40)
                            .opacity(enableCaffeine ? 1.0 : 0.5)
                        
                        // Extension is installed - show on/off toggle for HUD visibility
                        Toggle(isOn: $enableCaffeine) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("High Alert")
                                    if CaffeineManager.shared.isActive {
                                        Text(CaffeineManager.shared.formattedRemaining)
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                                    }
                                }
                                Text("Keep your Mac awake")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if enableCaffeine {
                        nativePickerRow(
                            title: "Prevention Mode",
                            subtitle: "Choose what stays awake while High Alert is active"
                        ) {
                            ForEach(CaffeineMode.allCases, id: \.rawValue) { mode in
                                SettingsSegmentButton(
                                    icon: caffeineModeIcon(mode),
                                    label: caffeineModeTileLabel(mode),
                                    isSelected: selectedCaffeineMode == mode,
                                    tileWidth: 82
                                ) {
                                    HapticFeedback.tap()
                                    setCaffeineMode(mode)
                                }
                            }
                        }

                        Toggle(isOn: $caffeineInstantlyExpandShelfOnHover) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Instant Shelf Expand on Hover")
                                Text("Skip the High Alert mini timer on hover and open the shelf directly")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    // Extension is not installed - clickable card to open Extension Store
                    Button {
                        // Navigate to Extension Store with High Alert selected
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenExtensionStore"),
                            object: nil,
                            userInfo: ["extension": CaffeineExtension.id]
                        )
                    } label: {
                        HStack(spacing: 12) {
                            ExtensionIconView<CaffeineExtension>(definition: CaffeineExtension.self, size: 40)
                                .opacity(0.5)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("High Alert")
                                    .foregroundStyle(.secondary)
                                Text("Enable in Extension Store")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Notchface Extension
                if isCameraInstalled {
                    HStack(spacing: 12) {
                        ExtensionIconView<CameraExtension>(definition: CameraExtension.self, size: 40)
                            .opacity(enableCamera ? 1.0 : 0.5)

                        Toggle(isOn: $enableCamera) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notchface")
                                Text("Show the camera button and preview mode")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if enableCamera {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text("Camera Source")
                                    Button {
                                        cameraManager.refreshAvailableDevices()
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .buttonStyle(DroppyCircleButtonStyle(size: 24))
                                    .help("Refresh connected cameras")
                                }

                                Text("Choose which connected camera Notchface should use.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(alignment: .center, spacing: 8) {
                                SettingsSegmentButton(
                                    icon: "camera.metering.center.weighted",
                                    label: "Auto",
                                    isSelected: normalizedCameraPreferredDeviceID == nil,
                                    tileWidth: 86
                                ) {
                                    selectNotchfaceCamera(nil)
                                }

                                ForEach(cameraManager.availableCameraDevices) { device in
                                    SettingsSegmentButton(
                                        icon: device.icon,
                                        label: cameraSourceTileLabel(for: device.displayName),
                                        isSelected: normalizedCameraPreferredDeviceID == device.id,
                                        tileWidth: 86
                                    ) {
                                        selectNotchfaceCamera(device.id)
                                    }
                                }
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .onAppear {
                            cameraManager.refreshAvailableDevices()
                        }

                        if cameraManager.availableCameraDevices.isEmpty {
                            Text("No connected cameras detected. Grant camera permission and connect a camera.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if isCameraPreferredDeviceMissing {
                            Text("Previously selected camera is not connected. Auto mode is being used.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Selected: \(selectedNotchfaceCameraDisplayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Button {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenExtensionStore"),
                            object: nil,
                            userInfo: ["extension": CameraExtension.id]
                        )
                    } label: {
                        HStack(spacing: 12) {
                            ExtensionIconView<CameraExtension>(definition: CameraExtension.self, size: 40)
                                .opacity(0.5)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notchface")
                                    .foregroundStyle(.secondary)
                                Text("Enable in Extension Store")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Extensions")
            }
            
            // MARK: Peripherals
            Section {
                // AirPods & Headphones
                HStack(spacing: 12) {
                    AirPodsHUDIcon()
                    
                    Toggle(isOn: $enableAirPodsHUD) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AirPods & Headphones")
                            Text("Show when connected with battery and 3D animation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableAirPodsHUD) { _, newValue in
                    if newValue {
                        NotchWindowController.shared.setupNotchWindow()
                        AirPodsManager.shared.startMonitoring()
                    } else {
                        AirPodsManager.shared.stopMonitoring()
                        closeNotchWindowIfUnused()
                    }
                }
            } header: {
                Text("Audio")
            }
            
            // MARK: Screen State (Focus Mode only - Lock Screen moved to dedicated tab)
            Section {
                // Focus Mode
                HStack(spacing: 12) {
                    FocusModeHUDIcon()
                    
                    Toggle(isOn: $enableDNDHUD) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Focus Mode")
                            Text("Show when toggled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableDNDHUD) { _, newValue in
                    if newValue {
                        NotchWindowController.shared.setupNotchWindow()
                        if !DNDManager.shared.hasAccess {
                            showDNDAccessAlert = true
                        }
                    } else {
                        closeNotchWindowIfUnused()
                    }
                }
                .sheet(isPresented: $showDNDAccessAlert) {
                    FullDiskAccessSheet(
                        enableDNDHUD: $enableDNDHUD,
                        isPresented: $showDNDAccessAlert
                    )
                }
                
                if !DNDManager.shared.hasAccess && enableDNDHUD {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 14))
                            Text("Requires Full Disk Access")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Needed to read Focus Mode state from macOS system files")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 22)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } header: {
                Text("Focus")
            }
        }
    }

    private func normalizeVisualizerModeIfNeeded() {
        if enableRealAudioVisualizer && enableGradientVisualizer {
            enableGradientVisualizer = false
        } else if !enableRealAudioVisualizer && !enableGradientVisualizer {
            enableGradientVisualizer = true
        }
    }

    private func selectRealAudioVisualizerMode() {
        guard !(enableRealAudioVisualizer && !enableGradientVisualizer) else { return }
        enableRealAudioVisualizer = true
        enableGradientVisualizer = false

        Task {
            await SystemAudioAnalyzer.shared.requestPermission()
        }
    }

    private func selectGradientVisualizerMode() {
        guard !(!enableRealAudioVisualizer && enableGradientVisualizer) else { return }
        enableRealAudioVisualizer = false
        enableGradientVisualizer = true
    }

    private func selectICloudDriveCloudAction() {
        guard quickActionsCloudProvider != QuickActionsCloudProvider.iCloudDrive.rawValue else { return }

        let isReady = QuickActionsCloudShare.ensureICloudDriveAccessReady(showErrors: true)
        if isReady {
            quickActionsCloudProvider = QuickActionsCloudProvider.iCloudDrive.rawValue
        } else {
            quickActionsCloudProvider = QuickActionsCloudProvider.droppyQuickshare.rawValue
        }
    }
    
    private var integrationsSettings: some View {
        ExtensionsShopView()
            .sheet(item: $deepLinkedExtension) { extensionType in
                // AI Background Removal has its own view
                if extensionType == .aiBackgroundRemoval {
                    AIInstallView()
                } else if extensionType == .windowSnap {
                    // Window Snap has its own detailed configuration view
                    WindowSnapInfoView(installCount: nil, rating: nil)
                } else if extensionType == .elementCapture {
                    // Element Capture has its own detailed configuration view
                    ElementCaptureInfoView(currentShortcut: .constant(nil), installCount: nil, rating: nil)
                } else if extensionType == .voiceTranscribe {
                    // Voice Transcribe has its own detailed configuration view
                    VoiceTranscribeInfoView(installCount: nil, rating: nil)
                } else if extensionType == .ffmpegVideoCompression {
                    // FFmpeg Video Compression has its own install view
                    FFmpegInstallView(installCount: nil, rating: nil)
                } else if extensionType == .camera {
                    CameraInfoView(installCount: nil, rating: nil)
                } else if extensionType == .menuBarManager {
                    // Menu Bar Manager has its own configuration view
                    MenuBarManagerInfoView(installCount: nil, rating: nil)
                } else {
                    // All other extensions use ExtensionInfoView
                    ExtensionInfoView(extensionType: extensionType) {
                        // Handle action based on type
                        switch extensionType {
                        case .alfred:
                            if let workflowPath = Bundle.main.path(forResource: "Droppy", ofType: "alfredworkflow") {
                                NSWorkspace.shared.open(URL(fileURLWithPath: workflowPath))
                            }
                        case .finder, .finderServices:
                            _ = openFinderServicesSettings()
                        case .spotify:
                            SpotifyAuthManager.shared.startAuthentication()
                        case .appleMusic:
                            AppleMusicController.shared.refreshState()
                        case .elementCapture, .aiBackgroundRemoval, .windowSnap, .voiceTranscribe, .ffmpegVideoCompression, .terminalNotch, .camera, .quickshare, .notificationHUD, .caffeine, .menuBarManager, .todo:
                            break // No action needed - these have their own configuration UI
                        }
                    }
                }
            }
    }

    
    private var quickshareSettings: some View {
        Group {
            if !ExtensionType.quickshare.isRemoved {
                QuickshareSettingsContent()
            }
        }
    }
    
    private var appearanceSettings: some View {
        Group {
            // MARK: Visual Style
            Section {
                Toggle(isOn: $useTransparentBackground) {
                    VStack(alignment: .leading) {
                        Text("Transparent Background")
                        Text("Use glass effect for windows (not shelf)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 8) {
                    ExternalDisplayInfoButton()
                    Toggle(isOn: $hideNotchOnExternalDisplays) {
                        VStack(alignment: .leading) {
                            Text("Hide on External Displays")
                            Text("Disable notch shelf on external monitors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Show external display mode picker when not hidden
                if !hideNotchOnExternalDisplays {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("External Display Style")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            SettingsSegmentButtonWithContent(
                                label: "Notch",
                                isSelected: !externalDisplayUseDynamicIsland,
                                action: { externalDisplayUseDynamicIsland = false }
                            ) {
                                UShape()
                                    .fill(!externalDisplayUseDynamicIsland ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 44, height: 14)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: externalDisplayUseDynamicIsland,
                                action: { externalDisplayUseDynamicIsland = true }
                            ) {
                                Capsule()
                                    .fill(externalDisplayUseDynamicIsland ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 44, height: 14)
                            }
                        }

                        externalDisplayAdvancedOptions
                    }
                }
            } header: {
                Text("Visual Style")
            }
            
            // MARK: Display Mode (Non-notch displays only)
            // MacBooks WITH a physical notch MUST use notch mode - no choice
            // Only non-notch Macs (iMacs, Mac minis, older MacBooks) can choose
            if !hasPhysicalNotch {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Mode")
                            .font(.headline)
                        
                        Text("Choose how Droppy appears at the top of your screen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            SettingsSegmentButtonWithContent(
                                label: "Notch",
                                isSelected: !useDynamicIslandStyle,
                                action: { useDynamicIslandStyle = false }
                            ) {
                                UShape()
                                    .fill(!useDynamicIslandStyle ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 50, height: 16)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: useDynamicIslandStyle,
                                action: { useDynamicIslandStyle = true }
                            ) {
                                Capsule()
                                    .fill(useDynamicIslandStyle ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 40, height: 14)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Display Mode")
                }
            }
            
            // MARK: Shelf Behavior
            Section {
                // Auto-Collapse toggle with delay slider
                Toggle(isOn: $autoCollapseShelf) {
                    VStack(alignment: .leading) {
                        Text("Auto-Collapse")
                        Text("Shrink shelf when mouse leaves")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if autoCollapseShelf {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Collapse Delay")
                            Spacer()
                            Text(String(format: "%.2fs", autoCollapseDelay))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $autoCollapseDelay, in: 0.1...2.0, step: 0.05)
                            .sliderHaptics(value: autoCollapseDelay, range: 0.1...2.0)
                    }
                }
                
                // Auto-Expand can be toggled, with delay slider
                Toggle(isOn: $autoExpandShelf) {
                    VStack(alignment: .leading) {
                        Text("Auto-Expand")
                        Text("Expand shelf when hovering over notch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if autoExpandShelf {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Expand Delay")
                            Spacer()
                            Text(String(format: "%.2fs", autoExpandDelay))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $autoExpandDelay, in: 0.1...2.0, step: 0.05)
                            .sliderHaptics(value: autoExpandDelay, range: 0.1...2.0)
                    }
                }
            } header: {
                Text("Shelf Behavior")
            }
            
            // MARK: Indicators (merged from Accessibility tab)
            indicatorsSettings
        }
    }
    
    private var indicatorsSettings: some View {
        Group {
            Section {
                Toggle(isOn: $showClipboardButton) {
                    VStack(alignment: .leading) {
                        Text("Clipboard in Menu")
                        Text("Adds \"Open Clipboard\" to right-click menu on notch/island")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Toggle(isOn: $hideNotchFromScreenshots) {
                    VStack(alignment: .leading) {
                        Text("Hide from Screenshots")
                        Text("Exclude the notch area from screenshots and screen recordings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: hideNotchFromScreenshots) { _, newValue in
                    // Apply the setting to the notch window
                    NotchWindowController.shared.updateScreenshotVisibility()
                }
                
                Toggle(isOn: $enableRightClickHide) {
                    VStack(alignment: .leading) {
                        Text("Right-Click to Hide")
                        Text("Show 'Hide Notch/Island' option in right-click menu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Toggle(isOn: $enableHapticFeedback) {
                    VStack(alignment: .leading) {
                        Text("Haptic Feedback")
                        Text("Play haptic patterns when dropping files or performing actions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Accessibility")
            } footer: {
                Text("Visual hints, quick-access buttons, and screenshot visibility.")
            }
        }
    }
    
    private var aboutSettings: some View {
        Group {
            // MARK: About
            Section {
                HStack(spacing: 16) {
                    // App Icon
                    if let appIcon = NSApp.applicationIconImage {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Droppy")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Version \(UpdateChecker.shared.currentVersion)")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        if let downloads = downloadCount {
                            Text("\(downloads) users")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                
                LabeledContent("Developer", value: "Jordy Spruit")
                
                HStack {
                    Text("Introduction")
                    Spacer()
                    Button {
                        OnboardingWindowController.shared.show()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                            Text("Open")
                        }
                    }
                    .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                }
            } header: {
                Text("About")
            }
            
            // MARK: Links
            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    LinkButton(
                        title: "Website",
                        icon: "globe",
                        url: "https://getdroppy.app"
                    )
                    
                    LinkButton(
                        title: "GitHub",
                        icon: "chevron.left.forwardslash.chevron.right",
                        url: "https://github.com/iordv/Droppy"
                    )
                    
                    LinkButton(
                        title: "Discord",
                        icon: "bubble.left.and.bubble.right.fill",
                        url: "https://discord.gg/YCMDFV5M7d"
                    )
                }
            } header: {
                Text("Links")
            }

            Section {
                Toggle(isOn: $disableAnalytics) {
                    VStack(alignment: .leading) {
                        Text("Skip All Analytics")
                        Text("Disable usage analytics and hide extension install/download stats")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: disableAnalytics) { _, isDisabled in
                    if isDisabled {
                        downloadCount = nil
                    } else {
                        Task {
                            if let count = try? await AnalyticsService.shared.fetchDownloadCount() {
                                downloadCount = count
                            }
                        }
                    }
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Analytics are optional and can be disabled at any time.")
            }
            
            // MARK: Reset
            Section {
                Toggle(isOn: $hardResetIncludeClipboard) {
                    VStack(alignment: .leading) {
                        Text("Include Clipboard")
                        Text("Also clear clipboard history when resetting")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Hard Reset")
                        Text("Reset all settings to defaults")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        showHardResetConfirmation = true
                    } label: {
                        Text("Reset")
                    }
                    .buttonStyle(DroppyAccentButtonStyle(color: .red, size: .small))
                }
            } header: {
                Text("Troubleshooting")
            } footer: {
                Text("Use this if settings become stuck or broken after an update.")
            }
            .alert("Hard Reset Droppy?", isPresented: $showHardResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset Everything", role: .destructive) {
                    performHardReset()
                }
            } message: {
                Text(hardResetIncludeClipboard
                    ? "This will reset ALL settings and clear clipboard history. Droppy will restart."
                    : "This will reset ALL settings (clipboard history will be preserved). Droppy will restart.")
            }
        }
        .onAppear {
            Task {
                guard !disableAnalytics else {
                    downloadCount = nil
                    return
                }
                if let count = try? await AnalyticsService.shared.fetchDownloadCount() {
                    downloadCount = count
                }
            }
        }
    }
    
    @State private var downloadCount: Int?
    
    // MARK: - Hard Reset
    
    /// Performs a complete reset of all Droppy settings
    /// This is designed to be 100% reliable - clears EVERYTHING
    private func performHardReset() {
        print("[HardReset] Starting complete reset…")
        
        // Get the bundle identifier
        guard let bundleID = Bundle.main.bundleIdentifier else {
            print("[HardReset] ERROR: Failed to get bundle identifier")
            return
        }
        
        // STEP 1: Backup clipboard data if user wants to preserve it
        var clipboardBackup: [String: Any] = [:]
        var clipboardFileBackup: URL?
        
        if !hardResetIncludeClipboard {
            // Backup clipboard history from UserDefaults
            if let defaults = UserDefaults.standard.persistentDomain(forName: bundleID) {
                // Common clipboard key patterns
                let clipboardKeys = defaults.keys.filter { key in
                    key.lowercased().contains("clipboard")
                }
                for key in clipboardKeys {
                    if let value = defaults[key] {
                        clipboardBackup[key] = value
                    }
                }
            }
            
            // Backup clipboard persistence file if it exists
            let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            let basePath = paths.first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
            let clipboardFile = basePath.appendingPathComponent("Droppy/clipboard.json")
            if FileManager.default.fileExists(atPath: clipboardFile.path) {
                let tempBackup = FileManager.default.temporaryDirectory.appendingPathComponent("clipboard_backup.json")
                try? FileManager.default.copyItem(at: clipboardFile, to: tempBackup)
                clipboardFileBackup = tempBackup
            }
            
            print("[HardReset] Backed up clipboard data (\(clipboardBackup.count) keys)")
        }
        
        // STEP 2: Clear ALL UserDefaults for this app
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        UserDefaults.standard.synchronize()
        print("[HardReset] Cleared UserDefaults")
        
        // STEP 3: Clear NSStatusItem position cache (system-level)
        // These are stored with prefix "NSStatusItem Preferred Position"
        let statusItemKeys = [
            "NSStatusItem Preferred Position DroppyMenuBarToggle",
            "NSStatusItem Preferred Position DroppyMenuBarDivider",
            "NSStatusItem Preferred Position DroppyStatusItem"
        ]
        for key in statusItemKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
        print("[HardReset] Cleared status item positions")
        
        // STEP 4: Clear Application Support folder
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let baseAppSupport = paths.first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let appSupportDir = baseAppSupport.appendingPathComponent("Droppy", isDirectory: true)
        
        if hardResetIncludeClipboard {
            // Delete entire Droppy folder
            try? FileManager.default.removeItem(at: appSupportDir)
            print("[HardReset] Deleted entire Application Support/Droppy folder")
        } else {
            // Delete everything EXCEPT clipboard files
            if let contents = try? FileManager.default.contentsOfDirectory(at: appSupportDir, includingPropertiesForKeys: nil) {
                for item in contents {
                    let filename = item.lastPathComponent.lowercased()
                    // Keep clipboard-related files
                    if !filename.contains("clipboard") {
                        try? FileManager.default.removeItem(at: item)
                    }
                }
            }
            // Still delete images folder if clearing clipboard
            let imagesDir = appSupportDir.appendingPathComponent("images", isDirectory: true)
            if hardResetIncludeClipboard {
                try? FileManager.default.removeItem(at: imagesDir)
            }
            print("[HardReset] Deleted Application Support contents (preserved clipboard)")
        }
        
        // STEP 5: Restore clipboard if preserved
        if !hardResetIncludeClipboard {
            // Restore UserDefaults clipboard keys
            for (key, value) in clipboardBackup {
                UserDefaults.standard.set(value, forKey: key)
            }
            UserDefaults.standard.synchronize()
            
            // Restore clipboard file if backed up
            if let backupURL = clipboardFileBackup {
                let clipboardFile = appSupportDir.appendingPathComponent("clipboard.json")
                try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
                try? FileManager.default.moveItem(at: backupURL, to: clipboardFile)
            }
            
            print("[HardReset] Restored clipboard data")
        }
        
        // STEP 6: Clear Caches
        if let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let droppyCaches = cachesDir.appendingPathComponent(bundleID, isDirectory: true)
            try? FileManager.default.removeItem(at: droppyCaches)
            print("[HardReset] Cleared caches")
        }
        
        print("[HardReset] ✅ Reset complete - restarting app…")
        
        // STEP 7: Restart app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Relaunch the app using the bundle path
            let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
            let appPath = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [appPath]
            task.launch()
            
            // Quit current instance
            NSApp.terminate(nil)
        }
    }
    
    // MARK: - Clipboard
    @AppStorage(AppPreferenceKey.showClipboardInMenuBar) private var showClipboardInMenuBar = PreferenceDefault.showClipboardInMenuBar
    @AppStorage(AppPreferenceKey.enableClipboard) private var enableClipboard = PreferenceDefault.enableClipboard
    @AppStorage(AppPreferenceKey.clipboardHistoryLimit) private var clipboardHistoryLimit = PreferenceDefault.clipboardHistoryLimit
    @AppStorage(AppPreferenceKey.clipboardAutoFocusSearch) private var autoFocusSearch = PreferenceDefault.clipboardAutoFocusSearch
    @AppStorage(AppPreferenceKey.clipboardTagsEnabled) private var tagsEnabled = PreferenceDefault.clipboardTagsEnabled
    @State private var currentShortcut: SavedShortcut?
    @State private var showAppPicker: Bool = false
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    
    // Custom Persistence for struct
    private func loadShortcut() {
        if let data = UserDefaults.standard.data(forKey: "clipboardShortcut"),
           let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            currentShortcut = decoded
        } else {
            // Default: Shift + Cmd + Space (49)
            currentShortcut = SavedShortcut(keyCode: 49, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
        }
    }
    
    private func saveShortcut(_ shortcut: SavedShortcut?) {
        if let s = shortcut, let encoded = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(encoded, forKey: "clipboardShortcut")
            // Update active monitor
            if enableClipboard {
                 ClipboardWindowController.shared.startMonitoringShortcut()
            }
        }
    }
    
    // MARK: - Copy+Favorite Shortcut (Issue #43)
    @AppStorage(AppPreferenceKey.clipboardCopyFavoriteEnabled) private var copyFavoriteEnabled = PreferenceDefault.clipboardCopyFavoriteEnabled
    @State private var copyFavoriteShortcut: SavedShortcut?
    
    private func loadCopyFavoriteShortcut() {
        if let data = UserDefaults.standard.data(forKey: "clipboardCopyFavoriteShortcut"),
           let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            copyFavoriteShortcut = decoded
        } else {
            // Default: Cmd+Shift+C
            copyFavoriteShortcut = SavedShortcut(keyCode: 8, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
        }
    }
    
    private func saveCopyFavoriteShortcut(_ shortcut: SavedShortcut?) {
        if let s = shortcut, let encoded = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(encoded, forKey: "clipboardCopyFavoriteShortcut")
            // Restart the shortcut
            if copyFavoriteEnabled {
                ClipboardWindowController.shared.startCopyFavoriteShortcut()
            }
        }
    }
    
    private var clipboardSettings: some View {
        Section {
            HStack(spacing: 8) {
                ClipboardShortcutInfoButton(shortcut: currentShortcut)
                Toggle(isOn: $enableClipboard) {
                    VStack(alignment: .leading) {
                        Text("Clipboard Manager")
                        Text("History with Preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Toggle(isOn: $showClipboardInMenuBar) {
                VStack(alignment: .leading) {
                    Text("Show in Menu Bar")
                    Text("Access clipboard history from the menu bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 28)
            .disabled(!enableClipboard)
            .onChange(of: enableClipboard) { oldValue, newValue in
                if newValue {
                    // Check for Accessibility Permissions using centralized manager
                    if !PermissionManager.shared.isAccessibilityGranted {
                        // Only prompt if not already trusted
                        PermissionManager.shared.requestAccessibility(context: .userInitiated)
                        print("Prompting for Accessibility permissions")
                    }
                    
                    ClipboardManager.shared.startMonitoring()
                    ClipboardWindowController.shared.startMonitoringShortcut()
                } else {
                    ClipboardManager.shared.stopMonitoring()
                    ClipboardWindowController.shared.stopMonitoringShortcut()
                    ClipboardWindowController.shared.close()
                }
            }

            Toggle(isOn: $showClipboardButton) {
                VStack(alignment: .leading) {
                    Text("Show in Shelf Context Menu")
                    Text("Adds \"Open Clipboard\" to right-click menu on notch/island")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 28)
            .disabled(!enableClipboard)
            
            if enableClipboard {
                ClipboardPreview()
                
                HStack {
                    Text("Global Shortcut")
                        .frame(minWidth: 120, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                    KeyShortcutRecorder(shortcut: Binding(
                        get: { currentShortcut },
                        set: { newVal in
                            currentShortcut = newVal
                            saveShortcut(newVal)
                        }
                    ))
                    
                    if currentShortcut != nil {
                        Button {
                            let defaultShortcut = SavedShortcut(
                                keyCode: 49,
                                modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue
                            )
                            currentShortcut = defaultShortcut
                            saveShortcut(defaultShortcut)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(DroppyCircleButtonStyle(size: 32))
                        .help("Reset Shortcut")
                    }
                }
                
                VStack(spacing: 10) {
                    HStack {
                        Text("History Limit")
                        Spacer()
                        Text("\(clipboardHistoryLimit) items")
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(clipboardHistoryLimit) },
                        set: { clipboardHistoryLimit = Int($0) }
                    ), in: 10...200, step: 10)
                    .accentColor(.cyan)
                }
                .onChange(of: clipboardHistoryLimit) { oldValue, newValue in
                    // Haptic feedback for slider
                    let isEndpoint = newValue == 10 || newValue == 200
                    if isEndpoint {
                        HapticFeedback.sliderEndpoint()
                    } else {
                        HapticFeedback.sliderTick()
                    }
                    ClipboardManager.shared.enforceHistoryLimit()
                }
                
                // Skip passwords toggle
                Toggle(isOn: $clipboardManager.skipConcealedContent) {
                    VStack(alignment: .leading) {
                        Text("Skip Passwords")
                        Text("Don't record passwords from password managers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                nativePickerRow(
                    title: "Clipboard Actions",
                    subtitle: "Enable advanced actions for managing clips"
                ) {
                    // Enable Tags
                    SettingsSegmentButtonWithContent(
                        label: "Tags",
                        isSelected: tagsEnabled,
                        action: { tagsEnabled.toggle() }
                    ) {
                        Image(systemName: "tag")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(tagsEnabled ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                    }
                    
                    // Copy + Favorite
                    SettingsSegmentButtonWithContent(
                        label: "Copy + Favorite",
                        isSelected: copyFavoriteEnabled,
                        tileWidth: 122,
                        action: {
                            copyFavoriteEnabled.toggle()
                            if copyFavoriteEnabled {
                                ClipboardWindowController.shared.startCopyFavoriteShortcut()
                            } else {
                                ClipboardWindowController.shared.stopCopyFavoriteShortcut()
                            }
                        }
                    ) {
                        Image(systemName: "heart")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(copyFavoriteEnabled ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                    }
                    
                    // Auto-Focus Search
                    SettingsSegmentButtonWithContent(
                        label: "Auto-Focus",
                        isSelected: autoFocusSearch,
                        action: {
                            if !autoFocusSearch {
                                showAutoFocusSearchWarning = true
                            }
                            autoFocusSearch.toggle()
                        }
                    ) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(autoFocusSearch ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                    }
                }
                .sheet(isPresented: $showAutoFocusSearchWarning) {
                    AutoFocusSearchInfoSheet(autoFocusSearch: $autoFocusSearch)
                }
                
                // Shortcut row appears when Copy+Favorite is enabled
                if copyFavoriteEnabled {
                    HStack {
                        Text("Shortcut")
                            .frame(minWidth: 74, alignment: .leading)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer()
                        KeyShortcutRecorder(shortcut: Binding(
                            get: { copyFavoriteShortcut },
                            set: { newVal in
                                copyFavoriteShortcut = newVal
                                saveCopyFavoriteShortcut(newVal)
                            }
                        ))
                        
                        if copyFavoriteShortcut != nil {
                            Button {
                                let defaultShortcut = SavedShortcut(
                                    keyCode: 8,
                                    modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue
                                )
                                copyFavoriteShortcut = defaultShortcut
                                saveCopyFavoriteShortcut(defaultShortcut)
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                            }
                            .buttonStyle(DroppyCircleButtonStyle(size: 32))
                            .help("Reset Shortcut")
                        }
                    }
                }
                
                // MARK: - Excluded Apps Section
                excludedAppsSection
            }
        } header: {
            Text("Clipboard")
        } footer: {
            Text("Requires Accessibility permissions to paste. Shortcuts may conflict with other apps.")
        }
        .onAppear {
            loadShortcut()
            loadCopyFavoriteShortcut()
        }
    }
    
    // MARK: - Excluded Apps Section
    private var excludedAppsSection: some View {
        Section {
            // List of excluded apps
            ForEach(Array(clipboardManager.excludedApps).sorted(), id: \.self) { bundleID in
                HStack(spacing: 12) {
                    // App icon
                    if let appPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                        Image(nsImage: ThumbnailCache.shared.cachedIcon(forPath: appPath.path))
                            .resizable()
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    
                    // App name
                    VStack(alignment: .leading) {
                        Text(appName(for: bundleID))
                            .font(.body)
                        Text(bundleID)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    // Remove button
                    Button {
                        withAnimation(DroppyAnimation.state) {
                            clipboardManager.removeExcludedApp(bundleID)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(DroppyCircleButtonStyle(size: 18))
                }
                .padding(.vertical, 4)
            }
            
            // Add app button
            Button {
                showAppPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add App…")
                }
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            .popover(isPresented: $showAppPicker, arrowEdge: .bottom) {
                appPickerView
            }
        } header: {
            Text("Excluded Apps")
        } footer: {
            Text("Clipboard entries from these apps won't be recorded. Useful for password managers.")
        }
    }
    
    // MARK: - App Picker View
    private var appPickerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Select App to Exclude")
                .font(.headline)
                .padding()
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button {
                            if let bundleID = app.bundleIdentifier {
                                withAnimation(DroppyAnimation.state) {
                                    clipboardManager.addExcludedApp(bundleID)
                                }
                                showAppPicker = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 28, height: 28)
                                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(app.localizedName ?? "Unknown")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if let bundleID = app.bundleIdentifier {
                                        Text(bundleID)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                
                                Spacer()
                                
                                if let bundleID = app.bundleIdentifier,
                                   clipboardManager.isAppExcluded(bundleID) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(DroppySelectableButtonStyle(isSelected: clipboardManager.isAppExcluded(app.bundleIdentifier ?? "")))
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(width: 320, height: 300)
        }
        .background(AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Properties
    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.icon != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
    
    private func appName(for bundleID: String) -> String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: appURL.path)
        }
        return bundleID
    }
}

// MARK: - Visual Effect View (Settings)

private struct SettingsVisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var isEmphasized: Bool = true
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = isEmphasized
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = isEmphasized
    }
}
// MARK: - Launch Handler

struct LaunchAtLoginManager {
    static func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if #available(macOS 13.0, *) {
                    try SMAppService.mainApp.register()
                }
            } else {
                if #available(macOS 13.0, *) {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }
}

// MARK: - Auto-Select Number Field
struct AutoSelectNumberField: NSViewRepresentable {
    @Binding var value: Int
    @Binding var isEditing: Bool
    
    func makeNSView(context: Context) -> ClickSelectingTextField {
        let textField = ClickSelectingTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.textColor = .labelColor
        textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textField.alignment = .center
        textField.focusRingType = .none
        textField.stringValue = String(value)
        
        // Route focus changes to the coordinator
        textField.onFocusChange = { [weak coordinator = context.coordinator] isFocused in
            coordinator?.didChangeFocus(isFocused)
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: ClickSelectingTextField, context: Context) {
        // Critical: Update parent reference so Coorindator has the latest Binding
        context.coordinator.parent = self
        
        if !isEditing && nsView.stringValue != String(value) {
            nsView.stringValue = String(value)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AutoSelectNumberField
        
        init(_ parent: AutoSelectNumberField) {
            self.parent = parent
        }
        
        func didChangeFocus(_ isFocused: Bool) {
            // Update immediately to ensure UI is responsive
            self.parent.isEditing = isFocused
        }
        
        func controlTextDidBeginEditing(_ obj: Notification) {
             didChangeFocus(true)
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            // Use async here to allow value validation logic to complete
            DispatchQueue.main.async {
                self.parent.isEditing = false
                if let textField = obj.object as? NSTextField {
                    if let val = Int(textField.stringValue) {
                        self.parent.value = val
                    } else {
                        textField.stringValue = String(self.parent.value)
                    }
                }
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let textField = control as? NSTextField {
                    textField.window?.makeFirstResponder(nil)
                }
                return true
            }
            return false
        }
    }
}

class ClickSelectingTextField: NSTextField {
    // Callback to notify parent of focus changes immediately
    var onFocusChange: ((Bool) -> Void)?
    
    override func becomeFirstResponder() -> Bool {
        let success = super.becomeFirstResponder()
        if success {
            onFocusChange?(true)
            // Use performSelector to avoid QoS priority inversion warning
            self.perform(#selector(selectText(_:)), with: nil, afterDelay: 0.0)
        }
        return success
    }
    
    override func resignFirstResponder() -> Bool {
        let success = super.resignFirstResponder()
        if success {
            onFocusChange?(false)
        }
        return success
    }
    
    override func mouseDown(with event: NSEvent) {
        // Ensure standard click processing happens
        super.mouseDown(with: event)
        
        // Then force selection
        if let textEditor = self.currentEditor() {
            textEditor.selectAll(nil)
        }
        
        // And notify focus
        onFocusChange?(true)
    }
}

private extension View {
    func droppyTooltipPopoverStyle(width: CGFloat) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .frame(width: width, alignment: .leading)
    }
}

// MARK: - Swipe Gesture Info Button

/// Info button that shows a popover explaining the swipe gesture for media/shelf switching
struct SwipeGestureInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        PremiumSettingsIcon(icon: "hand.draw.fill", baseHue: 0.95, size: 32, iconSize: 16)
                        Text("Swipe Gesture")
                            .font(.headline)
                    }
                    
                    Text("Swipe left or right on the notch to switch between Media Controls and the File Shelf.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Swipe left → Media Controls", systemImage: "music.note")
                        Label("Swipe right → File Shelf", systemImage: "tray.and.arrow.down.fill")
                        Label("Quick toggle between modes", systemImage: "arrow.left.arrow.right")
                        Label("Optional mouse gesture in Now Playing settings", systemImage: "computermouse")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

// MARK: - Notch Shelf Info Button

/// Info button explaining right-click to hide and show
struct NotchShelfInfoButton: View {
    @AppStorage(AppPreferenceKey.enableRightClickHide) private var enableRightClickHide = PreferenceDefault.enableRightClickHide
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.topthird.inset.filled")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue)
                        Text("Notch Shelf")
                            .font(.headline)
                    }
                    
                    Text("A file shelf that lives in your Mac's notch or as an Island.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        if enableRightClickHide {
                            Label("Right-click to hide the notch/island", systemImage: "cursorarrow.click.2")
                            Label("Right-click the area again to show", systemImage: "eye")
                        }
                        Label("Or use the menu bar icon", systemImage: "menubar.arrow.up.rectangle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }

    }
}

// MARK: - Basket Gesture Info Button

/// Info button explaining the jiggle gesture to summon basket
struct BasketGestureInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.purple)
                        Text("Summon Basket")
                            .font(.headline)
                    }
                    
                    Text("Shake files side-to-side while dragging to summon the floating basket.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Works with any file you're dragging", systemImage: "doc.fill")
                        Label("Basket appears after 2-3 quick shakes", systemImage: "arrow.left.arrow.right")
                        Label("Drop files into the basket", systemImage: "tray.and.arrow.down")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

// MARK: - Auto-Hide Info Button

/// Info button explaining auto-hide behavior
struct JiggleToShowInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 24))
                            .foregroundStyle(.purple)
                        Text("Auto-Hide")
                            .font(.headline)
                    }
                    
                    Text("Basket hides after a delay when your cursor leaves. Use your Basket Switcher shortcut to reopen hidden baskets.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Hides after configurable delay", systemImage: "timer")
                        Label("Jiggle while dragging files still works", systemImage: "arrow.left.arrow.right")
                        Label("Use Basket Switcher shortcut to reveal hidden baskets", systemImage: "keyboard")
                        Label("Baskets with items are preserved", systemImage: "tray.full.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

/// Legacy alias for backward compatibility
typealias PeekModeInfoButton = JiggleToShowInfoButton

// MARK: - Instant Appear Info Button

/// Info button explaining instant basket appear on drag
struct InstantAppearInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.orange)
                        Text("Instant Appear")
                            .font(.headline)
                    }
                    
                    Text("Basket appears immediately when you start dragging a file.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("No delay when dragging starts", systemImage: "hand.point.up.left.fill")
                        Label("Basket is ready right away", systemImage: "basket.fill")
                        Label("Great for quick file staging", systemImage: "bolt")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

// MARK: - Shake Sensitivity Info Button

/// Info button explaining shake sensitivity for basket summon
struct BasketSensitivityInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 24))
                            .foregroundStyle(.orange)
                        Text("Shake Sensitivity")
                            .font(.headline)
                    }
                    
                    Text("Adjust how much movement is needed before basket summon triggers during drag.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Low: requires stronger shake", systemImage: "tortoise.fill")
                        Label("High: triggers with lighter shake", systemImage: "hare.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

// MARK: - Drag Shortcut Info Button

/// Info button explaining the drag-time shortcut to reveal basket
struct BasketDragShortcutInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue)
                        Text("Drag Shortcut")
                            .font(.headline)
                    }
                    
                    Text("Set a shortcut that reveals the basket instantly while a drag is active.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Only triggers during drag", systemImage: "hand.draw.fill")
                        Label("Works as a quick reveal fallback", systemImage: "bolt.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

// MARK: - AirDrop Zone Info Button

/// Info button explaining the AirDrop drop zone
struct AirDropZoneInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "airplayaudio")
                            .font(.system(size: 24))
                            .foregroundStyle(.cyan)
                        Text("AirDrop Zone")
                            .font(.headline)
                    }
                    
                    Text("Drop files on the right side of shelf/basket to instantly open the AirDrop picker.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Drop on the right edge", systemImage: "arrow.right.circle")
                        Label("Opens system AirDrop picker", systemImage: "person.2.wave.2")
                        Label("Select a nearby device to send", systemImage: "iphone.and.arrow.right.outward")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

// MARK: - Auto-Clean Info Button

/// Info button explaining the Clear After Drop feature
struct AutoCleanInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)
                        Text("Auto-Remove")
                            .font(.headline)
                    }
                    
                    Text("Automatically removes items from shelf/basket after you drop them somewhere.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Clears item from shelf/basket", systemImage: "xmark.circle")
                        Label("Original file is NOT deleted", systemImage: "doc.text")
                        Label("Keeps your shelf tidy", systemImage: "sparkles")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 320)
            }
    }
}

// MARK: - Always Copy Info Button

/// Info button explaining the Protect Originals feature
struct AlwaysCopyInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)
                        Text("Protect Originals")
                            .font(.headline)
                    }
                    
                    Text("When enabled, files are always copied instead of moved, keeping originals safe.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Files are copied, never moved", systemImage: "doc.on.doc")
                        Label("Original stays at source location", systemImage: "lock.shield")
                        Label("When disabled: same disk = may move", systemImage: "exclamationmark.triangle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 320)
            }
    }
}

// MARK: - Protect Originals Warning Sheet

/// Warning sheet shown when user disables Protect Originals
struct ProtectOriginalsWarningSheet: View {
    @Binding var alwaysCopyOnDrag: Bool
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringConfirm = false
    @State private var isHoveringCancel = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with NotchFace
            VStack(spacing: 16) {
                NotchFace(size: 60, isExcited: false)
                
                Text("Disable File Protection?")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Content
            VStack(alignment: .center, spacing: 16) {
                Text("When you disable this setting:")
                    .font(.callout.weight(.medium))
                
                // Card with explanation items
                VStack(spacing: 0) {
                    // Warning item
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("Dragging files to the same disk may **delete** the original file")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(AdaptiveColors.overlayAuto(0.04)).frame(height: 0.5)
                    }
                    
                    // Info item
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.blue)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("Dragging to a different disk will still copy normally")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                }
                .background(AdaptiveColors.overlayAuto(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.05), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons (secondary left, Spacer, primary right)
            HStack(spacing: 8) {
                // Disable Anyway (secondary - left)
                Button {
                    alwaysCopyOnDrag = false  // Actually disable protection
                    dismiss()
                } label: {
                    Text("Disable Anyway")
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                .scaleEffect(isHoveringCancel ? 1.05 : 1.0)
                .onHover { isHoveringCancel = $0 }
                .animation(DroppyAnimation.hover, value: isHoveringCancel)
                
                Spacer()
                
                // Keep Protection (primary - right)
                Button {
                    alwaysCopyOnDrag = true
                    dismiss()
                } label: {
                    Text("Keep Protection")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                .scaleEffect(isHoveringConfirm ? 1.05 : 1.0)
                .onHover { isHoveringConfirm = $0 }
                .animation(DroppyAnimation.hover, value: isHoveringConfirm)
            }
            .padding(DroppySpacing.lg)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
    }
}

// MARK: - Stabilize Media Info Sheet

/// Info sheet shown when user enables Stabilize Media (advanced feature)
struct StabilizeMediaInfoSheet: View {
    @Binding var debounceMediaChanges: Bool
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringDisable = false
    @State private var isHoveringKeep = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with NotchFace
            VStack(spacing: 16) {
                NotchFace(size: 60, isExcited: true)
                
                Text("Stabilize Media Enabled")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Content
            VStack(alignment: .center, spacing: 16) {
                Text("What this does:")
                    .font(.callout.weight(.medium))
                
                // Card with explanation items
                VStack(spacing: 0) {
                    // Info item 1
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "clock")
                            .foregroundStyle(.blue)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("Adds a short delay before showing media changes")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(AdaptiveColors.overlayAuto(0.04)).frame(height: 0.5)
                    }
                    
                    // Info item 2
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("Prevents UI flickering when apps rapidly update metadata")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(AdaptiveColors.overlayAuto(0.04)).frame(height: 0.5)
                    }
                    
                    // Info item 3
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("May slightly delay initial song/album art display")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                }
                .background(AdaptiveColors.overlayAuto(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.05), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons (secondary left, Spacer, primary right)
            HStack(spacing: 8) {
                // Disable (secondary - left)
                Button {
                    debounceMediaChanges = false
                    dismiss()
                } label: {
                    Text("Disable")
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                Spacer()
                
                // Keep Enabled (primary - right)
                Button {
                    dismiss()
                } label: {
                    Text("Got It")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
            }
            .padding(DroppySpacing.lg)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
    }
}

// MARK: - Auto-Focus Search Info Sheet

/// Info sheet shown when user enables Auto-Focus Search (advanced feature)
struct AutoFocusSearchInfoSheet: View {
    @Binding var autoFocusSearch: Bool
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringDisable = false
    @State private var isHoveringKeep = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with NotchFace
            VStack(spacing: 16) {
                NotchFace(size: 60, isExcited: true)
                
                Text("Auto-Focus Search Enabled")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Content
            VStack(alignment: .center, spacing: 16) {
                Text("What this does:")
                    .font(.callout.weight(.medium))
                
                // Card with explanation items
                VStack(spacing: 0) {
                    // Info item 1
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.blue)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("Automatically focuses the search bar when clipboard opens")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(AdaptiveColors.overlayAuto(0.04)).frame(height: 0.5)
                    }
                    
                    // Info item 2
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "keyboard")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("Start typing immediately to filter clipboard history")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(AdaptiveColors.overlayAuto(0.04)).frame(height: 0.5)
                    }
                    
                    // Info item 3
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("Arrow keys won't navigate list until you press Escape")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                }
                .background(AdaptiveColors.overlayAuto(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.05), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons (secondary left, Spacer, primary right)
            HStack(spacing: 8) {
                // Disable (secondary - left)
                Button {
                    autoFocusSearch = false
                    dismiss()
                } label: {
                    Text("Disable")
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                Spacer()
                
                // Keep Enabled (primary - right)
                Button {
                    dismiss()
                } label: {
                    Text("Got It")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
            }
            .padding(DroppySpacing.lg)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
    }
}

// MARK: - Full Disk Access Sheet

/// Styled sheet for Full Disk Access permission request
struct FullDiskAccessSheet: View {
    @Binding var enableDNDHUD: Bool
    @Binding var isPresented: Bool
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var isHoveringOpen = false
    @State private var isHoveringGranted = false
    @State private var isHoveringCancel = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with NotchFace
            VStack(spacing: 16) {
                NotchFace(size: 60, isExcited: false)
                
                Text("Full Disk Access Required")
                    .font(.title2.bold())
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Content
            VStack(alignment: .center, spacing: 16) {
                Text("To detect Focus mode changes:")
                    .font(.callout.weight(.medium))
                
                // Steps card
                VStack(spacing: 0) {
                    stepRow(number: "1", text: "Click \"Open Settings\"", isFirst: true)
                    stepRow(number: "2", text: "Enable Droppy in the list")
                    stepRow(number: "3", text: "Click \"I've Granted Access\"", isLast: true)
                }
                .background(AdaptiveColors.overlayAuto(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.05), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons
            HStack(spacing: 8) {
                // Cancel (secondary - left)
                Button {
                    enableDNDHUD = false
                    isPresented = false
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                Spacer()
                
                // I've Granted Access
                Button {
                    DNDManager.shared.recheckAccess()
                    isPresented = false
                } label: {
                    Text("I've Granted Access")
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                // Open Settings (primary - right)
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
            }
            .padding(DroppySpacing.lg)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
    }
    
    private func stepRow(number: String, text: String, isFirst: Bool = false, isLast: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
                .frame(width: 22, height: 22)
                .background(Color.blue.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.sm, style: .continuous))
            
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AdaptiveColors.overlayAuto(0.02))
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(AdaptiveColors.overlayAuto(0.04)).frame(height: 0.5)
            }
        }
    }
}

// MARK: - Menu Bar Hidden Sheet

/// Styled sheet for Menu Bar Icon hidden warning
struct MenuBarHiddenSheet: View {
    @Binding var isPresented: Bool
    var onConfirm: () -> Void
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var isHoveringHide = false
    @State private var isHoveringCancel = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with NotchFace
            VStack(spacing: 16) {
                NotchFace(size: 60, isExcited: false)
                
                Text("Hide Menu Bar Icon?")
                    .font(.title2.bold())
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Content
            VStack(alignment: .center, spacing: 16) {
                // Info card
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("Right-click the Notch or Island to access Settings anytime")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                }
                .background(AdaptiveColors.overlayAuto(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.05), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons
            HStack(spacing: 8) {
                // Cancel (secondary - left)
                Button {
                    isPresented = false
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                Spacer()
                
                // Hide Icon (primary - right)
                Button {
                    isPresented = false
                    // Use DispatchQueue to ensure sheet dismissal completes before action
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onConfirm()
                    }
                } label: {
                    Text("Hide Icon")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
            }
            .padding(DroppySpacing.lg)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
    }
}

// MARK: - Power Folders Info Button
struct PowerFoldersInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill.badge.plus")
                            .font(.system(size: 24))
                            .foregroundStyle(.yellow)
                        Text("Power Folders")
                            .font(.headline)
                    }
                    
                    Text("Drop folders onto Droppy to pin them. Pinned folders stay accessible and you can drop files directly into them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Pin folders to keep them accessible", systemImage: "pin.fill")
                        Label("Drop files directly into pinned folders", systemImage: "arrow.right.doc.on.clipboard")
                        Label("Hover to preview folder contents", systemImage: "eye")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 320)
            }
    }
}

// MARK: - Clipboard Shortcut Info Button

/// Info button showing the clipboard keyboard shortcut
struct ClipboardShortcutInfoButton: View {
    var shortcut: SavedShortcut?
    @State private var showPopover = false
    
    /// Parse shortcut into display string
    private var shortcutString: String {
        guard let s = shortcut else { return "⇧⌘Space" }
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: s.modifiers)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(KeyCodeHelper.string(for: UInt16(s.keyCode)))
        return parts.joined()
    }
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.cyan)
                        Text("Clipboard Tips")
                            .font(.headline)
                    }
                    
                    Text("Press \(shortcutString) to quickly access your clipboard history.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Shortcut opens clipboard panel", systemImage: "keyboard")
                        Label("Click to paste any item", systemImage: "doc.on.doc")
                        Label("Double-tap text to rename & save", systemImage: "pencil")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

/// Styled keycap view for keyboard shortcut display
struct KeyCapView: View {
    let key: String
    var color: Color = .white
    var isWide: Bool = false
    
    var body: some View {
        Text(key)
            .font(.system(size: isWide ? 11 : 14, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, isWide ? 12 : 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DroppyRadius.sm, style: .continuous)
                    .fill(LinearGradient(colors: [color.opacity(0.2), color.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.sm, style: .continuous)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: color.opacity(0.15), radius: 4, y: 2)
    }
}

// MARK: - External Display Info Button

/// Info button explaining external display behavior
struct ExternalDisplayInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "display")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)
                        Text("External Display")
                            .font(.headline)
                    }
                    
                    Text("Configure how Droppy appears on external monitors that don't have a notch.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Choose Notch or Island style", systemImage: "rectangle.topthird.inset.filled")
                        Label("Or hide Droppy on external displays", systemImage: "eye.slash")
                        Label("Works independently for each display", systemImage: "display.2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

// MARK: - Quick Actions Info Button

struct QuickActionsInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue)
                        Text("Quick Actions")
                            .font(.headline)
                    }
                    
                    Text("Adds quick action drop targets under Shelf and Basket for fast sharing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Drag files onto AirDrop, Messages, Mail, or Quickshare (Droppy Quickshare)", systemImage: "bolt.fill")
                        Label("Choose your preferred app for the Mail quick action", systemImage: "envelope.badge")
                        Label("Also enables Select All and Add All tools in Basket", systemImage: "doc.on.doc")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

// MARK: - Quick Actions Info Sheet

/// Info sheet shown when user enables Quick Actions (advanced feature)
struct QuickActionsInfoSheet: View {
    @Binding var enableQuickActions: Bool
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringDisable = false
    @State private var isHoveringKeep = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with NotchFace
            VStack(spacing: 16) {
                NotchFace(size: 60, isExcited: true)
                
                Text("Quick Actions Enabled")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Content
            VStack(alignment: .center, spacing: 16) {
                Text("What this does:")
                    .font(.callout.weight(.medium))
                
                // Card with explanation items
                VStack(spacing: 0) {
                    // Info item 1 - Quick action drop targets
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("Shows quick action drop targets under Shelf and Basket (AirDrop, Messages, Mail, Quickshare via Droppy Quickshare)")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(AdaptiveColors.overlayAuto(0.04)).frame(height: 0.5)
                    }
                    
                    // Info item 2 - Mail app routing
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "envelope.badge")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("The Mail quick action uses the app selected in \"Mail App\" settings")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(AdaptiveColors.overlayAuto(0.04)).frame(height: 0.5)
                    }
                    
                    // Info item 3 - Basket tools
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("Also enables Select All and Add All tools in Basket for faster batch operations")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AdaptiveColors.overlayAuto(0.02))
                }
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
                )
            }
            .padding(DroppySpacing.xxl)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Footer with buttons
            HStack {
                // Disable (secondary - left)
                Button {
                    enableQuickActions = false
                    dismiss()
                } label: {
                    Text("Disable")
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                Spacer()
                
                // Keep Enabled (primary - right)
                Button {
                    dismiss()
                } label: {
                    Text("Got It")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
            }
            .padding(DroppySpacing.lg)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
    }
}

// MARK: - Tracked Folders Settings

/// Info button for Tracked Folders feature
struct TrackedFoldersInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .leading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue)
                        Text("Tracked Folders")
                            .font(.headline)
                    }
                    
                    Text("Monitor folders for new files and automatically add them to Droppy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Watch Downloads, Desktop, or any folder", systemImage: "folder")
                        Label("New files trigger shelf or basket automatically", systemImage: "arrow.forward.circle")
                        Label("Choose destination per folder", systemImage: "tray.2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

/// Settings row for Tracked Folders feature
struct TrackedFoldersSettingsRow: View {
    @AppStorage(AppPreferenceKey.enableTrackedFolders) private var enableTrackedFolders = PreferenceDefault.enableTrackedFolders
    @StateObject private var manager = TrackedFoldersManager.shared
    @State private var showFolderPicker = false
    @State private var newFolderDestination: TrackedFolderDestination = .basket
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main toggle
            HStack(spacing: 8) {
                TrackedFoldersInfoButton()
                Toggle(isOn: $enableTrackedFolders) {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 6) {
                            Text("Tracked Folders")
                            Text("advanced")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AdaptiveColors.overlayAuto(0.08)))
                                .overlay(Capsule().stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1))
                        }
                        Text("Watch folders and auto-add new files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: enableTrackedFolders) { _, newValue in
                if newValue {
                    manager.startMonitoring()
                } else {
                    manager.stopMonitoring()
                }
            }
            
            // Folder list (when enabled)
            if enableTrackedFolders {
                VStack(alignment: .leading, spacing: 8) {
                    // Watched folders list
                    ForEach(manager.watchedFolders) { folder in
                        WatchedFolderRow(folder: folder, manager: manager)
                    }
                    
                    // Add folder button
                    HStack(spacing: 8) {
                        Button {
                            showFolderPicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Folder")
                            }
                        }
                        .buttonStyle(DroppyPillButtonStyle(size: .small))
                        
                        Spacer()
                        
                        // Destination picker for new folder
                        Picker("Add to", selection: $newFolderDestination) {
                            ForEach(TrackedFolderDestination.allCases, id: \.self) { dest in
                                Label(dest.displayName, systemImage: dest.icon)
                                    .tag(dest)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    .padding(.top, 4)
                }
                .padding(.leading, 28)
            }
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                manager.addFolder(url, destination: newFolderDestination)
            }
        }
    }
}

/// Row for a single watched folder
struct WatchedFolderRow: View {
    let folder: WatchedFolder
    let manager: TrackedFoldersManager
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Folder icon
            Image(systemName: "folder.fill")
                .font(.system(size: 16))
                .foregroundStyle(.blue.opacity(0.8))
            
            // Folder name and path
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(folder.displayPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // Destination picker
            Picker("", selection: Binding(
                get: { folder.destination },
                set: { manager.updateDestination(for: folder.id, to: $0) }
            )) {
                ForEach(TrackedFolderDestination.allCases, id: \.self) { dest in
                    Label(dest.displayName, systemImage: dest.icon)
                        .tag(dest)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            
            // Remove button
            Button {
                manager.removeFolder(folder.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isHovering ? .red : .secondary.opacity(0.6))
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 16))
            .onHover { isHovering = $0 }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AdaptiveColors.overlayAuto(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
    }
}

// MARK: - Media Source Filter Settings Row

/// Settings row for Media Source Filter (inline list like Tracked Folders)
struct MediaSourceFilterSettingsRow: View {
    @Binding var allowedBundles: String
    @Binding var filterEnabled: Bool
    @State private var showAppPicker = false
    
    /// Parsed list of allowed apps (name and bundleId)
    private var allowedApps: [(name: String, bundleId: String)] {
        guard let data = allowedBundles.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return []
        }
        return dict.map { (name: $0.value, bundleId: $0.key) }.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main toggle
            Toggle(isOn: $filterEnabled) {
                VStack(alignment: .leading) {
                    HStack(alignment: .center, spacing: 6) {
                        Text("Filter Media Sources")
                        Text("advanced")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AdaptiveColors.overlayAuto(0.08)))
                            .overlay(Capsule().stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1))
                    }
                    Text("Only show selected apps in media player")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // App list (when enabled)
            if filterEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    // Allowed apps list
                    ForEach(allowedApps, id: \.bundleId) { app in
                        MediaSourceAppRow(
                            name: app.name,
                            bundleId: app.bundleId,
                            onRemove: { removeApp(app.bundleId) }
                        )
                    }
                    
                    // Add app button
                    Button {
                        showAppPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add App")
                        }
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))
                    .padding(.top, 4)
                }
                .padding(.leading, 28)
            }
        }
        .fileImporter(
            isPresented: $showAppPicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: true,
            onCompletion: { result in
                if case .success(let urls) = result {
                    for url in urls {
                        addAppFromURL(url)
                    }
                }
            }
        )
    }
    
    /// Add an app from its URL
    private func addAppFromURL(_ url: URL) {
        guard url.pathExtension == "app" else { return }
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else { return }
        
        let appName = url.deletingPathExtension().lastPathComponent
        
        var dict: [String: String] = [:]
        if let data = allowedBundles.data(using: .utf8),
           let existing = try? JSONDecoder().decode([String: String].self, from: data) {
            dict = existing
        }
        
        dict[bundleId] = appName
        
        if let data = try? JSONEncoder().encode(dict),
           let json = String(data: data, encoding: .utf8) {
            allowedBundles = json
        }
    }
    
    /// Remove an app from the list
    private func removeApp(_ bundleId: String) {
        var dict: [String: String] = [:]
        if let data = allowedBundles.data(using: .utf8),
           let existing = try? JSONDecoder().decode([String: String].self, from: data) {
            dict = existing
        }
        
        dict.removeValue(forKey: bundleId)
        
        if let data = try? JSONEncoder().encode(dict),
           let json = String(data: data, encoding: .utf8) {
            allowedBundles = json
        }
    }
}

/// Row for a single allowed media source app
private struct MediaSourceAppRow: View {
    let name: String
    let bundleId: String
    let onRemove: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            // App icon
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                Image(nsImage: ThumbnailCache.shared.cachedIcon(forPath: appURL.path))
                    .resizable()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            
            // App name and bundle ID
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(bundleId)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isHovering ? .red : .secondary.opacity(0.6))
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 16))
            .onHover { isHovering = $0 }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AdaptiveColors.overlayAuto(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
    }
}

// MARK: - Advanced Autofade Settings (Issue #79)

/// Info button for Advanced Autofade feature
struct AdvancedAutofadeInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .onTapGesture { showPopover.toggle() }
            .onHover { hovering in
                showPopover = hovering
            }
            .popover(isPresented: $showPopover, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Advanced Auto-Fade")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Configure when the media HUD auto-fades", systemImage: "clock")
                        Label("Set different delays per app", systemImage: "app.badge")
                        Label("Enable/disable per display", systemImage: "display.2")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .droppyTooltipPopoverStyle(width: 280)
            }
    }
}

/// Main settings row for Advanced Autofade
struct AdvancedAutofadeSettingsRow: View {
    @AppStorage(AppPreferenceKey.autoFadeMediaHUD) private var autoFadeEnabled = PreferenceDefault.autoFadeMediaHUD
    @AppStorage(AppPreferenceKey.autofadeDefaultDelay) private var defaultDelay = PreferenceDefault.autofadeDefaultDelay
    @AppStorage(AppPreferenceKey.autofadeAppRulesEnabled) private var appRulesEnabled = PreferenceDefault.autofadeAppRulesEnabled
    @AppStorage(AppPreferenceKey.autofadeDisplayRulesEnabled) private var displayRulesEnabled = PreferenceDefault.autofadeDisplayRulesEnabled
    @StateObject private var manager = AutofadeManager.shared
    @State private var showAppPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main toggle with info button
            HStack(spacing: 8) {
                AdvancedAutofadeInfoButton()
                Toggle(isOn: $autoFadeEnabled) {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 6) {
                            Text("Auto-Hide Preview")
                            Text("advanced")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AdaptiveColors.overlayAuto(0.08)))
                                .overlay(Capsule().stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 1))
                        }
                        Text("Fade out mini player after delay")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Sub-options (when enabled)
            if autoFadeEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    // Default delay slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Default Delay")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(defaultDelay))s")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $defaultDelay, in: 1...30, step: 1)
                            .tint(.droppyAccent)
                            .sliderHaptics(value: defaultDelay, range: 1...30)
                    }
                    
                    Divider()
                        .opacity(0.3)
                    
                    // App-specific rules section
                    Toggle(isOn: $appRulesEnabled) {
                        VStack(alignment: .leading) {
                            Text("App-Specific Rules")
                                .font(.subheadline)
                            Text("Different delays per app")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if appRulesEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            // App rules list
                            ForEach(manager.appRules) { rule in
                                AutofadeAppRuleRow(rule: rule)
                            }
                            
                            // Add app button
                            Button {
                                showAppPicker = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add App")
                                }
                            }
                            .buttonStyle(DroppyPillButtonStyle(size: .small))
                        }
                        .padding(.leading, 20)
                    }
                    
                    // Display-specific section (only show if multiple displays)
                    if NSScreen.screens.count > 1 {
                        Divider()
                            .opacity(0.3)
                        
                        Toggle(isOn: $displayRulesEnabled) {
                            VStack(alignment: .leading) {
                                Text("Display-Specific Rules")
                                    .font(.subheadline)
                                Text("Enable/disable per display")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if displayRulesEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(NSScreen.screens, id: \.displayID) { screen in
                                    AutofadeDisplayRow(screen: screen)
                                }
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
                .padding(.leading, 28)
            }
        }
        .sheet(isPresented: $showAppPicker) {
            AutofadeAppPicker(isPresented: $showAppPicker)
        }
    }
}

/// Row for a single app-specific autofade rule
struct AutofadeAppRuleRow: View {
    let rule: AutofadeAppRule
    @StateObject private var manager = AutofadeManager.shared
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            // App icon
            if let iconPath = rule.appIconPath {
                let icon = ThumbnailCache.shared.cachedIcon(forPath: iconPath)
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            
            // App name
            Text(rule.appName)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
            
            // Delay picker
            Picker("", selection: Binding(
                get: { rule.fadeDelay },
                set: { manager.updateAppRule(id: rule.id, delay: $0) }
            )) {
                ForEach(AutofadeDelay.standardCases, id: \.self) { delay in
                    Text(delay.displayName).tag(delay)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            
            // Remove button
            Button {
                manager.removeAppRule(id: rule.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isHovering ? .red : .secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AdaptiveColors.overlayAuto(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
    }
}

/// Row for display-specific autofade toggle
struct AutofadeDisplayRow: View {
    let screen: NSScreen
    @StateObject private var manager = AutofadeManager.shared
    
    private var displayName: String {
        screen.localizedName
    }
    
    private var isEnabled: Bool {
        manager.isDisplayEnabled(screen.displayID)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Display icon
            Image(systemName: screen.isBuiltIn ? "laptopcomputer" : "display")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            // Display name
            Text(displayName)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
            
            // Enable/disable toggle
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { manager.setDisplayEnabled(screen.displayID, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AdaptiveColors.overlayAuto(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
    }
}

struct ExternalDisplayVisibilityRow: View {
    let screen: NSScreen
    @Binding var isVisible: Bool

    private var displayName: String {
        screen.localizedName
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "display")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(isVisible ? "Visible" : "Hidden")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isVisible)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AdaptiveColors.overlayAuto(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
    }
}

/// App picker sheet for adding autofade rules
struct AutofadeAppPicker: View {
    @Binding var isPresented: Bool
    @StateObject private var manager = AutofadeManager.shared
    @State private var searchText = ""
    @State private var selectedDelay: AutofadeDelay = .never
    
    private var filteredApps: [(bundleID: String, name: String, icon: NSImage?)] {
        let apps = manager.runningApps()
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add App Rule")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .padding()
            
            Divider()
            
            // Delay picker
            HStack {
                Text("Auto-fade delay:")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $selectedDelay) {
                    ForEach(AutofadeDelay.standardCases, id: \.self) { delay in
                        Text(delay.displayName).tag(delay)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Search field
            TextField("Search apps…", text: $searchText)
                .textFieldStyle(.plain)
                .droppyTextInputChrome()
                .padding()
            
            // App list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredApps, id: \.bundleID) { app in
                        AppPickerRow(
                            name: app.name,
                            icon: app.icon,
                            isAlreadyAdded: manager.appRules.contains { $0.bundleIdentifier == app.bundleID }
                        ) {
                            manager.addAppRule(bundleID: app.bundleID, appName: app.name, delay: selectedDelay)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 400, height: 500)
    }
}

/// Row in the app picker
struct AppPickerRow: View {
    let name: String
    let icon: NSImage?
    let isAlreadyAdded: Bool
    let onAdd: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            
            // App name
            Text(name)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
            
            // Add button or checkmark
            if isAlreadyAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Add") {
                    onAdd()
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                .opacity(isHovering ? 1 : 0.7)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isHovering ? AdaptiveColors.overlayAuto(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
        .onHover { isHovering = $0 }
    }
}
