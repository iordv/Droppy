//
//  ElementCaptureInfoView.swift
//  Droppy
//
//  Element Capture extension info sheet with shortcut recording
//

import SwiftUI

struct ElementCaptureInfoView: View {
    @Binding var currentShortcut: SavedShortcut?
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringClose = false
    @State private var isRecording = false
    @State private var isHoveringRecord = false
    @State private var recordMonitor: Any?
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
                VStack(spacing: 24) {
                    // Features + Screenshot
                    featuresSection
                    
                    // Keyboard Shortcut Card
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
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onDisappear {
            stopRecording()
        }
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .elementCapture)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon from remote URL (cached to prevent flashing)
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/element-capture.jpg")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "viewfinder")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
            
            Text("Element Capture")
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
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    )
            }
            
            Text("Capture any screen element instantly")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Capture specific screen elements and copy them to clipboard or add to Droppy.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "keyboard", text: "Configurable shortcuts")
                featureRow(icon: "rectangle.dashed", text: "Select screen regions")
                featureRow(icon: "doc.on.clipboard", text: "Copy to clipboard")
                featureRow(icon: "plus.circle", text: "Add directly to Droppy")
            }
            
            // Screenshot
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/images/element-capture-screenshot.png")) { image in
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
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcut")
                .font(.headline)
                .foregroundStyle(.primary)
            
            // Shortcut display + Record button
            HStack(spacing: 8) {
                // Shortcut display
                Text(currentShortcut?.description ?? "None")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                    .background(AdaptiveColors.buttonBackgroundAuto)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isRecording ? Color.blue : AdaptiveColors.subtleBorderAuto, lineWidth: isRecording ? 2 : 1)
                    )
                
                // Record button
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    Text(isRecording ? "Press..." : "Record")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: isRecording ? .red : .blue, size: .small))
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
                UserDefaults.standard.removeObject(forKey: "elementCaptureShortcut")
                ElementCaptureManager.shared.shortcut = nil
                ElementCaptureManager.shared.stopMonitoringShortcut()
                currentShortcut = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 32))
            .help("Reset Shortcut")
            
            DisableExtensionButton(extensionType: .elementCapture)
        }
        .padding(16)
    }
    
    // MARK: - Recording
    
    private func startRecording() {
        isRecording = true
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
                saveShortcut(shortcut)
                stopRecording()
            }
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let m = recordMonitor {
            NSEvent.removeMonitor(m)
            recordMonitor = nil
        }
    }
    
    private func saveShortcut(_ shortcut: SavedShortcut) {
        currentShortcut = shortcut
        if let encoded = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(encoded, forKey: "elementCaptureShortcut")
            
            // Track extension activation (only once per user)
            if !UserDefaults.standard.bool(forKey: "elementCaptureTracked") {
                AnalyticsService.shared.trackExtensionActivation(extensionId: "elementCapture")
                UserDefaults.standard.set(true, forKey: "elementCaptureTracked")
            }
        }
        // Also update the manager (for global hotkey monitoring)
        Task { @MainActor in
            ElementCaptureManager.shared.shortcut = shortcut
            ElementCaptureManager.shared.startMonitoringShortcut()
        }
    }
}
