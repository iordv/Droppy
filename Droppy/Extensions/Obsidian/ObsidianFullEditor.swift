//
//  ObsidianFullEditor.swift
//  Droppy
//
//  Syntax-highlighted markdown editor for full note editing
//

import SwiftUI
import AppKit

struct ObsidianFullEditor: View {
    var manager: ObsidianManager

    @State private var editorText: String = ""
    @State private var hasUnsavedChanges: Bool = false
    @State private var scrollToHeading: String?

    private var canSaveCurrentNote: Bool {
        hasUnsavedChanges && manager.selectedNote?.isDaily != true
    }

    private var headingMenuTitle: String {
        manager.currentNoteHeadings.isEmpty ? "No headings" : "Jump to heading"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            // External change banner
            if manager.hasExternalChanges {
                externalChangeBanner
            }

            // Editor
            MarkdownEditorView(text: $editorText, scrollToHeading: $scrollToHeading)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
                .onChange(of: editorText) { _, newValue in
                    hasUnsavedChanges = (newValue != manager.currentNoteContent)
                }
        }
        .padding(8)
        .id(manager.selectedNoteID)
        .animation(DroppyAnimation.smooth(duration: 0.18), value: manager.selectedNoteID)
        .onAppear {
            editorText = manager.currentNoteContent
        }
        .onChange(of: manager.currentNoteContent) { _, newContent in
            if !hasUnsavedChanges {
                editorText = newContent
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            // Heading picker menu
            headingPickerMenu

            Spacer()

            Button {
                saveNote()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 10))
                    Text("Save")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(DroppyAccentButtonStyle(color: canSaveCurrentNote ? .purple : .gray, size: .small))
            .disabled(!canSaveCurrentNote)
            .help(manager.selectedNote?.isDaily == true ? "Daily notes support append/prepend instead of full save." : "Save note")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
    }

    private var headingPickerMenu: some View {
        Menu {
            if !manager.currentNoteHeadings.isEmpty {
                ForEach(manager.currentNoteHeadings, id: \.self) { heading in
                    Button {
                        scrollToHeading = heading
                    } label: {
                        Text(heading)
                    }
                }
            } else {
                Text("No headings")
                    .foregroundStyle(.secondary)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "number")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.purple.opacity(0.8))
                Text(headingMenuTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                if let noteName = manager.selectedNote?.displayName {
                    Text(noteName)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.sm, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - External Change Banner

    private var externalChangeBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            Text("File changed externally")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Button("Reload") {
                Task { @MainActor in
                    await manager.reloadCurrentNote()
                    editorText = manager.currentNoteContent
                    hasUnsavedChanges = false
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.blue)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .padding(.bottom, 4)
    }

    // MARK: - Actions

    private func saveNote() {
        guard let note = manager.selectedNote else { return }
        Task { @MainActor in
            let success = await manager.writeFullNote(note, content: editorText)
            if success { hasUnsavedChanges = false }
        }
    }
}

// MARK: - Markdown Editor (NSTextView wrapper)

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var scrollToHeading: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = NSColor(red: 202/255, green: 211/255, blue: 245/255, alpha: 1)
        textView.backgroundColor = NSColor(red: 36/255, green: 39/255, blue: 58/255, alpha: 1)
        textView.insertionPointColor = .white
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.delegate = context.coordinator
        textView.string = text

        // Enable auto-sizing to fill scroll view width
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        context.coordinator.textView = textView

        // Initial highlight
        context.coordinator.applyHighlighting()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyHighlighting()
        }

        // Scroll to heading if requested
        if let heading = scrollToHeading {
            let nsString = textView.string as NSString
            let range = nsString.range(of: heading)
            if range.location != NSNotFound {
                textView.scrollRangeToVisible(range)
                textView.setSelectedRange(range)
            }
            DispatchQueue.main.async {
                self.scrollToHeading = nil
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditorView
        weak var textView: NSTextView?
        private var highlightWorkItem: DispatchWorkItem?

        // Pre-compiled regexes for performance
        private static let headingRegex = try? NSRegularExpression(pattern: #"^#{1,6}\s+.+$"#, options: .anchorsMatchLines)
        private static let wikilinkRegex = try? NSRegularExpression(pattern: #"\[\[.*?\]\]"#)
        private static let mdLinkRegex = try? NSRegularExpression(pattern: #"\[.*?\]\(.*?\)"#)
        private static let codeBlockRegex = try? NSRegularExpression(pattern: #"```[\s\S]*?```"#, options: .dotMatchesLineSeparators)

        init(_ parent: MarkdownEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string

            // Debounce highlighting for large documents (>5KB)
            if textView.string.utf8.count > 5000 {
                highlightWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    self?.applyHighlighting()
                }
                highlightWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
            } else {
                applyHighlighting()
            }
        }

        func applyHighlighting() {
            guard let textView else { return }
            let text = textView.string
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            guard fullRange.length > 0 else { return }
            let storage = textView.textStorage!

            storage.beginEditing()

            // Reset to default
            storage.addAttribute(.foregroundColor, value: NSColor(red: 202/255, green: 211/255, blue: 245/255, alpha: 1), range: fullRange)
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), range: fullRange)

            let nsText = text as NSString

            // Headings: Bold
            if let regex = Self.headingRegex {
                for match in regex.matches(in: text, range: fullRange) {
                    storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold), range: match.range)
                    storage.addAttribute(.foregroundColor, value: NSColor.white, range: match.range)
                }
            }

            // Wikilinks: [[...]] — accent color
            if let regex = Self.wikilinkRegex {
                for match in regex.matches(in: text, range: fullRange) {
                    storage.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: match.range)
                }
            }

            // Markdown links: [...](...) — accent color
            if let regex = Self.mdLinkRegex {
                for match in regex.matches(in: text, range: fullRange) {
                    storage.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: match.range)
                }
            }

            // Frontmatter: between --- at file start — dimmed
            if nsText.hasPrefix("---") {
                let closingRange = nsText.range(of: "---", options: [], range: NSRange(location: 3, length: max(0, nsText.length - 3)))
                if closingRange.location != NSNotFound {
                    let fmRange = NSRange(location: 0, length: NSMaxRange(closingRange))
                    storage.addAttribute(.foregroundColor, value: NSColor(red: 202/255, green: 211/255, blue: 245/255, alpha: 0.5), range: fmRange)
                }
            }

            // Code blocks: ``` ... ``` — monospace, subtle
            if let regex = Self.codeBlockRegex {
                for match in regex.matches(in: text, range: fullRange) {
                    storage.addAttribute(.foregroundColor, value: NSColor.systemGreen.withAlphaComponent(0.8), range: match.range)
                }
            }

            storage.endEditing()
        }
    }
}
