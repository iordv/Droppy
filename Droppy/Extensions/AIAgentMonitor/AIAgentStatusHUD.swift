//
//  AIAgentStatusHUD.swift
//  Droppy
//
//  HUD view for displaying AI Agent status in the notch
//

import SwiftUI

// MARK: - Wing-based HUD for collapsed notch (matches BatteryHUDView pattern)

/// Compact AI Agent HUD that sits inside the notch
/// Matches MediaHUDView layout: icon on left wing, status on right wing
struct AIAgentHUDView: View {
    @ObservedObject var manager: AIAgentMonitorManager
    let hudWidth: CGFloat
    var targetScreen: NSScreen? = nil

    /// Centralized layout calculator - Single Source of Truth
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first!)
    }

    /// Pulsing animation state
    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if layout.isDynamicIslandMode {
                // DYNAMIC ISLAND: Icon on left edge, name on right edge
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)

                HStack {
                    // Agent icon with pulsing animation
                    Image(systemName: manager.currentSource.icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(layout.adjustedColor(manager.currentSource.borderColor))
                        .scaleEffect(isPulsing ? 1.1 : 1.0)
                        .frame(width: 20, height: iconSize, alignment: .leading)

                    Spacer()

                    // Agent name (short)
                    Text(shortName)
                        .font(.system(size: layout.labelFontSize, weight: .semibold))
                        .foregroundStyle(layout.adjustedColor(manager.currentSource.borderColor))
                }
                .padding(.horizontal, symmetricPadding)
                .frame(height: layout.notchHeight)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                let wingWidth = layout.wingWidth(for: hudWidth)

                HStack(spacing: 0) {
                    // Left wing: Agent icon near left edge
                    HStack {
                        Image(systemName: manager.currentSource.icon)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(manager.currentSource.borderColor)
                            .scaleEffect(isPulsing ? 1.1 : 1.0)
                            .frame(width: iconSize, height: iconSize, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, symmetricPadding)
                    .frame(width: wingWidth)

                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: layout.notchWidth)

                    // Right wing: Agent name near right edge
                    HStack {
                        Spacer(minLength: 0)
                        Text(shortName)
                            .font(.system(size: layout.labelFontSize, weight: .semibold))
                            .foregroundStyle(manager.currentSource.borderColor)
                    }
                    .padding(.trailing, symmetricPadding)
                    .frame(width: wingWidth)
                }
                .frame(height: layout.notchHeight)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    /// Short name for compact display
    private var shortName: String {
        switch manager.currentSource {
        case .claudeCode: return "Claude"
        case .codex: return "Codex"
        case .openCode: return "OpenCode"
        case .unknown: return "Agent"
        }
    }
}

// MARK: - Original Status HUD (for expanded view)

struct AIAgentStatusHUD: View {
    @ObservedObject private var manager = AIAgentMonitorManager.shared

    var body: some View {
        if manager.isActive {
            HStack(spacing: 12) {
                // Agent icon with color
                Image(systemName: manager.currentSource.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(manager.currentSource.borderColor)

                VStack(alignment: .leading, spacing: 2) {
                    // Agent name
                    Text(manager.currentSource.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    // Current tool call or status
                    if let toolCall = manager.currentToolCall {
                        Text(toolCall)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Active")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Token count
                if manager.tokenCount > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTokenCount(manager.tokenCount))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)

                        Text("tokens")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(manager.currentSource.borderColor.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Compact HUD for closed notch

struct AIAgentStatusIndicator: View {
    @ObservedObject private var manager = AIAgentMonitorManager.shared
    @State private var pulsePhase: CGFloat = 0

    var body: some View {
        if manager.isActive {
            Circle()
                .fill(manager.currentSource.borderColor)
                .frame(width: 8, height: 8)
                .shadow(color: manager.currentSource.borderColor.opacity(0.6), radius: 4)
                .scaleEffect(1 + pulsePhase * 0.2)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        pulsePhase = 1
                    }
                }
        }
    }
}

// MARK: - Extended Status View

struct AIAgentExtendedStatusView: View {
    @ObservedObject private var manager = AIAgentMonitorManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: manager.currentSource.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(manager.currentSource.borderColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.currentSource.displayName)
                        .font(.headline)
                    Text(manager.isActive ? "Active" : "Idle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(manager.isActive ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
            }

            Divider()

            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Current Tokens", value: "\(manager.tokenCount)", icon: "number")
                StatCard(title: "Session Tokens", value: "\(manager.sessionTokens)", icon: "sum")
            }

            // Current tool call
            if let toolCall = manager.currentToolCall {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Tool")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(toolCall)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // Last activity
            if let lastActivity = manager.lastActivity {
                HStack {
                    Text("Last activity:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lastActivity, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Expanded Shelf View (for inside expanded notch)

/// AI Agent status bar for the expanded shelf
struct AIAgentShelfStatusView: View {
    @ObservedObject var manager: AIAgentMonitorManager
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 12) {
            // Agent icon with pulsing animation
            ZStack {
                Circle()
                    .fill(manager.currentSource.borderColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .scaleEffect(isPulsing ? 1.15 : 1.0)

                Image(systemName: manager.currentSource.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(manager.currentSource.borderColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                // Agent name
                Text(manager.currentSource.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                // Status or tool call
                if let toolCall = manager.currentToolCall {
                    Text(toolCall)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                } else {
                    Text("Working...")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            // Session tokens
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTokenCount(manager.sessionTokens))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                Text("session tokens")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(manager.currentSource.borderColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(manager.currentSource.borderColor.opacity(0.4), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

#Preview("AI Agent Status HUD") {
    VStack(spacing: 20) {
        AIAgentStatusHUD()
        AIAgentStatusIndicator()
    }
    .padding()
    .frame(width: 400)
}
