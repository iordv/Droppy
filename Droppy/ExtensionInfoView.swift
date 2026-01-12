//
//  ExtensionInfoView.swift
//  Droppy
//
//  Extension information popups matching AIInstallView styling
//

import SwiftUI
import AppKit

// MARK: - Extension Type

enum ExtensionType: String, CaseIterable, Identifiable {
    case aiBackgroundRemoval
    case alfred
    case finder
    case spotify
    case elementCapture
    
    /// URL-safe ID for deep links
    case finderServices  // Alias for finder
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .aiBackgroundRemoval: return "AI Background Removal"
        case .alfred: return "Alfred Workflow"
        case .finder, .finderServices: return "Finder Services"
        case .spotify: return "Spotify Integration"
        case .elementCapture: return "Element Capture"
        }
    }
    
    var subtitle: String {
        switch self {
        case .aiBackgroundRemoval: return "One-click install"
        case .alfred: return "Requires Powerpack"
        case .finder, .finderServices: return "One-time setup"
        case .spotify: return "No setup needed"
        case .elementCapture: return "Keyboard shortcuts"
        }
    }
    
    var category: String {
        switch self {
        case .aiBackgroundRemoval: return "AI"
        case .alfred, .finder, .finderServices, .elementCapture: return "Productivity"
        case .spotify: return "Media"
        }
    }
    
    // Colors matching the extension card accent colors
    var categoryColor: Color {
        switch self {
        case .aiBackgroundRemoval: return .pink
        case .alfred: return .purple
        case .finder, .finderServices: return .blue
        case .spotify: return .green
        case .elementCapture: return .orange
        }
    }
    
    var description: String {
        switch self {
        case .aiBackgroundRemoval:
            return "Remove backgrounds from images instantly using local AI. No internet required, your images stay private. One-click install gets you started in seconds."
        case .alfred:
            return "Push any selected file or folder to Droppy instantly with a customizable Alfred hotkey. Perfect for power users who prefer keyboard-driven workflows."
        case .finder, .finderServices:
            return "Right-click any file in Finder to instantly add it to Droppy. No extra apps needed—it's built right into macOS."
        case .spotify:
            return "Control Spotify playback directly from the notch. See album art, track info, and use play/pause controls without switching apps."
        case .elementCapture:
            return "Capture specific screen elements and copy them to clipboard or add to Droppy. Perfect for grabbing UI components, icons, or any visual element."
        }
    }
    
    var features: [(icon: String, text: String)] {
        switch self {
        case .aiBackgroundRemoval:
            return [
                ("cpu", "Runs entirely on-device"),
                ("lock.shield", "Private—images never leave your Mac"),
                ("bolt.fill", "Fast InSPyReNet AI engine"),
                ("arrow.down.circle", "One-click install")
            ]
        case .alfred:
            return [
                ("keyboard", "Customizable keyboard shortcuts"),
                ("bolt.fill", "Instant file transfer"),
                ("folder.fill", "Works with files and folders"),
                ("arrow.right.circle", "Opens workflow in Alfred")
            ]
        case .finder, .finderServices:
            return [
                ("cursorarrow.click.2", "Right-click context menu"),
                ("bolt.fill", "Instant integration"),
                ("checkmark.seal.fill", "No extra apps required"),
                ("gearshape", "Configurable in Settings")
            ]
        case .spotify:
            return [
                ("music.note", "Now playing info in notch"),
                ("play.circle.fill", "Playback controls"),
                ("photo.fill", "Album art display"),
                ("link", "Secure OAuth connection")
            ]
        case .elementCapture:
            return [
                ("keyboard", "Configurable keyboard shortcuts"),
                ("rectangle.dashed", "Select screen regions"),
                ("doc.on.clipboard", "Copy to clipboard"),
                ("plus.circle", "Add directly to Droppy")
            ]
        }
    }
    
    @ViewBuilder
    var iconView: some View {
        switch self {
        case .aiBackgroundRemoval:
            // Same as AIBackgroundRemovalCard - uses AIExtensionIcon
            AIExtensionIcon(size: 64)
        case .alfred:
            // Same as AlfredExtensionCard
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.15))
                Image("AlfredIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            }
            .frame(width: 64, height: 64)
        case .finder, .finderServices:
            // Same as FinderExtensionCard - official Finder icon
            Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app"))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
        case .spotify:
            // Same as SpotifyExtensionCard
            Image("SpotifyIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
        case .elementCapture:
            // Same as ElementCaptureCard - with squircle background
            Image(systemName: "viewfinder")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 64, height: 64)
                .background(Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Extension Info View

struct ExtensionInfoView: View {
    let extensionType: ExtensionType
    var onAction: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringClose = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Features
            featuresSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Buttons
            buttonSection
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black)
        .clipped()
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            extensionType.iconView
                .shadow(color: extensionType.categoryColor.opacity(0.3), radius: 8, y: 4)
            
            // Title
            Text(extensionType.title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            // Subtitle with category badge
            HStack(spacing: 8) {
                Text(extensionType.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(extensionType.categoryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(extensionType.categoryColor.opacity(0.15))
                    )
                
                Text(extensionType.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Features
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(extensionType.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            
            ForEach(Array(extensionType.features.enumerated()), id: \.offset) { _, feature in
                featureRow(icon: feature.icon, text: feature.text)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(extensionType.categoryColor)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Buttons
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            // Close button
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(isHoveringClose ? 0.15 : 0.1))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringClose = h
                }
            }
            
            Spacer()
            
            // Action button (optional)
            if let action = onAction {
                Button {
                    action()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: actionIcon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(actionText)
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(extensionType.categoryColor.opacity(isHoveringAction ? 1.0 : 0.85))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isHoveringAction = h
                    }
                }
            }
        }
        .padding(16)
    }
    
    private var actionText: String {
        switch extensionType {
        case .aiBackgroundRemoval: return "Install"
        case .alfred: return "Install Workflow"
        case .finder, .finderServices: return "Configure"
        case .spotify: return "Connect"
        case .elementCapture: return "Configure Shortcut"
        }
    }
    
    private var actionIcon: String {
        switch extensionType {
        case .aiBackgroundRemoval: return "arrow.down.circle.fill"
        case .alfred: return "arrow.down.circle.fill"
        case .finder, .finderServices: return "gearshape"
        case .spotify: return "link"
        case .elementCapture: return "keyboard"
        }
    }
}

// MARK: - Element Capture Info View (with shortcut recording)

struct ElementCaptureInfoView: View {
    @Binding var currentShortcut: SavedShortcut?
    
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringClose = false
    @State private var isRecording = false
    @State private var recordMonitor: Any?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Features
            featuresSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Shortcut recording section
            shortcutSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Buttons
            buttonSection
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black)
        .clipped()
        .onDisappear {
            stopRecording()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon - with squircle background matching onboarding
            Image(systemName: "viewfinder")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 64, height: 64)
                .background(Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 4)
            
            Text("Element Capture")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            HStack(spacing: 8) {
                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
                
                Text("Keyboard shortcuts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Capture specific screen elements and copy them to clipboard or add to Droppy. Perfect for grabbing UI components, icons, or any visual element.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            
            featureRow(icon: "keyboard", text: "Configurable keyboard shortcuts")
            featureRow(icon: "rectangle.dashed", text: "Select screen regions")
            featureRow(icon: "doc.on.clipboard", text: "Copy to clipboard")
            featureRow(icon: "plus.circle", text: "Add directly to Droppy")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var shortcutSection: some View {
        VStack(spacing: 12) {
            Text("Keyboard Shortcut")
                .font(.headline)
                .foregroundStyle(.white)
            
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 8) {
                    if isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Press keys...")
                            .font(.system(size: 14, weight: .medium))
                    } else if let shortcut = currentShortcut {
                        Image(systemName: "keyboard")
                            .font(.system(size: 12))
                        Text(shortcut.description)
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Image(systemName: "record.circle")
                            .font(.system(size: 12))
                        Text("Click to record shortcut")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .foregroundStyle(isRecording ? .white : (currentShortcut != nil ? .primary : .white))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isRecording ? Color.red.opacity(0.85) : (currentShortcut != nil ? Color.white.opacity(0.1) : Color.orange.opacity(0.85)))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(isHoveringClose ? 0.15 : 0.1))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringClose = h
                }
            }
            
            Spacer()
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
        }
        // Also update the manager (for global hotkey monitoring)
        Task { @MainActor in
            ElementCaptureManager.shared.shortcut = shortcut
            ElementCaptureManager.shared.startMonitoringShortcut()
        }
    }
}

// MARK: - Preview

#Preview {
    ExtensionInfoView(extensionType: .alfred) {
        print("Action tapped")
    }
    .frame(width: 340, height: 450)
}
