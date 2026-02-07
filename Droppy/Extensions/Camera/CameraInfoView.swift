//
//  CameraInfoView.swift
//  Droppy
//
//  Camera extension info and setup view
//

import SwiftUI
import AVFoundation
import AppKit

struct CameraInfoView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.cameraKeepShelfOpen) private var cameraKeepShelfOpen = PreferenceDefault.cameraKeepShelfOpen
    @ObservedObject private var manager = CameraManager.shared
    @Environment(\.dismiss) private var dismiss

    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()
                .padding(.horizontal, 24)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    featuresSection
                    statusSection
                    behaviorSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 520)

            Divider()
                .padding(.horizontal, 24)

            buttonSection
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("CameraIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                        .fill(Color.cyan.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )

            Text("Camera")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)

                Button {
                    // No reviews sheet yet
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
                .disabled(true)

                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.15)))
            }

            Text("Quick mirror in your notch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "camera.fill", text: "Instant live camera preview")
            featureRow(icon: "person.crop.circle", text: "Front camera by default")
            featureRow(icon: "sparkles", text: "Perfect quick mirror before a call")
        }
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

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)

            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)

            if manager.permissionStatus == .notDetermined {
                Button {
                    manager.requestAccess()
                } label: {
                    Text("Request Camera Access")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .cyan, size: .small))
                .padding(.top, 4)
            } else if manager.permissionStatus == .denied || manager.permissionStatus == .restricted {
                Button {
                    openCameraPrivacySettings()
                } label: {
                    Text("Open System Settings")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .cyan, size: .small))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Shelf Behavior

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shelf Behavior")
                .font(.headline)

            Toggle(isOn: $cameraKeepShelfOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keep shelf open while camera is active")
                    Text("When off, the shelf auto-closes and the camera shuts down when you move away.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var statusMessage: String {
        switch manager.permissionStatus {
        case .authorized:
            return manager.isVisible ? "Camera preview is open in the notch." : "Camera preview is ready."
        case .notDetermined:
            return "Camera access will be requested on first use."
        case .denied, .restricted:
            return "Camera access is blocked. Enable it in System Settings."
        @unknown default:
            return "Camera access status is unknown."
        }
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))

            Spacer()

            if manager.isInstalled {
                DisableExtensionButton(extensionType: .camera)
            } else {
                Button {
                    installExtension()
                } label: {
                    Text("Install")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .cyan, size: .small))
            }
        }
        .padding(DroppySpacing.lg)
    }

    // MARK: - Actions

    private func installExtension() {
        manager.isInstalled = true
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
