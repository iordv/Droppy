//
//  AIAgentMonitorInfoView.swift
//  Droppy
//
//  Info and settings view for AI Agent Monitor extension
//

import SwiftUI

struct AIAgentMonitorInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = AIAgentMonitorManager.shared
    @State private var portText: String = ""

    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                Divider()

                // Status section
                statusSection

                Divider()

                // Settings section
                settingsSection

                Divider()

                // Features section
                featuresSection

                Divider()

                // How to use section
                howToUseSection

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .frame(width: 480, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            portText = String(manager.otlpPort)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Icon - use Claude logo
            Image("claude-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .frame(width: 80, height: 80)
                .background(Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("AI Agent Monitor")
                    .font(.title2.bold())

                Text("Track Claude Code, Codex & OpenCode usage")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Stats
                HStack(spacing: 12) {
                    if let count = installCount {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 11))
                            Text("\(count)")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let r = rating, r.ratingCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            Spacer()

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

            HStack(spacing: 16) {
                // Server status
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(manager.isEnabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(manager.isEnabled ? "Server Running" : "Server Stopped")
                            .font(.subheadline.weight(.medium))
                    }
                    Text("Port \(manager.otlpPort)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Agent status
                if manager.isActive {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: manager.currentSource.icon)
                                .foregroundStyle(manager.currentSource.borderColor)
                            Text(manager.currentSource.displayName)
                                .font(.subheadline.weight(.medium))
                        }
                        if let toolCall = manager.currentToolCall {
                            Text(toolCall)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No agent active")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Token stats
            if manager.sessionTokens > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Session Tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(manager.sessionTokens)")
                            .font(.title3.monospacedDigit().weight(.medium))
                    }

                    Spacer()

                    Button("Reset") {
                        manager.resetSession()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            VStack(spacing: 12) {
                // Enable toggle
                Toggle("Enable AI Agent Monitor", isOn: $manager.isEnabled)
                    .toggleStyle(.switch)

                Divider()

                // Border settings
                Toggle("Show animated border", isOn: $manager.borderEnabled)
                    .toggleStyle(.switch)
                    .disabled(!manager.isEnabled)

                Toggle("Pulsing animation", isOn: $manager.borderPulsing)
                    .toggleStyle(.switch)
                    .disabled(!manager.isEnabled || !manager.borderEnabled)

                Toggle("Enhanced glow effect", isOn: $manager.glowEnhanced)
                    .toggleStyle(.switch)
                    .disabled(!manager.isEnabled || !manager.borderEnabled)

                // Test button
                HStack {
                    Text("Preview border effect")
                    Spacer()
                    Button {
                        manager.testBorder()
                    } label: {
                        Label(manager.isTestMode ? "Testing..." : "Test", systemImage: "eye")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!manager.isEnabled || !manager.borderEnabled || manager.isTestMode)
                }

                Divider()

                // Port setting
                HStack {
                    Text("OTLP Port")
                    Spacer()
                    TextField("Port", text: $portText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            if let port = UInt16(portText), port > 0 {
                                manager.otlpPort = port
                                // Restart server with new port
                                manager.stopServer()
                                manager.startServer()
                            }
                        }
                }
                .disabled(!manager.isEnabled)

                Text("Restart required after changing port")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Features")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FeatureCard(icon: "sparkle", title: "Claude Code", description: "Orange indicator", color: .orange)
                FeatureCard(icon: "chevron.left.forwardslash.chevron.right", title: "Codex", description: "Blue indicator", color: .blue)
                FeatureCard(icon: "terminal", title: "OpenCode", description: "Green indicator", color: .green)
                FeatureCard(icon: "number", title: "Token Tracking", description: "Real-time count", color: .purple)
            }
        }
    }

    // MARK: - How to Use Section

    private var howToUseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Use")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                InstructionRow(number: 1, text: "Enable the extension using the toggle above")
                InstructionRow(number: 2, text: "Configure your AI coding agent to send OTLP telemetry to localhost:\(manager.otlpPort)")
                InstructionRow(number: 3, text: "The notch will show a colored border when an agent is active")
                InstructionRow(number: 4, text: "View token usage and current tool calls in real-time")
            }
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Configuration example
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude Code Configuration")
                    .font(.subheadline.weight(.medium))

                Text("OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:\(manager.otlpPort)")
                    .font(.system(size: 11, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.8))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    let config = "OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:\(manager.otlpPort)"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(config, forType: .string)
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Instruction Row

private struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.orange))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("AI Agent Monitor Info") {
    AIAgentMonitorInfoView()
}
