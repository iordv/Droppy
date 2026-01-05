import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var selectedTab: String? = "General"
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @AppStorage("enableNotchShelf") private var enableNotchShelf = true
    @AppStorage("enableFloatingBasket") private var enableFloatingBasket = true
    @AppStorage("hideNotchOnExternalDisplays") private var hideNotchOnExternalDisplays = false
    
    // HUD and Media Player settings
    @AppStorage("enableHUDReplacement") private var enableHUDReplacement = true
    @AppStorage("showMediaPlayer") private var showMediaPlayer = true
    @AppStorage("autoFadeMediaHUD") private var autoFadeMediaHUD = true


    
    // Background Hover Effect State
    @State private var hoverLocation: CGPoint = .zero
    @State private var isHovering: Bool = false
    
    @State private var dashPhase: CGFloat = 0
    @State private var isHistoryLimitEditing: Bool = false
    @State private var isUpdateHovering = false
    
    // Hover states for sidebar items
    @State private var hoverGeneral = false
    @State private var hoverClipboard = false
    @State private var hoverDisplay = false
    @State private var hoverAbout = false
    @State private var isCoffeeHovering = false
    
    var body: some View {
        ZStack {
            // Interactive background effect
            HexagonDotsEffect(
                mouseLocation: hoverLocation,
                isHovering: isHovering,
                coordinateSpaceName: "settingsView"
            )
            
            NavigationSplitView {
                VStack(spacing: 6) {
                    sidebarButton(title: "General", icon: "gear", tag: "General", isHovering: $hoverGeneral)
                    sidebarButton(title: "Clipboard", icon: "doc.on.clipboard", tag: "Clipboard", isHovering: $hoverClipboard)
                    sidebarButton(title: "Display", icon: "display", tag: "Display", isHovering: $hoverDisplay)
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
                        .scaleEffect(isUpdateHovering ? 1.02 : 1.0)
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
                .frame(minWidth: 180)
                .background(Color.clear) 
            } detail: {
                Form {
                    if selectedTab == "General" {
                        generalSettings
                    } else if selectedTab == "Clipboard" {
                        clipboardSettings
                    } else if selectedTab == "Display" {
                        displaySettings

                    } else if selectedTab == "About Droppy" {
                        aboutSettings
                    }
                }
                .formStyle(.grouped)
                // Fix: Use compatible background modifier
                .background(Color.clear)
            }
        }
        .onTapGesture {
            isHistoryLimitEditing = false
        }
        .coordinateSpace(name: "settingsView")
        // Fix: Replace visionOS glassEffect with macOS material
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .onContinuousHover(coordinateSpace: .named("settingsView")) { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHovering = true
                }
            case .ended:
                withAnimation(.linear(duration: 0.2)) {
                    isHovering = false
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedTab == tag 
                          ? Color.blue.opacity(0.9) 
                          : Color.white.opacity(isHovering.wrappedValue ? 0.15 : 0.08))
            )
            .foregroundStyle(selectedTab == tag ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(selectedTab == tag ? 0.2 : 0.1), lineWidth: 1)
            )
            .scaleEffect(isHovering.wrappedValue ? 1.02 : 1.0)
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
        Section {
            Toggle(isOn: $showInMenuBar) {
                VStack(alignment: .leading) {
                    Text("Menu Bar Icon")
                    Text("Show Droppy in the menu bar")
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
                    Text("Startup")
                    Text("Start automatically at login")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $enableNotchShelf) {
                VStack(alignment: .leading) {
                    Text("Notch Shelf")
                    Text("Show the tray at the top of the screen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: enableNotchShelf) { oldValue, newValue in
                if newValue {
                    NotchWindowController.shared.setupNotchWindow()
                } else {
                    NotchWindowController.shared.closeWindow()
                }
            }
            
            if enableNotchShelf {
                FeaturePreviewGIF(url: "https://i.postimg.cc/jqkPwkRp/Schermopname2026-01-05om22-04-43-ezgif-com-video-to-gif-converter.gif")
            }

            Toggle(isOn: $enableFloatingBasket) {
                VStack(alignment: .leading) {
                    Text("Floating Basket")
                    Text("Show the basket when jiggling files")
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
                FeaturePreviewGIF(url: "https://i.postimg.cc/X7VmqqYM/Schermopname2026-01-05om21-57-55-ezgif-com-video-to-gif-converter.gif")
            }
        } header: {
            Text("General")
        } footer: {
            Text("Basic settings for the application.")
        }
    }
    
    private var displaySettings: some View {
        Group {
            Section {
                Toggle(isOn: $useTransparentBackground) {
                    VStack(alignment: .leading) {
                        Text("Transparent Background")
                        Text("Make the shelf, notch, clipboard and notifications transparent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Toggle(isOn: $hideNotchOnExternalDisplays) {
                    VStack(alignment: .leading) {
                        Text("Hide Notch on External Displays")
                        Text("Don't show the visual notch on non-built-in displays")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Display")
            }
            
            Section {
                Toggle(isOn: $showMediaPlayer) {
                    VStack(alignment: .leading) {
                        Text("Media Player")
                        Text("Show Now Playing controls in the expanded notch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if showMediaPlayer {
                    FeaturePreviewGIF(url: "https://i.postimg.cc/wM52HXm6/Schermopname2026-01-05om21-48-08-ezgif-com-video-to-gif-converter.gif")
                    
                    Toggle(isOn: $autoFadeMediaHUD) {
                        VStack(alignment: .leading) {
                            Text("Auto-Fade Preview")
                            Text("Fade away small preview after 5 seconds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Toggle(isOn: $enableHUDReplacement) {
                    VStack(alignment: .leading) {
                        Text("Replace System HUD")
                        Text("Show volume and brightness changes in the notch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: enableHUDReplacement) { _, newValue in
                    if newValue {
                        // Start interceptor to capture keys and suppress system HUD
                        MediaKeyInterceptor.shared.start()
                    } else {
                        // Stop interceptor, let system handle keys normally
                        MediaKeyInterceptor.shared.stop()
                    }
                }
                
                if enableHUDReplacement {
                    FeaturePreviewGIF(url: "https://i.postimg.cc/hG22QtJ8/Schermopname2026-01-05om19-08-22-ezgif-com-video-to-gif-converter.gif")
                }
            } header: {
                Text("HUD & Media")
            } footer: {
                Text("HUD replacement requires Accessibility permissions to intercept media keys.")
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
                                .scaleEffect(isCoffeeHovering ? 1.02 : 1.0)
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
                FeaturePreviewGIF(url: "https://i.postimg.cc/dtHH09fB/Schermopname2026-01-05om22-01-22-ezgif-com-video-to-gif-converter.gif")
                
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
    @State private var isLoaded = false
    
    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .empty:
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 160)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
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
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .failure:
                EmptyView()
            @unknown default:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoaded)
        .padding(.vertical, 8)
    }
}
