//
//  VoiceTranscribeMenuBar.swift
//  Droppy
//
//  Menu bar integration for Voice Transcribe quick recording
//

import SwiftUI
import AppKit

@MainActor
final class VoiceTranscribeMenuBar {
    static let shared = VoiceTranscribeMenuBar()
    
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var isRecording = false
    private var isInvisiRecording = false // Invisi-record mode (no window)
    
    private init() {}
    
    // MARK: - Public API
    
    /// Show or hide the menu bar item
    func setVisible(_ visible: Bool) {
        if visible {
            setupStatusItem()
        } else {
            removeStatusItem()
        }
    }
    
    /// Update menu bar icon to show recording state
    func setRecordingState(_ recording: Bool) {
        isRecording = recording
        updateIcon()
        updateMenuForState()
        
        // If recording stopped and it was invisi-record, show result
        if !recording && isInvisiRecording {
            isInvisiRecording = false
            // Wait for transcription to complete, then show result
            Task { @MainActor in
                // Poll for completion
                for _ in 0..<120 {
                    try? await Task.sleep(for: .milliseconds(500))
                    let state = VoiceTranscribeManager.shared.state
                    if case .complete = state {
                        VoiceTranscriptionResultController.shared.showResult()
                        return
                    } else if case .error = state {
                        return
                    } else if case .idle = state {
                        return
                    }
                }
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupStatusItem() {
        guard statusItem == nil else { return }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set up button action for click-to-stop
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        updateIcon()
        setupMenu()
        
        print("VoiceTranscribe: Menu bar item shown")
    }
    
    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        
        let iconName = isRecording ? "VoiceTranscribeRecordingIcon" : "VoiceTranscribeMenuBarIcon"
        let image = NSImage(named: iconName)
        image?.size = NSSize(width: 22, height: 22)
        image?.isTemplate = true
        button.image = image
    }
    
    private func removeStatusItem() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
        menu = nil
        
        print("VoiceTranscribe: Menu bar item hidden")
    }
    
    private func setupMenu() {
        menu = NSMenu()
        updateMenuForState()
    }
    
    private func updateMenuForState() {
        guard let menu = menu else { return }
        menu.removeAllItems()
        
        if isRecording {
            // Recording state menu
            let stopItem = NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "")
            stopItem.target = self
            stopItem.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: nil)
            menu.addItem(stopItem)
        } else {
            // Idle state menu
            let recordItem = NSMenuItem(title: "Quick Record", action: #selector(startQuickRecord), keyEquivalent: "")
            recordItem.target = self
            recordItem.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: nil)
            menu.addItem(recordItem)
            
            let invisiItem = NSMenuItem(title: "Invisi-record", action: #selector(startInvisiRecord), keyEquivalent: "")
            invisiItem.target = self
            invisiItem.image = NSImage(systemSymbolName: "eye.slash.circle", accessibilityDescription: nil)
            menu.addItem(invisiItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let settingsItem = NSMenuItem(title: "Voice Transcribe Settings...", action: #selector(openSettings), keyEquivalent: "")
            settingsItem.target = self
            settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
            menu.addItem(settingsItem)
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        // If recording, one click stops it
        if isRecording {
            stopRecording()
        } else {
            // Show menu
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            // Remove menu reference so click handler works next time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.statusItem?.menu = nil
            }
        }
    }
    
    @objc private func startQuickRecord() {
        Task { @MainActor in
            isInvisiRecording = false
            VoiceRecordingWindowController.shared.showAndStartRecording()
        }
    }
    
    @objc private func startInvisiRecord() {
        Task { @MainActor in
            isInvisiRecording = true
            // Start recording without showing window
            VoiceTranscribeManager.shared.startRecording()
        }
    }
    
    @objc private func stopRecording() {
        Task { @MainActor in
            if isInvisiRecording {
                // Stop invisi-recording - transcription will trigger result window via setRecordingState
                VoiceTranscribeManager.shared.stopRecording()
            } else {
                // Stop normal recording
                VoiceRecordingWindowController.shared.stopRecordingAndTranscribe()
            }
        }
    }
    
    @objc private func openSettings() {
        Task { @MainActor in
            SettingsWindowController.shared.showSettings(openingExtension: .voiceTranscribe)
        }
    }
}
