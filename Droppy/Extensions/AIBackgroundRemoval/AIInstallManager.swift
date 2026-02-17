//
//  AIInstallManager.swift
//  Droppy
//
//  Created by Droppy on 11/01/2026.
//  Manages installation of AI background removal dependencies
//

import Foundation
import Combine

private nonisolated final class AIInstallOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    func outputString() -> String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? ""
    }
}

private struct AIInstallProcessResult: Sendable {
    let status: Int32
    let output: String
}

private struct PythonRuntimeInfo: Sendable {
    let major: Int
    let minor: Int
    let machine: String

    var versionString: String {
        "\(major).\(minor)"
    }
}

/// Runs a process while continuously draining output to prevent deadlocks on verbose commands.
private func runAIInstallProcess(executable: String, arguments: [String]) async throws -> AIInstallProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    let handle = outputPipe.fileHandleForReading
    let outputBuffer = AIInstallOutputBuffer()

    handle.readabilityHandler = { fileHandle in
        let chunk = fileHandle.availableData
        outputBuffer.append(chunk)
    }

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AIInstallProcessResult, Error>) in
        process.terminationHandler = { process in
            handle.readabilityHandler = nil
            let remainder = handle.readDataToEndOfFile()
            outputBuffer.append(remainder)
            let output = outputBuffer.outputString()

            continuation.resume(returning: AIInstallProcessResult(status: process.terminationStatus, output: output))
        }

        do {
            try process.run()
        } catch {
            handle.readabilityHandler = nil
            continuation.resume(throwing: error)
        }
    }
}

/// Manages the installation of Python transparent-background package
@MainActor
final class AIInstallManager: ObservableObject {
    static let shared = AIInstallManager()
    static let selectedPythonPathKey = "aiBackgroundRemovalPythonPath"

    nonisolated static var managedVenvURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("Droppy", isDirectory: true)
            .appendingPathComponent("AIBackgroundRemoval", isDirectory: true)
            .appendingPathComponent("venv", isDirectory: true)
    }

    nonisolated static var managedVenvPythonPath: String {
        managedVenvURL.appendingPathComponent("bin/python3").path
    }
    
    @Published var isInstalled = false
    @Published var isInstalling = false
    @Published var installProgress: String = ""
    @Published var installError: String?
    @Published private(set) var activePythonPath: String?
    @Published private(set) var detectedPythonPath: String?
    
    private let installedCacheKey = "aiBackgroundRemovalInstalled"
    private let transparentBackgroundRequirement = "transparent-background==1.2.10"
    
    private init() {
        // Load cached status immediately for instant UI response
        isInstalled = UserDefaults.standard.bool(forKey: installedCacheKey)
        if let cachedPythonPath = UserDefaults.standard.string(forKey: Self.selectedPythonPathKey),
           FileManager.default.fileExists(atPath: cachedPythonPath) {
            activePythonPath = cachedPythonPath
        }
        
        // Always verify in background — handles PearCleaner recovery (UserDefaults wiped
        // but Python packages still on disk) and stale cache scenarios
        checkInstallationStatus()
    }
    
    // MARK: - Installation Check
    
    func checkInstallationStatus() {
        Task {
            let candidates = await pythonCandidatePaths()
            let installCandidates = await installBaseCandidates(from: candidates).paths
            detectedPythonPath = installCandidates.first ?? preferredDetectedPythonPath(from: candidates)
            
            let installedPython = await findPythonWithTransparentBackground(in: candidates)
            setInstalledState(installedPython != nil, pythonPath: installedPython)
            
            if installedPython == nil, let detectedPythonPath {
                activePythonPath = detectedPythonPath
            }
        }
    }
    
    var recommendedManualInstallCommand: String {
        let venvPath = Self.managedVenvURL.path
        let venvPython = Self.managedVenvPythonPath

        if FileManager.default.fileExists(atPath: venvPython) {
            return "\(shellQuote(venvPython)) -m pip install --upgrade \(transparentBackgroundRequirement)"
        }

        let preferredPath = activePythonPath ?? detectedPythonPath
        let python = (preferredPath.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }) ?? "python3"

        return "\(shellQuote(python)) -m venv \(shellQuote(venvPath)) && \(shellQuote(venvPython)) -m pip install --upgrade \(transparentBackgroundRequirement)"
    }
    
    var hasDetectedPythonPath: Bool {
        guard let detectedPythonPath else { return false }
        return FileManager.default.fileExists(atPath: detectedPythonPath)
    }
    
    private func setInstalledState(_ installed: Bool, pythonPath: String?) {
        let previous = isInstalled
        
        isInstalled = installed
        UserDefaults.standard.set(installed, forKey: installedCacheKey)
        if installed {
            installError = nil
        }
        
        if let pythonPath {
            activePythonPath = pythonPath
            UserDefaults.standard.set(pythonPath, forKey: Self.selectedPythonPathKey)
        }
        
        if previous != installed {
            NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.aiBackgroundRemoval)
        }
    }
    
    private func findPythonWithTransparentBackground(in candidates: [String]) async -> String? {
        for pythonPath in candidates {
            if await isTransparentBackgroundInstalled(at: pythonPath) {
                return pythonPath
            }
        }
        return nil
    }
    
    private func isTransparentBackgroundInstalled(at pythonPath: String) async -> Bool {
        do {
            let result = try await runAIInstallProcess(
                executable: pythonPath,
                arguments: ["-c", "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('transparent_background') else 1)"]
            )
            return result.status == 0
        } catch {
            return false
        }
    }
    
    private func pythonCandidatePaths() async -> [String] {
        var candidates: [String] = []

        candidates.append(Self.managedVenvPythonPath)
        
        if let cachedPath = UserDefaults.standard.string(forKey: Self.selectedPythonPathKey) {
            candidates.append(cachedPath)
        }
        
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/usr/bin/python3"
        ])
        
        if let whichPath = await pythonPathFromWhich() {
            candidates.append(whichPath)
        }
        
        var seen: Set<String> = []
        var unique: [String] = []
        for path in candidates {
            guard !path.isEmpty else { continue }
            guard FileManager.default.fileExists(atPath: path) else { continue }
            if seen.insert(path).inserted {
                unique.append(path)
            }
        }
        
        return unique
    }

    private func preferredDetectedPythonPath(from candidates: [String]) -> String? {
        let sorted = candidates.sorted { rankForInstall($0) < rankForInstall($1) }
        return sorted.first { $0 != Self.managedVenvPythonPath } ?? sorted.first
    }
    
    private func pythonPathFromWhich() async -> String? {
        do {
            let result = try await runAIInstallProcess(executable: "/usr/bin/which", arguments: ["python3"])
            guard result.status == 0 else { return nil }
            guard let firstLine = result.output
                .split(separator: "\n")
                .map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
                .first,
                firstLine.hasPrefix("/") else {
                return nil
            }
            return firstLine
        } catch {
            return nil
        }
    }
    
    private func rankForInstall(_ path: String) -> Int {
        if path == Self.managedVenvPythonPath { return -100 }
        if path.hasPrefix("/opt/homebrew/") { return 0 }
        if path.hasPrefix("/usr/local/") { return 1 }
        if path.hasPrefix("/Library/Frameworks/Python.framework/") { return 2 }
        if path == "/usr/bin/python3" { return 9 }
        return 3
    }
    
    private func hasPip(at pythonPath: String) async -> Bool {
        do {
            let result = try await runAIInstallProcess(executable: pythonPath, arguments: ["-m", "pip", "--version"])
            return result.status == 0
        } catch {
            return false
        }
    }
    
    private func ensurePipAvailable(at pythonPath: String) async -> Bool {
        if await hasPip(at: pythonPath) {
            return true
        }
        
        do {
            let bootstrap = try await runAIInstallProcess(
                executable: pythonPath,
                arguments: ["-m", "ensurepip", "--upgrade"]
            )
            if bootstrap.status == 0 {
                return await hasPip(at: pythonPath)
            }
        } catch {
            return false
        }
        
        return false
    }

    private func canCreateVenv(at pythonPath: String) async -> Bool {
        do {
            let result = try await runAIInstallProcess(executable: pythonPath, arguments: ["-m", "venv", "--help"])
            return result.status == 0
        } catch {
            return false
        }
    }

    private func pythonRuntimeInfo(at pythonPath: String) async -> PythonRuntimeInfo? {
        do {
            let result = try await runAIInstallProcess(
                executable: pythonPath,
                arguments: ["-c", "import platform, sys; print(f'{sys.version_info[0]}.{sys.version_info[1]}|{platform.machine()}')"]
            )
            guard result.status == 0 else { return nil }
            guard let firstLine = result.output
                .split(separator: "\n")
                .map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
                .first else {
                return nil
            }
            let parts = firstLine.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }

            let versionParts = parts[0].split(separator: ".", maxSplits: 1).map(String.init)
            guard versionParts.count == 2,
                  let major = Int(versionParts[0]),
                  let minor = Int(versionParts[1]) else {
                return nil
            }

            return PythonRuntimeInfo(
                major: major,
                minor: minor,
                machine: parts[1].lowercased()
            )
        } catch {
            return nil
        }
    }

    private func compatibilityIssue(for info: PythonRuntimeInfo) -> String? {
        let isIntel = info.machine == "x86_64" || info.machine == "amd64" || info.machine == "i386"
        if isIntel && info.major == 3 && info.minor >= 13 {
            return "Intel Macs are currently unsupported on Python \(info.versionString). Use Python 3.12 or older for AI background removal."
        }
        return nil
    }

    private func installBaseCandidates(from candidates: [String]) async -> (paths: [String], issues: [String]) {
        let sorted = candidates
            .filter { $0 != Self.managedVenvPythonPath }
            .sorted { rankForInstall($0) < rankForInstall($1) }

        var usable: [String] = []
        var issues: [String] = []

        for path in sorted {
            guard await canCreateVenv(at: path) else {
                issues.append("venv unavailable at \(path)")
                continue
            }

            if let info = await pythonRuntimeInfo(at: path),
               let issue = compatibilityIssue(for: info) {
                issues.append("\(path): \(issue)")
                continue
            }

            usable.append(path)
        }

        return (usable, issues)
    }

    private func recreateManagedVenv(using basePythonPath: String) async -> AIInstallProcessResult? {
        let venvURL = Self.managedVenvURL
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: venvURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: venvURL.path) {
                try fileManager.removeItem(at: venvURL)
            }

            return try await runAIInstallProcess(
                executable: basePythonPath,
                arguments: ["-m", "venv", venvURL.path]
            )
        } catch {
            return nil
        }
    }
    
    private func isXcodeCliInstalled() async -> Bool {
        do {
            let result = try await runAIInstallProcess(executable: "/usr/bin/xcode-select", arguments: ["-p"])
            return result.status == 0
        } catch {
            return false
        }
    }
    
    // MARK: - Installation
    
    /// Trigger Xcode Command Line Tools installation (shows macOS dialog)
    private func triggerXcodeCliInstall() async -> Bool {
        installProgress = "Python 3 not found. Requesting Command Line Tools…"
        
        do {
            let result = try await runAIInstallProcess(executable: "/usr/bin/xcode-select", arguments: ["--install"])
            if result.status != 0 {
                let output = result.output.lowercased()
                if !output.contains("already installed") {
                    return false
                }
            }
            
            installProgress = "Complete the Command Line Tools prompt, then retry install."
            
            // Poll for up to 3 minutes after prompting install.
            for _ in 0..<36 {
                if await isXcodeCliInstalled() {
                    return true
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
            return await isXcodeCliInstalled()
        } catch {
            return false
        }
    }
    
    func installTransparentBackground() async {
        isInstalling = true
        installProgress = "Checking existing installation…"
        installError = nil
        
        defer {
            isInstalling = false
            checkInstallationStatus()
        }
        
        var candidates = await pythonCandidatePaths()
        var candidateEvaluation = await installBaseCandidates(from: candidates)
        detectedPythonPath = candidateEvaluation.paths.first ?? preferredDetectedPythonPath(from: candidates)
        
        if let installedPython = await findPythonWithTransparentBackground(in: candidates) {
            installProgress = "AI background removal is already installed."
            setInstalledState(true, pythonPath: installedPython)
            return
        }
        
        let systemCandidates = candidates.filter { $0 != Self.managedVenvPythonPath }
        if systemCandidates.isEmpty, !(await isXcodeCliInstalled()) {
            let requested = await triggerXcodeCliInstall()
            if requested {
                candidates = await pythonCandidatePaths()
                candidateEvaluation = await installBaseCandidates(from: candidates)
                detectedPythonPath = candidateEvaluation.paths.first ?? preferredDetectedPythonPath(from: candidates)
            }
        }
        
        let refreshedSystemCandidates = candidates.filter { $0 != Self.managedVenvPythonPath }
        guard !refreshedSystemCandidates.isEmpty else {
            installProgress = ""
            installError = "Python 3 is required. Install Command Line Tools or Python from python.org, then retry."
            return
        }
        
        let installCandidates = candidateEvaluation.paths
        let candidateIssues = candidateEvaluation.issues
        guard !installCandidates.isEmpty else {
            installProgress = ""
            if let compatibilityIssue = candidateIssues.first(where: { $0.localizedCaseInsensitiveContains("intel macs are currently unsupported") }) {
                let cleanedIssue = compatibilityIssue
                    .components(separatedBy: ": ")
                    .last ?? compatibilityIssue
                installError = "No compatible Python found. \(cleanedIssue)"
            } else if candidateIssues.contains(where: { $0.localizedCaseInsensitiveContains("venv unavailable") }) {
                installError = "Python was found, but this runtime cannot create virtual environments. Install Python from python.org and retry."
            } else {
                installError = "No compatible Python runtime found for AI background removal. Install Python 3.12 or run Command Line Tools, then retry."
            }
            return
        }

        let installArgs = [
            "-m", "pip", "install",
            "--upgrade",
            "--disable-pip-version-check",
            transparentBackgroundRequirement
        ]

        var lastError: String?

        for basePythonPath in installCandidates {
            installProgress = "Preparing isolated Python environment…"

            guard let venvResult = await recreateManagedVenv(using: basePythonPath) else {
                lastError = "Failed to create AI Python environment. Try installing Python from python.org and retry."
                continue
            }

            guard venvResult.status == 0 else {
                lastError = formatInstallError(venvResult.output)
                continue
            }

            let venvPythonPath = Self.managedVenvPythonPath
            guard await ensurePipAvailable(at: venvPythonPath) else {
                lastError = "Virtual environment was created, but pip is unavailable. Reinstall Python and retry."
                continue
            }

            activePythonPath = venvPythonPath
            UserDefaults.standard.set(venvPythonPath, forKey: Self.selectedPythonPathKey)
            installProgress = "Installing transparent-background package…"

            do {
                let result = try await runAIInstallProcess(executable: venvPythonPath, arguments: installArgs)
                guard result.status == 0 else {
                    lastError = formatInstallError(result.output)
                    continue
                }
            } catch {
                lastError = "Failed to start installation: \(error.localizedDescription)"
                continue
            }

            guard await isTransparentBackgroundInstalled(at: venvPythonPath) else {
                lastError = "Install finished, but package verification could not confirm transparent-background."
                continue
            }

            installProgress = "Installation complete!"
            setInstalledState(true, pythonPath: venvPythonPath)

            // Keep legacy key for backward compatibility.
            UserDefaults.standard.set(true, forKey: "useLocalBackgroundRemoval")

            // Track extension activation
            AnalyticsService.shared.trackExtensionActivation(extensionId: "aiBackgroundRemoval")
            return
        }

        installProgress = ""
        installError = lastError ?? formatInstallError(candidateIssues.joined(separator: "\n"))
    }
    
    private func formatInstallError(_ rawOutput: String) -> String {
        let cleanedOutput = stripAnsiEscapeCodes(in: rawOutput)
        let trimmed = cleanedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        
        if normalized.contains("no module named pip") {
            return "pip is missing for this Python install. Install pip, then retry."
        }
        
        if normalized.contains("externally-managed-environment") {
            return "Python refused package changes in this environment. Droppy now installs in an isolated venv; retry install."
        }

        if normalized.contains("resolutionimpossible")
            || normalized.contains("no matching distribution found for torch")
            || (normalized.contains("no matching distributions available for your environment") && normalized.contains("torch")) {
            return "This Python build is incompatible with required AI dependencies (torch). On Intel Macs, use Python 3.12 or older."
        }
        
        if normalized.contains("permission denied") {
            return "Permission denied while installing Python packages. Check your user account permissions and retry."
        }
        
        if normalized.contains("network") || normalized.contains("timed out") || normalized.contains("ssl") {
            return "Network error while downloading dependencies. Check connection and retry."
        }
        
        if trimmed.isEmpty {
            return "Installation failed. Try again, then run the manual command if it still fails."
        }

        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let meaningfulLines = lines.filter { line in
            let lower = line.lowercased()
            return !lower.hasPrefix("[notice]") && !lower.hasPrefix("warning:")
        }

        let priorityLine = meaningfulLines.first { line in
            let lower = line.lowercased()
            return lower.contains("error")
                || lower.contains("failed")
                || lower.contains("permission denied")
                || lower.contains("timed out")
                || lower.contains("no matching distribution")
                || lower.contains("unsupported")
                || lower.contains("not found")
        }

        let selectedLine = priorityLine ?? meaningfulLines.first ?? String(trimmed.prefix(220))
        let normalizedLine = selectedLine
            .replacingOccurrences(of: #"^error:\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^fatal:\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return "Installation failed: \(normalizedLine.prefix(180))"
    }

    private func stripAnsiEscapeCodes(in text: String) -> String {
        text.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*[A-Za-z]",
            with: "",
            options: .regularExpression
        )
    }
    
    // MARK: - Uninstall
    
    func uninstallTransparentBackground() async {
        isInstalling = true
        installProgress = "Removing package…"
        installError = nil
        
        defer {
            isInstalling = false
            checkInstallationStatus()
        }
        
        let candidates = await pythonCandidatePaths()
        var uninstallCandidates: [String] = []
        if let activePythonPath {
            uninstallCandidates.append(activePythonPath)
        }
        uninstallCandidates.append(contentsOf: candidates)
        
        var seen: Set<String> = []
        uninstallCandidates = uninstallCandidates.filter { seen.insert($0).inserted }
        
        var selectedPython: String?
        for path in uninstallCandidates {
            if await hasPip(at: path) {
                selectedPython = path
                break
            }
        }
        
        guard let pythonPath = selectedPython else {
            installError = "Python 3 not found. Cannot uninstall."
            return
        }
        
        do {
            let result = try await runAIInstallProcess(
                executable: pythonPath,
                arguments: ["-m", "pip", "uninstall", "-y", "transparent-background"]
            )
            
            let output = result.output.lowercased()
            if result.status == 0 || output.contains("not installed") {
                if pythonPath == Self.managedVenvPythonPath {
                    removeManagedVenvIfPresent()
                }
                setInstalledState(false, pythonPath: nil)
                
                // Keep legacy key for backward compatibility.
                UserDefaults.standard.set(false, forKey: "useLocalBackgroundRemoval")
            } else {
                installError = "Failed to uninstall: \(result.output.prefix(200))"
            }
        } catch {
            installError = "Failed to uninstall: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Extension Removal Cleanup
    
    /// Clean up all AI Background Removal resources when extension is removed
    func cleanup() {
        Task {
            // Uninstall the Python package
            await uninstallTransparentBackground()
            
            // Clear cached state
            UserDefaults.standard.removeObject(forKey: installedCacheKey)
            UserDefaults.standard.removeObject(forKey: Self.selectedPythonPathKey)
            UserDefaults.standard.removeObject(forKey: "useLocalBackgroundRemoval")
            UserDefaults.standard.removeObject(forKey: "aiBackgroundRemovalTracked")
            removeManagedVenvIfPresent()
            
            // Reset state
            isInstalled = false
            activePythonPath = nil
            installProgress = ""
            installError = nil
            
            NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.aiBackgroundRemoval)
            
            print("[AIInstallManager] Cleanup complete")
        }
    }

    private func removeManagedVenvIfPresent() {
        let venvURL = Self.managedVenvURL
        if FileManager.default.fileExists(atPath: venvURL.path) {
            try? FileManager.default.removeItem(at: venvURL)
        }
    }
    
    private func shellQuote(_ value: String) -> String {
        if value.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "'\"$`\\"))) == nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
