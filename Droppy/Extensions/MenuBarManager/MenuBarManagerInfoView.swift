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
    
    @State private var showReviewsSheet = false
    
    private var panelHeight: CGFloat {
        let availableHeight = NSScreen.main?.visibleFrame.height ?? 800
        return min(760, max(520, availableHeight - 120))
    }
    
    /// Use ExtensionType.isRemoved as single source of truth
    private var isActive: Bool {
        !ExtensionType.menuBarManager.isRemoved && manager.isEnabled
    }
    
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Usage instructions (when enabled)
                    if isActive {
                        usageSection
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Settings section
                        settingsSection
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(width: 450, height: panelHeight)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .menuBarManager)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon from remote URL
            CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/menubarmanager.png")) { image in
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
                    Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
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
                .buttonStyle(.plain)
                
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
                featureRow(icon: "eye.fill", text: "Eye icon toggles visibility")
                featureRow(icon: "line.vertical", text: "Separator line shows when icons are hidden")
                featureRow(icon: "hand.raised.fill", text: "Drag icons left of the separator to hide")
                featureRow(icon: "arrow.left.arrow.right", text: "Rearrange by holding ⌘ and dragging")
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Group {
                if NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                } else {
                    Text("|")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(.blue)
            .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
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
                instructionRow(step: "1", text: "Look for the eye icon in your menu bar")
                instructionRow(step: "2", text: "Click it to hide icons — a separator line ( | ) will appear")
                instructionRow(step: "3", text: "Hold ⌘ and drag icons LEFT of the separator to hide them")
            }
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Right-click the eye icon for more options")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            
            // Hover to show toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show on Hover")
                        .font(.callout)
                    Text("Automatically show icons when hovering over the menu bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $manager.showOnHover)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            
            // Hover delay slider (only visible when hover is enabled)
            if manager.showOnHover {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Hover Delay")
                            .font(.callout)
                        Spacer()
                        Text(String(format: "%.1fs", manager.showOnHoverDelay))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $manager.showOnHoverDelay, in: 0.0...2.0, step: 0.1)
                        .sliderHaptics(value: manager.showOnHoverDelay, range: 0.0...2.0)
                        .controlSize(.small)
                }
                .padding(.leading, 4)
            }
            
            Divider()
            
            // Auto-hide delay
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Hide Delay")
                            .font(.callout)
                        Text("Automatically hide after revealing (0 = never)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(manager.autoHideDelay == 0 ? "Off" : String(format: "%.1fs", manager.autoHideDelay))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $manager.autoHideDelay, in: 0.0...5.0, step: 0.5)
                    .sliderHaptics(value: manager.autoHideDelay, range: 0.0...5.0)
                    .controlSize(.small)
            }
            
            Divider()
            
            // Separator is required
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Separator")
                        .font(.callout)
                    Text("Required for hiding and revealing menu bar icons")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Always On")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Icon picker
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Toggle Icon")
                        .font(.callout)
                    Spacer()
                    Toggle("Gradient", isOn: $manager.useGradientIcon)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    Text("Gradient")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Icon options in a grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                    ForEach(MBMIconSet.allCases) { iconSet in
                        iconOption(iconSet)
                    }
                }
            }
            
            Divider()
            
            // Item spacing
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu Bar Spacing")
                            .font(.callout)
                        Text("Adjust spacing between all menu bar items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(manager.itemSpacingOffset > 0 ? "+" : "")\(manager.itemSpacingOffset)pt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                
                HStack {
                    Slider(value: Binding(
                        get: { Double(manager.itemSpacingOffset) },
                        set: { manager.itemSpacingOffset = Int($0) }
                    ), in: -8...8, step: 1)
                        .sliderHaptics(value: Double(manager.itemSpacingOffset), range: -8...8)
                        .controlSize(.small)
                    
                    Button {
                        Task {
                            await manager.applyItemSpacing()
                        }
                    } label: {
                        if manager.isApplyingSpacing {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 50)
                        } else {
                            Text("Apply")
                        }
                    }
                    .droppyAccentButton(color: .blue, size: .small)
                    .disabled(manager.isApplyingSpacing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }
    
    private func iconOption(_ iconSet: MBMIconSet) -> some View {
        let isSelected = manager.iconSet == iconSet
        
        return Button {
            manager.iconSet = iconSet
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Image(systemName: iconSet.visibleSymbol)
                        .font(.system(size: 14, weight: .medium))
                    Image(systemName: iconSet.hiddenSymbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(iconSet.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.blue : AdaptiveColors.overlayAuto(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func instructionRow(step: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var buttonSection: some View {
        HStack {
            Button("Close") { dismiss() }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            if isActive {
                DisableExtensionButton(extensionType: .menuBarManager)
            } else {
                Button {
                    // Enable via ExtensionType and manager
                    ExtensionType.menuBarManager.setRemoved(false)
                    manager.isEnabled = true
                    AnalyticsService.shared.trackExtensionActivation(extensionId: "menuBarManager")
                    NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.menuBarManager)
                } label: {
                    Text("Enable")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
            }
        }
        .padding(DroppySpacing.lg)
    }
}
