//
//  AgentSource.swift
//  Droppy
//
//  Agent source types and their visual properties for AI Agent Monitor
//

import SwiftUI

// MARK: - Agent Source

enum AgentSource: String, CaseIterable, Identifiable {
    case unknown
    case claudeCode
    case codex
    case openCode

    var id: String { rawValue }

    // MARK: - Display

    var displayName: String {
        switch self {
        case .unknown: return "Unknown Agent"
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .openCode: return "OpenCode"
        }
    }

    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .claudeCode: return "sparkle"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .openCode: return "terminal"
        }
    }

    var usesCustomIcon: Bool {
        switch self {
        case .claudeCode: return true
        default: return false
        }
    }

    var customIconName: String? {
        switch self {
        case .claudeCode: return "claude-logo"
        default: return nil
        }
    }

    // MARK: - Colors

    var borderColor: Color {
        switch self {
        case .claudeCode: return Color(red: 1.0, green: 0.55, blue: 0.2)   // Orange
        case .codex: return Color(red: 0.2, green: 0.45, blue: 0.9)        // Blue
        case .openCode: return Color(red: 0.2, green: 0.8, blue: 0.4)      // Green
        case .unknown: return Color(red: 0.6, green: 0.8, blue: 1.0)       // Light blue
        }
    }

    var glowColor: Color {
        borderColor.opacity(0.6)
    }

    // MARK: - Detection

    /// Detect source from OTLP payload text
    static func detect(from text: String) -> AgentSource {
        let lowercased = text.lowercased()

        // OpenCode detection
        if lowercased.contains("opencode") || lowercased.contains("sst") {
            return .openCode
        }

        // Codex detection
        if lowercased.contains("codex") {
            return .codex
        }

        // Claude Code detection
        if lowercased.contains("claude") || lowercased.contains("anthropic") {
            return .claudeCode
        }

        return .unknown
    }

    /// Detect source from event name prefix
    static func detect(fromEventPrefix event: String) -> AgentSource? {
        let normalized = event.lowercased().replacingOccurrences(of: "_", with: ".")

        if normalized.hasPrefix("opencode.") {
            return .openCode
        }
        if normalized.hasPrefix("codex.") {
            return .codex
        }
        if normalized.hasPrefix("claude.code.") || normalized.hasPrefix("claude_code.") {
            return .claudeCode
        }

        return nil
    }
}
