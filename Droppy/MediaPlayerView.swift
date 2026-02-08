//
//  MediaPlayerView.swift
//  Droppy
//
//  Created by Droppy on 05/01/2026.
//  Native macOS-style media player for the expanded notch
//

import SwiftUI
import AppKit

// MARK: - Scroll Wheel Capture (fixes swipe not working when cursor stationary)

/// Captures scroll wheel events using NSEvent local monitor
/// This fixes the bug where horizontal swipe only works after moving the cursor
private struct ScrollWheelCaptureModifier: ViewModifier {
    var onHorizontalScroll: (CGFloat) -> Void
    @State private var monitor: Any?
    @State private var accumulatedScrollX: CGFloat = 0
    @State private var lastScrollTime: Date = .distantPast
    @State private var viewFrame: CGRect = .zero
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: FramePreferenceKey.self, value: geo.frame(in: .global))
                }
            )
            .onPreferenceChange(FramePreferenceKey.self) { frame in
                viewFrame = frame
            }
            .onAppear {
                setupMonitor()
            }
            .onDisappear {
                removeMonitor()
            }
    }
    
    private func setupMonitor() {
        guard monitor == nil else { return }
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
            // Check if mouse is over this view's frame
            let mouseLocation = NSEvent.mouseLocation
            
            // Convert to same coordinate system
            guard let screen = NSScreen.main else { return event }
            let screenFrame = screen.frame
            let flippedY = screenFrame.height - mouseLocation.y
            let flippedLocation = CGPoint(x: mouseLocation.x, y: flippedY)
            
            // Check if mouse is in the view
            guard viewFrame.contains(flippedLocation) || viewFrame.contains(mouseLocation) else {
                return event
            }
            
            // Reset accumulated scroll if too much time passed
            if Date().timeIntervalSince(lastScrollTime) > 0.3 {
                accumulatedScrollX = 0
            }
            lastScrollTime = Date()
            
            // Accumulate horizontal scroll
            accumulatedScrollX += event.scrollingDeltaX
            
            // Only handle when clearly horizontal swipe
            guard abs(accumulatedScrollX) > abs(event.scrollingDeltaY) * 1.5 else {
                return event
            }
            
            let threshold: CGFloat = 30
            
            if abs(accumulatedScrollX) > threshold {
                let scrollValue = accumulatedScrollX
                accumulatedScrollX = 0
                DispatchQueue.main.async {
                    onHorizontalScroll(scrollValue)
                }
            }
            
            return event
        }
    }
    
    private func removeMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}

private struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private extension View {
    func captureHorizontalScroll(action: @escaping (CGFloat) -> Void) -> some View {
        modifier(ScrollWheelCaptureModifier(onHorizontalScroll: action))
    }
}

// MARK: - Inline HUD Type

/// Universal HUD types for the expanded media player
/// To add a new HUD: 1) Add case here, 2) Add observer in MediaPlayerView
enum InlineHUDType: Equatable {
    case volume
    case brightness
    case battery
    case capsLock
    case focus
    case airPods
    case lockScreen
    case update
    // Add new HUD types here
    
    /// Icon for this HUD type based on current value
    func icon(for value: CGFloat, isCharging: Bool = false) -> String {
        switch self {
        case .volume:
            if value <= 0 { return "speaker.slash.fill" }
            else if value < 0.33 { return "speaker.wave.1.fill" }
            else if value < 0.66 { return "speaker.wave.2.fill" }
            else { return "speaker.wave.3.fill" }
        case .brightness:
            return value < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .battery:
            if isCharging { return "battery.100percent.bolt" }
            if value <= 0.1 { return "battery.0percent" }
            else if value <= 0.25 { return "battery.25percent" }
            else if value <= 0.5 { return "battery.50percent" }
            else if value <= 0.75 { return "battery.75percent" }
            else { return "battery.100percent" }
        case .capsLock:
            return value > 0 ? "capslock.fill" : "capslock"
        case .focus:
            return value > 0 ? "moon.fill" : "moon"
        case .airPods:
            return "airpodspro"
        case .lockScreen:
            return value > 0 ? "lock.fill" : "lock.open.fill"
        case .update:
            return "arrow.down.circle.fill"
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
        case .airPods: return Color(white: 0.92)
        case .lockScreen: return .white
        case .update: return Color(red: 0.41, green: 0.71, blue: 1.0)
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
        case .airPods:
            return "Connected"
        case .lockScreen:
            return value > 0 ? "Locked" : "Unlocked"
        case .update:
            return "Update"
        }
    }
    
    /// Whether to show the slider bar
    var showsSlider: Bool {
        switch self {
        case .volume, .brightness, .battery: return true
        case .capsLock, .focus, .airPods, .lockScreen, .update: return false
        }
    }
}

/// Full media player view for the expanded notch
/// Native macOS design with album art, visualizer, and control buttons
struct MediaPlayerView: View {
    @ObservedObject var musicManager: MusicManager
    var notchHeight: CGFloat = 0  // Physical notch height to clear (0 for Dynamic Island)
    var isExternalWithNotchStyle: Bool = false  // External display with curved notch style
    var albumArtNamespace: Namespace.ID? = nil  // MORPH: For matchedGeometryEffect morphing
    var showAlbumArt: Bool = true  // PREMIUM: Set to false when morphing is handled externally
    var showVisualizer: Bool = true  // PREMIUM: Set to false when morphing is handled externally
    var showTitle: Bool = true  // PREMIUM: Set to false when morphing is handled externally
    @State private var contentAppeared: Bool = false  // Local animation state - syncs with container
    @State private var isDragging: Bool = false
    @State private var dragValue: Double = 0
    @State private var lastDragTime: Date = .distantPast
    @State private var isAlbumArtPressed: Bool = false
    @State private var isAlbumArtHovering: Bool = false
    @State private var albumArtFlipAngle: Double = 0  // For track change flip animation
    @State private var albumArtPauseScale: CGFloat = 1.0  // For pause/play scale animation
    
    // MARK: - Observed Managers for Fast HUD Updates
    @ObservedObject private var volumeManager = VolumeManager.shared
    @ObservedObject private var brightnessManager = BrightnessManager.shared
    @ObservedObject private var batteryManager = BatteryManager.shared
    @ObservedObject private var capsLockManager = CapsLockManager.shared
    @ObservedObject private var dndManager = DNDManager.shared
    var airPodsManager = AirPodsManager.shared  // @Observable - no wrapper needed
    @ObservedObject private var lockScreenManager = LockScreenManager.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    
    // MARK: - Preferences
    @AppStorage(AppPreferenceKey.enableRightClickHide) private var enableRightClickHide = PreferenceDefault.enableRightClickHide
    @AppStorage(AppPreferenceKey.enableGradientVisualizer) private var enableGradientVisualizer = PreferenceDefault.enableGradientVisualizer
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.enableHUDReplacement) private var enableHUDReplacement = PreferenceDefault.enableHUDReplacement
    @AppStorage(AppPreferenceKey.enableBatteryHUD) private var enableBatteryHUD = PreferenceDefault.enableBatteryHUD
    @AppStorage(AppPreferenceKey.enableCapsLockHUD) private var enableCapsLockHUD = PreferenceDefault.enableCapsLockHUD
    @AppStorage(AppPreferenceKey.enableAirPodsHUD) private var enableAirPodsHUD = PreferenceDefault.enableAirPodsHUD
    @AppStorage(AppPreferenceKey.enableLockScreenHUD) private var enableLockScreenHUD = PreferenceDefault.enableLockScreenHUD
    @AppStorage(AppPreferenceKey.enableDNDHUD) private var enableDNDHUD = PreferenceDefault.enableDNDHUD
    @AppStorage(AppPreferenceKey.enableUpdateHUD) private var enableUpdateHUD = PreferenceDefault.enableUpdateHUD
    
    // MARK: - Universal Inline HUD State
    // Handles all HUD types: volume, brightness, battery, caps lock, etc.
    @State private var inlineHUDType: InlineHUDType? = nil
    @State private var inlineHUDValue: CGFloat = 0.5
    @State private var inlineHUDMuted: Bool = false  // PREMIUM: Explicit mute state for volume
    @State private var inlineHUDBatteryCharging: Bool = false
    @State private var inlineHUDSymbolOverride: String? = nil
    @State private var inlineHUDHideWorkItem: DispatchWorkItem?
    
    /// Dominant color from album art for visualizer
    /// PERFORMANCE: Uses cached value from MusicManager (computed once per track change)
    private var visualizerColor: Color {
        musicManager.visualizerColor
    }
    
    /// Secondary color from album art for gradient visualizer mode
    private var visualizerSecondaryColor: Color {
        musicManager.visualizerSecondaryColor
    }

    /// Keep physical-notch media text white on black.
    /// Only adapt foregrounds for external transparent-notch mode.
    private var useAdaptiveForegrounds: Bool {
        useTransparentBackground && isExternalWithNotchStyle
    }

    private func primaryText(_ opacity: Double = 1.0) -> Color {
        useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto.opacity(opacity) : .white.opacity(opacity)
    }

    private func secondaryText(_ opacity: Double) -> Color {
        useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(opacity) : .white.opacity(opacity)
    }

    private func overlayTone(_ opacity: Double) -> Color {
        useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(opacity) : .white.opacity(opacity)
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
            // ALIGNMENT STANDARD (v21.68): .top alignment ensures title aligns with top of album art
            // Controls are pushed to bottom via the VStack's internal layout
            HStack(alignment: .top, spacing: 16) {
                // MARK: - Left: Large Album Art (100x100) with glow
                // PREMIUM: When showAlbumArt is false, morphing is handled externally
                if showAlbumArt {
                    albumArtViewLarge
                } else {
                    // PREMIUM MORPH: External morphing - keep layout with invisible spacer
                    Color.clear.frame(width: albumArtSize, height: albumArtSize)
                }
                
                // MARK: - Right: Stacked Controls
                // ALIGNMENT STANDARD (v21.68): Three content groups with equal spacing between them
                // Group 1: Title + Artist (top-aligned with album art)
                // Group 2: Progress bar (vertically centered)
                // Group 3: Controls (bottom-aligned with album art)
                VStack(alignment: .leading, spacing: 0) {
                    // GROUP 1: Title + Artist (TOP)
                    VStack(alignment: .leading, spacing: 2) {
                        titleRowView
                        artistRowView
                    }
                    
                    Spacer(minLength: 4)
                    
                    // GROUP 2: Progress Bar (CENTER)
                    HStack(spacing: 8) {
                        Text(elapsedTimeString(at: currentDate))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(secondaryText(0.62))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .leading)
                        
                        progressSliderView(at: currentDate)
                        
                        Text(remainingTimeString())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(secondaryText(0.62))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    Spacer(minLength: 4)
                    
                    // GROUP 3: Controls (BOTTOM - aligned with album art bottom)
                    controlsRowCompact
                }
                // Controls bottom-aligned with album art bottom edge
                .frame(maxWidth: .infinity, minHeight: albumArtSize, maxHeight: albumArtSize)
                // PREMIUM: Scale+blur+opacity appear animation (matches notchTransition pattern)
                .scaleEffect(contentAppeared ? 1.0 : 0.8, anchor: .top)
                .blur(radius: contentAppeared ? 0 : 8)
                .opacity(contentAppeared ? 1.0 : 0)
                .animation(DroppyAnimation.smoothContent, value: contentAppeared)
                .onAppear {
                    // Immediate animation start - syncs with container notchTransition
                    contentAppeared = true
                }
                .onDisappear {
                    contentAppeared = false
                }
            }
            // Use SSOT for consistent padding across all expanded views
            // contentEdgeInsets provides correct padding for each mode:
            // - Built-in notch: notchHeight top, 30pt left/right, 20pt bottom
            // - External notch style: 20pt top/bottom, 30pt left/right
            // - Pure Island mode: 30pt on all 4 edges
            .padding(NotchLayoutConstants.contentEdgeInsets(notchHeight: notchHeight, isExternalWithNotchStyle: isExternalWithNotchStyle))
            // MARK: - Premium Ambient Glow (from bottom-left corner to top-right)
            // AFTER padding so it anchors at actual container corner
            .background(alignment: .bottomLeading) {
                if musicManager.albumArt.size.width > 0 {
                    // Large blurred ellipse anchored at bottom-left corner of container
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    musicManager.visualizerColor.opacity(0.20),
                                    musicManager.visualizerColor.opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 350, height: 280)
                        .blur(radius: 60)
                        // Position: center of ellipse at bottom-left corner
                        .offset(x: -80, y: 60)
                        .drawingGroup() // GPU compositing for performance
                        .animation(.easeInOut(duration: 0.8), value: musicManager.visualizerColor)
                }
            }
        }
        // MARK: - Universal Inline HUD Observers
        // Uses local @ObservedObject references for snappy updates
        .onChange(of: volumeManager.lastChangeAt) { _, _ in
            guard enableHUDReplacement else { return }
            // When muted, pass 0 so bar drains and percentage shows 0
            let volumeValue = volumeManager.isMuted ? 0.0 : CGFloat(volumeManager.rawVolume)
            triggerInlineHUD(.volume, value: volumeValue, muted: volumeManager.isMuted)
        }
        .onChange(of: brightnessManager.lastChangeAt) { _, _ in
            guard enableHUDReplacement else { return }
            triggerInlineHUD(.brightness, value: CGFloat(brightnessManager.rawBrightness))
        }
        .onChange(of: batteryManager.lastChangeAt) { _, _ in
            guard enableBatteryHUD else { return }
            triggerInlineHUD(
                .battery,
                value: CGFloat(batteryManager.batteryLevel) / 100.0,
                isCharging: batteryManager.isCharging || batteryManager.isPluggedIn
            )
        }
        .onChange(of: capsLockManager.lastChangeAt) { _, _ in
            guard enableCapsLockHUD else { return }
            triggerInlineHUD(.capsLock, value: capsLockManager.isCapsLockOn ? 1.0 : 0.0)
        }
        .onChange(of: airPodsManager.lastConnectionAt) { _, _ in
            guard enableAirPodsHUD, let connectedAirPods = airPodsManager.connectedAirPods else { return }
            triggerInlineHUD(
                .airPods,
                value: max(0.01, CGFloat(connectedAirPods.batteryLevel) / 100.0),
                symbolOverride: connectedAirPods.type.symbolName
            )
        }
        .onChange(of: lockScreenManager.lastChangeAt) { _, _ in
            guard enableLockScreenHUD else { return }
            let isLocked = !lockScreenManager.isUnlocked
            triggerInlineHUD(.lockScreen, value: isLocked ? 1.0 : 0.0)
        }
        .onChange(of: dndManager.lastChangeAt) { _, _ in
            guard enableDNDHUD else { return }
            triggerInlineHUD(.focus, value: dndManager.isDNDActive ? 1.0 : 0.0)
        }
        .onChange(of: updateChecker.updateAvailable) { _, isAvailable in
            guard enableUpdateHUD, isAvailable else { return }
            triggerInlineHUD(.update, value: 1.0)
        }
        // MARK: - Album Art Flip on Track Change (directional)
        .onChange(of: musicManager.songTitle) { _, _ in
            // PREMIUM: Directional flip - right for forward, left for backward
            let flipAngle: Double = switch musicManager.lastSkipDirection {
            case .forward: 25
            case .backward: -25
            case .none: 25  // Default to forward
            }
            
            // Quick flip out with snappy spring
            withAnimation(DroppyAnimation.hoverBouncy) {
                albumArtFlipAngle = flipAngle
            }
            // Settle back smoothly after a brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(DroppyAnimation.transition) {
                    albumArtFlipAngle = 0
                }
            }
        }
        // MARK: - Album Art Scale on Pause/Play
        .onChange(of: musicManager.isPlaying) { _, isPlaying in
            // PREMIUM: Smooth scale with damping - shrink slightly when paused
            withAnimation(DroppyAnimation.itemInsertion) {
                albumArtPauseScale = isPlaying ? 1.0 : 0.95
            }
        }
        // MARK: - Horizontal Swipe to Toggle Media/Shelf
        // Captures scroll wheel directly to fix swipe not working when cursor stationary
        .captureHorizontalScroll { scrollX in
            // Swipe LEFT (negative) = Show media, Swipe RIGHT (positive) = Show shelf
            withAnimation(DroppyAnimation.transition) {
                if scrollX < 0 {
                    // Swipe LEFT -> Show MEDIA player
                    musicManager.isMediaHUDForced = true
                    musicManager.isMediaHUDHidden = false
                } else {
                    // Swipe RIGHT -> Show SHELF (hide media)
                    musicManager.isMediaHUDForced = false
                    musicManager.isMediaHUDHidden = true
                }
            }
        }
        // Right-click context menu - conditionally show hide option
        .contextMenu {
            if enableRightClickHide {
                Button {
                    NotchWindowController.shared.setTemporarilyHidden(true)
                } label: {
                    Label("Hide \(NotchWindowController.shared.displayModeLabel)", systemImage: "eye.slash")
                }
                Divider()
            }
            Button {
                SettingsWindowController.shared.showSettings()
            } label: {
                Label("Open Settings", systemImage: "gear")
            }
        }
    }
    
    // MARK: - Universal Inline HUD Trigger
    
    /// Trigger any inline HUD type in the media player
    /// Matches exact timing from NotchShelfView's triggerVolumeHUD
    private func triggerInlineHUD(
        _ type: InlineHUDType,
        value: CGFloat,
        muted: Bool = false,
        isCharging: Bool = false,
        symbolOverride: String? = nil
    ) {
        // Cancel any pending hide
        inlineHUDHideWorkItem?.cancel()
        
        // Update type, value, and mute state INSTANTLY (no animation - matches regular HUD)
        inlineHUDType = type
        inlineHUDValue = value
        inlineHUDMuted = muted
        inlineHUDBatteryCharging = isCharging
        inlineHUDSymbolOverride = symbolOverride
        
        // Animate visibility on (same as regular HUD: spring 0.3, 0.7)
        withAnimation(DroppyAnimation.state) {
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
        case .airPods: duration = airPodsManager.visibleDuration
        case .lockScreen: duration = lockScreenManager.visibleDuration
        case .update: duration = HUDManager.HUDType.update.defaultDuration
        }
        
        // Hide after duration (same as regular HUD: easeOut 0.3)
        let workItem = DispatchWorkItem { [self] in
            withAnimation(DroppyAnimation.viewChange) {
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
                            .fill(AdaptiveColors.overlayAuto(0.1))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 24))
                                    .foregroundStyle(secondaryText(0.58))
                            )
                    }
                }
                .frame(width: 64, height: 64)
                .modifier(AlbumArtMatchedGeometry(namespace: albumArtNamespace, id: "albumArt"))  // BEFORE clipShape!
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                
                // Spotify badge (bottom-right corner)
                if musicManager.isSpotifySource {
                    SpotifyBadge()
                        .offset(x: 4, y: 4)
                }
            }
            // Subtle border highlight
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.15), lineWidth: 0.5)
            )
            // Composite the entire view before applying shadow to prevent ghosting during animations
            .compositingGroup()
            .droppyCardShadow()
        }
        .buttonStyle(DroppyCardButtonStyle(cornerRadius: DroppyRadius.large))
        .scaleEffect((isAlbumArtPressed ? 0.95 : (isAlbumArtHovering ? 1.02 : 1.0)) * albumArtPauseScale)
        // Premium 3D flip on track change (Y-axis rotation)
        .rotation3DEffect(
            .degrees(albumArtFlipAngle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .parallax3D(magnitude: 12, enableOverride: true) // Premium 3D tilt on hover
        .animation(DroppyAnimation.hoverBouncy, value: isAlbumArtPressed)
        .animation(DroppyAnimation.hover, value: isAlbumArtHovering)
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
    
    // MARK: - Title Row (extracted to reduce type-checker complexity)
    
    private var titleRowView: some View {
        let songTitle = musicManager.songTitle.isEmpty ? "Not Playing" : musicManager.songTitle
        return HStack(spacing: 8) {
            // PREMIUM: When showTitle is false, morphing is handled externally
            if showTitle {
                MarqueeText(text: songTitle, speed: 30)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(primaryText())
                    .frame(height: 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
            } else {
                // Keep layout with invisible spacer - MUST use fixed height to match title row
                Color.clear
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
            }
            
            // Audio Visualizer (colored by album art) - fixedSize to prevent it from being squeezed
            if showVisualizer {
                AudioVisualizerBars(
                    isPlaying: musicManager.isPlaying,
                    color: visualizerColor,
                    secondaryColor: enableGradientVisualizer ? visualizerSecondaryColor : nil,
                    gradientMode: enableGradientVisualizer
                )
                    .frame(width: 24, height: 16)
                    .fixedSize()
            } else {
                Color.clear.frame(width: 24, height: 16)
            }
        }
        .frame(height: 20)
    }
    
    // MARK: - Artist Row (extracted to reduce type-checker complexity)
    
    private var artistRowView: some View {
        let artistName = musicManager.artistName.isEmpty ? "—" : musicManager.artistName
        return MarqueeText(text: artistName, speed: 25)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(secondaryText(0.72))
            .frame(height: 18)
    }
    
    // MARK: - Large Album Art (for horizontal layout)
    
    private var albumArtViewLarge: some View {
        ZStack {
            // MARK: - Album Art Glow (very subtle blurred halo)
            // PERFORMANCE FIX (Issue #81): Use drawingGroup() for GPU-accelerated blur rendering
            if musicManager.albumArt.size.width > 0 && musicManager.isPlaying {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .blur(radius: 18)
                    .scaleEffect(1.05)
                    .opacity(0.2)
                    .drawingGroup() // GPU compositing for expensive blur
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
                                .fill(AdaptiveColors.overlayAuto(0.08))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 36))
                                        .foregroundStyle(secondaryText(0.5))
                                )
                        }
                    }
                    .frame(width: 100, height: 100)
                    // PREMIUM: matchedGeometryEffect BEFORE clipShape - critical for morphing!
                    .modifier(AlbumArtMatchedGeometry(namespace: albumArtNamespace, id: "albumArt"))
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.lx, style: .continuous))
                    
                    // Source badge (bottom-right corner) - fades in without sliding
                    ZStack {
                        SpotifyBadge()
                            .opacity(musicManager.isSpotifySource ? 1 : 0)
                        AppleMusicBadge()
                            .opacity(musicManager.isAppleMusicSource ? 1 : 0)
                    }
                    .offset(x: 5, y: 5)
                    .animation(DroppyAnimation.state, value: musicManager.isSpotifySource)
                    .animation(DroppyAnimation.state, value: musicManager.isAppleMusicSource)
                }
                // Subtle border highlight
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.lx, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.12), lineWidth: 0.5)
                )
                .compositingGroup()
                .droppyCardShadow(opacity: 0.3)
            }
            .buttonStyle(DroppyCardButtonStyle(cornerRadius: DroppyRadius.lx))
            .scaleEffect((isAlbumArtPressed ? 0.96 : (isAlbumArtHovering ? 1.02 : 1.0)) * albumArtPauseScale)
            // Premium 3D flip on track change (Y-axis rotation)
            .rotation3DEffect(
                .degrees(albumArtFlipAngle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .parallax3D(magnitude: 12, enableOverride: true) // Premium 3D tilt on hover
            .animation(DroppyAnimation.hoverBouncy, value: isAlbumArtPressed)
            .animation(DroppyAnimation.hover, value: isAlbumArtHovering)
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
        .animation(DroppyAnimation.viewChange, value: musicManager.isPlaying)
        // PREMIUM: Scale+blur+opacity appear animation (matches controls pattern)
        .scaleEffect(contentAppeared ? 1.0 : 0.8, anchor: .top)
        .blur(radius: contentAppeared ? 0 : 8)
        .opacity(contentAppeared ? 1.0 : 0)
        .animation(DroppyAnimation.smoothContent, value: contentAppeared)
    }
    
    // MARK: - Progress Slider
    
    private func progressSliderView(at date: Date) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let currentProgress = progress(at: date)
            let progressWidth = max(0, min(width, width * currentProgress))
            // THINNER: 4pt → 6pt when dragging
            let trackHeight: CGFloat = isDragging ? 6 : 4
            
            ZStack(alignment: .leading) {
                // Track background (simple, no mask/blur)
                Capsule()
                    .fill(AdaptiveColors.overlayAuto(0.1))
                    .frame(height: trackHeight)
                
                // PREMIUM: Gradient fill with glow
                if currentProgress > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    visualizerColor,
                                    visualizerColor.opacity(0.85)
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
                                        colors: [overlayTone(0.4), .clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        // PREMIUM BLOOM: Multi-layer glow
                        .shadow(color: visualizerColor.opacity(0.3), radius: 1)
                        .shadow(color: visualizerColor.opacity(0.15 + (currentProgress * 0.15)), radius: 3)
                        .shadow(color: visualizerColor.opacity(0.1 + (currentProgress * 0.1)), radius: 5 + (currentProgress * 3))
                        .animation(.interpolatingSpring(stiffness: 350, damping: 28), value: currentProgress)
                }
            }
            .frame(height: trackHeight)
            .frame(maxHeight: .infinity, alignment: .center)
            .scaleEffect(y: isDragging ? 1.08 : 1.0, anchor: .center)
            .animation(DroppyAnimation.hover, value: isDragging)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        withAnimation(DroppyAnimation.hoverBouncy) {
                            isDragging = true
                        }
                        let fraction = max(0, min(1, value.location.x / width))
                        dragValue = Double(fraction) * musicManager.songDuration
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / width))
                        let seekTime = Double(fraction) * musicManager.songDuration
                        musicManager.seek(to: seekTime)
                        withAnimation(DroppyAnimation.hover) {
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
        let controlForeground = useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto : Color.white
        
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
                    MediaControlButton(icon: "backward.fill", size: 24, foregroundColor: controlForeground) {
                        musicManager.previousTrack()
                    }
                    
                    // Play/Pause (larger)
                    MediaControlButton(
                        icon: musicManager.isPlaying ? "pause.fill" : "play.fill",
                        size: 32,
                        foregroundColor: controlForeground
                    ) {
                        musicManager.togglePlay()
                    }
                    
                    // Next
                    MediaControlButton(icon: "forward.fill", size: 24, foregroundColor: controlForeground) {
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
                InlineHUDView(
                    type: hudType,
                    value: inlineHUDValue,
                    isMuted: inlineHUDMuted,
                    isCharging: inlineHUDBatteryCharging,
                    symbolOverride: inlineHUDSymbolOverride,
                    useAdaptiveForegrounds: useAdaptiveForegrounds
                )
                    .transition(DroppyAnimation.notchElementTransition)
            }
        }
        .animation(DroppyAnimation.notchState, value: inlineHUDType != nil)
        .allowsHitTesting(true)
    }
    
    // MARK: - Compact Controls Row (for horizontal layout)
    
    @ViewBuilder
    private var controlsRowCompact: some View {
        let isSpotify = musicManager.isSpotifySource
        let isAppleMusic = musicManager.isAppleMusicSource
        let spotify = musicManager.spotifyController
        let appleMusic = musicManager.appleMusicController
        let spotifyGreen = Color(red: 0.11, green: 0.73, blue: 0.33)
        let appleMusicPink = Color(red: 0.98, green: 0.34, blue: 0.40)  // Apple Music accent
        let controlForeground = useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto : Color.white
        
        ZStack {
            // Compact centered controls
            HStack(spacing: 20) {
                // Shuffle (Spotify or Apple Music)
                if isSpotify {
                    SpotifyControlButton(
                        icon: "shuffle",
                        isActive: spotify.shuffleEnabled,
                        accentColor: spotifyGreen,
                        size: 16
                    ) {
                        spotify.toggleShuffle()
                    }
                } else if isAppleMusic {
                    SpotifyControlButton(
                        icon: "shuffle",
                        isActive: appleMusic.shuffleEnabled,
                        accentColor: appleMusicPink,
                        size: 16
                    ) {
                        appleMusic.toggleShuffle()
                    }
                }
                
                // Previous (nudges left)
                MediaControlButton(
                    icon: "backward.fill",
                    size: 18,
                    foregroundColor: controlForeground,
                    tapPadding: 6,
                    nudgeDirection: .left
                ) {
                    musicManager.previousTrack()
                }
                
                // Play/Pause (wiggles - slightly larger)
                MediaControlButton(
                    icon: musicManager.isPlaying ? "pause.fill" : "play.fill",
                    size: 24,
                    foregroundColor: controlForeground,
                    tapPadding: 6,
                    nudgeDirection: .none
                ) {
                    musicManager.togglePlay()
                }
                
                // Next (nudges right)
                MediaControlButton(
                    icon: "forward.fill",
                    size: 18,
                    foregroundColor: controlForeground,
                    tapPadding: 6,
                    nudgeDirection: .right
                ) {
                    musicManager.nextTrack()
                }
                
                // Repeat (Spotify or Apple Music)
                if isSpotify {
                    SpotifyControlButton(
                        icon: spotify.repeatMode.iconName,
                        isActive: spotify.repeatMode != .off,
                        accentColor: spotifyGreen,
                        size: 16
                    ) {
                        spotify.cycleRepeatMode()
                    }
                } else if isAppleMusic {
                    SpotifyControlButton(
                        icon: appleMusic.repeatMode.iconName,
                        isActive: appleMusic.repeatMode != .off,
                        accentColor: appleMusicPink,
                        size: 16
                    ) {
                        appleMusic.cycleRepeatMode()
                    }
                }
                
                // Love button (Apple Music only - Spotify requires OAuth)
                if isAppleMusic {
                    SpotifyControlButton(
                        icon: appleMusic.isCurrentTrackLoved ? "heart.fill" : "heart",
                        isActive: appleMusic.isCurrentTrackLoved,
                        accentColor: appleMusicPink,
                        size: 16
                    ) {
                        appleMusic.toggleLove()
                    }
                }
            }
            .opacity(inlineHUDType != nil ? 0 : 1)
            .scaleEffect(inlineHUDType != nil ? 0.9 : 1)
            
            // Inline HUD overlay
            if let hudType = inlineHUDType {
                InlineHUDView(
                    type: hudType,
                    value: inlineHUDValue,
                    isMuted: inlineHUDMuted,
                    isCharging: inlineHUDBatteryCharging,
                    symbolOverride: inlineHUDSymbolOverride,
                    useAdaptiveForegrounds: useAdaptiveForegrounds
                )
                    .transition(DroppyAnimation.notchElementTransition)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(DroppyAnimation.notchState, value: inlineHUDType != nil)
    }
}

// Components moved to MediaPlayerComponents.swift


// MARK: - Preview

#Preview("Media Player - Horizontal Layout") {
    VStack {
        MediaPlayerView(musicManager: MusicManager.shared)
            .frame(width: 480, height: 130)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl))
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
