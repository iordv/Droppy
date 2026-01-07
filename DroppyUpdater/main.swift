//
//  main.swift
//  DroppyUpdater
//
//  A beautiful native update helper for Droppy
//  This runs as a standalone app to update Droppy while it's closed
//

import AppKit
import SwiftUI

// MARK: - Update Step Model

enum UpdateStep: Int, CaseIterable {
    case closing = 0
    case mounting
    case removing
    case installing
    case cleaning
    case complete
    
    var title: String {
        switch self {
        case .closing: return "Closing Droppy..."
        case .mounting: return "Mounting update image..."
        case .removing: return "Removing old version..."
        case .installing: return "Installing new Droppy..."
        case .cleaning: return "Cleaning up..."
        case .complete: return "Update Complete!"
        }
    }
    
    var icon: String {
        switch self {
        case .closing: return "xmark.circle"
        case .mounting: return "externaldrive.badge.plus"
        case .removing: return "trash"
        case .installing: return "arrow.down.doc"
        case .cleaning: return "sparkles"
        case .complete: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Update State

class UpdateState: ObservableObject {
    @Published var currentStep: UpdateStep = .closing
    @Published var isComplete = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var appPath = ""
    
    static let shared = UpdateState()
}

// MARK: - Update View

struct UpdaterView: View {
    @ObservedObject var state = UpdateState.shared
    @State private var isLaunchHovering = false
    @State private var pulseAnimation = false
    @State private var showSuccessGlow = false
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    // App icon with pulse animation when updating
                    ZStack {
                        // Success glow ring when complete
                        if state.isComplete {
                            Circle()
                                .stroke(Color.green.opacity(0.6), lineWidth: 3)
                                .frame(width: 76, height: 76)
                                .scaleEffect(showSuccessGlow ? 1.3 : 1.0)
                                .opacity(showSuccessGlow ? 0 : 1)
                                .animation(.easeOut(duration: 0.8), value: showSuccessGlow)
                        }
                        
                        // Pulse animation while updating
                        if !state.isComplete && !state.hasError {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                                .opacity(pulseAnimation ? 0 : 0.5)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)
                        }
                        
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                            // Trigger confetti after a tiny delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showConfetti = true
                            }
                        }
                    }
                    
                    Text(state.hasError ? "Update Failed" : (state.isComplete ? "Update Complete!" : "Updating Droppy..."))
                        .font(.title2.bold())
                        .foregroundStyle(state.isComplete ? .green : .white)
                        .animation(.easeInOut(duration: 0.3), value: state.isComplete)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)
                
                // Progress Steps
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(UpdateStep.allCases.filter { $0 != .complete }, id: \.rawValue) { step in
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
                        
                        Text("You can manually update by dragging Droppy.app from the mounted disk image to Applications.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                                // Launch the new Droppy
                                NSWorkspace.shared.open(URL(fileURLWithPath: state.appPath))
                            }
                            // Quit the updater
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
            
            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black)
        .clipped()
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
        
        // Reduced from 40 to 18 particles for performance
        for i in 0..<18 {
            var particle = ConfettiParticle(
                id: i,
                x: CGFloat.random(in: 20...(size.width - 20)),
                startY: size.height + 10,
                endY: CGFloat.random(in: -20...size.height * 0.4),
                color: colors[i % colors.count],
                size: CGFloat.random(in: 5...7),
                delay: Double(i) * 0.02 // Staggered for natural look
            )
            particle.currentX = particle.x
            particle.currentY = particle.startY
            particles.append(particle)
        }
    }
    
    private func startAnimation() {
        // Animate all particles
        for i in 0..<particles.count {
            let delay = particles[i].delay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard i < particles.count else { return }
                
                withAnimation(.easeOut(duration: 1.0)) {
                    particles[i].currentY = particles[i].endY
                    particles[i].currentX = particles[i].x + CGFloat.random(in: -25...25)
                }
            }
            
            // Fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.7) {
                guard i < particles.count else { return }
                withAnimation(.easeIn(duration: 0.3)) {
                    particles[i].opacity = 0
                }
            }
        }
        
        // Remove confetti view after animation completes
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
    let step: UpdateStep
    let currentStep: UpdateStep
    let isAllComplete: Bool
    let hasError: Bool
    
    private var isComplete: Bool {
        // When all done, all steps are complete
        if isAllComplete { return true }
        return step.rawValue < currentStep.rawValue
    }
    
    private var isCurrent: Bool {
        // When all done, no step is "current"
        if isAllComplete { return false }
        return step.rawValue == currentStep.rawValue
    }
    
    private var isPending: Bool {
        // When all done, no step is pending
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

class UpdaterWindowController: NSObject {
    var window: NSWindow?
    
    func showWindow() {
        let contentView = UpdaterView()
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 400)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.backgroundColor = .black
        window?.isMovableByWindowBackground = true
        window?.contentView = hostingView
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.level = .floating
        
        // Update window size based on content
        if let contentView = window?.contentView {
            let fittingSize = contentView.fittingSize
            window?.setContentSize(fittingSize)
        }
    }
}

// MARK: - Update Logic

class Updater {
    let dmgPath: String
    let appPath: String
    let oldPID: Int32
    let state = UpdateState.shared
    
    init(dmgPath: String, appPath: String, oldPID: Int32) {
        self.dmgPath = dmgPath
        self.appPath = appPath
        self.oldPID = oldPID
        state.appPath = appPath
    }
    
    func run() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performUpdate()
        }
    }
    
    private func setStep(_ step: UpdateStep) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.state.currentStep = step
            }
        }
        // Small delay for visual feedback between steps
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
    
    private func performUpdate() {
        // Step 1: Close old app
        setStep(.closing)
        
        // Kill the old process
        kill(oldPID, SIGKILL)
        
        // Wait for it to die
        for _ in 0..<20 {
            if kill(oldPID, 0) != 0 {
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        Thread.sleep(forTimeInterval: 0.8)
        
        // Step 2: Mount DMG
        setStep(.mounting)
        
        let mountProcess = Process()
        mountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        mountProcess.arguments = ["attach", dmgPath, "-nobrowse", "-mountpoint", "/Volumes/DroppyUpdate"]
        
        do {
            try mountProcess.run()
            mountProcess.waitUntilExit()
        } catch {
            setError("Failed to mount update image")
            return
        }
        
        // Check if mount succeeded
        let appInDMG = "/Volumes/DroppyUpdate/Droppy.app"
        if !FileManager.default.fileExists(atPath: appInDMG) {
            setError("Could not find Droppy.app in update image")
            return
        }
        
        // Step 3: Remove old app
        setStep(.removing)
        
        do {
            if FileManager.default.fileExists(atPath: appPath) {
                try FileManager.default.removeItem(atPath: appPath)
            }
        } catch {
            // Try with admin privileges using osascript
            let script = "do shell script \"rm -rf '\(appPath)'\" with administrator privileges"
            let appleScript = NSAppleScript(source: script)
            var errorDict: NSDictionary?
            appleScript?.executeAndReturnError(&errorDict)
            
            if FileManager.default.fileExists(atPath: appPath) {
                setError("Could not remove old version. Please delete Droppy.app manually.")
                // Open Applications folder to help user
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Volumes/DroppyUpdate"))
                return
            }
        }
        
        // Step 4: Install new app
        setStep(.installing)
        
        do {
            try FileManager.default.copyItem(atPath: appInDMG, toPath: appPath)
        } catch {
            setError("Failed to install new version: \(error.localizedDescription)")
            return
        }
        
        // Remove quarantine attribute
        let xattrProcess = Process()
        xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattrProcess.arguments = ["-rd", "com.apple.quarantine", appPath]
        try? xattrProcess.run()
        xattrProcess.waitUntilExit()
        
        // Step 5: Cleanup
        setStep(.cleaning)
        
        let unmountProcess = Process()
        unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        unmountProcess.arguments = ["detach", "/Volumes/DroppyUpdate", "-quiet"]
        try? unmountProcess.run()
        unmountProcess.waitUntilExit()
        
        try? FileManager.default.removeItem(atPath: dmgPath)
        
        // Small delay before showing complete
        Thread.sleep(forTimeInterval: 0.4)
        
        // Complete!
        setComplete()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: UpdaterWindowController?
    var updater: Updater?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Parse command line arguments
        let args = CommandLine.arguments
        
        guard args.count >= 4 else {
            print("Usage: DroppyUpdater <dmg_path> <app_path> <old_pid>")
            NSApp.terminate(nil)
            return
        }
        
        let dmgPath = args[1]
        let appPath = args[2]
        let oldPID = Int32(args[3]) ?? 0
        
        // Show the window
        windowController = UpdaterWindowController()
        windowController?.showWindow()
        
        // Start the update
        updater = Updater(dmgPath: dmgPath, appPath: appPath, oldPID: oldPID)
        updater?.run()
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
