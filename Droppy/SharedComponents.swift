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

// MARK: - Option Button Style

/// Shared button style with press animation
struct OptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

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
            withAnimation(.spring(response: DesignConstants.bounceResponse, dampingFraction: DesignConstants.bounceDamping)) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    iconBounce = false
                    isOn.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOn ? color.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: DesignConstants.springResponse, dampingFraction: DesignConstants.springDamping), value: isHovering)
        }
        .buttonStyle(OptionButtonStyle())
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
            withAnimation(.spring(response: DesignConstants.bounceResponse, dampingFraction: DesignConstants.bounceDamping)) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    iconBounce = false
                    isOn.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOn ? color.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(isHovering && isEnabled ? 1.02 : 1.0)
            .animation(.spring(response: DesignConstants.springResponse, dampingFraction: DesignConstants.springDamping), value: isHovering)
        }
        .buttonStyle(OptionButtonStyle())
        .contentShape(Rectangle())
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovering = hovering
        }
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
            withAnimation(.spring(response: DesignConstants.bounceResponse, dampingFraction: DesignConstants.bounceDamping)) {
                iconBounce = true
                showBrightnessIcon = true
            }
            
            // Switch back to volume after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showBrightnessIcon = false
                }
            }
            
            // Toggle state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    iconBounce = false
                    isEnabled.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isEnabled ? AdaptiveColors.subtleBorderAuto : Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: DesignConstants.springResponse, dampingFraction: DesignConstants.springDamping), value: isHovering)
        }
        .buttonStyle(OptionButtonStyle())
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
    
    @State private var isHovering = false
    @State private var isPressed = false
    @State private var iconBounce = false
    
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
            withAnimation(.spring(response: DesignConstants.bounceResponse, dampingFraction: DesignConstants.bounceDamping)) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    iconBounce = false
                    action()
                }
            }
        }) {
            HStack(spacing: 12) {
                // Icon preview area
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : (isHovering ? 1.02 : 1.0))
            .animation(.spring(response: DesignConstants.springResponse, dampingFraction: DesignConstants.springDamping), value: isHovering)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
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
            withAnimation(.spring(response: DesignConstants.bounceResponse, dampingFraction: DesignConstants.bounceDamping)) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    iconBounce = false
                    isOn.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOn ? color.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: DesignConstants.springResponse, dampingFraction: DesignConstants.springDamping), value: isHovering)
        }
        .buttonStyle(OptionButtonStyle())
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
