import SwiftUI

struct LicenseActivationView: View {
    @ObservedObject private var licenseManager = LicenseManager.shared
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground

    @State private var emailInput: String = ""
    @State private var licenseKeyInput: String = ""
    @State private var showConfetti = false
    @State private var showActivatedState = false
    @State private var isLicenseKeyVisible = true

    @FocusState private var focusedField: FocusedField?
    @Namespace private var cardMorphNamespace

    let onRequestQuit: () -> Void
    let onActivationCompleted: () -> Void

    private enum FocusedField {
        case email
        case key
    }

    private let horizontalInset: CGFloat = 18
    private let sectionInset: CGFloat = 16
    private let cornerRadius: CGFloat = 24
    private let morphAnimation = Animation.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.1)

    var body: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.horizontal, horizontalInset)
                .padding(.top, 20)
                .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, horizontalInset)

            contentSection
                .padding(.horizontal, horizontalInset)
                .padding(.top, 14)
                .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, horizontalInset)

            footerSection
                .padding(.horizontal, horizontalInset)
                .padding(.vertical, sectionInset)
        }
        .frame(width: 430)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .overlay {
            if showConfetti {
                OnboardingConfettiView()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onAppear {
            if emailInput.isEmpty {
                emailInput = licenseManager.licensedEmail
            }
            showActivatedState = licenseManager.isActivated
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            Text(showActivatedState || licenseManager.isActivated ? "License Activated" : "Activate Droppy")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)

            Text(showActivatedState || licenseManager.isActivated
                 ? "Welcome to Droppy, you can remove everything else now!"
                 : "Enter your Gumroad license to unlock Droppy")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Group {
                if showActivatedState || licenseManager.isActivated {
                    LicenseIdentityCard(
                        title: "Droppy Licensed",
                        subtitle: "Activated on this Mac",
                        email: licenseManager.licensedEmail,
                        keyHint: normalizedHint(licenseManager.licenseKeyHint),
                        verifiedAt: licenseManager.lastVerifiedAt,
                        accentColor: .blue,
                        enableInteractiveEffects: false
                    )
                    .matchedGeometryEffect(id: "license-card", in: cardMorphNamespace, properties: .frame)
                    .transition(.opacity)
                } else {
                    LicenseLivePreviewCard(
                        email: previewEmail,
                        keyDisplay: previewKeyDisplay,
                        isActivated: false,
                        accentColor: .blue,
                        enableInteractiveEffects: false
                    )
                    .matchedGeometryEffect(id: "license-card", in: cardMorphNamespace, properties: .frame)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var contentSection: some View {
        if !(showActivatedState || licenseManager.isActivated) {
            VStack(alignment: .leading, spacing: 10) {
                textInputRow(
                    icon: "envelope.fill",
                    focused: focusedField == .email
                ) {
                    TextField("Purchase email (optional)", text: $emailInput)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .email)
                }

                textInputRow(
                    icon: "key.fill",
                    focused: focusedField == .key
                ) {
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

                if shouldShowStatusRow {
                    statusRow
                }
            }
            .transition(.opacity.animation(.easeOut(duration: 0.14)))
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: licenseManager.isChecking ? "hourglass" : "shield.lefthalf.filled")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(licenseManager.isChecking ? .orange : .secondary)

            Text(licenseManager.statusMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            if licenseManager.isChecking {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func textInputRow<Content: View>(
        icon: String,
        focused: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue.opacity(0.9))
                .frame(width: 16)

            content()
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .disableAutocorrection(true)
        }
        .droppyTextInputChrome(cornerRadius: DroppyRadius.ml, horizontalPadding: 12, verticalPadding: 10)
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(focused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.2)
        )
    }

    private var footerSection: some View {
        HStack(spacing: 10) {
            Button {
                onRequestQuit()
            } label: {
                Text("Quit")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))

            Spacer()

            if let purchaseURL = licenseManager.purchaseURL,
               !(showActivatedState || licenseManager.isActivated) {
                Link(destination: purchaseURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                        Text("Buy License")
                    }
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
            }

            if showActivatedState || licenseManager.isActivated {
                Button {
                    onActivationCompleted()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Start!")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .green, size: .small))
            } else {
                Button {
                    activateLicense()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                        Text("Activate License")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                .disabled(licenseManager.isChecking)
            }
        }
    }

    private func activateLicense() {
        let key = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            let success = await licenseManager.activate(licenseKey: key, email: emailInput)
            guard success else { return }

            HapticFeedback.expand()
            withAnimation(morphAnimation) {
                showActivatedState = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(DroppyAnimation.hoverQuick) {
                    showConfetti = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(DroppyAnimation.hoverQuick) {
                    showConfetti = false
                }
            }
        }
    }

    private var previewEmail: String {
        if showActivatedState || licenseManager.isActivated {
            return licenseManager.licensedEmail
        }
        return emailInput
    }

    private var previewKeyDisplay: String {
        if showActivatedState || licenseManager.isActivated {
            let hint = licenseManager.licenseKeyHint.trimmingCharacters(in: .whitespacesAndNewlines)
            return hint.isEmpty ? "****-****-****-****" : hint
        }

        let trimmed = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return formattedPreviewKey(from: trimmed)
    }

    private func formattedPreviewKey(from rawValue: String) -> String {
        guard !rawValue.isEmpty else { return "XXXX-XXXX-XXXX-XXXX" }

        let sanitized = rawValue.uppercased().filter { character in
            character.isLetter || character.isNumber
        }

        guard !sanitized.isEmpty else { return "XXXX-XXXX-XXXX-XXXX" }

        var groups: [String] = []
        var current = ""
        for character in sanitized {
            current.append(character)
            if current.count == 4 {
                groups.append(current)
                current = ""
            }
        }

        if !current.isEmpty {
            groups.append(current)
        }

        return groups.joined(separator: "-")
    }

    private func normalizedHint(_ hint: String) -> String {
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "****-****" : trimmed
    }

    private var shouldShowStatusRow: Bool {
        if licenseManager.isChecking {
            return true
        }

        let normalized = licenseManager.statusMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return normalized != "license not activated."
    }
}
