//
//  AIAgentMonitorExtension.swift
//  Droppy
//
//  Self-contained definition for AI Agent Monitor extension
//  Tracks Claude Code, Codex, and OpenCode usage via OTLP telemetry
//

import SwiftUI

struct AIAgentMonitorExtension: ExtensionDefinition {
    static let id = "aiAgentMonitor"
    static let title = "AI Agent Monitor"
    static let subtitle = "Track Claude Code, Codex & OpenCode usage"
    static let category: ExtensionGroup = .ai
    static let categoryColor = Color.orange

    static let description = """
    Monitor your AI coding agents in real-time. See active status, current tool calls, \
    and token usage for Claude Code, Codex, and OpenCode directly in your notch.

    The extension runs an OTLP server to receive telemetry from your coding agents \
    and displays a beautiful animated border when an agent is active.
    """

    static let features: [(icon: String, text: String)] = [
        ("brain", "Claude Code monitoring"),
        ("chevron.left.forwardslash.chevron.right", "Codex integration"),
        ("terminal", "OpenCode support"),
        ("chart.bar.fill", "Token usage tracking"),
        ("circle.hexagongrid.fill", "Animated status border")
    ]

    static var screenshotURL: URL? {
        nil // Will add later when hosted
    }

    static var iconURL: URL? {
        nil // Will add later when hosted
    }

    static let iconPlaceholder = "brain.head.profile"
    static let iconPlaceholderColor = Color.orange

    static func cleanup() {
        AIAgentMonitorManager.shared.cleanup()
    }
}
