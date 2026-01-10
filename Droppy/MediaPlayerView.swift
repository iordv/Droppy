//
//  MediaPlayerView.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  Native macOS-style media player for the expanded notch
//

import SwiftUI

// MARK: - Inline HUD Type

/// Universal HUD types for the expanded media player
/// To add a new HUD: 1) Add case here, 2) Add observer in MediaPlayerView
enum InlineHUDType: Equatable {
    case volume
    case brightness
    case battery
    case capsLock
    // Add new HUD types here
    
    /// Icon for this HUD type based on current value
    func icon(for value: CGFloat) -> String {
        switch self {
        case .volume:
            if value <= 0 { return "speaker.slash.fill" }
            else if value < 0.33 { return "speaker.wave.1.fill" }
            else if value < 0.66 { return "speaker.wave.2.fill" }
            else { return "speaker.wave.3.fill" }
        case .brightness:
            return value < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .battery:
            if value <= 0.1 { return "battery.0percent" }
            else if value <= 0.25 { return "battery.25percent" }
            else if value <= 0.5 { return "battery.50percent" }
            else if value <= 0.75 { return "battery.75percent" }
            else { return "battery.100percent" }
        case .capsLock:
            return value > 0 ? "capslock.fill" : "capslock"
        }
    }
    
    /// Accent color for this HUD type
    var accentColor: Color {
        switch self {
        case .volume: return .white
        case .brightness: return .yellow
        case .battery: return .green
        case .capsLock: return .white
        }
    }
    
    /// Display text for this HUD type
    func displayText(for value: CGFloat) -> String {
        switch self {
        case .volume, .brightness:
            let percent = Int(value * 100)
            return percent >= 100 ? "MAX" : "\(percent)%"
        case .battery:
            let percent = Int(value * 100)
            return percent >= 100 ? "MAX" : "\(percent)%"
        case .capsLock:
            return value > 0 ? "ON" : "OFF"
        }
    }
    
    /// Whether to show the slider bar
    var showsSlider: Bool {
        switch self {
        case .volume, .brightness, .battery: return true
        case .capsLock: return false
        }
    }
}

/// Full media player view for the expanded notch
/// Native macOS design with album art, visualizer, and control buttons
struct MediaPlayerView: View {
    @ObservedObject var musicManager: MusicManager
    @State private var isDragging: Bool = false
    @State private var dragValue: Double = 0
    @State private var lastDragTime: Date = .distantPast
    @State private var isAlbumArtPressed: Bool = false
    @State private var isAlbumArtHovering: Bool = false
    
    // MARK: - Observed Managers for Fast HUD Updates
    @ObservedObject private var volumeManager = VolumeManager.shared
    @ObservedObject private var brightnessManager = BrightnessManager.shared
    @ObservedObject private var batteryManager = BatteryManager.shared
    @ObservedObject private var capsLockManager = CapsLockManager.shared
    
    // MARK: - Universal Inline HUD State
    // Handles all HUD types: volume, brightness, battery, caps lock, etc.
    @State private var inlineHUDType: InlineHUDType? = nil
    @State private var inlineHUDValue: CGFloat = 0.5
    @State private var inlineHUDHideWorkItem: DispatchWorkItem?
    
    /// Dominant color from album art for visualizer
    private var visualizerColor: Color {
        if musicManager.albumArt.size.width > 0 {
            return musicManager.albumArt.dominantColor()
        }
        return .white.opacity(0.7)
    }
    
    /// Compute estimated position at given date
    private func estimatedPosition(at date: Date) -> Double {
        musicManager.estimatedPlaybackPosition(at: date)
    }
    
    /// Progress as fraction (0.0 - 1.0)
    private func progress(at date: Date) -> CGFloat {
        guard musicManager.songDuration > 0 else { return 0 }
        let pos = isDragging ? dragValue : estimatedPosition(at: date)
        return CGFloat(min(1, max(0, pos / musicManager.songDuration)))
    }
    
    /// Formatted elapsed time (mm:ss)
    private func elapsedTimeString(at date: Date) -> String {
        let seconds = isDragging ? dragValue : estimatedPosition(at: date)
        return timeString(from: seconds)
    }
    
    /// Formatted remaining/total time
    private func remainingTimeString() -> String {
        return timeString(from: musicManager.songDuration)
    }
    
    private func timeString(from seconds: Double) -> String {
        let totalSeconds = Int(max(0, seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !musicManager.isPlaying && !isDragging)) { context in
            let currentDate = context.date
            
            VStack(spacing: 16) {
                // MARK: - Top Row: Album Art + Song Info + Visualizer
                HStack(spacing: 14) {
                    // Album Art
                    albumArtView
                    
                    // Song info (title + artist)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(musicManager.songTitle.isEmpty ? "Not Playing" : musicManager.songTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(musicManager.artistName.isEmpty ? "—" : musicManager.artistName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Audio Visualizer (right side, colored by album art)
                    AudioVisualizerBars(isPlaying: musicManager.isPlaying, color: visualizerColor)
                        .frame(width: 32, height: 20)
                }
                
                // MARK: - Middle Row: Time + Slider
                HStack(spacing: 0) {
                    // Current time - aligned to left edge (same as album art)
                    Text(elapsedTimeString(at: currentDate))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: 56, alignment: .leading)
                    
                    Spacer().frame(width: 8)
                    
                    // Progress Slider
                    progressSliderView(at: currentDate)
                    
                    Spacer().frame(width: 8)
                    
                    // Total time - aligned to right edge (same as visualizer)
                    Text(remainingTimeString())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: 56, alignment: .trailing)
                }
                
                // MARK: - Bottom Row: Controls
                controlsRow
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        // MARK: - Universal Inline HUD Observers
        // Uses local @ObservedObject references for snappy updates
        .onChange(of: volumeManager.lastChangeAt) { _, _ in
            triggerInlineHUD(.volume, value: CGFloat(volumeManager.rawVolume))
        }
        .onChange(of: brightnessManager.lastChangeAt) { _, _ in
            triggerInlineHUD(.brightness, value: CGFloat(brightnessManager.rawBrightness))
        }
        .onChange(of: batteryManager.lastChangeAt) { _, _ in
            triggerInlineHUD(.battery, value: CGFloat(batteryManager.batteryLevel) / 100.0)
        }
        .onChange(of: capsLockManager.lastChangeAt) { _, _ in
            triggerInlineHUD(.capsLock, value: capsLockManager.isCapsLockOn ? 1.0 : 0.0)
        }
    }
    
    // MARK: - Universal Inline HUD Trigger
    
    /// Trigger any inline HUD type in the media player
    /// Matches exact timing from NotchShelfView's triggerVolumeHUD
    private func triggerInlineHUD(_ type: InlineHUDType, value: CGFloat) {
        // Cancel any pending hide
        inlineHUDHideWorkItem?.cancel()
        
        // Update type and value INSTANTLY (no animation - matches regular HUD)
        inlineHUDType = type
        inlineHUDValue = value
        
        // Animate visibility on (same as regular HUD: spring 0.3, 0.7)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // Already set, but this triggers the animation
        }
        
        // Get visible duration from the appropriate manager (matches regular HUD)
        let duration: TimeInterval
        switch type {
        case .volume: duration = volumeManager.visibleDuration
        case .brightness: duration = brightnessManager.visibleDuration
        case .battery: duration = batteryManager.visibleDuration
        case .capsLock: duration = capsLockManager.visibleDuration
        }
        
        // Hide after duration (same as regular HUD: easeOut 0.3)
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.3)) {
                inlineHUDType = nil
            }
        }
        inlineHUDHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }
    
    // MARK: - Album Art
    
    private var albumArtView: some View {
        Button {
            musicManager.openMusicApp()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if musicManager.albumArt.size.width > 0 {
                        Image(nsImage: musicManager.albumArt)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.4))
                            )
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Spotify badge (bottom-right corner)
                if musicManager.isSpotifySource {
                    SpotifyBadge()
                        .offset(x: 4, y: 4)
                }
            }
            // Subtle border highlight
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isAlbumArtPressed ? 0.95 : (isAlbumArtHovering ? 1.02 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isAlbumArtPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAlbumArtHovering)
        .onHover { hovering in
            isAlbumArtHovering = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isAlbumArtPressed = true
                }
                .onEnded { _ in
                    isAlbumArtPressed = false
                }
        )
    }
    
    // MARK: - Progress Slider
    
    private func progressSliderView(at date: Date) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let currentProgress = progress(at: date)
            let progressWidth = max(0, min(width, width * currentProgress))
            // Expand track height when dragging
            let trackHeight: CGFloat = isDragging ? 6 : 4
            
            ZStack(alignment: .leading) {
                // Track background (dark gray)
                Capsule()
                    .fill(Color.white.opacity(isDragging ? 0.3 : 0.2))
                    .frame(height: trackHeight)
                
                // Filled portion (white with glow when dragging)
                if currentProgress > 0 {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(trackHeight, progressWidth), height: trackHeight)
                        .shadow(color: isDragging ? .white.opacity(0.4) : .clear, radius: isDragging ? 4 : 0)
                }
            }
            .frame(height: trackHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .scaleEffect(y: isDragging ? 1.1 : 1.0, anchor: .center)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isDragging = true
                        }
                        let fraction = max(0, min(1, value.location.x / width))
                        dragValue = Double(fraction) * musicManager.songDuration
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / width))
                        let seekTime = Double(fraction) * musicManager.songDuration
                        musicManager.seek(to: seekTime)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            isDragging = false
                        }
                        lastDragTime = Date()
                    }
            )
        }
        .frame(height: 20)
    }
    
    // MARK: - Controls Row
    
    @ViewBuilder
    private var controlsRow: some View {
        let isSpotify = musicManager.isSpotifySource
        let spotify = musicManager.spotifyController
        
        // Spotify's signature green
        let spotifyGreen = Color(red: 0.11, green: 0.73, blue: 0.33)
        
        // ZStack for morphing between controls and volume indicator
        ZStack {
            // MARK: - Playback Controls (hide when volume shown)
            HStack(spacing: 0) {
                // Left side: Shuffle (Spotify only) or spacer
                if isSpotify {
                    SpotifyControlButton(
                        icon: "shuffle",
                        isActive: spotify.shuffleEnabled,
                        accentColor: spotifyGreen
                    ) {
                        spotify.toggleShuffle()
                    }
                } else {
                    Spacer()
                        .frame(width: 40)
                }
                
                Spacer()
                
                // Center: Core playback controls
                HStack(spacing: 32) {
                    // Previous
                    MediaControlButton(icon: "backward.fill", size: 24) {
                        musicManager.previousTrack()
                    }
                    
                    // Play/Pause (larger)
                    MediaControlButton(
                        icon: musicManager.isPlaying ? "pause.fill" : "play.fill",
                        size: 32
                    ) {
                        musicManager.togglePlay()
                    }
                    
                    // Next
                    MediaControlButton(icon: "forward.fill", size: 24) {
                        musicManager.nextTrack()
                    }
                }
                
                Spacer()
                
                // Right side: Repeat (Spotify only) or spacer
                if isSpotify {
                    SpotifyControlButton(
                        icon: spotify.repeatMode.iconName,
                        isActive: spotify.repeatMode != .off,
                        accentColor: spotifyGreen
                    ) {
                        spotify.cycleRepeatMode()
                    }
                } else {
                    Spacer()
                        .frame(width: 40)
                }
            }
            .opacity(inlineHUDType != nil ? 0 : 1)
            .scaleEffect(inlineHUDType != nil ? 0.9 : 1)
            
            // MARK: - Universal Inline HUD (morphs in for any HUD type)
            if let hudType = inlineHUDType {
                InlineHUDView(type: hudType, value: inlineHUDValue)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: inlineHUDType != nil)
        .allowsHitTesting(true)
    }
}

// MARK: - Universal Inline HUD View

/// Universal inline HUD that morphs into the controls row
/// Supports all HUD types: volume, brightness, battery, caps lock, etc.
/// Uses same animations as HUDSlider for consistency
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

/// Animated audio visualizer bars (BoringNotch-style CAShapeLayer animation)
struct AudioVisualizerBars: View {
    let isPlaying: Bool
    var color: Color = .white
    
    var body: some View {
        AudioSpectrumView(isPlaying: isPlaying, barCount: 5, barWidth: 3, spacing: 2, height: 20, color: color)
            .frame(width: 5 * 3 + 4 * 2, height: 20) // 5 bars * 3px + 4 gaps * 2px
    }
}

// MARK: - Spotify Badge

/// Small Spotify logo badge for album art overlay
struct SpotifyBadge: View {
    var body: some View {
        Image("SpotifyIcon")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
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
