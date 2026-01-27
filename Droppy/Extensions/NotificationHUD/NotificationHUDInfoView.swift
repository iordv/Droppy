//
//  NotificationHUDInfoView.swift
//  Droppy
//
//  Notification HUD extension setup and configuration view
//

import SwiftUI

struct NotificationHUDInfoView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @ObservedObject private var manager = NotificationHUDManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringCancel = false
    @State private var showReviewsSheet = false

    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed, non-scrolling)
            headerSection

            Divider()
                .padding(.horizontal, 24)

            // Scrollable content area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Features
                    screenshotSection

                    // Settings (config card)
                    if manager.isInstalled {
                        settingsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 520)

            Divider()
                .padding(.horizontal, 24)

            // Buttons (fixed, non-scrolling)
            buttonSection
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .notificationHUD)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/notification-hud.png")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "bell.badge.fill").font(.system(size: 32, weight: .medium)).foregroundStyle(.orange)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .orange.opacity(0.4), radius: 8, y: 4)

            Text("Notification HUD")
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
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
            }

            Text("Show notifications in your notch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Screenshot Section

    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Feature rows
            featureRow(icon: "bell.badge", text: "Notification display in the notch")
            featureRow(icon: "app.badge", text: "App icon and notification preview")
            featureRow(icon: "slider.horizontal.3", text: "Per-app notification filtering")
            featureRow(icon: "eye.slash", text: "Option to replace system notifications")

            // Screenshot placeholder
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/images/notification-hud-screenshot.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            } placeholder: {
                // Placeholder with notification preview
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.8))
                    .frame(height: 120)
                    .overlay(
                        HStack(spacing: 12) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Messages")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("New message from John")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            Spacer()
                        }
                        .padding(16)
                        , alignment: .leading
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 24)

            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 16) {
            // Full Disk Access Permission Status
            VStack(spacing: 12) {
                HStack {
                    Text("Permission")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()
                }

                HStack(spacing: 12) {
                    Image(systemName: manager.hasFullDiskAccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(manager.hasFullDiskAccess ? .green : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Full Disk Access")
                            .font(.system(size: 14, weight: .medium))
                        Text(manager.hasFullDiskAccess ? "Granted - notifications will be captured" : "Required to capture notifications")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    if !manager.hasFullDiskAccess {
                        Button {
                            manager.openFullDiskAccessSettings()
                        } label: {
                            Text("Grant")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !manager.hasFullDiskAccess {
                    Text("Click 'Grant' then add Droppy to Full Disk Access in System Settings")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(16)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(manager.hasFullDiskAccess ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
            )
            .onAppear {
                manager.recheckAccess()
            }

            // Show Preview Toggle
            VStack(spacing: 12) {
                HStack {
                    Text("Settings")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()
                }

                Toggle(isOn: $manager.showPreview) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Notification Preview")
                            .font(.system(size: 14, weight: .medium))
                        Text("Display notification body text in the HUD")
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

            // Hide Native Notifications Guide
            VStack(spacing: 12) {
                HStack {
                    Text("Hide Native Banners")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("To show notifications only in Droppy's notch:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        instructionRow(number: 1, text: "Open System Notifications settings")
                        instructionRow(number: 2, text: "Select an app (e.g., Messages)")
                        instructionRow(number: 3, text: "Set banner style to \"None\"")
                    }

                    Text("Droppy will still capture and display the notification.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }

                Button {
                    openNotificationSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 14, weight: .medium))
                        Text("Open Notification Settings")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue.opacity(0.6)))

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
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
                DisableExtensionButton(extensionType: .notificationHUD)
            } else {
                Button {
                    installExtension()
                } label: {
                    Text("Install")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(isHoveringAction ? 1.0 : 0.85))
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
        ExtensionType.notificationHUD.setRemoved(false)

        // Track installation
        Task {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "notificationHUD")
        }

        // Post notification
        NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.notificationHUD)
    }
}

#Preview {
    NotificationHUDInfoView()
        .frame(height: 600)
}
