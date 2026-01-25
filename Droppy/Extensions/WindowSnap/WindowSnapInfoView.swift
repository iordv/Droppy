//
//  WindowSnapInfoView.swift
//  Droppy
//
//  Window Snap extension info sheet with shortcut configuration grid
//

import SwiftUI

struct WindowSnapInfoView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var shortcuts: [SnapAction: SavedShortcut] = [:]
    @State private var recordingAction: SnapAction?
    @State private var recordMonitor: Any?
    @State private var isHoveringShortcut: [SnapAction: Bool] = [:]
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringClose = false
    @State private var isHoveringDefaults = false
    @State private var isHoveringRemoveDefaults = false
    @State private var showReviewsSheet = false
    @State private var isHoveringReviews = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed, non-scrolling)
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Scrollable content area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Features + Screenshot
                    featuresSection
                    
                    // Shortcuts grid
                    shortcutSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons (fixed, non-scrolling)
            buttonSection
        }
        .frame(width: 540)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            loadShortcuts()
        }
        .onDisappear {
            stopRecording()
        }
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .windowSnap)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon from remote URL (cached to prevent flashing)
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/window-snap.jpg")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "rectangle.split.2x2")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.cyan.opacity(0.3), radius: 8, y: 4)
            
            Text("Window Snap")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            // Stats row: installs + rating + category badge
            HStack(spacing: 12) {
                // Installs
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
                // Rating (clickable)
                Button {
                    showReviewsSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption.weight(.medium))
                            Text("(\(r.ratingCount))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("–")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(DroppySelectableButtonStyle(isSelected: false))
                
                // Category badge
                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.15))
                    )
            }
            
            Text("Keyboard-driven window management")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Snap windows to halves, quarters, or thirds with keyboard shortcuts.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "keyboard", text: "Configurable shortcuts")
                featureRow(icon: "rectangle.split.2x2", text: "Halves, quarters, thirds")
                featureRow(icon: "arrow.up.left.and.arrow.down.right", text: "Maximize and restore")
                featureRow(icon: "display", text: "Multi-monitor support")
            }
            
            // Screenshot
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/images/window-snap-screenshot.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            } placeholder: {
                EmptyView()
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var shortcutSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Shortcuts")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    loadDefaults()
                } label: {
                    Text("Load Defaults")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                .onHover { h in
                    withAnimation(DroppyAnimation.hoverQuick) { isHoveringDefaults = h }
                }
            }
            
            // Two-column grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(SnapAction.allCases.filter { $0 != .restore }) { action in
                    shortcutRow(for: action)
                }
            }
        }
        .padding(16)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func shortcutRow(for action: SnapAction) -> some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: action.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(width: 20)
            
            // Title
            Text(action.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // Shortcut button
            Button {
                if recordingAction == action {
                    stopRecording()
                } else {
                    startRecording(for: action)
                }
            } label: {
                HStack(spacing: 4) {
                    if recordingAction == action {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("...")
                            .font(.system(size: 11, weight: .medium))
                    } else if let shortcut = shortcuts[action] {
                        Text(shortcut.description)
                            .font(.system(size: 11, weight: .semibold))
                    } else {
                        Text("Click")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(recordingAction == action ? .primary : (shortcuts[action] != nil ? .primary : .secondary))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(recordingAction == action ? Color.red.opacity(isHoveringShortcut[action] == true ? 1.0 : 0.85) : (isHoveringShortcut[action] == true ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
                )
            }
            .buttonStyle(DroppySelectableButtonStyle(isSelected: shortcuts[action] != nil))
            .onHover { h in
                withAnimation(DroppyAnimation.hoverQuick) { isHoveringShortcut[action] = h }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    @State private var isHoveringReset = false
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            // Reset
            Button {
                removeDefaults()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 32))
            .help("Reset Shortcuts")
            
            DisableExtensionButton(extensionType: .windowSnap)
        }
        .padding(16)
    }
    
    // MARK: - Recording
    
    private func startRecording(for action: SnapAction) {
        stopRecording()
        recordingAction = action
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore just modifier keys pressed alone
            if event.keyCode == 54 || event.keyCode == 55 || event.keyCode == 56 ||
               event.keyCode == 58 || event.keyCode == 59 || event.keyCode == 60 ||
               event.keyCode == 61 || event.keyCode == 62 {
                return nil
            }
            
            // Capture the shortcut
            DispatchQueue.main.async {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let shortcut = SavedShortcut(keyCode: Int(event.keyCode), modifiers: flags.rawValue)
                saveShortcut(shortcut, for: action)
                stopRecording()
            }
            return nil
        }
    }
    
    private func stopRecording() {
        recordingAction = nil
        if let m = recordMonitor {
            NSEvent.removeMonitor(m)
            recordMonitor = nil
        }
    }
    
    private func loadShortcuts() {
        shortcuts = WindowSnapManager.shared.shortcuts
    }
    
    private func saveShortcut(_ shortcut: SavedShortcut, for action: SnapAction) {
        shortcuts[action] = shortcut
        Task { @MainActor in
            WindowSnapManager.shared.setShortcut(shortcut, for: action)
        }
    }
    
    private func loadDefaults() {
        Task { @MainActor in
            WindowSnapManager.shared.loadDefaults()
            loadShortcuts()
        }
    }
    
    private func removeDefaults() {
        Task { @MainActor in
            WindowSnapManager.shared.removeDefaults()
            loadShortcuts()
        }
    }
}
