//
//  CameraManager.swift
//  Droppy
//
//  Manages camera session and visibility for the Camera extension
//

import SwiftUI
import Combine
@preconcurrency import AVFoundation
import AppKit

// AVFoundation types are not Sendable; wrap the session in a Sendable box and
// serialize all access through a private queue.
nonisolated final class CameraSessionBox: @unchecked Sendable {
    let session: AVCaptureSession = AVCaptureSession()
}

@MainActor
final class CameraManager: ObservableObject {
    static let shared = CameraManager()

    // MARK: - Published State

    @Published var isVisible: Bool = false
    @Published var isRunning: Bool = false
    @Published var isStopping: Bool = false
    @Published var permissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var videoAspectRatio: CGFloat = 16.0 / 9.0

    private var isStarting: Bool = false
    private var stopRequestID: Int = 0
    private var pendingStart: Bool = false
    private let restartDelay: TimeInterval = 0.2
    private var lastStopAt: Date? = nil

    // MARK: - Settings

    @AppStorage(AppPreferenceKey.cameraInstalled) var isInstalled: Bool = PreferenceDefault.cameraInstalled
    // MARK: - Capture

    nonisolated let sessionBox = CameraSessionBox()
    nonisolated let sessionQueue = DispatchQueue(label: "Droppy.CameraSession")
    private var isConfigured = false

    nonisolated var session: AVCaptureSession {
        sessionBox.session
    }

    private init() {}

    // MARK: - Public API

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if !isInstalled {
            install()
        }

        if ExtensionType.camera.isRemoved {
            ExtensionType.camera.setRemoved(false)
            NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.camera)
        }

        stopRequestID &+= 1
        isVisible = true

        // Expand shelf on the screen where the cursor is
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            DroppyState.shared.expandShelf(for: screen.displayID)
        } else if let mainScreen = NSScreen.main {
            DroppyState.shared.expandShelf(for: mainScreen.displayID)
        }

    }

    func hide() {
        if !isVisible && isStopping { return }

        stopRequestID &+= 1
        let requestID = stopRequestID

        if isVisible {
            isVisible = false
        }
        pendingStart = false
        isStopping = true

        stopSession {
            let manager = CameraManager.shared
            manager.isStopping = false
            manager.lastStopAt = Date()
            let shouldStart = manager.pendingStart && manager.isVisible
            manager.pendingStart = false
            if shouldStart {
                DispatchQueue.main.asyncAfter(deadline: .now() + manager.restartDelay) {
                    guard manager.isVisible else { return }
                    manager.startSessionIfNeeded()
                }
                return
            }
            let shouldCollapse = manager.stopRequestID == requestID && !manager.isVisible
            if shouldCollapse {
                // Collapse shelf when hiding camera (after session fully stops)
                DroppyState.shared.expandedDisplayID = nil
            }
        }
    }

    func cleanup() {
        isVisible = false
        isRunning = false
        isStopping = false
        isConfigured = false
        isInstalled = false

        stopSession()
        resetSession()
    }

    func preferredWidth(forHeight height: CGFloat, notchHeight: CGFloat, isExternalWithNotchStyle: Bool) -> CGFloat {
        let insets = NotchLayoutConstants.contentEdgeInsets(
            notchHeight: notchHeight,
            isExternalWithNotchStyle: isExternalWithNotchStyle
        )
        let availableHeight = max(1, height - insets.top - insets.bottom)
        let feedWidth = availableHeight * videoAspectRatio
        let totalWidth = feedWidth + insets.leading + insets.trailing

        return max(240, totalWidth)
    }

    // MARK: - Camera Session

    func startSessionIfNeeded() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permissionStatus = status

        switch status {
        case .authorized:
            startSessionIfPossible()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    let manager = CameraManager.shared
                    manager.permissionStatus = granted ? .authorized : .denied
                    if granted {
                        manager.startSessionIfPossible()
                    }
                }
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func requestAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permissionStatus = status

        if status == .authorized {
            startSessionIfPossible()
            return
        }

        guard status == .notDetermined else { return }

        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in
                let manager = CameraManager.shared
                manager.permissionStatus = granted ? .authorized : .denied
                if granted {
                    manager.startSessionIfPossible()
                }
            }
        }
    }

    private func startSessionIfPossible() {
        guard isVisible else { return }
        if isStopping {
            pendingStart = true
            return
        }
        if let lastStopAt {
            let elapsed = Date().timeIntervalSince(lastStopAt)
            if elapsed < restartDelay {
                DispatchQueue.main.asyncAfter(deadline: .now() + (restartDelay - elapsed)) {
                    guard self.isVisible else { return }
                    self.startSessionIfNeeded()
                }
                return
            }
        }
        lastStopAt = nil
        configureSessionIfNeeded()
        startSession()
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        var aspect: CGFloat?

        let localBox = sessionBox
        sessionQueue.sync {
            let session = localBox.session
            session.beginConfiguration()
            session.sessionPreset = .high

            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video)

            guard let camera = device else {
                session.commitConfiguration()
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(input) {
                    session.addInput(input)
                }

                let format = camera.activeFormat.formatDescription
                let dimensions = CMVideoFormatDescriptionGetDimensions(format)
                if dimensions.height > 0 {
                    aspect = CGFloat(dimensions.width) / CGFloat(dimensions.height)
                }
            } catch {
                session.commitConfiguration()
                return
            }

            session.commitConfiguration()
        }

        if let aspect {
            videoAspectRatio = aspect
        }

        isConfigured = true
    }

    private func startSession() {
        if isRunning || isStarting { return }
        isStarting = true
        isRunning = true
        let localBox = sessionBox
        sessionQueue.async {
            let session = localBox.session
            if session.isRunning {
                Task { @MainActor in
                    let manager = CameraManager.shared
                    manager.isRunning = true
                    manager.isStarting = false
                }
                return
            }
            session.startRunning()
            Task { @MainActor in
                let manager = CameraManager.shared
                manager.isRunning = true
                manager.isStarting = false
            }
        }
    }

    private func stopSession(completion: (() -> Void)? = nil) {
        isStarting = false
        let localBox = sessionBox
        sessionQueue.async {
            let session = localBox.session
            if !session.isRunning {
                Task { @MainActor in
                    CameraManager.shared.isRunning = false
                    CameraManager.shared.isStarting = false
                    completion?()
                }
                return
            }

            session.stopRunning()
            Task { @MainActor in
                CameraManager.shared.isRunning = false
                CameraManager.shared.isStarting = false
                completion?()
            }
        }
    }

    private func resetSession() {
        let localBox = sessionBox
        sessionQueue.async {
            let session = localBox.session
            session.beginConfiguration()
            for input in session.inputs {
                session.removeInput(input)
            }
            for output in session.outputs {
                session.removeOutput(output)
            }
            session.commitConfiguration()
        }
    }

    private func install() {
        isInstalled = true
        NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.camera)
    }
}
