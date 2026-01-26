//
//  MenuBarManagerInfoView.swift
//  Droppy
//
//  Menu Bar Manager configuration view
//

import SwiftUI

struct MenuBarManagerInfoView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @StateObject private var manager = MenuBarManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    @State private var isHoveringClose = false
    @State private var isHoveringEnable = false
    @State private var showReviewsSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed, non-scrolling)
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Features section
                    featuresSection
                    
                    // Enable section (when disabled)
                    if !manager.isEnabled {
                        enableSection
                    }
                    
                    // Usage instructions (when enabled)
                    if manager.isEnabled {
                        usageSection
                        
                        // Discovered items section
                        discoveredItemsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons (fixed, non-scrolling)
            buttonSection
        }
        .frame(width: 540)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .menuBarManager)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon from remote URL
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/menu-bar-manager.jpg")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
            
            Text("Menu Bar Manager")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            // Stats row
            HStack(spacing: 12) {
                // Installs
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
                // Rating (clickable)
                Button {
                    showReviewsSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption.weight(.medium))
                            Text("(\(r.ratingCount))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("–")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(DroppySelectableButtonStyle(isSelected: false))
                
                // Category badge
                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    )
            }
            
            Text("Clean up your menu bar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hide unused menu bar icons and reveal them with a click. Keep your menu bar clean and organized.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "menubar.rectangle", text: "Hide/show menu bar icons")
                featureRow(icon: "chevron.compact.right", text: "Click divider to expand/collapse")
                featureRow(icon: "hand.draw", text: "Hold ⌘ + drag icons to far left to hide")
                featureRow(icon: "arrow.left.arrow.right", text: "Rearrange by holding ⌘ and dragging")
            }
            
            // Screenshot
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/screenshots/menu-bar-manager.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            } placeholder: {
                EmptyView()
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var enableSection: some View {
        VStack(spacing: 16) {
            Text("Enable Menu Bar Manager to get started")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("A divider will appear in your menu bar. Click it to show/hide icons to its left.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                manager.enable()
                
                // Track activation
                AnalyticsService.shared.trackExtensionActivation(extensionId: "menuBarManager")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                    Text("Enable")
                }
            }
            .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .medium))
        }
        .padding(20)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Menu Bar Manager is active")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                instructionRow(step: "1", text: "Click the chevron ( › ) to expand and show all icons")
                instructionRow(step: "2", text: "Hold ⌘ and drag icons ALL THE WAY to the far left edge")
                instructionRow(step: "3", text: "Release — icons left of the chevron are now hidden")
                instructionRow(step: "4", text: "Click the chevron anytime to show/hide them")
            }
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Right-click the chevron for more options")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func instructionRow(step: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                Text(step)
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Discovered Items Section
    
    private var discoveredItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Menu Bar Items")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    manager.refreshDiscoveredItems()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(DroppySelectableButtonStyle(isSelected: false))
                .help("Refresh item list")
            }
            
            if manager.discoveredItems.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("No menu bar items discovered")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(manager.discoveredItems, id: \.id) { item in
                        MenuBarItemRow(item: item, manager: manager)
                        
                        if item.id != manager.discoveredItems.last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            
            // IceBar button
            Button {
                manager.toggleIceBar()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.bottomhalf.filled")
                    Text("Show Hidden Items Bar")
                }
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            .disabled(manager.items(in: .hidden).isEmpty && manager.items(in: .alwaysHidden).isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            DisableExtensionButton(extensionType: .menuBarManager)
        }
        .padding(16)
    }
}

// MARK: - Menu Bar Item Row

struct MenuBarItemRow: View {
    let item: MenuBarItem
    let manager: MenuBarManager
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon or placeholder
            Group {
                if let icon = item.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 24, height: 24)
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                
                Text(item.ownerName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Section picker
            Picker("", selection: Binding(
                get: { item.section },
                set: { manager.setItemSection(item.id, section: $0) }
            )) {
                ForEach(MenuBarSection.allCases) { section in
                    Label(section.displayName, systemImage: section.icon)
                        .tag(section)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 130)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
