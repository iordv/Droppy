import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var selectedTab: String? = "General"
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @AppStorage("enableNotchShelf") private var enableNotchShelf = true
    @AppStorage("enableFloatingBasket") private var enableFloatingBasket = true
    @AppStorage("showClipboardButton") private var showClipboardButton = false
    @AppStorage("showOpenShelfIndicator") private var showOpenShelfIndicator = true
    @AppStorage("showDropIndicator") private var showDropIndicator = true
    @AppStorage("hideNotchOnExternalDisplays") private var hideNotchOnExternalDisplays = false
    
    // HUD and Media Player settings
    @AppStorage("enableHUDReplacement") private var enableHUDReplacement = true
    @AppStorage("enableBatteryHUD") private var enableBatteryHUD = true  // Enabled by default
    @AppStorage("showMediaPlayer") private var showMediaPlayer = true
    @AppStorage("autoFadeMediaHUD") private var autoFadeMediaHUD = true
    @AppStorage("debounceMediaChanges") private var debounceMediaChanges = false  // Delay media HUD for rapid changes
    @AppStorage("autoShrinkShelf") private var autoShrinkShelf = true
    @AppStorage("autoShrinkDelay") private var autoShrinkDelay = 3  // Seconds (1-10)


    
    @State private var dashPhase: CGFloat = 0
    @State private var isHistoryLimitEditing: Bool = false
    @State private var isUpdateHovering = false
    
    // Hover states for sidebar items
    @State private var hoverGeneral = false
    @State private var hoverClipboard = false
    @State private var hoverDisplay = false
    @State private var hoverAccessibility = false
    @State private var hoverAbout = false
    @State private var isCoffeeHovering = false
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            NavigationSplitView {
                VStack(spacing: 6) {
                    sidebarButton(title: "General", icon: "gear", tag: "General", isHovering: $hoverGeneral)
                    sidebarButton(title: "Clipboard", icon: "doc.on.clipboard", tag: "Clipboard", isHovering: $hoverClipboard)
                    sidebarButton(title: "Display", icon: "display", tag: "Display", isHovering: $hoverDisplay)
                    sidebarButton(title: "Accessibility", icon: "accessibility", tag: "Accessibility", isHovering: $hoverAccessibility)
                    sidebarButton(title: "About Droppy", icon: "info.circle", tag: "About Droppy", isHovering: $hoverAbout)
                    
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
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                        if selectedTab == "General" {
                            generalSettings
                        } else if selectedTab == "Clipboard" {
                            clipboardSettings
                        } else if selectedTab == "Display" {
                            displaySettings
                        } else if selectedTab == "Accessibility" {
                            accessibilitySettings
                        } else if selectedTab == "About Droppy" {
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selectedTab == tag 
                          ? Color.blue.opacity(isHovering.wrappedValue ? 1.0 : 0.8) 
                          : Color.white.opacity(isHovering.wrappedValue ? 0.15 : 0.08))
            )
            .foregroundStyle(selectedTab == tag ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
    
    private var generalSettings: some View {
        Group {
            // MARK: System Section
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
                Text("System")
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
                    FeaturePreviewGIF(url: "https://i.postimg.cc/jqkPwkRp/Schermopname2026-01-05om22-04-43-ezgif-com-video-to-gif-converter.gif")
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
                    FeaturePreviewGIF(url: "https://i.postimg.cc/dtHH09fB/Schermopname2026-01-05om22-01-22-ezgif-com-video-to-gif-converter.gif")
                }
            } header: {
                Text("Drop Zones")
            } footer: {
                Text("Enable one or both drop zones to hold files temporarily.")
            }
        }
    }
    
    private var displaySettings: some View {
        Group {
            // MARK: Appearance
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
            } header: {
                Text("Appearance")
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
                        FeaturePreviewGIF(url: "https://i.postimg.cc/SKjDMGrP/Schermopname2026-01-07om15-17-29-ezgif-com-video-to-gif-converter.gif")
                        
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
                Text("Media Player")
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
                    FeaturePreviewGIF(url: "https://i.postimg.cc/qqQ3wPMV/Schermopname2026-01-07om15-20-48-ezgif-com-video-to-gif-converter.gif")
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
                    FeaturePreviewGIF(url: "https://i.postimg.cc/Fznd6bvv/Schermopname2026-01-07om22-36-08-ezgif-com-video-to-gif-converter.gif")
                }
            } header: {
                Text("System HUD")
            } footer: {
                Text("Requires Accessibility permissions to intercept media keys.")
            }
        }
    }
    
    private var accessibilitySettings: some View {
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
                    FeaturePreviewImage(url: "https://i.postimg.cc/8CcLwcLd/image.png")
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
                    FeaturePreviewImage(url: "https://i.postimg.cc/RhL3vxcz/image.png")
                }
            } header: {
                Text("Interface Helpers")
            } footer: {
                Text("Show or hide visual hints and quick-access buttons.")
            }
        }
    }
    
    

    
    private var aboutSettings: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Droppy")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Version \(UpdateChecker.shared.currentVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
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
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                    // Check for Accessibility Permissions
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                    let isTrusted = AXIsProcessTrustedWithOptions(options)
                    
                    if !isTrusted {
                        // User needs to approve. 
                        // The system prompt appears automatically due to options above.
                        // We can also show a helper alert if needed, but system prompt is standard.
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
                FeaturePreviewGIF(url: "https://i.postimg.cc/Kvc9c2Kr/Schermopname2026-01-06om18-05-02-ezgif-com-video-to-gif-converter.gif")
                
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
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("History Limit")
                        Text("Number of items to keep in history")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    HStack(spacing: 0) {
                        AutoSelectNumberField(value: $clipboardHistoryLimit, isEditing: $isHistoryLimitEditing)
                            .frame(width: 60, height: 24)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        Color.accentColor.opacity(isHistoryLimitEditing ? 0.8 : 0),
                                        style: StrokeStyle(
                                            lineWidth: 1.5,
                                            lineCap: .round,
                                            dash: [3, 3],
                                            dashPhase: dashPhase
                                        )
                                    )
                            )
                            .onAppear {
                                withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                                    dashPhase = 6
                                }
                            }
                    }
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
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
/// Checks GIFPreloader's cache first for instant display in Settings
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
        
        // INSTANT: Check if image is already pre-loaded in cache
        if let cachedImage = GIFPreloader.shared.getCachedImage(for: url) {
            imageView.image = cachedImage
        } else {
            // Fallback: Load GIF data asynchronously (for non-preloaded images)
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

// MARK: - GIF Pre-loader
/// Pre-loads all feature preview GIFs at app launch so they're instantly ready in Settings
/// Maintains an in-memory NSImage cache for zero-latency display
class GIFPreloader {
    static let shared = GIFPreloader()
    
    /// Thread-safe image cache (URL string -> decoded NSImage)
    private var imageCache: [String: NSImage] = [:]
    private let cacheLock = NSLock()
    
    /// All preview GIF URLs (MUST match URLs in SettingsView)
    private let gifURLs = [
        // Notch Shelf
        "https://i.postimg.cc/jqkPwkRp/Schermopname2026-01-05om22-04-43-ezgif-com-video-to-gif-converter.gif",
        // Floating Basket
        "https://i.postimg.cc/dtHH09fB/Schermopname2026-01-05om22-01-22-ezgif-com-video-to-gif-converter.gif",
        // Media Player
        "https://i.postimg.cc/SKjDMGrP/Schermopname2026-01-07om15-17-29-ezgif-com-video-to-gif-converter.gif",
        // HUDs
        "https://i.postimg.cc/qqQ3wPMV/Schermopname2026-01-07om15-20-48-ezgif-com-video-to-gif-converter.gif",
        // Clipboard Manager (CRITICAL: was missing!)
        "https://i.postimg.cc/Kvc9c2Kr/Schermopname2026-01-06om18-05-02-ezgif-com-video-to-gif-converter.gif"
    ]
    
    private init() {}
    
    /// Retrieve a pre-loaded image from cache (instant, no network)
    func getCachedImage(for urlString: String) -> NSImage? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return imageCache[urlString]
    }
    
    /// Call this at app launch to pre-fetch and decode all GIFs into memory
    func preloadAll() {
        for urlString in gifURLs {
            guard let url = URL(string: urlString) else { continue }
            
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self, let data = data else { return }
                
                // Decode image on background thread
                if let image = NSImage(data: data) {
                    self.cacheLock.lock()
                    self.imageCache[urlString] = image
                    self.cacheLock.unlock()
                }
                
                // Also store in URLCache as a backup
                if let response = response {
                    let cachedResponse = CachedURLResponse(response: response, data: data)
                    URLCache.shared.storeCachedResponse(cachedResponse, for: request)
                }
            }.resume()
        }
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
