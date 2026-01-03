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
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.purple.gradient)
                    Text("Latest Updates")
                        .font(.headline)
                }
                .padding(.bottom, 4)
                
                // Dynamic Content from Release Script
                ForEach(ChangelogData.current.split(separator: "\n"), id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        Text(String(line))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)

                // Keep the 2.0 Highlight as a "Featured" section
                Group {
                    Text("Highlights from 2.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Label("Floating Basket", systemImage: "basket.fill")
                    Label("Smart Zipping & Rename", systemImage: "pencil.line")
                    Label("Text Extraction (OCR)", systemImage: "doc.text.viewfinder")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        } header: {
            Text("What's New")
        }
    }
}

struct ChangelogData {
    static let current = """
    Fixed: App quitting when closing Settings window
    Fixed: Crash when moving basket during animation
    Fixed: Window memory management stability improvements
    """
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
