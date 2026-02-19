//
//  SharedComponents.swift
//  Droppy
//
//  Shared UI components used across SettingsView and OnboardingView
//  Consolidated to maintain consistency and reduce code duplication
//

import SwiftUI

// MARK: - Design Constants

/// Centralized design constants for consistent styling
enum DesignConstants {
    static let buttonCornerRadius: CGFloat = 16
    static let innerPreviewRadius: CGFloat = 12
    static let springResponse: Double = 0.25
    static let springDamping: Double = 0.7
    static let bounceResponse: Double = 0.2
    static let bounceDamping: Double = 0.4
}

// MARK: - Centered Toggle Style

/// Custom toggle style that centers the switch vertically with its label
/// Fixes the default SwiftUI behavior where the switch aligns to the top
struct CenteredSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center) {
            configuration.label
            Spacer()
            Toggle("", isOn: configuration.$isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

// MARK: - Legacy OptionButtonStyle removed - all usages migrated to DroppySelectableButtonStyle

/// Reusable HUD toggle button with horizontal layout matching onboarding style
/// Used in both OnboardingView and SettingsView for HUD option grids
struct AnimatedHUDToggle: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var color: Color = .green
    var fixedWidth: CGFloat? = 100  // nil = flexible (fills container)
    
    @State private var iconBounce = false
    @State private var isHovering = false
    
    var body: some View {
        Button {
            // Trigger icon bounce
            withAnimation(DroppyAnimation.bounce) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(DroppyAnimation.stateEmphasis) {
                    iconBounce = false
                    isOn.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                        .fill(isOn ? color.opacity(0.2) : AdaptiveColors.buttonBackgroundAuto)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isOn ? color : .secondary)
                        .scaleEffect(iconBounce ? 1.3 : 1.0)
                        .rotationEffect(.degrees(iconBounce ? -8 : 0))
                }
                .frame(width: 40, height: 40)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isOn ? .primary : .secondary)
                
                Spacer()
                
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? .green : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: fixedWidth)
            .frame(maxWidth: fixedWidth == nil ? .infinity : nil)
            .background((isOn ? AdaptiveColors.buttonBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(isOn ? color.opacity(0.3) : AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovering)
        }
        .buttonStyle(DroppySelectableButtonStyle(isSelected: isOn))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Animated HUD Toggle with Subtitle

/// HUD toggle with subtitle text and icon bounce animation
/// Uses horizontal layout matching other toggle styles
struct AnimatedHUDToggleWithSubtitle: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var color: Color = .pink
    var isEnabled: Bool = true
    
    @State private var iconBounce = false
    @State private var isHovering = false
    
    var body: some View {
        Button {
            guard isEnabled else { return }
            // Trigger icon bounce
            withAnimation(DroppyAnimation.bounce) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(DroppyAnimation.stateEmphasis) {
                    iconBounce = false
                    isOn.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                        .fill(isOn ? color.opacity(0.2) : AdaptiveColors.buttonBackgroundAuto)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isOn ? color : .secondary)
                        .scaleEffect(iconBounce ? 1.3 : 1.0)
                        .rotationEffect(.degrees(iconBounce ? -8 : 0))
                }
                .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isOn ? .primary : .secondary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? .green : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background((isOn ? AdaptiveColors.buttonBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(isOn ? color.opacity(0.3) : AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(isHovering && isEnabled ? 1.02 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovering)
        }
        .buttonStyle(DroppySelectableButtonStyle(isSelected: isOn))
        .contentShape(Rectangle())
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Animated HUD Toggle with Custom Icon View

/// HUD toggle that accepts a custom icon view (for premium animated icons)
/// Uses horizontal layout matching other toggle styles
struct AnimatedHUDToggleWithIconView<Icon: View>: View {
    let icon: Icon
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var color: Color = .green
    var isEnabled: Bool = true
    
    @State private var iconBounce = false
    @State private var isHovering = false
    
    var body: some View {
        Button {
            guard isEnabled else { return }
            withAnimation(DroppyAnimation.bounce) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(DroppyAnimation.stateEmphasis) {
                    iconBounce = false
                    isOn.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                icon
                    .scaleEffect(iconBounce ? 1.15 : 1.0)
                    .rotationEffect(.degrees(iconBounce ? -5 : 0))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isOn ? .primary : .secondary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? .green : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(AdaptiveColors.buttonBackgroundAuto)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(isOn ? color.opacity(0.3) : AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(isHovering && isEnabled ? 1.02 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovering)
        }
        .buttonStyle(DroppySelectableButtonStyle(isSelected: isOn))
        .contentShape(Rectangle())
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Settings Segment Button

/// Segmented button for settings grids - matches target design with cyan accent
/// Label appears below the button, icon/preview inside taller button container
struct SettingsSegmentButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let showsLabel: Bool
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let action: () -> Void
    
    @State private var isHovering = false
    @State private var iconBounce = false
    @Environment(\.controlActiveState) private var controlActiveState
    
    private let accentColor = Color.blue // Droppy blue
    private var hitHeight: CGFloat {
        tileHeight + (showsLabel ? 24 : 0) + 6
    }
    
    init(
        icon: String,
        label: String,
        isSelected: Bool,
        showsLabel: Bool = true,
        tileWidth: CGFloat = 108,
        tileHeight: CGFloat = 46,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.isSelected = isSelected
        self.showsLabel = showsLabel
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.action = action
    }
    
    var body: some View {
        Button {
            withAnimation(DroppyAnimation.bounce) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(DroppyAnimation.stateEmphasis) {
                    iconBounce = false
                    action()
                }
            }
        } label: {
            VStack(spacing: 6) {
                // Button container with icon
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AdaptiveColors.overlayAuto(controlActiveState == .key ? 0.14 : 0.10),
                                    AdaptiveColors.overlayAuto(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: DroppyRadius.medium - 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AdaptiveColors.overlayAuto(isSelected ? 0.08 : 0.04),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(1.5)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isSelected ? accentColor : .secondary)
                        .scaleEffect(iconBounce ? 1.2 : 1.0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(width: tileWidth, height: tileHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(
                            isSelected ? accentColor.opacity(0.95) : AdaptiveColors.overlayAuto(0.12),
                            lineWidth: isSelected ? 1.8 : 1
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium - 1, style: .continuous)
                        .stroke(
                            isSelected ? AdaptiveColors.overlayAuto(0.22) : AdaptiveColors.overlayAuto(0.05),
                            lineWidth: 1
                        )
                        .padding(1)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .padding(6)
                    }
                }
                
                if showsLabel {
                    // Label below button
                    Text(label)
                        .font(.system(size: 11, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: tileWidth)
                }
            }
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovering)
            .frame(width: tileWidth, height: hitHeight, alignment: .top)
            .contentShape(Rectangle())
        }
        .frame(width: tileWidth, height: hitHeight, alignment: .top)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// Segmented button variant that accepts custom content view (for visualizer previews, etc.)
struct SettingsSegmentButtonWithContent<Content: View>: View {
    let content: Content
    let label: String
    let isSelected: Bool
    let showsLabel: Bool
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let action: () -> Void
    
    @State private var isHovering = false
    @State private var iconBounce = false
    @Environment(\.controlActiveState) private var controlActiveState
    
    private let accentColor = Color.blue // Droppy blue
    private var hitHeight: CGFloat {
        tileHeight + (showsLabel ? 24 : 0) + 6
    }
    
    init(
        label: String,
        isSelected: Bool,
        showsLabel: Bool = true,
        tileWidth: CGFloat = 108,
        tileHeight: CGFloat = 46,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.isSelected = isSelected
        self.showsLabel = showsLabel
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button {
            withAnimation(DroppyAnimation.bounce) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(DroppyAnimation.stateEmphasis) {
                    iconBounce = false
                    action()
                }
            }
        } label: {
            VStack(spacing: 6) {
                // Button container with custom content
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AdaptiveColors.overlayAuto(controlActiveState == .key ? 0.14 : 0.10),
                                    AdaptiveColors.overlayAuto(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: DroppyRadius.medium - 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AdaptiveColors.overlayAuto(isSelected ? 0.08 : 0.04),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(1.5)
                    
                    content
                        .scaleEffect(iconBounce ? 1.1 : 1.0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(width: tileWidth, height: tileHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(
                            isSelected ? accentColor.opacity(0.95) : AdaptiveColors.overlayAuto(0.12),
                            lineWidth: isSelected ? 1.8 : 1
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium - 1, style: .continuous)
                        .stroke(
                            isSelected ? AdaptiveColors.overlayAuto(0.22) : AdaptiveColors.overlayAuto(0.05),
                            lineWidth: 1
                        )
                        .padding(1)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .padding(6)
                    }
                }
                
                if showsLabel {
                    // Label below button
                    Text(label)
                        .font(.system(size: 11, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: tileWidth)
                }
            }
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovering)
            .frame(width: tileWidth, height: hitHeight, alignment: .top)
            .contentShape(Rectangle())
        }
        .frame(width: tileWidth, height: hitHeight, alignment: .top)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Settings Visualizer Previews

/// Live preview of mono visualizer bars (animated)
struct VisualizerPreviewMono: View {
    var isSelected: Bool = false
    
    var body: some View {
        AudioSpectrumView(
            isPlaying: true,  // Always animate in preview
            barCount: 5,
            barWidth: 3,
            spacing: 2,
            height: 20,
            color: isSelected ? Color.blue : Color.secondary,
            secondaryColor: nil,
            gradientMode: false
        )
        .frame(width: 5 * 3 + 4 * 2, height: 20)
    }
}

/// Live preview of gradient visualizer bars (animated with bottom-to-top gradient)
struct VisualizerPreviewGradient: View {
    var isSelected: Bool = false
    
    var body: some View {
        // Use vibrant contrasting colors for preview (cyan/magenta)
        let primaryColor = isSelected 
            ? Color(red: 0.9, green: 0.3, blue: 0.6)  // Magenta (bottom)
            : Color(red: 0.55, green: 0.35, blue: 0.45)
        let secondaryColor = isSelected
            ? Color(red: 0.2, green: 0.8, blue: 0.9)  // Cyan (top)
            : Color(red: 0.3, green: 0.5, blue: 0.55)
        
        AudioSpectrumView(
            isPlaying: true,  // Always animate in preview
            barCount: 5,
            barWidth: 3,
            spacing: 2,
            height: 20,
            color: primaryColor,
            secondaryColor: secondaryColor,
            gradientMode: true
        )
        .frame(width: 5 * 3 + 4 * 2, height: 20)
    }
}

// MARK: - Volume & Brightness Toggle



/// Special toggle for Volume/Brightness that morphs between icons on tap
/// Uses horizontal layout matching onboarding style
struct VolumeAndBrightnessToggle: View {
    @Binding var isEnabled: Bool
    
    @State private var showBrightnessIcon = false
    @State private var iconBounce = false
    @State private var isHovering = false
    
    var body: some View {
        Button {
            // Trigger icon morph animation
            withAnimation(DroppyAnimation.bounce) {
                iconBounce = true
                showBrightnessIcon = true
            }
            
            // Switch back to volume after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(DroppyAnimation.stateEmphasis) {
                    showBrightnessIcon = false
                }
            }
            
            // Toggle state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(DroppyAnimation.stateEmphasis) {
                    iconBounce = false
                    isEnabled.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                        .fill(isEnabled ? AdaptiveColors.subtleBorderAuto : AdaptiveColors.buttonBackgroundAuto)
                    
                    ZStack {
                        // Volume icon
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isEnabled ? .primary : .secondary)
                            .opacity(showBrightnessIcon ? 0 : 1)
                            .scaleEffect(showBrightnessIcon ? 0.5 : 1)
                        
                        // Brightness icon (shown briefly on tap)
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isEnabled ? .yellow : .secondary)
                            .opacity(showBrightnessIcon ? 1 : 0)
                            .scaleEffect(showBrightnessIcon ? 1 : 0.5)
                    }
                    .scaleEffect(iconBounce ? 1.3 : 1.0)
                    .rotationEffect(.degrees(iconBounce ? -8 : 0))
                }
                .frame(width: 40, height: 40)
                
                Text("Volume & Brightness")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                
                Spacer()
                
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isEnabled ? .green : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background((isEnabled ? AdaptiveColors.buttonBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(isEnabled ? AdaptiveColors.subtleBorderAuto : AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovering)
        }
        .buttonStyle(DroppySelectableButtonStyle(isSelected: isEnabled))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Display Mode Button

/// Reusable button for Notch/Dynamic Island mode selection
/// Uses horizontal layout matching other toggle styles with icon animations preserved
struct DisplayModeButton<Icon: View>: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let icon: Icon
    let action: () -> Void
    
    @State private var iconBounce = false
    @State private var isHovering = false
    
    init(title: String, subtitle: String? = nil, isSelected: Bool, @ViewBuilder icon: () -> Icon, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.icon = icon()
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            // Trigger icon bounce animation
            withAnimation(DroppyAnimation.bounce) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(DroppyAnimation.stateEmphasis) {
                    iconBounce = false
                    action()
                }
            }
        }) {
            HStack(spacing: 12) {
                // Icon preview area
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                        .fill(isSelected ? Color.blue.opacity(0.2) : AdaptiveColors.buttonBackgroundAuto)
                    
                    icon
                        .scaleEffect(iconBounce ? 1.2 : 1.0)
                        .rotationEffect(.degrees(iconBounce ? -5 : 0))
                }
                .frame(width: 70, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .green : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background((isSelected ? AdaptiveColors.buttonBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovering)
        }
        .buttonStyle(DroppySelectableButtonStyle(isSelected: isSelected))
        .contentShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Media Player Toggle Button

/// Premium toggle button for Now Playing with animated icon and info button
struct MediaPlayerToggleButton: View {
    @Binding var isOn: Bool
    var color: Color = .green
    
    @State private var iconBounce = false
    @State private var isHovering = false
    
    var body: some View {
        Button {
            withAnimation(DroppyAnimation.bounce) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(DroppyAnimation.stateEmphasis) {
                    iconBounce = false
                    isOn.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                NowPlayingIcon(size: 40)
                    .scaleEffect(iconBounce ? 1.15 : 1.0)
                    .rotationEffect(.degrees(iconBounce ? -5 : 0))
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Now Playing")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isOn ? .primary : .secondary)
                        SwipeGestureInfoButton()
                    }
                    Text("Show current song with album art")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? .green : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(AdaptiveColors.buttonBackgroundAuto)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(isOn ? color.opacity(0.3) : AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovering)
        }
        .buttonStyle(DroppySelectableButtonStyle(isSelected: isOn))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Link Button

/// Reusable button for external links, styled to match DisplayModeButton
struct LinkButton: View {
    let title: String
    let icon: String
    let url: String
    
    @State private var iconBounce = false
    @State private var isHovering = false
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                // Icon area
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                        .fill(AdaptiveColors.buttonBackgroundAuto)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.blue)
                        .scaleEffect(iconBounce ? 1.2 : 1.0)
                        .rotationEffect(.degrees(iconBounce ? -5 : 0))
                }
                .frame(width: 40, height: 40)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(AdaptiveColors.buttonBackgroundAuto)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovering)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                withAnimation(DroppyAnimation.bounce) {
                    iconBounce = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(DroppyAnimation.stateEmphasis) {
                        iconBounce = false
                    }
                }
            }
        }
    }
}
// MARK: - Animated Sub-Setting Toggle

/// Sub-setting toggle with icon bounce animation and subtitle
/// Uses horizontal layout matching other toggle styles
struct AnimatedSubSettingToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var color: Color = .green
    
    @State private var iconBounce = false
    @State private var isHovering = false
    
    var body: some View {
        Button {
            // Trigger icon bounce
            withAnimation(DroppyAnimation.bounce) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(DroppyAnimation.stateEmphasis) {
                    iconBounce = false
                    isOn.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                        .fill(isOn ? color.opacity(0.2) : AdaptiveColors.buttonBackgroundAuto)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isOn ? color : .secondary)
                        .scaleEffect(iconBounce ? 1.3 : 1.0)
                        .rotationEffect(.degrees(iconBounce ? -8 : 0))
                }
                .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isOn ? .primary : .secondary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? .green : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background((isOn ? AdaptiveColors.buttonBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(isOn ? color.opacity(0.3) : AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovering)
        }
        .buttonStyle(DroppySelectableButtonStyle(isSelected: isOn))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Haptic Slider

/// A slider that provides tactile feedback via Force Touch trackpad on each value change
/// Gives a premium feel like native macOS controls
struct HapticSlider<V: BinaryFloatingPoint>: View where V.Stride: BinaryFloatingPoint {
    @Binding var value: V
    let range: ClosedRange<V>
    let step: V.Stride
    var tint: Color = .blue
    
    var body: some View {
        Slider(value: $value, in: range, step: step)
            .tint(tint)
            .onChange(of: value) { oldValue, newValue in
                // Provide feedback on each step change
                let isEndpoint = newValue == range.lowerBound || newValue == range.upperBound
                
                if isEndpoint {
                    // Stronger feedback for reaching min/max
                    HapticFeedback.sliderEndpoint()
                } else {
                    // Subtle tick for regular steps
                    HapticFeedback.sliderTick()
                }
            }
    }
}

/// Convenience initializers for HapticSlider
extension HapticSlider {
    /// Full customization initializer
    init(
        value: Binding<V>,
        in range: ClosedRange<V>,
        step: V.Stride,
        tint: Color = .blue
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.tint = tint
    }
}

/// Drop-in view modifier to add haptic feedback to existing Slider views
/// Use this for sliders that can't easily be replaced with HapticSlider
struct SliderHapticModifier<V: BinaryFloatingPoint>: ViewModifier {
    let value: V
    let range: ClosedRange<V>
    
    func body(content: Content) -> some View {
        content
            .onChange(of: value) { oldValue, newValue in
                let isEndpoint = newValue == range.lowerBound || newValue == range.upperBound
                
                if isEndpoint {
                    HapticFeedback.sliderEndpoint()
                } else {
                    HapticFeedback.sliderTick()
                }
            }
    }
}

extension View {
    /// Adds haptic feedback to a slider when its value changes (via Force Touch trackpad)
    func sliderHaptics<V: BinaryFloatingPoint>(value: V, range: ClosedRange<V>) -> some View {
        modifier(SliderHapticModifier(value: value, range: range))
    }
}
