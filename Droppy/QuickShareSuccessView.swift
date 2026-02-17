//
//  QuickShareSuccessView.swift
//  Droppy
//
//  Success popup for Droppy Quickshare - shows link created and copied to clipboard
//  Now also shows upload progress with animated progress bar
//

import SwiftUI
import AppKit

// MARK: - Upload State

enum QuickShareUploadState {
    case uploading(filename: String, fileCount: Int)
    case success(shareURL: String)
    case failed(error: String)
}

// MARK: - Quick Share View (supports progress and success)

struct QuickShareSuccessView: View {
    @Binding var uploadState: QuickShareUploadState
    let onDismiss: () -> Void
    
    @State private var showCopiedFeedback = false
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    
    var body: some View {
        VStack(spacing: 0) {
            switch uploadState {
            case .uploading(let filename, let fileCount):
                uploadingContent(filename: filename, fileCount: fileCount)
            case .success(let shareURL):
                successContent(shareURL: shareURL)
            case .failed(let error):
                failedContent(error: error)
            }
        }
        .frame(width: 500, height: 330)
        .background {
            if useTransparentBackground {
                Rectangle().fill(.ultraThinMaterial)
            } else {
                AdaptiveColors.panelBackgroundAuto
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.xxl, style: .continuous)
                .strokeBorder(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
        .animation(DroppyAnimation.basketTransition, value: isUploading)
    }
    
    private var isUploading: Bool {
        if case .uploading = uploadState { return true }
        return false
    }
    
    // MARK: - Uploading Content
    
    @ViewBuilder
    private func uploadingContent(filename: String, fileCount: Int) -> some View {
        VStack(spacing: 0) {
            // Header with NotchFace
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.1))
                        .frame(width: 65, height: 65)
                        .blur(radius: 14)
                    
                    NotchFace(size: 48, isExcited: false)
                }
                
                Text("Droppy Quickshare")
                    .font(.system(size: 22, weight: .bold))
                
                Text(fileCount > 1 ? "Uploading \(fileCount) items…" : "Uploading file…")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .frame(height: 140)
            
            // Content
            VStack(spacing: 20) {
                // Filename Display
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.cyan)
                        .frame(width: 22)
                    
                    Text(filename)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AdaptiveColors.overlayAuto(0.03))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AdaptiveColors.overlayAuto(0.05), lineWidth: 1)
                )
                
                // Animated progress bar
                QuickShareProgressBar()
            }
            .padding(.horizontal, 30)
            .frame(height: 120)
            
            Spacer()
            
            // Cancel button
            HStack {
                Spacer()
                
                Button(action: onDismiss) {
                    Text("Cancel")
                        .fixedSize()
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(DroppySpacing.lg)
        }
    }
    
    // MARK: - Success Content
    
    @ViewBuilder
    private func successContent(shareURL: String) -> some View {
        VStack(spacing: 0) {
            // Header with NotchFace
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.1))
                        .frame(width: 65, height: 65)
                        .blur(radius: 14)
                    
                    NotchFace(size: 48, isExcited: true)
                }
                
                Text("Droppy Quickshare")
                    .font(.system(size: 22, weight: .bold))
                
                Text("Your shareable link has been copied to clipboard")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .frame(height: 140)
            
            // Content
            VStack(spacing: 20) {
                // URL Display
                HStack(spacing: 12) {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.cyan)
                        .frame(width: 22)
                    
                    Text(shareURL)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AdaptiveColors.overlayAuto(0.03))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AdaptiveColors.overlayAuto(0.05), lineWidth: 1)
                )
                
                // Copied feedback
                HStack(spacing: 6) {
                    Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.clipboard.fill")
                        .font(.system(size: 12))
                    Text(showCopiedFeedback ? "Copied!" : "Link copied to clipboard")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(showCopiedFeedback ? .green : .secondary)
                .animation(DroppyAnimation.hoverQuick, value: showCopiedFeedback)
            }
            .padding(.horizontal, 30)
            .frame(height: 120)
            
            Spacer()
            
            // Action buttons (matches UpdateView style exactly)
            HStack(spacing: 10) {
                // Copy again button
                Button(action: { copyToClipboard(shareURL) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Again")
                    }
                    .fixedSize()
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                // Open in browser button
                Button(action: { openInBrowser(shareURL) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                        Text("Open Link")
                    }
                    .fixedSize()
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                // Manage button - opens Quickshare Manager
                Button(action: openManager) {
                    HStack(spacing: 6) {
                        Image(systemName: "tray.full")
                        Text("Manage")
                    }
                    .fixedSize()
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                Spacer()
                
                // Done button
                Button(action: onDismiss) {
                    Text("Done")
                        .fixedSize()
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .green, size: .small))
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(DroppySpacing.lg)
        }
    }
    
    // MARK: - Failed Content
    
    @ViewBuilder
    private func failedContent(error: String) -> some View {
        VStack(spacing: 0) {
            // Header with NotchFace
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 65, height: 65)
                        .blur(radius: 14)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.red)
                }
                
                Text("Upload Failed")
                    .font(.system(size: 22, weight: .bold))
                
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .frame(height: 140)
            
            Spacer()
            
            // Dismiss button
            HStack {
                Spacer()
                
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .fixedSize()
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(DroppySpacing.lg)
        }
    }
    
    private func copyToClipboard(_ shareURL: String) {
        let clipboard = NSPasteboard.general
        clipboard.clearContents()
        clipboard.setString(shareURL, forType: .string)
        
        showCopiedFeedback = true
        HapticFeedback.copy()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedFeedback = false
        }
    }
    
    private func openInBrowser(_ shareURL: String) {
        if let url = URL(string: shareURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openManager() {
        onDismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            QuickshareManagerWindowController.show()
        }
    }
}

// MARK: - Animated Progress Bar

struct QuickShareProgressBar: View {
    @State private var animating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(AdaptiveColors.overlayAuto(0.1))
                    .frame(height: 6)
                
                // Animated glow bar
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.3),
                                Color.cyan,
                                Color.cyan.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * 0.4, height: 6)
                    .offset(x: animating ? geometry.size.width * 0.6 : 0)
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                animating = true
            }
        }
    }
}

// MARK: - Window Controller (matches OnboardingWindowController exactly)

/// Observable state for the Quickshare window - allows live updates while window is open
@Observable
final class QuickShareWindowState {
    var uploadState: QuickShareUploadState = .uploading(filename: "", fileCount: 1)
}

final class QuickShareSuccessWindowController: NSObject, NSWindowDelegate {
    static var shared: QuickShareSuccessWindowController?
    
    private var window: NSPanel?
    private let windowState = QuickShareWindowState()
    
    /// Show the window immediately in uploading state
    static func showUploading(filename: String, fileCount: Int) {
        // Close existing window if any
        shared?.close()
        
        let controller = QuickShareSuccessWindowController()
        shared = controller
        controller.windowState.uploadState = .uploading(filename: filename, fileCount: fileCount)
        controller.showWindow()
    }
    
    /// Legacy method - show directly with success URL (for backwards compatibility)
    static func show(shareURL: String) {
        // Close existing window if any
        shared?.close()
        
        let controller = QuickShareSuccessWindowController()
        shared = controller
        controller.windowState.uploadState = .success(shareURL: shareURL)
        controller.showWindow()
    }
    
    /// Update the current window to show success state
    static func updateToSuccess(shareURL: String) {
        guard let controller = shared else {
            // No window open, create one
            show(shareURL: shareURL)
            return
        }
        
        DispatchQueue.main.async {
            withAnimation(DroppyAnimation.basketTransition) {
                controller.windowState.uploadState = .success(shareURL: shareURL)
            }
        }
    }
    
    /// Update the current window to show failed state
    static func updateToFailed(error: String) {
        guard let controller = shared else { return }
        
        DispatchQueue.main.async {
            withAnimation(DroppyAnimation.basketTransition) {
                controller.windowState.uploadState = .failed(error: error)
            }
        }
    }
    
    private func showWindow() {
        let contentView = QuickShareSuccessView(
            uploadState: Binding(
                get: { [weak self] in self?.windowState.uploadState ?? .uploading(filename: "", fileCount: 1) },
                set: { [weak self] newValue in self?.windowState.uploadState = newValue }
            ),
            onDismiss: { [weak self] in
                DispatchQueue.main.async {
                    self?.close()
                }
            }
        )
        
        
        let hostingView = NSHostingView(rootView: contentView)
        
        // Use NSPanel with borderless style (matches onboarding exactly)
        let newWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 330),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.contentView = hostingView
        
        // Center on main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = newWindow.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2
            newWindow.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            newWindow.center()
        }
        // Use level higher than basket (popUpMenu+1) so QuickShare appears on top
        newWindow.level = NSWindow.Level(Int(NSWindow.Level.popUpMenu.rawValue) + 2)
        
        window = newWindow
        
        // Start scaled down and invisible for spring animation
        newWindow.alphaValue = 0
        if let contentView = newWindow.contentView {
            contentView.wantsLayer = true
            contentView.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
            contentView.layer?.opacity = 0
        }
        
        // Show window
        newWindow.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            newWindow.makeKeyAndOrderFront(nil)
        }
        
        // Spring animation (matches onboarding)
        if let layer = newWindow.contentView?.layer {
            // Fade in
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 0
            fadeAnim.toValue = 1
            fadeAnim.duration = 0.25
            fadeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fadeAnim.fillMode = .forwards
            fadeAnim.isRemovedOnCompletion = false
            layer.add(fadeAnim, forKey: "fadeIn")
            layer.opacity = 1
            
            // Scale with spring overshoot
            let scaleAnim = CASpringAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.85
            scaleAnim.toValue = 1.0
            scaleAnim.mass = 1.0
            scaleAnim.stiffness = 250
            scaleAnim.damping = 22
            scaleAnim.initialVelocity = 6
            scaleAnim.duration = scaleAnim.settlingDuration
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            layer.add(scaleAnim, forKey: "scaleSpring")
            layer.transform = CATransform3DIdentity
        }
        
        // Fade window alpha
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            newWindow.animator().alphaValue = 1.0
        })
    }
    
    func close() {
        guard let panel = window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window = nil
            panel.orderOut(nil)
            QuickShareSuccessWindowController.shared = nil
        })
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        window = nil
        QuickShareSuccessWindowController.shared = nil
    }
}
