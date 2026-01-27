//
//  NotificationHUDView.swift
//  Droppy
//
//  Polished Notification HUD that displays in the notch
//  Features: Smooth animations, clear layout, stacked notifications
//

import SwiftUI

/// Polished Notification HUD with smooth animations and clear layout
/// - Expands smoothly from notch
/// - Shows app icon, title, sender, message
/// - Supports notification queue with indicators
/// - Click to open, swipe to dismiss
struct NotificationHUDView: View {
    @ObservedObject var manager: NotificationHUDManager
    let hudWidth: CGFloat
    var targetScreen: NSScreen? = nil

    @State private var isHovering = false
    @State private var isPressed = false
    @State private var dragOffset: CGFloat = 0
    @State private var appearScale: CGFloat = 0.8
    @State private var appearOpacity: Double = 0

    /// Centralized layout calculator
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first!)
    }

    /// Whether we're in compact mode (Dynamic Island style)
    private var isCompact: Bool {
        layout.isDynamicIslandMode
    }

    /// Whether notification is expanded to show full content
    private var isExpanded: Bool {
        // Always expand to show content when a notification is present
        // This ensures title and body are not cut off
        return manager.currentNotification != nil || manager.isExpanded || isHovering
    }

    var body: some View {
        Group {
            if isCompact {
                compactLayout
            } else {
                expandedNotchLayout
            }
        }
        .contentShape(Rectangle())
        // Click affordance: pointer cursor on hover
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isHovering = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        // Press state for visual feedback
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPressed = false
                    }
                }
        )
        .onTapGesture {
            openSourceApp()
        }
        .gesture(dismissGesture)
        .offset(y: dragOffset)
        .opacity(appearOpacity * (1.0 - Double(abs(dragOffset)) / 80.0))
        .scaleEffect(appearScale * (isPressed ? 0.97 : (isHovering ? 1.02 : 1.0)))
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appearScale = 1.0
                appearOpacity = 1.0
            }
        }
        .onChange(of: manager.currentNotification?.id) { _, _ in
            // Animate when notification changes
            appearScale = 0.9
            appearOpacity = 0.5
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appearScale = 1.0
                appearOpacity = 1.0
            }
        }
    }

    // MARK: - Dismiss Gesture

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // Allow upward drag for dismiss
                if value.translation.height < 0 {
                    dragOffset = value.translation.height * 0.6
                }
            }
            .onEnded { value in
                if value.translation.height < -30 || value.predictedEndTranslation.height < -50 {
                    // Dismiss with animation
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        dragOffset = -100
                        appearOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        manager.dismissCurrentOnly()
                        dragOffset = 0
                        appearOpacity = 1
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Compact Layout (Dynamic Island)

    private var compactLayout: some View {
        HStack(spacing: 14) {
            // App icon - larger and more prominent
            appIconView(size: 42)

            // Content - clean vertical stack
            VStack(alignment: .leading, spacing: 2) {
                // Top row: App name and time
                HStack {
                    if let notification = manager.currentNotification {
                        Text(notification.appName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    if let notification = manager.currentNotification {
                        Text(timeAgo(notification.timestamp))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                // Title - prominent
                if let notification = manager.currentNotification {
                    Text(notification.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // Body - message content
                if manager.showPreview, let body = manager.currentNotification?.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(isExpanded ? 3 : 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Queue indicator + chevron
            VStack(alignment: .trailing, spacing: 6) {
                if manager.queueCount > 1 {
                    queueIndicator
                }
                
                if isHovering {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: layout.notchHeight)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.1 : 0.05))
                .animation(.easeOut(duration: 0.2), value: isHovering)
        )
    }

    // MARK: - Expanded Notch Layout (Full Notch with Wings)

    private var expandedNotchLayout: some View {
        HStack(spacing: 0) {
            // Left wing: App icon and name
            leftWing
                .frame(width: wingWidth)

            // Notch spacer
            Spacer()
                .frame(width: layout.notchWidth)

            // Right wing: Content
            rightWing
                .frame(width: wingWidth)
        }
        .frame(height: isExpanded ? expandedHeight : layout.notchHeight)
        // Hit-testable background + hover highlight
        .background(
            ZStack {
                // Almost invisible background to ensure clicks are captured
                Color.white.opacity(0.001)
                
                // Hover highlight
                Color.white.opacity(isHovering ? 0.06 : 0)
            }
            .animation(.easeOut(duration: 0.2), value: isHovering)
        )
    }

    private var wingWidth: CGFloat {
        (hudWidth - layout.notchWidth) / 2
    }

    private var expandedHeight: CGFloat {
        let baseHeight = layout.notchHeight
        let hasBody = manager.showPreview && manager.currentNotification?.body != nil
        let hasSubtitle = manager.currentNotification?.displaySubtitle != nil

        if isExpanded {
            var height = baseHeight + 24
            if hasSubtitle { height += 18 }
            if hasBody { height += 42 } // Increased for 3 lines (was 28)
            return min(height, baseHeight + 85) // Increased max height (was 70)
        }
        return baseHeight
    }

    // MARK: - Left Wing

    private var leftWing: some View {
        HStack(spacing: 12) {
            // App icon - larger and more prominent
            appIconView(size: 36)

            // App name + queue count
            VStack(alignment: .leading, spacing: 2) {
                if let notification = manager.currentNotification {
                    Text(notification.appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                if manager.queueCount > 1 {
                    Text("\(manager.queueCount) more")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 14)
    }

    // MARK: - Right Wing

    private var rightWing: some View {
        HStack {
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                // Title (sender or main title) - prominent
                if let notification = manager.currentNotification {
                    Text(notification.displayTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // Subtitle
                if let subtitle = manager.currentNotification?.displaySubtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                // Body
                if manager.showPreview, let body = manager.currentNotification?.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(isExpanded ? 3 : 1) // Increased to 3 lines
                        .multilineTextAlignment(.trailing)
                }

                // Time + open hint (show when expanded/hovering)
                if isExpanded || isHovering {
                    HStack(spacing: 6) {
                        if let notification = manager.currentNotification {
                            Text(timeAgo(notification.timestamp))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        
                        if isHovering {
                            Text("• Click to open")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .padding(.top, 2)
                }
            }

            // Chevron indicator on hover
            if isHovering {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.leading, 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.trailing, 12)
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func appIconView(size: CGFloat) -> some View {
        if let notification = manager.currentNotification,
           let appIcon = notification.appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        } else {
            // Fallback: App initials or generic icon
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.gray.opacity(0.7), .gray.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)

                if let name = manager.currentNotification?.appName, !name.isEmpty {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.6, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: size * 0.5, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }

    private var queueIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<min(manager.queueCount, 4), id: \.self) { index in
                Circle()
                    .fill(index == 0 ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 5, height: 5)
            }
            if manager.queueCount > 4 {
                Text("+\(manager.queueCount - 4)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Actions

    private func openSourceApp() {
        guard let notification = manager.currentNotification else {
            print("NotificationHUD: No current notification to open")
            return
        }
        
        print("NotificationHUD: Opening app for bundle ID: \(notification.appBundleID)")

        // Visual feedback
        withAnimation(.easeOut(duration: 0.1)) {
            isPressed = true
        }

        // Open the app - Robust Method
        // Method 1: Try NSWorkspace with configuration (standard modern way)
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: notification.appBundleID) {
            print("NotificationHUD: Found app URL at \(appURL.path), launching...")
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
                if let error = error {
                    print("NotificationHUD: Failed to open via URL: \(error.localizedDescription)")
                    // Fallback 1: Activate running instance
                    self.activateRunningApp(bundleID: notification.appBundleID)
                } else {
                    print("NotificationHUD: App opened successfully via NSWorkspace")
                }
            }
        } else {
            print("NotificationHUD: No app URL found for \(notification.appBundleID), trying active instances...")
            // Fallback 1: Activate running instance
            if !activateRunningApp(bundleID: notification.appBundleID) {
                // Fallback 2: Shell command (Ultimate Hammer)
                print("NotificationHUD: Running app failed, trying shell open...")
                openViaShell(bundleID: notification.appBundleID)
            }
        }

        // Dismiss after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.1)) {
                self.isPressed = false
            }
            self.manager.dismissCurrentOnly()
        }
    }

    @discardableResult
    private func activateRunningApp(bundleID: String) -> Bool {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            print("NotificationHUD: Found running instance, activating...")
            // Try everything to wake it up
            let success = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) 
            if !success {
                 app.activate(options: [])
            }
            return true
        }
        return false
    }

    private func openViaShell(bundleID: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-b", bundleID]
            try? process.run()
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 5 {
            return "now"
        } else if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m"
        } else if seconds < 86400 {
            return "\(seconds / 3600)h"
        } else {
            return "\(seconds / 86400)d"
        }
    }
}

// MARK: - Preview

#Preview("Notification HUD") {
    ZStack {
        Color.black.opacity(0.9)

        VStack(spacing: 40) {
            // Simulated notch area
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black)
                    .frame(width: 400, height: 80)

                NotificationHUDView(
                    manager: NotificationHUDManager.shared,
                    hudWidth: 400
                )
            }

            Text("Hover to see click affordance, swipe up to dismiss")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .frame(width: 500, height: 200)
}
