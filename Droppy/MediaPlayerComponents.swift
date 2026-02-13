import SwiftUI
import Combine

// MARK: - Custom Loading Spinner
// Pure SwiftUI spinner to avoid AppKit bridging warnings from ProgressView

/// Custom animated loading spinner that matches Droppy's aesthetic
/// Replaces ProgressView() to avoid AppKitProgressView layout constraint warnings
struct LoadingSpinner: View {
    @State private var rotation: Double = 0
    var color: Color = .white
    var size: CGFloat = 16
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .onDisappear {
                // PERFORMANCE FIX: Stop repeatForever animation when removed
                withAnimation(.linear(duration: 0)) {
                    rotation = 0
                }
            }
    }
}

// MARK: - Media Player Components
// Extracted from MediaPlayerView.swift for faster incremental builds

struct InlineHUDView: View {
    let type: InlineHUDType
    let value: CGFloat
    var isMuted: Bool = false  // PREMIUM: Explicit mute state from VolumeManager
    var isCharging: Bool = false  // Battery charging state for modern battery glyphs
    var symbolOverride: String? = nil
    var useAdaptiveForegrounds: Bool = false
    @ObservedObject private var volumeManager = VolumeManager.shared
    
    /// Animation trigger value for CapsLock/Focus (boolean-based)
    private var boolTrigger: Bool {
        value > 0
    }
    
    /// Whether to show muted state (explicit mute OR value is 0)
    private var shouldShowMuted: Bool {
        type == .volume && (isMuted || value <= 0)
    }

    private var iconSymbol: String {
        if type == .volume {
            return volumeManager.volumeHUDIcon(for: value, isMuted: shouldShowMuted)
        }
        if let symbolOverride {
            return symbolOverride
        }
        return type.icon(for: value, isCharging: type == .battery && isCharging)
    }
    
    /// PREMIUM: Delayed mute state for drain-then-color effect
    @State private var displayedMuted = false
    
    /// PREMIUM: Fill color based on HUD type (uses displayedMuted for delayed transition)
    private var fillColor: Color {
        if displayedMuted {
            return Color(red: 0.85, green: 0.25, blue: 0.25)  // Subtle red for muted
        }
        switch type {
        case .brightness:
            return Color(red: 1.0, green: 0.85, blue: 0.0)  // Bright yellow
        case .volume:
            return Color(red: 0.2, green: 0.9, blue: 0.4)   // Bright green
        case .battery:
            if value <= 0.2 && !isCharging {
                return Color(red: 1.0, green: 0.33, blue: 0.40)  // iOS-like low battery red
            }
            return isCharging
                ? Color(red: 0.46, green: 0.96, blue: 0.56)
                : Color(red: 0.2, green: 0.9, blue: 0.4)
        case .capsLock, .focus:
            return value > 0
                ? type.accentColor
                : AdaptiveColors.secondaryTextAuto.opacity(0.85)
        case .airPods:
            return Color(white: 0.92)
        case .lockScreen:
            return Color(white: 0.9)
        case .update:
            return Color(red: 0.41, green: 0.71, blue: 1.0)
        }
    }
    
    /// PREMIUM: Track color (darker, faded version)
    private var trackColor: Color {
        if displayedMuted {
            return Color(red: 0.25, green: 0.1, blue: 0.1)  // Dark muted red
        }
        switch type {
        case .brightness:
            return Color(red: 0.35, green: 0.3, blue: 0.05)  // Dark faded yellow
        case .volume:
            return Color(red: 0.08, green: 0.25, blue: 0.12)  // Dark faded green
        case .battery:
            if value <= 0.2 && !isCharging {
                return Color(red: 0.35, green: 0.2, blue: 0.08)  // Dark amber track
            }
            return Color(red: 0.08, green: 0.25, blue: 0.12)
        case .capsLock, .focus:
            return AdaptiveColors.overlayAuto(0.1)
        case .airPods, .lockScreen, .update:
            return AdaptiveColors.overlayAuto(0.1)
        }
    }
    
    /// Consistent icon tint across all expanded HUD variants
    private var iconColor: Color {
        switch type {
        case .brightness:
            return Color(red: 1.0, green: 0.85, blue: 0.0)
        case .volume, .battery, .capsLock, .focus, .airPods, .lockScreen, .update:
            return useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto : .white
        }
    }

    private var batteryOuterColor: Color {
        if isCharging {
            return Color(white: 0.62)
        }
        if value <= 0.2 {
            return Color(red: 0.62, green: 0.12, blue: 0.18)
        }
        return Color(red: 0.16, green: 0.48, blue: 0.24)
    }

    private var batteryInnerColor: Color {
        if isCharging {
            return Color(red: 0.46, green: 0.96, blue: 0.56)
        }
        if value <= 0.2 {
            return Color(red: 1.0, green: 0.33, blue: 0.40)
        }
        return Color(red: 0.46, green: 0.93, blue: 0.52)
    }

    private var batteryTerminalColor: Color {
        if isCharging {
            return Color(white: 0.62)
        }
        if value <= 0.2 {
            return Color(red: 0.68, green: 0.14, blue: 0.20)
        }
        return Color(red: 0.20, green: 0.56, blue: 0.28)
    }

    private var batteryChargingSegmentColor: Color {
        Color(white: 0.58)
    }

    var body: some View {
        // Equal spacing: Icon | 10px | Slider/state | 10px | Value text (when applicable)
        HStack(spacing: 10) {
            Group {
                switch type {
                case .capsLock, .focus:
                    // Toggle-based: bounce.up with downUp transition (same as CapsLock/DND HUDs)
                    Image(systemName: iconSymbol)
                        .symbolEffect(.bounce.up, value: boolTrigger)
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                case .battery:
                    IOSBatteryGlyph(
                        level: value,
                        outerColor: batteryOuterColor,
                        innerColor: batteryInnerColor,
                        terminalColor: batteryTerminalColor,
                        chargingSegmentColor: batteryChargingSegmentColor,
                        isCharging: isCharging,
                        bodyWidth: 21,
                        bodyHeight: 12
                    )
                case .lockScreen:
                    Image(systemName: iconSymbol)
                        .symbolEffect(.bounce.up, value: boolTrigger)
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                case .volume, .brightness, .airPods, .update:
                    Image(systemName: iconSymbol)
                        .contentTransition(.symbolEffect(.replace.byLayer))
                }
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(iconColor)
            .frame(width: 32, alignment: .trailing)
            .animation(DroppyAnimation.notchState, value: iconSymbol)
            
            // Slider (visual only) - PREMIUM: New colored slider with smooth mute transition
            if type.showsSlider {
                GeometryReader { geo in
                    let width = geo.size.width
                    let progress = max(0, min(1, value))
                    let fillWidth = max(4, width * progress)
                    let trackHeight: CGFloat = 4
                    
                    ZStack(alignment: .leading) {
                        // Track background - PREMIUM colored track
                        Capsule()
                            .fill(trackColor)
                            .frame(height: trackHeight)
                            .animation(.easeInOut(duration: 0.25), value: isMuted)
                        
                        // PREMIUM: Gradient fill with glow
                        if progress > 0 {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            fillColor,
                                            fillColor.opacity(0.85)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: fillWidth, height: trackHeight)
                                // Top highlight stroke
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.4) : .white.opacity(0.4),
                                                    .clear
                                                ],
                                                startPoint: .top,
                                                endPoint: .center
                                            ),
                                            lineWidth: 0.5
                                        )
                                )
                                // PREMIUM BLOOM: Multi-layer glow
                                .shadow(color: fillColor.opacity(0.3), radius: 1)
                                .shadow(color: fillColor.opacity(0.15 + (progress * 0.15)), radius: 3)
                                .shadow(color: fillColor.opacity(0.1 + (progress * 0.1)), radius: 5 + (progress * 3))
                                .animation(.easeInOut(duration: 0.25), value: isMuted)
                        }
                    }
                    .frame(height: trackHeight)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .animation(.interpolatingSpring(stiffness: 350, damping: 28), value: value)
                }
                .frame(height: 28)
                
                // PREMIUM: Animated percentage text with rolling number effect
                Text("\(Int(max(0, min(1, value)) * 100))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        useAdaptiveForegrounds
                            ? AdaptiveColors.primaryTextAuto.opacity(0.88)
                            : .white.opacity(0.85)
                    )
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: 32, alignment: .leading)
                    .contentTransition(.numericText(value: Double(Int(value * 100))))
                    .animation(DroppyAnimation.state, value: Int(value * 100))
            } else {
                let isOn = value > 0
                Text(type.displayText(for: value).uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        useAdaptiveForegrounds
                            ? AdaptiveColors.primaryTextAuto.opacity(0.9)
                            : .white.opacity(0.88)
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isOn ? fillColor.opacity(0.2) : AdaptiveColors.overlayAuto(0.08))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isOn ? fillColor.opacity(0.45) : AdaptiveColors.overlayAuto(0.22), lineWidth: 0.8)
                    )
            }
        }
        // Match width of center controls
        .frame(width: type.showsSlider ? 170 : 116)
        // PREMIUM: Delayed mute color transition - bar drains first, then color changes
        .onChange(of: shouldShowMuted) { _, newMuted in
            if newMuted {
                // When muting: delay color change so bar drains to 0 first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayedMuted = true
                    }
                }
            } else {
                // When unmuting: immediately show green
                withAnimation(.easeInOut(duration: 0.15)) {
                    displayedMuted = false
                }
            }
        }
        .onAppear {
            displayedMuted = shouldShowMuted
        }
    }
}

// MARK: - Audio Visualizer Bars

/// Animated audio visualizer bars with real audio support (ScreenCaptureKit)
/// Falls back to enhanced simulation if permission not granted or macOS < 13
struct AudioVisualizerBars: View {
    let isPlaying: Bool
    var color: Color = .white
    var secondaryColor: Color? = nil  // For gradient mode
    var gradientMode: Bool = false    // Enable gradient across bars
    
    @StateObject private var audioAnalyzer = AudioVisualizerState()
    
    var body: some View {
        AudioSpectrumView(
            isPlaying: isPlaying,
            barCount: 5,
            barWidth: 2.1,
            spacing: 1.7,
            height: 18,
            color: color,
            secondaryColor: secondaryColor,
            gradientMode: gradientMode,
            audioLevel: audioAnalyzer.audioLevel
        )
        .frame(width: 5 * 2.1 + 4 * 1.7, height: 18)
        .onAppear { audioAnalyzer.startObserving() }
        .onDisappear { audioAnalyzer.stopObserving() }
    }
}

/// Shared observer for SystemAudioAnalyzer - manages observer lifecycle
/// Only uses real audio capture if user has enabled it in Settings (opt-in for privacy)
@MainActor
private class AudioVisualizerState: ObservableObject {
    @Published var audioLevel: CGFloat? = nil
    private var cancellable: AnyCancellable?
    
    /// Whether real audio visualizer is enabled (opt-in for Screen Recording permission)
    private var enableRealAudioVisualizer: Bool {
        UserDefaults.standard.bool(forKey: "enableRealAudioVisualizer")
    }
    
    func startObserving() {
        // Only use real audio capture if explicitly enabled by user
        // This requires Screen Recording permission which we don't want to request by default
        guard enableRealAudioVisualizer else {
            audioLevel = nil  // Will use simulation fallback in AudioSpectrumView
            return
        }
        
        if #available(macOS 13.0, *) {
            let analyzer = SystemAudioAnalyzer.shared
            analyzer.addObserver()
            
            // Combine both audioLevel and isActive to properly react when capture becomes active
            cancellable = analyzer.$audioLevel
                .combineLatest(analyzer.$isActive)
                .receive(on: RunLoop.main)
                .sink { [weak self] (level, isActive) in
                    self?.audioLevel = isActive ? level : nil
                }
        }
    }
    
    func stopObserving() {
        // Only remove observer if we actually added one
        if enableRealAudioVisualizer {
            if #available(macOS 13.0, *) {
                SystemAudioAnalyzer.shared.removeObserver()
            }
        }
        cancellable = nil
        audioLevel = nil
    }
}

// MARK: - Spotify Badge

/// Small Spotify logo badge for album art overlay
/// Uses bundled high-quality Spotify icon for reliable visibility
struct SpotifyBadge: View {
    var size: CGFloat = 24
    
    var body: some View {
        Image("SpotifyIcon")
            .resizable()
            .renderingMode(.original)  // Preserve original colors
            .antialiased(true)         // Smooth edges
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }
}

/// Small Apple Music badge for album art overlay
/// Uses bundled official Apple Music icon for reliable visibility
struct AppleMusicBadge: View {
    var size: CGFloat = 24
    
    var body: some View {
        Image("AppleMusicIcon")
            .resizable()
            .renderingMode(.original)  // Preserve original colors
            .antialiased(true)         // Smooth edges
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }
}

/// Small Tidal badge for album art overlay
/// Uses bundled official Tidal icon for reliable visibility
struct TidalBadge: View {
    var size: CGFloat = 24

    var body: some View {
        Image("TidalIcon")
            .resizable()
            .renderingMode(.original)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }
}

// MARK: - Media Control Button (with premium nudge effects)

/// Media control button with premium press animations
/// - nudgeDirection: .left for previous, .right for next, .none for play/pause (uses wiggle)
struct MediaControlButton: View {
    let icon: String
    let size: CGFloat
    var foregroundColor: Color = .white
    var tapPadding: CGFloat = 16
    var nudgeDirection: NudgeDirection = .none
    let action: () -> Void
    
    @State private var isHovering = false
    @State private var pressOffset: CGFloat = 0
    @State private var rotationAngle: Double = 0
    
    enum NudgeDirection {
        case left, right, none
    }
    
    var body: some View {
        Button {
            triggerPressEffect()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(foregroundColor)
                .frame(width: size + tapPadding, height: size + tapPadding)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(MediaButtonStyle(isHovering: isHovering))
        .offset(x: pressOffset)
        .rotationEffect(.degrees(rotationAngle))
        .onHover { hovering in
            withAnimation(DroppyAnimation.hover) {
                isHovering = hovering
            }
        }
    }
    
    /// Premium press effect - nudge for prev/next, wiggle for play/pause
    private func triggerPressEffect() {
        switch nudgeDirection {
        case .left:
            // Nudge left briefly
            withAnimation(DroppyAnimation.mediaPress) {
                pressOffset = -6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(DroppyAnimation.mediaRelease) {
                    pressOffset = 0
                }
            }
        case .right:
            // Nudge right briefly
            withAnimation(DroppyAnimation.mediaPress) {
                pressOffset = 6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(DroppyAnimation.mediaRelease) {
                    pressOffset = 0
                }
            }
        case .none:
            // Wiggle for play/pause
            withAnimation(DroppyAnimation.mediaEmphasis) {
                rotationAngle = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(DroppyAnimation.mediaSettle) {
                    rotationAngle = 0
                }
            }
        }
    }
}

/// Custom button style for media controls with press animation
struct MediaButtonStyle: ButtonStyle {
    var isHovering: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : (isHovering ? 1.05 : 1.0))
            .animation(DroppyAnimation.hoverQuick, value: configuration.isPressed)
            .animation(DroppyAnimation.hoverQuick, value: isHovering)
    }
}

// MARK: - Spotify Control Button

/// Spotify-specific control button with active state highlighting
/// Styled to match MediaControlButton with additional active state support
struct SpotifyControlButton: View {
    let icon: String
    var isActive: Bool = false
    var isLoading: Bool = false
    var accentColor: Color = .white
    var size: CGFloat = 16  // Icon size (tap target scales proportionally)
    let action: () -> Void
    
    @State private var isHovering = false
    
    private var foregroundColor: Color {
        if isActive {
            return accentColor.ensureMinimumBrightness(factor: 0.7)
        }
        return .white.opacity(0.6)
    }
    
    private var tapTargetSize: CGFloat {
        size * 2.5  // Proportional tap target
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    LoadingSpinner(color: foregroundColor, size: size)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: size, weight: .semibold))
                        .foregroundStyle(foregroundColor)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: tapTargetSize, height: tapTargetSize)
            .background(
                Circle()
                    .fill(isActive ? accentColor.opacity(0.15) : AdaptiveColors.overlayAuto(isHovering ? 0.08 : 0))
            )
            .contentShape(Circle())
        }
        .buttonStyle(SpotifyButtonStyle(isHovering: isHovering))
        .disabled(isLoading)
        .onHover { hovering in
            withAnimation(DroppyAnimation.hover) {
                isHovering = hovering
            }
        }
    }
}

/// Custom button style for Spotify controls with press animation
struct SpotifyButtonStyle: ButtonStyle {
    var isHovering: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : (isHovering ? 1.05 : 1.0))
            .animation(DroppyAnimation.hoverQuick, value: configuration.isPressed)
            .animation(DroppyAnimation.hoverQuick, value: isHovering)
    }
}

// MARK: - Color Extension

extension Color {
    /// Ensure minimum brightness for legibility on dark backgrounds
    func ensureMinimumBrightness(factor: CGFloat) -> Color {
        guard let nsColor = NSColor(self).usingColorSpace(.deviceRGB) else {
            return self
        }
        
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        let newBrightness = max(b, factor)
        return Color(hue: h, saturation: s, brightness: newBrightness, opacity: a)
    }
}

// MARK: - Compact Media Player (for closed notch hints)

struct CompactMediaPlayerView: View {
    @ObservedObject var musicManager = MusicManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // Mini album art
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xs))
            
            // Playing indicator bars
            if musicManager.isPlaying {
                MusicVisualizerBars()
                    .frame(width: 16, height: 16)
            }
        }
    }
}

/// Animated music bars for playing indicator
struct MusicVisualizerBars: View {
    @State private var heights: [CGFloat] = [0.3, 0.6, 0.4]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white)
                    .frame(width: 3, height: 16 * heights[index])
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            // PERFORMANCE FIX: Stop repeatForever animations by resetting to initial values
            withAnimation(.linear(duration: 0)) {
                heights = [0.3, 0.6, 0.4]
            }
        }
    }
    
    private func startAnimation() {
        withAnimation(DroppyAnimation.viewChange.repeatForever(autoreverses: true)) {
            heights = [0.6, 1.0, 0.5]
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                heights[1] = 0.4
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                heights[2] = 0.9
            }
        }
    }
}

// MARK: - Preview

#Preview("Media Player") {
    VStack {
        MediaPlayerView(musicManager: MusicManager.shared)
            .frame(width: 350, height: 200)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl))
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
