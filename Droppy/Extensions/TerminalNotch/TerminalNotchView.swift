//
//  TerminalNotchView.swift
//  Droppy
//
//  SwiftUI view for the terminal interface
//

import SwiftUI

/// Quick command terminal view that appears in the notch area
struct TerminalNotchView: View {
    @ObservedObject var manager: TerminalNotchManager
    @FocusState private var isInputFocused: Bool
    
    /// Physical notch height from safe area insets (matches MediaPlayerView)
    private var notchHeight: CGFloat {
        NSScreen.main?.safeAreaInsets.top ?? 0
    }
    
    /// Dynamic Island mode detection (notchHeight == 0 means external display or Dynamic Island)
    private var isDynamicIslandMode: Bool {
        notchHeight == 0
    }
    
    /// Animated dash phase for marching ants effect on dotted outline
    @State private var dashPhase: CGFloat = 0
    
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
                RoundedRectangle(cornerRadius: 20)
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
                    .animation(.easeInOut(duration: 0.5), value: manager.pulsePosition)
            }
        }
        // No external styling - terminal lives inside shelf's content area
        // which already has its own black background
        .onAppear {
            isInputFocused = true
        }
        .onChange(of: manager.isVisible) { _, isVisible in
            if isVisible {
                // Focus the text field when terminal becomes visible
                isInputFocused = true
            }
        }
    }
    
    // MARK: - Initial Centered Command View
    
    /// Beautiful centered command input with dotted outline (shown before first command)
    private var initialCommandView: some View {
        ZStack {
            // Dotted outline container with marching ants animation (like empty shelf)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    Color.green.opacity(0.4),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        dash: [6, 8],
                        dashPhase: dashPhase
                    )
                )
            
            // Centered command input
            VStack(spacing: 12) {
                // Terminal icon
                Image(systemName: "terminal")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.green.opacity(0.6))
                
                // Command input row with fixed frame to prevent shift
                HStack(spacing: 8) {
                    Text("$")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    
                    TextField("Enter command...", text: $manager.commandText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.white)
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
                .fixedSize(horizontal: false, vertical: true) // Prevent height changes
            }
            .padding(24)
        }
        // CRITICAL: Match drop zone padding - Island mode: 16pt uniform, Notch mode: symmetrical 20pt + notch-aware top
        .padding(EdgeInsets(
            top: isDynamicIslandMode ? 16 : notchHeight + 14,
            leading: isDynamicIslandMode ? 16 : 20,
            bottom: isDynamicIslandMode ? 16 : 20,
            trailing: isDynamicIslandMode ? 16 : 20
        ))
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
                TextField("Enter command...", text: $manager.commandText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white)
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
            
            // Output preview (if any)
            if !manager.lastOutput.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                ScrollView {
                    Text(manager.lastOutput)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled) // Allow text selection and copy
                }
                .frame(maxHeight: 200)
            }
            
            Spacer(minLength: 0)
        }
        // CRITICAL: Use exact same padding as MediaPlayerView for alignment
        .padding(EdgeInsets(
            top: notchHeight > 0 ? notchHeight + 6 : 20,
            leading: 20,
            bottom: 20,
            trailing: 20
        ))
    }
    
    // MARK: - Expanded Terminal View
    
    private var expandedTerminalView: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Terminal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                // Collapse button
                Button(action: { manager.toggleExpanded() }) {
                    Image(systemName: "rectangle.compress.vertical")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Collapse to quick mode")
                
                // Open in Terminal.app
                Button(action: { manager.openInTerminalApp() }) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Open in Terminal.app")
                
                // Close button
                Button(action: { manager.hide() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
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
                                    .foregroundStyle(.white)
                            }
                            .font(.system(size: 13, design: .monospaced))
                        }
                        
                        if !manager.lastOutput.isEmpty {
                            Text(manager.lastOutput)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                
                // Input line
                HStack(spacing: 8) {
                    Text("$")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    
                    TextField("", text: $manager.commandText)
                        .textFieldStyle(.plain)
                        .font(.system(size: manager.fontSize, design: .monospaced))
                        .foregroundStyle(.white)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.03))
            }
            .frame(height: 300)
        }
    }
    
    // MARK: - Background
    
    private var terminalBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
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
