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
    case focus
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
        case .focus:
            return value > 0 ? "moon.fill" : "moon"
        }
    }
    
    /// Accent color for this HUD type
    var accentColor: Color {
        switch self {
        case .volume: return .white
        case .brightness: return .yellow
        case .battery: return .green
        case .capsLock: return .white
        case .focus: return Color(red: 0.55, green: 0.35, blue: 0.95)
        }
    }
    
    /// Display text for this HUD type
    func displayText(for value: CGFloat) -> String {
        switch self {
        case .volume, .brightness:
            let percent = Int(value * 100)
            return percent >= 100 ? "Max" : "\(percent)%"
        case .battery:
            let percent = Int(value * 100)
            return percent >= 100 ? "Full" : "\(percent)%"
        case .capsLock:
            return value > 0 ? "On" : "Off"
        case .focus:
            return value > 0 ? "On" : "Off"
        }
    }
    
    /// Whether to show the slider bar
    var showsSlider: Bool {
        switch self {
        case .volume, .brightness, .battery: return true
        case .capsLock, .focus: return false
        }
    }
}

/// Full media player view for the expanded notch
/// Native macOS design with album art, visualizer, and control buttons
struct MediaPlayerView: View {
    @ObservedObject var musicManager: MusicManager
    var notchHeight: CGFloat = 0  // Physical notch height to clear (0 for Dynamic Island)
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
    @ObservedObject private var dndManager = DNDManager.shared
    
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
    // Edge padding - reduced to push content closer to edges
    private let edgePadding: CGFloat = 12
    // Album art size - VStack must match this height for perfect symmetry
    private let albumArtSize: CGFloat = 100
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !musicManager.isPlaying && !isDragging)) { context in
            let currentDate = context.date
            
            // MARK: - Horizontal Layout: Big Album Art Left | Controls Right
            HStack(alignment: .top, spacing: 16) {
                // MARK: - Left: Large Album Art (100x100) with glow
                albumArtViewLarge
                
                // MARK: - Right: Stacked Controls
                VStack(alignment: .leading, spacing: 4) {
                    // Row 1: Song Title + Visualizer
                    let songTitle = musicManager.songTitle.isEmpty ? "Not Playing" : musicManager.songTitle
                    HStack(spacing: 8) {
                        Text(songTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Spacer(minLength: 4)
                        
                        // Audio Visualizer (colored by album art)
                        AudioVisualizerBars(isPlaying: musicManager.isPlaying, color: visualizerColor)
                            .frame(width: 28, height: 18)
                    }
                    
                    // Row 2: Artist Name
                    let artistName = musicManager.artistName.isEmpty ? "—" : musicManager.artistName
                    Text(artistName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer(minLength: 0)
                    
                    // Row 3: Progress Bar with Timestamps
                    HStack(spacing: 8) {
                        Text(elapsedTimeString(at: currentDate))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .leading)
                        
                        progressSliderView(at: currentDate)
                        
                        Text(remainingTimeString())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    // Row 4: Media Controls (centered)
                    controlsRowCompact
                }
                .frame(maxWidth: .infinity, minHeight: albumArtSize, maxHeight: albumArtSize)
            }
            // Use SSOT for consistent padding across all expanded views
            .padding(NotchLayoutConstants.contentEdgeInsets(notchHeight: notchHeight))
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
        .onChange(of: dndManager.lastChangeAt) { _, _ in
            triggerInlineHUD(.focus, value: dndManager.isDNDActive ? 1.0 : 0.0)
        }
        // Right-click context menu to hide the notch/island (same as notch background)
        .contextMenu {
            Button("Hide \(NotchWindowController.shared.displayModeLabel)") {
                NotchWindowController.shared.setTemporarilyHidden(true)
            }
            Divider()
            Button("Settings...") {
                SettingsWindowController.shared.showSettings()
            }
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
        case .focus: duration = dndManager.visibleDuration
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
            // Composite the entire view before applying shadow to prevent ghosting during animations
            .compositingGroup()
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
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
    
    // MARK: - Large Album Art (for horizontal layout)
    
    private var albumArtViewLarge: some View {
        ZStack {
            // MARK: - Album Art Glow (very subtle blurred halo)
            if musicManager.albumArt.size.width > 0 && musicManager.isPlaying {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .blur(radius: 18)
                    .scaleEffect(1.05)
                    .opacity(0.2)
            }
            
            // MARK: - Actual Album Art Button
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
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.white.opacity(0.3))
                                )
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    // Spotify badge (bottom-right corner)
                    if musicManager.isSpotifySource {
                        SpotifyBadge()
                            .offset(x: 5, y: 5)
                    }
                }
                // Subtle border highlight
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .compositingGroup()
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .scaleEffect(isAlbumArtPressed ? 0.96 : (isAlbumArtHovering ? 1.02 : 1.0))
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
        .animation(.easeInOut(duration: 0.4), value: musicManager.isPlaying)
    }
    
    // MARK: - Progress Slider
    
    private func progressSliderView(at date: Date) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let currentProgress = progress(at: date)
            let progressWidth = max(0, min(width, width * currentProgress))
            // Expand track height when dragging (5pt → 9pt)
            let trackHeight: CGFloat = isDragging ? 9 : 5
            
            ZStack(alignment: .leading) {
                // Track background (subtle, tinted by album art)
                Capsule()
                    .fill(visualizerColor.opacity(isDragging ? 0.3 : 0.15))
                    .frame(height: trackHeight)
                
                // Filled portion (tinted by album art with glow when dragging)
                if currentProgress > 0 {
                    Capsule()
                        .fill(visualizerColor.opacity(0.9))
                        .frame(width: max(trackHeight, progressWidth), height: trackHeight)
                        .shadow(color: isDragging ? visualizerColor.opacity(0.5) : .clear, radius: isDragging ? 6 : 0)
                }
            }
            .frame(height: trackHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isDragging)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                            isDragging = true
                        }
                        let fraction = max(0, min(1, value.location.x / width))
                        dragValue = Double(fraction) * musicManager.songDuration
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / width))
                        let seekTime = Double(fraction) * musicManager.songDuration
                        musicManager.seek(to: seekTime)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
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
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: inlineHUDType != nil)
        .allowsHitTesting(true)
    }
    
    // MARK: - Compact Controls Row (for horizontal layout)
    
    @ViewBuilder
    private var controlsRowCompact: some View {
        let isSpotify = musicManager.isSpotifySource
        let spotify = musicManager.spotifyController
        let spotifyGreen = Color(red: 0.11, green: 0.73, blue: 0.33)
        
        ZStack {
            // Compact centered controls
            HStack(spacing: 20) {
                // Shuffle (Spotify only)
                if isSpotify {
                    SpotifyControlButton(
                        icon: "shuffle",
                        isActive: spotify.shuffleEnabled,
                        accentColor: spotifyGreen,
                        size: 16
                    ) {
                        spotify.toggleShuffle()
                    }
                }
                
                // Previous
                MediaControlButton(icon: "backward.fill", size: 18, tapPadding: 6) {
                    musicManager.previousTrack()
                }
                
                // Play/Pause (slightly larger)
                MediaControlButton(
                    icon: musicManager.isPlaying ? "pause.fill" : "play.fill",
                    size: 24,
                    tapPadding: 6
                ) {
                    musicManager.togglePlay()
                }
                
                // Next
                MediaControlButton(icon: "forward.fill", size: 18, tapPadding: 6) {
                    musicManager.nextTrack()
                }
                
                // Repeat (Spotify only)
                if isSpotify {
                    SpotifyControlButton(
                        icon: spotify.repeatMode.iconName,
                        isActive: spotify.repeatMode != .off,
                        accentColor: spotifyGreen,
                        size: 16
                    ) {
                        spotify.cycleRepeatMode()
                    }
                }
            }
            .opacity(inlineHUDType != nil ? 0 : 1)
            .scaleEffect(inlineHUDType != nil ? 0.9 : 1)
            
            // Inline HUD overlay
            if let hudType = inlineHUDType {
                InlineHUDView(type: hudType, value: inlineHUDValue)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: inlineHUDType != nil)
    }
}

// Components moved to MediaPlayerComponents.swift


// MARK: - Preview

#Preview("Media Player - Horizontal Layout") {
    VStack {
        MediaPlayerView(musicManager: MusicManager.shared)
            .frame(width: 480, height: 130)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
