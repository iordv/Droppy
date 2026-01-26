//
//  LockScreenMediaPanelManager.swift
//  Droppy
//
//  Created by Droppy on 26/01/2026.
//  Manages the lock screen media panel - shows music controls on the macOS lock screen
//  Uses SkyLight.framework private APIs via SkyLightWindow package
//

import Foundation
import AppKit
import SwiftUI
import SkyLightWindow
import Combine

/// Animation timing constants for lock screen panel transitions
enum LockScreenMediaAnimationTimings {
    static let panelShow: TimeInterval = 0.2
    static let panelHide: TimeInterval = 0.1
}

/// Animator for panel visibility state - allows SwiftUI to animate entry/exit
@MainActor
final class LockScreenMediaPanelAnimator: ObservableObject {
    @Published var isPresented: Bool = false
}

/// Manages the floating media panel that appears on the macOS lock screen
/// Uses SkyLightWindow to delegate windows to the system lock screen space
@MainActor
final class LockScreenMediaPanelManager {
    static let shared = LockScreenMediaPanelManager()
    
    // MARK: - Window State
    private var panelWindow: NSWindow?
    private var hasDelegated = false
    private var cancellables = Set<AnyCancellable>()
    private let panelAnimator = LockScreenMediaPanelAnimator()
    private var hideTask: Task<Void, Never>?
    private var screenChangeObserver: NSObjectProtocol?
    
    // MARK: - Panel Dimensions (must match LockScreenMediaPanelView)
    private let panelWidth: CGFloat = 380
    private let panelHeight: CGFloat = 160
    private let panelCornerRadius: CGFloat = 24
    
    // MARK: - Dependencies
    private weak var musicManager: MusicManager?
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
        print("LockScreenMediaPanelManager: 🔒 Initialized")
    }
    
    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        cancellables.removeAll()
    }
    
    // MARK: - Configuration
    
    /// Configure with dependencies
    func configure(musicManager: MusicManager) {
        self.musicManager = musicManager
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Listen for screen geometry changes
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleScreenGeometryChange()
            }
        }
    }
    
    // MARK: - Public API
    
    /// Show the lock screen media panel
    /// Called by LockScreenManager when screen locks
    func showPanel() {
        // Check if feature is enabled
        guard UserDefaults.standard.preference(
            AppPreferenceKey.enableLockScreenMediaWidget,
            default: PreferenceDefault.enableLockScreenMediaWidget
        ) else {
            print("LockScreenMediaPanelManager: ⏭️ Widget disabled in settings")
            return
        }
        
        // Check if media is available
        guard let musicManager = musicManager, 
              !musicManager.songTitle.isEmpty || musicManager.isPlaying || musicManager.wasRecentlyPlaying else {
            print("LockScreenMediaPanelManager: ⏭️ No media content to display")
            return
        }
        
        // Get the built-in display (where lock screen appears)
        // CRITICAL: Use builtInWithNotch, NOT main - main could be an external monitor!
        guard let screen = NSScreen.builtInWithNotch ?? NSScreen.main else {
            print("LockScreenMediaPanelManager: ⚠️ No built-in screen available")
            return
        }
        
        print("LockScreenMediaPanelManager: 🎵 Showing lock screen panel on: \(screen.localizedName)")
        
        let targetFrame = calculatePanelFrame(for: screen)
        
        let window: NSWindow
        
        if let existingWindow = panelWindow {
            window = existingWindow
        } else {
            window = createPanelWindow(frame: targetFrame)
            panelWindow = window
            hasDelegated = false
        }
        
        // Update frame for current screen
        window.setFrame(targetFrame, display: true)
        
        // Cancel any pending hide
        hideTask?.cancel()
        panelAnimator.isPresented = false
        
        // Set up content view
        let hostingView = NSHostingView(rootView: 
            LockScreenMediaPanelView(animator: panelAnimator)
                .environmentObject(musicManager)
        )
        hostingView.frame = NSRect(origin: .zero, size: targetFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        
        // Set up rounded corners
        if let content = window.contentView {
            content.wantsLayer = true
            content.layer?.masksToBounds = true
            content.layer?.cornerRadius = panelCornerRadius
            content.layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        // Delegate to SkyLight for lock screen visibility
        if !hasDelegated {
            SkyLightOperator.shared.delegateWindow(window)
            hasDelegated = true
            print("LockScreenMediaPanelManager: ✅ Window delegated to SkyLight space")
        }
        
        // Show window
        window.orderFrontRegardless()
        
        // Animate in
        DispatchQueue.main.async { [weak self] in
            self?.panelAnimator.isPresented = true
        }
        
        print("LockScreenMediaPanelManager: ✅ Panel visible")
    }
    
    /// Hide the lock screen media panel
    /// Called by LockScreenManager when screen unlocks
    func hidePanel() {
        print("LockScreenMediaPanelManager: 🚪 Hiding panel")
        
        // SKYLIGHT FIX: Reset DragMonitor state on screen unlock
        // After SkyLight delegation, the drag polling state can get stuck (isDragging=true)
        // which blocks all hover detection in NotchWindow. Force reset on unlock.
        DragMonitor.shared.forceReset()
        
        panelAnimator.isPresented = false
        hideTask?.cancel()
        
        guard let window = panelWindow else {
            print("LockScreenMediaPanelManager: No panel to hide")
            return
        }
        
        // Delay to allow fade out animation
        hideTask = Task { [weak window] in
            try? await Task.sleep(for: .milliseconds(Int(LockScreenMediaAnimationTimings.panelHide * 1000)))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                window?.orderOut(nil)
                window?.contentView = nil
                print("LockScreenMediaPanelManager: ✅ Panel hidden")
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func createPanelWindow(frame: NSRect) -> NSWindow {
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isMovable = false
        window.hasShadow = true
        
        return window
    }
    
    private func calculatePanelFrame(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        
        // Center horizontally
        let originX = screenFrame.midX - (panelWidth / 2)
        
        // Position slightly above center (like iOS lock screen widgets)
        let baseY = screenFrame.origin.y + (screenFrame.height / 2) - panelHeight
        let offsetY = baseY - 60  // Push up a bit from center
        
        return NSRect(x: originX, y: offsetY, width: panelWidth, height: panelHeight)
    }
    
    private func handleScreenGeometryChange() {
        guard let window = panelWindow, window.isVisible else { return }
        // Use built-in display, same as showPanel()
        guard let screen = NSScreen.builtInWithNotch ?? NSScreen.main else { return }
        
        let newFrame = calculatePanelFrame(for: screen)
        window.setFrame(newFrame, display: true)
        
        print("LockScreenMediaPanelManager: 📐 Realigned panel after screen change")
    }
}
