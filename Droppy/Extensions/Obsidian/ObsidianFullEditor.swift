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
    @State private var isFrontmatterCollapsed: Bool = true
    @State private var storedFrontmatter: String = ""
    @State private var isSavingNote: Bool = false
    @State private var isSavingViaCLI: Bool = false

    private var canSaveCurrentNote: Bool {
        hasUnsavedChanges
    }

    /// Reconstructs the full note content, prepending stored frontmatter.
    private var fullContent: String {
        storedFrontmatter + editorText
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

            // Collapsible frontmatter section
            if !storedFrontmatter.isEmpty {
                frontmatterSection
            }

            // Editor
            MarkdownEditorView(text: $editorText, scrollToHeading: $scrollToHeading)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
                .onChange(of: editorText) { _, _ in
                    hasUnsavedChanges = (fullContent != manager.currentNoteContent)
                }
                .onChange(of: storedFrontmatter) { _, _ in
                    hasUnsavedChanges = (fullContent != manager.currentNoteContent)
                }
        }
        .padding(8)
        .id(manager.selectedNoteID)
        .animation(DroppyAnimation.smooth(duration: 0.18), value: manager.selectedNoteID)
        .onAppear {
            print("[Obsidian][SaveDebug] fullEditor onAppear note='\(manager.selectedNote?.displayName ?? "nil")'")
            loadEditorContent(manager.currentNoteContent)
        }
        .onChange(of: manager.currentNoteContent) { _, newContent in
            if !hasUnsavedChanges {
                loadEditorContent(newContent)
            }
        }
        .onChange(of: hasUnsavedChanges) { _, newValue in
            print("[Obsidian][SaveDebug] fullEditor hasUnsavedChanges=\(newValue)")
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
                    if isSavingViaCLI {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 10))
                    }
                    Text(isSavingViaCLI ? "Saving..." : "Save")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill((canSaveCurrentNote ? Color.purple : Color.gray).opacity(0.85))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSavingNote)
            .keyboardShortcut("s", modifiers: [.command])
            .help("Save note")
            .zIndex(50)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .zIndex(40)
    }

    private var headingPickerMenu: some View {
        Menu {
            if !manager.currentNoteHeadings.isEmpty {
                ForEach(manager.currentNoteHeadings, id: \.self) { heading in
                    Button {
                        scrollToHeading = heading
                    } label: {
                        Text(ObsidianDisplay.headingDisplayText(heading))
                            .padding(.leading, ObsidianDisplay.headingIndent(heading))
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
                    loadEditorContent(manager.currentNoteContent)
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

    // MARK: - Frontmatter Section

    private var frontmatterSection: some View {
        VStack(spacing: 0) {
            // Toggle banner
            Button {
                withAnimation(DroppyAnimation.smooth(duration: 0.18)) {
                    isFrontmatterCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .rotationEffect(.degrees(isFrontmatterCollapsed ? 0 : 90))
                    Text("frontmatter")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.3))
                    Text("\(frontmatterPropertyCount(storedFrontmatter)) properties")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: isFrontmatterCollapsed ? 6 : 0, style: .continuous))
            }
            .buttonStyle(.plain)

            // Expanded frontmatter content
            if !isFrontmatterCollapsed {
                ScrollView(.vertical, showsIndicators: true) {
                    TextField("", text: $storedFrontmatter, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(red: 202/255, green: 211/255, blue: 245/255).opacity(0.5))
                        .lineLimit(3...)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .frame(maxHeight: 120)
                .background(Color.white.opacity(0.02))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.bottom, 2)
    }

    // MARK: - Frontmatter Helpers

    /// Splits text into (frontmatter block including delimiters + trailing newline, body).
    /// Returns `("", text)` if no frontmatter is found.
    private static func splitFrontmatter(_ text: String) -> (frontmatter: String, body: String) {
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return ("", text)
        }
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                let fmLines = Array(lines[0...i])
                let bodyLines = Array(lines[(i + 1)...])
                let frontmatter = fmLines.joined(separator: "\n") + "\n"
                let body = bodyLines.joined(separator: "\n")
                return (frontmatter, body)
            }
        }
        return ("", text)
    }

    /// Counts lines containing `:` between the `---` delimiters.
    private func frontmatterPropertyCount(_ frontmatter: String) -> Int {
        let lines = frontmatter.components(separatedBy: "\n")
        return lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed != "---" && trimmed.contains(":")
        }.count
    }

    /// Loads content, splitting and collapsing frontmatter.
    private func loadEditorContent(_ content: String) {
        let (fm, body) = Self.splitFrontmatter(content)
        storedFrontmatter = fm
        editorText = body
        isFrontmatterCollapsed = true
        hasUnsavedChanges = false
    }

    // MARK: - Actions

    private func saveNote() {
        guard let note = manager.selectedNote else {
            print("[Obsidian][SaveDebug] saveNote ignored: no selected note")
            return
        }
        print("[Obsidian][SaveDebug] saveNote tapped note='\(note.displayName)' isDaily=\(note.isDaily) hasUnsavedChanges=\(hasUnsavedChanges) canUseCLI=\(manager.canUseCLIBackend) contentChars=\(fullContent.count)")
        guard hasUnsavedChanges else {
            print("[Obsidian][SaveDebug] saveNote ignored: no unsaved changes")
            return
        }
        isSavingNote = true
        isSavingViaCLI = manager.canUseCLIBackend
        Task { @MainActor in
            let success = await manager.writeFullNote(note, content: fullContent)
            if success {
                hasUnsavedChanges = false
                closeNotchAfterSave()
            }
            print("[Obsidian][SaveDebug] saveNote completed success=\(success)")
            isSavingViaCLI = false
            isSavingNote = false
        }
    }

    private func closeNotchAfterSave() {
        withAnimation(DroppyAnimation.smooth) {
            manager.hide()
            DroppyState.shared.expandedDisplayID = nil
            DroppyState.shared.hoveringDisplayID = nil
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
            let textLength = (text as NSString).length
            let safeRanges = selectedRanges.filter { nsValue in
                let range = nsValue.rangeValue
                return NSMaxRange(range) <= textLength
            }
            textView.selectedRanges = safeRanges.isEmpty
                ? [NSValue(range: NSRange(location: 0, length: 0))]
                : safeRanges
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
        private static let mdLinkRegex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)
        private static let frontmatterRegex = try? NSRegularExpression(
            pattern: #"\A---\R.*?\R---[ \t]*(?:\R|$)"#,
            options: [.dotMatchesLineSeparators]
        )
        private static let codeBlockRegex = try? NSRegularExpression(
            pattern: #"(?ms)^(```|~~~)([^\n]*)\n(.*?)^\1[ \t]*$"#,
            options: [.anchorsMatchLines, .dotMatchesLineSeparators]
        )
        private static let inlineCodeRegex = try? NSRegularExpression(pattern: #"(?<!`)`[^`\n]+`(?!`)"#)
        private static let boldAsteriskRegex = try? NSRegularExpression(pattern: #"(?<!\*)\*\*[^*\n]+\*\*(?!\*)"#)
        private static let boldUnderscoreRegex = try? NSRegularExpression(pattern: #"(?<!_)__[^_\n]+__(?!_)"#)
        private static let italicAsteriskRegex = try? NSRegularExpression(pattern: #"(?<!\*)\*[^*\n]+\*(?!\*)"#)
        private static let italicUnderscoreRegex = try? NSRegularExpression(pattern: #"(?<!_)_[^_\n]+_(?!_)"#)
        private static let strikethroughRegex = try? NSRegularExpression(pattern: #"~~[^~\n]+~~"#)
        private static let taskListRegex = try? NSRegularExpression(pattern: #"^(\s*[-*+]\s+\[(?: |x|X)\])\s+.*$"#, options: .anchorsMatchLines)
        private static let listMarkerRegex = try? NSRegularExpression(pattern: #"^(\s*(?:[-*+]|\d+\.)\s+)"#, options: .anchorsMatchLines)
        private static let blockquoteRegex = try? NSRegularExpression(pattern: #"^\s*>\s?.*$"#, options: .anchorsMatchLines)
        private static let calloutRegex = try? NSRegularExpression(pattern: #"^\s*>\s*\[![^\]]+\].*$"#, options: .anchorsMatchLines)
        private static let horizontalRuleRegex = try? NSRegularExpression(pattern: #"^\s{0,3}(?:-{3,}|\*{3,}|_{3,})\s*$"#, options: .anchorsMatchLines)
        private static let tableRowRegex = try? NSRegularExpression(pattern: #"^\s*\|.*\|\s*$"#, options: .anchorsMatchLines)
        private static let tableSeparatorRegex = try? NSRegularExpression(
            pattern: #"^\s*\|?(?:\s*:?-+:?\s*\|)+\s*:?-+:?\s*\|?\s*$"#,
            options: .anchorsMatchLines
        )
        private static let footnoteDefRegex = try? NSRegularExpression(pattern: #"^\[\^[^\]]+\]:\s+.*$"#, options: .anchorsMatchLines)
        private static let footnoteRefRegex = try? NSRegularExpression(pattern: #"\[\^[^\]]+\]"#)
        private static let tagRegex = try? NSRegularExpression(pattern: #"(?<![A-Za-z0-9_])#[A-Za-z][\w/-]*"#)
        private static let metadataRegex = try? NSRegularExpression(pattern: #"^([A-Za-z0-9_-]+::)(\s+.*)?$"#, options: .anchorsMatchLines)
        private static let codeCommentRegex = try? NSRegularExpression(pattern: #"(?m)//.*$|#.*$|/\*[\s\S]*?\*/"#)
        private static let codeDoubleQuotedStringRegex = try? NSRegularExpression(pattern: #""(?:\\.|[^"\\])*""#)
        private static let codeSingleQuotedStringRegex = try? NSRegularExpression(pattern: #"'(?:\\.|[^'\\])*'"#)
        private static let codeNumberRegex = try? NSRegularExpression(pattern: #"\b\d+(?:\.\d+)?\b"#)
        private static let swiftKeywordRegex = try? NSRegularExpression(
            pattern: #"\b(class|struct|enum|protocol|extension|func|var|let|if|else|guard|switch|case|for|while|return|async|await|throws|throw|import|public|private|internal|fileprivate|open|actor|init|deinit|inout|where|some)\b"#
        )
        private static let jsTsKeywordRegex = try? NSRegularExpression(
            pattern: #"\b(function|const|let|var|if|else|switch|case|for|while|return|class|extends|new|import|export|default|async|await|try|catch|finally|throw|interface|type|implements|enum)\b"#
        )
        private static let pythonKeywordRegex = try? NSRegularExpression(
            pattern: #"\b(def|class|if|elif|else|for|while|return|import|from|as|try|except|finally|raise|with|lambda|yield|pass|break|continue|async|await|match|case|True|False|None)\b"#
        )
        private static let shellKeywordRegex = try? NSRegularExpression(
            pattern: #"\b(if|then|else|fi|for|in|do|done|case|esac|while|function|export|local|readonly)\b"#
        )

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

            let defaultColor = NSColor(red: 202/255, green: 211/255, blue: 245/255, alpha: 1)
            let accentColor = NSColor.systemPurple
            let urlColor = NSColor.systemBlue
            let codeColor = NSColor.systemGreen.withAlphaComponent(0.82)
            let dimmedColor = NSColor(red: 202/255, green: 211/255, blue: 245/255, alpha: 0.5)
            let inlineCodeBackground = NSColor.systemGreen.withAlphaComponent(0.16)

            var blockedRanges: [NSRange] = []

            // Frontmatter: only highlight when a bounded block exists at file start.
            if let regex = Self.frontmatterRegex,
               let match = regex.firstMatch(in: text, range: fullRange),
               match.range.location == 0 {
                storage.addAttribute(.foregroundColor, value: dimmedColor, range: match.range)
                blockedRanges.append(match.range)

                if let metadataRegex = Self.metadataRegex {
                    for metadataMatch in metadataRegex.matches(in: text, range: match.range) {
                        guard metadataMatch.numberOfRanges > 1 else { continue }
                        let keyRange = metadataMatch.range(at: 1)
                        guard keyRange.location != NSNotFound else { continue }
                        storage.addAttribute(.foregroundColor, value: NSColor.systemOrange.withAlphaComponent(0.85), range: keyRange)
                    }
                }
            }

            // Fenced code blocks: support ``` and ~~~, with language-aware token highlighting.
            if let codeRegex = Self.codeBlockRegex {
                for blockMatch in codeRegex.matches(in: text, range: fullRange) {
                    let blockRange = blockMatch.range
                    blockedRanges.append(blockRange)
                    storage.addAttribute(.foregroundColor, value: codeColor, range: blockRange)

                    let openingFenceRange = blockMatch.range(at: 1)
                    let languageRange = blockMatch.range(at: 2)
                    let bodyRange = blockMatch.range(at: 3)

                    storage.addAttribute(.foregroundColor, value: NSColor.systemGray, range: openingFenceRange)
                    if languageRange.location != NSNotFound, languageRange.length > 0 {
                        storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: languageRange)
                    }
                    if bodyRange.location != NSNotFound {
                        let closingFenceRange = NSRange(
                            location: NSMaxRange(bodyRange),
                            length: max(0, NSMaxRange(blockRange) - NSMaxRange(bodyRange))
                        )
                        if closingFenceRange.length > 0 {
                            storage.addAttribute(.foregroundColor, value: NSColor.systemGray, range: closingFenceRange)
                        }
                    }

                    if bodyRange.location != NSNotFound, bodyRange.length > 0 {
                        if let regex = Self.codeCommentRegex {
                            applyRegex(regex, color: NSColor.systemGray.withAlphaComponent(0.92), in: bodyRange, storage: storage)
                        }
                        if let regex = Self.codeDoubleQuotedStringRegex {
                            applyRegex(regex, color: NSColor.systemYellow.withAlphaComponent(0.95), in: bodyRange, storage: storage)
                        }
                        if let regex = Self.codeSingleQuotedStringRegex {
                            applyRegex(regex, color: NSColor.systemYellow.withAlphaComponent(0.95), in: bodyRange, storage: storage)
                        }
                        if let regex = Self.codeNumberRegex {
                            applyRegex(regex, color: NSColor.systemTeal.withAlphaComponent(0.95), in: bodyRange, storage: storage)
                        }
                        let languageHint = languageRange.location != NSNotFound
                            ? (text as NSString).substring(with: languageRange)
                            : ""
                        if let keywordRegex = keywordRegex(for: languageHint) {
                            applyRegex(keywordRegex, color: NSColor.systemPink.withAlphaComponent(0.95), in: bodyRange, storage: storage)
                            storage.addAttribute(
                                .font,
                                value: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                                range: bodyRange
                            )
                        }
                    }
                }
            }

            // Inline code spans before emphasis to keep their styling stable.
            var inlineCodeRanges: [NSRange] = []
            if let inlineRegex = Self.inlineCodeRegex {
                for match in inlineRegex.matches(in: text, range: fullRange) {
                    guard !range(match.range, overlapsAny: blockedRanges) else { continue }
                    inlineCodeRanges.append(match.range)
                    storage.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: match.range)
                    storage.addAttribute(.backgroundColor, value: inlineCodeBackground, range: match.range)
                }
            }

            let blockedAndInline = blockedRanges + inlineCodeRanges

            // Headings: bold + white
            if let regex = Self.headingRegex {
                for match in regex.matches(in: text, range: fullRange) {
                    guard !range(match.range, overlapsAny: blockedAndInline) else { continue }
                    storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold), range: match.range)
                    storage.addAttribute(.foregroundColor, value: NSColor.white, range: match.range)
                }
            }

            // Wikilinks: [[...]]
            if let regex = Self.wikilinkRegex {
                for match in regex.matches(in: text, range: fullRange) {
                    guard !range(match.range, overlapsAny: blockedAndInline) else { continue }
                    storage.addAttribute(.foregroundColor, value: accentColor, range: match.range)
                }
            }

            // Markdown links: style text and URL separately.
            if let regex = Self.mdLinkRegex {
                for match in regex.matches(in: text, range: fullRange) {
                    guard !range(match.range, overlapsAny: blockedAndInline) else { continue }
                    storage.addAttribute(.foregroundColor, value: accentColor.withAlphaComponent(0.95), range: match.range(at: 1))
                    storage.addAttribute(.foregroundColor, value: urlColor.withAlphaComponent(0.95), range: match.range(at: 2))
                    storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range(at: 2))
                }
            }

            // Emphasis tokens.
            applyRegex(Self.boldAsteriskRegex, color: defaultColor, in: fullRange, storage: storage, blocked: blockedAndInline) {
                storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold), range: $0)
            }
            applyRegex(Self.boldUnderscoreRegex, color: defaultColor, in: fullRange, storage: storage, blocked: blockedAndInline) {
                storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold), range: $0)
            }
            applyRegex(Self.italicAsteriskRegex, color: defaultColor, in: fullRange, storage: storage, blocked: blockedAndInline) {
                storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .light), range: $0)
            }
            applyRegex(Self.italicUnderscoreRegex, color: defaultColor, in: fullRange, storage: storage, blocked: blockedAndInline) {
                storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .light), range: $0)
            }
            applyRegex(Self.strikethroughRegex, color: NSColor.systemRed.withAlphaComponent(0.9), in: fullRange, storage: storage, blocked: blockedAndInline) {
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: $0)
            }

            // Lists and tasks.
            if let regex = Self.listMarkerRegex {
                for match in regex.matches(in: text, range: fullRange) {
                    let markerRange = match.range(at: 1)
                    guard markerRange.location != NSNotFound, !range(markerRange, overlapsAny: blockedAndInline) else { continue }
                    storage.addAttribute(.foregroundColor, value: NSColor.systemBlue.withAlphaComponent(0.9), range: markerRange)
                }
            }
            if let regex = Self.taskListRegex {
                for match in regex.matches(in: text, range: fullRange) {
                    let markerRange = match.range(at: 1)
                    guard markerRange.location != NSNotFound, !range(markerRange, overlapsAny: blockedAndInline) else { continue }
                    let markerText = (text as NSString).substring(with: markerRange)
                    let markerColor = markerText.contains("[x]") || markerText.contains("[X]")
                        ? NSColor.systemGreen.withAlphaComponent(0.95)
                        : NSColor.systemOrange.withAlphaComponent(0.95)
                    storage.addAttribute(.foregroundColor, value: markerColor, range: markerRange)
                }
            }

            // Quotes, callouts, and horizontal rules.
            applyRegex(Self.blockquoteRegex, color: NSColor.systemCyan.withAlphaComponent(0.75), in: fullRange, storage: storage, blocked: blockedAndInline)
            applyRegex(Self.calloutRegex, color: NSColor.systemIndigo.withAlphaComponent(0.95), in: fullRange, storage: storage, blocked: blockedAndInline) {
                storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold), range: $0)
            }
            applyRegex(Self.horizontalRuleRegex, color: NSColor.systemGray.withAlphaComponent(0.9), in: fullRange, storage: storage, blocked: blockedAndInline)

            // Tables + footnotes.
            applyRegex(Self.tableRowRegex, color: NSColor.systemTeal.withAlphaComponent(0.88), in: fullRange, storage: storage, blocked: blockedAndInline)
            applyRegex(Self.tableSeparatorRegex, color: NSColor.systemTeal.withAlphaComponent(0.98), in: fullRange, storage: storage, blocked: blockedAndInline)
            applyRegex(Self.footnoteDefRegex, color: NSColor.systemOrange.withAlphaComponent(0.9), in: fullRange, storage: storage, blocked: blockedAndInline)
            applyRegex(Self.footnoteRefRegex, color: NSColor.systemOrange.withAlphaComponent(0.95), in: fullRange, storage: storage, blocked: blockedAndInline)

            // Obsidian tags + metadata lines.
            applyRegex(Self.tagRegex, color: NSColor.systemPink.withAlphaComponent(0.95), in: fullRange, storage: storage, blocked: blockedAndInline)
            if let regex = Self.metadataRegex {
                for match in regex.matches(in: text, range: fullRange) {
                    guard !range(match.range, overlapsAny: blockedAndInline), match.numberOfRanges > 1 else { continue }
                    let keyRange = match.range(at: 1)
                    guard keyRange.location != NSNotFound else { continue }
                    storage.addAttribute(.foregroundColor, value: NSColor.systemOrange.withAlphaComponent(0.9), range: keyRange)
                }
            }

            storage.endEditing()
        }

        private func applyRegex(
            _ regex: NSRegularExpression?,
            color: NSColor,
            in searchRange: NSRange,
            storage: NSTextStorage,
            blocked: [NSRange] = [],
            extraAttributes: ((NSRange) -> Void)? = nil
        ) {
            guard let regex else { return }
            for match in regex.matches(in: storage.string, range: searchRange) {
                guard !range(match.range, overlapsAny: blocked) else { continue }
                storage.addAttribute(.foregroundColor, value: color, range: match.range)
                extraAttributes?(match.range)
            }
        }

        private func range(_ range: NSRange, overlapsAny blockedRanges: [NSRange]) -> Bool {
            guard range.location != NSNotFound, range.length > 0 else { return false }
            return blockedRanges.contains { NSIntersectionRange($0, range).length > 0 }
        }

        private func keywordRegex(for languageHint: String) -> NSRegularExpression? {
            let normalized = languageHint
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ")
                .first?
                .lowercased() ?? ""
            switch normalized {
            case "swift":
                return Self.swiftKeywordRegex
            case "js", "jsx", "javascript", "ts", "tsx", "typescript":
                return Self.jsTsKeywordRegex
            case "py", "python":
                return Self.pythonKeywordRegex
            case "sh", "bash", "zsh", "shell":
                return Self.shellKeywordRegex
            default:
                return nil
            }
        }
    }
}
