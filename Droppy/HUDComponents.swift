import SwiftUI
import Combine

// MARK: - HUD Components
// Extracted from HUDOverlayView.swift for faster incremental builds

struct HUDSlider: View {
    @Binding var value: CGFloat
    var accentColor: Color = .white
    var isActive: Bool = false
    var onChange: ((CGFloat) -> Void)?
    
    @State private var isDragging = false
    
    /// Whether slider should be expanded (dragging OR externally active)
    private var isExpanded: Bool { isDragging || isActive }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = max(0, min(1, value))
            let progressWidth = max(0, min(width, width * progress))
            // Expand track height when active/dragging
            let trackHeight: CGFloat = isExpanded ? 6 : 4
            
            ZStack(alignment: .leading) {
                // Track background (dark gray, matches seek slider)
                Capsule()
                    .fill(accentColor.opacity(isExpanded ? 0.3 : 0.2))
                    .frame(height: trackHeight)
                
                // Filled portion with ultra-smooth animation
                if progress > 0 {
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(trackHeight, progressWidth), height: trackHeight)
                        .shadow(color: isExpanded ? accentColor.opacity(0.4) : .clear, radius: isExpanded ? 4 : 0)
                        // Fast interpolating spring for buttery smooth fill
                        .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: progress)
                }
            }
            .frame(height: trackHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .scaleEffect(y: isExpanded ? 1.1 : 1.0, anchor: .center)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isExpanded)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                        }
                        let fraction = max(0, min(1, gesture.location.x / width))
                        value = fraction
                        onChange?(fraction)
                    }
                    .onEnded { gesture in
                        let fraction = max(0, min(1, gesture.location.x / width))
                        value = fraction
                        onChange?(fraction)
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                            isDragging = false
                        }
                    }
            )
        }
        .frame(height: 20)
    }
}

// MARK: - Media Player HUD

/// Compact media HUD that sits inside the notch
/// Album art and visualizer are centered within each wing, with consistent padding
struct MediaHUDView: View {
    @ObservedObject var musicManager: MusicManager
    @Binding var isHovered: Bool
    let notchWidth: CGFloat  // Physical notch width
    let notchHeight: CGFloat // Physical notch height (for vertical centering)
    let hudWidth: CGFloat    // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    /// Whether we're in Dynamic Island mode (screen-aware for multi-monitor)
    /// For HUD LAYOUT purposes: external displays always use compact layout (no physical notch)
    private var isDynamicIslandMode: Bool {
        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        
        // External displays never have physical notches, so always use compact HUD layout
        // The externalDisplayUseDynamicIsland setting only affects the visual shape, not HUD content layout
        if !screen.isBuiltIn {
            return true
        }
        
        // For built-in display, use main Dynamic Island setting
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    /// Combined song info for marquee
    private var songInfo: String {
        if musicManager.songTitle.isEmpty {
            return "Not Playing"
        }
        return "\(musicManager.songTitle) - \(musicManager.artistName)"
    }
    
    /// Dominant color extracted from album art for visualizer
    private var visualizerColor: Color {
        if musicManager.albumArt.size.width > 0 {
            return musicManager.albumArt.dominantColor()
        }
        return .white.opacity(0.7)
    }
    
    /// Width of each "wing" (area left/right of physical notch) - only used in notch mode
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Main HUD layout differs for Dynamic Island vs Notch mode
            if isDynamicIslandMode {
                // DYNAMIC ISLAND: Album on left, Visualizer on right, Title centered
                // Standardized sizing: 20px elements, 13pt text, 14px horizontal padding
                ZStack {
                    // Title - truly centered in the island (both horizontally and vertically)
                    VStack {
                        Spacer(minLength: 0)
                        MarqueeText(text: musicManager.songTitle.isEmpty ? "Not Playing" : musicManager.songTitle, speed: 30)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(height: 16) // Fixed height for text
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 36) // Leave space for album art and visualizer
                    
                    // Album art (left) and Visualizer (right)
                    HStack {
                        // Album art - matches icon size from other HUDs
                        Group {
                            if musicManager.albumArt.size.width > 0 {
                                Image(nsImage: musicManager.albumArt)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.5))
                                    )
                            }
                        }
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Spacer()
                        
                        // Visualizer - scaled to match other HUD elements
                        AudioSpectrumView(isPlaying: musicManager.isPlaying, barCount: 3, barWidth: 2.5, spacing: 2, height: 14, color: visualizerColor)
                            .frame(width: 3 * 2.5 + 2 * 2, height: 14)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: notchHeight)
                .padding(.horizontal, 14)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                // Album art and visualizer positioned near outer edges
                // Horizontal padding matches vertical: (notchHeight - 26) / 2 ≈ 3-5px
                HStack(spacing: 0) {
                    // Left wing: Album art near left edge
                    HStack {
                        Group {
                            if musicManager.albumArt.size.width > 0 {
                                Image(nsImage: musicManager.albumArt)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.5))
                                    )
                            }
                        }
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 8)  // Balanced with vertical padding
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: notchWidth)
                    
                    // Right wing: Visualizer near right edge
                    HStack {
                        Spacer(minLength: 0)
                        MiniAudioVisualizerBars(isPlaying: musicManager.isPlaying, color: visualizerColor)
                    }
                    .padding(.trailing, 8)  // Balanced with vertical padding
                    .frame(width: wingWidth)
                }
                .frame(height: notchHeight)
            }
            
            // Hover: Scrolling song info (appears below album art / visualizer row)
            // Only in Notch mode - Dynamic Island already shows title inline
            if isHovered && !isDynamicIslandMode {
                MarqueeText(text: songInfo, speed: 40)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(height: 20)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isHovered)
        .allowsHitTesting(true)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                // Show media player when expanding from mini HUD
                MusicManager.shared.isMediaHUDForced = true
                MusicManager.shared.isMediaHUDHidden = false
                // Expand shelf on THIS screen (use targetScreen if available, else main)
                if let displayID = targetScreen?.displayID ?? NSScreen.main?.displayID {
                    DroppyState.shared.expandShelf(for: displayID)
                }
            }
        }
    }
}

/// Mini audio visualizer bars for compact HUD with real audio support
struct MiniAudioVisualizerBars: View {
    let isPlaying: Bool
    var color: Color = .white
    
    @StateObject private var audioAnalyzer = MiniAudioVisualizerState()
    
    var body: some View {
        AudioSpectrumView(
            isPlaying: isPlaying,
            barCount: 5,
            barWidth: 3,
            spacing: 2,
            height: 18,
            color: color,
            audioLevel: audioAnalyzer.audioLevel
        )
        .frame(width: 5 * 3 + 4 * 2, height: 18)
        .onAppear { audioAnalyzer.startObserving() }
        .onDisappear { audioAnalyzer.stopObserving() }
    }
}

/// Observer for SystemAudioAnalyzer in mini HUD
@MainActor
private class MiniAudioVisualizerState: ObservableObject {
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

/// Scrolling marquee text view using TimelineView for efficiency
struct MarqueeText: View {
    let text: String
    let speed: Double // Points per second
    
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var startTime: Date = Date()
    
    private var needsScroll: Bool {
        textWidth > containerWidth && containerWidth > 0
    }
    
    var body: some View {
        GeometryReader { geo in
            // Use native display refresh rate for smooth 120Hz ProMotion scrolling
            TimelineView(.animation(paused: !needsScroll)) { timeline in
                let totalDistance = textWidth + 50
                let elapsed = timeline.date.timeIntervalSince(startTime)
                let rawOffset = elapsed * speed
                let offset = needsScroll ? -CGFloat(rawOffset.truncatingRemainder(dividingBy: Double(totalDistance))) : 0
                
                HStack(spacing: needsScroll ? 50 : 0) {
                    Text(text)
                        .fixedSize()
                        .background(
                            GeometryReader { textGeo in
                                Color.clear.onAppear {
                                    textWidth = textGeo.size.width
                                }
                                .onChange(of: text) { _, _ in
                                    textWidth = textGeo.size.width
                                    startTime = Date() // Reset scroll on text change
                                }
                            }
                        )
                    
                    if needsScroll {
                        Text(text)
                            .fixedSize()
                    }
                }
                .offset(x: offset)
                // Center text when it fits, left-align when scrolling
                .frame(maxWidth: .infinity, alignment: needsScroll ? .leading : .center)
            }
            .onAppear {
                containerWidth = geo.size.width
                startTime = Date()
            }
            .onChange(of: geo.size.width) { _, newWidth in
                containerWidth = newWidth
            }
        }
        .clipped()
    }
}

/// Progress slider that matches LiquidSlider aesthetics (non-interactive)
struct ProgressSlider: View {
    var progress: CGFloat
    var accentColor: Color
    
    private let height: CGFloat = 6
    
    /// Safe progress value - guards against NaN and infinity
    private var safeProgress: CGFloat {
        let p = progress
        if p.isNaN || p.isInfinite {
            return 0
        }
        return min(1, max(0, p))
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let filledWidth = safeProgress * width
            
            ZStack(alignment: .leading) {
                // Track background - concave glass well (matches LiquidSlider)
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                    )
                    // Concave lighting: shadow on top, highlight on bottom
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .black.opacity(0.3), location: 0),
                                        .init(color: .clear, location: 0.3),
                                        .init(color: .white.opacity(0.2), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .frame(height: height)
                
                // Filled portion - gradient with glow (matches LiquidSlider)
                if width > 0 && safeProgress > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor,
                                    accentColor.opacity(0.6)
                                ],
                                startPoint: .trailing,
                                endPoint: .leading
                            )
                        )
                        .frame(width: max(height, filledWidth), height: height)
                        // Inner glow
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(0.6), location: 0),
                                            .init(color: .clear, location: 0.5)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        // Glow shadow
                        .shadow(
                            color: accentColor.opacity(0.3),
                            radius: 4,
                            x: 2,
                            y: 0
                        )
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: safeProgress)
                }
            }
            .frame(height: height)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: height)
    }
}

// MARK: - Legacy HUD (kept for reference)

/// HUD overlay view that appears below the notch for volume/brightness control
/// Styled with Liquid Glass aesthetics to match Droppy's design system
