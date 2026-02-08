//
//  CopiedTextToastWindowController.swift
//  Droppy
//
//  Bottom-right toast feedback for copied text results (OCR/transcription).
//

import SwiftUI
import AppKit

@MainActor
final class CopiedTextToastWindowController {
    static let shared = CopiedTextToastWindowController()

    private var window: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    func show(title: String, subtitle: String, symbolName: String) {
        dismissWorkItem?.cancel()

        if let existing = window {
            existing.orderOut(nil)
            existing.close()
            window = nil
        }

        let contentSize = NSSize(width: 320, height: 94)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = NSHostingView(
            rootView: CopiedTextToastView(
                title: title,
                subtitle: subtitle,
                symbolName: symbolName
            )
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.maxX - contentSize.width - 20
            let y = frame.minY + 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        window = panel

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.dismiss()
            }
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private func dismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        guard let panel = window else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let currentWindow = self.window else { return }
                currentWindow.orderOut(nil)
                currentWindow.close()
                self.window = nil
            }
        })
    }
}

private struct CopiedTextToastView: View {
    let title: String
    let subtitle: String
    let symbolName: String

    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.1), lineWidth: 1)
        )
    }
}

enum TextCopyFeedback {
    static func copyOCRText(_ text: String) {
        Task { @MainActor in
            copyToClipboard(text)
            CopiedTextToastWindowController.shared.show(
                title: "Text Copied",
                subtitle: "Extracted text copied to clipboard",
                symbolName: "text.viewfinder"
            )
        }
    }

    static func copyTranscriptionText(_ text: String) {
        Task { @MainActor in
            copyToClipboard(text)
            CopiedTextToastWindowController.shared.show(
                title: "Transcription Copied",
                subtitle: "Text copied to clipboard",
                symbolName: "waveform.and.mic"
            )
        }
    }

    @MainActor
    private static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        HapticFeedback.copy()
    }
}
