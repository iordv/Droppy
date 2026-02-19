//
//  TelepromptyManager.swift
//  Droppy
//
//  Runtime manager for Teleprompty countdown/scroll state.
//

import Combine
import SwiftUI
import QuartzCore

@MainActor
final class TelepromptyManager: ObservableObject {
    static let shared = TelepromptyManager()
    nonisolated let objectWillChange = ObservableObjectPublisher()

    @Published private(set) var isPromptVisible = false
    @Published private(set) var isRunning = false
    @Published private(set) var isCountingDown = false
    @Published private(set) var countdownRemaining = 0
    @Published private(set) var scrollOffset: CGFloat = 0
    @Published var isShelfViewVisible = false
    @Published var isInlineEditorVisible = false

    private var countdownTask: Task<Void, Never>?
    private var tickTimer: Timer?
    private var lastTickTime: CFTimeInterval = 0
    private var activeSpeedPointsPerSecond: Double = PreferenceDefault.telepromptySpeed

    private init() {}

    func start(script: String, speed: Double, countdown: Double) {
        let normalizedScript = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedScript.isEmpty else {
            stop(hidePrompt: true)
            return
        }

        stopTicking()
        countdownTask?.cancel()
        countdownTask = nil

        activeSpeedPointsPerSecond = clampedSpeed(speed)
        scrollOffset = 0
        isInlineEditorVisible = false
        isPromptVisible = true
        isRunning = false

        let totalCountdown = max(0, Int(round(countdown)))
        guard totalCountdown > 0 else {
            beginRunning()
            return
        }

        isCountingDown = true
        countdownRemaining = totalCountdown

        countdownTask = Task { [weak self] in
            guard let self else { return }

            for remaining in stride(from: totalCountdown, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                self.countdownRemaining = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            guard !Task.isCancelled else { return }
            self.isCountingDown = false
            self.countdownRemaining = 0
            self.beginRunning()
        }
    }

    func stop(hidePrompt: Bool = true) {
        countdownTask?.cancel()
        countdownTask = nil

        isCountingDown = false
        countdownRemaining = 0
        isRunning = false

        stopTicking()

        if hidePrompt {
            isPromptVisible = false
        }
    }

    func reset() {
        stop(hidePrompt: false)
        scrollOffset = 0
    }

    func jumpBack(seconds: Double) {
        guard seconds > 0 else { return }
        let backDistance = CGFloat(activeSpeedPointsPerSecond * seconds)
        scrollOffset = max(0, scrollOffset - backDistance)
    }

    func markEndedAndReturnToControls() {
        stop(hidePrompt: true)
    }

    func cleanup() {
        stop(hidePrompt: true)
        scrollOffset = 0
        isShelfViewVisible = false
        isInlineEditorVisible = false
    }

    static func estimatedReadTime(for script: String, speed: Double) -> TimeInterval {
        let words = max(1, script.split { $0.isWhitespace || $0.isNewline }.count)
        let normalizedSpeed = max(40, min(speed, 260))
        let wordsPerMinute = max(70, normalizedSpeed * 1.7)
        return (Double(words) / wordsPerMinute) * 60
    }

    static func estimatedReadTimeLabel(for script: String, speed: Double) -> String {
        let duration = estimatedReadTime(for: script, speed: speed)
        let roundedSeconds = max(1, Int(round(duration)))

        if roundedSeconds < 60 {
            return "Estimated read time: ~\(roundedSeconds)s"
        }

        let minutes = roundedSeconds / 60
        let seconds = roundedSeconds % 60
        if seconds == 0 {
            return "Estimated read time: ~\(minutes)m"
        }
        return "Estimated read time: ~\(minutes)m \(seconds)s"
    }

    private func beginRunning() {
        isCountingDown = false
        countdownRemaining = 0
        isRunning = true
        isPromptVisible = true

        lastTickTime = CACurrentMediaTime()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTick()
            }
        }
        tickTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
        lastTickTime = 0
    }

    private func handleTick() {
        guard isRunning else { return }

        let now = CACurrentMediaTime()
        let delta = lastTickTime > 0 ? max(0, min(now - lastTickTime, 0.1)) : (1.0 / 60.0)
        lastTickTime = now

        scrollOffset += CGFloat(activeSpeedPointsPerSecond * delta)
    }

    private func clampedSpeed(_ value: Double) -> Double {
        max(40, min(value, 260))
    }
}
