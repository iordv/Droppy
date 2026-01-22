import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var selectedTab: String? = "Features"
    @AppStorage(AppPreferenceKey.showInMenuBar) private var showInMenuBar = PreferenceDefault.showInMenuBar
    @AppStorage(AppPreferenceKey.startAtLogin) private var startAtLogin = PreferenceDefault.startAtLogin
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.enableNotchShelf) private var enableNotchShelf = PreferenceDefault.enableNotchShelf
    @AppStorage(AppPreferenceKey.enableFloatingBasket) private var enableFloatingBasket = PreferenceDefault.enableFloatingBasket
    @AppStorage(AppPreferenceKey.enableBasketAutoHide) private var enableBasketAutoHide = PreferenceDefault.enableBasketAutoHide
    @AppStorage(AppPreferenceKey.enableAutoClean) private var enableAutoClean = PreferenceDefault.enableAutoClean
    @AppStorage(AppPreferenceKey.alwaysCopyOnDrag) private var alwaysCopyOnDrag = PreferenceDefault.alwaysCopyOnDrag
    @AppStorage(AppPreferenceKey.enableAirDropZone) private var enableAirDropZone = PreferenceDefault.enableAirDropZone
    @AppStorage(AppPreferenceKey.enableShelfAirDropZone) private var enableShelfAirDropZone = PreferenceDefault.enableShelfAirDropZone
    @AppStorage(AppPreferenceKey.enablePowerFolders) private var enablePowerFolders = PreferenceDefault.enablePowerFolders
    @AppStorage(AppPreferenceKey.enableQuickActions) private var enableQuickActions = PreferenceDefault.enableQuickActions
    @AppStorage(AppPreferenceKey.basketAutoHideEdge) private var basketAutoHideEdge = PreferenceDefault.basketAutoHideEdge
    @AppStorage(AppPreferenceKey.instantBasketOnDrag) private var instantBasketOnDrag = PreferenceDefault.instantBasketOnDrag
    @AppStorage(AppPreferenceKey.instantBasketDelay) private var instantBasketDelay = PreferenceDefault.instantBasketDelay
    @AppStorage(AppPreferenceKey.showClipboardButton) private var showClipboardButton = PreferenceDefault.showClipboardButton
    @AppStorage(AppPreferenceKey.showOpenShelfIndicator) private var showOpenShelfIndicator = PreferenceDefault.showOpenShelfIndicator
    @AppStorage(AppPreferenceKey.hideNotchOnExternalDisplays) private var hideNotchOnExternalDisplays = PreferenceDefault.hideNotchOnExternalDisplays
    @AppStorage(AppPreferenceKey.hideNotchFromScreenshots) private var hideNotchFromScreenshots = PreferenceDefault.hideNotchFromScreenshots
    @AppStorage(AppPreferenceKey.useDynamicIslandStyle) private var useDynamicIslandStyle = PreferenceDefault.useDynamicIslandStyle
    @AppStorage(AppPreferenceKey.useDynamicIslandTransparent) private var useDynamicIslandTransparent = PreferenceDefault.useDynamicIslandTransparent
    @AppStorage(AppPreferenceKey.externalDisplayUseDynamicIsland) private var externalDisplayUseDynamicIsland = PreferenceDefault.externalDisplayUseDynamicIsland
    
    // HUD and Media Player settings
    @AppStorage(AppPreferenceKey.enableHUDReplacement) private var enableHUDReplacement = PreferenceDefault.enableHUDReplacement
    @AppStorage(AppPreferenceKey.enableBatteryHUD) private var enableBatteryHUD = PreferenceDefault.enableBatteryHUD
    @AppStorage(AppPreferenceKey.enableCapsLockHUD) private var enableCapsLockHUD = PreferenceDefault.enableCapsLockHUD
    @AppStorage(AppPreferenceKey.enableAirPodsHUD) private var enableAirPodsHUD = PreferenceDefault.enableAirPodsHUD
    @AppStorage(AppPreferenceKey.enableLockScreenHUD) private var enableLockScreenHUD = PreferenceDefault.enableLockScreenHUD
    @AppStorage(AppPreferenceKey.enableDNDHUD) private var enableDNDHUD = PreferenceDefault.enableDNDHUD
    @AppStorage(AppPreferenceKey.showMediaPlayer) private var showMediaPlayer = PreferenceDefault.showMediaPlayer
    @AppStorage(AppPreferenceKey.autoFadeMediaHUD) private var autoFadeMediaHUD = PreferenceDefault.autoFadeMediaHUD
    @AppStorage(AppPreferenceKey.debounceMediaChanges) private var debounceMediaChanges = PreferenceDefault.debounceMediaChanges
    @AppStorage(AppPreferenceKey.enableRealAudioVisualizer) private var enableRealAudioVisualizer = PreferenceDefault.enableRealAudioVisualizer
    @AppStorage(AppPreferenceKey.autoShrinkShelf) private var autoShrinkShelf = PreferenceDefault.autoShrinkShelf  // Legacy
    @AppStorage(AppPreferenceKey.autoShrinkDelay) private var autoShrinkDelay = PreferenceDefault.autoShrinkDelay  // Legacy
    @AppStorage(AppPreferenceKey.autoCollapseDelay) private var autoCollapseDelay = PreferenceDefault.autoCollapseDelay
    @AppStorage(AppPreferenceKey.autoCollapseShelf) private var autoCollapseShelf = PreferenceDefault.autoCollapseShelf
    @AppStorage(AppPreferenceKey.autoExpandShelf) private var autoExpandShelf = PreferenceDefault.autoExpandShelf
    @AppStorage(AppPreferenceKey.autoExpandDelay) private var autoExpandDelay = PreferenceDefault.autoExpandDelay
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
    
    // Hover states for sidebar items (6 tabs)
    @State private var hoverShelf = false
    @State private var hoverBasket = false
    @State private var hoverClipboard = false
    @State private var hoverHUDs = false
    @State private var hoverExtensions = false
    @State private var hoverAbout = false
    @State private var isCoffeeHovering = false
    @State private var isIntroHovering = false
    @State private var scrollOffset: CGFloat = 0
    
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
                VStack(spacing: 6) {
                    sidebarButton(title: "Shelf & Basket", icon: "star.fill", tag: "Features", isHovering: $hoverShelf)
                    sidebarButton(title: "Clipboard", icon: "clipboard.fill", tag: "Clipboard", isHovering: $hoverClipboard)
                    sidebarButton(title: "HUDs", icon: "dial.medium.fill", tag: "HUDs", isHovering: $hoverHUDs)
                    sidebarButton(title: "Extensions", icon: "puzzlepiece.extension.fill", tag: "Extensions", isHovering: $hoverExtensions)
                    sidebarButton(title: "About", icon: "info.circle.fill", tag: "About", isHovering: $hoverAbout)
                    
                    Spacer()
                    
                    // Buy Me a Coffee button
                    Link(destination: URL(string: "https://buymeacoffee.com/droppy")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("Support")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        // BMC Yellow: #FFDD00
                        .background(Color(red: 1.0, green: 0.867, blue: 0.0).opacity(isCoffeeHovering ? 1.0 : 0.9))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(DroppyAnimation.hover) {
                            isCoffeeHovering = hovering
                        }
                    }
                    
                    // Update button at bottom
                    Button {
                        UpdateChecker.shared.checkAndNotify()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Update")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(isUpdateHovering ? 1.0 : 0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(DroppyAnimation.hover) {
                            isUpdateHovering = hovering
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(minWidth: 200)
                .background(Color.clear) 
            } detail: {
                ZStack(alignment: .top) {
                    Form {
                        if selectedTab == "Features" {
                            featuresSettings
                        } else if selectedTab == "Clipboard" {
                            clipboardSettings
                        } else if selectedTab == "HUDs" {
                            hudSettings
                        } else if selectedTab == "Extensions" {
                            integrationsSettings
                        } else if selectedTab == "About" {
                            aboutSettings
                        }
                    }
                    .formStyle(.grouped)
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
            // Check if there's a pending extension from a deep link
            if let pending = SettingsWindowController.shared.pendingExtensionToOpen {
                selectedTab = "Extensions"
                SettingsWindowController.shared.clearPendingExtension()
                // Delay to allow card views to fully initialize before presenting sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    deepLinkedExtension = pending
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openExtensionFromDeepLink)) { notification in
            // Always navigate to Extensions tab
            selectedTab = "Extensions"
            // If a specific extension type was provided, open its sheet
            if let extensionType = notification.object as? ExtensionType {
                // Small delay to allow tab switch animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    deepLinkedExtension = extensionType
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSmartExportSettings)) { _ in
            // Navigate to Features tab where Smart Export is located
            selectedTab = "Features"
        }
    }
    
    // MARK: - Sidebar Button Helper
    
    private func sidebarButton(title: String, icon: String, tag: String, isHovering: Binding<Bool>) -> some View {
        Button {
            selectedTab = tag
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selectedTab == tag 
                          ? Color.blue.opacity(isHovering.wrappedValue ? 1.0 : 0.8) 
                          : Color.white.opacity(isHovering.wrappedValue ? 0.15 : 0.08))
            )
            .foregroundStyle(selectedTab == tag ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DroppyAnimation.hover) {
                isHovering.wrappedValue = hovering
            }
        }
    }
    
    // MARK: - Sections
    
    // MARK: Features Tab (Shelf + Basket + Shared)
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
                    VStack(alignment: .leading, spacing: 10) {
                        Text("External Display Style")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            DisplayModeButton(
                                title: "Notch",
                                isSelected: !externalDisplayUseDynamicIsland,
                                icon: {
                                    UShape()
                                        .fill(!externalDisplayUseDynamicIsland ? Color.blue : Color.white.opacity(0.5))
                                        .frame(width: 60, height: 18)
                                }
                            ) {
                                externalDisplayUseDynamicIsland = false
                            }
                            
                            DisplayModeButton(
                                title: "Dynamic Island",
                                isSelected: externalDisplayUseDynamicIsland,
                                icon: {
                                    Capsule()
                                        .fill(externalDisplayUseDynamicIsland ? Color.blue : Color.white.opacity(0.5))
                                        .frame(width: 50, height: 16)
                                }
                            ) {
                                externalDisplayUseDynamicIsland = true
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } header: {
                Text("Display")
            }
            
            // MARK: Display Mode (Non-notch displays only)
            if !hasPhysicalNotch {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Display Mode")
                            .font(.headline)
                        
                        Text("Choose how Droppy appears at the top of your screen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Mode picker with visual icons
                        HStack(spacing: 12) {
                            DisplayModeButton(
                                title: "Notch",
                                isSelected: !useDynamicIslandStyle,
                                icon: {
                                    UShape()
                                        .fill(!useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
                                        .frame(width: 60, height: 18)
                                }
                            ) {
                                useDynamicIslandStyle = false
                            }
                            
                            DisplayModeButton(
                                title: "Dynamic Island",
                                isSelected: useDynamicIslandStyle,
                                icon: {
                                    Capsule()
                                        .fill(useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
                                        .frame(width: 50, height: 16)
                                }
                            ) {
                                useDynamicIslandStyle = true
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
                            Text(String(format: "%.1fs", autoCollapseDelay))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $autoCollapseDelay, in: 0.5...2.0, step: 0.5)
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
                            Text(String(format: "%.1fs", autoExpandDelay))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $autoExpandDelay, in: 0.5...2.0, step: 0.5)
                    }
                }
            } header: {
                Text("Shelf Behavior")
            }
            
            // MARK: Shared Features
            Section {
                // AirDrop Zone (affects both shelf and basket)
                HStack(spacing: 8) {
                    AirDropZoneInfoButton()
                    Toggle(isOn: Binding(
                        get: { enableAirDropZone || enableShelfAirDropZone },
                        set: { newValue in
                            enableAirDropZone = newValue
                            enableShelfAirDropZone = newValue
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text("AirDrop Zone")
                            Text("Drop files on the right side to share via AirDrop")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
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
                    Picker(selection: $basketAutoHideEdge) {
                        Text("Left Edge").tag("left")
                        Text("Right Edge").tag("right")
                        Text("Bottom Edge").tag("bottom")
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Hide Edge")
                            Text("Which edge the basket slides to")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    PeekPreview(edge: basketAutoHideEdge)
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
                        Picker(selection: $basketAutoHideEdge) {
                            Text("Left Edge").tag("left")
                            Text("Right Edge").tag("right")
                            Text("Bottom Edge").tag("bottom")
                        } label: {
                            VStack(alignment: .leading) {
                                Text("Hide Edge")
                                Text("Which edge the basket slides to")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        // Animated peek preview
                        PeekPreview(edge: basketAutoHideEdge)
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
                        Toggle(isOn: $autoFadeMediaHUD) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-Hide Preview")
                                Text("Fade out mini player after 5 seconds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Toggle(isOn: $enableRealAudioVisualizer) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Real Audio Visualizer")
                                Text("Visualizer reacts to actual audio")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: enableRealAudioVisualizer) { _, newValue in
                            if newValue {
                                Task {
                                    await SystemAudioAnalyzer.shared.requestPermission()
                                }
                            }
                        }
                        
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
                    }
                } else {
                    // macOS 14 - feature not available
                    HStack(spacing: 12) {
                        Image(systemName: "music.note.tv")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                        
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
            } header: {
                Text("System")
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
            
            // MARK: Screen State
            Section {
                // Lock Screen
                HStack(spacing: 12) {
                    LockScreenHUDIcon()
                    
                    Toggle(isOn: $enableLockScreenHUD) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lock Screen")
                            Text("Show lock animation")
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
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))
                        Text("Requires Full Disk Access")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 52)
                }
            } header: {
                Text("Screen State")
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
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
                        case .spotify:
                            SpotifyAuthManager.shared.startAuthentication()
                        case .elementCapture, .aiBackgroundRemoval, .windowSnap, .voiceTranscribe, .ffmpegVideoCompression, .terminalNotch, .menuBarManager:
                            break // No action needed - these have their own configuration UI
                        }
                    }
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
                    VStack(alignment: .leading, spacing: 10) {
                        Text("External Display Style")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            DisplayModeButton(
                                title: "Notch",
                                isSelected: !externalDisplayUseDynamicIsland,
                                icon: {
                                    UShape()
                                        .fill(!externalDisplayUseDynamicIsland ? Color.blue : Color.white.opacity(0.5))
                                        .frame(width: 60, height: 18)
                                }
                            ) {
                                externalDisplayUseDynamicIsland = false
                            }
                            
                            DisplayModeButton(
                                title: "Dynamic Island",
                                isSelected: externalDisplayUseDynamicIsland,
                                icon: {
                                    Capsule()
                                        .fill(externalDisplayUseDynamicIsland ? Color.blue : Color.white.opacity(0.5))
                                        .frame(width: 50, height: 16)
                                }
                            ) {
                                externalDisplayUseDynamicIsland = true
                            }
                        }
                        
                        // Note: Transparency for DI is controlled by the main "Transparent Background" toggle
                    }
                    .padding(.top, 4)
                }
            } header: {
                Text("Visual Style")
            }
            
            // MARK: Display Mode (Non-notch displays only)
            // MacBooks WITH a physical notch MUST use notch mode - no choice
            // Only non-notch Macs (iMacs, Mac minis, older MacBooks) can choose
            if !hasPhysicalNotch {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Display Mode")
                            .font(.headline)
                        
                        Text("Choose how Droppy appears at the top of your screen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Mode picker with visual icons
                        HStack(spacing: 12) {
                            // Notch Mode option
                            DisplayModeButton(
                                title: "Notch",
                                isSelected: !useDynamicIslandStyle,
                                icon: {
                                    UShape()
                                        .fill(!useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
                                        .frame(width: 60, height: 18)
                                }
                            ) {
                                useDynamicIslandStyle = false
                            }
                            
                            // Dynamic Island Mode option
                            DisplayModeButton(
                                title: "Dynamic Island",
                                isSelected: useDynamicIslandStyle,
                                icon: {
                                    Capsule()
                                        .fill(useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
                                        .frame(width: 50, height: 16)
                                }
                            ) {
                                useDynamicIslandStyle = true
                            }
                        }
                        
                        // Note: Transparency is controlled by the main "Transparent Background" toggle
                        // No separate toggle needed here - it applies globally to all DI views
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
                            Text(String(format: "%.1fs", autoCollapseDelay))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $autoCollapseDelay, in: 0.5...2.0, step: 0.5)
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
                            Text(String(format: "%.1fs", autoExpandDelay))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $autoExpandDelay, in: 0.5...2.0, step: 0.5)
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
            } header: {
                Text("Accessibility")
            } footer: {
                Text("Visual hints, quick-access buttons, and screenshot visibility.")
            }
        }
    }
    
    private var aboutSettings: some View {
        Group {
            // MARK: Startup (merged from Features tab)
            Section {
                Toggle(isOn: Binding(
                    get: { showInMenuBar },
                    set: { newValue in
                        if newValue {
                            // Enabling - just set it
                            showInMenuBar = true
                        } else {
                            // Disabling - show warning first, then set
                            showMenuBarHiddenWarning = true
                        }
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Menu Bar Icon")
                        Text("Display Droppy icon in the menu bar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .sheet(isPresented: $showMenuBarHiddenWarning) {
                    MenuBarHiddenSheet(
                        showInMenuBar: $showInMenuBar,
                        isPresented: $showMenuBarHiddenWarning
                    )
                }
                
                Toggle(isOn: Binding(
                    get: { startAtLogin },
                    set: { newValue in
                        startAtLogin = newValue
                        LaunchAtLoginManager.setLaunchAtLogin(enabled: newValue)
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Launch at Login")
                        Text("Start Droppy automatically when you log in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Startup")
            }
            
            // MARK: About
            Section {
            HStack(spacing: 14) {
                // App Icon
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                VStack(alignment: .leading) {
                    Text("Droppy")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Version \(UpdateChecker.shared.currentVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    OnboardingWindowController.shared.show()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Introduction")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(isIntroHovering ? 1.0 : 0.8))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(DroppyAnimation.hover) {
                        isIntroHovering = hovering
                    }
                }
            }
            .padding(.vertical, 8)
            
            
            LabeledContent("Developer", value: "Jordy Spruit")
            
            if let downloads = downloadCount {
                LabeledContent {
                    Text("\(downloads) Users")
                } label: {
                    VStack(alignment: .leading) {
                        Text("Downloads")
                        Text("We do NOT store personal data. We ONLY track the total amount of downloads.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        // Official BMC Logo (cached to prevent flashing)
                        CachedAsyncImage(url: URL(string: "https://i.postimg.cc/MHxm3CKr/5c58570cfdd26f0001068f06-198x149-2x.avif")) { image in
                             image.resizable()
                                  .aspectRatio(contentMode: .fit)
                        } placeholder: {
                             Color.gray.opacity(0.3)
                        }
                        .frame(width: 44, height: 44) // Generic size container
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Support Development")
                                .font(.headline)
                            
                            Text("Hi, I'm Jordy. I'm a solo developer building Droppy because I believe essential tools should be free.\n\nI don't sell this app, but if you enjoy using it, a coffee would mean the world to me. Thanks for your support! ❤️")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Link(destination: URL(string: "https://buymeacoffee.com/droppy")!) {
                                HStack(spacing: 8) {
                                    Text("Buy me a coffee")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                // BMC Yellow: #FFDD00
                                .background(Color(red: 1.0, green: 0.867, blue: 0.0).opacity(isCoffeeHovering ? 1.0 : 0.9))
                                .foregroundStyle(.black) // Black text for contrast on yellow
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                withAnimation(DroppyAnimation.hover) {
                                    isCoffeeHovering = hovering
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("About")
        }
        .onAppear {
            Task {
                if let count = try? await AnalyticsService.shared.fetchDownloadCount() {
                    downloadCount = count
                }
            }
        }
        }
    }
    
    @State private var downloadCount: Int?
    
    // MARK: - Clipboard
    @AppStorage(AppPreferenceKey.enableClipboard) private var enableClipboard = PreferenceDefault.enableClipboard
    @AppStorage(AppPreferenceKey.clipboardHistoryLimit) private var clipboardHistoryLimit = PreferenceDefault.clipboardHistoryLimit
    @AppStorage(AppPreferenceKey.clipboardAutoFocusSearch) private var autoFocusSearch = PreferenceDefault.clipboardAutoFocusSearch
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
                .onChange(of: clipboardHistoryLimit) { _, _ in
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
                
                // Copy+Favorite Shortcut (Issue #43)
                Toggle(isOn: $copyFavoriteEnabled) {
                    VStack(alignment: .leading) {
                        Text("Copy + Favorite Shortcut")
                        Text("Global shortcut to copy and mark as favorite at once")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: copyFavoriteEnabled) { _, newValue in
                    if newValue {
                        ClipboardWindowController.shared.startCopyFavoriteShortcut()
                    } else {
                        ClipboardWindowController.shared.stopCopyFavoriteShortcut()
                    }
                }
                
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
                
                // Auto-focus search toggle (advanced - at bottom)
                Toggle(isOn: $autoFocusSearch) {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 6) {
                            Text("Auto-Focus Search")
                            Text("advanced")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }
                        Text("Open search bar automatically when clipboard opens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: autoFocusSearch) { _, newValue in
                    if newValue {
                        // User is enabling - show explanation sheet
                        showAutoFocusSearchWarning = true
                    }
                }
                .sheet(isPresented: $showAutoFocusSearchWarning) {
                    AutoFocusSearchInfoSheet(autoFocusSearch: $autoFocusSearch)
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
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            
            // Add app button
            Button {
                showAppPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Add App...")
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
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
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        .buttonStyle(.plain)
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
    @State private var animateSwipe = false
    
    var body: some View {
        Button {
            showPopover.toggle()
            if showPopover {
                // Start animation when popover opens
                animateSwipe = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        animateSwipe = true
                    }
                }
            }
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 16) {
                Text("Swipe Gesture")
                    .font(.system(size: 15, weight: .semibold))
                
                // Animated swipe preview with Droppy design
                HStack(spacing: 16) {
                    // Media icon - gradient glass style
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.pink.opacity(0.25), Color.pink.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: .pink.opacity(0.2), radius: 8, y: 2)
                            Image(systemName: "music.note")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.pink, .pink.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .frame(width: 44, height: 44)
                        
                        Text("Media")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Animated arrows
                    VStack(spacing: 4) {
                        // Left arrows (swipe left for media)
                        HStack(spacing: 1) {
                            Image(systemName: "chevron.left")
                            Image(systemName: "chevron.left")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.pink)
                        .offset(x: animateSwipe ? -4 : 4)
                        .opacity(animateSwipe ? 1 : 0.4)
                        
                        // Right arrows (swipe right for shelf)
                        HStack(spacing: 1) {
                            Image(systemName: "chevron.right")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.blue)
                        .offset(x: animateSwipe ? 4 : -4)
                        .opacity(animateSwipe ? 0.4 : 1)
                    }
                    .frame(width: 24)
                    
                    // Shelf icon - gradient glass style
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.25), Color.blue.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: .blue.opacity(0.2), radius: 8, y: 2)
                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .frame(width: 44, height: 44)
                        
                        Text("Shelf")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                // Instructions with colored indicators
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(LinearGradient(colors: [.pink, .pink.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 6, height: 6)
                        Text("Swipe left → Media")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .blue.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 6, height: 6)
                        Text("Swipe right → Shelf")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(width: 180)
        }
    }
}

// MARK: - Notch Shelf Info Button

/// Info button explaining right-click to hide and show
struct NotchShelfInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 12) {
                Text("Notch Shelf Tips")
                    .font(.system(size: 15, weight: .semibold))
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "cursorarrow.click.2")
                            .foregroundStyle(.red)
                        Text("**Right-click** to hide the notch/island")
                            .font(.system(size: 13))
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "cursorarrow.click.2")
                            .foregroundStyle(.green)
                        Text("**Right-click** the area again to show")
                            .font(.system(size: 13))
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "menubar.arrow.up.rectangle")
                            .foregroundStyle(.blue)
                        Text("Or use the **menu bar icon**")
                            .font(.system(size: 13))
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(width: 280)
        }
    }
}

// MARK: - Basket Gesture Info Button

/// Info button explaining the jiggle gesture to summon basket
struct BasketGestureInfoButton: View {
    @State private var showPopover = false
    @State private var animateJiggle = false
    
    var body: some View {
        Button {
            showPopover.toggle()
            if showPopover {
                animateJiggle = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(DroppyAnimation.hoverQuick.repeatForever(autoreverses: true)) {
                        animateJiggle = true
                    }
                }
            }
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 16) {
                Text("Summon Basket")
                    .font(.system(size: 15, weight: .semibold))
                
                // Jiggle animation preview
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.25), Color.purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .purple.opacity(0.2), radius: 8, y: 2)
                        
                        Image(systemName: "doc.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .purple.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                            )
                    }
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(animateJiggle ? 8 : -8))
                    
                    Text("Jiggle while dragging")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw.fill")
                        .foregroundStyle(.purple)
                        .font(.system(size: 11))
                    Text("Shake files to summon basket")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(width: 180)
        }
    }
}

// MARK: - Peek Mode Info Button

/// Info button explaining auto-hide with peek behavior
struct PeekModeInfoButton: View {
    @State private var showPopover = false
    @State private var animatePeek = false
    
    var body: some View {
        Button {
            showPopover.toggle()
            if showPopover {
                animatePeek = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        animatePeek = true
                    }
                }
            }
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 16) {
                Text("Peek Mode")
                    .font(.system(size: 15, weight: .semibold))
                
                // Peek animation
                HStack(spacing: 0) {
                    // Screen representation
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 80, height: 50)
                        
                        Text("Screen")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Basket peeking from edge
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.15)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                            )
                        
                        Image(systemName: "basket.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.purple)
                    }
                    .frame(width: 30, height: 40)
                    .offset(x: animatePeek ? 0 : 20)
                    .opacity(animatePeek ? 1 : 0.5)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 5, height: 5)
                        Text("Slides to edge when idle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 5, height: 5)
                        Text("Hover edge to reveal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(width: 180)
        }
    }
}

// MARK: - Instant Appear Info Button

/// Info button explaining instant basket appear on drag
struct InstantAppearInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Button { showPopover.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 16) {
                Text("Instant Appear")
                    .font(.system(size: 15, weight: .semibold))
                
                HStack(spacing: 16) {
                    // Drag icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient(colors: [Color.orange.opacity(0.25), Color.orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                            .shadow(color: .orange.opacity(0.2), radius: 6, y: 2)
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    }
                    .frame(width: 40, height: 40)
                    
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    
                    // Basket appears
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient(colors: [Color.purple.opacity(0.25), Color.purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.purple.opacity(0.3), lineWidth: 1))
                            .shadow(color: .purple.opacity(0.2), radius: 6, y: 2)
                        Image(systemName: "basket.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(LinearGradient(colors: [.purple, .purple.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    }
                    .frame(width: 40, height: 40)
                }
                .padding(.vertical, 4)
                
                Text("Basket appears immediately\nwhen you start dragging")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(width: 200)
        }
    }
}

// MARK: - AirDrop Zone Info Button

/// Info button explaining the AirDrop drop zone
struct AirDropZoneInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Button { showPopover.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 16) {
                Text("AirDrop Zone")
                    .font(.system(size: 15, weight: .semibold))
                
                // Basket with AirDrop zone visualization
                HStack(spacing: 2) {
                    // Regular basket area
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.purple.opacity(0.15))
                        VStack(spacing: 2) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 10))
                            Image(systemName: "doc.fill")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.purple.opacity(0.6))
                    }
                    .frame(width: 50, height: 50)
                    
                    // AirDrop zone
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(colors: [Color.cyan.opacity(0.25), Color.blue.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                        
                        Image(systemName: "airplayaudio")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                    }
                    .frame(width: 40, height: 50)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.cyan).frame(width: 5, height: 5)
                        Text("Drop on right side")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.cyan).frame(width: 5, height: 5)
                        Text("Opens AirDrop picker")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(width: 180)
        }
    }
}

// MARK: - Auto-Clean Info Button

/// Info button explaining the Clear After Drop feature
struct AutoCleanInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Button { showPopover.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 16) {
                Text("Auto-Remove")
                    .font(.system(size: 15, weight: .semibold))
                
                // Visual: item leaving shelf
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.purple.opacity(0.15))
                        Image(systemName: "doc.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.purple.opacity(0.6))
                    }
                    .frame(width: 40, height: 40)
                    
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.green.opacity(0.15))
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .frame(width: 40, height: 40)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Clears item from shelf/basket")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Original file is NOT deleted")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(width: 220)
        }
    }
}

// MARK: - Always Copy Info Button

/// Info button explaining the Protect Originals feature
struct AlwaysCopyInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Button { showPopover.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 16) {
                Text("Protect Originals")
                    .font(.system(size: 15, weight: .semibold))
                
                // Visual: file with shield
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.blue.opacity(0.15))
                        Image(systemName: "doc.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                    }
                    .frame(width: 40, height: 40)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.green.opacity(0.15))
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 16))
                            .foregroundStyle(.green)
                    }
                    .frame(width: 40, height: 40)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Files are copied, never moved")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Original stays at source location")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    
                    Divider().padding(.vertical, 2)
                    
                    Text("When disabled:")
                        .font(.caption).fontWeight(.medium)
                    HStack(spacing: 6) {
                        Circle().fill(Color.orange).frame(width: 5, height: 5)
                        Text("Same disk = may delete original")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(width: 240)
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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                    dismiss()
                } label: {
                    Text("Disable Anyway")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isHoveringConfirm ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringConfirm = h }
                }
                
                Spacer()
                
                // Keep Protection (primary - right)
                Button {
                    alwaysCopyOnDrag = true
                    dismiss()
                } label: {
                    Text("Keep Protection")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(isHoveringCancel ? 1.0 : 0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringCancel = h }
                }
            }
            .padding(16)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isHoveringDisable ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringDisable = h }
                }
                
                Spacer()
                
                // Keep Enabled (primary - right)
                Button {
                    dismiss()
                } label: {
                    Text("Got It")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(isHoveringKeep ? 1.0 : 0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringKeep = h }
                }
            }
            .padding(16)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isHoveringDisable ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringDisable = h }
                }
                
                Spacer()
                
                // Keep Enabled (primary - right)
                Button {
                    dismiss()
                } label: {
                    Text("Got It")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(isHoveringKeep ? 1.0 : 0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringKeep = h }
                }
            }
            .padding(16)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isHoveringCancel ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringCancel = h }
                }
                
                Spacer()
                
                // I've Granted Access
                Button {
                    DNDManager.shared.recheckAccess()
                    isPresented = false
                } label: {
                    Text("I've Granted Access")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isHoveringGranted ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringGranted = h }
                }
                
                // Open Settings (primary - right)
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(isHoveringOpen ? 1.0 : 0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringOpen = h }
                }
            }
            .padding(16)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private func stepRow(number: String, text: String, isFirst: Bool = false, isLast: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
                .frame(width: 22, height: 22)
                .background(Color.blue.opacity(0.15))
                .clipShape(Circle())
            
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
    @Binding var showInMenuBar: Bool
    @Binding var isPresented: Bool
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
                        Text("Right-click the Notch or Dynamic Island to access Settings anytime")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.02))
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isHoveringCancel ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringCancel = h }
                }
                
                Spacer()
                
                // Hide Icon (primary - right)
                Button {
                    showInMenuBar = false
                    isPresented = false
                } label: {
                    Text("Hide Icon")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(isHoveringHide ? 1.0 : 0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringHide = h }
                }
            }
            .padding(16)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Power Folders Info Button
struct PowerFoldersInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Button { showPopover.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 16) {
                Text("Power Folders")
                    .font(.system(size: 15, weight: .semibold))
                
                // Folder visualization
                HStack(spacing: 12) {
                    // Regular folder
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue.opacity(0.15))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                        Image(systemName: "folder.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.blue)
                    }
                    .frame(width: 45, height: 45)
                    
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    
                    // Pinned folder
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.yellow.opacity(0.15))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.yellow.opacity(0.5), lineWidth: 2))
                        VStack(spacing: 2) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.yellow)
                        }
                    }
                    .frame(width: 45, height: 45)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.yellow).frame(width: 5, height: 5)
                        Text("Pin folders to keep them")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.yellow).frame(width: 5, height: 5)
                        Text("Drop files directly into them")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.yellow).frame(width: 5, height: 5)
                        Text("Hover to preview contents")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(width: 200)
        }
    }
}

// MARK: - Clipboard Shortcut Info Button

/// Info button showing the clipboard keyboard shortcut
struct ClipboardShortcutInfoButton: View {
    var shortcut: SavedShortcut?
    @State private var showPopover = false
    
    /// Parse shortcut into individual key components for display
    private var shortcutKeys: [String] {
        guard let s = shortcut else {
            // Default fallback
            return ["⌘", "⇧", "Space"]
        }
        
        var keys: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: s.modifiers)
        
        if flags.contains(.command) { keys.append("⌘") }
        if flags.contains(.shift) { keys.append("⇧") }
        if flags.contains(.option) { keys.append("⌥") }
        if flags.contains(.control) { keys.append("⌃") }
        
        // Add the actual key
        let keyString = KeyCodeHelper.string(for: UInt16(s.keyCode))
        keys.append(keyString)
        
        return keys
    }
    
    var body: some View {
        Button { showPopover.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 16) {
                Text("Clipboard Tips")
                    .font(.system(size: 15, weight: .semibold))
                
                // Keyboard shortcut section - dynamic based on user's shortcut
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(shortcutKeys, id: \.self) { key in
                            KeyCapView(
                                key: key,
                                color: .cyan,
                                isWide: key.count > 1
                            )
                        }
                    }
                    Text("Open clipboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .padding(.vertical, 2)
                
                // Double-tap rename section
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient(colors: [Color.orange.opacity(0.25), Color.orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                        }
                        .frame(width: 32, height: 32)
                        
                        VStack(spacing: 2) {
                            Text("×2")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange.opacity(0.7))
                        }
                        
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 10))
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient(colors: [Color.green.opacity(0.25), Color.green.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.green.opacity(0.3), lineWidth: 1))
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundStyle(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                        }
                        .frame(width: 32, height: 32)
                    }
                    Text("Double-tap to rename & save")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(width: 210)
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
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [color.opacity(0.2), color.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
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
        Button { showPopover.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 16) {
                Text("External Display")
                    .font(.system(size: 15, weight: .semibold))
                
                // Monitor icons
                HStack(spacing: 12) {
                    // Laptop
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 30, height: 20)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 8, height: 3)
                                .offset(y: -6)
                        }
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 36, height: 3)
                        Text("Built-in")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    // External monitor
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 40, height: 26)
                            Capsule()
                                .fill(Color.green.opacity(0.4))
                                .frame(width: 14, height: 5)
                                .offset(y: -8)
                        }
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 4, height: 6)
                        Text("External")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Choose Notch or Island style")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Or hide completely")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(width: 190)
        }
    }
}

// MARK: - Quick Actions Info Button

struct QuickActionsInfoButton: View {
    @State private var showPopover = false
    
    var body: some View {
        Button { showPopover.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .center, spacing: 16) {
                Text("Quick Actions")
                    .font(.system(size: 15, weight: .semibold))
                
                // Visual demonstration
                HStack(spacing: 12) {
                    // Select All button
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.blue.opacity(0.15))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.blue)
                    }
                    .frame(width: 36, height: 36)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    // Add All button
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.green.opacity(0.15))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.green.opacity(0.3), lineWidth: 1))
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.green)
                    }
                    .frame(width: 36, height: 36)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.blue).frame(width: 5, height: 5)
                        Text("Select All selects all files")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Add All copies to Finder folder")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(width: 210)
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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(24)
            
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isHoveringDisable ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringDisable = h }
                }
                
                Spacer()
                
                // Keep Enabled (primary - right)
                Button {
                    dismiss()
                } label: {
                    Text("Got It")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(isHoveringKeep ? 1.0 : 0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hover) { isHoveringKeep = h }
                }
            }
            .padding(16)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
