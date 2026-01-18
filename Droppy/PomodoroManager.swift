//
//  PomodoroManager.swift
//  Droppy
//
//  Created by Droppy on 18/01/2026.
//  Beautiful Pomodoro timer state management
//

import SwiftUI
import UserNotifications
import Combine

/// Centralized state management for the Pomodoro timer
/// Follows the singleton pattern (like VolumeManager, BatteryManager)
@Observable
final class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()
    
    // MARK: - Published State
    
    /// Whether the timer is currently active (running or paused)
    var isActive: Bool = false
    
    /// Whether the timer is paused
    var isPaused: Bool = false
    
    /// Remaining seconds on the timer
    var remainingSeconds: Int = 0
    
    /// Total duration in seconds (for progress calculation)
    var totalSeconds: Int = 0
    
    /// Timestamp for HUD triggering (notifies observers of state changes)
    var lastChangeAt: Date = Date()
    
    /// Whether to show the HUD after timer reveal gesture
    var showHUD: Bool = false
    
    // MARK: - Preset Durations
    
    enum Preset: Int, CaseIterable {
        case quick = 300       // 5 minutes
        case short = 900       // 15 minutes
        case standard = 1500   // 25 minutes (classic Pomodoro)
        case long = 2700       // 45 minutes
        
        var label: String {
            switch self {
            case .quick: return "5m"
            case .short: return "15m"
            case .standard: return "25m"
            case .long: return "45m"
            }
        }
        
        var seconds: Int { rawValue }
    }
    
    /// Current preset for quick-start
    var currentPreset: Preset = .standard
    
    // MARK: - Private State
    
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.droppy.pomodoro", qos: .userInteractive)
    
    // MARK: - Computed Properties
    
    /// Progress from 0.0 to 1.0
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
    
    /// Remaining progress from 1.0 to 0.0 (for countdown visualization)
    var remainingProgress: Double {
        guard totalSeconds > 0 else { return 1 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }
    
    /// Formatted time string (MM:SS)
    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Short formatted time (for HUD)
    var shortFormattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", seconds))"
        } else {
            return "\(seconds)s"
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        requestNotificationPermission()
    }
    
    // MARK: - Timer Control
    
    /// Start the timer with the current preset
    func start(preset: Preset? = nil) {
        if let preset = preset {
            currentPreset = preset
        }
        start(seconds: currentPreset.seconds)
    }
    
    /// Start the timer with a custom duration
    func start(seconds: Int) {
        stop() // Cancel any existing timer
        
        totalSeconds = seconds
        remainingSeconds = seconds
        isActive = true
        isPaused = false
        showHUD = true
        lastChangeAt = Date()
        
        startInternalTimer()
    }
    
    /// Pause the timer
    func pause() {
        guard isActive && !isPaused else { return }
        isPaused = true
        timer?.suspend()
        lastChangeAt = Date()
    }
    
    /// Resume the timer
    func resume() {
        guard isActive && isPaused else { return }
        isPaused = false
        timer?.resume()
        lastChangeAt = Date()
    }
    
    /// Toggle pause/resume
    func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }
    
    /// Stop and reset the timer
    func stop() {
        timer?.cancel()
        timer = nil
        isActive = false
        isPaused = false
        remainingSeconds = 0
        totalSeconds = 0
        showHUD = false
        lastChangeAt = Date()
    }
    
    /// Add time to the running timer
    func addTime(seconds: Int) {
        guard isActive else { return }
        remainingSeconds += seconds
        totalSeconds += seconds
        lastChangeAt = Date()
    }
    
    // MARK: - Internal Timer
    
    private func startInternalTimer() {
        timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer?.schedule(deadline: .now() + 1, repeating: 1)
        
        timer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                } else {
                    self.timerCompleted()
                }
            }
        }
        
        timer?.resume()
    }
    
    private func timerCompleted() {
        timer?.cancel()
        timer = nil
        
        isActive = false
        isPaused = false
        lastChangeAt = Date()
        
        // Send notification
        sendCompletionNotification()
        
        // Keep HUD visible briefly to show completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showHUD = false
        }
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete!"
        content.body = "Your \(currentPreset.label) timer has finished."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
