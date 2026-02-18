//
//  TerminalNotchInfoView.swift
//  Droppy
//
//  Terminal Notch extension setup and configuration view
//

import SwiftUI

struct TerminalNotchInfoView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.terminalNotchExternalApp) private var terminalNotchExternalApp = PreferenceDefault.terminalNotchExternalApp
    @ObservedObject private var manager = TerminalNotchManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringCancel = false
    @State private var isHoveringReviews = false
    @State private var isHoveringRecord = false
    @State private var isHoveringReset = false
    @State private var showReviewsSheet = false
    @State private var isRecordingShortcut = false
    @State private var showShortcutInfo = false
    @State private var recordMonitor: Any?
    
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed, non-scrolling)
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Scrollable content area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Features
                    screenshotSection
                    
                    // Settings (config card)
                    if manager.isInstalled {
                        settingsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 520)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons (fixed, non-scrolling)
            buttonSection
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .terminalNotch)
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/terminotch.jpg")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "terminal").font(.system(size: 32, weight: .medium)).foregroundStyle(.green)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .shadow(color: .green.opacity(0.4), radius: 8, y: 4)
            
            Text("Termi-Notch")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            // Stats row
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
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
                
                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
            }
            
            Text("Quick access terminal in your notch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Screenshot Section
    
    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Feature rows
            featureRow(icon: "terminal", text: "Full terminal emulation in the notch")
            featureRow(icon: "keyboard", text: "Customizable keyboard shortcut")
            featureRow(icon: "rectangle.expand.vertical", text: "Quick command & expanded modes")
            featureRow(icon: "arrow.up.forward.app", text: "Open in your terminal app anytime")
            
            // Screenshot
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/images/terminal-notch-screenshot.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            } placeholder: {
                // Placeholder with terminal preview
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .fill(AdaptiveColors.panelBackgroundAuto)
                    .frame(height: 120)
                    .overlay(
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("$")
                                    .foregroundStyle(.green)
                                Text("echo \"Hello, Droppy!\"")
                                    .foregroundStyle(AdaptiveColors.primaryTextAuto)
                            }
                            Text("Hello, Droppy!")
                                .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .padding(DroppySpacing.md)
                        , alignment: .topLeading
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.green)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(spacing: 16) {
            terminalAppSection
            
            // Keyboard Shortcut Section
            VStack(spacing: 12) {
                HStack {
                    Text("Keyboard Shortcut")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    // Info button tooltip
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .onTapGesture { showShortcutInfo.toggle() }
                        .onHover { hovering in
                            showShortcutInfo = hovering
                        }
                        .popover(isPresented: $showShortcutInfo, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "terminal")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.green)
                                    Text("Accessing Termi-Notch")
                                        .font(.headline)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Use **shortcut** from anywhere", systemImage: "keyboard")
                                    Label("**Click** terminal icon in expanded shelf", systemImage: "tray.and.arrow.down")
                                    Label("Also visible in **media HUD**", systemImage: "music.note")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .frame(width: 280)
                        }
                    
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    // Shortcut display
                    Text(manager.shortcut?.description ?? "Not set")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AdaptiveColors.buttonBackgroundAuto)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isRecordingShortcut ? Color.green : AdaptiveColors.subtleBorderAuto, lineWidth: isRecordingShortcut ? 2 : 1)
                        )
                    
                    // Record button
                    Button {
                        if isRecordingShortcut {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    } label: {
                        Text(isRecordingShortcut ? "Press…" : "Record")
                    }
                    .buttonStyle(DroppyAccentButtonStyle(color: isRecordingShortcut ? .red : .green, size: .small))
                }
                
                Text("Press the shortcut to toggle the terminal from anywhere")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DroppySpacing.lg)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
        }
    }

    private var terminalAppSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Terminal App")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Choose which app opens when you use \"Open in Terminal\".")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(TerminalNotchExternalApp.allCases) { app in
                    SettingsSegmentButton(
                        icon: app.icon,
                        label: app.title,
                        isSelected: terminalNotchExternalApp == app.rawValue,
                        tileWidth: 82
                    ) {
                        terminalNotchExternalApp = app.rawValue
                    }
                }
            }

            let selectedTerminalApp = TerminalNotchExternalApp(rawValue: terminalNotchExternalApp) ?? .appleTerminal
            if !selectedTerminalApp.isInstalled {
                Text("\(selectedTerminalApp.title) is not installed. Droppy will fall back to Terminal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Buttons
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            // Reset shortcut button (only when installed and shortcut exists)
            if manager.isInstalled && manager.shortcut != nil {
                Button {
                    manager.removeShortcut()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 32))
                .help("Reset Shortcut")
            }
            
            if manager.isInstalled {
                DisableExtensionButton(extensionType: .terminalNotch)
            } else {
                Button {
                    installExtension()
                } label: {
                    Text("Install")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .green, size: .small))
            }
        }
        .padding(DroppySpacing.lg)
    }
    
    // MARK: - Actions
    
    private func installExtension() {
        manager.isInstalled = true
        ExtensionType.terminalNotch.setRemoved(false)
        
        // Track installation
        Task {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "terminalNotch")
        }
        
        // Post notification
        NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.terminalNotch)
    }
    
    // MARK: - Shortcut Recording
    
    private func startRecording() {
        stopRecording()
        isRecordingShortcut = true
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
                self.manager.shortcut = shortcut
                self.manager.registerShortcut()
                self.stopRecording()
            }
            return nil
        }
    }
    
    private func stopRecording() {
        isRecordingShortcut = false
        if let m = recordMonitor {
            NSEvent.removeMonitor(m)
            recordMonitor = nil
        }
    }
}

#Preview {
    TerminalNotchInfoView()
        .frame(height: 600)
}
