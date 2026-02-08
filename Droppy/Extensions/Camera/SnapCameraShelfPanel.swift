//
//  SnapCameraShelfPanel.swift
//  Droppy
//
//  Live camera panel rendered inside the expanded shelf.
//

import SwiftUI
import AppKit
@preconcurrency import AVFoundation

struct SnapCameraShelfPanel: View {
    @ObservedObject var manager: CameraManager
    var size: CGFloat = 100
    private let panelCornerRadius: CGFloat = 24

    var body: some View {
        ZStack {
            if manager.permissionStatus == .authorized {
                CameraPreviewView(session: manager.session)
            } else {
                permissionPlaceholder
            }
        }
        .frame(width: size, height: size)
        .background(Color.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .onAppear {
            manager.previewDidAppear()
        }
        .onDisappear {
            manager.previewDidDisappear()
        }
    }

    @ViewBuilder
    private var permissionPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))

            Text(permissionText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 8)

            if manager.permissionStatus == .notDetermined {
                Button("Allow") {
                    manager.requestAccess()
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .cyan, size: .small))
            } else if manager.permissionStatus == .denied || manager.permissionStatus == .restricted {
                Button("Settings") {
                    openCameraPrivacySettings()
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .cyan, size: .small))
            }
        }
        .padding(.horizontal, 4)
    }

    private var permissionText: String {
        switch manager.permissionStatus {
        case .notDetermined:
            return "Camera access needed"
        case .denied, .restricted:
            return "Camera blocked"
        default:
            return "Camera unavailable"
        }
    }

    private func openCameraPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct SnapCameraNotchView: View {
    @ObservedObject var manager: CameraManager
    var notchHeight: CGFloat = 0
    var isExternalWithNotchStyle: Bool = false

    private let previewCornerRadius: CGFloat = 24

    private var contentPadding: EdgeInsets {
        NotchLayoutConstants.contentEdgeInsets(
            notchHeight: notchHeight,
            isExternalWithNotchStyle: isExternalWithNotchStyle
        )
    }

    var body: some View {
        ZStack {
            if manager.permissionStatus == .authorized {
                CameraPreviewView(session: manager.session)
            } else {
                expandedPermissionPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .padding(contentPadding)
        .onAppear {
            manager.previewDidAppear()
        }
        .onDisappear {
            manager.previewDidDisappear()
        }
    }

    @ViewBuilder
    private var expandedPermissionPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            Text(permissionText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(2)

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
        .padding(.horizontal, 16)
    }

    private var permissionText: String {
        switch manager.permissionStatus {
        case .notDetermined:
            return "Camera access needed for Notchface"
        case .denied, .restricted:
            return "Camera is blocked in System Settings"
        default:
            return "Camera unavailable"
        }
    }

    private func openCameraPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.session = session
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        if nsView.session !== session {
            nsView.session = session
        }
        nsView.updateMirroring()
    }
}

final class CameraPreviewNSView: NSView {
    var session: AVCaptureSession? {
        didSet {
            previewLayer.session = session
        }
    }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
    }

    override func makeBackingLayer() -> CALayer {
        AVCaptureVideoPreviewLayer()
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        updateMirroring()
    }

    func updateMirroring() {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}
