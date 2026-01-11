//
//  main.swift
//  DroppyInstaller
//
//  A beautiful native installer for Droppy
//  This runs as a standalone app to install Droppy to /Applications
//

import AppKit
import SwiftUI

// MARK: - Install Step Model

enum InstallStep: Int, CaseIterable {
    case checking = 0
    case preparing
    case installing
    case configuring
    case complete
    
    var title: String {
        switch self {
        case .checking: return "Checking system..."
        case .preparing: return "Preparing installation..."
        case .installing: return "Installing Droppy..."
        case .configuring: return "Configuring..."
        case .complete: return "Installation Complete!"
        }
    }
    
    var icon: String {
        switch self {
        case .checking: return "magnifyingglass.circle"
        case .preparing: return "folder.badge.gearshape"
        case .installing: return "arrow.down.doc"
        case .configuring: return "gearshape"
        case .complete: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Install State

class InstallState: ObservableObject {
    @Published var currentStep: InstallStep = .checking
    @Published var isComplete = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var needsReplace = false
    @Published var showReplaceConfirm = false
    
    static let shared = InstallState()
}

// MARK: - Installer View

struct InstallerView: View {
    @ObservedObject var state = InstallState.shared
    @State private var isLaunchHovering = false
    @State private var pulseAnimation = false
    @State private var showSuccessGlow = false
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with slogan
                VStack(spacing: 16) {
                    // App icon with pulse animation
                    ZStack {
                        // Success glow ring when complete
                        if state.isComplete {
                            Circle()
                                .stroke(Color.green.opacity(0.6), lineWidth: 3)
                                .frame(width: 86, height: 86)
                                .scaleEffect(showSuccessGlow ? 1.3 : 1.0)
                                .opacity(showSuccessGlow ? 0 : 1)
                                .animation(.easeOut(duration: 0.8), value: showSuccessGlow)
                        }
                        
                        // Pulse animation while installing
                        if !state.isComplete && !state.hasError {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 90, height: 90)
                                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                                .opacity(pulseAnimation ? 0 : 0.5)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)
                        }
                        
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: state.isComplete ? .green.opacity(0.4) : .black.opacity(0.3), radius: 8, y: 4)
                            .scaleEffect(state.isComplete ? 1.05 : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: state.isComplete)
                    }
                    .onAppear {
                        pulseAnimation = true
                    }
                    .onChange(of: state.isComplete) { _, complete in
                        if complete {
                            showSuccessGlow = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showConfetti = true
                            }
                        }
                    }
                    
                    // Slogan
                    VStack(spacing: 4) {
                        HStack(spacing: 0) {
                            Text("Just ")
                                .foregroundStyle(.white)
                            Text("drop it.")
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(0.1))
                                )
                            Text(" We've got it.")
                                .foregroundStyle(.white)
                        }
                        .font(.title2.bold())
                    }
                    
                    Text(state.hasError ? "Installation Failed" : (state.isComplete ? "Ready to go!" : "Installing Droppy..."))
                        .font(.subheadline)
                        .foregroundStyle(state.isComplete ? .green : (state.hasError ? .red : .secondary))
                        .animation(.easeInOut(duration: 0.3), value: state.isComplete)
                }
                .padding(.top, 28)
                .padding(.bottom, 24)
                
                // Progress Steps
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(InstallStep.allCases.filter { $0 != .complete }, id: \.rawValue) { step in
                        StepRow(
                            step: step,
                            currentStep: state.currentStep,
                            isAllComplete: state.isComplete,
                            hasError: state.hasError
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                // Error Message
                if state.hasError {
                    VStack(spacing: 8) {
                        Text(state.errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 16)
                }
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Action Button
                HStack {
                    Spacer()
                    
                    if state.isComplete || state.hasError {
                        Button {
                            if state.isComplete {
                                // Launch Droppy
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Droppy.app"))
                            }
                            // Quit the installer
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                NSApp.terminate(nil)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: state.hasError ? "xmark" : "arrow.right.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(state.hasError ? "Close" : "Launch Droppy")
                            }
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                state.isComplete
                                    ? Color.green.opacity(isLaunchHovering ? 1.0 : 0.8)
                                    : Color.blue.opacity(isLaunchHovering ? 1.0 : 0.8)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                isLaunchHovering = h
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(16)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.isComplete)
            }
            
            // Replace confirmation dialog
            if state.showReplaceConfirm {
                ReplaceConfirmView()
            }
            
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(red: 0.06, green: 0.09, blue: 0.16)) // slate-950
        .clipped()
    }
}

// MARK: - Replace Confirm View

struct ReplaceConfirmView: View {
    @State private var isReplaceHovering = false
    @State private var isCancelHovering = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)
                
                Text("Droppy Already Installed")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("Do you want to replace the existing installation?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 12) {
                    Button {
                        InstallState.shared.showReplaceConfirm = false
                        InstallState.shared.hasError = true
                        InstallState.shared.errorMessage = "Installation cancelled"
                    } label: {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(isCancelHovering ? 0.2 : 0.1))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .onHover { h in isCancelHovering = h }
                    
                    Button {
                        InstallState.shared.showReplaceConfirm = false
                        InstallState.shared.needsReplace = true
                        // Continue installation
                        Installer.shared?.continueAfterReplace()
                    } label: {
                        Text("Replace")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(isReplaceHovering ? 1.0 : 0.8))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .onHover { h in isReplaceHovering = h }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.1, green: 0.12, blue: 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 20)
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isVisible = true
    
    var body: some View {
        GeometryReader { geo in
            if isVisible {
                Canvas { context, size in
                    for particle in particles {
                        let rect = CGRect(
                            x: particle.currentX - particle.size / 2,
                            y: particle.currentY - particle.size * 0.75,
                            width: particle.size,
                            height: particle.size * 1.5
                        )
                        context.fill(
                            RoundedRectangle(cornerRadius: 1).path(in: rect),
                            with: .color(particle.color.opacity(particle.opacity))
                        )
                    }
                }
                .onAppear {
                    createParticles(in: geo.size)
                    startAnimation()
                }
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.green, .blue, .yellow, .orange, .pink, .purple, .cyan]
        
        for i in 0..<18 {
            var particle = ConfettiParticle(
                id: i,
                x: CGFloat.random(in: 20...(size.width - 20)),
                startY: size.height + 10,
                endY: CGFloat.random(in: -20...size.height * 0.4),
                color: colors[i % colors.count],
                size: CGFloat.random(in: 5...7),
                delay: Double(i) * 0.02
            )
            particle.currentX = particle.x
            particle.currentY = particle.startY
            particles.append(particle)
        }
    }
    
    private func startAnimation() {
        for i in 0..<particles.count {
            let delay = particles[i].delay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard i < particles.count else { return }
                
                withAnimation(.easeOut(duration: 1.0)) {
                    particles[i].currentY = particles[i].endY
                    particles[i].currentX = particles[i].x + CGFloat.random(in: -25...25)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.7) {
                guard i < particles.count else { return }
                withAnimation(.easeIn(duration: 0.3)) {
                    particles[i].opacity = 0
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isVisible = false
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: Int
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let color: Color
    let size: CGFloat
    let delay: Double
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var opacity: Double = 1
}

struct StepRow: View {
    let step: InstallStep
    let currentStep: InstallStep
    let isAllComplete: Bool
    let hasError: Bool
    
    private var isComplete: Bool {
        if isAllComplete { return true }
        return step.rawValue < currentStep.rawValue
    }
    
    private var isCurrent: Bool {
        if isAllComplete { return false }
        return step.rawValue == currentStep.rawValue
    }
    
    private var isPending: Bool {
        if isAllComplete { return false }
        return step.rawValue > currentStep.rawValue
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else if isCurrent {
                    if hasError {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                            .transition(.opacity)
                    }
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .transition(.opacity)
                }
            }
            .frame(width: 20, height: 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isComplete)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrent)
            
            Text(step.title)
                .font(.system(size: 13, weight: isComplete ? .medium : (isCurrent ? .semibold : .regular)))
                .foregroundColor(isPending ? Color.secondary : (isComplete ? Color.green : Color.white))
            
            Spacer()
        }
        .padding(.vertical, 8)
        .opacity(isPending ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isComplete)
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
    }
}

// MARK: - Window Controller

class InstallerWindowController: NSObject {
    var window: NSWindow?
    
    func showWindow() {
        let contentView = InstallerView()
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 340, height: 420)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.backgroundColor = NSColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1.0)
        window?.isMovableByWindowBackground = true
        window?.contentView = hostingView
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.level = .floating
        
        if let contentView = window?.contentView {
            let fittingSize = contentView.fittingSize
            window?.setContentSize(fittingSize)
        }
    }
}

// MARK: - Install Logic

class Installer {
    static var shared: Installer?
    
    let state = InstallState.shared
    let appBundle: Bundle
    var waitingForReplace = false
    
    init() {
        self.appBundle = Bundle.main
        Installer.shared = self
    }
    
    func run() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performInstall()
        }
    }
    
    func continueAfterReplace() {
        waitingForReplace = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performInstallAfterReplace()
        }
    }
    
    private func setStep(_ step: InstallStep) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.state.currentStep = step
            }
        }
        Thread.sleep(forTimeInterval: 0.15)
    }
    
    private func setError(_ message: String) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.state.hasError = true
                self.state.errorMessage = message
            }
        }
    }
    
    private func setComplete() {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.state.currentStep = .complete
                self.state.isComplete = true
            }
        }
    }
    
    private func showReplaceConfirm() {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.state.showReplaceConfirm = true
            }
        }
    }
    
    private func performInstall() {
        // Step 1: Check system
        setStep(.checking)
        Thread.sleep(forTimeInterval: 0.5)
        
        // Find Droppy.app in the hidden .payload folder
        let bundlePath = appBundle.bundlePath
        let parentDir = (bundlePath as NSString).deletingLastPathComponent
        let payloadDir = (parentDir as NSString).appendingPathComponent(".payload")
        var droppyAppPath = (payloadDir as NSString).appendingPathComponent("Droppy.app")
        
        // Fallback: check same directory (for development/testing)
        if !FileManager.default.fileExists(atPath: droppyAppPath) {
            droppyAppPath = (parentDir as NSString).appendingPathComponent("Droppy.app")
        }
        
        if !FileManager.default.fileExists(atPath: droppyAppPath) {
            setError("Droppy.app not found. Please run the installer from the disk image.")
            return
        }
        
        // Step 2: Prepare
        setStep(.preparing)
        Thread.sleep(forTimeInterval: 0.3)
        
        let targetPath = "/Applications/Droppy.app"
        
        // Check if Droppy already exists
        if FileManager.default.fileExists(atPath: targetPath) {
            waitingForReplace = true
            showReplaceConfirm()
            
            // Wait for user response
            while waitingForReplace {
                Thread.sleep(forTimeInterval: 0.1)
                if state.hasError {
                    return
                }
            }
        }
        
        performInstallAfterReplace()
    }
    
    func performInstallAfterReplace() {
        let bundlePath = appBundle.bundlePath
        let parentDir = (bundlePath as NSString).deletingLastPathComponent
        let payloadDir = (parentDir as NSString).appendingPathComponent(".payload")
        var droppyAppPath = (payloadDir as NSString).appendingPathComponent("Droppy.app")
        
        // Fallback: check same directory
        if !FileManager.default.fileExists(atPath: droppyAppPath) {
            droppyAppPath = (parentDir as NSString).appendingPathComponent("Droppy.app")
        }
        
        let targetPath = "/Applications/Droppy.app"
        
        // Step 3: Install
        setStep(.installing)
        
        // Remove old version if exists
        if FileManager.default.fileExists(atPath: targetPath) {
            do {
                try FileManager.default.removeItem(atPath: targetPath)
            } catch {
                // Try with admin privileges
                let script = "do shell script \"rm -rf '\(targetPath)'\" with administrator privileges"
                let appleScript = NSAppleScript(source: script)
                var errorDict: NSDictionary?
                appleScript?.executeAndReturnError(&errorDict)
                
                if FileManager.default.fileExists(atPath: targetPath) {
                    setError("Could not remove existing installation. Please close Droppy and try again.")
                    return
                }
            }
        }
        
        // Copy new version
        do {
            try FileManager.default.copyItem(atPath: droppyAppPath, toPath: targetPath)
        } catch {
            // Try with admin privileges
            let script = "do shell script \"cp -R '\(droppyAppPath)' '\(targetPath)'\" with administrator privileges"
            let appleScript = NSAppleScript(source: script)
            var errorDict: NSDictionary?
            appleScript?.executeAndReturnError(&errorDict)
            
            if !FileManager.default.fileExists(atPath: targetPath) {
                setError("Failed to install: \(error.localizedDescription)")
                return
            }
        }
        
        // Step 4: Configure
        setStep(.configuring)
        
        // Remove quarantine attribute
        let xattrProcess = Process()
        xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattrProcess.arguments = ["-rd", "com.apple.quarantine", targetPath]
        try? xattrProcess.run()
        xattrProcess.waitUntilExit()
        
        Thread.sleep(forTimeInterval: 0.4)
        
        // Complete!
        setComplete()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: InstallerWindowController?
    var installer: Installer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show the window
        windowController = InstallerWindowController()
        windowController?.showWindow()
        
        // Start the installation
        installer = Installer()
        installer?.run()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
