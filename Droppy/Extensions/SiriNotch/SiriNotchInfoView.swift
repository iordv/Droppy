//
//  SiriNotchInfoView.swift
//  Droppy
//
//  Siri Notch extension setup and configuration view
//

import SwiftUI

struct SiriNotchInfoView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @ObservedObject private var manager = SiriNotchManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringCancel = false
    @State private var showReviewsSheet = false

    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()
                .padding(.horizontal, 24)

            // Scrollable content area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Features
                    featuresSection

                    // Settings (when installed)
                    if manager.isInstalled {
                        settingsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 400)

            Divider()
                .padding(.horizontal, 24)

            // Buttons
            buttonSection
        }
        .frame(width: 400)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .siriNotch)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Animated gradient icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .purple.opacity(0.4), radius: 8, y: 4)

            Text("Siri Notch")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            // Stats row
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)

                Button {
                    showReviewsSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption.weight(.medium))
                            Text("(\(r.ratingCount))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("-")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.purple.opacity(0.15)))
            }

            Text("Display Siri interface in your notch with beautiful animations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "waveform", text: "Animated Siri waveform in notch")
            featureRow(icon: "mic.fill", text: "Automatic Siri activation detection")
            featureRow(icon: "eye.slash", text: "Option to hide system Siri window")
            featureRow(icon: "sparkles", text: "Beautiful gradient animations")
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.purple)
                .frame(width: 24)

            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text("Settings")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }

                Toggle(isOn: $manager.hideSystemWindow) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide System Siri Window")
                            .font(.system(size: 14, weight: .medium))
                        Text("Move the native Siri window off-screen")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(16)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isHoveringCancel ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(DroppyAnimation.hoverQuick) { isHoveringCancel = h }
            }

            Spacer()

            if manager.isInstalled {
                DisableExtensionButton(extensionType: .siriNotch)
            } else {
                Button {
                    installExtension()
                } label: {
                    Text("Install")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .opacity(isHoveringAction ? 1.0 : 0.85)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(DroppyAnimation.hoverQuick) { isHoveringAction = h }
                }
            }
        }
        .padding(16)
    }

    // MARK: - Actions

    private func installExtension() {
        manager.isInstalled = true
        manager.startMonitoring()
        ExtensionType.siriNotch.setRemoved(false)

        // Track installation
        Task {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "siriNotch")
        }

        // Post notification
        NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.siriNotch)
    }
}

#Preview {
    SiriNotchInfoView()
        .frame(height: 500)
}
