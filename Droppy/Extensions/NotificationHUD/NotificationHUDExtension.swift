//
//  NotificationHUDExtension.swift
//  Droppy
//
//  Self-contained definition for Notification HUD extension
//  Shows macOS notifications in the notch (like iPhone Dynamic Island)
//

import SwiftUI

struct NotificationHUDExtension: ExtensionDefinition {
    static let id = "notificationHUD"
    static let title = "Notification HUD"
    static let subtitle = "Show notifications in your notch"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .orange

    static let description = "Display macOS notifications directly in your notch, similar to iPhone's Dynamic Island. See alerts, messages, and app notifications without cluttering your screen corners."

    static let features: [(icon: String, text: String)] = [
        ("bell.badge", "Notification display in notch"),
        ("app.badge", "App icon and notification preview"),
        ("slider.horizontal.3", "Per-app notification filtering"),
        ("eye.slash", "Option to replace system notifications")
    ]

    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/notification-hud-screenshot.png")
    }

    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/notification-hud.png")
    }

    static let iconPlaceholder = "bell.badge.fill"
    static let iconPlaceholderColor: Color = .orange

    static func cleanup() {
        NotificationHUDManager.shared.cleanup()
    }
}
