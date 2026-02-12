//
//  FinderServicesSetupView.swift
//  Droppy
//
//  Guides users through enabling Finder Services in System Settings
//  Design matches AIInstallView for visual consistency
//

import SwiftUI
import AppKit

@discardableResult
func openFinderServicesSettings() -> Bool {
    // Try direct Services/Keyboard links first, then broader Keyboard pane fallbacks.
    let candidates = [
        "x-apple.systempreferences:com.apple.preference.keyboard?Services",
        "x-apple.systempreferences:com.apple.preference.keyboard?KeyboardShortcuts",
        "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts",
        "x-apple.systempreferences:com.apple.Keyboard-Settings.extension",
        "x-apple.systempreferences:com.apple.Keyboard-Settings",
        "x-apple.systempreferences:com.apple.preference.keyboard"
    ]
    
    for candidate in candidates {
        guard let url = URL(string: candidate) else { continue }
        if NSWorkspace.shared.open(url) {
            return true
        }
    }
    
    return false
}

// MARK: - Finder Services Setup View

struct FinderServicesSetupView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var hasOpenedSettings = false
    @State private var openSettingsFailed = false
    
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - matching AIInstallView structure
            headerSection
            
            // Steps content
            stepsSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Action Buttons - matching AIInstallView
            buttonSection
        }
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .droppyFloatingShadow()
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon - Finder icon from remote URL (cached to prevent flashing)
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/finder.png")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "folder").font(.system(size: 32)).foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            
            Text("Enable Finder Services")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text("Quick one-time setup")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Steps
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepRow(
                number: 1,
                text: "Click \"Open Settings\" below.",
                detail: "Droppy opens Keyboard Shortcuts in System Settings."
            )
            stepRow(
                number: 2,
                text: "Open Services in Keyboard Shortcuts.",
                detail: "Path: Keyboard > Keyboard Shortcuts > Services."
            )
            stepRow(
                number: 3,
                text: "Enable \"Add to Droppy Shelf\" and \"Add to Droppy Basket\".",
                detail: "Look under Files and Folders."
            )
            stepRow(
                number: 4,
                text: "In Finder, right-click selected files > Quick Actions or Services.",
                detail: "You should now see both Droppy actions."
            )
            
            if openSettingsFailed {
                Text("Could not open System Settings automatically. Open it manually, then go to Keyboard > Keyboard Shortcuts > Services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    private func stepRow(number: Int, text: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 22, height: 22)
                .background(Color.blue.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.sm, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
                
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                .fill(Color.primary.opacity(useTransparentBackground ? 0.08 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Buttons
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            // Cancel button - matching AIInstallView secondary style
            Button {
                onComplete()
            } label: {
                Text("Done")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            // Action button - matching AIInstallView primary style
            Button {
                openServicesSettings()
                withAnimation(DroppyAnimation.state) {
                    hasOpenedSettings = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: hasOpenedSettings ? "arrow.clockwise" : "gear")
                    Text(hasOpenedSettings ? "Open Again" : "Open Settings")
                }
            }
            .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
        }
        .padding(DroppySpacing.lg)
        .animation(DroppyAnimation.transition, value: hasOpenedSettings)
    }
    
    private func openServicesSettings() {
        openSettingsFailed = !openFinderServicesSettings()
    }
}

// MARK: - Sheet View (for SwiftUI .sheet presentation)

/// Sheet-compatible version that uses @Environment(\.dismiss) like AIInstallView
struct FinderServicesSetupSheetView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @Environment(\.dismiss) private var dismiss
    @State private var hasOpenedSettings = false
    @State private var openSettingsFailed = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - matching AIInstallView structure
            headerSection
            
            // Steps content
            stepsSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Action Buttons - matching AIInstallView
            buttonSection
        }
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipped()  // Same as AIInstallView
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon - Finder icon from remote URL (cached to prevent flashing)
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/finder.png")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "folder").font(.system(size: 32)).foregroundStyle(.blue)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            
            Text("Enable Finder Services")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text("Quick one-time setup")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Steps
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepRow(
                number: 1,
                text: "Click \"Open Settings\" below.",
                detail: "Droppy opens Keyboard Shortcuts in System Settings."
            )
            stepRow(
                number: 2,
                text: "Open Services in Keyboard Shortcuts.",
                detail: "Path: Keyboard > Keyboard Shortcuts > Services."
            )
            stepRow(
                number: 3,
                text: "Enable \"Add to Droppy Shelf\" and \"Add to Droppy Basket\".",
                detail: "Look under Files and Folders."
            )
            stepRow(
                number: 4,
                text: "In Finder, right-click selected files > Quick Actions or Services.",
                detail: "You should now see both Droppy actions."
            )
            
            if openSettingsFailed {
                Text("Could not open System Settings automatically. Open it manually, then go to Keyboard > Keyboard Shortcuts > Services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    private func stepRow(number: Int, text: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 22, height: 22)
                .background(Color.blue.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.sm, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineSpacing(2)
                
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                .fill(Color.primary.opacity(useTransparentBackground ? 0.08 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Buttons
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            // Cancel button - matching AIInstallView secondary style
            Button {
                dismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            // Action button - matching AIInstallView primary style
            Button {
                openServicesSettings()
                withAnimation(DroppyAnimation.state) {
                    hasOpenedSettings = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: hasOpenedSettings ? "arrow.clockwise" : "gear")
                    Text(hasOpenedSettings ? "Open Again" : "Open Settings")
                }
            }
            .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
        }
        .padding(DroppySpacing.lg)
        .animation(DroppyAnimation.transition, value: hasOpenedSettings)
    }
    
    private func openServicesSettings() {
        openSettingsFailed = !openFinderServicesSettings()
    }
}

// MARK: - Window Controller

final class FinderServicesSetupWindowController: NSObject, NSWindowDelegate {
    static let shared = FinderServicesSetupWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    func show() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // If window already exists, just bring it to front
            if let window = self.window {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                return
            }
            
            // Create the SwiftUI view
            let view = FinderServicesSetupView {
                self.close()
            }

            let hostingView = NSHostingView(rootView: view)
            
            // Create the window - exact same style as sheet presentation
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 420),
                styleMask: [.fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            newWindow.center()
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .hidden
            newWindow.level = .floating
            
            newWindow.isMovableByWindowBackground = true
            newWindow.backgroundColor = .clear  // Clear to show rounded corners
            newWindow.isOpaque = false
            newWindow.hasShadow = false  // View has its own shadow
            newWindow.isReleasedWhenClosed = false
            
            newWindow.delegate = self
            newWindow.contentView = hostingView
            
            self.window = newWindow
            
            // Bring to front and activate
            newWindow.orderFront(nil)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                newWindow.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    func close() {
        DispatchQueue.main.async { [weak self] in
            self?.window?.close()
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
