//
//  NotchShelfView.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers

// Wrapper to silence deprecation warning - standardShareMenuItem doesn't work in SwiftUI context menus
@available(macOS, deprecated: 13.0)
private func getSharingServices(for items: [Any]) -> [NSSharingService] {
    NSSharingService.sharingServices(forItems: items)
}

/// The notch-based shelf view that shows a yellow glow during drag and expands to show items
struct NotchShelfView: View {
    @Bindable var state: DroppyState
    @ObservedObject var dragMonitor = DragMonitor.shared
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @AppStorage("hideNotchOnExternalDisplays") private var hideNotchOnExternalDisplays = false
    @AppStorage("enableHUDReplacement") private var enableHUDReplacement = true
    @AppStorage("showMediaPlayer") private var showMediaPlayer = true
    @AppStorage("autoFadeMediaHUD") private var autoFadeMediaHUD = true
    
    // HUD State - Use @ObservedObject for singletons (they manage their own lifecycle)
    @ObservedObject private var volumeManager = VolumeManager.shared
    @ObservedObject private var brightnessManager = BrightnessManager.shared
    @ObservedObject private var musicManager = MusicManager.shared
    @State private var showVolumeHUD = false
    @State private var showBrightnessHUD = false
    @State private var hudWorkItem: DispatchWorkItem?
    @State private var hudType: HUDContentType = .volume
    @State private var hudValue: CGFloat = 0
    @State private var hudIsVisible = false
    @State private var mediaHUDFadedOut = false  // Tracks if media HUD has auto-faded
    @State private var mediaFadeWorkItem: DispatchWorkItem?
    @State private var isSongTransitioning = false  // Temporarily hide media during song transitions
    
    
    /// Animation state for the border dash
    @State private var dashPhase: CGFloat = 0
    @State private var dropZoneDashPhase: CGFloat = 0
    
    // Marquee Selection State
    @State private var selectionRect: CGRect? = nil
    @State private var initialSelection: Set<UUID> = []
    @State private var itemFrames: [UUID: CGRect] = [:]
    
    // Global rename state
    @State private var renamingItemId: UUID?
    
    // Removed isDropTargeted state as we use shared state now
    
    /// Real MacBook notch dimensions
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    private let expandedWidth: CGFloat = 450
    
    /// HUD dimensions (notch expands to show HUD)
    private let hudWidth: CGFloat = 350
    private let hudHeight: CGFloat = 73
    
    /// Whether media player HUD should be shown
    private var shouldShowMediaHUD: Bool {
        // Don't show during song transitions (collapse-expand effect)
        if isSongTransitioning { return false }
        // Don't show if auto-fade is enabled and it has faded out
        if autoFadeMediaHUD && mediaHUDFadedOut {
            return false
        }
        return showMediaPlayer && musicManager.isPlaying && !hudIsVisible && !state.isExpanded
    }
    
    /// Current notch width based on state
    private var currentNotchWidth: CGFloat {
        if state.isExpanded {
            return expandedWidth
        } else if hudIsVisible || shouldShowMediaHUD {
            return hudWidth
        } else if dragMonitor.isDragging || state.isMouseHovering {
            return notchWidth + 20
        } else {
            return notchWidth
        }
    }
    
    /// Current notch height based on state
    private var currentNotchHeight: CGFloat {
        if state.isExpanded {
            return currentExpandedHeight
        } else if hudIsVisible || shouldShowMediaHUD {
            return hudHeight
        } else if dragMonitor.isDragging || state.isMouseHovering {
            return notchHeight + 40
        } else {
            return notchHeight
        }
    }
    
    private var currentExpandedHeight: CGFloat {
        let rowCount = (Double(state.items.count) / 5.0).rounded(.up)
        let baseHeight = max(1, rowCount) * 110 + 54 // 110 per row + 54 header
        
        // Add extra height when showing media player to prevent overlap with header buttons
        if state.items.isEmpty && showMediaPlayer && musicManager.isPlaying && !musicManager.isPlayerIdle {
            return baseHeight + 50 // Extra space for media player content
        }
        return baseHeight
    }
    
    /// Helper to check if current screen is built-in (MacBook display)
    private var isBuiltInDisplay: Bool {
        guard let screen = NSScreen.main else { return true }
        // On modern macOS, built-in displays usually have "Built-in" in their localized name
        // This is the most reliable simple check without diving into IOKit
        return screen.localizedName.contains("Built-in") || screen.localizedName.contains("Internal")
    }
    
    private var shouldShowVisualNotch: Bool {
        // Always show when expanded or during drag/hover (for drop indication)
        if state.isExpanded { return true }
        if dragMonitor.isDragging || state.isMouseHovering || state.isDropTargeted { return true }
        
        // Hide on external displays when setting is enabled (static state only)
        if hideNotchOnExternalDisplays && !isBuiltInDisplay {
            return false
        }
        return true
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // MARK: - Main Morphing Background
            // This is the persistent black shape that grows/shrinks
            NotchShape(bottomRadius: state.isExpanded ? 20 : (hudIsVisible ? 18 : 16))
                .fill(useTransparentBackground ? Color.clear : Color.black)
                .frame(
                    width: currentNotchWidth,
                    height: currentNotchHeight
                )
                .opacity(shouldShowVisualNotch ? 1.0 : 0.0)
                .background {
                    if useTransparentBackground && shouldShowVisualNotch {
                        Color.clear
                            .liquidGlass(shape: NotchShape(bottomRadius: state.isExpanded ? 20 : 16))
                    }
                }
                .overlay(
                   NotchOutlineShape(bottomRadius: state.isExpanded ? 20 : 16)
                       .trim(from: 0, to: 1) // Ensures full path
                       .stroke(
                           style: StrokeStyle(
                               lineWidth: 2,
                               lineCap: .round,
                               lineJoin: .round,
                               dash: [3, 5],
                               dashPhase: dashPhase
                           )
                       )
                       .foregroundStyle(Color.blue)
                       .opacity((shouldShowVisualNotch && !state.isExpanded && (dragMonitor.isDragging || state.isMouseHovering)) ? 1 : 0)
                       .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragMonitor.isDragging)
                       .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isMouseHovering)
                )
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.isExpanded)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragMonitor.isDragging)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hudIsVisible)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: musicManager.isPlaying)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSongTransitioning)  // Match song transition timing
                // Animate height changes when items are added/removed
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.items.count)
            
            // MARK: - Content Overlay
            ZStack {
                // Always have the drop zone / interaction layer at the top
                // BUT disable hit testing when expanded so slider/buttons can receive gestures
                dropZone
                    .zIndex(1)
                    .allowsHitTesting(!state.isExpanded)
                
                // MARK: - HUD Content (embedded in notch)
                if hudIsVisible && enableHUDReplacement && !state.isExpanded {
                    NotchHUDView(
                        hudType: $hudType,
                        value: $hudValue,
                        onValueChange: { newValue in
                            if hudType == .volume {
                                volumeManager.setAbsolute(Float32(newValue))
                            } else {
                                brightnessManager.setAbsolute(value: Float(newValue))
                            }
                        }
                    )
                    .frame(width: hudWidth, height: hudHeight)
                    // Match media player transition - scale with notch
                    .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
                    .zIndex(3)
                }
                
                // MARK: - Media Player HUD (when music is playing)
                // Only show if we have valid song info (not just isPlaying)
                // Wait for songDuration > 0 to ensure complete metadata is loaded
                // Hide during song transitions for collapse-expand effect
                // Removed songDuration > 0 check - web sources often don't provide valid duration
                if showMediaPlayer && musicManager.isPlaying && !musicManager.songTitle.isEmpty && !hudIsVisible && !state.isExpanded && !(autoFadeMediaHUD && mediaHUDFadedOut) && !isSongTransitioning {
                    MediaHUDView(musicManager: musicManager)
                        .frame(width: hudWidth, height: hudHeight)
                        // Match the exact notch collapse/expand animation
                        .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.25, dampingFraction: 0.8)))
                        .zIndex(3)
                }
                
                if state.isExpanded {
                    expandedShelfContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)).animation(.spring(response: 0.35, dampingFraction: 0.7)),
                            removal: .opacity.combined(with: .scale(scale: 0.95)).animation(.spring(response: 0.3, dampingFraction: 0.8))
                        ))
                        .frame(width: expandedWidth, height: currentExpandedHeight)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentExpandedHeight)
                        .clipShape(NotchShape(bottomRadius: 20))
                        .zIndex(2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Animate all state changes smoothly
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showMediaPlayer)
        .animation(.easeOut(duration: 0.4), value: mediaHUDFadedOut)
        .onChange(of: state.items.count) { oldCount, newCount in
             if newCount > oldCount && !state.isExpanded {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    state.isExpanded = true
                }
            }
             if newCount == 0 && state.isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    state.isExpanded = false
                }
            }
        }
        // MARK: - HUD Observers
        .onChange(of: volumeManager.lastChangeAt) { _, _ in
            guard enableHUDReplacement, !state.isExpanded else { return }
            triggerVolumeHUD()
        }
        .onChange(of: brightnessManager.lastChangeAt) { _, _ in
            guard enableHUDReplacement, !state.isExpanded else { return }
            triggerBrightnessHUD()
        }
        // MARK: - Media HUD Auto-Fade
        .onChange(of: musicManager.songTitle) { oldTitle, newTitle in
            // Trigger collapse-expand animation on song change
            if !oldTitle.isEmpty && !newTitle.isEmpty && oldTitle != newTitle {
                // Start transition: collapse (hide media)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isSongTransitioning = true
                }
                // End transition after a delay: expand (show new song)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        isSongTransitioning = false
                    }
                }
            }
            // Reset fade state when song changes (new song = show HUD again)
            if !newTitle.isEmpty {
                mediaHUDFadedOut = false
                startMediaFadeTimer()
            }
        }
        .onChange(of: musicManager.isPlaying) { wasPlaying, isPlaying in
            // When playback starts, reset fade state and start timer
            if isPlaying && !wasPlaying {
                mediaHUDFadedOut = false
                startMediaFadeTimer()
            }
        }
        // HUD is now embedded in the notch content (see ZStack above)
    }
    
    // MARK: - HUD Overlay Content (Legacy - now embedded in notch)
    // Kept for reference but no longer used
    
    // MARK: - HUD Helper Functions
    
    private func triggerVolumeHUD() {
        hudWorkItem?.cancel()
        hudType = .volume
        hudValue = CGFloat(volumeManager.rawVolume)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            hudIsVisible = true
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.3)) {
                hudIsVisible = false
            }
        }
        hudWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + volumeManager.visibleDuration, execute: workItem)
    }
    
    private func triggerBrightnessHUD() {
        hudWorkItem?.cancel()
        hudType = .brightness
        hudValue = CGFloat(brightnessManager.rawBrightness)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            hudIsVisible = true
        }
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.3)) {
                hudIsVisible = false
            }
        }
        hudWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + brightnessManager.visibleDuration, execute: workItem)
    }
    
    private func startMediaFadeTimer() {
        // Only start timer if auto-fade is enabled
        guard autoFadeMediaHUD else { return }
        
        // Cancel any existing timer
        mediaFadeWorkItem?.cancel()
        
        // Start 5-second timer to fade out media HUD
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.4)) {
                mediaHUDFadedOut = true
            }
        }
        mediaFadeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }
    
    // MARK: - Glow Effect
    
    // Old glowEffect removed

    
    // MARK: - Drop Zone
    
    private var dropZone: some View {
        // Dynamic hit area: tiny in idle, larger when active
        // This prevents blocking Safari URL bars, Outlook search fields, etc.
        let isActive = state.isExpanded || state.isMouseHovering || dragMonitor.isDragging || state.isDropTargeted
        
        // Idle: just the notch itself (small area that doesn't extend below menu bar)
        // Active: larger area for comfortable interaction
        let dropAreaWidth: CGFloat = isActive ? (notchWidth + 80) : notchWidth
        let dropAreaHeight: CGFloat = isActive ? (notchHeight + 50) : notchHeight
        
        return ZStack {
            // Invisible hit area for hovering/clicking - SIZE CHANGES based on state
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.clear)
                .frame(width: dropAreaWidth, height: dropAreaHeight)
                .contentShape(Rectangle()) // Only THIS rectangle is interactive
            
            // Beautiful drop indicator when hovering with files
            if state.isDropTargeted && !state.isExpanded {
                dropIndicator
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .allowsHitTesting(false) // Don't let the badge capture clicks
            }
            // "Open Shelf" indicator when hovering with mouse (no drag)
            else if state.isMouseHovering && !dragMonitor.isDragging && !state.isExpanded {
                openIndicator
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .allowsHitTesting(false) // Don't let the badge capture clicks
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                state.isExpanded.toggle()
            }
        }
        .onHover { isHovering in
            // Only update hover state if not dragging (drag state handles its own)
            if !dragMonitor.isDragging {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    state.isMouseHovering = isHovering
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isDropTargeted)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isMouseHovering)
    }
    
    // MARK: - Indicators
    
    private var dropIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white, .green)
                .symbolEffect(.bounce, value: state.isDropTargeted)
            
            Text("Drop!")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .shadow(radius: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(indicatorBackground)
        .offset(y: notchHeight + 50)
    }
    
    private var openIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white, .blue)
                .symbolEffect(.bounce, value: state.isMouseHovering)
            
            Text("Open Shelf")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
                .shadow(radius: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(indicatorBackground)
        .offset(y: notchHeight + 50)
    }
    
    private var indicatorBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }

    // MARK: - Expanded Content
    
    private var expandedShelfContent: some View {
        VStack(spacing: 0) {
            // Header / Controls
            HStack(spacing: 0) {
                // Close button
                NotchControlButton(icon: "chevron.up") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.isExpanded = false
                    }
                }
                .padding(.leading, 16)
                
                Spacer()
                
                // Clear button OR Settings button (when empty)
                if !state.items.isEmpty {
                    NotchControlButton(icon: "trash") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            state.clearAll()
                        }
                    }
                    .padding(.trailing, 16)
                } else {
                    NotchControlButton(icon: "gearshape") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            state.isExpanded = false
                        }
                        SettingsWindowController.shared.showSettings()
                    }
                    .padding(.trailing, 16)
                }
            }
            .frame(height: 54)
            .frame(width: expandedWidth)
            .contentShape(Rectangle()) // Make header clickable to deselect if needed, or just let it pass
            .onTapGesture {
                state.deselectAll()
            }
            
            // Grid Items or Media Player or Drop Zone
            ZStack {
                // Show drop zone when dragging over (takes priority)
                if state.isDropTargeted && state.items.isEmpty {
                    emptyShelfContent
                        .frame(height: currentExpandedHeight - 54)
                        .transition(.opacity.animation(.spring(response: 0.3, dampingFraction: 0.8)))
                }
                // Show media player when music is playing and NOT drop targeted
                else if state.items.isEmpty && showMediaPlayer && musicManager.isPlaying && !musicManager.isPlayerIdle && !state.isDropTargeted {
                    MediaPlayerView(musicManager: musicManager)
                        .frame(height: currentExpandedHeight - 54)
                        .transition(.opacity.animation(.spring(response: 0.35, dampingFraction: 0.7)))
                }
                // Show empty shelf when no items and no music
                else if state.items.isEmpty {
                    emptyShelfContent
                        .frame(height: currentExpandedHeight - 54)
                        .transition(.opacity.animation(.spring(response: 0.35, dampingFraction: 0.7)))
                }
                // Show items grid when items exist
                else {
                    itemsGridView
                        .frame(height: currentExpandedHeight - 54)
                        .transition(.opacity.animation(.spring(response: 0.35, dampingFraction: 0.7)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state.isDropTargeted)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: musicManager.isPlaying)
        }
    }
    
    private var itemsGridView: some View {
        let items = state.items
        let chunkedItems = stride(from: 0, to: items.count, by: 5).map {
            Array(items[$0..<min($0 + 5, items.count)])
        }
        
        return ScrollView(.vertical, showsIndicators: false) {
            ZStack {
                // Background tap handler - acts as a "canvas" to catch clicks
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        state.deselectAll()
                        renamingItemId = nil
                    }
                    // Moved Marquee Drag Gesture HERE so it doesn't conflict with dragging items
                    .gesture(
                         DragGesture(minimumDistance: 1, coordinateSpace: .named("shelfGrid"))
                             .onChanged { value in
                                 // Start selection
                                 if selectionRect == nil {
                                     initialSelection = state.selectedItems
                                     
                                     if !NSEvent.modifierFlags.contains(.command) && !NSEvent.modifierFlags.contains(.shift) {
                                         state.deselectAll()
                                         initialSelection = []
                                     }
                                 }
                                 
                                 let rect = CGRect(
                                     x: min(value.startLocation.x, value.location.x),
                                     y: min(value.startLocation.y, value.location.y),
                                     width: abs(value.location.x - value.startLocation.x),
                                     height: abs(value.location.y - value.startLocation.y)
                                 )
                                 selectionRect = rect
                                 
                                 // Update Selection
                                 var newSelection = initialSelection
                                 for (id, frame) in itemFrames {
                                     if rect.intersects(frame) {
                                         newSelection.insert(id)
                                     }
                                 }
                                 state.selectedItems = newSelection
                             }
                             .onEnded { _ in
                                 selectionRect = nil
                                 initialSelection = []
                             }
                    )
                
                VStack(spacing: 12) {
                    ForEach(Array(chunkedItems.enumerated()), id: \.offset) { index, rowItems in
                        HStack(spacing: 10) {
                            // Center items: add spacer if row is not full?
                            // Actually, plain HStack with spacing centers by default if not strictly aligned leading
                            // But we want "always center".
                            // If we just do HStack, it centers in the container view.
                            ForEach(rowItems) { item in
                                NotchItemView(
                                    item: item,
                                    state: state,
                                    renamingItemId: $renamingItemId,
                                    onRemove: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            state.removeItem(item)
                                        }
                                    }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity) // Ensures HStack takes full width to center content
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 6)
            }
        }
        .contentShape(Rectangle())
        // Removed .onTapGesture from here to prevent swallowing touches on children
        .overlay(alignment: .topLeading) {
            if let rect = selectionRect {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.blue.opacity(0.2))
                    .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "shelfGrid")
        .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
            self.itemFrames = frames
        }
    }
}

// MARK: - Custom Notch Shape
struct NotchShape: Shape {
    var bottomRadius: CGFloat
    
    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start top left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Top edge (straight)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        
        // Bottom Right Corner
        path.addArc(
            center: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        
        // Bottom Left Corner
        path.addArc(
            center: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Notch Outline Shape
/// Defines the U-shape outline of the notch (without the top edge)
struct NotchOutlineShape: Shape {
    var bottomRadius: CGFloat
    
    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start Top Right
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        
        // Bottom Right Corner
        path.addArc(
            center: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        
        // Bottom Left Corner
        path.addArc(
            center: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        return path
    }
}

// Extension to split up complex view code
extension NotchShelfView {

    private var emptyShelfContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
            
            Text(state.isDropTargeted ? "It tickles! Drop it please" : "Drop files here")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    state.isDropTargeted ? Color.blue : Color.white.opacity(0.2),
                    style: StrokeStyle(
                        lineWidth: state.isDropTargeted ? 2 : 1.5,
                        lineCap: .round,
                        dash: [6, 8],
                        dashPhase: dropZoneDashPhase
                    )
                )
        )
        .padding(EdgeInsets(top: 10, leading: 20, bottom: 20, trailing: 20))
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                dropZoneDashPhase -= 280 // Multiple of 14 (6+8) for smooth loop
            }
        }
    }
}

// MARK: - Notch Item View

/// Compact item view optimized for the notch shelf
struct NotchItemView: View {
    let item: DroppedItem
    let state: DroppyState
    @Binding var renamingItemId: UUID?
    let onRemove: () -> Void
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    
    @State private var thumbnail: NSImage?
    @State private var isHovering = false
    @State private var isConverting = false
    @State private var isExtractingText = false
    @State private var isCreatingZIP = false
    @State private var isCompressing = false
    @State private var isPoofing = false
    @State private var pendingConvertedItem: DroppedItem?
    // Removed local isRenaming
    @State private var renamingText = ""
    
    // Feedback State
    @State private var shakeOffset: CGFloat = 0
    @State private var isShakeAnimating = false
    
    private func chooseDestinationAndMove() {
        // Dispatch to main async to allow the menu to close and UI to settle
        DispatchQueue.main.async {
            // Ensure the app is active so the panel appears on top
            NSApp.activate(ignoringOtherApps: true)
            
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Move Here"
            panel.message = "Choose a destination to move the selected files."
            
            // Use runModal for a simpler blocking flow in this context, 
            // or begin with completion. runModal is often more reliable for "popup" utilities.
            if panel.runModal() == .OK, let url = panel.url {
                DestinationManager.shared.addDestination(url: url)
                moveFiles(to: url)
            }
        }
    }
    
    private func moveFiles(to destination: URL) {
        let itemsToMove = state.selectedItems.isEmpty ? [item] : state.items.filter { state.selectedItems.contains($0.id) }
        
        // Run file operations in background to prevent UI freezing (especially for NAS/Network drives)
        DispatchQueue.global(qos: .userInitiated).async {
            for item in itemsToMove {
                do {
                    let destURL = destination.appendingPathComponent(item.url.lastPathComponent)
                    var finalDestURL = destURL
                    var counter = 1
                    
                    // Check existence (this is fast usually, but good to be in bg for network drives)
                    while FileManager.default.fileExists(atPath: finalDestURL.path) {
                        let ext = destURL.pathExtension
                        let name = destURL.deletingPathExtension().lastPathComponent
                        let newName = "\(name) \(counter)" + (ext.isEmpty ? "" : ".\(ext)")
                        finalDestURL = destination.appendingPathComponent(newName)
                        counter += 1
                    }
                    
                    // Try primitive move first
                    try FileManager.default.moveItem(at: item.url, to: finalDestURL)
                    
                    // Update UI on Main Thread
                    DispatchQueue.main.async {
                        state.removeItem(item)
                    }
                } catch {
                    // Fallback copy+delete mechanism for cross-volume moves
                    do {
                        try FileManager.default.copyItem(at: item.url, to: destination.appendingPathComponent(item.url.lastPathComponent))
                        try FileManager.default.removeItem(at: item.url)
                        
                        DispatchQueue.main.async {
                            state.removeItem(item)
                        }
                    } catch {
                        let errorDescription = error.localizedDescription
                        DispatchQueue.main.async {
                            print("Failed to move file: \(errorDescription)")
                            let alert = NSAlert()
                            alert.messageText = "Move Failed"
                            alert.informativeText = "Could not move \(item.name): \(errorDescription)"
                            alert.alertStyle = .warning
                            // Check if window is still available to attach sheet, otherwise runModal
                            alert.runModal()
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        DraggableArea(
            items: {
                // If this item is selected, drag all selected items.
                // Otherwise, drag only this item.
                if state.selectedItems.contains(item.id) {
                    let selected = state.items.filter { state.selectedItems.contains($0.id) }
                    return selected.map { $0.url as NSURL }
                } else {
                    return [item.url as NSURL]
                }
            },
            onTap: { modifiers in
                // Handle Selection
                if modifiers.contains(.command) {
                    state.toggleSelection(item)
                } else {
                    // Standard click: select this, deselect others
                    // But if it's already selected and we are just clicking it?
                    // Usually: select this one only.
                    state.deselectAll()
                    state.selectedItems.insert(item.id)
                }
            },
            onRightClick: {
                // Select if not selected
                 if !state.selectedItems.contains(item.id) {
                    state.deselectAll()
                    state.selectedItems.insert(item.id)
                }
            },
            selectionSignature: state.selectedItems.hashValue
        ) {
            NotchItemContent(
                item: item,
                state: state,
                onRemove: onRemove,
                thumbnail: thumbnail,
                isHovering: isHovering,
                isConverting: isConverting,
                isExtractingText: isExtractingText,
                isPoofing: $isPoofing,
                pendingConvertedItem: $pendingConvertedItem,
                renamingItemId: $renamingItemId,
                renamingText: $renamingText,
                onRename: performRename
            )
            .offset(x: shakeOffset)
            .overlay(alignment: .center) {
                if isShakeAnimating {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
                            .frame(width: 44, height: 44)
                            .shadow(radius: 4)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(width: 76, height: 96)
        .background {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: ItemFramePreferenceKey.self,
                        value: [item.id: geo.frame(in: .named("shelfGrid"))]
                    )
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button {
                state.copyToClipboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            Button {
                item.openFile()
            } label: {
                Label("Open", systemImage: "arrow.up.forward.square")
            }
            
            // Move To...
            Menu {
                // Saved Destinations
                ForEach(DestinationManager.shared.destinations) { dest in
                    Button {
                        moveFiles(to: dest.url)
                    } label: {
                        Label(dest.name, systemImage: "externaldrive")
                    }
                }
                
                if !DestinationManager.shared.destinations.isEmpty {
                    Divider()
                }
                
                Button {
                    chooseDestinationAndMove()
                } label: {
                    Label("Choose Folder...", systemImage: "folder.badge.plus")
                }
            } label: {
                Label("Move to...", systemImage: "arrow.right.doc.on.clipboard")
            }
            
            // Open With submenu
            let availableApps = item.getAvailableApplications()
            if !availableApps.isEmpty {
                Menu {
                    ForEach(availableApps, id: \.url) { app in
                        Button {
                            item.openWith(applicationURL: app.url)
                        } label: {
                            Label(app.name, image: NSImage.Name(app.name))
                        }
                    }
                } label: {
                    Label("Open With...", systemImage: "square.and.arrow.up.on.square")
                }
            }
            
            // Share submenu with system sharing services
            Menu {
                ForEach(getSharingServices(for: [item.url]), id: \.title) { service in
                    Button {
                        service.perform(withItems: [item.url])
                    } label: {
                        Label {
                            Text(service.title)
                        } icon: {
                            Image(nsImage: service.image)
                        }
                    }
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button {
                item.saveToDownloads()
            } label: {
                Label("Save", systemImage: "arrow.down.circle")
            }
            
            // Conversion submenu - only show if conversions are available
            let conversions = FileConverter.availableConversions(for: item.fileType)
            if !conversions.isEmpty {
                Divider()
                
                Menu {
                    ForEach(conversions) { option in
                        Button {
                            convertFile(to: option.format)
                        } label: {
                            Label(option.displayName, systemImage: option.icon)
                        }
                    }
                } label: {
                    Label("Convert to...", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            
            // OCR Option
            if item.fileType?.conforms(to: .image) == true || item.fileType?.conforms(to: .pdf) == true {
                Button {
                    extractText()
                } label: {
                    Label("Extract Text", systemImage: "text.viewfinder")
                }
            }
            
            // Create ZIP option
            Divider()
            
            // Compress option - only show for compressible file types
            if FileCompressor.canCompress(fileType: item.fileType) {
                if item.fileType?.conforms(to: .image) == true {
                    Menu {
                        Button("Auto (Medium)") {
                            compressFile(mode: .preset(.medium))
                        }
                        Button("Target Size...") {
                            compressFile(mode: nil) // Triggers prompt
                        }
                    } label: {
                        Label("Compress", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                    .disabled(isCompressing)
                } else {
                    Button {
                        compressFile(mode: .preset(.medium))
                    } label: {
                        Label("Compress", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                    .disabled(isCompressing)
                }
            }
            
            Button {
                createZIPFromSelection()
            } label: {
                Label("Create ZIP", systemImage: "doc.zipper")
            }
            .disabled(isCreatingZIP)
            
            // Rename option (single item only)
            if state.selectedItems.count <= 1 {
                Button {
                    startRenaming()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                 if state.selectedItems.contains(item.id) {
                     state.removeSelectedItems()
                 } else {
                     onRemove()
                 }
            }) {
                Label("Remove", systemImage: "trash")
            }
        }
        .task {
            thumbnail = await item.generateThumbnail(size: CGSize(width: 120, height: 120))
        }
    }
    
    // MARK: - OCR
    
    private func extractText() {
        guard !isExtractingText else { return }
        isExtractingText = true
        
        Task {
            do {
                let text = try await OCRService.shared.extractText(from: item.url)
                await MainActor.run {
                    isExtractingText = false
                    OCRWindowController.shared.show(with: text)
                }
            } catch {
                await MainActor.run {
                    isExtractingText = false
                    OCRWindowController.shared.show(with: "Error extracting text: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Conversion
    
    private func convertFile(to format: ConversionFormat) {
        guard !isConverting else { return }
        isConverting = true
        
        Task {
            if let convertedURL = await FileConverter.convert(item.url, to: format) {
                // Create new DroppedItem from converted file (marked as temporary for cleanup)
                let newItem = DroppedItem(url: convertedURL, isTemporary: true)
                
                await MainActor.run {
                    isConverting = false
                    pendingConvertedItem = newItem
                    // Trigger poof animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPoofing = true
                    }
                }
            } else {
                await MainActor.run {
                    isConverting = false
                }
            }
        }
    }
    
    // MARK: - ZIP Creation
    
    private func createZIPFromSelection() {
        guard !isCreatingZIP else { return }
        
        // Determine items to include: selected items or just this item
        let itemsToZip: [DroppedItem]
        if state.selectedItems.isEmpty || (state.selectedItems.count == 1 && state.selectedItems.contains(item.id)) {
            itemsToZip = [item]
        } else {
            itemsToZip = state.items.filter { state.selectedItems.contains($0.id) }
        }
        
        isCreatingZIP = true
        
        Task {
            // Generate archive name based on item count
            let archiveName = itemsToZip.count == 1 
                ? itemsToZip[0].url.deletingPathExtension().lastPathComponent
                : "Archive (\(itemsToZip.count) items)"
            
            if let zipURL = await FileConverter.createZIP(from: itemsToZip, archiveName: archiveName) {
                // Mark ZIP as temporary for cleanup when removed
                let newItem = DroppedItem(url: zipURL, isTemporary: true)
                
                await MainActor.run {
                    isCreatingZIP = false
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        state.replaceItems(itemsToZip, with: newItem)
                    }
                    // Auto-start renaming the new zip file
                    renamingItemId = newItem.id
                }
            } else {
                await MainActor.run {
                    isCreatingZIP = false
                }
                print("ZIP creation failed")
            }
        }
    }
    
    // MARK: - Compression
    
    private func compressFile(mode explicitMode: CompressionMode? = nil) {
        guard !isCompressing else { return }
        isCompressing = true
        
        Task {
            // Determine compression mode
            let mode: CompressionMode
            
            if let explicit = explicitMode {
                mode = explicit
            } else {
                // No explicit mode means request Target Size (for images)
                guard let currentSize = FileCompressor.fileSize(url: item.url) else {
                    await MainActor.run { isCompressing = false }
                    return
                }
                
                guard let targetBytes = await TargetSizeDialogController.shared.show(
                    currentSize: currentSize,
                    fileName: item.name
                ) else {
                    // User cancelled
                    await MainActor.run { isCompressing = false }
                    return
                }
                
                mode = .targetSize(bytes: targetBytes)
            }
            
            if let compressedURL = await FileCompressor.shared.compress(url: item.url, mode: mode) {
                // Mark compressed file as temporary for cleanup when removed
                let newItem = DroppedItem(url: compressedURL, isTemporary: true)
                
                await MainActor.run {
                    isCompressing = false
                    pendingConvertedItem = newItem
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPoofing = true
                    }
                    // Clean up after slight delay to ensure poof is seen
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        await MainActor.run {
                            state.replaceItem(item, with: newItem)
                            isPoofing = false
                        }
                    }
                }
            } else {
                await MainActor.run {
                    isCompressing = false
                    // Trigger Feedback: Shake + Shield
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        isShakeAnimating = true
                    }
                    
                    // Shake animation sequence
                    Task {
                        for _ in 0..<3 {
                            withAnimation(.linear(duration: 0.05)) { shakeOffset = -4 }
                            try? await Task.sleep(nanoseconds: 50_000_000)
                            withAnimation(.linear(duration: 0.05)) { shakeOffset = 4 }
                            try? await Task.sleep(nanoseconds: 50_000_000)
                        }
                        withAnimation { shakeOffset = 0 }
                        
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        withAnimation { isShakeAnimating = false }
                    }
                }
                print("Compression failed or no size reduction (Size Guard)")
            }
        }
    }
    
    // MARK: - Rename
    
    private func startRenaming() {
        // Set the text to filename without extension for easier editing
        renamingItemId = item.id
    }
    
    private func performRename() {
        let trimmedName = renamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("Rename: Empty name, cancelling")
            renamingItemId = nil
            return
        }
        
        print("Rename: Attempting to rename '\(item.name)' to '\(trimmedName)'")
        
        if let renamedItem = item.renamed(to: trimmedName) {
            print("Rename: Success! New item: \(renamedItem.name)")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                state.replaceItem(item, with: renamedItem)
            }
        } else {
            print("Rename: Failed - renamed() returned nil")
        }
        renamingItemId = nil
    }
}

// MARK: - Helper Views

struct NotchControlButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(isHovering ? 0.2 : 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { mirroring in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovering = mirroring
            }
        }
    }
}

// MARK: - Preferences for Marquee Selection
struct ItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}



// MARK: - Notch Item Content
private struct NotchItemContent: View {
    let item: DroppedItem
    let state: DroppyState
    let onRemove: () -> Void
    let thumbnail: NSImage?
    let isHovering: Bool
    let isConverting: Bool
    let isExtractingText: Bool
    @Binding var isPoofing: Bool
    @Binding var pendingConvertedItem: DroppedItem?
    @Binding var renamingItemId: UUID?
    @Binding var renamingText: String
    let onRename: () -> Void
    
    private var isSelected: Bool {
        state.selectedItems.contains(item.id)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail container
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
                    .frame(width: 60, height: 60)
                    .overlay {
                        Group {
                            if let thumbnail = thumbnail {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Image(nsImage: item.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .opacity((isConverting || isExtractingText) ? 0.5 : 1.0)
                    }
                    .overlay {
                        if isConverting || isExtractingText {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        }
                    }
                
                // Remove button on hover
                if isHovering && !isPoofing && renamingItemId != item.id {
                    Button(action: onRemove) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red.opacity(0.9))
                                .frame(width: 20, height: 20)
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Filename or rename text field
            if renamingItemId == item.id {
                RenameTextField(
                    text: $renamingText,
                    // Pass a binding derived from the ID check
                    isRenaming: Binding(
                        get: { renamingItemId == item.id },
                        set: { if !$0 { renamingItemId = nil } }
                    ),
                    onRename: onRename
                )
                .onAppear {
                    renamingText = item.url.deletingPathExtension().lastPathComponent
                }
            } else {
                Text(item.name)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                    .lineLimit(1)
                    .frame(width: 68)
                    .padding(.horizontal, 4)
                    .background(
                        isSelected ?
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.blue) :
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.clear)
                    )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering && !isSelected ? Color.white.opacity(0.1) : Color.clear)
        )
        .poofEffect(isPoofing: $isPoofing) {
            // Replace item when poof completes
            if let newItem = pendingConvertedItem {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    state.replaceItem(item, with: newItem)
                }
                pendingConvertedItem = nil
            }
        }
    }
}

// MARK: - Rename Text Field with Auto-Select and Animated Dotted Border
private struct RenameTextField: View {
    @Binding var text: String
    @Binding var isRenaming: Bool
    let onRename: () -> Void
    
    @State private var dashPhase: CGFloat = 0
    
    var body: some View {
        AutoSelectTextField(
            text: $text,
            onSubmit: onRename,
            onCancel: { isRenaming = false }
        )
        .font(.system(size: 11, weight: .medium))
        .frame(width: 72)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        // Animated dotted blue outline
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    Color.accentColor.opacity(0.8),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        dash: [3, 3],
                        dashPhase: dashPhase
                    )
                )
        )
        .onAppear {
            // Animate the marching ants
            withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                dashPhase = 6
            }
        }
    }
}

// MARK: - Auto-Select Text Field (NSViewRepresentable)
private struct AutoSelectTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.textColor = .white
        textField.font = .systemFont(ofSize: 11, weight: .medium)
        textField.alignment = .center
        textField.focusRingType = .none
        textField.stringValue = text
        
        // Make it the first responder and select all text after a brief delay
        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
            textField.selectText(nil)
            textField.currentEditor()?.selectedRange = NSRange(location: 0, length: textField.stringValue.count)
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if text changed externally
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: AutoSelectTextField
        
        init(_ parent: AutoSelectTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Enter pressed - submit
                parent.onSubmit()
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Escape pressed - cancel
                parent.onCancel()
                return true
            }
            return false
        }
    }
}

