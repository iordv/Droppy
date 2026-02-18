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
    @AppStorage(AppPreferenceKey.cameraPreferredDeviceID) private var preferredDeviceID = PreferenceDefault.cameraPreferredDeviceID

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
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .camera)
        }
        .onAppear {
            manager.refreshAvailableDevices()
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

            VStack(alignment: .leading, spacing: 0) {
                Toggle(isOn: $isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Notchface")
                            .font(.callout.weight(.medium))
                        Text("Show a floating button and full camera preview mode in expanded shelf")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, DroppySpacing.lg)
                .padding(.top, DroppySpacing.lg)
                .disabled(!isInstalled)

                Divider()
                    .padding(.top, DroppySpacing.md)
                    .padding(.horizontal, DroppySpacing.lg)

                cameraSourceSection
                    .padding(.horizontal, DroppySpacing.lg)
                    .padding(.top, DroppySpacing.md)
                    .padding(.bottom, DroppySpacing.lg)
            }
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .disabled(!isInstalled)
            .opacity(isInstalled ? 1 : 0.6)
        }
    }

    private var cameraSourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Camera Source")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    manager.refreshAvailableDevices()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 28))
                .help("Refresh connected cameras")
            }

            Text("Choose which connected camera Notchface should use.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                SettingsSegmentButton(
                    icon: "camera.metering.center.weighted",
                    label: "Auto",
                    isSelected: normalizedPreferredDeviceID == nil,
                    tileWidth: 96
                ) {
                    selectCamera(nil)
                }

                ForEach(manager.availableCameraDevices) { device in
                    SettingsSegmentButton(
                        icon: device.icon,
                        label: cameraTileLabel(for: device.displayName),
                        isSelected: normalizedPreferredDeviceID == device.id,
                        tileWidth: 96
                    ) {
                        selectCamera(device.id)
                    }
                }
            }

            if manager.availableCameraDevices.isEmpty {
                Text("No connected cameras detected. Grant camera permission and connect a camera.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isPreferredDeviceMissing {
                Text("Previously selected camera is not connected. Auto mode is being used.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Selected: \(selectedCameraDisplayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    private var normalizedPreferredDeviceID: String? {
        let trimmed = preferredDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var isPreferredDeviceMissing: Bool {
        guard let selectedID = normalizedPreferredDeviceID else { return false }
        if manager.availableCameraDevices.contains(where: { $0.id == selectedID }) {
            return false
        }
        return true
    }

    private func selectCamera(_ deviceID: String?) {
        let normalized = deviceID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        preferredDeviceID = normalized
        manager.setPreferredDeviceID(normalized.isEmpty ? nil : normalized)
    }

    private func cameraTileLabel(for displayName: String) -> String {
        if displayName.localizedCaseInsensitiveContains("iphone") {
            return "iPhone"
        }
        if displayName.localizedCaseInsensitiveContains("facetime") {
            return "FaceTime"
        }

        let cleaned = displayName
            .replacingOccurrences(of: "Camera", with: "")
            .replacingOccurrences(of: "camera", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count > 12 {
            return String(cleaned.prefix(11)) + "…"
        }
        return cleaned.isEmpty ? "Camera" : cleaned
    }

    private var selectedCameraDisplayName: String {
        guard let selectedID = normalizedPreferredDeviceID else {
            return "Auto (best available)"
        }
        return manager.availableCameraDevices.first(where: { $0.id == selectedID })?.displayName ?? "Auto (best available)"
    }
}
