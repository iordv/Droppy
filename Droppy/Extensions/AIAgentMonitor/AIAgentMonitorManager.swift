//
//  AIAgentMonitorManager.swift
//  Droppy
//
//  Manages AI coding agent status via OTLP telemetry
//

import SwiftUI
import Combine

@MainActor
class AIAgentMonitorManager: ObservableObject {

    // MARK: - Singleton

    static let shared = AIAgentMonitorManager()

    // MARK: - Published State

    @Published private(set) var isActive: Bool = false
    @Published private(set) var currentSource: AgentSource = .unknown
    @Published private(set) var lastActivity: Date?
    @Published private(set) var currentToolCall: String?
    @Published private(set) var tokenCount: Int = 0
    @Published private(set) var sessionTokens: Int = 0

    // MARK: - Metrics

    @Published private(set) var sessionCost: Double = 0.0
    @Published private(set) var inputTokens: Int = 0
    @Published private(set) var outputTokens: Int = 0
    @Published private(set) var cacheReadTokens: Int = 0
    @Published private(set) var cacheCreationTokens: Int = 0
    @Published private(set) var activeTimeSeconds: Int = 0
    @Published private(set) var linesAdded: Int = 0
    @Published private(set) var linesRemoved: Int = 0

    // MARK: - Computed Properties

    var totalTokens: Int {
        inputTokens + outputTokens
    }

    var formattedCost: String {
        if sessionCost < 0.01 {
            return String(format: "$%.4f", sessionCost)
        }
        return String(format: "$%.2f", sessionCost)
    }

    var formattedActiveTime: String {
        let minutes = activeTimeSeconds / 60
        let seconds = activeTimeSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    // MARK: - Settings

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "aiAgentMonitor.enabled")
            if isEnabled {
                startServer()
            } else {
                stopServer()
            }
        }
    }

    @Published var borderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(borderEnabled, forKey: "aiAgentMonitor.borderEnabled")
        }
    }

    @Published var borderPulsing: Bool {
        didSet {
            UserDefaults.standard.set(borderPulsing, forKey: "aiAgentMonitor.borderPulsing")
        }
    }

    @Published var glowEnhanced: Bool {
        didSet {
            UserDefaults.standard.set(glowEnhanced, forKey: "aiAgentMonitor.glowEnhanced")
        }
    }

    /// Temporary test mode to preview the border effect
    @Published var isTestMode: Bool = false

    @Published var otlpPort: UInt16 {
        didSet {
            UserDefaults.standard.set(Int(otlpPort), forKey: "aiAgentMonitor.otlpPort")
        }
    }

    // MARK: - Private

    private var server: OTLPServer?
    private var activityTimer: Timer?

    /// Duration after which agent is considered inactive
    private let inactivityTimeout: TimeInterval = 5.0

    // MARK: - Init

    private init() {
        // Load settings from UserDefaults
        self.isEnabled = UserDefaults.standard.bool(forKey: "aiAgentMonitor.enabled")
        self.borderEnabled = UserDefaults.standard.object(forKey: "aiAgentMonitor.borderEnabled") as? Bool ?? true
        self.borderPulsing = UserDefaults.standard.object(forKey: "aiAgentMonitor.borderPulsing") as? Bool ?? true
        self.glowEnhanced = UserDefaults.standard.object(forKey: "aiAgentMonitor.glowEnhanced") as? Bool ?? true
        self.otlpPort = UInt16(UserDefaults.standard.integer(forKey: "aiAgentMonitor.otlpPort"))
        if self.otlpPort == 0 {
            self.otlpPort = 4318 // Default OTLP port
        }

        // Start server if enabled
        if isEnabled {
            startServer()
        }
    }

    // MARK: - Server Control

    func startServer() {
        guard server == nil else { return }
        guard isEnabled else { return }

        server = OTLPServer(port: otlpPort) { [weak self] data, path in
            // Debug: write to file
            let debugMsg = "[\(Date())] Manager handler called, data size=\(data.count)\n"
            if let debugData = debugMsg.data(using: .utf8) {
                let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("droppy_manager_debug.txt")
                if FileManager.default.fileExists(atPath: debugFile.path) {
                    if let handle = try? FileHandle(forWritingTo: debugFile) {
                        handle.seekToEndOfFile()
                        handle.write(debugData)
                        handle.closeFile()
                    }
                } else {
                    try? debugData.write(to: debugFile)
                }
            }

            Task { @MainActor in
                self?.handleTelemetry(data: data, path: path)
            }
        }

        server?.start()
        print("AI Agent Monitor: OTLP server started on port \(otlpPort)")
    }

    func stopServer() {
        server?.stop()
        server = nil

        isActive = false
        currentSource = .unknown
        currentToolCall = nil

        print("AI Agent Monitor: OTLP server stopped")
    }

    // MARK: - Telemetry Handling

    private func handleTelemetry(data: Data, path: String) {
        // Detect source from payload
        let payloadText = String(data: data, encoding: .utf8) ?? ""

        let detectedSource = AgentSource.detect(from: payloadText)

        // Debug: write state to file
        let debugMsg = "[\(Date())] handleTelemetry: payload=\(payloadText.prefix(100)), detected=\(detectedSource.displayName), setting isActive=true\n"
        if let debugData = debugMsg.data(using: .utf8) {
            let debugFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("droppy_telemetry_debug.txt")
            if FileManager.default.fileExists(atPath: debugFile.path) {
                if let handle = try? FileHandle(forWritingTo: debugFile) {
                    handle.seekToEndOfFile()
                    handle.write(debugData)
                    handle.closeFile()
                }
            } else {
                try? debugData.write(to: debugFile)
            }
        }

        // Update state
        currentSource = detectedSource
        isActive = true
        lastActivity = Date()

        // Parse tool call if present
        if let toolCall = parseToolCall(from: payloadText) {
            currentToolCall = toolCall
        }

        // Parse token count if present
        if let tokens = parseTokenCount(from: payloadText) {
            tokenCount = tokens
            sessionTokens += tokens
        }

        // Parse metrics from OTLP format
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            parseMetrics(from: json)
        }

        // Reset activity timer
        resetActivityTimer()

        // Track extension usage
        if !UserDefaults.standard.bool(forKey: "aiAgentMonitorTracked") {
            UserDefaults.standard.set(true, forKey: "aiAgentMonitorTracked")
        }
    }

    // MARK: - Parsing Helpers

    private func parseToolCall(from text: String) -> String? {
        // Look for tool_call or similar patterns
        if text.contains("tool_call") || text.contains("toolCall") {
            // Extract tool name
            if let range = text.range(of: "\"name\":\"([^\"]+)\"", options: .regularExpression) {
                let match = String(text[range])
                return match
                    .replacingOccurrences(of: "\"name\":\"", with: "")
                    .replacingOccurrences(of: "\"", with: "")
            }
        }

        return nil
    }

    private func parseTokenCount(from text: String) -> Int? {
        // Look for token count in payload
        if let range = text.range(of: "\"tokens\":(\\d+)", options: .regularExpression) {
            let match = String(text[range])
            let numberString = match.replacingOccurrences(of: "\"tokens\":", with: "")
            return Int(numberString)
        }
        return nil
    }

    // MARK: - OTLP Metrics Parsing

    private func parseMetrics(from json: [String: Any]) {
        // Check for resourceMetrics (metrics format)
        if let resourceMetrics = json["resourceMetrics"] as? [[String: Any]] {
            for resourceMetric in resourceMetrics {
                if let scopeMetrics = resourceMetric["scopeMetrics"] as? [[String: Any]] {
                    for scopeMetric in scopeMetrics {
                        if let metrics = scopeMetric["metrics"] as? [[String: Any]] {
                            for metric in metrics {
                                processMetric(metric)
                            }
                        }
                    }
                }
            }
        }
    }

    private func processMetric(_ metric: [String: Any]) {
        guard let name = metric["name"] as? String else { return }

        // Get value from sum or gauge dataPoints
        var value: Double = 0
        var attributes: [String: String] = [:]

        if let sum = metric["sum"] as? [String: Any],
           let dataPoints = sum["dataPoints"] as? [[String: Any]],
           let firstPoint = dataPoints.first {
            if let doubleValue = firstPoint["asDouble"] as? Double {
                value = doubleValue
            } else if let intValue = firstPoint["asInt"] as? String {
                value = Double(intValue) ?? 0
            }
            // Parse attributes
            if let attrs = firstPoint["attributes"] as? [[String: Any]] {
                for attr in attrs {
                    if let key = attr["key"] as? String,
                       let val = attr["value"] as? [String: Any],
                       let stringVal = val["stringValue"] as? String {
                        attributes[key] = stringVal
                    }
                }
            }
        } else if let gauge = metric["gauge"] as? [String: Any],
                  let dataPoints = gauge["dataPoints"] as? [[String: Any]],
                  let firstPoint = dataPoints.first {
            if let doubleValue = firstPoint["asDouble"] as? Double {
                value = doubleValue
            } else if let intValue = firstPoint["asInt"] as? String {
                value = Double(intValue) ?? 0
            }
            // Parse attributes
            if let attrs = firstPoint["attributes"] as? [[String: Any]] {
                for attr in attrs {
                    if let key = attr["key"] as? String,
                       let val = attr["value"] as? [String: Any],
                       let stringVal = val["stringValue"] as? String {
                        attributes[key] = stringVal
                    }
                }
            }
        }

        switch name {
        case "claude_code.cost.usage":
            self.sessionCost += value
        case "claude_code.token.usage":
            let type = attributes["type"] ?? ""
            switch type {
            case "input": self.inputTokens += Int(value)
            case "output": self.outputTokens += Int(value)
            case "cacheRead": self.cacheReadTokens += Int(value)
            case "cacheCreation": self.cacheCreationTokens += Int(value)
            default: break
            }
        case "claude_code.active_time.total":
            self.activeTimeSeconds = Int(value)
        case "claude_code.lines_of_code.count":
            let type = attributes["type"] ?? ""
            if type == "added" {
                self.linesAdded += Int(value)
            } else if type == "removed" {
                self.linesRemoved += Int(value)
            }
        default:
            break
        }
    }

    // MARK: - Activity Timer

    private func resetActivityTimer() {
        activityTimer?.invalidate()

        activityTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.handleInactivity()
            }
        }
    }

    private func handleInactivity() {
        isActive = false
        currentToolCall = nil
    }

    // MARK: - Session Management

    func resetSession() {
        sessionTokens = 0
        sessionCost = 0.0
        inputTokens = 0
        outputTokens = 0
        cacheReadTokens = 0
        cacheCreationTokens = 0
        activeTimeSeconds = 0
        linesAdded = 0
        linesRemoved = 0
    }

    // MARK: - Cleanup

    func cleanup() {
        stopServer()
        UserDefaults.standard.removeObject(forKey: "aiAgentMonitor.enabled")
        UserDefaults.standard.removeObject(forKey: "aiAgentMonitor.borderEnabled")
        UserDefaults.standard.removeObject(forKey: "aiAgentMonitor.borderPulsing")
        UserDefaults.standard.removeObject(forKey: "aiAgentMonitor.glowEnhanced")
        UserDefaults.standard.removeObject(forKey: "aiAgentMonitor.otlpPort")
        UserDefaults.standard.removeObject(forKey: "aiAgentMonitorTracked")
    }

    // MARK: - Test Mode

    /// Trigger test mode to preview the border effect
    func testBorder() {
        isTestMode = true
        // Auto-disable after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isTestMode = false
        }
    }
}
