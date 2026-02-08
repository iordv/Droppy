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
    var manager: NotificationHUDManager
    let hudWidth: CGFloat
    var targetScreen: NSScreen? = nil
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground

    @State private var isHovering = false
    @State private var isPressed = false
    @State private var dragOffset: CGFloat = 0
    @State private var appearScale: CGFloat = 0.8
    @State private var appearOpacity: Double = 0

    init(manager: NotificationHUDManager, hudWidth: CGFloat, targetScreen: NSScreen? = nil) {
        self.manager = manager
        self.hudWidth = hudWidth
        self.targetScreen = targetScreen
        // DEBUG: Log when view is created
        print("🔔 NotificationHUDView: VIEW CREATED - hudWidth=\(hudWidth), hasNotification=\(manager.currentNotification != nil)")
    }

    /// Centralized layout calculator
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen())
    }

    /// Whether we're in compact mode (Dynamic Island style)
    /// External displays with notch visual style should use expanded layout, not compact
    private var isCompact: Bool {
        // If external with notch style, use expanded layout (not compact DI pill)
        if isExternalWithNotchStyle {
            return false
        }
        return layout.isDynamicIslandMode
    }

    /// Whether notification is expanded to show full content
    private var isExpanded: Bool {
        manager.currentNotification != nil || manager.isExpanded || isHovering
    }

    /// Keep built-in notch HUD text white on black.
    /// Only adapt foregrounds for external transparent-notch mode.
    private var useAdaptiveForegrounds: Bool {
        useTransparentBackground && isExternalWithNotchStyle
    }

    private func primaryText(_ opacity: Double = 1.0) -> Color {
        useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto.opacity(opacity) : .white.opacity(opacity)
    }

    private func secondaryText(_ opacity: Double) -> Color {
        useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(opacity) : .white.opacity(opacity)
    }

    private func overlayTone(_ opacity: Double) -> Color {
        useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(opacity) : .white.opacity(opacity)
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
        .onHover { hovering in
            withAnimation(DroppyAnimation.hover) {
                isHovering = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        // HIGH PRIORITY GESTURE: Must capture clicks BEFORE parent view's hover/expand logic
        // Using highPriorityGesture ensures notification clicks aren't consumed by shelf
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Debug: Log that gesture is receiving events
                    if !isPressed {
                        print("🔔 NotificationHUDView: Gesture onChanged - press started")
                    }
                    // Visual press feedback
                    if !isPressed {
                        withAnimation(.easeOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                    // Drag up for dismiss (only track upward drags past threshold)
                    if value.translation.height < -8 {
                        dragOffset = value.translation.height * 0.6
                    }
                }
                .onEnded { value in
                    let dragDistance = abs(value.translation.height) + abs(value.translation.width)
                    print("🔔 NotificationHUDView: Gesture onEnded - dragDistance=\(dragDistance), translation=\(value.translation)")

                    withAnimation(.easeOut(duration: 0.15)) {
                        isPressed = false
                    }

                    // Check if this was a swipe up to dismiss
                    if value.translation.height < -30 || value.predictedEndTranslation.height < -50 {
                        // Swipe up - dismiss the notification
                        print("🔔 NotificationHUDView: Swipe up detected - dismissing")
                        withAnimation(DroppyAnimation.hoverScale) {
                            dragOffset = -100
                            appearOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            manager.dismissCurrentOnly()
                            dragOffset = 0
                            appearOpacity = 1
                        }
                    } else if dragDistance < 10 {
                        // This was a TAP (minimal movement) - open the source app
                        print("🔔 NotificationHUDView: TAP detected - opening source app")
                        withAnimation(DroppyAnimation.hover) {
                            dragOffset = 0
                        }
                        openSourceApp()
                    } else {
                        // Small drag that wasn't a dismiss - reset position
                        print("🔔 NotificationHUDView: Small drag detected - resetting position")
                        withAnimation(DroppyAnimation.hover) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .offset(y: dragOffset)
        .opacity(appearOpacity * (1.0 - Double(abs(dragOffset)) / 80.0))
        .scaleEffect(appearScale * (isPressed ? 0.97 : (isHovering ? 1.02 : 1.0)))
        .onAppear {
            print("🔔 NotificationHUDView: VIEW APPEARED - notification=\(manager.currentNotification?.appName ?? "nil")")
            withAnimation(DroppyAnimation.transition) {
                appearScale = 1.0
                appearOpacity = 1.0
            }
        }
        .onChange(of: manager.currentNotification?.id) { _, _ in
            appearScale = 0.9
            appearOpacity = 0.5
            withAnimation(DroppyAnimation.transition) {
                appearScale = 1.0
                appearOpacity = 1.0
            }
        }
    }

    // MARK: - Compact Layout (Dynamic Island)

    private var compactLayout: some View {
        HStack(spacing: 14) {
            appIconView(size: 42)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if let notification = manager.currentNotification {
                        Text(notification.appName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(secondaryText(0.72))
                    }

                    Spacer()

                    if let notification = manager.currentNotification {
                        Text(timeAgo(notification.timestamp))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(secondaryText(0.56))
                    }
                }

                if let notification = manager.currentNotification {
                    Text(notification.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(primaryText())
                        .lineLimit(1)
                }

                if manager.showPreview, let body = manager.currentNotification?.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 13))
                        .foregroundStyle(secondaryText(0.82))
                        .lineLimit(1)  // Truncate with ellipsis
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 6) {
                if manager.queueCount > 1 {
                    queueIndicator
                }

                if isHovering {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(secondaryText(0.7))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: layout.notchHeight)
        // No background - displays directly inside the Dynamic Island
    }

    // MARK: - Expanded Notch Layout (Beautiful Notification Card)

    private var expandedNotchLayout: some View {
        // Notification content - use SSOT padding to match MediaPlayerView
        HStack(alignment: .center, spacing: 12) {
            // App Icon
            appIconView(size: 38)
            
            // Content
            VStack(alignment: .leading, spacing: 3) {
                // Top row: App name + timestamp + queue
                HStack(alignment: .center, spacing: 8) {
                    if let notification = manager.currentNotification {
                        Text(notification.appName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(secondaryText(0.66))
                    }
                    
                    Spacer()
                    
                    if let notification = manager.currentNotification {
                        Text(timeAgo(notification.timestamp))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(secondaryText(0.56))
                    }
                    
                    if manager.queueCount > 1 {
                        Text("+\(manager.queueCount - 1)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(secondaryText(0.72))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(overlayTone(0.15)))
                    }
                }
                
                // Title
                if let notification = manager.currentNotification {
                    Text(notification.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(primaryText())
                        .lineLimit(1)
                }
                
                // Subtitle/Body
                if let notification = manager.currentNotification {
                    let displayText = [notification.displaySubtitle, notification.body]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                    
                    if !displayText.isEmpty && manager.showPreview {
                        Text(displayText)
                            .font(.system(size: 12))
                            .foregroundStyle(secondaryText(0.78))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Hover chevron
            if isHovering {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryText(0.6))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        // Use SSOT for consistent padding across all expanded views
        // contentEdgeInsets provides correct padding for each mode:
        // - Built-in notch: notchHeight top, 30pt left/right, 20pt bottom
        // - External notch style: 20pt top/bottom, 30pt left/right
        // - Pure Island mode: 30pt on all 4 edges
        .padding(notificationContentInsets)
    }
    
    /// Content layout notch height - 0 for external displays (no physical notch)
    private var contentLayoutNotchHeight: CGFloat {
        guard let screen = targetScreen ?? NSScreen.main else { return 0 }
        // Only built-in displays with physical notch return a positive height
        if screen.isBuiltIn {
            let hasNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
            if hasNotch {
                return screen.safeAreaInsets.top
            }
        }
        return 0
    }
    
    
    /// Whether this is an external display with notch visual style
    private var isExternalWithNotchStyle: Bool {
        guard let screen = targetScreen ?? NSScreen.main else { return false }
        if screen.isBuiltIn { return false }
        let externalUseDI = (UserDefaults.standard.object(forKey: "externalDisplayUseDynamicIsland") as? Bool) ?? true
        return !externalUseDI
    }

    /// Notification content insets — uses SSOT for consistency with all HUDs.
    private var notificationContentInsets: EdgeInsets {
        NotchLayoutConstants.contentEdgeInsets(
            notchHeight: contentLayoutNotchHeight,
            isExternalWithNotchStyle: isExternalWithNotchStyle
        )
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
                .droppyCardShadow(opacity: 0.3)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.1), lineWidth: 0.5)
                )
        } else {
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
                        .foregroundStyle(primaryText())
                } else {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: size * 0.5, weight: .semibold))
                        .foregroundStyle(primaryText())
                }
            }
            .droppyCardShadow(opacity: 0.3)
        }
    }

    private var queueIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<min(manager.queueCount, 4), id: \.self) { index in
                Circle()
                    .fill(index == 0 ? primaryText() : overlayTone(0.4))
                    .frame(width: 5, height: 5)
            }
            if manager.queueCount > 4 {
                Text("+\(manager.queueCount - 4)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(secondaryText(0.68))
            }
        }
    }

    // MARK: - Debug Logging

    /// Debug flag for notification HUD troubleshooting
    private var isDebugEnabled: Bool {
        UserDefaults.standard.bool(forKey: "DEBUG_NOTIFICATION_HUD")
    }

    private func debugLog(_ message: String) {
        if isDebugEnabled {
            print("🔔 NotificationHUDView: \(message)")
        }
    }

    // MARK: - Actions

    private func openSourceApp() {
        guard let notification = manager.currentNotification else {
            print("NotificationHUD: No current notification to open")
            debugLog("openSourceApp called but currentNotification is nil")
            return
        }

        let bundleID = notification.appBundleID
        print("NotificationHUD: Opening app for bundle ID: \(bundleID)")
        debugLog("Click received - opening \(notification.appName) (\(bundleID))")

        withAnimation(.easeOut(duration: 0.1)) {
            isPressed = true
        }

        // ROBUST APP ACTIVATION STRATEGY
        // The most reliable way to bring an app to foreground on macOS (including minimized apps,
        // apps on other Spaces, etc.) is the `open` command. We use this as our PRIMARY method.
        //
        // Strategy:
        // 1. First, try to unhide and activate via NSRunningApplication (fast, works for visible apps)
        // 2. Always follow up with `open -b` command (handles minimized, different Spaces, etc.)

        let debugEnabled = isDebugEnabled

        // Step 1: Try NSRunningApplication first for immediate activation of visible apps
        Self.activateRunningAppStatic(bundleID: bundleID, debugEnabled: debugEnabled)

        // Step 2: ALWAYS use `open -b` as the reliable method
        // This handles all edge cases: minimized windows, different Spaces, app not running, etc.
        Self.openViaShellStatic(bundleID: bundleID, debugEnabled: debugEnabled)

        // Dismiss notification after a short delay
        let notificationManager = manager
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.1)) {
                // isPressed animation handled by view lifecycle
            }
            notificationManager.dismissCurrentOnly()
        }
    }

    /// Static helper for activating running apps (avoids struct self-capture issues)
    /// This provides fast activation for apps that are already visible/accessible
    @discardableResult
    private static func activateRunningAppStatic(bundleID: String, debugEnabled: Bool) -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if debugEnabled { print("🔔 NotificationHUDView: Found \(runningApps.count) running instance(s) for \(bundleID)") }

        guard let app = runningApps.first else {
            if debugEnabled { print("🔔 NotificationHUDView: No running instance found for \(bundleID)") }
            return false
        }

        print("NotificationHUD: Found running instance, activating...")

        // If app is hidden, unhide it first
        if app.isHidden {
            if debugEnabled { print("🔔 NotificationHUDView: App is hidden, unhiding...") }
            app.unhide()
        }

        // Activate the app - brings to foreground
        let success = app.activate()
        if debugEnabled { print("🔔 NotificationHUDView: activate() result: \(success), isActive: \(app.isActive)") }

        return success
    }

    /// Static helper for shell-based app opening - THE MOST RELIABLE METHOD
    /// `open -b` handles all edge cases: minimized windows, different Spaces, app not running
    private static func openViaShellStatic(bundleID: String, debugEnabled: Bool) {
        if debugEnabled { print("🔔 NotificationHUDView: Using open -b \(bundleID) (most reliable method)") }

        // Run synchronously on background thread to ensure it completes
        DispatchQueue.global(qos: .userInteractive).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            // -b: open by bundle identifier
            // -g would keep in background, but we WANT foreground, so don't use it
            process.arguments = ["-b", bundleID]

            // Suppress any output
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()

                let exitCode = process.terminationStatus
                if debugEnabled {
                    DispatchQueue.main.async {
                        if exitCode == 0 {
                            print("🔔 NotificationHUDView: ✅ open -b succeeded for \(bundleID)")
                        } else {
                            print("🔔 NotificationHUDView: ⚠️ open -b exited with code \(exitCode) for \(bundleID)")
                        }
                    }
                }
            } catch {
                if debugEnabled {
                    DispatchQueue.main.async {
                        print("🔔 NotificationHUDView: ❌ open -b failed: \(error.localizedDescription)")
                    }
                }
            }
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
