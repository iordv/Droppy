//
//  CaffeineManager.swift
//  Droppy
//

import SwiftUI
import IOKit.pwr_mgt
import Observation

enum CaffeineDuration: Equatable, Identifiable {
    case indefinite
    case hours(Int)
    case minutes(Int)
    
    var id: String {
        switch self {
        case .indefinite: return "indefinite"
        case .hours(let h): return "hours_\(h)"
        case .minutes(let m): return "minutes_\(m)"
        }
    }
    
    var displayName: String {
        switch self {
        case .indefinite: return "Indefinite"
        case .hours(let h): return "\(h) hour\(h == 1 ? "" : "s")"
        case .minutes(let m): return "\(m) min"
        }
    }
    
    var totalSeconds: TimeInterval? {
        switch self {
        case .indefinite: return nil
        case .hours(let h): return TimeInterval(h * 3600)
        case .minutes(let m): return TimeInterval(m * 60)
        }
    }
    
    static let hourPresets: [CaffeineDuration] = [.hours(1), .hours(2), .hours(3), .hours(4), .hours(5)]
    static let minutePresets: [CaffeineDuration] = [.minutes(10), .minutes(15), .minutes(25), .minutes(30)]
    
    // UI label
    var shortLabel: String {
        switch self {
        case .indefinite: return "∞"
        case .hours(let h): return "\(h)h"
        case .minutes(let m): return "\(m)m"
        }
    }
}

enum CaffeineMode: String, CaseIterable {
    case displayOnly = "Display Only"
    case systemOnly = "System Only"
    case both = "Both"
    
    var description: String {
        switch self {
        case .displayOnly: return "Keeps screen on, system may sleep"
        case .systemOnly: return "System stays awake, display may dim"
        case .both: return "Full keep-awake"
        }
    }
}

@Observable
final class CaffeineManager {
    static let shared = CaffeineManager()
    
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.caffeineInstalled) var isInstalled = PreferenceDefault.caffeineInstalled
    
    private(set) var isActive: Bool = false
    private(set) var currentDuration: CaffeineDuration = .indefinite
    private(set) var remainingSeconds: TimeInterval = 0
    private(set) var mode: CaffeineMode = .both
    
    // Internal assertion IDs
    private var displayAssertionID: IOPMAssertionID = 0
    private var systemAssertionID: IOPMAssertionID = 0
    
    private var timer: Timer?
    private var endTime: Date?
    
    private init() {}
    
    deinit {
        deactivate()
    }
    
    func activate(duration: CaffeineDuration, mode: CaffeineMode = .both) {
        // Reset state
        deactivate()
        
        self.currentDuration = duration
        self.mode = mode
        
        let reason = "Droppy Caffeine" as CFString
        
        // Prevent display sleep
        if mode == .displayOnly || mode == .both {
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &displayAssertionID
            )
        }
        
        // Prevent idle sleep
        if mode == .systemOnly || mode == .both {
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoIdleSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &systemAssertionID
            )
        }
        
        isActive = true
        
        // Handle timer
        if let totalSeconds = duration.totalSeconds {
            remainingSeconds = totalSeconds
            endTime = Date().addingTimeInterval(totalSeconds)
            startTimer()
        } else {
            remainingSeconds = 0
            endTime = nil
        }
    }
    
    func deactivate() {
        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
        
        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
        }
        
        timer?.invalidate()
        timer = nil
        endTime = nil
        remainingSeconds = 0
        
        isActive = false
    }
    
    func toggle(duration: CaffeineDuration = .indefinite, mode: CaffeineMode = .both) {
        if isActive {
            deactivate()
        } else {
            activate(duration: duration, mode: mode)
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    private func updateTimer() {
        guard let endTime = endTime else { return }
        
        remainingSeconds = max(0, endTime.timeIntervalSinceNow)
        if remainingSeconds <= 0 {
            deactivate()
        }
    }
    
    var formattedRemaining: String {
        if currentDuration == .indefinite { return "∞" }
        guard remainingSeconds > 0 else { return "" }
        
        let hours = Int(remainingSeconds) / 3600
        let minutes = (Int(remainingSeconds) % 3600) / 60
        let seconds = Int(remainingSeconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
