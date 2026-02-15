//
//  ObsidianQuickPanel.swift
//  Droppy
//
//  Compact panel for heading selection, text input, and append/prepend actions
//

import SwiftUI
import AppKit

struct ObsidianQuickPanel: View {
    @Bindable var manager: ObsidianManager

    @FocusState private var isInputFocused: Bool
    @State private var focusRequestToken = UUID()

    var body: some View {
        VStack(spacing: 6) {
            // Row 1: Heading picker
            headingPicker

            // Row 2: Text input
            textInput

            // Row 3: Action buttons
            actionBar
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .onAppear { requestInputFocus() }
        .onChange(of: manager.isQuickPanelExpanded) { _, expanded in
            if expanded {
                requestInputFocus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            requestInputFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            requestInputFocus()
        }
        .onDisappear { cancelFocusRequests() }
    }

    // MARK: - Focus Helpers

    /// Retry focus at staggered delays to handle animation timing and key-window races.
    private func requestInputFocus() {
        guard manager.isVisible, manager.isQuickPanelExpanded else { return }
        let token = UUID()
        focusRequestToken = token

        for delay in [0, 60, 160, 320] {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) { [self] in
                guard focusRequestToken == token else { return }
                guard manager.isVisible, manager.isQuickPanelExpanded else { return }
                isInputFocused = false
                DispatchQueue.main.async {
                    guard manager.isVisible, manager.isQuickPanelExpanded else { return }
                    isInputFocused = true
                }
            }
        }
    }

    private func cancelFocusRequests() {
        focusRequestToken = UUID()
    }

    // MARK: - Heading Picker

    private var headingPicker: some View {
        Menu {
            Button {
                manager.setSelectedHeading(nil)
            } label: {
                Label("Entire note", systemImage: "doc.text")
            }

            if !manager.currentNoteHeadings.isEmpty {
                Divider()
                ForEach(manager.currentNoteHeadings, id: \.self) { heading in
                    Button {
                        manager.setSelectedHeading(heading)
                    } label: {
                        Text(heading)
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "number")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                Text(manager.selectedHeading ?? "Entire note")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Text Input

    private var textInput: some View {
        ZStack(alignment: .topLeading) {
            if manager.inputText.isEmpty {
                Text("Type to append or prepend...")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.top, 1)
                    .allowsHitTesting(false)
            }

            TextField("", text: $manager.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 202/255, green: 211/255, blue: 245/255))
                .lineLimit(2...3)
                .focused($isInputFocused)
                .onSubmit {
                    performLastAction()
                }
                .onChange(of: isInputFocused) { _, focused in
                    manager.isEditingText = focused
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 36/255, green: 39/255, blue: 58/255))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 6) {
            // Prepend button
            Button {
                manager.lastUsedAction = .prepend
                performLastAction()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 10))
                    Text("Prepend")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(DroppyAccentButtonStyle(
                color: manager.lastUsedAction == .prepend ? .purple : .gray,
                size: .small
            ))

            // Append button
            Button {
                manager.lastUsedAction = .append
                performLastAction()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 10))
                    Text("Append")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(DroppyAccentButtonStyle(
                color: manager.lastUsedAction == .append ? .purple : .gray,
                size: .small
            ))

            Spacer()

            // Success indicator
            if manager.showSuccessFlash {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }

            // Expand to full editor
            Button {
                withAnimation(DroppyAnimation.smooth) {
                    manager.enterFullEditor()
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .animation(DroppyAnimation.smooth, value: manager.showSuccessFlash)
    }

    // MARK: - Actions

    private func performLastAction() {
        guard let note = manager.selectedNote else { return }
        Task { @MainActor in
            _ = await manager.performAction(on: note)
        }
    }
}
