//
//  CameraNotchView.swift
//  Droppy
//
//  SwiftUI view for the Camera extension notch preview
//

import SwiftUI
import AVFoundation
import AppKit

struct CameraNotchView: View {
    @ObservedObject var manager: CameraManager
    var notchHeight: CGFloat = 0
    var isExternalWithNotchStyle: Bool = false

    private var contentInsets: EdgeInsets {
        NotchLayoutConstants.contentEdgeInsets(
            notchHeight: notchHeight,
            isExternalWithNotchStyle: isExternalWithNotchStyle
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cameraContent
                .padding(contentInsets)
        }
        .onAppear {
            if manager.isVisible {
                manager.startSessionIfNeeded()
            }
        }
        .onChange(of: manager.isVisible) { _, isVisible in
            if isVisible {
                manager.startSessionIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
        if manager.permissionStatus == .authorized {
            CameraPreviewView(session: manager.session)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xxl + 2, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.xxl + 2, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text(permissionMessage)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xxl + 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.xxl + 2, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var permissionMessage: String {
        switch manager.permissionStatus {
        case .denied, .restricted:
            return "Camera access is blocked. Enable it in System Settings."
        case .notDetermined:
            return "Allow camera access to preview your camera."
        default:
            return "Camera access is unavailable."
        }
    }

    private func openCameraPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Camera Preview Layer

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
        previewLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect
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
