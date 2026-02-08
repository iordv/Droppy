import SwiftUI

struct LicenseSettingsSection: View {
    @ObservedObject private var licenseManager = LicenseManager.shared

    @State private var emailInput: String = ""
    @State private var licenseKeyInput: String = ""
    @State private var showConfetti = false
    @State private var isLicenseKeyVisible = true

    @FocusState private var focusedField: FocusedField?

    private enum FocusedField {
        case email
        case key
    }

    var body: some View {
        Group {
            if licenseManager.requiresLicenseEnforcement {
                if licenseManager.isActivated {
                    Section {
                        activeLicenseCard
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .overlay {
                                if showConfetti {
                                    OnboardingConfettiView()
                                        .allowsHitTesting(false)
                                        .transition(.opacity)
                                }
                            }

                        licenseActionRow
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                    } header: {
                        Text("License")
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            headerRow
                            activationCard
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.clear)
                        .overlay {
                            if showConfetti {
                                OnboardingConfettiView()
                                    .allowsHitTesting(false)
                                    .transition(.opacity)
                            }
                        }
                    } header: {
                        Text("License")
                    } footer: {
                        Text("Droppy verifies this key with Gumroad so your license follows Gumroad seat limits.")
                    }
                }
            }
        }
        .onAppear {
            if emailInput.isEmpty {
                emailInput = licenseManager.licensedEmail
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((licenseManager.isActivated ? Color.green : Color.orange).opacity(0.2))
                    .frame(width: 26, height: 26)

                Image(systemName: licenseManager.isActivated ? "checkmark.seal.fill" : "key.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(licenseManager.isActivated ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(licenseManager.isActivated ? "Licensed" : "Activation Required")
                    .font(.system(size: 13, weight: .semibold))
                Text(licenseManager.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if licenseManager.isChecking {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var activeLicenseCard: some View {
        LicenseIdentityCard(
            title: "Droppy License",
            subtitle: "Activated on this Mac",
            email: licenseManager.licensedEmail,
            deviceName: licenseManager.activatedDeviceName,
            keyHint: normalized(licenseManager.licenseKeyHint),
            verifiedAt: licenseManager.lastVerifiedAt,
            accentColor: .blue,
            footer: nil,
            enableInteractiveEffects: false
        )
    }

    private var licenseActionRow: some View {
        HStack(spacing: 8) {
            Text("Manage")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button {
                Task {
                    await licenseManager.revalidateStoredLicense()
                }
            } label: {
                HStack(spacing: 5) {
                    if licenseManager.isChecking {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    Text("Re-check")
                }
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            .disabled(licenseManager.isChecking)

            Button {
                Task {
                    await licenseManager.deactivateCurrentDevice()
                    licenseKeyInput = ""
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Remove")
                }
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            .disabled(licenseManager.isChecking)
        }
    }

    private var activationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activate this Mac")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            inputField(icon: "envelope.fill", isFocused: focusedField == .email) {
                TextField("Purchase email (optional)", text: $emailInput)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .email)
            }

            inputField(icon: "key.fill", isFocused: focusedField == .key) {
                HStack(spacing: 8) {
                    if isLicenseKeyVisible {
                        TextField("Gumroad license key", text: $licenseKeyInput)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .key)
                    } else {
                        SecureField("Gumroad license key", text: $licenseKeyInput)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .key)
                    }

                    Button {
                        isLicenseKeyVisible.toggle()
                    } label: {
                        Image(systemName: isLicenseKeyVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isLicenseKeyVisible ? "Hide license key" : "Show license key")
                }
            }

            HStack(spacing: 8) {
                if let purchaseURL = licenseManager.purchaseURL {
                    Link(destination: purchaseURL) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right")
                            Text("Buy License")
                        }
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))
                }

                Spacer()

                Button {
                    activateLicense()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                        Text("Activate")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                .disabled(licenseManager.isChecking)
            }
        }
        .padding(14)
        .background(AdaptiveColors.overlayAuto(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }

    private func activateLicense() {
        let key = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            let success = await licenseManager.activate(licenseKey: key, email: emailInput)
            guard success else { return }

            withAnimation(DroppyAnimation.state) {
                showConfetti = true
                licenseKeyInput = ""
                emailInput = licenseManager.licensedEmail
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(DroppyAnimation.hoverQuick) {
                    showConfetti = false
                }
            }
        }
    }

    private func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not available" : trimmed
    }

    private func inputField<Content: View>(icon: String, isFocused: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue.opacity(0.92))
                .frame(width: 16)

            content()
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .disableAutocorrection(true)
        }
        .droppyTextInputChrome(cornerRadius: DroppyRadius.ml, horizontalPadding: 12, verticalPadding: 10)
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.2)
        )
    }
}
