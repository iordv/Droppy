//
//  DroppyAlertView.swift
//  Droppy
//
//  Custom styled alert dialogs matching the Droppy design language.
//

import SwiftUI
import AppKit

// MARK: - Alert Type

enum DroppyAlertStyle {
    case info
    case warning
    case error
    case permissions
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .permissions: return "lock.shield.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .permissions: return .blue
        }
    }
}

// MARK: - Alert View

struct DroppyAlertView: View {
    let style: DroppyAlertStyle
    let title: String
    let message: String
    let primaryButtonTitle: String
    let secondaryButtonTitle: String?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?
    
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var isPrimaryHovering = false
    @State private var isSecondaryHovering = false
    
    init(
        style: DroppyAlertStyle,
        title: String,
        message: String,
        primaryButtonTitle: String = "OK",
        secondaryButtonTitle: String? = nil,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil
    ) {
        self.style = style
        self.title = title
        self.message = message
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with NotchFace
            VStack(spacing: 16) {
                NotchFace(size: 60, isExcited: false)
                
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Content
            VStack(alignment: .center, spacing: 16) {
                // Message card
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: style.icon)
                            .foregroundStyle(style.iconColor)
                            .font(.system(size: 14))
                            .frame(width: 22)
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.02))
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Action buttons (secondary left, Spacer, primary right)
            HStack(spacing: 8) {
                if let secondaryTitle = secondaryButtonTitle, let onSecondary = onSecondary {
                    Button {
                        onSecondary()
                    } label: {
                        Text(secondaryTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSecondaryHovering ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.easeInOut(duration: 0.15)) { isSecondaryHovering = h }
                    }
                }
                
                Spacer()
                
                Button {
                    onPrimary()
                } label: {
                    Text(primaryButtonTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(isPrimaryHovering ? 1.0 : 0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.easeInOut(duration: 0.15)) { isPrimaryHovering = h }
                }
            }
            .padding(16)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Alert Controller

class DroppyAlertController {
    static let shared = DroppyAlertController()
    
    private var window: NSPanel?
    
    private init() {}
    
    /// Shows an alert and waits for user response
    @MainActor
    func show(
        style: DroppyAlertStyle,
        title: String,
        message: String,
        primaryButtonTitle: String = "OK",
        secondaryButtonTitle: String? = nil
    ) async -> Bool {
        return await withCheckedContinuation { continuation in
            let alertView = DroppyAlertView(
                style: style,
                title: title,
                message: message,
                primaryButtonTitle: primaryButtonTitle,
                secondaryButtonTitle: secondaryButtonTitle,
                onPrimary: { [weak self] in
                    self?.dismiss()
                    continuation.resume(returning: true)
                },
                onSecondary: { [weak self] in
                    self?.dismiss()
                    continuation.resume(returning: false)
                }
            )
            
            let hostingView = NSHostingView(rootView: alertView.preferredColorScheme(.dark)) // Force dark mode
            
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 150),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            panel.center()
            panel.title = title
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .visible
            
            panel.isMovableByWindowBackground = false
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.isReleasedWhenClosed = false
            panel.level = .screenSaver
            panel.hidesOnDeactivate = false
            
            panel.contentView = hostingView
            
            self.window = panel
            
            // Use deferred makeKey to avoid NotchWindow conflicts
            panel.orderFront(nil)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                panel.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    /// Shows a simple info/error alert (fire and forget)
    @MainActor
    func showSimple(
        style: DroppyAlertStyle,
        title: String,
        message: String
    ) {
        Task {
            _ = await show(style: style, title: title, message: message)
        }
    }
    
    private func dismiss() {
        window?.close()
        window = nil
    }
}

// MARK: - Convenience Extensions

extension DroppyAlertController {
    /// Shows an error alert
    @MainActor
    func showError(title: String, message: String) async {
        _ = await show(style: .error, title: title, message: message)
    }
    
    /// Shows a warning alert with optional cancel button
    @MainActor
    func showWarning(title: String, message: String, actionButtonTitle: String = "OK", showCancel: Bool = false) async -> Bool {
        return await show(
            style: .warning,
            title: title,
            message: message,
            primaryButtonTitle: actionButtonTitle,
            secondaryButtonTitle: showCancel ? "Cancel" : nil
        )
    }
    
    /// Shows a permissions alert with action button
    @MainActor
    func showPermissions(title: String, message: String, actionButtonTitle: String = "Open Settings") async -> Bool {
        return await show(
            style: .permissions,
            title: title,
            message: message,
            primaryButtonTitle: actionButtonTitle,
            secondaryButtonTitle: "Later"
        )
    }
}
