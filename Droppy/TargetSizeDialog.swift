//
//  TargetSizeDialog.swift
//  Droppy
//
//  Created by Jordy Spruit on 03/01/2026.
//

import SwiftUI
import AppKit

/// A dialog for entering a target file size for compression
struct TargetSizeDialogView: View {
    let currentSize: Int64
    let fileName: String
    let onCompress: (Int64) -> Void
    let onCancel: () -> Void
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var targetSizeMB: String = ""
    @State private var isCompressButtonHovering = false
    @State private var isCancelButtonHovering = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Compress File")
                        .font(.headline)
                    Text(fileName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(DroppySpacing.lg)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Content
            VStack(spacing: 16) {
                // Current size info
                HStack {
                    Text("Current Size")
                    Spacer()
                    Text(FileCompressor.formatSize(currentSize))
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                
                // Target size input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Size")
                        .font(.subheadline)
                    
                    HStack(spacing: 8) {
                        TargetSizeTextField(
                            text: $targetSizeMB,
                            onSubmit: compress,
                            onCancel: onCancel
                        )
                        .frame(width: 120)
                        .droppyTextInputChrome(
                            cornerRadius: DroppyRadius.ml,
                            horizontalPadding: 12,
                            verticalPadding: 8
                        )
                        
                        Text("MB")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }
            .padding(DroppySpacing.mdl)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Action buttons
            HStack(spacing: 10) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
                
                Spacer()
                
                Button {
                    compress()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                        Text("Compress")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                .disabled(targetBytes == nil || targetBytes! >= currentSize)
                .opacity(targetBytes == nil || targetBytes! >= currentSize ? 0.5 : 1.0)
            }
            .padding(DroppySpacing.mdl)
        }
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .droppyTransparentBackground(useTransparentBackground)
        .onAppear {
            // Default to 50% of current size
            let suggestedMB = Double(currentSize) / (1024 * 1024) / 2
            targetSizeMB = String(format: "%.1f", suggestedMB)
        }
    }
    
    private var targetBytes: Int64? {
        guard let mb = Double(targetSizeMB.replacingOccurrences(of: ",", with: ".")),
              mb > 0 else {
            return nil
        }
        return Int64(mb * 1024 * 1024)
    }
    
    private func compress() {
        guard let bytes = targetBytes else { return }
        onCompress(bytes)
    }
}

// MARK: - Target Size Text Field (same as AutoSelectTextField from rename)

private struct TargetSizeTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.backgroundColor = .clear
        textField.textColor = NSColor.labelColor
        textField.font = .systemFont(ofSize: 16, weight: .medium)
        textField.alignment = .left
        textField.focusRingType = .none
        textField.stringValue = text
        
        // Make it the first responder and select all text after a brief delay
        // For non-activating panels, we need special handling to make them accept keyboard input
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = textField.window as? NSPanel else { return }
            
            // Temporarily allow the panel to become key window
            window.becomesKeyOnlyIfNeeded = false
            
            // CRITICAL: Activate the app itself - this is what makes the selection blue vs grey
            NSApp.activate(ignoringOtherApps: true)
            
            // Make the window key and order it front to accept keyboard input
            window.makeKeyAndOrderFront(nil)
            
            // Now make the text field first responder
            window.makeFirstResponder(textField)
            
            // Select all text
            textField.selectText(nil)
            if let editor = textField.currentEditor() {
                editor.selectedRange = NSRange(location: 0, length: textField.stringValue.count)
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if text changed externally
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: TargetSizeTextField
        
        init(_ parent: TargetSizeTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Enter pressed - submit
                parent.onSubmit()
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Escape pressed - cancel
                parent.onCancel()
                return true
            }
            return false
        }
    }
}

/// Window controller for showing the target size dialog
class TargetSizeDialogController {
    static let shared = TargetSizeDialogController()
    
    private var window: NSWindow?
    private var continuation: CheckedContinuation<Int64?, Never>?
    
    private init() {}
    
    /// Shows the dialog and returns the target size in bytes, or nil if cancelled
    @MainActor
    func show(currentSize: Int64, fileName: String) async -> Int64? {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            
            let dialogView = TargetSizeDialogView(
                currentSize: currentSize,
                fileName: fileName,
                onCompress: { [weak self] bytes in
                    self?.dismiss(result: bytes)
                },
                onCancel: { [weak self] in
                    self?.dismiss(result: nil)
                }
            )
            
            let hostingView = NSHostingView(rootView: dialogView)
            
            // Use custom CompressPanel that can become key (like BasketPanel)
            let panel = CompressPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 240),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            panel.center()
            panel.title = "Compress File"
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .visible
            
            panel.isMovableByWindowBackground = false
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.isReleasedWhenClosed = false
            panel.level = .screenSaver
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = false
            
            panel.contentView = hostingView
            
            self.window = panel
            
            // Use deferred makeKey to avoid NotchWindow conflicts
            panel.orderFront(nil)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                panel.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    private func dismiss(result: Int64?) {
        window?.close()
        window = nil
        continuation?.resume(returning: result)
        continuation = nil
    }
}

// MARK: - Custom Panel Class (like BasketPanel)
class CompressPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
