import SwiftUI
import AppKit

struct RenameWindowView: View {
    @State var text: String
    var originalText: String
    var onRename: (String) -> Void
    var onCancel: () -> Void
    
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var isHoveringCancel = false
    @State private var isHoveringSave = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Text field
                RenameAutoSelectTextField(
                    text: $text,
                    onSubmit: {
                        onRename(text)
                    }
                )
                .font(.system(size: 14, weight: .medium))
                .droppyTextInputChrome(
                    cornerRadius: DroppyRadius.ml,
                    horizontalPadding: DroppySpacing.md,
                    verticalPadding: DroppySpacing.md
                )
                
                // Buttons - matching DroppyAlertView style exactly (secondary left, spacer, primary right)
                HStack(spacing: 8) {
                    // Cancel button - secondary style (left side)
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    Spacer()
                    
                    // Save button - primary accent style (right side)
                    Button {
                        onRename(text)
                    } label: {
                        Text("Save")
                    }
                    .buttonStyle(DroppyAccentButtonStyle(color: .accentColor, size: .small))
                    .keyboardShortcut(.return, modifiers: [])
                }
                .padding(.top, 16)
            }
            .padding(DroppySpacing.lg)
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous)
                .stroke(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
        )
    }
}

// MARK: - Rename Auto-Select Text Field

/// NSTextField wrapper that auto-selects text ONCE on initial focus
private struct RenameAutoSelectTextField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.stringValue = text
        textField.font = .systemFont(ofSize: 14, weight: .medium)
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.delegate = context.coordinator
        textField.cell?.usesSingleLineMode = true
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        
        // Schedule auto-select and focus after a brief delay to ensure window is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            textField.window?.makeFirstResponder(textField)
            textField.selectText(nil)
            // Mark as ready for submission after selection is complete
            context.coordinator.isReady = true
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update if text changed externally (not from typing)
        // This prevents overwriting user input
        if !context.coordinator.isEditing && nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: RenameAutoSelectTextField
        var isReady = false
        var isEditing = false
        
        init(_ parent: RenameAutoSelectTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func controlTextDidBeginEditing(_ obj: Notification) {
            isEditing = true
            // Do NOT select text here - it causes repeated selection on every keystroke
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
            // Do NOT auto-submit on end editing - user may have clicked outside
            // Submission should only happen via Enter key or Save button
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if isReady {
                    parent.onSubmit()
                }
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Escape is handled by the button keyboard shortcut
                return false
            }
            return false
        }
    }
}
