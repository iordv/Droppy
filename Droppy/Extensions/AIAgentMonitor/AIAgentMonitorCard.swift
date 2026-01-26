//
//  AIAgentMonitorCard.swift
//  Droppy
//
//  AI Agent Monitor extension card for Settings extensions grid
//

import SwiftUI

struct AIAgentMonitorCard: View {
    @ObservedObject private var manager = AIAgentMonitorManager.shared
    @State private var showInfoSheet = false

    private var isInstalled: Bool { UserDefaults.standard.bool(forKey: "aiAgentMonitorTracked") }
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, stats, and badge
            HStack(alignment: .top) {
                // Icon
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Spacer()

                // Stats row: installs + rating + badge
                HStack(spacing: 8) {
                    // Installs
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                        Text("\(installCount ?? 0)")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)

                    // Rating
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption2.weight(.medium))
                        } else {
                            Text("–")
                                .font(.caption2.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)

                    // Category badge
                    Text(isInstalled ? "Installed" : "AI")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isInstalled ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isInstalled ? Color.green.opacity(0.15) : AdaptiveColors.subtleBorderAuto)
                        )
                }
            }

            // Title & Description
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Agent Monitor")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Track Claude Code, Codex & OpenCode usage in real-time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            // Status row
            HStack {
                Circle()
                    .fill(manager.isActive ? manager.currentSource.borderColor : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)

                if manager.isActive {
                    Text(manager.currentSource.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary)
                } else if manager.isEnabled {
                    Text("Listening on port \(manager.otlpPort)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Disabled")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Token count if active
                if manager.isActive && manager.tokenCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "number")
                            .font(.system(size: 9))
                        Text("\(manager.tokenCount)")
                            .font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minHeight: 160)
        .extensionCardStyle(accentColor: .orange)
        .contentShape(Rectangle())
        .onTapGesture {
            showInfoSheet = true
        }
        .sheet(isPresented: $showInfoSheet) {
            ExtensionInfoView(extensionType: .aiAgentMonitor, installCount: installCount, rating: rating)
        }
    }
}

#Preview("AI Agent Monitor Card") {
    AIAgentMonitorCard()
        .frame(width: 200)
        .padding()
}
