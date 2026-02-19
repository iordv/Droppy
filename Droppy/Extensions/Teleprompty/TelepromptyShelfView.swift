//
//  TelepromptyShelfView.swift
//  Droppy
//
//  Teleprompty controls and live prompt surface inside expanded shelf.
//

import SwiftUI

private struct TelepromptyScriptHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TelepromptyShelfView: View {
    @ObservedObject var manager: TelepromptyManager
    @Binding var isVisible: Bool

    var notchHeight: CGFloat = 0
    var isExternalWithNotchStyle: Bool = false

    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.telepromptyScript) private var script = PreferenceDefault.telepromptyScript
    @AppStorage(AppPreferenceKey.telepromptySpeed) private var speed = PreferenceDefault.telepromptySpeed
    @AppStorage(AppPreferenceKey.telepromptyFontSize) private var fontSize = PreferenceDefault.telepromptyFontSize
    @AppStorage(AppPreferenceKey.telepromptyPromptWidth) private var promptWidth = PreferenceDefault.telepromptyPromptWidth
    @AppStorage(AppPreferenceKey.telepromptyPromptHeight) private var promptHeight = PreferenceDefault.telepromptyPromptHeight
    @AppStorage(AppPreferenceKey.telepromptyCountdown) private var countdown = PreferenceDefault.telepromptyCountdown

    @State private var showInlineEditor = false
    @State private var draftScript = ""
    @State private var measuredScriptHeight: CGFloat = 0

    private var contentPadding: EdgeInsets {
        NotchLayoutConstants.contentEdgeInsets(
            notchHeight: notchHeight,
            isExternalWithNotchStyle: isExternalWithNotchStyle
        )
    }

    private var useAdaptiveForegrounds: Bool {
        useTransparentBackground && notchHeight == 0
    }

    private var clampedPromptWidth: CGFloat {
        CGFloat(max(320, min(promptWidth, 760)))
    }

    private var clampedPromptHeight: CGFloat {
        CGFloat(max(100, min(promptHeight, 260)))
    }

    private var telepromptyPanelWidth: CGFloat {
        max(clampedPromptWidth, 430)
    }

    var body: some View {
        Group {
            if manager.isPromptVisible {
                promptStage
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
            } else {
                controlsStage
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
            }
        }
        .animation(DroppyAnimation.smoothContent, value: manager.isPromptVisible)
        .animation(DroppyAnimation.smoothContent, value: manager.isCountingDown)
        .onAppear {
            manager.isShelfViewVisible = true
            manager.isInlineEditorVisible = showInlineEditor
        }
        .onDisappear {
            manager.isShelfViewVisible = false
            manager.isInlineEditorVisible = false
        }
        .onChange(of: showInlineEditor) { _, isShown in
            manager.isInlineEditorVisible = isShown
        }
    }

    private var controlsStage: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Teleprompty", systemImage: "text.bubble")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(primaryText())

                Spacer(minLength: 12)

                Text(TelepromptyManager.estimatedReadTimeLabel(for: script, speed: speed))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondaryText(0.78))
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Button("Start") {
                    startPrompt()
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .mint, size: .small))
                .disabled(script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Reset") {
                    manager.reset()
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))

                Button("Jump Back 5s") {
                    manager.jumpBack(seconds: 5)
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))

                Button(showInlineEditor ? "Hide Editor" : "Add Text") {
                    withAnimation(DroppyAnimation.smoothContent) {
                        showInlineEditor.toggle()
                    }
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))

                Spacer(minLength: 0)

                Button {
                    withAnimation(DroppyAnimation.smoothContent) {
                        manager.stop(hidePrompt: true)
                        manager.isInlineEditorVisible = false
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 30))
            }

            if showInlineEditor {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $draftScript)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .frame(height: 72)
                        .padding(6)
                        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                                .stroke(AdaptiveColors.overlayAuto(0.1), lineWidth: 1)
                        )

                    HStack(spacing: 8) {
                        Button("Append") {
                            appendDraftText()
                        }
                        .buttonStyle(DroppyAccentButtonStyle(color: .mint, size: .small))
                        .disabled(draftScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Replace") {
                            replaceWithDraftText()
                        }
                        .buttonStyle(DroppyPillButtonStyle(size: .small))
                        .disabled(draftScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Spacer()

                        Button("Cancel") {
                            withAnimation(DroppyAnimation.smoothContent) {
                                draftScript = ""
                                showInlineEditor = false
                            }
                        }
                        .buttonStyle(DroppyPillButtonStyle(size: .small))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 12) {
                capsuleValue(title: "Speed", value: "\(Int(round(speed)))")
                capsuleValue(title: "Font", value: "\(Int(round(fontSize)))")
                capsuleValue(title: "Size", value: "\(Int(round(promptWidth)))×\(Int(round(promptHeight)))")
                capsuleValue(title: "Countdown", value: "\(Int(round(countdown)))s")
            }
        }
        .frame(width: telepromptyPanelWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(contentPadding)
    }

    private var promptStage: some View {
        let textWidth = max(220, clampedPromptWidth - 44)
        let startOffsetY = clampedPromptHeight * 0.62

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(promptStatusText, systemImage: promptStatusIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(promptStatusColor)

                Spacer(minLength: 12)

                Button("Jump Back 5s") {
                    manager.jumpBack(seconds: 5)
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))

                Button("Reset") {
                    manager.reset()
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))

                Button("Stop") {
                    withAnimation(DroppyAnimation.smoothContent) {
                        manager.stop(hidePrompt: true)
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .mint, size: .small))
            }

            ZStack {
                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                    .fill(useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(0.08) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                            .stroke(AdaptiveColors.overlayAuto(0.14), lineWidth: 1)
                    )

                GeometryReader { _ in
                    Text(script.isEmpty ? "Add your script in Teleprompty settings" : script)
                        .font(.system(size: CGFloat(max(12, min(fontSize, 42))), weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryText())
                        .lineSpacing(max(6, CGFloat(fontSize) * 0.42))
                        .multilineTextAlignment(.center)
                        .frame(width: textWidth, alignment: .top)
                        .offset(y: startOffsetY - manager.scrollOffset)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: TelepromptyScriptHeightPreferenceKey.self,
                                    value: proxy.size.height
                                )
                            }
                        )
                        .frame(width: clampedPromptWidth, height: clampedPromptHeight, alignment: .top)
                        .clipped()
                }

                if manager.isCountingDown {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.65))
                            .frame(width: 58, height: 58)
                        Text("\(manager.countdownRemaining)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: clampedPromptWidth, height: clampedPromptHeight)
            .onPreferenceChange(TelepromptyScriptHeightPreferenceKey.self) { measuredScriptHeight = $0 }
            .onChange(of: manager.scrollOffset) { _, offset in
                let endThreshold = measuredScriptHeight + (clampedPromptHeight * 0.65)
                if measuredScriptHeight > 0, offset >= endThreshold {
                    manager.markEndedAndReturnToControls()
                }
            }
        }
        .frame(width: telepromptyPanelWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(contentPadding)
    }

    private var promptStatusText: String {
        if manager.isCountingDown { return "Starts in \(manager.countdownRemaining)" }
        if manager.isRunning { return "Teleprompting" }
        return "Ready"
    }

    private var promptStatusIcon: String {
        if manager.isCountingDown { return "timer" }
        if manager.isRunning { return "play.fill" }
        return "checkmark.circle"
    }

    private var promptStatusColor: Color {
        if manager.isCountingDown { return .orange }
        if manager.isRunning { return .mint }
        return .secondary
    }

    private func startPrompt() {
        showInlineEditor = false
        manager.isInlineEditorVisible = false
        manager.start(script: script, speed: speed, countdown: countdown)
    }

    private func appendDraftText() {
        let cleaned = draftScript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let existing = script.trimmingCharacters(in: .whitespacesAndNewlines)
        if existing.isEmpty {
            script = cleaned
        } else {
            script = existing + "\n\n" + cleaned
        }

        draftScript = ""
        withAnimation(DroppyAnimation.smoothContent) {
            showInlineEditor = false
        }
    }

    private func replaceWithDraftText() {
        let cleaned = draftScript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        script = cleaned
        draftScript = ""
        withAnimation(DroppyAnimation.smoothContent) {
            showInlineEditor = false
        }
    }

    private func capsuleValue(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryText(0.78))
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(primaryText())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(AdaptiveColors.overlayAuto(0.09))
        )
    }

    private func primaryText(_ opacity: Double = 1.0) -> Color {
        useAdaptiveForegrounds
            ? AdaptiveColors.primaryTextAuto.opacity(opacity)
            : .white.opacity(opacity)
    }

    private func secondaryText(_ opacity: Double) -> Color {
        useAdaptiveForegrounds
            ? AdaptiveColors.secondaryTextAuto.opacity(opacity)
            : .white.opacity(opacity)
    }
}
