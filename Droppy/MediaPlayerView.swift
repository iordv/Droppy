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

// Components moved to MediaPlayerComponents.swift


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
