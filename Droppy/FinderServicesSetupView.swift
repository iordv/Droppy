//
//  FinderServicesSetupView.swift
//  Droppy
//
//  Guides users through enabling Finder Services in System Settings
//  Required because macOS doesn't allow programmatic enabling of services
//

import SwiftUI
import AppKit

// MARK: - Finder Services Setup View

struct FinderServicesSetupView: View {
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    
    @State private var isOpenHovering = false
    @State private var isDoneHovering = false
    @State private var hasOpenedSettings = false
    
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with icon and info
            HStack(spacing: 14) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Enable Finder Services")
                        .font(.headline)
                    
                    Text("macOS requires you to enable Droppy's services in System Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(20)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: "1", text: "Click \"Open System Settings\" below")
                stepRow(number: "2", text: "Click \"Keyboard Shortcuts...\" button")
                stepRow(number: "3", text: "Select \"Services\" in the left sidebar")
                stepRow(number: "4", text: "Check \"Add to Droppy Shelf\" and \"Add to Droppy Basket\"")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Action buttons
            HStack(spacing: 10) {
                Button {
                    onComplete()
                } label: {
                    Text("Done")
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(isDoneHovering ? 0.15 : 0.08))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isDoneHovering = h
                    }
                }
                
                Spacer()
                
                Button {
                    openServicesSettings()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        hasOpenedSettings = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: hasOpenedSettings ? "checkmark" : "gear")
                            .font(.system(size: 12, weight: .semibold))
                        Text(hasOpenedSettings ? "Settings Opened" : "Open System Settings")
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background((hasOpenedSettings ? Color.green : Color.blue).opacity(isOpenHovering ? 1.0 : 0.8))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isOpenHovering = h
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
    }
    
    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue.opacity(0.6))
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
        }
    }
    
    private func openServicesSettings() {
        // Opens System Settings > Keyboard
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
            let hostingView = NSHostingView(rootView: view)
            
            // Create the window
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            newWindow.center()
            newWindow.title = "Finder Services Setup"
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .visible
            
            newWindow.isMovableByWindowBackground = false
            newWindow.backgroundColor = .clear
            newWindow.isOpaque = false
            newWindow.hasShadow = true
            newWindow.isReleasedWhenClosed = false
            
            newWindow.delegate = self
            newWindow.contentView = hostingView
            
            self.window = newWindow
            
            // Bring to front and activate - use deferred makeKey to avoid NotchWindow conflicts
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
