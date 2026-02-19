//
//  NotificationHUDInfoView.swift
//  Droppy
//
//  Notification HUD extension setup and configuration view
//

import SwiftUI
import AppKit

struct NotificationHUDInfoView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    private var manager = NotificationHUDManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showReviewsSheet = false

    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()
                .padding(.horizontal, 24)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    screenshotSection

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

            buttonSection
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .notificationHUD)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            manager.recheckAccess()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/notification-hud.png")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "bell.badge.fill").font(.system(size: 32, weight: .medium)).foregroundStyle(.red)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .shadow(color: .orange.opacity(0.4), radius: 8, y: 4)

            Text("Notify me!")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            // Stats row
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
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
            }

            Text("Show notifications in your notch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Community Extension Badge
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                Text("Community Extension")
                    .font(.caption.weight(.medium))
                Text("by")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Link("Valetivivek", destination: URL(string: "https://github.com/valetivivek")!)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.purple.opacity(0.12)))
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Screenshot Section

    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "bell.badge", text: "Notification display in the notch")
            featureRow(icon: "app.badge", text: "App icon and notification preview")
            featureRow(icon: "arrowshape.turn.up.backward", text: "Quick reply for supported messaging apps")
            featureRow(icon: "slider.horizontal.3", text: "Per-app notification filtering")
            featureRow(icon: "eye.slash", text: "Option to replace system notifications")

            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/images/notification-hud-screenshot.png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            } placeholder: {
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .fill(AdaptiveColors.panelBackgroundAuto)
                    .frame(height: 120)
                    .overlay(
                        HStack(spacing: 12) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Messages")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AdaptiveColors.primaryTextAuto)
                                Text("New message from John")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                            }

                            Spacer()
                        }
                        .padding(DroppySpacing.lg)
                        , alignment: .leading
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.red)
                .frame(width: 24)

            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 16) {
            // Permission Card
            VStack(spacing: 12) {
                HStack {
                    Text("Permission")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(manager.hasFullDiskAccess ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(manager.hasFullDiskAccess ? "Granted" : "Required")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(manager.hasFullDiskAccess ? .green : .orange)
                    }
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(width: 32, height: 32)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Full Disk Access")
                            .font(.system(size: 14, weight: .medium))
                        Text(manager.hasFullDiskAccess ? "Notifications will be captured" : "Required to read notifications")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    if !manager.hasFullDiskAccess {
                        Button {
                            manager.openFullDiskAccessSettings()
                        } label: {
                            Text("Grant")
                        }
                        .buttonStyle(DroppyAccentButtonStyle(color: .orange, size: .small))
                    }
                }
            }
            .padding(DroppySpacing.lg)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            .onAppear {
                manager.recheckAccess()
            }
            
            // Settings Card
            VStack(spacing: 12) {
                HStack {
                    Text("Display")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "text.below.photo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(manager.isEnabled ? .blue : .secondary)
                        .frame(width: 32, height: 32)
                        .background((manager.isEnabled ? Color.blue : Color.secondary).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Notification Preview")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(manager.isEnabled ? .primary : .secondary)
                        Text(manager.isEnabled ? "Display body text in the HUD" : "Enable under HUD Settings")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    if manager.isEnabled {
                        Toggle("", isOn: Bindable(manager).showPreview)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
            .padding(DroppySpacing.lg)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
            .overlay(

                RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            
            // System Integration Card
            VStack(spacing: 12) {
                HStack {
                    Text("System Integration")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button {
                        openNotificationSettings()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 10, weight: .semibold))
                            Text("System Settings")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.purple)
                        .frame(width: 32, height: 32)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide Native Banners")
                            .font(.system(size: 14, weight: .medium))
                        Text("Set each app's banner style to \"None\" in System Settings → Notifications")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer(minLength: 0)
                }
                
                Text("Droppy will still capture and display notifications even when system banners are disabled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DroppySpacing.lg)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            
            // Captured Apps Card
            if !manager.seenApps.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        Text("Captured Apps")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text("\(manager.seenApps.count)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AdaptiveColors.buttonBackgroundAuto)
                            .clipShape(Capsule())
                    }
                    
                    // App grid - compact icons only
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                        ForEach(Array(manager.seenApps.keys.sorted()), id: \.self) { bundleID in
                            if let app = manager.seenApps[bundleID] {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
                                        .help(app.name)
                                } else {
                                    RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 32, height: 32)
                                        .help(app.name)
                                }
                            }
                        }
                    }
                }
                .padding(DroppySpacing.lg)
                .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
                )
            }
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
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))

            Spacer()

            if manager.isInstalled {
                DisableExtensionButton(extensionType: .notificationHUD)
            } else {
                Button {
                    installExtension()
                } label: {
                    Text("Install")
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .orange, size: .small))
            }
        }
        .padding(DroppySpacing.lg)
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
