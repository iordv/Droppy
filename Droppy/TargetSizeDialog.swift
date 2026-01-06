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
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @State private var targetSizeMB: String = ""
    @State private var dashPhase: CGFloat = 0
    @State private var hoverLocation: CGPoint = .zero
    @State private var isBgHovering: Bool = false
    @State private var isCompressButtonHovering = false
    @State private var isCancelButtonHovering = false
    @State private var inputDashPhase: CGFloat = 0
    
    private let cornerRadius: CGFloat = 24
    
    var body: some View {
        ZStack {
            // Background with hexagon effect
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(useTransparentBackground ? Color.clear : Color.black)
                .background {
                    if useTransparentBackground {
                        Color.clear
                            .liquidGlass(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
                .overlay {
                    HexagonDotsEffect(
                        mouseLocation: hoverLocation,
                        isHovering: isBgHovering,
                        coordinateSpaceName: "compressDialog"
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.2),
                            style: StrokeStyle(
                                lineWidth: 1.5,
                                lineCap: .round,
                                dash: [6, 8],
                                dashPhase: dashPhase
                            )
                        )
                        .padding(12)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
            
            // Content
            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue.gradient)
                    
                    VStack(alignment: .leading) {
                        Text("Compress File")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(fileName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                
                // Current size info
                HStack {
                    Text("Current Size:")
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text(FileCompressor.formatSize(currentSize))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                // Target size input - using same style as rename text field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Size (MB)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    HStack(spacing: 8) {
                        // Text field with animated dotted border (same as rename)
                        TargetSizeTextField(
                            text: $targetSizeMB,
                            onSubmit: compress,
                            onCancel: onCancel
                        )
                        .frame(width: 200)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.black.opacity(0.3))
                        )
                        // Animated dotted blue outline (same as rename)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    Color.accentColor.opacity(0.8),
                                    style: StrokeStyle(
                                        lineWidth: 1.5,
                                        lineCap: .round,
                                        dash: [3, 3],
                                        dashPhase: inputDashPhase
                                    )
                                )
                        )
                        
                        Text("MB")
                            .foregroundStyle(.white.opacity(0.6))
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                
                // Buttons
                HStack(spacing: 12) {
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(isCancelButtonHovering ? 0.25 : 0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isCancelButtonHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isCancelButtonHovering = isHovering
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        compress()
                    } label: {
                        Text("Compress")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(isCompressButtonHovering ? 1.0 : 0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isCompressButtonHovering)
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isCompressButtonHovering = isHovering
                        }
                    }
                    .disabled(targetBytes == nil || targetBytes! >= currentSize)
                    .opacity(targetBytes == nil || targetBytes! >= currentSize ? 0.5 : 1.0)
                }
            }
            .padding(24)
        }
        .frame(width: 340, height: 290)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background(Color.clear)
        .coordinateSpace(name: "compressDialog")
        .onContinuousHover(coordinateSpace: .named("compressDialog")) { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
                isBgHovering = true
            case .ended:
                isBgHovering = false
            }
        }
        .onAppear {
            // Animate dashed borders
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                dashPhase -= 280
            }
            withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                inputDashPhase = 6
            }
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
        textField.textColor = .white
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
            
            let windowWidth: CGFloat = 340
            let windowHeight: CGFloat = 290
            
            // Use custom CompressPanel that can become key (like BasketPanel)
            let panel = CompressPanel(
                contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false // We handle shadow in SwiftUI
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isMovableByWindowBackground = true
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = false
            panel.animationBehavior = .none
            panel.isReleasedWhenClosed = false
            
            // Create SwiftUI hosting view
            let hostingView = NSHostingView(rootView: dialogView)
            hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
            
            // CRITICAL: Make hosting view layer-backed and fully transparent
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear
            
            panel.contentView = hostingView
            
            // Center on screen
            if let screen = NSScreen.main {
                let screenFrame = screen.frame
                let x = (screenFrame.width - windowWidth) / 2
                let y = (screenFrame.height - windowHeight) / 2
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            self.window = panel
            panel.makeKeyAndOrderFront(nil)
            
            // Make window accept key events
            NSApp.activate(ignoringOtherApps: true)
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

