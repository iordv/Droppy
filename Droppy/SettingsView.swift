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
    @AppStorage("basketAutoHideEdge") private var basketAutoHideEdge = "right"  // "left", "right", "bottom"
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
    @AppStorage("showAirPodsHUD") private var showAirPodsHUD = true  // AirPods connection HUD
    @AppStorage("showMediaPlayer") private var showMediaPlayer = true
    @AppStorage("autoFadeMediaHUD") private var autoFadeMediaHUD = true
    @AppStorage("debounceMediaChanges") private var debounceMediaChanges = false  // Delay media HUD for rapid changes
    @AppStorage("autoShrinkShelf") private var autoShrinkShelf = true
    @AppStorage("autoShrinkDelay") private var autoShrinkDelay = 3  // Seconds (1-10)
    @AppStorage("enableFinderServices") private var enableFinderServices = true


    
    @State private var dashPhase: CGFloat = 0
    @State private var isHistoryLimitEditing: Bool = false
    @State private var isUpdateHovering = false
    
    // Hover states for sidebar items
    @State private var hoverFeatures = false
    @State private var hoverClipboard = false
    @State private var hoverAppearance = false
    @State private var hoverAccessibility = false
    @State private var hoverIntegrations = false
    @State private var hoverAbout = false
    @State private var isCoffeeHovering = false
    @State private var isAlfredHovering = false
    @State private var isFinderHovering = false
    @State private var isIntroHovering = false
    @State private var scrollOffset: CGFloat = 0
    
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
                    sidebarButton(title: "Clipboard", icon: "doc.on.clipboard", tag: "Clipboard", isHovering: $hoverClipboard)
                    sidebarButton(title: "Appearance", icon: "paintbrush.fill", tag: "Appearance", isHovering: $hoverAppearance)
                    sidebarButton(title: "Accessibility", icon: "accessibility", tag: "Accessibility", isHovering: $hoverAccessibility)
                    sidebarButton(title: "Integrations", icon: "puzzlepiece.extension.fill", tag: "Integrations", isHovering: $hoverIntegrations)
                    sidebarButton(title: "About", icon: "info.circle.fill", tag: "About", isHovering: $hoverAbout)
                    
                    Spacer()
                    
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
                .padding(.vertical, 16)
                .frame(minWidth: 200)
                .background(Color.clear) 
            } detail: {
                ZStack(alignment: .top) {
                    Form {
                        if selectedTab == "Features" {
                            featuresSettings
                        } else if selectedTab == "Clipboard" {
                            clipboardSettings
                        } else if selectedTab == "Appearance" {
                            appearanceSettings
                        } else if selectedTab == "Accessibility" {
                            indicatorsSettings
                        } else if selectedTab == "Integrations" {
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
            // MARK: Startup Section
            Section {
                Toggle(isOn: $showInMenuBar) {
                    VStack(alignment: .leading) {
                        Text("Menu Bar Icon")
                        Text("Display Droppy icon in the menu bar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            
            // MARK: Drop Zones Section
            Section {
                Toggle(isOn: $enableNotchShelf) {
                    VStack(alignment: .leading) {
                        Text("Notch Shelf")
                        Text("Drop zone at the top of your screen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

                Toggle(isOn: $enableFloatingBasket) {
                    VStack(alignment: .leading) {
                        Text("Floating Basket")
                        Text("Appears when you jiggle files anywhere on screen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: enableFloatingBasket) { oldValue, newValue in
                    if !newValue {
                        FloatingBasketWindowController.shared.hideBasket()
                    }
                }
                
                if enableFloatingBasket {
                    FloatingBasketPreview()
                    
                    // Auto-hide with peek toggle
                    Toggle(isOn: $enableBasketAutoHide) {
                        VStack(alignment: .leading) {
                            Text("Auto-Hide with Peek")
                            Text("Basket slides to edge when cursor leaves, hover to reveal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                }
                
                // Auto-Clean toggle (applies to both shelf and basket)
                if enableNotchShelf || enableFloatingBasket {
                    Toggle(isOn: $enableAutoClean) {
                        VStack(alignment: .leading) {
                            Text("Auto-Clean")
                            Text("Remove files from shelf/basket after dragging them out")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Drop Zones")
            } footer: {
                Text("Enable one or both drop zones to hold files temporarily.")
            }
            
            // MARK: Media Player
            Section {
                // Media Player requires macOS 15.0+ due to MediaRemoteAdapter.framework
                if #available(macOS 15.0, *) {
                    Toggle(isOn: $showMediaPlayer) {
                        VStack(alignment: .leading) {
                            Text("Now Playing")
                            Text("Show current song in the notch")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
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
                Toggle(isOn: $enableHUDReplacement) {
                    VStack(alignment: .leading) {
                        Text("Replace System HUD")
                        Text("Display volume and brightness controls in the notch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: enableHUDReplacement) { _, newValue in
                    if newValue {
                        // Ensure notch window exists (needed even if shelf is disabled)
                        NotchWindowController.shared.setupNotchWindow()
                        MediaKeyInterceptor.shared.start()
                    } else {
                        MediaKeyInterceptor.shared.stop()
                        // Close window only if shelf and media player are also disabled
                        if !enableNotchShelf && !showMediaPlayer {
                            NotchWindowController.shared.closeWindow()
                        }
                    }
                }
                
                if enableHUDReplacement {
                    VolumeHUDPreview()
                }
                
                Toggle(isOn: $enableBatteryHUD) {
                    VStack(alignment: .leading) {
                        Text("Battery HUD")
                        Text("Show when charging or low battery")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: enableBatteryHUD) { _, newValue in
                    if newValue {
                        // Ensure notch window exists
                        NotchWindowController.shared.setupNotchWindow()
                    } else {
                        // Close window only if shelf, HUD replacement, and media player are also disabled
                        if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer {
                            NotchWindowController.shared.closeWindow()
                        }
                    }
                }
                
                if enableBatteryHUD {
                    BatteryHUDPreview()
                }
                
                Toggle(isOn: $enableCapsLockHUD) {
                    VStack(alignment: .leading) {
                        Text("Caps Lock HUD")
                        Text("Show when Caps Lock is toggled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: enableCapsLockHUD) { _, newValue in
                    if newValue {
                        // Ensure notch window exists
                        NotchWindowController.shared.setupNotchWindow()
                    } else {
                        // Close window only if all HUD features are disabled
                        if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer && !enableBatteryHUD {
                            NotchWindowController.shared.closeWindow()
                        }
                    }
                }
                
                if enableCapsLockHUD {
                    CapsLockHUDPreview()
                }
                
                Toggle(isOn: $showAirPodsHUD) {
                    VStack(alignment: .leading) {
                        Text("AirPods HUD")
                        Text("Show when AirPods connect")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: showAirPodsHUD) { _, newValue in
                    if newValue {
                        AirPodsManager.shared.startMonitoring()
                        NotchWindowController.shared.setupNotchWindow()
                    } else {
                        AirPodsManager.shared.stopMonitoring()
                        // Close window only if all HUD features are disabled
                        if !enableNotchShelf && !enableHUDReplacement && !showMediaPlayer && !enableBatteryHUD && !enableCapsLockHUD {
                            NotchWindowController.shared.closeWindow()
                        }
                    }
                }
            } header: {
                Text("System HUDs")
            } footer: {
                Text("Requires Accessibility permissions to intercept media keys.")
            }
        }
    }
    
    private var integrationsSettings: some View {
        Group {
            // MARK: Alfred Integration
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        // Alfred Icon (bundled locally for instant loading)
                        Image("AlfredIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Alfred Integration")
                                .font(.headline)
                            
                            Text("Select files in Finder and push them to Droppy with a quick Alfred action. Supports both Shelf and Basket destinations.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Button {
                                // Open the bundled Alfred workflow for installation
                                if let workflowPath = Bundle.main.path(forResource: "Droppy", ofType: "alfredworkflow") {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: workflowPath))
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Install in Alfred")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.purple.opacity(isAlfredHovering ? 1.0 : 0.8))
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
                                    isAlfredHovering = hovering
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Alfred")
            } footer: {
                Text("Requires Alfred 4+ with Powerpack.")
            }
            
            // MARK: Finder Services
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        // Official macOS Finder icon
                        Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app"))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Finder Integration")
                                .font(.headline)
                            
                            Text("Right-click files in Finder and add them to Droppy via the Services menu. Supports both Shelf and Basket destinations.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Button {
                                FinderServicesSetupWindowController.shared.show()
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Setup Guide")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(isFinderHovering ? 1.0 : 0.8))
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
                                    isFinderHovering = hovering
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Finder")
            } footer: {
                Text("Requires one-time setup in System Settings.")
            }
            
            // MARK: Spotify Integration
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        // Official Spotify icon (bundled asset)
                        Image("SpotifyIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Spotify Integration")
                                .font(.headline)
                            
                            Text("Extra controls appear in the media player when playing from Spotify: shuffle, repeat, and replay from the start.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Status indicator
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(SpotifyController.shared.isSpotifyRunning ? Color(red: 0.11, green: 0.73, blue: 0.33) : Color.gray.opacity(0.5))
                                    .frame(width: 8, height: 8)
                                Text(SpotifyController.shared.isSpotifyRunning ? "Spotify is running" : "Spotify is not running")
                                    .font(.caption)
                                    .foregroundStyle(SpotifyController.shared.isSpotifyRunning ? .primary : .secondary)
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    // Like feature note (OAuth currently blocked by Spotify)
                    if !SpotifyAuthManager.shared.hasValidClientId {
                        Divider()
                            .padding(.vertical, 4)
                        
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Like Songs")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                
                                Text("The ability to like songs directly from Droppy is temporarily unavailable. Spotify has paused new developer app registrations.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Spotify")
            } footer: {
                Text("No setup required. Controls appear automatically when Spotify is the active player.")
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
                
                Toggle(isOn: $hideNotchOnExternalDisplays) {
                    VStack(alignment: .leading) {
                        Text("Hide on External Displays")
                        Text("Disable notch shelf on external monitors")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        if useDynamicIslandStyle && useTransparentBackground {
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
                Toggle(isOn: $autoShrinkShelf) {
                    VStack(alignment: .leading) {
                        Text("Auto-Collapse")
                        Text("Shrink shelf when mouse leaves")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if autoShrinkShelf {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Collapse Delay")
                            Spacer()
                            Text("\(autoShrinkDelay)s")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: Binding(
                            get: { Double(autoShrinkDelay) },
                            set: { autoShrinkDelay = Int($0) }
                        ), in: 1...10, step: 1)
                    }
                }
            } header: {
                Text("Shelf Behavior")
            }
        }
    }
    
    private var indicatorsSettings: some View {
        Group {
            Section {
                Toggle(isOn: $showClipboardButton) {
                    VStack(alignment: .leading) {
                        Text("Clipboard Button")
                        Text("Show button to open clipboard in shelf and basket")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Toggle(isOn: $showOpenShelfIndicator) {
                    VStack(alignment: .leading) {
                        Text("Open Shelf Indicator")
                        Text("Show \"Open Shelf\" tooltip when hovering over notch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if showOpenShelfIndicator {
                    OpenShelfIndicatorPreview()
                }
                
                Toggle(isOn: $showDropIndicator) {
                    VStack(alignment: .leading) {
                        Text("Drop Indicator")
                        Text("Show \"Drop!\" tooltip when dragging files over notch")
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
                        // Official BMC Logo
                        AsyncImage(url: URL(string: "https://i.postimg.cc/MHxm3CKr/5c58570cfdd26f0001068f06-198x149-2x.avif")) { image in
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
    @AppStorage("enableClipboardBeta") private var enableClipboard = false
    @AppStorage("clipboardHistoryLimit") private var clipboardHistoryLimit = 50
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
    
    private var clipboardSettings: some View {
        Section {
            Toggle(isOn: $enableClipboard) {
                VStack(alignment: .leading) {
                    Text("Clipboard Manager")
                    Text("History with Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: enableClipboard) { oldValue, newValue in
                if newValue {
                    // Check for Accessibility Permissions - first check WITHOUT prompting
                    let isTrusted = AXIsProcessTrusted()
                    
                    if !isTrusted {
                        // Only prompt if not already trusted
                        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
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
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

// MARK: - Feature Preview GIF Component

struct FeaturePreviewGIF: View {
    let url: String
    
    var body: some View {
        AnimatedGIFView(url: url)
            .frame(maxWidth: 500, maxHeight: 200)
            .frame(maxWidth: .infinity, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.4), location: 0),
                                .init(color: .white.opacity(0.1), location: 0.5),
                                .init(color: .black.opacity(0.2), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .padding(.vertical, 8)
    }
}

/// Static image preview with same styling as GIF previews
struct FeaturePreviewImage: View {
    let url: String
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ProgressView()
                    .frame(height: 60)
            }
        }
        .frame(maxWidth: 250, maxHeight: 80)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
        .task {
            guard let imageURL = URL(string: url) else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let loadedImage = NSImage(data: data) {
                    await MainActor.run {
                        self.image = loadedImage
                    }
                }
            } catch {
                print("Failed to load preview image: \(error)")
            }
        }
    }
}

/// Native NSImageView-based GIF display (crash-safe, no WebKit)
struct AnimatedGIFView: NSViewRepresentable {
    let url: String
    
    func makeNSView(context: Context) -> NSView {
        // Container view to properly constrain the image
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.animates = true
        imageView.imageScaling = .scaleProportionallyDown  // Only scale DOWN, never up
        imageView.canDrawSubviewsIntoLayer = true
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        container.addSubview(imageView)
        
        // Center the image within the container and constrain its edges
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            imageView.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        
        // Store imageView reference for loading
        context.coordinator.imageView = imageView
        
        // Load GIF data asynchronously
        if let gifURL = URL(string: url) {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: gifURL)
                    if let image = NSImage(data: data) {
                        await MainActor.run {
                            context.coordinator.imageView?.image = image
                        }
                    }
                } catch {
                    print("GIF load failed: \(error)")
                }
            }
        }
        
        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Ensure animation is running
        context.coordinator.imageView?.animates = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        weak var imageView: NSImageView?
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - U-Shape for Notch Icon Preview
/// Simple U-shape for notch mode icon in settings picker
struct UShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 6
        
        // Start top-left
        path.move(to: CGPoint(x: 0, y: 0))
        // Down left side
        path.addLine(to: CGPoint(x: 0, y: rect.height - radius))
        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: radius, y: rect.height),
            control: CGPoint(x: 0, y: rect.height)
        )
        // Across bottom
        path.addLine(to: CGPoint(x: rect.width - radius, y: rect.height))
        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height - radius),
            control: CGPoint(x: rect.width, y: rect.height)
        )
        // Up right side
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        return path
    }
}

// MARK: - Display Mode Button
/// Reusable button for Notch/Dynamic Island mode selection with hover and press animations
struct DisplayModeButton<Icon: View>: View {
    let title: String
    let isSelected: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            VStack(spacing: 8) {
                // Icon preview area
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                        .frame(width: 100, height: 50)
                    
                    icon()
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? Color.blue.opacity(0.5) : 
                                    (isHovering ? Color.white.opacity(0.3) : Color.white.opacity(0.1)),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.97 : (isHovering && !isSelected ? 1.02 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}


// MARK: - SwiftUI Feature Previews (Using REAL Components)

/// Volume/Brightness HUD Preview - uses REAL NotchShape and HUDSlider
struct VolumeHUDPreview: View {
    @State private var animatedValue: CGFloat = 0.65
    
    // Match real notch dimensions from NotchShelfView
    private let hudWidth: CGFloat = 280
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var wingWidth: CGFloat { (hudWidth - notchWidth) / 2 }
    
    var body: some View {
        ZStack {
            // Notch background with proper rounded corners
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight + 28)
                .overlay(
                    NotchShape(bottomRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            // HUD content - laid out exactly like real NotchHUDView
            VStack(spacing: 0) {
                // Wings: Icon (left) | Camera Gap | Percentage (right)
                HStack(spacing: 0) {
                    // Left wing - Icon
                    HStack {
                        Spacer(minLength: 0)
                        Image(systemName: volumeIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .symbolVariant(.fill)
                        Spacer(minLength: 0)
                    }
                    .frame(width: wingWidth)
                    
                    // Camera notch gap
                    Spacer().frame(width: notchWidth)
                    
                    // Right wing - Percentage (clipped to prevent animation overflow)
                    HStack {
                        Spacer(minLength: 0)
                        Text("\(Int(animatedValue * 100))%")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Spacer(minLength: 0)
                    }
                    .frame(width: wingWidth)
                    .clipped()
                }
                .frame(height: notchHeight)
                
                // REAL HUDSlider below notch
                HUDSlider(
                    value: $animatedValue,
                    accentColor: .white,
                    isActive: false,
                    onChange: nil
                )
                .frame(height: 20)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .allowsHitTesting(false)
            }
            .frame(width: hudWidth)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animatedValue = 0.35
            }
        }
    }
    
    private var volumeIcon: String {
        if animatedValue == 0 { return "speaker.slash.fill" }
        if animatedValue < 0.33 { return "speaker.wave.1.fill" }
        if animatedValue < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

/// Media Player Preview - uses REAL NotchShape, AudioSpectrumView, and MarqueeText
struct MediaPlayerPreview: View {
    @State private var isPlaying = true
    
    // Match real notch dimensions
    private let hudWidth: CGFloat = 280
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var wingWidth: CGFloat { (hudWidth - notchWidth) / 2 }
    
    var body: some View {
        ZStack {
            // Notch background with proper rounded corners
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight + 28)
                .overlay(
                    NotchShape(bottomRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            // HUD content - laid out exactly like real MediaHUDView
            VStack(spacing: 0) {
                // Wings: Album (left) | Camera Gap | Visualizer (right)
                HStack(spacing: 0) {
                    // Left wing - Album art
                    HStack {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.8))
                            )
                        Spacer(minLength: 0)
                    }
                    .frame(width: wingWidth)
                    
                    // Camera notch gap
                    Spacer().frame(width: notchWidth)
                    
                    // Right wing - REAL AudioSpectrumView
                    HStack {
                        Spacer(minLength: 0)
                        AudioSpectrumView(isPlaying: isPlaying, barCount: 4, barWidth: 3, spacing: 2, height: 16, color: .orange)
                            .frame(width: 4 * 3 + 3 * 2, height: 16)
                        Spacer(minLength: 0)
                    }
                    .frame(width: wingWidth)
                }
                .frame(height: notchHeight)
                
                // REAL MarqueeText below notch
                MarqueeText(text: "Purple Rain — Prince", speed: 30)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(height: 18)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
            .frame(width: hudWidth)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPlaying.toggle()
                }
            }
        }
    }
}

/// Clipboard Preview - realistic split view matching ClipboardWindow
struct ClipboardPreview: View {
    var body: some View {
        HStack(spacing: 0) {
            // Left: Item list
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Text("History")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                
                Divider().background(Color.white.opacity(0.1))
                
                // Items
                VStack(spacing: 2) {
                    ClipboardMockItem(icon: "doc.text.fill", text: "Hello World", color: .blue, isSelected: true)
                    ClipboardMockItem(icon: "link", text: "droppy.app", color: .green, isSelected: false)
                    ClipboardMockItem(icon: "photo.fill", text: "Image.png", color: .purple, isSelected: false)
                }
                .padding(4)
                
                Spacer(minLength: 0)
            }
            .frame(width: 110)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Right: Preview pane
            VStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("Hello World")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                    Text("Copied text")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                
                // Paste button
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 8))
                    Text("Paste")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.bottom, 8)
            }
            .frame(width: 90)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .frame(width: 200, height: 120)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

/// Single mock item for ClipboardPreview
private struct ClipboardMockItem: View {
    let icon: String
    let text: String
    let color: Color
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)
                .frame(width: 12)
            
            Text(text)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

/// Battery HUD Preview - animated charging state with real battery icon
struct BatteryHUDPreview: View {
    @State private var isCharging = false
    @State private var batteryLevel: Int = 75
    
    // Match real notch dimensions
    private let hudWidth: CGFloat = 280
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var wingWidth: CGFloat { (hudWidth - notchWidth) / 2 }
    
    private var batteryIcon: String {
        if isCharging {
            return "battery.100.bolt"
        } else {
            switch batteryLevel {
            case 0...24: return "battery.25"
            case 25...49: return "battery.50"
            case 50...74: return "battery.75"
            default: return "battery.100"
            }
        }
    }
    
    private var batteryColor: Color {
        if isCharging { return .green }
        if batteryLevel <= 20 { return .red }
        return .white // White when not charging
    }
    
    var body: some View {
        ZStack {
            // Notch background with proper rounded corners
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight)
                .overlay(
                    NotchShape(bottomRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            // Wings: Battery (left) | Camera Gap | Percentage (right)
            HStack(spacing: 0) {
                // Left wing - Battery icon with animation
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: batteryIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(batteryColor)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.pulse, options: .repeating, isActive: isCharging)
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
                
                // Camera notch gap
                Spacer().frame(width: notchWidth)
                
                // Right wing - Percentage
                HStack {
                    Spacer(minLength: 0)
                    Text("\(batteryLevel)%")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(batteryLevel)))
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
            }
            .frame(width: hudWidth, height: notchHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            // Animate charging state and battery level
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isCharging.toggle()
                    // Animate battery level when charging
                    if isCharging {
                        batteryLevel = min(100, batteryLevel + 10)
                    } else {
                        batteryLevel = 75 // Reset
                    }
                }
            }
        }
    }
}

/// Caps Lock HUD Preview - animated ON/OFF state toggle
struct CapsLockHUDPreview: View {
    @State private var isCapsLockOn = true
    
    // Match real notch dimensions
    private let hudWidth: CGFloat = 280
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var wingWidth: CGFloat { (hudWidth - notchWidth) / 2 }
    
    private var capsLockIcon: String {
        isCapsLockOn ? "capslock.fill" : "capslock"
    }
    
    private var accentColor: Color {
        isCapsLockOn ? .green : .white
    }
    
    var body: some View {
        ZStack {
            // Notch background with proper rounded corners
            NotchShape(bottomRadius: 16)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight)
                .overlay(
                    NotchShape(bottomRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            // Wings: Caps Lock (left) | Camera Gap | ON/OFF (right)
            HStack(spacing: 0) {
                // Left wing - Caps Lock icon with animation
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: capsLockIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.pulse, options: .repeating, isActive: isCapsLockOn)
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
                
                // Camera notch gap
                Spacer().frame(width: notchWidth)
                
                // Right wing - ON/OFF text
                HStack {
                    Spacer(minLength: 0)
                    Text(isCapsLockOn ? "ON" : "OFF")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .contentTransition(.interpolate)
                    Spacer(minLength: 0)
                }
                .frame(width: wingWidth)
            }
            .frame(width: hudWidth, height: notchHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            // Animate ON/OFF state
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isCapsLockOn.toggle()
                }
            }
        }
    }
}

/// Floating Basket Preview - realistic mock matching FloatingBasketView
struct FloatingBasketPreview: View {
    @State private var dashPhase: CGFloat = 0
    
    private let cornerRadius: CGFloat = 20
    private let previewWidth: CGFloat = 220
    private let previewHeight: CGFloat = 150
    private let insetPadding: CGFloat = 20 // Symmetrical padding from dotted border
    
    var body: some View {
        ZStack {
                // Background with animated dashed border
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius - 10, style: .continuous)
                            .stroke(
                                Color.white.opacity(0.2),
                                style: StrokeStyle(
                                    lineWidth: 1.5,
                                    lineCap: .round,
                                    dash: [6, 8],
                                    dashPhase: dashPhase
                                )
                            )
                            .padding(10)
                    )
                
                // Content - symmetrical padding from dotted border
                VStack(spacing: 10) {
                    // Header - moved up for symmetry
                    HStack(spacing: 8) {
                        Text("3 items")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // To Shelf button - single line
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.to.line")
                                .font(.system(size: 8, weight: .bold))
                            Text("To Shelf")
                                .font(.system(size: 8, weight: .semibold))
                                .fixedSize() // Prevent wrapping
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        // Clear button
                        Image(systemName: "eraser.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Mock items grid - centered
                    HStack(spacing: 12) {
                        MockFileItem(icon: "doc.fill", color: .blue, name: "Document")
                        MockFileItem(icon: "photo.fill", color: .purple, name: "Image.png")
                        MockFileItem(icon: "folder.fill", color: .cyan, name: "Folder")
                    }
                }
                .padding(insetPadding) // Symmetrical padding on all sides
            }
            .frame(width: previewWidth, height: previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            // Dashed border animation
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                dashPhase -= 280
            }
        }
    }
}

/// Animated preview demonstrating the Auto-Hide Peek feature
struct PeekPreview: View {
    let edge: String
    
    @State private var isPeeking = false
    @State private var dashPhase: CGFloat = 0
    
    private let containerWidth: CGFloat = 280
    private let containerHeight: CGFloat = 100
    private let basketWidth: CGFloat = 100
    private let basketHeight: CGFloat = 70
    private let peekAmount: CGFloat = 20 // How much stays visible
    
    var body: some View {
        ZStack {
            // Container representing the screen
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.12))
                .overlay(
                    Text("Screen")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.quaternary)
                        .padding(.leading, 8)
                        .padding(.top, 6)
                    , alignment: .topLeading
                )
            
            // Mini basket that peeks
            miniBasket
                .offset(basketOffset)
                .rotation3DEffect(
                    .degrees(isPeeking ? rotationAngle : 0),
                    axis: rotationAxis,
                    perspective: 0.5
                )
                .scaleEffect(isPeeking ? 0.92 : 1.0)
                .animation(.easeInOut(duration: isPeeking ? 0.55 : 0.25), value: isPeeking)
        }
        .frame(width: containerWidth, height: containerHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .onAppear {
            // Delay initial start
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                startAnimationCycle()
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                dashPhase -= 280
            }
        }
        .onChange(of: edge) { _, _ in
            isPeeking = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startAnimationCycle()
            }
        }
    }
    
    private let miniBasketScale: CGFloat = 0.5
    
    private var miniBasket: some View {
        ZStack {
            // Background with animated dashed border
            RoundedRectangle(cornerRadius: 20 * miniBasketScale, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 12 * miniBasketScale, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.2),
                            style: StrokeStyle(
                                lineWidth: 1.5 * miniBasketScale,
                                lineCap: .round,
                                dash: [6 * miniBasketScale, 8 * miniBasketScale],
                                dashPhase: dashPhase * miniBasketScale
                            )
                        )
                        .padding(10 * miniBasketScale)
                )
            
            // Content - matching real basket layout
            VStack(spacing: 6 * miniBasketScale) {
                // Header row
                HStack(spacing: 4 * miniBasketScale) {
                    Text("3 items")
                        .font(.system(size: 10 * miniBasketScale, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // To Shelf button
                    HStack(spacing: 2 * miniBasketScale) {
                        Image(systemName: "arrow.up.to.line")
                            .font(.system(size: 8 * miniBasketScale, weight: .bold))
                        Text("To Shelf")
                            .font(.system(size: 8 * miniBasketScale, weight: .semibold))
                            .fixedSize()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6 * miniBasketScale)
                    .padding(.vertical, 4 * miniBasketScale)
                    .background(Color.blue.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 16 * miniBasketScale, style: .continuous))
                    
                    // Clear button
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 8 * miniBasketScale, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 16 * miniBasketScale, height: 16 * miniBasketScale)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14 * miniBasketScale, style: .continuous))
                }
                
                Spacer(minLength: 0)
                
                // File items grid
                HStack(spacing: 8 * miniBasketScale) {
                    MiniFileItem(icon: "doc.fill", color: .blue, name: "Document", scale: miniBasketScale)
                    MiniFileItem(icon: "photo.fill", color: .purple, name: "Image.png", scale: miniBasketScale)
                    MiniFileItem(icon: "folder.fill", color: .cyan, name: "Folder", scale: miniBasketScale)
                }
            }
            .padding(12 * miniBasketScale)
        }
        .frame(width: basketWidth, height: basketHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20 * miniBasketScale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20 * miniBasketScale, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10 * miniBasketScale, x: 0, y: 5 * miniBasketScale)
    }
    
    private var basketOffset: CGSize {
        if isPeeking {
            switch edge {
            case "left":
                return CGSize(width: -(containerWidth/2 - peekAmount + basketWidth/2), height: 0)
            case "right":
                return CGSize(width: (containerWidth/2 - peekAmount + basketWidth/2), height: 0)
            case "bottom":
                return CGSize(width: 0, height: (containerHeight/2 - peekAmount + basketHeight/2))
            default:
                return CGSize(width: (containerWidth/2 - peekAmount + basketWidth/2), height: 0)
            }
        } else {
            return .zero
        }
    }
    
    private var rotationAngle: Double {
        // Match real peek: ~10 degrees (0.18 radians ≈ 10.3°)
        switch edge {
        case "left": return 10
        case "right": return -10
        case "bottom": return 10
        default: return -10
        }
    }
    
    private var rotationAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        switch edge {
        case "left", "right": return (x: 0, y: 1, z: 0)
        case "bottom": return (x: 1, y: 0, z: 0)
        default: return (x: 0, y: 1, z: 0)
        }
    }
    
    private func startAnimationCycle() {
        // Step 1: Slide to peek position (0.55s - matches real)
        isPeeking = true
        
        // Step 2: Stay peeking for 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            // Step 3: Reveal back (0.25s - matches real)
            isPeeking = false
            
            // Step 4: Stay visible for 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                // Step 5: Wait 4 more seconds before repeating
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    startAnimationCycle()
                }
            }
        }
    }
}

/// Scaled file item for PeekPreview mini basket
private struct MiniFileItem: View {
    let icon: String
    let color: Color
    let name: String
    let scale: CGFloat
    
    var body: some View {
        VStack(spacing: 4 * scale) {
            Image(systemName: icon)
                .font(.system(size: 22 * scale))
                .foregroundStyle(color)
                .frame(width: 44 * scale, height: 44 * scale)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
            
            Text(name)
                .font(.system(size: 7 * scale))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Mock file item for basket and shelf previews
private struct MockFileItem: View {
    let icon: String
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            Text(name)
                .font(.system(size: 7))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Notch Shelf Preview - realistic mock matching NotchShelfView expanded state
struct NotchShelfPreview: View {
    @State private var dashPhase: CGFloat = 0
    @State private var bounce = false
    
    // Notch dimensions
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    private let shelfWidth: CGFloat = 280
    private let shelfHeight: CGFloat = 70
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Expanded shelf background with NotchShape
                NotchShape(bottomRadius: 16)
                    .fill(Color.black)
                    .frame(width: shelfWidth, height: shelfHeight)
                    .overlay(
                        // BLUE marching ants - matches real drag indicator
                        NotchShape(bottomRadius: 12)
                            .stroke(
                                Color.blue,
                                style: StrokeStyle(
                                    lineWidth: 2,
                                    lineCap: .round,
                                    dash: [6, 8],
                                    dashPhase: dashPhase
                                )
                            )
                            .padding(8)
                    )
                    .overlay(
                        NotchShape(bottomRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                // REAL "Drop!" indicator - exact copy from NotchShelfView.dropIndicatorContent
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: notchHeight)
                    
                    // Real drop indicator content
                    HStack(spacing: 8) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white, .green)
                            .symbolEffect(.bounce, value: bounce)
                        
                        Text("Drop!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    )
                    
                    Spacer()
                }
            }
            .frame(width: shelfWidth, height: shelfHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            // Blue marching ants animation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                dashPhase -= 280
            }
            // Bounce animation for icon
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                bounce = true
            }
        }
    }
}

/// Mock shelf item (smaller than basket items)
private struct MockShelfItem: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Open Shelf Indicator Preview - REAL component from NotchShelfView
struct OpenShelfIndicatorPreview: View {
    @State private var bounce = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white, .blue)
                .symbolEffect(.bounce, value: bounce)
            
            Text("Open Shelf")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                bounce = true
            }
        }
    }
}

/// Drop Indicator Preview - REAL component from NotchShelfView
struct DropIndicatorPreview: View {
    @State private var bounce = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white, .green)
                .symbolEffect(.bounce, value: bounce)
            
            Text("Drop!")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                bounce = true
            }
        }
    }
}

