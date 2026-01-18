import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var selectedTab: String? = "Features"
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @AppStorage("enableNotchShelf") private var enableNotchShelf = true
    @AppStorage("enableFloatingBasket") private var enableFloatingBasket = true
    @AppStorage("enableBasketAutoHide") private var enableBasketAutoHide = false  // Auto-hide basket with peek (v5.3)
    @AppStorage("enableAutoClean") private var enableAutoClean = false  // Auto-clear after drag-out (v6.0.2)
    @AppStorage("enableAirDropZone") private var enableAirDropZone = true  // AirDrop drop zone in basket
    @AppStorage("enableShelfAirDropZone") private var enableShelfAirDropZone = false  // AirDrop drop zone in shelf
    @AppStorage("basketAutoHideEdge") private var basketAutoHideEdge = "right"  // "left", "right", "bottom"
    @AppStorage("instantBasketOnDrag") private var instantBasketOnDrag = false  // Show basket immediately on drag
    @AppStorage("showClipboardButton") private var showClipboardButton = false
    @AppStorage("showOpenShelfIndicator") private var showOpenShelfIndicator = true
    @AppStorage("showDropIndicator") private var showDropIndicator = true
    @AppStorage("hideNotchOnExternalDisplays") private var hideNotchOnExternalDisplays = false
    @AppStorage("hideNotchFromScreenshots") private var hideNotchFromScreenshots = false
    @AppStorage("useDynamicIslandStyle") private var useDynamicIslandStyle = true  // Default: true for non-notch
    @AppStorage("useDynamicIslandTransparent") private var useDynamicIslandTransparent = false  // Glass effect for DI
    @AppStorage("externalDisplayUseDynamicIsland") private var externalDisplayUseDynamicIsland = true  // External display mode
    
    // HUD and Media Player settings
    @AppStorage("enableHUDReplacement") private var enableHUDReplacement = true
    @AppStorage("enableBatteryHUD") private var enableBatteryHUD = true  // Enabled by default
    @AppStorage("enableCapsLockHUD") private var enableCapsLockHUD = true  // Caps Lock indicator
    @AppStorage("enableAirPodsHUD") private var enableAirPodsHUD = true  // AirPods connection HUD
    @AppStorage("enableLockScreenHUD") private var enableLockScreenHUD = true  // Lock/Unlock HUD
    @AppStorage("enableDNDHUD") private var enableDNDHUD = false  // Focus/DND HUD (requires Full Disk Access)
    @AppStorage("showMediaPlayer") private var showMediaPlayer = true
    @AppStorage("autoFadeMediaHUD") private var autoFadeMediaHUD = true
    @AppStorage("debounceMediaChanges") private var debounceMediaChanges = false  // Delay media HUD for rapid changes
    @AppStorage("enableRealAudioVisualizer") private var enableRealAudioVisualizer = false  // Opt-in: requires Screen Recording
    @AppStorage("autoShrinkShelf") private var autoShrinkShelf = true  // Legacy - always true now
    @AppStorage("autoShrinkDelay") private var autoShrinkDelay = 3  // Legacy - kept for backwards compat
    @AppStorage("autoCollapseDelay") private var autoCollapseDelay = 1.0  // New: 0.5-2.0 seconds
    @AppStorage("autoCollapseShelf") private var autoCollapseShelf = true  // Toggle for auto-collapse
    @AppStorage("autoExpandShelf") private var autoExpandShelf = true  // Now default true
    @AppStorage("autoExpandDelay") private var autoExpandDelay = 1.0  // New: 0.5-2.0 seconds
    @AppStorage("enableFinderServices") private var enableFinderServices = true


    
    @State private var dashPhase: CGFloat = 0
    @State private var isHistoryLimitEditing: Bool = false
    @State private var isUpdateHovering = false
    @State private var showDNDAccessAlert = false  // Full Disk Access alert for Focus Mode HUD
    @State private var showMenuBarHiddenWarning = false  // Warning when hiding menu bar icon (Issue #57)
    
    // Hover states for sidebar items
    @State private var hoverFeatures = false
    @State private var hoverAppearance = false
    @State private var hoverExtensions = false
    @State private var hoverAbout = false
    @State private var isCoffeeHovering = false
    @State private var isIntroHovering = false
    @State private var scrollOffset: CGFloat = 0
    
    /// Extension to open from deep link (e.g., droppy://extension/ai-bg)
    @State private var deepLinkedExtension: ExtensionType?
    
    /// Detects if the current screen has a physical notch
    private var hasPhysicalNotch: Bool {
        guard let screen = NSScreen.main else { return false }
        return screen.safeAreaInsets.top > 0
    }
    
    var body: some View {
        ZStack {
            NavigationSplitView {
                VStack(spacing: 6) {
                    sidebarButton(title: "Features", icon: "star.fill", tag: "Features", isHovering: $hoverFeatures)
                    sidebarButton(title: "Appearance", icon: "paintbrush.fill", tag: "Appearance", isHovering: $hoverAppearance)
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
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
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
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
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
                        } else if selectedTab == "Appearance" {
                            appearanceSettings
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
                    .animation(.easeInOut(duration: 0.2), value: scrollOffset < -10)
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
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovering.wrappedValue = hovering
            }
        }
    }
    
    // MARK: - Sections
    
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
                    
                    // Shelf AirDrop Zone toggle
                    HStack(spacing: 8) {
                        AirDropZoneInfoButton()
                        Toggle(isOn: $enableShelfAirDropZone) {
                            VStack(alignment: .leading) {
                                Text("AirDrop Zone")
                                Text("Drop files on the right side of empty shelf to AirDrop")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Auto-Clean toggle (applies to both shelf and basket)
                if enableNotchShelf || enableFloatingBasket {
                    Toggle(isOn: $enableAutoClean) {
                        VStack(alignment: .leading) {
                            Text("Auto-Clean")
                            Text("Auto-remove files from shelf & basket after dragging out")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Notch Shelf")
            }
            
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
                    
                    // AirDrop Zone toggle
                    HStack(spacing: 8) {
                        AirDropZoneInfoButton()
                        Toggle(isOn: $enableAirDropZone) {
                            VStack(alignment: .leading) {
                                Text("AirDrop Zone")
                                Text("Drop files on the right side to AirDrop instantly")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Floating Basket")
            }
            
            // MARK: Media Player
            Section {
                // Media Player requires macOS 15.0+ due to MediaRemoteAdapter.framework
                if #available(macOS 15.0, *) {
                    HStack(spacing: 8) {
                        // Info button with swipe gesture tooltip
                        SwipeGestureInfoButton()
                        
                        Toggle(isOn: $showMediaPlayer) {
                            VStack(alignment: .leading) {
                                Text("Now Playing")
                                Text("Show current song in the notch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: showMediaPlayer) { _, newValue in
                        if newValue {
                            // Ensure notch window exists (needed even if shelf is disabled)
                            NotchWindowController.shared.setupNotchWindow()
                        } else {
                            // Close window only if shelf and HUD are also disabled
                            if !enableNotchShelf && !enableHUDReplacement {
                                NotchWindowController.shared.closeWindow()
                            }
                        }
                    }
                    
                    if showMediaPlayer {
                        MediaPlayerPreview()
                        
                        Toggle(isOn: $autoFadeMediaHUD) {
                            VStack(alignment: .leading) {
                                Text("Auto-Hide Preview")
                                Text("Fade out mini player after 5 seconds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Toggle(isOn: $debounceMediaChanges) {
                            VStack(alignment: .leading) {
                                Text("Stabilize Media")
                                Text("Delay preview by 1 second to prevent flickering")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Real Audio Visualizer (opt-in for Screen Recording permission)
                        Toggle(isOn: $enableRealAudioVisualizer) {
                            VStack(alignment: .leading) {
                                Text("Real Audio Visualizer")
                                Text("Requires Screen Recording permission")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: enableRealAudioVisualizer) { _, newValue in
                            if newValue {
                                // Request Screen Recording permission when enabled
                                Task {
                                    await SystemAudioAnalyzer.shared.requestPermission()
                                }
                            }
                        }
                    }
                } else {
                    // macOS 14 - feature not available
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                            Text("Now Playing")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Requires macOS 15")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.orange.opacity(0.15))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                        Text("Media player features require macOS 15.0 (Sequoia) or later.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Media")
            }
            
            // MARK: System HUD
            Section {
                // 2x2 Grid of HUD toggle buttons
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    // Volume/Brightness HUD - special morph animation
                    VolumeAndBrightnessToggle(isEnabled: $enableHUDReplacement)
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
                    
                    // Battery HUD
                    HUDToggleButton(
                        title: "Battery",
                        icon: "battery.100.bolt",
                        isEnabled: $enableBatteryHUD,
                        color: .green
                    )
                    .onChange(of: enableBatteryHUD) { _, newValue in
                        if newValue {
                            NotchWindowController.shared.setupNotchWindow()
                        } else {
                            if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer {
                                NotchWindowController.shared.closeWindow()
                            }
                        }
                    }
                    
                    // Caps Lock HUD
                    HUDToggleButton(
                        title: "Caps Lock",
                        icon: "capslock.fill",
                        isEnabled: $enableCapsLockHUD,
                        color: .orange
                    )
                    .onChange(of: enableCapsLockHUD) { _, newValue in
                        if newValue {
                            NotchWindowController.shared.setupNotchWindow()
                        } else {
                            if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer && !enableBatteryHUD {
                                NotchWindowController.shared.closeWindow()
                            }
                        }
                    }
                    
                    // AirPods HUD
                    HUDToggleButton(
                        title: "AirPods",
                        icon: "airpodspro",
                        isEnabled: $enableAirPodsHUD,
                        color: .blue
                    )
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
                    
                    // Lock Screen HUD
                    HUDToggleButton(
                        title: "Lock Screen",
                        icon: "lock.fill",
                        isEnabled: $enableLockScreenHUD,
                        color: .purple
                    )
                    .onChange(of: enableLockScreenHUD) { _, newValue in
                        if newValue {
                            NotchWindowController.shared.setupNotchWindow()
                        } else {
                            if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer && !enableBatteryHUD && !enableCapsLockHUD && !enableAirPodsHUD {
                                NotchWindowController.shared.closeWindow()
                            }
                        }
                    }
                    
                    // Focus/DND HUD
                    HUDToggleButton(
                        title: DNDManager.shared.hasAccess ? "Focus Mode" : "Focus Mode ⚠️",
                        icon: "moon.fill",
                        isEnabled: $enableDNDHUD,
                        color: Color(red: 0.55, green: 0.35, blue: 0.95)
                    )
                    .onChange(of: enableDNDHUD) { _, newValue in
                        if newValue {
                            NotchWindowController.shared.setupNotchWindow()
                            // Only show alert if we don't have access
                            if !DNDManager.shared.hasAccess {
                                showDNDAccessAlert = true
                            }
                        } else {
                            if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer && !enableBatteryHUD && !enableCapsLockHUD && !enableAirPodsHUD && !enableLockScreenHUD {
                                NotchWindowController.shared.closeWindow()
                            }
                        }
                    }
                    .alert("Full Disk Access Required", isPresented: $showDNDAccessAlert) {
                        Button("Open Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        Button("I've Granted Access") {
                            DNDManager.shared.recheckAccess()
                        }
                        Button("Cancel", role: .cancel) {
                            enableDNDHUD = false
                        }
                    } message: {
                        Text("To detect Focus mode changes, Droppy needs Full Disk Access.\n\n1. Click \"Open Settings\"\n2. Enable Droppy in the list\n3. Click \"I've Granted Access\"")
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("System HUDs")
            } footer: {
                Text("Tap to toggle. System HUD requires Accessibility. Focus Mode requires Full Disk Access to detect Focus state changes.")
            }
            
            // MARK: Clipboard (merged from separate tab)
            clipboardSettings
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
                        case .elementCapture, .aiBackgroundRemoval, .windowSnap, .voiceTranscribe, .ffmpegVideoCompression, .terminalNotch:
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
                        
                        // Transparent Dynamic Island toggle (external displays)
                        if externalDisplayUseDynamicIsland && useTransparentBackground {
                            Divider()
                                .padding(.vertical, 4)
                            
                            Toggle(isOn: $useDynamicIslandTransparent) {
                                VStack(alignment: .leading) {
                                    Text("Transparent Dynamic Island")
                                    Text("Use glass effect instead of solid black")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } header: {
                Text("Visual Style")
            }
            
            // MARK: Display Mode (Non-notch displays only)
            // Only show on non-notch displays (iMacs, Mac minis, older MacBooks, external displays)
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
                                        .frame(width: 60, height: 18) // Wider notch shape
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
                        
                        // Transparent Dynamic Island option (only when DI + transparent enabled)
                        // Show for both built-in (useDynamicIslandStyle) AND external (externalDisplayUseDynamicIsland)
                        if (useDynamicIslandStyle || externalDisplayUseDynamicIsland) && useTransparentBackground {
                            Divider()
                                .padding(.vertical, 4)
                            
                            Toggle(isOn: $useDynamicIslandTransparent) {
                                VStack(alignment: .leading) {
                                    Text("Transparent Dynamic Island")
                                    Text("Use glass effect instead of solid black")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
                
                Toggle(isOn: $showDropIndicator) {
                    VStack(alignment: .leading) {
                        Text("Drop Indicator")
                        Text("Show NotchFace tooltip when dragging files over notch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if showDropIndicator {
                    DropIndicatorPreview()
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
                .alert("Menu Bar Icon Hidden", isPresented: $showMenuBarHiddenWarning) {
                    Button("Hide Icon") {
                        showInMenuBar = false
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("You can always access Settings by right-clicking on the Notch or Dynamic Island at the top of your screen.")
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
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
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
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
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
    @AppStorage("enableClipboardBeta") private var enableClipboard = true
    @AppStorage("clipboardHistoryLimit") private var clipboardHistoryLimit = 50
    @AppStorage("clipboardAutoFocusSearch") private var autoFocusSearch = false
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
    @AppStorage("clipboardCopyFavoriteEnabled") private var copyFavoriteEnabled = false
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
                
                // Auto-focus search toggle (Issue #43)
                Toggle(isOn: $autoFocusSearch) {
                    VStack(alignment: .leading) {
                        Text("Auto-Focus Search")
                        Text("Open search bar automatically when clipboard opens")
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
            VStack(alignment: .leading, spacing: 12) {
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
                    withAnimation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true)) {
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

