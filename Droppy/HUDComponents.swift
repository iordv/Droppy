import SwiftUI
import Combine

// MARK: - HUD Components
// Extracted from HUDOverlayView.swift for faster incremental builds

struct HUDSlider: View {
    @Binding var value: CGFloat
    var hudType: HUDContentType = .volume  // PREMIUM: Determines green/yellow coloring
    var accentColor: Color = .white  // Kept for backwards compatibility, overridden by hudType
    var isMuted: Bool = false  // PREMIUM: When true, uses red color for muted volume
    var isActive: Bool = false
    var onChange: ((CGFloat) -> Void)?
    
    @State private var isDragging = false
    @State private var displayedMuted = false  // PREMIUM: Delayed mute state for drain-then-color effect
    
    /// Whether slider should be expanded (dragging OR externally active)
    private var isExpanded: Bool { isDragging || isActive }
    
    /// PREMIUM: Fill color based on HUD type (red override when muted - uses displayedMuted for delayed transition)
    private var fillColor: Color {
        if displayedMuted {
            return Color(red: 0.85, green: 0.25, blue: 0.25)  // Subtle red for muted
        }
        switch hudType {
        case .brightness:
            return Color(red: 1.0, green: 0.85, blue: 0.0)  // Bright yellow
        case .volume, .backlight, .mute:
            return Color(red: 0.2, green: 0.9, blue: 0.4)   // Bright green
        }
    }
    
    /// PREMIUM: Track (empty side) color based on HUD type - darker, faded version
    private var trackColor: Color {
        if displayedMuted {
            return Color(red: 0.25, green: 0.1, blue: 0.1)  // Dark muted red
        }
        switch hudType {
        case .brightness:
            return Color(red: 0.35, green: 0.3, blue: 0.05)  // Dark faded yellow
        case .volume, .backlight, .mute:
            return Color(red: 0.08, green: 0.25, blue: 0.12)  // Dark faded green
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {  // Matches icon-to-slider spacing in HUDOverlayView
            // Slider portion
            sliderTrack
            
            // PREMIUM: Animated percentage text with natural width
            AnimatedPercentageText(value: value)
                .fixedSize()  // Natural width - no extra padding
        }
        .frame(height: 20)
        // PREMIUM: Smooth width animation when text changes size (e.g. 9→10, 99→100)
        .animation(DroppyAnimation.state, value: Int(value * 100))
        // PREMIUM: Delayed mute color transition - bar drains first, then color changes
        .onChange(of: isMuted) { _, newMuted in
            if newMuted {
                // When muting: delay color change so bar drains to 0 first (green -> empty -> red)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(DroppyAnimation.easeInOut(duration: 0.2)) {
                        displayedMuted = true
                    }
                }
            } else {
                // When unmuting: immediately show green (red -> green instantly, then bar fills)
                withAnimation(DroppyAnimation.easeInOut(duration: 0.15)) {
                    displayedMuted = false
                }
            }
        }
        .onAppear {
            // Sync initial state
            displayedMuted = isMuted
        }
    }
    
    private var sliderTrack: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = max(0, min(1, value))
            let progressWidth = max(0, min(width, width * progress))
            let trackHeight: CGFloat = isExpanded ? 5 : 4
            
            ZStack(alignment: .leading) {
                // Track background - PREMIUM colored track (not just white/gray)
                Capsule()
                    .fill(trackColor)
                    .frame(height: trackHeight)
                    // PREMIUM: Smooth color transition for mute state
                    .animation(DroppyAnimation.easeInOut(duration: 0.25), value: isMuted)
                
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
                        .frame(width: max(trackHeight, progressWidth), height: trackHeight)
                        // Top highlight stroke (no mask)
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
                        .shadow(color: fillColor.opacity(0.3), radius: 1)
                        .shadow(color: fillColor.opacity(0.15 + (progress * 0.15)), radius: 3)
                        .shadow(color: fillColor.opacity(0.1 + (progress * 0.1)), radius: 5 + (progress * 3))
                        // PREMIUM: Smooth animation for both progress AND mute color transition
                        .animation(.interpolatingSpring(stiffness: 350, damping: 28), value: progress)
                        .animation(DroppyAnimation.easeInOut(duration: 0.25), value: isMuted)
                }
            }
            .frame(height: trackHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .scaleEffect(y: isExpanded ? 1.08 : 1.0, anchor: .center)
            .animation(DroppyAnimation.hover, value: isExpanded)
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
                        withAnimation(DroppyAnimation.hover) {
                            isDragging = false
                        }
                    }
            )
        }
    }
}

/// PREMIUM: Animated percentage text with rolling number effect
private struct AnimatedPercentageText: View {
    let value: CGFloat
    
    /// Current percentage value (0-100)
    private var percentage: Int {
        Int(max(0, min(1, value)) * 100)
    }
    
    var body: some View {
        // PREMIUM: Rolling number animation effect
        Text("\(percentage)")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(percentage)))
            .animation(DroppyAnimation.state, value: percentage)
    }
}

// MARK: - Album Art Matched Geometry Modifier

/// PREMIUM-STYLE: Applies matchedGeometryEffect to views for smooth morphing between HUD and expanded player.
/// Only applies the effect when a namespace is provided, allowing optional usage.
struct AlbumArtMatchedGeometry: ViewModifier {
    var namespace: Namespace.ID?
    var id: String = "albumArt"
    
    func body(content: Content) -> some View {
        if let ns = namespace {
            content.matchedGeometryEffect(id: id, in: ns)
        } else {
            content
        }
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
    var albumArtNamespace: Namespace.ID? = nil  // MORPH: For matchedGeometryEffect morphing
    var showAlbumArt: Bool = true  // PREMIUM: Set to false when morphing is handled externally
    var showVisualizer: Bool = true  // PREMIUM: Set to false when morphing is handled externally
    var showTitle: Bool = true  // PREMIUM: Set to false when morphing is handled externally
    
    /// SSOT: Use HUDLayoutCalculator for consistent padding across all HUDs
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }

    
    /// Whether we're in Dynamic Island mode (screen-aware for multi-monitor)
    /// For HUD LAYOUT purposes: external displays always use compact layout (no physical notch)
    private var isDynamicIslandMode: Bool {
        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first
        // CRITICAL: Return false (notch mode) when screen is unavailable to prevent layout jumps
        guard let screen = screen else { return false }
        // Use auxiliary areas to detect notch (stable on lock screen)
        let hasNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
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
    /// PERFORMANCE: Uses cached value from MusicManager (computed once per track change)
    private var visualizerColor: Color {
        musicManager.visualizerColor
    }
    
    /// Secondary color from album art for gradient visualizer mode
    private var visualizerSecondaryColor: Color {
        musicManager.visualizerSecondaryColor
    }
    
    /// Whether gradient visualizer mode is enabled
    @AppStorage(AppPreferenceKey.enableGradientVisualizer) private var enableGradientVisualizer = PreferenceDefault.enableGradientVisualizer
    
    /// Width of each "wing" (area left/right of physical notch) - only used in notch mode
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Main HUD layout differs for Dynamic Island vs Notch mode
            if isDynamicIslandMode {
                // DYNAMIC ISLAND: Album on left, Visualizer on right, Title centered
                // SSOT: Use HUDLayoutCalculator for consistent padding across all modes/displays
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                let visualizerBarCount = 3
                let visualizerBarWidth: CGFloat = 2.0
                let visualizerSpacing: CGFloat = 1.5
                let visualizerHeight: CGFloat = max(14, iconSize - 2)
                let visualizerWidth = CGFloat(visualizerBarCount) * visualizerBarWidth + CGFloat(visualizerBarCount - 1) * visualizerSpacing
                
                ZStack {
                    // Title - truly centered in the island (both horizontally and vertically)
                    // PREMIUM: When showTitle is false, morphing is handled externally
                    if showTitle {
                        VStack {
                            Spacer(minLength: 0)
                            MarqueeText(text: musicManager.songTitle.isEmpty ? "Not Playing" : musicManager.songTitle, speed: 30, alignment: .center)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(height: 16, alignment: .center) // Fixed height, centered
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)  // Center horizontally
                        .padding(.horizontal, 36) // Leave space for album art and visualizer
                    }
                    
                    // Album art (left) and Visualizer (right)
                    HStack {
                        // Album art - matches icon size from other HUDs
                        // PREMIUM: matchedGeometryEffect goes BEFORE clipShape for morphing to work
                        // When showAlbumArt is false, morphing is handled externally - show invisible spacer
                        if showAlbumArt {
                            Group {
                                if musicManager.albumArt.size.width > 0 {
                                    Image(nsImage: musicManager.albumArt)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    RoundedRectangle(cornerRadius: iconSize / 2)  // Circular to match pill-shaped DI edges
                                        .fill(AdaptiveColors.overlayAuto(0.2))
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.white.opacity(0.5))
                                        )
                                }
                            }
                            .frame(width: iconSize, height: iconSize)
                            .modifier(AlbumArtMatchedGeometry(namespace: albumArtNamespace, id: "albumArt"))  // BEFORE clipShape!
                            .clipShape(RoundedRectangle(cornerRadius: iconSize / 2))  // Circular to match pill-shaped DI edges
                        } else {
                            // PREMIUM MORPH: External morphing - keep layout with invisible spacer
                            Color.clear.frame(width: iconSize, height: iconSize)
                        }
                        
                        Spacer()
                        
                        // Visualizer - harmonized to match icon size (18px for DI mode)
                        // PREMIUM: visualizer also uses matchedGeometryEffect for morphing
                        if showVisualizer {
                            AudioSpectrumView(
                                isPlaying: musicManager.isPlaying,
                                barCount: visualizerBarCount,
                                barWidth: visualizerBarWidth,
                                spacing: visualizerSpacing,
                                height: visualizerHeight,
                                color: visualizerColor,
                                secondaryColor: enableGradientVisualizer ? visualizerSecondaryColor : nil,
                                gradientMode: enableGradientVisualizer
                            )
                                .frame(width: visualizerWidth, height: visualizerHeight)
                                .modifier(AlbumArtMatchedGeometry(namespace: albumArtNamespace, id: "spectrum"))
                        } else {
                            Color.clear.frame(width: visualizerWidth, height: visualizerHeight)
                        }
                    }
                    .padding(.horizontal, symmetricPadding)  // Same as vertical for symmetry
                }
                .frame(height: notchHeight)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                // SSOT: Use HUDLayoutCalculator for consistent padding across all modes/displays
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                
                HStack(spacing: 0) {
                    // Left wing: Album art near left edge
                    HStack {
                        // PREMIUM: Album art with optional external morphing
                        if showAlbumArt {
                            Group {
                                if musicManager.albumArt.size.width > 0 {
                                    Image(nsImage: musicManager.albumArt)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    RoundedRectangle(cornerRadius: 5)  // ~25% of size for Apple-style rounded corners
                                        .fill(AdaptiveColors.overlayAuto(0.2))
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.white.opacity(0.5))
                                        )
                                }
                            }
                            .frame(width: iconSize, height: iconSize)
                            .modifier(AlbumArtMatchedGeometry(namespace: albumArtNamespace, id: "albumArt"))  // BEFORE clipShape!
                            .clipShape(RoundedRectangle(cornerRadius: 5))  // ~25% of size for Apple-style rounded corners
                        } else {
                            // PREMIUM MORPH: External morphing - keep layout with invisible spacer
                            Color.clear.frame(width: iconSize, height: iconSize)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, symmetricPadding)
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: notchWidth)
                    
                    // Right wing: Visualizer near right edge
                    HStack {
                        Spacer(minLength: 0)
                        if showVisualizer {
                            MiniAudioVisualizerBars(
                                isPlaying: musicManager.isPlaying,
                                color: visualizerColor,
                                secondaryColor: enableGradientVisualizer ? visualizerSecondaryColor : nil,
                                gradientMode: enableGradientVisualizer
                            )
                                .modifier(AlbumArtMatchedGeometry(namespace: albumArtNamespace, id: "spectrum"))  // Visualizer morphing
                        } else {
                            Color.clear.frame(width: 5 * 2.3 + 4 * 1.5, height: 16)
                        }
                    }
                    .padding(.trailing, symmetricPadding)
                    .frame(width: wingWidth)
                }
                .frame(height: notchHeight)
            }
            
            // NOTE: Hover text below notch removed - auto-expand is fast enough that users won't see it
        }
        // PREMIUM: Unified smooth animation for ALL transitions
        // This matches the morphing animation (.smooth(duration: 0.35)) for consistent feel
        .compositingGroup() // Unity Standard: animate as single layer
        .animation(DroppyAnimation.smooth(duration: 0.35, for: targetScreen), value: isHovered)
        .allowsHitTesting(true)
        .onTapGesture {
            withAnimation(DroppyAnimation.state) {
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
    var secondaryColor: Color? = nil  // For gradient mode
    var gradientMode: Bool = false    // Enable gradient across bars
    
    @StateObject private var audioAnalyzer = MiniAudioVisualizerState()
    
    var body: some View {
        AudioSpectrumView(
            isPlaying: isPlaying,
            barCount: 5,
            barWidth: 2.3,
            spacing: 1.5,
            height: 16,
            color: color,
            secondaryColor: secondaryColor,
            gradientMode: gradientMode,
            audioLevel: audioAnalyzer.audioLevel
        )
        .frame(width: 5 * 2.3 + 4 * 1.5, height: 16)
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

// MARK: - Subtle Scrolling Text for Long File Names

/// A text view that subtly scrolls horizontally to reveal long file names
/// - Centered when text fits, left-aligned with gradient fade when it overflows
/// - Only scrolls when hovered (not in static state)
/// - Very slow and subtle scroll speed for premium feel
/// - Scrolls to show full text, pauses, then scrolls back
/// - Uses fade edges for a premium look
struct SubtleScrollingText: View {
    let text: String
    var font: Font = .system(size: 10, weight: .medium)
    var foregroundStyle: AnyShapeStyle = AnyShapeStyle(.white.opacity(0.9))
    var maxWidth: CGFloat = 72
    var lineLimit: Int = 1
    var alignment: TextAlignment = .center
    /// Optional external hover state (e.g. whole-card hover). If nil, uses internal text hover.
    var externallyHovered: Bool? = nil
    
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isHovering: Bool = false
    @State private var scrollTask: Task<Void, Never>?
    @State private var isReturningToStart: Bool = false  // Keep scrolling view visible during return animation
    
    /// Points per second for marquee movement.
    private let marqueeSpeed: CGFloat = 34
    
    /// Whether text overflows the container (needs fade/scrolling)
    private var needsScroll: Bool {
        overflowWidth > 1 && containerWidth > 0 && textWidth > 0
    }
    
    private var overflowWidth: CGFloat {
        max(0, textWidth - containerWidth)
    }
    
    /// Keep center alignment when the text fits. Overflowing text anchors leading.
    private var effectiveAlignment: Alignment {
        needsScroll ? .leading : (alignment == .center ? .center : .leading)
    }
    
    private var isActiveHover: Bool {
        externallyHovered ?? isHovering
    }
    
    /// Preserve requested static line limit, but force single-line during marquee.
    private var effectiveLineLimit: Int {
        (needsScroll && isActiveHover) ? 1 : max(1, lineLimit)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Group {
                    if (isActiveHover || isReturningToStart) && needsScroll {
                        // Seamless marquee: duplicate label back-to-back and wrap offset continuously.
                        HStack(spacing: 0) {
                            Text(text)
                                .font(font)
                                .foregroundStyle(foregroundStyle)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Text(text)
                                .font(font)
                                .foregroundStyle(foregroundStyle)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .offset(x: -scrollOffset)
                        .frame(maxWidth: geo.size.width, alignment: .leading)
                    } else {
                        Text(text)
                            .font(font)
                            .foregroundStyle(foregroundStyle)
                            .lineLimit(effectiveLineLimit)
                            .fixedSize(horizontal: effectiveLineLimit == 1, vertical: false)
                            .frame(maxWidth: geo.size.width, alignment: effectiveAlignment)
                    }
                }
                    .clipped()
                    .background(
                        // Measure intrinsic single-line width for overflow/marquee decisions.
                        Text(text)
                            .font(font)
                            .lineLimit(1)
                            .fixedSize()
                            .hidden()
                            .background(
                                GeometryReader { textGeo in
                                    Color.clear
                                        .onAppear {
                                            textWidth = textGeo.size.width
                                        }
                                        .onChange(of: textGeo.size.width) { _, newWidth in
                                            textWidth = newWidth
                                        }
                                }
                            )
                    )
                    .mask(
                        HStack(spacing: 0) {
                            if isActiveHover && needsScroll && scrollOffset > 0.5 {
                                LinearGradient(
                                    colors: [.clear, .white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 10)
                            }
                            
                            Rectangle()
                            
                            // Keep right fade whenever overflowing.
                            if needsScroll {
                                LinearGradient(
                                    stops: [
                                        .init(color: .white, location: 0),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 12)
                            }
                        }
                    )
            }
            .onAppear {
                containerWidth = geo.size.width
                resetScroll(animated: false)
                if isActiveHover && needsScroll {
                    startHoverScroll()
                }
            }
            .onChange(of: geo.size.width) { _, newWidth in
                containerWidth = newWidth
                if isActiveHover && needsScroll {
                    startHoverScroll()
                } else {
                    stopHoverScroll()
                }
            }
            .onChange(of: text) { _, _ in
                resetScroll(animated: false)
                if isActiveHover && needsScroll {
                    startHoverScroll()
                }
            }
            .onChange(of: textWidth) { _, _ in
                if isActiveHover && needsScroll {
                    startHoverScroll()
                } else {
                    stopHoverScroll()
                }
            }
            .onChange(of: externallyHovered ?? false) { _, hovered in
                if hovered && needsScroll {
                    startHoverScroll()
                } else {
                    stopHoverScroll()
                }
            }
            .onDisappear {
                scrollTask?.cancel()
                scrollTask = nil
            }
            .onHover { hovering in
                // Ignore local text hover if an external hover source is driving this component.
                guard externallyHovered == nil else { return }
                isHovering = hovering
                if hovering && needsScroll {
                    startHoverScroll()
                } else {
                    stopHoverScroll()
                }
            }
        }
        .frame(width: maxWidth, height: 14)
    }
    
    private func resetScroll(animated: Bool) {
        scrollTask?.cancel()
        scrollTask = nil
        if animated {
            let progress = scrollOffset / max(1, textWidth)
            let duration = min(0.35, max(0.14, 0.12 + Double(progress) * 0.22))
            withAnimation(DroppyAnimation.easeOut(duration: duration)) {
                scrollOffset = 0
            }
        } else {
            scrollOffset = 0
        }
    }
    
    private func stopHoverScroll() {
        scrollTask?.cancel()
        scrollTask = nil
        
        // Skip animation if already at start
        guard scrollOffset > 0.5 else {
            scrollOffset = 0
            isReturningToStart = false
            return
        }
        
        // SMOOTH RETURN: Keep the scrolling view structure visible during animation
        isReturningToStart = true
        
        let progress = scrollOffset / max(1, textWidth)
        let duration = min(0.4, max(0.18, 0.15 + Double(progress) * 0.25))
        withAnimation(DroppyAnimation.easeOut(duration: duration)) {
            scrollOffset = 0
        }
        
        // Clear isReturningToStart after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.02) { [self] in
            isReturningToStart = false
        }
    }
    
    private func startHoverScroll() {
        guard isActiveHover && needsScroll else {
            stopHoverScroll()
            return
        }
        
        scrollTask?.cancel()
        scrollTask = Task { @MainActor in
            let hoverDelayNanos: UInt64 = 60_000_000
            let frameDelayNanos: UInt64 = 16_666_667
            try? await Task.sleep(nanoseconds: hoverDelayNanos)
            
            var lastTick = Date().timeIntervalSinceReferenceDate
            while !Task.isCancelled && isActiveHover && needsScroll {
                let now = Date().timeIntervalSinceReferenceDate
                let dt = min(max(now - lastTick, 0), 0.05)
                lastTick = now
                
                let cycleWidth = max(1, textWidth)
                scrollOffset += CGFloat(dt) * marqueeSpeed
                if scrollOffset >= cycleWidth {
                    scrollOffset.formTruncatingRemainder(dividingBy: cycleWidth)
                }
                
                try? await Task.sleep(nanoseconds: frameDelayNanos)
            }
        }
    }
}

struct MarqueeText: View {
    let text: String
    let speed: Double // Points per second (unused, kept for API compatibility)
    /// Optional external start time for synchronized scrolling across morphing transitions (unused, kept for API compatibility)
    var externalStartTime: Date? = nil
    /// Text alignment when text fits without overflow (default: .leading for backwards compatibility)
    var alignment: Alignment = .leading
    
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    
    private var needsFade: Bool {
        textWidth > containerWidth && containerWidth > 0 && textWidth > 0
    }
    
    /// Effective alignment: use provided alignment when text fits, always leading when scrolling/fading
    private var effectiveAlignment: Alignment {
        needsFade ? .leading : alignment
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Text(text)
                    .fixedSize()
                    .background(
                        GeometryReader { textGeo in
                            Color.clear
                                .onAppear {
                                    textWidth = textGeo.size.width
                                }
                                .onChange(of: text) { _, _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        textWidth = textGeo.size.width
                                    }
                                }
                        }
                    )
                    .frame(maxWidth: geo.size.width, alignment: effectiveAlignment.horizontal == .center ? .center : .leading)
                    // PREMIUM: Gradient mask to fade out right edge
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                            if needsFade {
                                LinearGradient(
                                    stops: [
                                        .init(color: .white, location: 0),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 35)
                            }
                        }
                    )
                
                // PREMIUM: Blurred overlay at fade edge for soft premium look
                if needsFade {
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(.clear)
                            .frame(width: 20)
                            .background(
                                Text(text)
                                    .fixedSize()
                                    .blur(radius: 6)
                                    .opacity(0.4)
                                    .mask(
                                        LinearGradient(
                                            colors: [.clear, .white],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .clipped()
                    }
                }
            }
            .onAppear {
                containerWidth = geo.size.width
            }
            .onChange(of: geo.size.width) { _, newWidth in
                containerWidth = newWidth
            }
        }
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
                            .fill(AdaptiveColors.overlayAuto(0.05))
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
                        .animation(DroppyAnimation.notchState, value: safeProgress)
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
