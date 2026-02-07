//
//  CameraExtension.swift
//  Droppy
//
//  Self-contained definition for Camera extension
//

import SwiftUI

struct CameraExtension: ExtensionDefinition {
    static let id = "camera"
    static let title = "Camera"
    static let subtitle = "Quick mirror in your notch"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .cyan

    static let description = "Instantly preview your camera in the notch as a quick mirror before joining a call."

    static let features: [(icon: String, text: String)] = [
        ("camera.fill", "Instant live camera preview"),
        ("person.crop.circle", "Front camera by default"),
        ("xmark.circle", "Close any time")
    ]

    static let screenshotURL: URL? = nil
    static let previewView: AnyView? = nil

    static let iconURL: URL? = nil
    static let iconPlaceholder: String = "camera.fill"
    static let iconPlaceholderColor: Color = .cyan

    static func cleanup() {
        CameraManager.shared.cleanup()
    }
}
