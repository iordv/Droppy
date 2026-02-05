import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @AppStorage(AppPreferenceKey.showInMenuBar) private var showInMenuBar = PreferenceDefault.showInMenuBar
    @AppStorage(AppPreferenceKey.showQuickshareInMenuBar) private var showQuickshareInMenuBar = PreferenceDefault.showQuickshareInMenuBar
    @AppStorage(AppPreferenceKey.startAtLogin) private var startAtLogin = PreferenceDefault.startAtLogin
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.enableNotchShelf) private var enableNotchShelf = PreferenceDefault.enableNotchShelf
    @AppStorage(AppPreferenceKey.enableFloatingBasket) private var enableFloatingBasket = PreferenceDefault.enableFloatingBasket
    @AppStorage(AppPreferenceKey.enableBasketAutoHide) private var enableBasketAutoHide = PreferenceDefault.enableBasketAutoHide
    @AppStorage(AppPreferenceKey.enableAutoClean) private var enableAutoClean = PreferenceDefault.enableAutoClean
    @AppStorage(AppPreferenceKey.alwaysCopyOnDrag) private var alwaysCopyOnDrag = PreferenceDefault.alwaysCopyOnDrag
    @AppStorage(AppPreferenceKey.enableAirDropZone) private var enableAirDropZone = PreferenceDefault.enableAirDropZone
    @AppStorage(AppPreferenceKey.enablePowerFolders) private var enablePowerFolders = PreferenceDefault.enablePowerFolders
    @AppStorage(AppPreferenceKey.enableQuickActions) private var enableQuickActions = PreferenceDefault.enableQuickActions
    @AppStorage(AppPreferenceKey.basketAutoHideEdge) private var basketAutoHideEdge = PreferenceDefault.basketAutoHideEdge
    @AppStorage(AppPreferenceKey.instantBasketOnDrag) private var instantBasketOnDrag = PreferenceDefault.instantBasketOnDrag
    @AppStorage(AppPreferenceKey.instantBasketDelay) private var instantBasketDelay = PreferenceDefault.instantBasketDelay
    @AppStorage(AppPreferenceKey.showClipboardButton) private var showClipboardButton = PreferenceDefault.showClipboardButton
    @AppStorage(AppPreferenceKey.showOpenShelfIndicator) private var showOpenShelfIndicator = PreferenceDefault.showOpenShelfIndicator
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
    @AppStorage(AppPreferenceKey.dynamicIslandHeightOffset) private var dynamicIslandHeightOffset = PreferenceDefault.dynamicIslandHeightOffset
    
    // HUD and Media Player settings
    @AppStorage(AppPreferenceKey.enableHUDReplacement) private var enableHUDReplacement = PreferenceDefault.enableHUDReplacement
    @AppStorage(AppPreferenceKey.enableBatteryHUD) private var enableBatteryHUD = PreferenceDefault.enableBatteryHUD
    @AppStorage(AppPreferenceKey.enableCapsLockHUD) private var enableCapsLockHUD = PreferenceDefault.enableCapsLockHUD
    @AppStorage(AppPreferenceKey.enableAirPodsHUD) private var enableAirPodsHUD = PreferenceDefault.enableAirPodsHUD
    @AppStorage(AppPreferenceKey.enableLockScreenHUD) private var enableLockScreenHUD = PreferenceDefault.enableLockScreenHUD
    @AppStorage(AppPreferenceKey.enableDNDHUD) private var enableDNDHUD = PreferenceDefault.enableDNDHUD
    @AppStorage(AppPreferenceKey.enableUpdateHUD) private var enableUpdateHUD = PreferenceDefault.enableUpdateHUD
    @AppStorage(AppPreferenceKey.notificationHUDInstalled) private var isNotificationHUDInstalled = PreferenceDefault.notificationHUDInstalled
    @AppStorage(AppPreferenceKey.notificationHUDEnabled) private var enableNotificationHUD = PreferenceDefault.notificationHUDEnabled
    @AppStorage(AppPreferenceKey.terminalNotchInstalled) private var isTerminalNotchInstalled = PreferenceDefault.terminalNotchInstalled
    @AppStorage(AppPreferenceKey.terminalNotchEnabled) private var enableTerminalNotch = PreferenceDefault.terminalNotchEnabled
    @AppStorage(AppPreferenceKey.caffeineInstalled) private var isCaffeineInstalled = PreferenceDefault.caffeineInstalled
    @AppStorage(AppPreferenceKey.caffeineEnabled) private var enableCaffeine = PreferenceDefault.caffeineEnabled
    @AppStorage(AppPreferenceKey.enableLockScreenMediaWidget) private var enableLockScreenMediaWidget = PreferenceDefault.enableLockScreenMediaWidget
    @AppStorage(AppPreferenceKey.showMediaPlayer) private var showMediaPlayer = PreferenceDefault.showMediaPlayer
    @AppStorage(AppPreferenceKey.autoFadeMediaHUD) private var autoFadeMediaHUD = PreferenceDefault.autoFadeMediaHUD
    @AppStorage(AppPreferenceKey.debounceMediaChanges) private var debounceMediaChanges = PreferenceDefault.debounceMediaChanges
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
    @AppStorage(AppPreferenceKey.autoExpandDelay) private var autoExpandDelay = PreferenceDefault.autoExpandDelay
    @AppStorage(AppPreferenceKey.autoOpenMediaHUDOnShelfExpand) private var autoOpenMediaHUDOnShelfExpand = PreferenceDefault.autoOpenMediaHUDOnShelfExpand
    @AppStorage(AppPreferenceKey.autoHideOnFullscreen) private var autoHideOnFullscreen = PreferenceDefault.autoHideOnFullscreen
    @AppStorage(AppPreferenceKey.hideMediaOnlyOnFullscreen) private var hideMediaOnlyOnFullscreen = PreferenceDefault.hideMediaOnlyOnFullscreen
    @AppStorage(AppPreferenceKey.enableFinderServices) private var enableFinderServices = PreferenceDefault.enableFinderServices


    
    @State private var dashPhase: CGFloat = 0
    @State private var isHistoryLimitEditing: Bool = false
    @State private var isUpdateHovering = false
    @State private var showDNDAccessAlert = false  // Full Disk Access alert for Focus Mode HUD
    @State private var showMenuBarHiddenWarning = false  // Warning when hiding menu bar icon (Issue #57)
    @State private var showProtectOriginalsWarning = false  // Warning when disabling Protect Originals
    @State private var showStabilizeMediaWarning = false  // Warning when enabling Stabilize Media
    @State private var showAutoFocusSearchWarning = false  // Warning when enabling Auto-Focus Search
    @State private var showQuickActionsWarning = false  // Warning when enabling Quick Actions
    
    // Hover states for special buttons
    @State private var isCoffeeHovering = false
    @State private var isIntroHovering = false
    @State private var isHardResetHovering = false
    @State private var showHardResetConfirmation = false
    @State private var hardResetIncludeClipboard = false
    @State private var scrollOffset: CGFloat = 0
    
    // Hover states for Shared Features grid toggles
    @State private var isAutoRemoveHovering = false
    @State private var isPowerFoldersHovering = false
    @State private var isProtectionHovering = false
    
    /// Extension to open from deep link (e.g., droppy://extension/ai-bg)
    @State private var deepLinkedExtension: ExtensionType?
    
    /// Detects if the BUILT-IN display has a physical notch
    /// Uses builtInWithNotch or isBuiltIn check - NOT main screen (which could be external)
    private var hasPhysicalNotch: Bool {
        // Check if there's a built-in display with a notch
        if let builtIn = NSScreen.builtInWithNotch {
            return builtIn.safeAreaInsets.top > 0
        }
        // Fallback: check all screens for a built-in one with a notch
        for screen in NSScreen.screens {
            if screen.isBuiltIn && screen.safeAreaInsets.top > 0 {
                return true
            }
        }
        return false
    }

    var body: some View {
        ZStack {
            NavigationSplitView {
                SettingsSidebar(selectedTab: $selectedTab)
                    .background(Color.clear)
            } detail: {
                ZStack(alignment: .top) {
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
                        case .lockScreen:
                            lockScreenSettings
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
                    .toggleStyle(CenteredSwitchToggleStyle())  // Center all toggles vertically
                    // In transparent mode, keep some section visibility; in dark mode, hide default background
                    .scrollContentBackground(useTransparentBackground ? .visible : .hidden)
                    .background(Color.clear)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: geo.frame(in: .named("settingsScroll")).minY
                                )
                        }
                    )
                    .coordinateSpace(name: "settingsScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                    }
                    
                    // Beautiful gradient fade - only shows when scrolling
                    VStack(spacing: 0) {
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(useTransparentBackground ? 0 : 1), location: 0),
                                .init(color: Color.black.opacity(useTransparentBackground ? 0 : 0.95), location: 0.3),
                                .init(color: Color.black.opacity(useTransparentBackground ? 0 : 0.7), location: 0.6),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                        .allowsHitTesting(false)
                        
                        Spacer()
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .opacity(scrollOffset < -10 ? 1 : 0)
                    .animation(DroppyAnimation.hoverQuick, value: scrollOffset < -10)
                }
            }
        }
        .onTapGesture {
            isHistoryLimitEditing = false
        }
        // Apply blue accent color for toggles
        .tint(.droppyAccent)
        // Apply transparent material or solid black
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        // CRITICAL: Always use dark color scheme to ensure text is readable
        // In both solid black and transparent material modes, we need light text
        .preferredColorScheme(.dark)
        // Force complete view rebuild when transparency mode changes
        // This fixes the issue where background doesn't update immediately
        .id(useTransparentBackground)
        // Handle deep links to open specific extensions
        .onAppear {
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
            // MARK: Startup
            Section {
                HStack(alignment: .top, spacing: 8) {
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
                            .foregroundStyle(showInMenuBar ? Color.blue : Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .sheet(isPresented: $showMenuBarHiddenWarning) {
                        MenuBarHiddenSheet(
                            isPresented: $showMenuBarHiddenWarning,
                            onConfirm: {
                                showInMenuBar = false
                            }
                        )
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
                            .foregroundStyle(startAtLogin ? Color.blue : Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
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
                                    .fill(!useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
                                    .frame(width: 50, height: 16)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: useDynamicIslandStyle,
                                action: { useDynamicIslandStyle = true }
                            ) {
                                Capsule()
                                    .fill(useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
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
                                    .fill(!externalDisplayUseDynamicIsland ? Color.blue : Color.white.opacity(0.5))
                                    .frame(width: 44, height: 14)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: externalDisplayUseDynamicIsland,
                                action: { externalDisplayUseDynamicIsland = true }
                            ) {
                                Capsule()
                                    .fill(externalDisplayUseDynamicIsland ? Color.blue : Color.white.opacity(0.5))
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
                }
            } header: {
                Text("External Displays")
            }
            
            // MARK: Shared Features
            Section {
                // 3-Grid Feature Toggles
                HStack(alignment: .top, spacing: 8) {
                    // Auto-Remove
                    VStack(spacing: 6) {
                        Button {
                            withAnimation(DroppyAnimation.bounce) {
                                enableAutoClean.toggle()
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                                    .fill(Color.black.opacity(0.35))
                                Image(systemName: "trash")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(enableAutoClean ? Color.blue : Color.white.opacity(0.5))
                            }
                            .frame(height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                                    .stroke(enableAutoClean ? Color.blue.opacity(0.6) : Color.white.opacity(0.05), lineWidth: enableAutoClean ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(isAutoRemoveHovering ? 1.02 : 1.0)
                        .onHover { isAutoRemoveHovering = $0 }
                        .animation(.easeOut(duration: 0.15), value: isAutoRemoveHovering)
                        
                        HStack(spacing: 4) {
                            AutoCleanInfoButton()
                            Text("Auto-Remove")
                                .font(.system(size: 11, weight: enableAutoClean ? .semibold : .regular))
                                .foregroundStyle(enableAutoClean ? .primary : .secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Power Folders
                    VStack(spacing: 6) {
                        Button {
                            withAnimation(DroppyAnimation.bounce) {
                                enablePowerFolders.toggle()
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                                    .fill(Color.black.opacity(0.35))
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(enablePowerFolders ? Color.blue : Color.white.opacity(0.5))
                            }
                            .frame(height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                                    .stroke(enablePowerFolders ? Color.blue.opacity(0.6) : Color.white.opacity(0.05), lineWidth: enablePowerFolders ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(isPowerFoldersHovering ? 1.02 : 1.0)
                        .onHover { isPowerFoldersHovering = $0 }
                        .animation(.easeOut(duration: 0.15), value: isPowerFoldersHovering)
                        
                        HStack(spacing: 4) {
                            PowerFoldersInfoButton()
                            Text("Power Folders")
                                .font(.system(size: 11, weight: enablePowerFolders ? .semibold : .regular))
                                .foregroundStyle(enablePowerFolders ? .primary : .secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Protect Originals
                    VStack(spacing: 6) {
                        Button {
                            withAnimation(DroppyAnimation.bounce) {
                                if alwaysCopyOnDrag {
                                    showProtectOriginalsWarning = true
                                } else {
                                    alwaysCopyOnDrag = true
                                }
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                                    .fill(Color.black.opacity(0.35))
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(alwaysCopyOnDrag ? Color.blue : Color.white.opacity(0.5))
                            }
                            .frame(height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                                    .stroke(alwaysCopyOnDrag ? Color.blue.opacity(0.6) : Color.white.opacity(0.05), lineWidth: alwaysCopyOnDrag ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(isProtectionHovering ? 1.02 : 1.0)
                        .onHover { isProtectionHovering = $0 }
                        .animation(.easeOut(duration: 0.15), value: isProtectionHovering)
                        .sheet(isPresented: $showProtectOriginalsWarning) {
                            ProtectOriginalsWarningSheet(alwaysCopyOnDrag: $alwaysCopyOnDrag)
                        }
                        
                        HStack(spacing: 4) {
                            AlwaysCopyInfoButton()
                            Text("Protection")
                                .font(.system(size: 11, weight: alwaysCopyOnDrag ? .semibold : .regular))
                                .foregroundStyle(alwaysCopyOnDrag ? .primary : .secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Smart Export & Tracked Folders (keep as custom rows)
                SmartExportSettingsRow()
                TrackedFoldersSettingsRow()
            } header: {
                Text("Shared Features")
            } footer: {
                Text("These features apply to both Notch Shelf and Floating Basket.")
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
                        if !enableHUDReplacement && !showMediaPlayer {
                            NotchWindowController.shared.closeWindow()
                        }
                    }
                }
                
                if enableNotchShelf {
                    NotchShelfPreview()
                }
            } header: {
                Text("Notch Shelf")
            }
            
            // MARK: Shelf Behavior
            if enableNotchShelf {
                Section {
                    // 3-Grid Behavior Options
                    HStack(alignment: .top, spacing: 8) {
                        // Auto-Collapse
                        SettingsSegmentButtonWithContent(
                            label: "Auto-Collapse",
                            isSelected: autoCollapseShelf,
                            action: { autoCollapseShelf.toggle() }
                        ) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(autoCollapseShelf ? Color.blue : Color.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Auto-Expand
                        SettingsSegmentButtonWithContent(
                            label: "Auto-Expand",
                            isSelected: autoExpandShelf,
                            action: { autoExpandShelf.toggle() }
                        ) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(autoExpandShelf ? Color.blue : Color.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Auto-Open Media
                        SettingsSegmentButtonWithContent(
                            label: "Auto-Open Media",
                            isSelected: autoOpenMediaHUDOnShelfExpand,
                            action: { autoOpenMediaHUDOnShelfExpand.toggle() }
                        ) {
                            Image(systemName: "music.note")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(autoOpenMediaHUDOnShelfExpand ? Color.blue : Color.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
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
                        FloatingBasketWindowController.shared.hideBasket()
                    }
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
                } header: {
                    Text("Appearance")
                }
                
                // MARK: Auto-Hide Settings
                Section {
                    HStack(spacing: 8) {
                        PeekModeInfoButton()
                        Toggle(isOn: $enableBasketAutoHide) {
                            VStack(alignment: .leading) {
                                Text("Auto-Hide with Peek")
                                Text("Basket slides to edge when cursor leaves, hover to reveal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if enableBasketAutoHide {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hide Edge")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 8) {
                                SettingsSegmentButton(
                                    icon: "arrow.left.to.line",
                                    label: "Left",
                                    isSelected: basketAutoHideEdge == "left"
                                ) {
                                    basketAutoHideEdge = "left"
                                }
                                
                                SettingsSegmentButton(
                                    icon: "arrow.right.to.line",
                                    label: "Right",
                                    isSelected: basketAutoHideEdge == "right"
                                ) {
                                    basketAutoHideEdge = "right"
                                }
                                
                                SettingsSegmentButton(
                                    icon: "arrow.down.to.line",
                                    label: "Bottom",
                                    isSelected: basketAutoHideEdge == "bottom"
                                ) {
                                    basketAutoHideEdge = "bottom"
                                }
                            }
                        }
                    }
                } header: {
                    Text("Auto-Hide")
                }
            }
        }
    }
    
    // MARK: Lock Screen Tab (Extracted from HUDs)
    private var lockScreenSettings: some View {
        Group {
            // MARK: Lock Screen HUD
            Section {
                HStack(spacing: 12) {
                    LockScreenHUDIcon()
                    
                    Toggle(isOn: $enableLockScreenHUD) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lock and Unlock Animation")
                            Text("Show animation when screen locks and unlocks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableLockScreenHUD) { _, newValue in
                    if newValue {
                        NotchWindowController.shared.setupNotchWindow()
                    } else {
                        if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer && !enableBatteryHUD && !enableCapsLockHUD && !enableAirPodsHUD {
                            NotchWindowController.shared.closeWindow()
                        }
                    }
                }
            } header: {
                Text("Lock and Unlock Animation")
            }
            
            // MARK: Now Playing Widget
            Section {
                HStack(spacing: 12) {
                    NowPlayingIcon()
                    
                    Toggle(isOn: $enableLockScreenMediaWidget) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Now Playing")
                                Text("new")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.droppyAccent))
                            }
                            Text("Show notch & music controls on the lock screen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: enableLockScreenMediaWidget) { _, newValue in
                    if newValue {
                        LockScreenMediaPanelManager.shared.configure(musicManager: MusicManager.shared)
                        NotchWindowController.shared.delegateToLockScreen()
                    }
                }
                

            } header: {
                Text("Now Playing")
            }
        }
    }
    
    // MARK: Accessibility Tab (Extracted from various places)
    private var accessibilitySettings: some View {
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
                
                // Hide Physical Notch - only makes sense in Notch mode, not Dynamic Island
                Toggle(isOn: $hidePhysicalNotch) {
                    VStack(alignment: .leading) {
                        HStack(spacing: 6) {
                            Text("Hide Physical Notch")
                            Text("new")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.droppyAccent))
                        }
                        Text("Draw a black bar to hide the notch, allowing menu bar icons to use that space. Only applies in Notch mode.")
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
                
                // Sub-option: Include external displays
                if hidePhysicalNotch {
                    Toggle(isOn: $hidePhysicalNotchOnExternals) {
                        VStack(alignment: .leading) {
                            Text("Include External Displays")
                            Text("Also draw black bar on external monitors in Notch mode")
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
                Text("Interface")
            }
            
            Section {
                Toggle(isOn: $enableHapticFeedback) {
                    VStack(alignment: .leading) {
                        Text("Haptic Feedback")
                        Text("Play haptic patterns when dropping files or performing actions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Feedback")
            } footer: {
                Text("Haptic feedback requires a Force Touch trackpad.")
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
                        // Only close if HUD replacement and Media Player are ALSO disabled
                        // The notch window is still needed for HUD/Media features
                        if !enableHUDReplacement && !showMediaPlayer {
                            NotchWindowController.shared.closeWindow()
                        }
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
                                    .fill(!externalDisplayUseDynamicIsland ? Color.blue : Color.white.opacity(0.5))
                                    .frame(width: 44, height: 14)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: externalDisplayUseDynamicIsland,
                                action: { externalDisplayUseDynamicIsland = true }
                            ) {
                                Capsule()
                                    .fill(externalDisplayUseDynamicIsland ? Color.blue : Color.white.opacity(0.5))
                                    .frame(width: 44, height: 14)
                            }
                        }
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
                                    .fill(!useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
                                    .frame(width: 50, height: 16)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: useDynamicIslandStyle,
                                action: { useDynamicIslandStyle = true }
                            ) {
                                Capsule()
                                    .fill(useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
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
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
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
                    FloatingBasketWindowController.shared.hideBasket()
                }
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
            } header: {
                Text("Basket Appearance")
            }
            
            // MARK: Auto-Hide Settings
            Section {
                HStack(spacing: 8) {
                    PeekModeInfoButton()
                    Toggle(isOn: $enableBasketAutoHide) {
                        VStack(alignment: .leading) {
                            Text("Auto-Hide with Peek")
                            Text("Basket slides to edge when cursor leaves, hover to reveal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if enableBasketAutoHide {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hide Edge")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            SettingsSegmentButton(
                                icon: "arrow.left.to.line",
                                label: "Left",
                                isSelected: basketAutoHideEdge == "left"
                            ) {
                                basketAutoHideEdge = "left"
                            }
                            
                            SettingsSegmentButton(
                                icon: "arrow.right.to.line",
                                label: "Right",
                                isSelected: basketAutoHideEdge == "right"
                            ) {
                                basketAutoHideEdge = "right"
                            }
                            
                            SettingsSegmentButton(
                                icon: "arrow.down.to.line",
                                label: "Bottom",
                                isSelected: basketAutoHideEdge == "bottom"
                            ) {
                                basketAutoHideEdge = "bottom"
                            }
                        }
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
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.08)))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                            }
                            Text("Select all and drop to Finder folder")
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
                        FloatingBasketWindowController.shared.hideBasket()
                    }
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
                                Text("Auto-Hide with Peek")
                                Text("Basket slides to edge when cursor leaves, hover to reveal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Edge picker (only when auto-hide is enabled)
                    if enableBasketAutoHide {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hide Edge")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 8) {
                                SettingsSegmentButton(
                                    icon: "arrow.left.to.line",
                                    label: "Left",
                                    isSelected: basketAutoHideEdge == "left"
                                ) {
                                    basketAutoHideEdge = "left"
                                }
                                
                                SettingsSegmentButton(
                                    icon: "arrow.right.to.line",
                                    label: "Right",
                                    isSelected: basketAutoHideEdge == "right"
                                ) {
                                    basketAutoHideEdge = "right"
                                }
                                
                                SettingsSegmentButton(
                                    icon: "arrow.down.to.line",
                                    label: "Bottom",
                                    isSelected: basketAutoHideEdge == "bottom"
                                ) {
                                    basketAutoHideEdge = "bottom"
                                }
                            }
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
                                        .foregroundStyle(.white.opacity(0.7))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.white.opacity(0.08)))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                                }
                                Text("Select all and drop to Finder folder")
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
                            if !enableNotchShelf && !enableHUDReplacement {
                                NotchWindowController.shared.closeWindow()
                            }
                        }
                    }
                    
                    if showMediaPlayer {
                        // Advanced Auto-Fade settings (Issue #79)
                        AdvancedAutofadeSettingsRow()
                        
                        // Visualizer Mode - segmented grid with real visualizer previews
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Visualizer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 8) {
                                SettingsSegmentButtonWithContent(
                                    label: "Real Audio",
                                    isSelected: enableRealAudioVisualizer
                                ) {
                                    enableRealAudioVisualizer.toggle()
                                    if enableRealAudioVisualizer {
                                        Task {
                                            await SystemAudioAnalyzer.shared.requestPermission()
                                        }
                                    }
                                } content: {
                                    VisualizerPreviewMono(isSelected: enableRealAudioVisualizer)
                                }
                                
                                SettingsSegmentButtonWithContent(
                                    label: "Gradient",
                                    isSelected: enableGradientVisualizer
                                ) {
                                    enableGradientVisualizer.toggle()
                                } content: {
                                    VisualizerPreviewGradient(isSelected: enableGradientVisualizer)
                                }
                            }
                        }
                        
                        // Fullscreen Behavior - segmented grid
                        VStack(alignment: .leading, spacing: 8) {
                            Text("In Fullscreen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 8) {
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
                        }
                        
                        // Advanced options - standard toggles
                        Toggle(isOn: $debounceMediaChanges) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Stabilize Media")
                                    Text("advanced")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.white.opacity(0.08)))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
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
                        NotchWindowController.shared.setupNotchWindow()
                        MediaKeyInterceptor.shared.start()
                    } else {
                        MediaKeyInterceptor.shared.stop()
                        if !enableNotchShelf && !showMediaPlayer {
                            NotchWindowController.shared.closeWindow()
                        }
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
                        if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer {
                            NotchWindowController.shared.closeWindow()
                        }
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
                        if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer && !enableBatteryHUD {
                            NotchWindowController.shared.closeWindow()
                        }
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
                        if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer && !enableBatteryHUD && !enableCapsLockHUD {
                            NotchWindowController.shared.closeWindow()
                        }
                    }
                }
            } header: {
                Text("System")
            }
            
            // MARK: Extensions (Notify Me, Terminal Notch, Caffeine)
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
                        if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer && !enableBatteryHUD && !enableCapsLockHUD {
                            NotchWindowController.shared.closeWindow()
                        }
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
                        if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer && !enableBatteryHUD && !enableCapsLockHUD && !enableAirPodsHUD && !enableLockScreenHUD {
                            NotchWindowController.shared.closeWindow()
                        }
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
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings")!)
                        case .spotify:
                            SpotifyAuthManager.shared.startAuthentication()
                        case .appleMusic:
                            AppleMusicController.shared.refreshState()
                        case .elementCapture, .aiBackgroundRemoval, .windowSnap, .voiceTranscribe, .ffmpegVideoCompression, .terminalNotch, .quickshare, .notificationHUD, .caffeine, .menuBarManager, .todo:
                            break // No action needed - these have their own configuration UI
                        }
                    }
                }
            }
    }

    
    private var quickshareSettings: some View {
        QuickshareSettingsContent()
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
                                    .fill(!externalDisplayUseDynamicIsland ? Color.blue : Color.white.opacity(0.5))
                                    .frame(width: 44, height: 14)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: externalDisplayUseDynamicIsland,
                                action: { externalDisplayUseDynamicIsland = true }
                            ) {
                                Capsule()
                                    .fill(externalDisplayUseDynamicIsland ? Color.blue : Color.white.opacity(0.5))
                                    .frame(width: 44, height: 14)
                            }
                        }
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
                                    .fill(!useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
                                    .frame(width: 50, height: 16)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: useDynamicIslandStyle,
                                action: { useDynamicIslandStyle = true }
                            ) {
                                Capsule()
                                    .fill(useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
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
                        url: "https://discord.gg/uxqynmJb"
                    )
                    
                    LinkButton(
                        title: "Support",
                        icon: "cup.and.heat.waves.fill",
                        url: "https://buymeacoffee.com/droppy"
                    )
                }
            } header: {
                Text("Links")
            }
            
            // MARK: Support
            Section {
                Text("I'm Jordy, a solo developer building Droppy because I believe essential tools should be free. If you enjoy using it, a coffee would mean the world ❤️")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Link(destination: URL(string: "https://buymeacoffee.com/droppy")!) {
                    HStack {
                        Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Support")
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
        print("[HardReset] Starting complete reset...")
        
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
        
        print("[HardReset] ✅ Reset complete - restarting app...")
        
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
                        PermissionManager.shared.requestAccessibility()
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
            
            if enableClipboard {
                ClipboardPreview()
                
                HStack {
                    Text("Global Shortcut")
                    Spacer()
                    KeyShortcutRecorder(shortcut: Binding(
                        get: { currentShortcut },
                        set: { newVal in
                            currentShortcut = newVal
                            saveShortcut(newVal)
                        }
                    ))
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
                
                // 3-Grid Clipboard Options
                HStack(alignment: .top, spacing: 8) {
                    // Enable Tags
                    SettingsSegmentButtonWithContent(
                        label: "Tags",
                        isSelected: tagsEnabled,
                        action: { tagsEnabled.toggle() }
                    ) {
                        Image(systemName: "tag")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(tagsEnabled ? Color.blue : Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Copy + Favorite
                    SettingsSegmentButtonWithContent(
                        label: "Copy + Favorite",
                        isSelected: copyFavoriteEnabled,
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
                            .foregroundStyle(copyFavoriteEnabled ? Color.blue : Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    
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
                            .foregroundStyle(autoFocusSearch ? Color.blue : Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
                .sheet(isPresented: $showAutoFocusSearchWarning) {
                    AutoFocusSearchInfoSheet(autoFocusSearch: $autoFocusSearch)
                }
                
                // Shortcut row appears when Copy+Favorite is enabled
                if copyFavoriteEnabled {
                    HStack {
                        Text("Shortcut")
                        Spacer()
                        KeyShortcutRecorder(shortcut: Binding(
                            get: { copyFavoriteShortcut },
                            set: { newVal in
                                copyFavoriteShortcut = newVal
                                saveCopyFavoriteShortcut(newVal)
                            }
                        ))
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
                        Image(nsImage: NSWorkspace.shared.icon(forFile: appPath.path))
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
                    Text("Add App...")
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
        .background(.ultraThinMaterial)
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
        textField.textColor = .white
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
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(width: 280)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(width: 280)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(width: 280)
            }
    }
}

// MARK: - Peek Mode Info Button

/// Info button explaining auto-hide with peek behavior
struct PeekModeInfoButton: View {
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
                        Image(systemName: "eye.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.purple)
                        Text("Peek Mode")
                            .font(.headline)
                    }
                    
                    Text("Basket slides to the screen edge when idle and peeks out so you can hover to reveal it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Slides to edge when not in use", systemImage: "arrow.right.to.line")
                        Label("Hover the edge to reveal basket", systemImage: "cursorarrow.rays")
                        Label("Stays visible while you interact", systemImage: "hand.point.up.left")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(width: 280)
            }
    }
}

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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(width: 280)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(width: 280)
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
                .padding()
                .frame(width: 320)
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
                .padding()
                .frame(width: 320)
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
                    .background(Color.white.opacity(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5)
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
                    .background(Color.white.opacity(0.02))
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
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
                .animation(.easeOut(duration: 0.15), value: isHoveringCancel)
                
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
                .animation(.easeOut(duration: 0.15), value: isHoveringConfirm)
            }
            .padding(DroppySpacing.lg)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
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
                    .background(Color.white.opacity(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5)
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
                    .background(Color.white.opacity(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5)
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
                    .background(Color.white.opacity(0.02))
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
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
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
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
                    .background(Color.white.opacity(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5)
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
                    .background(Color.white.opacity(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5)
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
                    .background(Color.white.opacity(0.02))
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
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
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
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
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
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
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
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
        .background(Color.white.opacity(0.02))
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5)
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
                    .background(Color.white.opacity(0.02))
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
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
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
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
                .padding()
                .frame(width: 320)
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
        guard let s = shortcut else { return "⌘⇧Space" }
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: s.modifiers)
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.control) { parts.append("⌃") }
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(width: 280)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(width: 280)
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
                    
                    Text("Adds Select All and Add All buttons for faster batch operations.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Select All selects all items at once", systemImage: "checkmark.circle.fill")
                        Label("Add All copies items to Finder folder", systemImage: "plus.circle.fill")
                        Label("Great for managing many files", systemImage: "doc.on.doc")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(width: 280)
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
                    // Info item 1 - Select All
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("\"Select All\" button selects all files in the basket")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5)
                    }
                    
                    // Info item 2 - Add All
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("When all selected, button becomes \"Add All\" to copy files to the frontmost Finder folder")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.02))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5)
                    }
                    
                    // Info item 3 - Deselect
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text("Click anywhere in the basket to deselect all")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.02))
                }
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
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
                        Label("New files trigger shelf or basket automatically", systemImage: "arrow.right.circle")
                        Label("Choose destination per folder", systemImage: "tray.2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .frame(width: 280)
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
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
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
        .background(Color.white.opacity(0.03))
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
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
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
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
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
        .background(Color.white.opacity(0.03))
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
                .padding()
                .frame(width: 280)
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
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
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
                let icon = NSWorkspace.shared.icon(forFile: iconPath)
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
        .background(Color.white.opacity(0.03))
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
        .background(Color.white.opacity(0.03))
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
            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)
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
        .background(isHovering ? Color.white.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
        .onHover { isHovering = $0 }
    }
}
