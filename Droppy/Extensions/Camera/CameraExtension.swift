//
//  CameraExtension.swift
//  Droppy
//
//  Self-contained definition for Snap! Camera extension.
//

import SwiftUI

struct CameraExtension: ExtensionDefinition {
    static let id = "camera"
    static let title = "Snap! Camera"
    static let subtitle = "Live notch camera preview"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .cyan

    static let description = "Adds a floating camera button below the shelf. Open it for a full live front-camera preview with balanced notch padding."

    static let features: [(icon: String, text: String)] = [
        ("camera.fill", "Floating Snap! Camera button below the shelf"),
        ("rectangle.inset.filled", "Full preview mode with aligned notch padding"),
        ("bolt.fill", "Low-latency startup with smooth transitions")
    ]

    static let screenshotURL: URL? = nil
    static let previewView: AnyView? = nil

    static let iconURL: URL? = URL(string: "https://getdroppy.app/assets/icons/snap-camera-v2.png")
    static let iconPlaceholder: String = "camera.fill"
    static let iconPlaceholderColor: Color = .cyan

    static let isCommunity = false

    static func cleanup() {
        CameraManager.shared.cleanup()
    }
}
