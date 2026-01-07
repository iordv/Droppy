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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                // App icon with pulse animation when updating
                ZStack {
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
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                .onAppear {
                    pulseAnimation = true
                }
                
                Text(state.hasError ? "Update Failed" : (state.isComplete ? "Update Complete!" : "Updating Droppy..."))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // Progress Steps
            VStack(alignment: .leading, spacing: 0) {
                ForEach(UpdateStep.allCases.filter { $0 != .complete }, id: \.rawValue) { step in
                    StepRow(step: step, currentStep: state.currentStep, hasError: state.hasError)
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
                        .background(Color.blue.opacity(isLaunchHovering ? 1.0 : 0.8))
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
                }
            }
            .padding(16)
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black)
    }
}

struct StepRow: View {
    let step: UpdateStep
    let currentStep: UpdateStep
    let hasError: Bool
    
    private var isComplete: Bool {
        step.rawValue < currentStep.rawValue
    }
    
    private var isCurrent: Bool {
        step.rawValue == currentStep.rawValue
    }
    
    private var isPending: Bool {
        step.rawValue > currentStep.rawValue
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                } else if isCurrent {
                    if hasError {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                    }
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 20)
            
            Text(step.title)
                .font(.system(size: 13, weight: isComplete || isCurrent ? .medium : .regular))
                .foregroundStyle(isPending ? .secondary : .primary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .opacity(isPending ? 0.5 : 1.0)
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
    }
    
    private func setError(_ message: String) {
        DispatchQueue.main.async {
            self.state.hasError = true
            self.state.errorMessage = message
        }
    }
    
    private func setComplete() {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
        Thread.sleep(forTimeInterval: 1.0)
        
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
        Thread.sleep(forTimeInterval: 0.5)
        
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
        Thread.sleep(forTimeInterval: 0.3)
        
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
        Thread.sleep(forTimeInterval: 0.3)
        
        let unmountProcess = Process()
        unmountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        unmountProcess.arguments = ["detach", "/Volumes/DroppyUpdate", "-quiet"]
        try? unmountProcess.run()
        unmountProcess.waitUntilExit()
        
        try? FileManager.default.removeItem(atPath: dmgPath)
        
        // Complete!
        Thread.sleep(forTimeInterval: 0.5)
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
