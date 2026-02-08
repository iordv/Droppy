//
//  CameraInfoView.swift
//  Droppy
//
//  Setup/configuration sheet for Notchface extension.
//

import SwiftUI
import AppKit
@preconcurrency import AVFoundation

struct CameraInfoView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.cameraInstalled) private var isInstalled = PreferenceDefault.cameraInstalled
    @AppStorage(AppPreferenceKey.cameraEnabled) private var isEnabled = PreferenceDefault.cameraEnabled

    @ObservedObject private var manager = CameraManager.shared
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
                    settingsSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)

            Divider()
                .padding(.horizontal, 24)

            footerSection
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .camera)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            CachedAsyncImage(url: CameraExtension.iconURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 64, height: 64)
                    .background(Color.cyan.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
                    .shadow(color: .cyan.opacity(0.35), radius: 8, y: 4)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.16), lineWidth: 1)
            )

            Text("Notchface")
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
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.15)))
            }

            Text("Floating camera button with a full notch preview")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "camera.fill", text: "Floating Notchface toggle below expanded shelf")
            featureRow(icon: "rectangle.inset.filled", text: "Full preview mode with balanced notch padding")
            featureRow(icon: "sparkles", text: "Smooth, low-latency preview updates")

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Status")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(permissionStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if manager.permissionStatus == .notDetermined {
                    Button("Allow Camera") {
                        manager.requestAccess()
                    }
                    .buttonStyle(DroppyAccentButtonStyle(color: .cyan, size: .small))
                } else if manager.permissionStatus == .denied || manager.permissionStatus == .restricted {
                    Button("Open Settings") {
                        openCameraPrivacySettings()
                    }
                    .buttonStyle(DroppyAccentButtonStyle(color: .cyan, size: .small))
                }
            }
            .padding(DroppySpacing.md)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                Toggle(isOn: $isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Notchface")
                            .font(.callout.weight(.medium))
                        Text("Show a floating button and full camera preview mode in expanded shelf")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(DroppySpacing.md)
                .disabled(!isInstalled)
            }
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
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
                DisableExtensionButton(extensionType: .camera)
            } else {
                Button("Install") {
                    installExtension()
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .cyan, size: .small))
            }
        }
        .padding(DroppySpacing.lg)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.cyan)
                .frame(width: 24)
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }

    private var permissionStatusText: String {
        switch manager.permissionStatus {
        case .authorized:
            return "Camera permission granted"
        case .notDetermined:
            return "Camera permission will be requested when needed"
        case .denied, .restricted:
            return "Camera permission blocked. Enable camera access in System Settings."
        @unknown default:
            return "Camera permission status unknown"
        }
    }

    private func installExtension() {
        isInstalled = true
        isEnabled = true
        ExtensionType.camera.setRemoved(false)

        Task {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "camera")
        }

        NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.camera)
    }

    private func openCameraPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}
