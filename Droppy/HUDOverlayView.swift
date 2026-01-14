//
//  HUDOverlayView.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  System HUD replacement that expands inside the notch
//

import SwiftUI

// HUDContentType is defined in LiquidSlider.swift

/// Helper to format HUD percentage - shows "MAX" instead of "100%"
private func hudPercentageText(_ value: CGFloat) -> String {
    let percent = Int(value * 100)
    return percent >= 100 ? "MAX" : "\(percent)%"
}

/// Embedded HUD view that appears inside the expanded notch
/// Icon on left wing, percentage on right wing, slider at bottom (full width)
/// Layout matches MediaHUDView for consistent positioning
struct NotchHUDView: View {
    @Binding var hudType: HUDContentType
    @Binding var value: CGFloat
    var isActive: Bool = true // Whether value is currently changing (for slider thickening)
    let notchWidth: CGFloat   // Physical notch width (passed from parent)
    let notchHeight: CGFloat  // Physical notch height (passed from parent)
    let hudWidth: CGFloat     // Total HUD width (passed from parent)
    var onValueChange: ((CGFloat) -> Void)?
    
    /// Whether we're in Dynamic Island mode
    private var isDynamicIslandMode: Bool {
        guard let screen = NSScreen.main else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    /// Width of each "wing" (area left/right of physical notch) - only used in notch mode
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if isDynamicIslandMode {
                // DYNAMIC ISLAND: Compact horizontal layout, all content in one row
                // Standardized sizing: 18px icons, 13pt text, 14px horizontal padding
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: hudType.icon(for: value))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(hudType == .brightness ? .yellow : .white)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolVariant(.fill)
                        .frame(width: 20, height: 20)
                    
                    // Mini slider - expands to fill available space
                    HUDSlider(
                        value: $value,
                        accentColor: hudType == .brightness ? .yellow : .white,
                        isActive: isActive,
                        onChange: onValueChange
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 16)
                    
                    // Percentage
                    Text(hudPercentageText(value))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: value))
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .frame(height: notchHeight)
            } else {
                // NOTCH MODE: Main HUD - Two wings separated by the notch space
                // Icons use fixed 16px padding to align with slider edges below
                HStack(spacing: 0) {
                    // Left wing: Icon aligned with slider left edge
                    HStack {
                        Image(systemName: hudType.icon(for: value))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(hudType == .brightness ? .yellow : .white)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolVariant(.fill)
                            .frame(width: 26, height: 26)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hudType.icon(for: value))
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 16)  // Align with slider's 16px left padding
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: notchWidth)
                    
                    // Right wing: Percentage aligned with slider right edge
                    HStack {
                        Spacer(minLength: 0)
                        Text(hudPercentageText(value))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: value))
                            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: value)
                    }
                    .padding(.trailing, 16)  // Align with slider's 16px right padding
                    .frame(width: wingWidth)
                }
                .frame(height: notchHeight)
                
                // Below notch: Slider (same style as seek slider in expanded media player)
                HUDSlider(
                    value: $value,
                    accentColor: hudType == .brightness ? .yellow : .white,
                    isActive: isActive,
                    onChange: onValueChange
                )
                .frame(height: 20)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .animation(.spring(response: 0.15, dampingFraction: 0.8), value: value)
            }
        }
    }
}

// MARK: - HUD Slider (matches seek slider in expanded media player)

/// Interactive slider matching MediaPlayerView's seek slider style
/// Simple solid colors, 4px→6px height when active, subtle glow
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
                
                // Filled portion (solid color with glow when active)
                if progress > 0 {
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(trackHeight, progressWidth), height: trackHeight)
                        .shadow(color: isExpanded ? accentColor.opacity(0.4) : .clear, radius: isExpanded ? 4 : 0)
                }
            }
            .frame(height: trackHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .scaleEffect(y: isExpanded ? 1.1 : 1.0, anchor: .center)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isExpanded)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
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
    
    /// Whether we're in Dynamic Island mode
    private var isDynamicIslandMode: Bool {
        guard let screen = NSScreen.main else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
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
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
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
                DroppyState.shared.isExpanded = true
            }
        }
    }
}

/// Mini audio visualizer bars for compact HUD
/// Uses BoringNotch-style CAShapeLayer animation with album art color
struct MiniAudioVisualizerBars: View {
    let isPlaying: Bool
    var color: Color = .white
    
    var body: some View {
        AudioSpectrumView(isPlaying: isPlaying, barCount: 5, barWidth: 3, spacing: 2, height: 18, color: color)
            .frame(width: 5 * 3 + 4 * 2, height: 18) // 5 bars * 3px + 4 gaps * 2px = 23px
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
struct HUDOverlayView: View {
    @Binding var isVisible: Bool
    @Binding var hudType: HUDContentType
    @Binding var value: CGFloat
    
    var onValueChange: ((CGFloat) -> Void)?
    
    @State private var animatedValue: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon with dynamic symbol
            Image(systemName: hudType.icon(for: value))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.interpolate)
                .symbolVariant(.fill)
                .frame(width: 24, height: 20)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            
            // Slider
            LiquidSlider(
                value: $value,
                accentColor: hudType == .brightness ? .yellow : .white,
                onChange: { newValue in
                    onValueChange?(newValue)
                },
                onDragChange: { newValue in
                    onValueChange?(newValue)
                }
            )
            .frame(width: 160)
            
            // Percentage
            Text(hudPercentageText(value))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(hudBackground)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
        .offset(y: isVisible ? 0 : -10)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isVisible)
        .onChange(of: value) { _, newValue in
            withAnimation(.smooth(duration: 0.1)) {
                animatedValue = newValue
            }
        }
    }
    
    private var hudBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.6))
            )
            // Specular rim lighting
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.4), location: 0),
                                .init(color: .white.opacity(0.1), location: 0.3),
                                .init(color: .black.opacity(0.2), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }
}

// MARK: - HUD State Manager

/// Manages the HUD overlay state and auto-hide timing
@Observable
class HUDStateManager {
    static let shared = HUDStateManager()
    
    var isVisible: Bool = false
    var hudType: HUDContentType = .volume
    var value: CGFloat = 0
    
    private var hideTask: Task<Void, Never>?
    private let visibleDuration: TimeInterval = 1.5
    
    private init() {}
    
    /// Show the HUD with the given type and value
    func show(type: HUDContentType, value: CGFloat) {
        hideTask?.cancel()
        
        self.hudType = type
        self.value = value
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            self.isVisible = true
        }
        
        // Schedule auto-hide
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(visibleDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.isVisible = false
            }
        }
    }
    
    /// Hide the HUD immediately
    func hide() {
        hideTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isVisible = false
        }
    }
    
    /// Update value while HUD is visible (resets auto-hide timer)
    func updateValue(_ newValue: CGFloat) {
        value = newValue
        // Reset auto-hide timer
        show(type: hudType, value: newValue)
    }
}

// MARK: - Preview

#Preview("Notch HUD") {
    ZStack {
        Color.gray.opacity(0.3)
        
        VStack {
            // Simulate notch background
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black)
                .frame(width: 280, height: 90)
                .overlay {
                    NotchHUDView(
                        hudType: .constant(.volume),
                        value: .constant(0.65),
                        notchWidth: 180,
                        notchHeight: 37,
                        hudWidth: 280
                    )
                }
            
            Spacer().frame(height: 40)
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black)
                .frame(width: 280, height: 90)
                .overlay {
                    NotchHUDView(
                        hudType: .constant(.brightness),
                        value: .constant(0.4),
                        notchWidth: 180,
                        notchHeight: 37,
                        hudWidth: 280
                    )
                }
        }
    }
    .frame(width: 400, height: 300)
}
