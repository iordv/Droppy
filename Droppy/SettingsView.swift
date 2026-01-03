import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var selectedTab: String? = "General"
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    // Beta feature removed - Jiggle is now standard
    // @AppStorage("showFloatingBasket") private var showFloatingBasket = false

    
    // Background Hover Effect State
    @State private var hoverLocation: CGPoint = .zero
    @State private var isHovering: Bool = false
    
    var body: some View {
        ZStack {
            // Interactive background effect
            HexagonDotsEffect(
                mouseLocation: hoverLocation,
                isHovering: isHovering,
                coordinateSpaceName: "settingsView"
            )
            
            NavigationSplitView {
                List(selection: $selectedTab) {
                    Label("General", systemImage: "gear")
                        .tag("General")
                    Label("Display", systemImage: "display")
                        .tag("Display")
                    Label("What's New", systemImage: "sparkles")
                        .tag("Changelog")
                    Label("About Droppy", systemImage: "info.circle")
                        .tag("About Droppy")
                }
                .navigationTitle("Settings")
                // Fix: Use compatible background modifer
                .background(Color.clear) 
            } detail: {
                Form {
                    if selectedTab == "General" {
                        generalSettings
                    } else if selectedTab == "Display" {
                        displaySettings
                    } else if selectedTab == "Changelog" {
                        changelogSettings
                    } else if selectedTab == "About Droppy" {
                        aboutSettings
                    }
                }
                .formStyle(.grouped)
                // Fix: Use compatible background modifier
                .background(Color.clear)
            }
        }
        .coordinateSpace(name: "settingsView")
        // Fix: Replace visionOS glassEffect with macOS material
        .background(.ultraThinMaterial)
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
        } header: {
            Text("General")
        } footer: {
            Text("Basic settings for the application.")
        }
    }
    
    private var displaySettings: some View {
        Section {
            Toggle(isOn: $useTransparentBackground) {
                VStack(alignment: .leading) {
                    Text("Transparent Background")
                    Text("Make the shelf and notch transparent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Display")
        }
    }
    
    private var changelogSettings: some View {
        Section {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "party.popper.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.purple.gradient)
                    VStack(alignment: .leading) {
                        Text("Welcome to Droppy 2.0")
                            .font(.title2.bold())
                        Text("A huge update with powerful new workflows.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 10)
                
                // Feature 1: The Basket
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "basket.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The Floating Basket")
                            .font(.headline)
                        Text("Jiggle your mouse while dragging files to summon a temporary drop zone right where you are. Drag files in, drag them out, or push them to the shelf.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Feature 2: Auto-Rename
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "pencil.line")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Zipping")
                            .font(.headline)
                        Text("Create ZIP files instantly. New archives automatically enter rename mode so you can label them immediately.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Feature 3: OCR & Conversion
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Text Extraction & Conversion")
                            .font(.headline)
                        Text("Right-click any image or PDF to extract text using OCR, or convert images to different formats (PNG, JPEG, HEIC, etc.) on the fly.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Feature 4: Sonoma Ready
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "macwindow")
                        .font(.title3)
                        .foregroundStyle(.pink)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Refined for Sonoma")
                            .font(.headline)
                        Text("Smoother animations, glass materials, and full compatibility with macOS 14+.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("What's New in v2.0")
        } footer: {
            Text("Enjoy the new update!")
        }
    }
    
    private var aboutSettings: some View {
        Section {
            HStack {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.gradient)
                
                VStack(alignment: .leading) {
                    Text("Droppy")
                        .font(.headline)
                    Text("Version \(UpdateChecker.shared.currentVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            
            LabeledContent("Developer", value: "Jordy Spruit")
            
            Button {
                UpdateChecker.shared.checkAndNotify()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Check for Updates")
                }
            }
        } header: {
            Text("About")
        }
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
