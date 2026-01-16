import SwiftUI
import Combine

// MARK: - Media Player Components
// Extracted from MediaPlayerView.swift for faster incremental builds

struct InlineHUDView: View {
    let type: InlineHUDType
    let value: CGFloat
    
    var body: some View {
        // Equal spacing: Icon (32px) | 10px | Slider | 10px | Text (32px)
        HStack(spacing: 10) {
            // Icon with smooth symbol transition
            Image(systemName: type.icon(for: value))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(type.accentColor)
                .frame(width: 32, alignment: .trailing) // Same width as text for symmetry
                .contentTransition(.symbolEffect(.replace))
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: type.icon(for: value))
            
            // Slider (visual only) - matches HUDSlider style
            if type.showsSlider {
                GeometryReader { geo in
                    let width = geo.size.width
                    let progress = max(0, min(1, value))
                    let fillWidth = max(5, width * progress)
                    let trackHeight: CGFloat = 5
                    
                    ZStack(alignment: .leading) {
                        // Track background
                        Capsule()
                            .fill(type.accentColor.opacity(0.2))
                            .frame(height: trackHeight)
                        
                        // Filled portion with glow
                        if progress > 0 {
                            Capsule()
                                .fill(type.accentColor)
                                .frame(width: fillWidth, height: trackHeight)
                                .shadow(color: type.accentColor.opacity(0.4), radius: 4)
                        }
                    }
                    .frame(height: trackHeight)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .animation(.spring(response: 0.15, dampingFraction: 0.8), value: value)
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
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: value)
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
@MainActor
private class AudioVisualizerState: ObservableObject {
    @Published var audioLevel: CGFloat? = nil
    private var cancellable: AnyCancellable?
    
    func startObserving() {
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
        if #available(macOS 13.0, *) {
            SystemAudioAnalyzer.shared.removeObserver()
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

// MARK: - Media Control Button (plain, no background)

/// Simple media control button without background (for rewind/play/forward)
struct MediaControlButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size + 16, height: size + 16)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(MediaButtonStyle(isHovering: isHovering))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
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
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
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
    let action: () -> Void
    
    @State private var isHovering = false
    
    private var foregroundColor: Color {
        if isActive {
            return accentColor.ensureMinimumBrightness(factor: 0.7)
        }
        return .white.opacity(0.6)
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(foregroundColor)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 40, height: 40)  // Larger tap target
            .background(
                Circle()
                    .fill(isActive ? accentColor.opacity(0.15) : Color.white.opacity(isHovering ? 0.08 : 0))
            )
            .contentShape(Circle())
        }
        .buttonStyle(SpotifyButtonStyle(isHovering: isHovering))
        .disabled(isLoading)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
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
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
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
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
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
