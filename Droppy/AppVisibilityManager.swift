//
//  AppVisibilityManager.swift
//  Droppy
//
//  Centralized app visibility behavior for Dock/MenuBar policies.
//

import AppKit

@MainActor
enum AppVisibilityManager {
    static func applyDockVisibilityFromPreferences() {
        let showInDock = UserDefaults.standard.preference(
            AppPreferenceKey.showInDock,
            default: PreferenceDefault.showInDock
        )

        let policy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        _ = NSApp.setActivationPolicy(policy)
    }
}
