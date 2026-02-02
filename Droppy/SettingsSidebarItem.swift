//
//  SettingsSidebarItem.swift
//  Droppy
//
//  Professional macOS System Settings-inspired sidebar components
//

import SwiftUI

// MARK: - Settings Tab Definition

/// Represents a settings tab with its icon, color, and title
enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case shelf = "Shelf"
    case basket = "Basket"
    case clipboard = "Clipboard"
    case huds = "HUDs"
    case extensions = "Extensions"
    case quickshare = "Quickshare"  // Conditional: shown when enabled in settings
    case accessibility = "Accessibility"
    case about = "About"
    
    var id: String { rawValue }
    
    var title: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .shelf: return "star.fill"
        case .basket: return "tray.fill"
        case .clipboard: return "clipboard.fill"
        case .huds: return "dial.medium.fill"
        case .extensions: return "puzzlepiece.extension.fill"
        case .quickshare: return "drop.fill"
        case .accessibility: return "accessibility"
        case .about: return "info.circle.fill"
        }
    }
    
    /// Primary badge color (used for gradient base)
    var badgeColor: Color {
        switch self {
        case .general: return Color(hue: 0, saturation: 0, brightness: 0.50) // Gray
        case .shelf: return Color(hue: 0.08, saturation: 0.80, brightness: 0.98) // Orange
        case .basket: return Color(hue: 0.80, saturation: 0.60, brightness: 0.85) // Purple
        case .clipboard: return Color(hue: 0.58, saturation: 0.70, brightness: 0.95) // Blue
        case .huds: return Color(hue: 0.50, saturation: 0.70, brightness: 0.90) // Teal/Cyan
        case .extensions: return Color(hue: 0.38, saturation: 0.65, brightness: 0.80) // Green
        case .quickshare: return Color(hue: 0.52, saturation: 0.80, brightness: 0.95) // Cyan
        case .accessibility: return Color(hue: 0.58, saturation: 0.70, brightness: 0.95) // Blue
        case .about: return Color(hue: 0.58, saturation: 0.70, brightness: 0.95) // Blue
        }
    }
    
    /// Secondary badge color for gradient (slightly darker/more saturated)
    var badgeColorSecondary: Color {
        switch self {
        case .general: return Color(hue: 0, saturation: 0, brightness: 0.35) // Darker Gray
        case .shelf: return Color(hue: 0.06, saturation: 0.90, brightness: 0.85) // Deeper Orange
        case .basket: return Color(hue: 0.78, saturation: 0.75, brightness: 0.70) // Deeper Purple
        case .clipboard: return Color(hue: 0.60, saturation: 0.85, brightness: 0.80) // Deeper Blue
        case .huds: return Color(hue: 0.52, saturation: 0.85, brightness: 0.75) // Deeper Teal
        case .extensions: return Color(hue: 0.36, saturation: 0.80, brightness: 0.65) // Deeper Green
        case .quickshare: return Color(hue: 0.54, saturation: 0.90, brightness: 0.75) // Deeper Cyan
        case .accessibility: return Color(hue: 0.60, saturation: 0.85, brightness: 0.80) // Deeper Blue
        case .about: return Color(hue: 0.60, saturation: 0.85, brightness: 0.80) // Deeper Blue
        }
    }
    
    /// Gradient for the icon badge (top-light to bottom-dark like macOS)
    var badgeGradient: LinearGradient {
        LinearGradient(
            colors: [badgeColor, badgeColorSecondary],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Section header this tab belongs to (nil for items without section header above them)
    var sectionHeader: String? {
        switch self {
        case .general: return nil
        case .shelf: return "Features"
        case .basket, .clipboard: return nil // Same section as Shelf
        case .huds: return "System"
        case .extensions: return "Other"
        case .quickshare: return nil // Same section as Extensions (conditional)
        case .accessibility, .about: return nil // Same section as Extensions
        }
    }
    
    /// Whether this tab is conditionally shown based on user preferences
    var isConditional: Bool {
        switch self {
        case .quickshare: return true
        default: return false
        }
    }
}

// MARK: - Sidebar Section Header

/// Gray section header text for sidebar groupings
struct SettingsSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary.opacity(0.7))
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
}

// MARK: - Sidebar Item

/// A single sidebar item with colored icon badge
struct SettingsSidebarItem: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Colored icon badge
                iconBadge
                
                // Title
                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.85))
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(backgroundShape)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private var iconBadge: some View {
        ZStack {
            // Squircle gradient background
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tab.badgeGradient)
                .frame(width: 28, height: 28)
            
            // Subtle inner highlight at top for 3D effect
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 28, height: 28)
            
            // Icon with subtle shadow
            Image(systemName: tab.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
        }
    }
    
    @ViewBuilder
    private var backgroundShape: some View {
        if isSelected {
            // Squircle selection (like Dynamic Island)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.15))
        } else if isHovering {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        } else {
            Color.clear
        }
    }
}

// MARK: - Complete Sidebar

/// The complete settings sidebar with sections and items
struct SettingsSidebar: View {
    @Binding var selectedTab: SettingsTab
    
    /// Preference for showing Quickshare in sidebar
    @AppStorage(AppPreferenceKey.showQuickshareInSidebar) private var showQuickshareInSidebar = PreferenceDefault.showQuickshareInSidebar
    
    /// Tabs to show, filtering out conditional tabs based on preferences
    private var visibleTabs: [SettingsTab] {
        SettingsTab.allCases.filter { tab in
            switch tab {
            case .quickshare:
                return showQuickshareInSidebar
            default:
                return true
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(visibleTabs) { tab in
                // Section header if this tab starts a new section
                if let header = tab.sectionHeader {
                    SettingsSectionHeader(title: header)
                }
                
                SettingsSidebarItem(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }
            
            Spacer()
            
            // Support button at bottom
            supportButton
            
            // Update button at bottom
            updateButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(minWidth: 200)
    }
    
    private var supportButton: some View {
        Link(destination: URL(string: "https://buymeacoffee.com/droppy")!) {
            HStack(spacing: 10) {
                // Premium gradient icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hue: 0.08, saturation: 0.80, brightness: 0.98),
                                    Color(hue: 0.06, saturation: 0.90, brightness: 0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
                }
                
                Text("Support")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.85))
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(SettingsSidebarLinkStyle())
    }
    
    private var updateButton: some View {
        Button {
            UpdateChecker.shared.checkAndNotify()
        } label: {
            HStack(spacing: 10) {
                // Premium gradient icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hue: 0.38, saturation: 0.65, brightness: 0.80),
                                    Color(hue: 0.36, saturation: 0.80, brightness: 0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 0.5)
                }
                
                Text("Updates")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.85))
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(SettingsSidebarLinkStyle())
    }
}

// MARK: - Sidebar Link Style

/// Button style for sidebar links (Support, Update)
struct SettingsSidebarLinkStyle: ButtonStyle {
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(hoverBackground)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
    }
    
    @ViewBuilder
    private var hoverBackground: some View {
        if isHovering {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        } else {
            Color.clear
        }
    }
}

// MARK: - Accent Color

extension Color {
    /// The accent color used for toggles and interactive elements (standard blue)
    static let droppyAccent = Color.accentColor
}

// MARK: - Preview

#Preview("Settings Sidebar") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        SettingsSidebar(selectedTab: .constant(.general))
            .frame(width: 220)
    }
}
