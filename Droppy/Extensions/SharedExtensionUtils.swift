//
//  SharedExtensionUtils.swift
//  Droppy
//
//  Shared utilities for extensions to maintain consistency and reduce duplication.
//

import SwiftUI
import AppKit

// MARK: - Image Resizing

extension NSImage {
    /// Resize image to target size while maintaining aspect ratio or fitting
    /// - Parameter targetSize: The size to resize to
    /// - Returns: A new resized NSImage
    func resized(to targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: targetSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

// MARK: - Accessibility Helper

struct AccessibilityUtils {
    /// Check if the app has Accessibility permissions
    /// - Parameter prompt: Whether to show system prompt if not trusted
    /// - Returns: True if trusted
    static func isTrusted(prompt: Bool = false) -> Bool {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
