//
//  TerminalNotchView.swift
//  Droppy
//
//  SwiftUI view for the terminal interface
//

import SwiftUI
import AppKit

/// Quick command terminal view that appears in the notch area
struct TerminalNotchView: View {
    @ObservedObject var manager: TerminalNotchManager
    var notchHeight: CGFloat = 0  // Physical notch height from parent (0 for Dynamic Island)
    var isExternalWithNotchStyle: Bool = false  // External display with curved notch style
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @FocusState private var isInputFocused: Bool
    
    /// Dynamic Island mode detection based on notchHeight
    private var isDynamicIslandMode: Bool {
        notchHeight == 0
    }
    
    /// Content padding from SSOT - ensures perfect consistency
    /// - Built-in notch: notchHeight top, 30pt left/right, 20pt bottom
    /// - External notch style: 20pt top/bottom, 30pt left/right
    /// - Island mode: 30pt on all 4 edges
    private var contentPadding: EdgeInsets {
        NotchLayoutConstants.contentEdgeInsets(notchHeight: notchHeight, isExternalWithNotchStyle: isExternalWithNotchStyle)
    }

    /// Keep built-in notch text white on black.
    /// Only use adaptive foregrounds for external transparent-notch mode.
    private var useAdaptiveForegrounds: Bool {
        useTransparentBackground && isExternalWithNotchStyle
    }

    private func textColor(_ whiteOpacity: Double = 1.0) -> Color {
        useAdaptiveForegrounds ? AdaptiveColors.primaryTextAuto.opacity(whiteOpacity) : .white.opacity(whiteOpacity)
    }

    private func secondaryTextColor(_ whiteOpacity: Double) -> Color {
        useAdaptiveForegrounds ? AdaptiveColors.secondaryTextAuto.opacity(whiteOpacity) : .white.opacity(whiteOpacity)
    }

    private func overlayColor(_ whiteOpacity: Double) -> Color {
        useAdaptiveForegrounds ? AdaptiveColors.overlayAuto(whiteOpacity) : .white.opacity(whiteOpacity)
    }

    private var inputChromeBackgroundOpacity: Double {
        useAdaptiveForegrounds ? 0.95 : 0.12
    }

    private var inputChromeBorderOpacity: Double {
        useAdaptiveForegrounds ? 1.0 : 0.16
    }
    
    /// Animated dash phase for marching ants effect on dotted outline
    @State private var dashPhase: CGFloat = 0
    @State private var focusRequestToken = UUID()

    private func forceInputFocus() {
        guard manager.isVisible else { return }
        isInputFocused = false
        DispatchQueue.main.async {
            guard manager.isVisible else { return }
            isInputFocused = true
        }
    }

    private func requestInputFocus() {
        guard manager.isVisible else { return }
        let requestToken = UUID()
        focusRequestToken = requestToken

        // Retry across the shelf/open animation to avoid focus races.
        for delay in [0.0, 0.06, 0.16, 0.32] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard manager.isVisible, focusRequestToken == requestToken else { return }
                forceInputFocus()
            }
        }
    }

    private func cancelFocusRequests() {
        focusRequestToken = UUID()
        isInputFocused = false
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if manager.isExpanded {
                    expandedTerminalView
                } else if !manager.hasExecutedCommand {
                    // Initial centered state with dotted outline
                    initialCommandView
                } else {
                    quickCommandView
                }
            }
            
            // Sweeping green pulse on command execution (left to right)
            if manager.showPulse {
                // Sweeping trim animation
                RoundedRectangle(cornerRadius: DroppyRadius.xxl + 2)
                    .trim(from: max(0, manager.pulsePosition - 0.15), to: min(1, manager.pulsePosition))
                    .stroke(
                        LinearGradient(
                            colors: [.clear, .green, .green, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .blur(radius: 2)
            }
        }
        // No external styling - terminal lives inside shelf's content area
        // which already has its own black background
        .onAppear {
            requestInputFocus()
        }
        .onChange(of: manager.isVisible) { _, isVisible in
            if isVisible {
                requestInputFocus()
            } else {
                cancelFocusRequests()
            }
        }
        .onChange(of: manager.isExpanded) { _, _ in
            requestInputFocus()
        }
        .onChange(of: manager.hasExecutedCommand) { _, _ in
            requestInputFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            requestInputFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            requestInputFocus()
        }
        .onDisappear {
            cancelFocusRequests()
        }
    }
    
    // MARK: - Initial Centered Command View
    
    /// Beautiful centered command input with dotted outline (shown before first command)
    private var initialCommandView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DroppyRadius.xxl + 2, style: .continuous)
                .strokeBorder(
                    Color.green.opacity(0.4),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        dash: [6, 8],
                        dashPhase: dashPhase
                    )
                )
            
            VStack(spacing: 12) {
                // Terminal icon
                Image(systemName: "terminal")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.green.opacity(0.6))

                // Command input row with fixed frame to prevent shift
                HStack(alignment: .center, spacing: 8) {
                    Text("$")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)

                    // Use ZStack with fixed frame to prevent any layout shift
                    ZStack(alignment: .leading) {
                        // Invisible sizing reference that never changes
                        Text("Enter command…")
                            .font(.system(size: 16, design: .monospaced))
                            .opacity(0)

                        // Placeholder text (only visible when empty and not focused)
                        if manager.commandText.isEmpty && !isInputFocused {
                            Text("Enter command…")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundStyle(secondaryTextColor(0.4))
                        }

                        // Actual text field with no placeholder (avoids SwiftUI's placeholder shift bug)
                        TextField("", text: $manager.commandText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(textColor())
                            .focused($isInputFocused)
                            .onSubmit {
                                manager.executeQuickCommand(manager.commandText)
                            }
                            .onKeyPress(.upArrow) {
                                manager.historyUp()
                                return .handled
                            }
                            .onKeyPress(.downArrow) {
                                manager.historyDown()
                                return .handled
                            }
                    }

                    // Placeholder for running indicator to prevent shift
                    if manager.isRunning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    } else {
                        // Invisible spacer to keep layout stable
                        Color.clear
                            .frame(width: 16, height: 16)
                    }
                }
                .droppyTextInputChrome(
                    cornerRadius: DroppyRadius.medium,
                    horizontalPadding: 16,
                    verticalPadding: 10,
                    backgroundOpacity: inputChromeBackgroundOpacity,
                    borderOpacity: inputChromeBorderOpacity,
                    useAdaptiveColors: useAdaptiveForegrounds
                )
            }
            .padding(.horizontal, DroppySpacing.lg)
            .padding(.vertical, DroppySpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        // Use SSOT for consistent outer padding across all expanded views
        .padding(contentPadding)
        // Start marching ants animation when view appears
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                dashPhase -= 280 // Multiple of 14 (6+8) for smooth loop
            }
        }
        // Reset dash phase when view disappears to save CPU
        .onDisappear {
            dashPhase = 0
        }
    }
    
    // MARK: - Quick Command View
    
    private var quickCommandView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Command input row
            HStack(spacing: 10) {
                // Shell prompt
                Text("$")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                
                // Command input
                TextField(
                    "",
                    text: $manager.commandText,
                    prompt: Text("Enter command…").foregroundColor(secondaryTextColor(0.42))
                )
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(textColor())
                    .focused($isInputFocused)
                    .onSubmit {
                        manager.executeQuickCommand(manager.commandText)
                    }
                    .onKeyPress(.upArrow) {
                        manager.historyUp()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        manager.historyDown()
                        return .handled
                    }
                
                // Running indicator
                if manager.isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .droppyTextInputChrome(
                cornerRadius: DroppyRadius.medium,
                horizontalPadding: 12,
                verticalPadding: 10,
                backgroundOpacity: inputChromeBackgroundOpacity,
                borderOpacity: inputChromeBorderOpacity,
                useAdaptiveColors: useAdaptiveForegrounds
            )
            
            // Output preview (if any)
            if !manager.lastOutput.isEmpty {
                Divider()
                    .background(overlayColor(0.1))
                
                ScrollView {
                    Text(manager.lastOutput)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(secondaryTextColor(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled) // Allow text selection and copy
                }
                .frame(maxHeight: 200)
            }
            
            Spacer(minLength: 0)
        }
        // Use SSOT for consistent padding across all expanded views
        .padding(contentPadding)
    }
    
    // MARK: - Expanded Terminal View
    
    private var expandedTerminalView: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Terminal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(secondaryTextColor(0.6))
                
                Spacer()
                
                // Collapse button
                Button(action: { manager.toggleExpanded() }) {
                    Image(systemName: "rectangle.compress.vertical")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 24))
                .help("Collapse to quick mode")
                
                // Open in selected terminal app
                Button(action: { manager.openInTerminalApp() }) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 24))
                .help("Open in \(manager.preferredExternalAppTitle)")
                
                // Close button
                Button(action: { manager.hide() }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 24))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(overlayColor(0.05))
            
            Divider()
                .background(overlayColor(0.1))
            
            // Terminal content area
            // This will be replaced with SwiftTerm's LocalProcessTerminalView
            // For now, show a placeholder with the quick command interface
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        // Show command history with outputs
                        ForEach(manager.commandHistory.suffix(20), id: \.self) { cmd in
                            HStack(spacing: 6) {
                                Text("$")
                                    .foregroundStyle(.green)
                                Text(cmd)
                                    .foregroundStyle(textColor())
                            }
                            .font(.system(size: 13, design: .monospaced))
                        }
                        
                        if !manager.lastOutput.isEmpty {
                            Text(manager.lastOutput)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(secondaryTextColor(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DroppySpacing.md)
                }
                
                // Input line
                HStack(spacing: 8) {
                    Text("$")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    
                    TextField("", text: $manager.commandText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(textColor())
                        .focused($isInputFocused)
                        .onSubmit {
                            manager.executeQuickCommand(manager.commandText)
                        }
                        .onKeyPress(.upArrow) {
                            manager.historyUp()
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            manager.historyDown()
                            return .handled
                        }
                }
                .droppyTextInputChrome(
                    cornerRadius: DroppyRadius.medium,
                    horizontalPadding: 12,
                    verticalPadding: 10,
                    backgroundOpacity: inputChromeBackgroundOpacity,
                    borderOpacity: inputChromeBorderOpacity,
                    useAdaptiveColors: useAdaptiveForegrounds
                )
            }
            .frame(height: 300)
        }
        // Use SSOT for consistent padding across all expanded views
        .padding(contentPadding)
    }
    
    // MARK: - Background
    
    private var terminalBackground: some View {
        RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
            .droppyGlassFill()
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                    .fill(Color.black.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                    .strokeBorder(overlayColor(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    TerminalNotchView(manager: TerminalNotchManager.shared)
        .frame(width: 400)
        .padding()
        .background(Color.black)
}
