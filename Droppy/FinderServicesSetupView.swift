//
//  FinderServicesSetupView.swift
//  Droppy
//
//  Guides users through enabling Finder Services in System Settings
//  Design matches AIInstallView for visual consistency
//

import SwiftUI
import AppKit

// MARK: - Finder Services Setup View

struct FinderServicesSetupView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var isHoveringAction = false
    @State private var isHoveringCancel = false
    @State private var hasOpenedSettings = false
    
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
        .frame(width: 340)  // Same width as AIInstallView
        .fixedSize(horizontal: false, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
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
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            
            Text("Enable Finder Services")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text("One-time setup in System Settings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Steps
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepRow(number: 1, text: "Click \"Open Settings\" below")
            stepRow(number: 2, text: "Click \"Keyboard Shortcuts...\" button")
            stepRow(number: 3, text: "Select \"Services\" in the left sidebar")
            stepRow(number: 4, text: "Enable \"Add to Droppy Shelf\" and \"Add to Droppy Basket\"")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 22, height: 22)
                .background(Color.blue.opacity(0.6))
                .clipShape(Circle())
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
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
                    Image(systemName: hasOpenedSettings ? "checkmark" : "gear")
                    Text(hasOpenedSettings ? "Opened" : "Open Settings")
                }
            }
            .buttonStyle(DroppyAccentButtonStyle(color: hasOpenedSettings ? .green : .blue, size: .small))
        }
        .padding(16)
        .animation(DroppyAnimation.transition, value: hasOpenedSettings)
    }
    
    private func openServicesSettings() {
        // Opens System Settings > Keyboard
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Sheet View (for SwiftUI .sheet presentation)

/// Sheet-compatible version that uses @Environment(\.dismiss) like AIInstallView
struct FinderServicesSetupSheetView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringCancel = false
    @State private var hasOpenedSettings = false
    
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
        .frame(width: 340)  // Same width as AIInstallView
        .fixedSize(horizontal: false, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
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
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            
            Text("Enable Finder Services")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text("One-time setup in System Settings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Steps
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepRow(number: 1, text: "Click \"Open Settings\" below")
            stepRow(number: 2, text: "Click \"Keyboard Shortcuts...\" button")
            stepRow(number: 3, text: "Select \"Services\" in the left sidebar")
            stepRow(number: 4, text: "Enable \"Add to Droppy Shelf\" and \"Add to Droppy Basket\"")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 22, height: 22)
                .background(Color.blue.opacity(0.6))
                .clipShape(Circle())
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
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
                    Image(systemName: hasOpenedSettings ? "checkmark" : "gear")
                    Text(hasOpenedSettings ? "Opened" : "Open Settings")
                }
            }
            .buttonStyle(DroppyAccentButtonStyle(color: hasOpenedSettings ? .green : .blue, size: .small))
        }
        .padding(16)
        .animation(DroppyAnimation.transition, value: hasOpenedSettings)
    }
    
    private func openServicesSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
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
            .preferredColorScheme(.dark) // Force dark mode always
            let hostingView = NSHostingView(rootView: view)
            
            // Create the window - exact same style as sheet presentation
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 320),
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
