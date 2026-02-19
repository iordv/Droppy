//
//  TelepromptyInfoView.swift
//  Droppy
//
//  Setup/configuration sheet for Teleprompty extension.
//

import SwiftUI

struct TelepromptyInfoView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.telepromptyInstalled) private var isInstalled = PreferenceDefault.telepromptyInstalled
    @AppStorage(AppPreferenceKey.telepromptyEnabled) private var isEnabled = PreferenceDefault.telepromptyEnabled
    @AppStorage(AppPreferenceKey.telepromptyScript) private var script = PreferenceDefault.telepromptyScript
    @AppStorage(AppPreferenceKey.telepromptySpeed) private var speed = PreferenceDefault.telepromptySpeed
    @AppStorage(AppPreferenceKey.telepromptyFontSize) private var fontSize = PreferenceDefault.telepromptyFontSize
    @AppStorage(AppPreferenceKey.telepromptyPromptWidth) private var promptWidth = PreferenceDefault.telepromptyPromptWidth
    @AppStorage(AppPreferenceKey.telepromptyPromptHeight) private var promptHeight = PreferenceDefault.telepromptyPromptHeight
    @AppStorage(AppPreferenceKey.telepromptyCountdown) private var countdown = PreferenceDefault.telepromptyCountdown

    @ObservedObject private var manager = TelepromptyManager.shared
    @State private var showReviewsSheet = false

    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()
                .padding(.horizontal, 24)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    featuresSection
                    controlsSection
                    promptSettingsSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 540)

            Divider()
                .padding(.horizontal, 24)

            footerSection
        }
        .frame(width: 560)
        .fixedSize(horizontal: true, vertical: true)
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .teleprompty)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.mint)
                .frame(width: 64, height: 64)
                .background(Color.mint.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.16), lineWidth: 1)
                )

            Text("Teleprompty")
                .font(.title2.bold())

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
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
                            Text("–")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(DroppySelectableButtonStyle(isSelected: false))

                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.mint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.mint.opacity(0.15)))
            }

            Text("Floating teleprompter controls and live notch prompt")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "text.bubble", text: "Adds a floating Teleprompty button in the expanded shelf")
            featureRow(icon: "play.fill", text: "Start countdown + scrolling with one tap")
            featureRow(icon: "slider.horizontal.3", text: "Tune speed, font size, width, height, and countdown")
            featureRow(icon: "pencil.and.scribble", text: "Edit and save your script directly in settings or shelf")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Script")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Teleprompty")
                            .font(.callout.weight(.medium))
                        Text("Show a floating button and teleprompter view in the expanded shelf")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!isInstalled)

                HStack(spacing: 8) {
                    Button("Start") {
                        manager.start(script: script, speed: speed, countdown: countdown)
                    }
                    .buttonStyle(DroppyAccentButtonStyle(color: .mint, size: .small))
                    .disabled(script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Reset") {
                        manager.reset()
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))

                    Button("Jump Back 5s") {
                        manager.jumpBack(seconds: 5)
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))

                    Spacer(minLength: 0)

                    statusBadge
                }

                Text(TelepromptyManager.estimatedReadTimeLabel(for: script, speed: speed))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                TextEditor(text: $script)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .frame(minHeight: 210)
                    .padding(8)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                            .stroke(AdaptiveColors.overlayAuto(0.1), lineWidth: 1)
                    )
                    .disabled(!isInstalled)
                    .opacity(isInstalled ? 1 : 0.6)
            }
            .padding(DroppySpacing.lg)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.48))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .disabled(!isInstalled)
            .opacity(isInstalled ? 1 : 0.72)
        }
    }

    private var promptSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompter")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                sliderRow(title: "Speed", value: $speed, range: 40...240, step: 1, valueSuffix: "")

                HStack(spacing: 8) {
                    presetButton(title: "Slow", targetSpeed: 80)
                    presetButton(title: "Normal", targetSpeed: 110)
                    presetButton(title: "Fast", targetSpeed: 155)
                    Spacer(minLength: 0)
                }

                sliderRow(title: "Font", value: $fontSize, range: 12...42, step: 1, valueSuffix: "")
                sliderRow(title: "Width", value: $promptWidth, range: 320...760, step: 2, valueSuffix: "")
                sliderRow(title: "Height", value: $promptHeight, range: 100...260, step: 2, valueSuffix: "")
                sliderRow(title: "Countdown", value: $countdown, range: 0...8, step: 1, valueSuffix: "s")
            }
            .padding(DroppySpacing.lg)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .disabled(!isInstalled)
            .opacity(isInstalled ? 1 : 0.72)
        }
    }

    private var statusBadge: some View {
        let title: String
        let color: Color

        if manager.isCountingDown {
            title = "Starting: \(manager.countdownRemaining)"
            color = .orange
        } else if manager.isRunning {
            title = "Running"
            color = .mint
        } else {
            title = "Idle"
            color = .secondary
        }

        return Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }

    private func presetButton(title: String, targetSpeed: Double) -> some View {
        Button(title) {
            speed = targetSpeed
        }
        .buttonStyle(DroppyPillButtonStyle(size: .small))
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueSuffix: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.callout.weight(.medium))
                .frame(width: 78, alignment: .leading)

            Slider(value: value, in: range, step: step)
                .tint(.mint)

            Text("\(Int(value.wrappedValue.rounded()))\(valueSuffix)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
    }

    private var footerSection: some View {
        HStack(spacing: 10) {
            Button("Close") {
                dismiss()
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))

            Spacer()

            if isInstalled {
                DisableExtensionButton(extensionType: .teleprompty)
            } else {
                Button("Install") {
                    installExtension()
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .mint, size: .small))
            }
        }
        .padding(DroppySpacing.lg)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.mint)
                .frame(width: 24)
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }

    private func installExtension() {
        isInstalled = true
        isEnabled = true
        ExtensionType.teleprompty.setRemoved(false)

        Task {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "teleprompty")
        }

        NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.teleprompty)
    }
}
