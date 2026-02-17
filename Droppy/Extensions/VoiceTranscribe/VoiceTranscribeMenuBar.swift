//
//  VoiceTranscribeMenuBar.swift
//  Droppy
//
//  Menu bar integration for Voice Transcribe quick recording
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class VoiceTranscribeMenuBar {
    static let shared = VoiceTranscribeMenuBar()
    
    private var statusItem: NSStatusItem?
    private var activeMenu: NSMenu?
    private var isRecording = false
    private var isInvisiRecording = false // Invisi-record mode (no window)
    private lazy var idleMenu: NSMenu = makeIdleMenu()
    private lazy var recordingMenu: NSMenu = makeRecordingMenu()
    private lazy var idleIconImage: NSImage? = configuredIcon(named: "VoiceTranscribeMenuBarIcon")
    private lazy var recordingIconImage: NSImage? = configuredIcon(named: "VoiceTranscribeRecordingIcon")
    
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
            button.setAccessibilityIdentifier("DroppyVoiceTranscribe")
            button.setAccessibilityTitle("Droppy Voice Transcribe")
        }
        
        updateIcon()
        updateMenuForState()
        
        print("VoiceTranscribe: Menu bar item shown")
    }
    
    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        button.image = isRecording ? recordingIconImage : idleIconImage
    }
    
    private func removeStatusItem() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
        activeMenu = nil
        
        print("VoiceTranscribe: Menu bar item hidden")
    }
    
    private func updateMenuForState() {
        activeMenu = isRecording ? recordingMenu : idleMenu
    }

    private func makeIdleMenu() -> NSMenu {
        let menu = NSMenu()

        let recordItem = NSMenuItem(title: "Quick Record", action: #selector(startQuickRecord), keyEquivalent: "")
        recordItem.target = self
        recordItem.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: nil)
        menu.addItem(recordItem)

        let invisiItem = NSMenuItem(title: "Invisi-record", action: #selector(startInvisiRecord), keyEquivalent: "")
        invisiItem.target = self
        invisiItem.image = NSImage(systemSymbolName: "eye.slash.circle", accessibilityDescription: nil)
        menu.addItem(invisiItem)

        let uploadItem = NSMenuItem(title: "Upload Audio File…", action: #selector(uploadAudioFile), keyEquivalent: "")
        uploadItem.target = self
        uploadItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
        menu.addItem(uploadItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Voice Transcribe Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        return menu
    }

    private func makeRecordingMenu() -> NSMenu {
        let menu = NSMenu()
        let stopItem = NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "")
        stopItem.target = self
        stopItem.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: nil)
        menu.addItem(stopItem)
        return menu
    }

    private func configuredIcon(named name: String) -> NSImage? {
        guard let image = NSImage(named: name) else { return nil }
        image.size = NSSize(width: 22, height: 22)
        image.isTemplate = true
        return image
    }
    
    // MARK: - Actions
    
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        // If recording, one click stops it
        if isRecording {
            stopRecording()
        } else {
            // Pop up directly without using deprecated NSStatusItem.popUpMenu.
            if let menu = activeMenu, let button = statusItem?.button {
                menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.midX, y: button.bounds.maxY), in: button)
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
                // Stop invisi-recording - show the transcribing progress window
                isInvisiRecording = false
                VoiceTranscribeManager.shared.stopRecording()
                // Show the progress window in bottom right so user sees transcription
                VoiceRecordingWindowController.shared.showTranscribingProgress()
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
    
    @objc private func uploadAudioFile() {
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.title = "Select Audio File to Transcribe"
            panel.allowedContentTypes = [
                .audio,
                .mp3,
                .wav,
                .mpeg4Audio,
                .aiff
            ]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            
            let response = await panel.begin()
            
            if response == .OK, let url = panel.url {
                // Show transcribing progress window
                VoiceRecordingWindowController.shared.showTranscribingProgress()
                
                // Start transcription of the selected file
                VoiceTranscribeManager.shared.transcribeFile(at: url)
            }
        }
    }
}
