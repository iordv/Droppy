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
    }
}

// MARK: - Media Player Components
// Extracted from MediaPlayerView.swift for faster incremental builds

struct InlineHUDView: View {
    let type: InlineHUDType
    let value: CGFloat
    
    /// Animation trigger value for CapsLock/Focus (boolean-based)
    private var boolTrigger: Bool {
        value > 0
    }
    
    var body: some View {
        // Equal spacing: Icon (32px) | 10px | Slider | 10px | Text (32px)
        HStack(spacing: 10) {
            // Icon with smooth symbol transition - matches regular HUD animations
            Group {
                switch type {
                case .capsLock, .focus:
                    // Toggle-based: bounce.up with downUp transition (same as CapsLock/DND HUDs)
                    Image(systemName: type.icon(for: value))
                        .symbolEffect(.bounce.up, value: boolTrigger)
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                case .battery:
                    // State-based: bounce on charging (same as Battery HUD)
                    Image(systemName: type.icon(for: value))
                        .symbolEffect(.bounce, value: value)
                        .contentTransition(.symbolEffect(.replace.byLayer))
                case .volume, .brightness:
                    // No bounce - just smooth icon transition (bounce on slider causes jitter)
                    Image(systemName: type.icon(for: value))
                        .contentTransition(.symbolEffect(.replace.byLayer))
                }
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(type.accentColor)
            .frame(width: 32, alignment: .trailing) // Same width as text for symmetry
            .animation(DroppyAnimation.notchState, value: type.icon(for: value))
            
            // Slider (visual only) - matches HUDSlider premium style
            if type.showsSlider {
                GeometryReader { geo in
                    let width = geo.size.width
                    let progress = max(0, min(1, value))
                    let fillWidth = max(4, width * progress)
                    let trackHeight: CGFloat = 4
                    
                    ZStack(alignment: .leading) {
                        // Track background (simple, no mask/blur)
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: trackHeight)
                        
                        // PREMIUM: Gradient fill with glow
                        if progress > 0 {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            type.accentColor,
                                            type.accentColor.opacity(0.85)
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
                                                colors: [.white.opacity(0.4), .clear],
                                                startPoint: .top,
                                                endPoint: .center
                                            ),
                                            lineWidth: 0.5
                                        )
                                )
                                // PREMIUM BLOOM: Multi-layer glow
                                .shadow(color: type.accentColor.opacity(0.3), radius: 1)
                                .shadow(color: type.accentColor.opacity(0.15 + (progress * 0.15)), radius: 3)
                                .shadow(color: type.accentColor.opacity(0.1 + (progress * 0.1)), radius: 5 + (progress * 3))
                        }
                    }
                    .frame(height: trackHeight)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .animation(.interpolatingSpring(stiffness: 350, damping: 28), value: value)
                }
                .frame(height: 28)
            }
            
            // Value text - MUST stay on one line
            Text(type.displayText(for: value))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: 32, alignment: .leading) // Same width as icon for symmetry
                .contentTransition(.numericText(value: value))
                .animation(DroppyAnimation.notchState, value: value)
        }
        // Match width of center controls
        .frame(width: type.showsSlider ? 160 : 80)
    }
}

// MARK: - Audio Visualizer Bars

/// Animated audio visualizer bars with real audio support (ScreenCaptureKit)
/// Falls back to enhanced simulation if permission not granted or macOS < 13
struct AudioVisualizerBars: View {
    let isPlaying: Bool
    var color: Color = .white
    
    @StateObject private var audioAnalyzer = AudioVisualizerState()
    
    var body: some View {
        AudioSpectrumView(
            isPlaying: isPlaying,
            barCount: 5,
            barWidth: 3,
            spacing: 2,
            height: 20,
            color: color,
            audioLevel: audioAnalyzer.audioLevel
        )
        .frame(width: 5 * 3 + 4 * 2, height: 20) // 5 bars * 3px + 4 gaps * 2px
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
struct SpotifyBadge: View {
    var body: some View {
        CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/spotify.png")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            Image(systemName: "music.note.list")
                .font(.system(size: 12))
                .foregroundStyle(.blue)
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

// MARK: - Media Control Button (with premium nudge effects)

/// Media control button with premium press animations
/// - nudgeDirection: .left for previous, .right for next, .none for play/pause (uses wiggle)
struct MediaControlButton: View {
    let icon: String
    let size: CGFloat
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
                .foregroundStyle(.white)
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
            withAnimation(.spring(response: 0.16, dampingFraction: 0.72)) {
                pressOffset = -6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                    pressOffset = 0
                }
            }
        case .right:
            // Nudge right briefly
            withAnimation(.spring(response: 0.16, dampingFraction: 0.72)) {
                pressOffset = 6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                    pressOffset = 0
                }
            }
        case .none:
            // Wiggle for play/pause
            withAnimation(.spring(response: 0.18, dampingFraction: 0.52)) {
                rotationAngle = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
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
                    .fill(isActive ? accentColor.opacity(0.15) : Color.white.opacity(isHovering ? 0.08 : 0))
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
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
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
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
