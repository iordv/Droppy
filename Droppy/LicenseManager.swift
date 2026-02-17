import Combine
import CryptoKit
import Foundation
import Security

@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    /// Maximum number of simultaneous device activations allowed per license key.
    private static let maxDeviceActivations = 1
    private static let trialDuration: TimeInterval = 3 * 24 * 60 * 60
    private static let clockRollbackTolerance: TimeInterval = 300
    private static let remoteTrialSyncGrace: TimeInterval = 24 * 60 * 60

    @Published private(set) var requiresLicenseEnforcement: Bool
    @Published private(set) var isActivated: Bool
    @Published private(set) var isTrialActive: Bool
    @Published private(set) var hasUsedTrial: Bool
    @Published private(set) var trialStartedAt: Date?
    @Published private(set) var trialExpiresAt: Date?
    @Published private(set) var lastRemoteTrialSyncAt: Date?
    @Published private(set) var isChecking: Bool = false
    @Published private(set) var statusMessage: String
    @Published private(set) var licensedEmail: String
    @Published private(set) var licenseKeyHint: String
    @Published private(set) var activatedDeviceName: String
    @Published private(set) var lastVerifiedAt: Date?

    var purchaseURL: URL? { configuration.purchaseURL }
    var hasAccess: Bool {
        guard requiresLicenseEnforcement else { return true }
        if isActivated { return true }
        guard isTrialActive else { return false }
        guard configuration.usesRemoteTrialEntitlement else { return true }
        guard let lastRemoteTrialSyncAt else { return false }
        return Date().timeIntervalSince(lastRemoteTrialSyncAt) <= Self.remoteTrialSyncGrace
    }
    var canStartTrial: Bool { requiresLicenseEnforcement && !isActivated && !hasUsedTrial }
    var needsEmailForTrialStart: Bool {
        guard canStartTrial else { return false }
        guard configuration.usesRemoteTrialEntitlement else { return false }
        return cachedTrialAccountHash() == nil
    }
    var trialEmailRequirementText: String? {
        needsEmailForTrialStart ? "Purchase email required to start trial." : nil
    }
    func canSubmitTrialStart(accountEmail: String?) -> Bool {
        guard canStartTrial else { return false }
        guard needsEmailForTrialStart else { return true }
        return makeTrialAccountHash(fromEmail: accountEmail) != nil
    }
    var trialRemaining: TimeInterval? {
        guard isTrialActive, let trialExpiresAt else { return nil }
        return max(0, trialExpiresAt.timeIntervalSinceNow)
    }
    var trialStatusText: String {
        if isActivated {
            return "License active. Trial not needed."
        }
        if isTrialActive {
            return "Trial active: \(Self.formatTrialRemaining(trialRemaining ?? 0)) left."
        }
        if hasUsedTrial {
            return "Trial already used."
        }
        return "Start your 3-day trial."
    }

    private let defaults: UserDefaults
    private let session: URLSession
    private let keychainStore: GumroadLicenseKeychainStore
    private let trialStore: DroppyTrialKeychainStore
    private let trialMarkerURL: URL
    private let configuration: Configuration
    private var trialAccountHash: String?
    private var didBootstrap = false

    private init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
        self.keychainStore = GumroadLicenseKeychainStore()
        self.trialStore = DroppyTrialKeychainStore()
        self.trialMarkerURL = Self.makeTrialMarkerURL()

        let loadedConfiguration = Self.loadConfiguration()
        self.configuration = loadedConfiguration

        let enforcementEnabled = loadedConfiguration.isConfigured
        self.requiresLicenseEnforcement = enforcementEnabled
        self.isActivated = !enforcementEnabled
        self.isTrialActive = false
        self.hasUsedTrial = false
        self.trialStartedAt = nil
        self.trialExpiresAt = nil
        self.lastRemoteTrialSyncAt = nil
        self.trialAccountHash = nil
        self.statusMessage = enforcementEnabled ? "License not activated." : "License checks disabled."
        self.licensedEmail = ""
        self.licenseKeyHint = ""
        self.activatedDeviceName = ""
        self.lastVerifiedAt = nil

        if enforcementEnabled {
            if let storedHash = trialStore.fetchAccountHash()?.nonEmpty {
                self.trialAccountHash = storedHash
            } else if let defaultsHash = defaults.string(forKey: AppPreferenceKey.licenseTrialAccountHash)?.nonEmpty {
                self.trialAccountHash = defaultsHash
            }
            if defaults.object(forKey: AppPreferenceKey.licenseTrialLastRemoteSyncAt) != nil {
                let ts = defaults.double(forKey: AppPreferenceKey.licenseTrialLastRemoteSyncAt)
                if ts > 0 {
                    self.lastRemoteTrialSyncAt = Date(timeIntervalSince1970: ts)
                }
            }
            restoreStoredState()
            refreshTrialState()
        }
    }

    func bootstrap() {
        guard requiresLicenseEnforcement, !didBootstrap else { return }
        didBootstrap = true
        refreshTrialState()

        Task {
            await syncRemoteTrialEntitlement()
            // Re-validate in background on launch so revoked licenses are detected.
            await revalidateStoredLicense()
        }
    }

    @discardableResult
    func activate(licenseKey: String, email: String?) async -> Bool {
        guard requiresLicenseEnforcement else { return true }
        guard !isChecking else { return false }

        let trimmedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = (email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            statusMessage = "Enter your Gumroad license key."
            return false
        }

        isChecking = true
        defer { isChecking = false }

        do {
            let response = try await verifyLicense(licenseKey: trimmedKey, incrementUsesCount: true)
            guard response.isValidPurchase else {
                statusMessage = response.message?.nonEmpty ?? "That license key is not valid for this product."
                return false
            }

            // Enforce single-device limit: if uses exceeds the max, this key is
            // already active on another device. Roll back the increment and reject.
            let currentUses = response.purchase?.uses ?? 1
            if currentUses > Self.maxDeviceActivations {
                // Decrement back so the count stays accurate
                _ = try? await verifyLicense(licenseKey: trimmedKey, incrementUsesCount: false, decrementUsesCount: true)
                statusMessage = "This license is already active on another device. Deactivate it there first."
                return false
            }

            let resolvedEmail = response.purchase?.email?.nonEmpty ?? trimmedEmail
            let keyHint = Self.keyHint(for: trimmedKey)

            guard keychainStore.storeLicenseKey(trimmedKey) else {
                // We already incremented uses_count above, so roll it back if local persistence fails.
                _ = try? await verifyLicense(
                    licenseKey: trimmedKey,
                    incrementUsesCount: false,
                    decrementUsesCount: true
                )
                statusMessage = "License could not be saved to Keychain."
                return false
            }

            setActivatedState(
                isActive: true,
                email: resolvedEmail,
                keyHint: keyHint,
                deviceName: Self.currentDeviceName(),
                verifiedAt: Date(),
                message: "License activated."
            )
            persistTrialAccountHash(fromEmail: resolvedEmail)
            return true
        } catch {
            statusMessage = "Could not verify with Gumroad: \(error.localizedDescription)"
            return false
        }
    }

    func revalidateStoredLicense() async {
        guard requiresLicenseEnforcement else { return }
        guard !isChecking else { return }
        refreshTrialState()
        await syncRemoteTrialEntitlement()

        guard let storedKey = keychainStore.fetchLicenseKey()?.nonEmpty else {
            if isTrialActive {
                statusMessage = trialStatusText
            } else if configuration.usesRemoteTrialEntitlement && hasUsedTrial {
                statusMessage = "Trial verification required. Connect to the internet."
            } else {
                setActivatedState(
                    isActive: false,
                    email: "",
                    keyHint: "",
                    deviceName: "",
                    verifiedAt: nil,
                    message: hasUsedTrial ? "Trial ended. Activate a license to continue." : "License not activated.",
                    clearKeychain: false
                )
            }
            return
        }

        isChecking = true
        defer { isChecking = false }

        do {
            let response = try await verifyLicense(licenseKey: storedKey, incrementUsesCount: false)
            guard response.isValidPurchase else {
                setActivatedState(
                    isActive: false,
                    email: "",
                    keyHint: "",
                    deviceName: "",
                    verifiedAt: nil,
                    message: response.message?.nonEmpty ?? "License is no longer valid.",
                    clearKeychain: true
                )
                return
            }

            let resolvedEmail = response.purchase?.email?.nonEmpty ?? licensedEmail
            setActivatedState(
                isActive: true,
                email: resolvedEmail,
                keyHint: Self.keyHint(for: storedKey),
                deviceName: Self.currentDeviceName(),
                verifiedAt: Date(),
                message: "License verified."
            )
        } catch {
            if isActivated {
                statusMessage = "Could not reach Gumroad. Using last verified license."
            } else if isTrialActive {
                statusMessage = trialStatusText
            } else {
                statusMessage = "Could not verify license: \(error.localizedDescription)"
            }
        }
    }

    @discardableResult
    func startTrial(accountEmail: String? = nil) async -> Bool {
        guard requiresLicenseEnforcement else { return false }
        guard !isActivated else {
            statusMessage = "License is already active."
            return false
        }

        refreshTrialState()
        guard !hasUsedTrial else {
            statusMessage = "This Mac has already used its 3-day trial."
            return false
        }

        let previousAccess = hasAccess
        let accountHash = resolveTrialAccountHash(inputEmail: accountEmail)
        var didNotifyAccessChange = false
        if configuration.usesRemoteTrialEntitlement {
            guard accountHash != nil else {
                statusMessage = "Enter your purchase email to start trial."
                return false
            }
            do {
                let response = try await requestRemoteTrialEntitlement(action: "start", accountHash: accountHash)
                applyRemoteTrialState(response)
                didNotifyAccessChange = true

                guard isTrialActive else {
                    statusMessage = response.message?.nonEmpty ?? "Trial is unavailable for this Mac."
                    return false
                }
            } catch {
                statusMessage = "Could not start trial: \(error.localizedDescription)"
                return false
            }
        } else {
            let now = Date()
            let expires = now.addingTimeInterval(Self.trialDuration)

            let consumedStored = trialStore.storeConsumedFlag(true)
            let startedStored = trialStore.storeTrialStartedAt(now)
            let expiresStored = trialStore.storeTrialExpiresAt(expires)
            let seenStored = trialStore.storeLastSeenDate(now)
            let markerStored = markTrialConsumedFile()

            guard consumedStored || startedStored || expiresStored || seenStored || markerStored else {
                statusMessage = "Trial could not be started on this Mac."
                return false
            }

            hasUsedTrial = true
            isTrialActive = true
            trialStartedAt = now
            trialExpiresAt = expires
            statusMessage = "Trial started: \(Self.formatTrialRemaining(Self.trialDuration)) left."

            defaults.set(true, forKey: AppPreferenceKey.licenseTrialConsumed)
            defaults.set(now.timeIntervalSince1970, forKey: AppPreferenceKey.licenseTrialStartedAt)
            defaults.set(expires.timeIntervalSince1970, forKey: AppPreferenceKey.licenseTrialExpiresAt)
        }

        if !didNotifyAccessChange && !previousAccess && hasAccess {
            NotificationCenter.default.post(name: .licenseStateDidChange, object: hasAccess)
        }

        return true
    }

    func deactivateLocally() {
        guard requiresLicenseEnforcement else { return }

        setActivatedState(
            isActive: false,
            email: "",
            keyHint: "",
            deviceName: "",
            verifiedAt: nil,
            message: "License removed from this Mac.",
            clearKeychain: true
        )
    }

    func deactivateCurrentDevice() async {
        guard requiresLicenseEnforcement else { return }
        guard !isChecking else { return }

        guard let storedKey = keychainStore.fetchLicenseKey()?.nonEmpty else {
            deactivateLocally()
            return
        }

        isChecking = true
        defer { isChecking = false }

        do {
            _ = try await verifyLicense(
                licenseKey: storedKey,
                incrementUsesCount: false,
                decrementUsesCount: true
            )

            setActivatedState(
                isActive: false,
                email: "",
                keyHint: "",
                deviceName: "",
                verifiedAt: nil,
                message: "License removed from this Mac.",
                clearKeychain: true
            )
        } catch {
            setActivatedState(
                isActive: false,
                email: "",
                keyHint: "",
                deviceName: "",
                verifiedAt: nil,
                message: "License removed locally. Re-activate and remove while online to release this seat.",
                clearKeychain: true
            )
        }
    }

    private func restoreStoredState() {
        licensedEmail = defaults.string(forKey: AppPreferenceKey.gumroadLicenseEmail) ?? ""
        licenseKeyHint = defaults.string(forKey: AppPreferenceKey.gumroadLicenseKeyHint) ?? ""
        activatedDeviceName = defaults.string(forKey: AppPreferenceKey.gumroadLicenseDeviceName) ?? ""

        if defaults.object(forKey: AppPreferenceKey.gumroadLicenseLastValidatedAt) != nil {
            let seconds = defaults.double(forKey: AppPreferenceKey.gumroadLicenseLastValidatedAt)
            if seconds > 0 {
                lastVerifiedAt = Date(timeIntervalSince1970: seconds)
            }
        }

        let hasStoredKey = keychainStore.fetchLicenseKey()?.nonEmpty != nil
        let hasStoredActivationFlag = defaults.object(forKey: AppPreferenceKey.gumroadLicenseActive) != nil
        let storedActiveFlag = defaults.bool(forKey: AppPreferenceKey.gumroadLicenseActive)

        isActivated = hasStoredKey && (storedActiveFlag || !hasStoredActivationFlag)
        if isActivated && activatedDeviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activatedDeviceName = Self.currentDeviceName()
            defaults.set(activatedDeviceName, forKey: AppPreferenceKey.gumroadLicenseDeviceName)
        }
        if isActivated {
            statusMessage = hasStoredActivationFlag ? "License active." : "Saved license found. Verifying…"
        } else {
            statusMessage = "License not activated."
        }
    }

    private func refreshTrialState(referenceDate: Date = Date()) {
        guard requiresLicenseEnforcement else {
            isTrialActive = false
            hasUsedTrial = false
            trialStartedAt = nil
            trialExpiresAt = nil
            return
        }

        let fileConsumed = FileManager.default.fileExists(atPath: trialMarkerURL.path)
        let defaultsConsumed = defaults.bool(forKey: AppPreferenceKey.licenseTrialConsumed)
        let keychainConsumed = trialStore.fetchConsumedFlag()

        var startedAt = trialStore.fetchTrialStartedAt()
        if startedAt == nil {
            let ts = defaults.double(forKey: AppPreferenceKey.licenseTrialStartedAt)
            if ts > 0 { startedAt = Date(timeIntervalSince1970: ts) }
        }

        var expiresAt = trialStore.fetchTrialExpiresAt()
        if expiresAt == nil {
            let ts = defaults.double(forKey: AppPreferenceKey.licenseTrialExpiresAt)
            if ts > 0 { expiresAt = Date(timeIntervalSince1970: ts) }
        }

        let consumed = fileConsumed || defaultsConsumed || keychainConsumed || startedAt != nil
        if consumed {
            _ = trialStore.storeConsumedFlag(true)
            _ = markTrialConsumedFile()
        }

        if consumed, let startedAt, expiresAt == nil {
            expiresAt = startedAt.addingTimeInterval(Self.trialDuration)
            _ = trialStore.storeTrialExpiresAt(expiresAt!)
        }

        let lastSeen = trialStore.fetchLastSeenDate()
        let hasClockRollback: Bool
        if let lastSeen {
            hasClockRollback = referenceDate < lastSeen.addingTimeInterval(-Self.clockRollbackTolerance)
            if referenceDate > lastSeen {
                _ = trialStore.storeLastSeenDate(referenceDate)
            }
        } else {
            hasClockRollback = false
            _ = trialStore.storeLastSeenDate(referenceDate)
        }

        let active: Bool
        if consumed, let expiresAt {
            active = !hasClockRollback && referenceDate < expiresAt
        } else {
            active = false
        }

        let remoteSyncExpired: Bool
        if configuration.usesRemoteTrialEntitlement {
            guard let lastRemoteTrialSyncAt else {
                remoteSyncExpired = consumed
                hasUsedTrial = consumed
                trialStartedAt = startedAt
                trialExpiresAt = expiresAt
                isTrialActive = false
                defaults.set(consumed, forKey: AppPreferenceKey.licenseTrialConsumed)
                if let startedAt {
                    defaults.set(startedAt.timeIntervalSince1970, forKey: AppPreferenceKey.licenseTrialStartedAt)
                } else {
                    defaults.removeObject(forKey: AppPreferenceKey.licenseTrialStartedAt)
                }
                if let expiresAt {
                    defaults.set(expiresAt.timeIntervalSince1970, forKey: AppPreferenceKey.licenseTrialExpiresAt)
                } else {
                    defaults.removeObject(forKey: AppPreferenceKey.licenseTrialExpiresAt)
                }
                if !isActivated && consumed {
                    statusMessage = "Trial verification required. Connect to the internet."
                }
                return
            }
            remoteSyncExpired = referenceDate.timeIntervalSince(lastRemoteTrialSyncAt) > Self.remoteTrialSyncGrace
        } else {
            remoteSyncExpired = false
        }

        hasUsedTrial = consumed
        trialStartedAt = startedAt
        trialExpiresAt = expiresAt
        isTrialActive = active && !remoteSyncExpired

        defaults.set(consumed, forKey: AppPreferenceKey.licenseTrialConsumed)
        if let startedAt {
            defaults.set(startedAt.timeIntervalSince1970, forKey: AppPreferenceKey.licenseTrialStartedAt)
        } else {
            defaults.removeObject(forKey: AppPreferenceKey.licenseTrialStartedAt)
        }
        if let expiresAt {
            defaults.set(expiresAt.timeIntervalSince1970, forKey: AppPreferenceKey.licenseTrialExpiresAt)
        } else {
            defaults.removeObject(forKey: AppPreferenceKey.licenseTrialExpiresAt)
        }

        if !isActivated {
            if hasClockRollback && consumed {
                statusMessage = "Trial ended because system time changed unexpectedly."
            } else if remoteSyncExpired && consumed {
                statusMessage = "Trial verification required. Connect to the internet."
            } else if active {
                statusMessage = trialStatusText
            } else if consumed {
                statusMessage = "Trial ended. Activate a license to continue."
            }
        }
    }

    private func syncRemoteTrialEntitlement() async {
        guard requiresLicenseEnforcement else { return }
        guard configuration.usesRemoteTrialEntitlement else { return }
        guard !isActivated else { return }

        do {
            let response = try await requestRemoteTrialEntitlement(action: "status", accountHash: resolveTrialAccountHash(inputEmail: nil))
            applyRemoteTrialState(response)
        } catch {
            refreshTrialState()
            if isTrialActive {
                // Keep existing trial state if we recently synced, but surface degraded mode.
                statusMessage = "Using cached trial state. Reconnect to verify."
            } else {
                statusMessage = "Trial verification required. Connect to the internet."
            }
        }
    }

    private func applyRemoteTrialState(_ response: RemoteTrialEntitlementResponse) {
        let previousAccess = hasAccess
        let now = Date()
        let serverNow = response.serverNow ?? now
        let startedAt = response.startedAt ?? (response.active ? serverNow : nil)
        let expiresAt = response.expiresAt
        let consumed = response.consumed || response.active || response.eligible == false
        let active = response.active && (expiresAt.map { serverNow < $0 } ?? false)

        _ = trialStore.storeConsumedFlag(consumed)
        if let startedAt {
            _ = trialStore.storeTrialStartedAt(startedAt)
        }
        if let expiresAt {
            _ = trialStore.storeTrialExpiresAt(expiresAt)
        }
        _ = trialStore.storeLastSeenDate(serverNow)
        if consumed {
            _ = markTrialConsumedFile()
        }

        defaults.set(consumed, forKey: AppPreferenceKey.licenseTrialConsumed)
        if let startedAt {
            defaults.set(startedAt.timeIntervalSince1970, forKey: AppPreferenceKey.licenseTrialStartedAt)
        } else {
            defaults.removeObject(forKey: AppPreferenceKey.licenseTrialStartedAt)
        }
        if let expiresAt {
            defaults.set(expiresAt.timeIntervalSince1970, forKey: AppPreferenceKey.licenseTrialExpiresAt)
        } else {
            defaults.removeObject(forKey: AppPreferenceKey.licenseTrialExpiresAt)
        }

        lastRemoteTrialSyncAt = now
        defaults.set(now.timeIntervalSince1970, forKey: AppPreferenceKey.licenseTrialLastRemoteSyncAt)

        hasUsedTrial = consumed
        trialStartedAt = startedAt
        trialExpiresAt = expiresAt
        isTrialActive = active

        if !isActivated {
            if active {
                statusMessage = "Trial active: \(Self.formatTrialRemaining(expiresAt?.timeIntervalSince(now) ?? 0)) left."
            } else if consumed {
                statusMessage = response.message?.nonEmpty ?? "Trial already used on this Mac."
            } else {
                statusMessage = "Start your 3-day trial."
            }
        }

        if previousAccess != hasAccess {
            NotificationCenter.default.post(name: .licenseStateDidChange, object: hasAccess)
        }
    }

    private func setActivatedState(
        isActive: Bool,
        email: String,
        keyHint: String,
        deviceName: String,
        verifiedAt: Date?,
        message: String,
        clearKeychain: Bool = false,
        notify: Bool = true
    ) {
        let previousAccess = hasAccess

        if clearKeychain {
            keychainStore.deleteLicenseKey()
        }

        isActivated = isActive
        licensedEmail = email
        licenseKeyHint = keyHint
        activatedDeviceName = isActive ? (deviceName.nonEmpty ?? Self.currentDeviceName()) : ""
        lastVerifiedAt = verifiedAt
        statusMessage = message

        defaults.set(isActive, forKey: AppPreferenceKey.gumroadLicenseActive)
        defaults.set(email, forKey: AppPreferenceKey.gumroadLicenseEmail)
        defaults.set(keyHint, forKey: AppPreferenceKey.gumroadLicenseKeyHint)
        defaults.set(activatedDeviceName, forKey: AppPreferenceKey.gumroadLicenseDeviceName)

        if let verifiedAt {
            defaults.set(verifiedAt.timeIntervalSince1970, forKey: AppPreferenceKey.gumroadLicenseLastValidatedAt)
        } else {
            defaults.removeObject(forKey: AppPreferenceKey.gumroadLicenseLastValidatedAt)
        }

        refreshTrialState()

        if notify, previousAccess != hasAccess {
            NotificationCenter.default.post(name: .licenseStateDidChange, object: hasAccess)
        }
    }

    private func verifyLicense(
        licenseKey: String,
        incrementUsesCount: Bool,
        decrementUsesCount: Bool = false
    ) async throws -> GumroadVerifyResponse {
        guard configuration.isConfigured else {
            throw LicenseVerificationError.missingProductIdentifier
        }

        guard let url = URL(string: "https://api.gumroad.com/v2/licenses/verify") else {
            throw LicenseVerificationError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "license_key", value: licenseKey),
            URLQueryItem(name: "increment_uses_count", value: incrementUsesCount ? "true" : "false")
        ]

        if decrementUsesCount {
            queryItems.append(URLQueryItem(name: "decrement_uses_count", value: "true"))
        }

        if let productID = configuration.productID {
            queryItems.append(URLQueryItem(name: "product_id", value: productID))
        } else if let productPermalink = configuration.productPermalink {
            queryItems.append(URLQueryItem(name: "product_permalink", value: productPermalink))
        }

        var components = URLComponents()
        components.queryItems = queryItems
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LicenseVerificationError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseVerificationError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let decoded = try? decoder.decode(GumroadVerifyResponse.self, from: data) {
            if httpResponse.statusCode >= 500 {
                throw LicenseVerificationError.server(decoded.message?.nonEmpty ?? "Gumroad is temporarily unavailable.")
            }
            return decoded
        }

        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = payload["message"] as? String {
            throw LicenseVerificationError.server(message)
        }

        let fallbackMessage = String(data: data, encoding: .utf8)?.nonEmpty ?? "Unexpected response from Gumroad."
        throw LicenseVerificationError.server(fallbackMessage)
    }

    private func requestRemoteTrialEntitlement(
        action: String,
        accountHash: String?
    ) async throws -> RemoteTrialEntitlementResponse {
        guard let baseURL = configuration.trialEntitlementBaseURL else {
            throw LicenseVerificationError.invalidRequest
        }

        let endpoint = baseURL.appendingPathComponent(action)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let publicKey = configuration.trialEntitlementPublicKey {
            request.setValue("Bearer \(publicKey)", forHTTPHeaderField: "Authorization")
            request.setValue(publicKey, forHTTPHeaderField: "x-trial-key")
        }

        let payload = RemoteTrialEntitlementRequest(
            deviceID: stableTrialDeviceID(),
            accountHash: accountHash,
            appBundleID: Bundle.main.bundleIdentifier ?? "com.iordv.droppy",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LicenseVerificationError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseVerificationError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970

        guard let decoded = try? decoder.decode(RemoteTrialEntitlementResponse.self, from: data) else {
            let raw = String(data: data, encoding: .utf8)?.nonEmpty ?? "Invalid trial entitlement response."
            throw LicenseVerificationError.server(raw)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw LicenseVerificationError.server(decoded.message?.nonEmpty ?? "Trial entitlement request failed.")
        }

        return decoded
    }

    private func stableTrialDeviceID() -> String {
        if let existing = trialStore.fetchDeviceID()?.nonEmpty {
            return existing
        }

        let seed = [
            Host.current().localizedName ?? "",
            ProcessInfo.processInfo.hostName,
            ProcessInfo.processInfo.operatingSystemVersionString,
            Bundle.main.bundleIdentifier ?? "com.iordv.droppy"
        ].joined(separator: "|")

        let hash = SHA256.hash(data: Data(seed.utf8))
        let value = hash.map { String(format: "%02x", $0) }.joined()
        _ = trialStore.storeDeviceID(value)
        return value
    }

    private func resolveTrialAccountHash(inputEmail: String?) -> String? {
        if let hash = makeTrialAccountHash(fromEmail: inputEmail) {
            trialAccountHash = hash
            _ = trialStore.storeAccountHash(hash)
            defaults.set(hash, forKey: AppPreferenceKey.licenseTrialAccountHash)
            return hash
        }

        if let existing = trialAccountHash?.nonEmpty {
            return existing
        }

        if let stored = trialStore.fetchAccountHash()?.nonEmpty {
            trialAccountHash = stored
            defaults.set(stored, forKey: AppPreferenceKey.licenseTrialAccountHash)
            return stored
        }

        if let defaultsHash = defaults.string(forKey: AppPreferenceKey.licenseTrialAccountHash)?.nonEmpty {
            trialAccountHash = defaultsHash
            return defaultsHash
        }

        if let hash = makeTrialAccountHash(fromEmail: licensedEmail) {
            trialAccountHash = hash
            _ = trialStore.storeAccountHash(hash)
            defaults.set(hash, forKey: AppPreferenceKey.licenseTrialAccountHash)
            return hash
        }

        return nil
    }

    private func cachedTrialAccountHash() -> String? {
        if let existing = trialAccountHash?.nonEmpty {
            return existing
        }
        if let stored = trialStore.fetchAccountHash()?.nonEmpty {
            return stored
        }
        if let defaultsHash = defaults.string(forKey: AppPreferenceKey.licenseTrialAccountHash)?.nonEmpty {
            return defaultsHash
        }
        if let hash = makeTrialAccountHash(fromEmail: licensedEmail) {
            return hash
        }
        return nil
    }

    private func persistTrialAccountHash(fromEmail email: String) {
        guard let hash = makeTrialAccountHash(fromEmail: email) else { return }
        trialAccountHash = hash
        _ = trialStore.storeAccountHash(hash)
        defaults.set(hash, forKey: AppPreferenceKey.licenseTrialAccountHash)
    }

    private func makeTrialAccountHash(fromEmail email: String?) -> String? {
        guard let email else { return nil }
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.contains("@"), normalized.count >= 5 else { return nil }
        let hash = SHA256.hash(data: Data(normalized.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static func loadConfiguration() -> Configuration {
        let info = Bundle.main.infoDictionary ?? [:]

        let productID = normalizedConfigValue(info["GumroadProductID"] as? String)
        let productPermalink = normalizedConfigValue(info["GumroadProductPermalink"] as? String)

        let rawPurchaseURL = normalizedConfigValue(info["GumroadPurchaseURL"] as? String)
        let purchaseURL = rawPurchaseURL.flatMap(URL.init(string:))
        let rawTrialURL = normalizedConfigValue(info["TrialEntitlementBaseURL"] as? String)
        let trialEntitlementBaseURL = rawTrialURL.flatMap(URL.init(string:))
        let trialEntitlementPublicKey = normalizedConfigValue(info["TrialEntitlementPublicKey"] as? String)

        return Configuration(
            productID: productID,
            productPermalink: productPermalink,
            purchaseURL: purchaseURL,
            trialEntitlementBaseURL: trialEntitlementBaseURL,
            trialEntitlementPublicKey: trialEntitlementPublicKey
        )
    }

    private static func normalizedConfigValue(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let placeholderValues: Set<String> = [
            "YOUR_GUMROAD_PRODUCT_ID",
            "YOUR_GUMROAD_PRODUCT_PERMALINK",
            "YOUR_GUMROAD_PURCHASE_URL",
            "YOUR_TRIAL_ENTITLEMENT_BASE_URL",
            "YOUR_TRIAL_ENTITLEMENT_PUBLIC_KEY"
        ]

        if placeholderValues.contains(trimmed) {
            return nil
        }

        return trimmed
    }

    private static func keyHint(for key: String) -> String {
        let suffix = String(key.suffix(4))
        return suffix.isEmpty ? "****" : "****\(suffix)"
    }

    private static func currentDeviceName() -> String {
        if let localized = Host.current().localizedName?.nonEmpty {
            return localized
        }
        if let host = ProcessInfo.processInfo.hostName.nonEmpty {
            return host
        }
        return "This Mac"
    }

    private static func formatTrialRemaining(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 86_400 ? [.day, .hour] : [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(0, interval)) ?? "0m"
    }

    private static func makeTrialMarkerURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = appSupport
            .appendingPathComponent("com.iordv.droppy", isDirectory: true)
            .appendingPathComponent("licensing", isDirectory: true)
        return directory.appendingPathComponent("trial_used.marker", isDirectory: false)
    }

    private func markTrialConsumedFile() -> Bool {
        let directory = trialMarkerURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let payload = "trial-used".data(using: .utf8) ?? Data()
            try payload.write(to: trialMarkerURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

private extension LicenseManager {
    struct Configuration {
        let productID: String?
        let productPermalink: String?
        let purchaseURL: URL?
        let trialEntitlementBaseURL: URL?
        let trialEntitlementPublicKey: String?

        var isConfigured: Bool {
            productID != nil || productPermalink != nil
        }

        var usesRemoteTrialEntitlement: Bool {
            trialEntitlementBaseURL != nil
        }
    }

    struct RemoteTrialEntitlementRequest: Encodable {
        let deviceID: String
        let accountHash: String?
        let appBundleID: String
        let appVersion: String
    }

    struct RemoteTrialEntitlementResponse: Decodable {
        let eligible: Bool?
        let active: Bool
        let consumed: Bool
        let startedAt: Date?
        let expiresAt: Date?
        let serverNow: Date?
        let message: String?

        enum CodingKeys: String, CodingKey {
            case eligible
            case active
            case consumed
            case startedAt
            case expiresAt
            case serverNow
            case message
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            eligible = try container.decodeIfPresent(Bool.self, forKey: .eligible)
            active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? false
            consumed = try container.decodeIfPresent(Bool.self, forKey: .consumed) ?? false
            startedAt = try Self.decodeDateIfPresent(container: container, key: .startedAt)
            expiresAt = try Self.decodeDateIfPresent(container: container, key: .expiresAt)
            serverNow = try Self.decodeDateIfPresent(container: container, key: .serverNow)
            message = try container.decodeIfPresent(String.self, forKey: .message)
        }

        private static func decodeDateIfPresent(
            container: KeyedDecodingContainer<CodingKeys>,
            key: CodingKeys
        ) throws -> Date? {
            if let seconds = try container.decodeIfPresent(Double.self, forKey: key) {
                return Date(timeIntervalSince1970: seconds)
            }
            if let secondsInt = try container.decodeIfPresent(Int.self, forKey: key) {
                return Date(timeIntervalSince1970: TimeInterval(secondsInt))
            }
            if let iso = try container.decodeIfPresent(String.self, forKey: key),
               let date = ISO8601DateFormatter().date(from: iso) {
                return date
            }
            return nil
        }
    }

    struct GumroadVerifyResponse: Decodable {
        let success: Bool
        let message: String?
        let purchase: Purchase?

        var isValidPurchase: Bool {
            guard success else { return false }
            guard purchase?.refunded != true,
                  purchase?.disputed != true,
                  purchase?.chargebacked != true else {
                return false
            }
            guard purchase?.subscriptionEndedAt?.nonEmpty == nil else {
                return false
            }
            return true
        }

        struct Purchase: Decodable {
            let email: String?
            let uses: Int?
            let refunded: Bool?
            let disputed: Bool?
            let chargebacked: Bool?
            let subscriptionEndedAt: String?
        }
    }

    enum LicenseVerificationError: LocalizedError {
        case missingProductIdentifier
        case invalidRequest
        case invalidResponse
        case network(String)
        case server(String)

        var errorDescription: String? {
            switch self {
            case .missingProductIdentifier:
                return "Gumroad product identifier is missing. Set GumroadProductID in Info.plist."
            case .invalidRequest:
                return "License verification request could not be created."
            case .invalidResponse:
                return "Received an invalid response from Gumroad."
            case .network(let message):
                return message
            case .server(let message):
                return message
            }
        }
    }
}

private struct GumroadLicenseKeychainStore {
    private let service = "com.iordv.droppy.gumroad-license"
    private let account = "license_key"

    func storeLicenseKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    func fetchLicenseKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    func deleteLicenseKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private struct DroppyTrialKeychainStore {
    private let service = "com.iordv.droppy.trial"
    private let consumedAccount = "consumed"
    private let startedAtAccount = "started_at"
    private let expiresAtAccount = "expires_at"
    private let lastSeenAccount = "last_seen_at"
    private let deviceIDAccount = "device_id"
    private let accountHashAccount = "account_hash"

    func storeConsumedFlag(_ value: Bool) -> Bool {
        storeString(value ? "1" : "0", account: consumedAccount)
    }

    func fetchConsumedFlag() -> Bool {
        fetchString(account: consumedAccount) == "1"
    }

    func storeTrialStartedAt(_ date: Date) -> Bool {
        storeString(String(date.timeIntervalSince1970), account: startedAtAccount)
    }

    func fetchTrialStartedAt() -> Date? {
        fetchDate(account: startedAtAccount)
    }

    func storeTrialExpiresAt(_ date: Date) -> Bool {
        storeString(String(date.timeIntervalSince1970), account: expiresAtAccount)
    }

    func fetchTrialExpiresAt() -> Date? {
        fetchDate(account: expiresAtAccount)
    }

    func storeLastSeenDate(_ date: Date) -> Bool {
        storeString(String(date.timeIntervalSince1970), account: lastSeenAccount)
    }

    func fetchLastSeenDate() -> Date? {
        fetchDate(account: lastSeenAccount)
    }

    func storeDeviceID(_ value: String) -> Bool {
        storeString(value, account: deviceIDAccount)
    }

    func fetchDeviceID() -> String? {
        fetchString(account: deviceIDAccount)
    }

    func storeAccountHash(_ value: String) -> Bool {
        storeString(value, account: accountHashAccount)
    }

    func fetchAccountHash() -> String? {
        fetchString(account: accountHashAccount)
    }

    private func fetchDate(account: String) -> Date? {
        guard let raw = fetchString(account: account),
              let seconds = TimeInterval(raw),
              seconds > 0 else {
            return nil
        }
        return Date(timeIntervalSince1970: seconds)
    }

    private func storeString(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func fetchString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
