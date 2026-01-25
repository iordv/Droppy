//
//  BasketQuickActionsBar.swift
//  Droppy
//
//  Quick Actions bar - simple, snappy animation
//  Supports transparency mode
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Quick Actions Bar

struct BasketQuickActionsBar: View {
    let items: [DroppedItem]
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var isBoltTargeted = false  // Track when files are dragged over collapsed bolt
    
    private let buttonSize: CGFloat = 48
    private let spacing: CGFloat = 12
    
    // Colors based on transparency mode
    private var buttonFill: Color {
        useTransparentBackground ? Color.white.opacity(0.12) : Color.black
    }
    @State private var isBarAreaTargeted = false  // Track when drag is over the bar area (between buttons)
    
    /// Computed width of expanded bar area: 4 buttons + 3 gaps
    private var expandedBarWidth: CGFloat {
        (buttonSize * 4) + (spacing * 3) + 16  // Extra padding for safety
    }
    
    var body: some View {
        ZStack {
            // Transparent hit area background - captures drags between buttons AND clears state when drag exits
            if isExpanded {
                Capsule()
                    .fill(Color.white.opacity(0.001)) // Nearly invisible but captures events
                    .frame(width: expandedBarWidth, height: buttonSize + 8)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    // Track when drag is over the bar area
                    .onDrop(of: [UTType.fileURL], isTargeted: $isBarAreaTargeted) { _ in
                        return false  // Don't handle drop here
                    }
                    // Clear global state when drag exits the bar area
                    .onChange(of: isBarAreaTargeted) { _, targeted in
                        if !targeted {
                            // Drag left the bar area - clear the global targeting state
                            DroppyState.shared.isQuickActionsTargeted = false
                        }
                    }
            }
            
            HStack(spacing: spacing) {
                if isExpanded {
                    // Expanded: Floating buttons only
                    QuickDropActionButton(actionType: .airdrop, useTransparent: useTransparentBackground, shareAction: shareViaAirDrop)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.0)),
                            removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                        ))
                    QuickDropActionButton(actionType: .messages, useTransparent: useTransparentBackground, shareAction: shareViaMessages)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.03)),
                            removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                        ))
                    QuickDropActionButton(actionType: .mail, useTransparent: useTransparentBackground, shareAction: shareViaMail)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.06)),
                            removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                        ))
                    QuickDropActionButton(actionType: .quickshare, useTransparent: useTransparentBackground, shareAction: quickShareTo0x0)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.09)),
                            removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                        ))
                } else {
                    // Collapsed: Zap button - matches basket border style
                    // CRITICAL: Also accepts drops to auto-expand when files are dragged over it
                    Circle()
                        .fill(buttonFill)
                        .frame(width: buttonSize, height: buttonSize)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isBoltTargeted ? 0.4 : 0.08), lineWidth: isBoltTargeted ? 2 : 1)
                        )
                        .overlay(
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white.opacity(isBoltTargeted ? 1.0 : 0.75))
                        )
                        .scaleEffect(isBoltTargeted ? 1.15 : 1.0)
                        .contentShape(Circle().scale(1.3))
                        // DRAG-TO-EXPAND: Detect when files are dragged over the collapsed bolt
                        .onDrop(of: [UTType.fileURL], isTargeted: $isBoltTargeted) { _ in
                            // Don't handle the drop here - just expand so user can drop on specific action
                            return false
                        }
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isBoltTargeted)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isExpanded)
        .onHover { hovering in
            isHovering = hovering
        }
        .onChange(of: isHovering) { _, hovering in
            // EXPANDED VIA HOVER: normal expand/collapse on hover
            // But don't collapse if still dragging over quick action buttons
            if !hovering && (DroppyState.shared.isQuickActionsTargeted || isBoltTargeted) {
                return  // Keep expanded while dragging over bar
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isExpanded = hovering
            }
            // Clear hovered action when collapsing
            if !hovering {
                DroppyState.shared.hoveredQuickAction = nil
            }
            if hovering && !isExpanded {
                HapticFeedback.expand()
            }
        }
        // DRAG-TO-EXPAND: Auto-expand when files are dragged over the collapsed bolt
        .onChange(of: isBoltTargeted) { _, targeted in
            if targeted && !isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isExpanded = true
                }
                HapticFeedback.expand()
            }
        }
        // COLLAPSE when quick action targeting ends (drag left the buttons)
        .onChange(of: DroppyState.shared.isQuickActionsTargeted) { _, targeted in
            if !targeted && !isHovering && isExpanded {
                DroppyState.shared.hoveredQuickAction = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isExpanded = false
                }
            }
        }
        // COLLAPSE when basket becomes targeted (drag moved to basket area)
        .onChange(of: DroppyState.shared.isBasketTargeted) { _, targeted in
            if targeted && isExpanded {
                // Drag moved to basket - collapse back to bolt and clear quick actions state
                DroppyState.shared.isQuickActionsTargeted = false
                DroppyState.shared.hoveredQuickAction = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isExpanded = false
                }
            }
        }
    }
    
    // MARK: - Share Actions
    
    private func shareViaAirDrop(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
        FloatingBasketWindowController.shared.hideBasket()
    }
    
    private func shareViaMessages(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .composeMessage)?.perform(withItems: urls)
        FloatingBasketWindowController.shared.hideBasket()
    }
    
    private func shareViaMail(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .composeEmail)?.perform(withItems: urls)
        FloatingBasketWindowController.shared.hideBasket()
    }
    
    /// Droppy Quickshare - uploads files to 0x0.st and copies shareable link to clipboard
    /// Multiple files are automatically zipped into a single archive
    private func quickShareTo0x0(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        // Lock the window open during upload
        DroppyState.shared.isSharingInProgress = true
        
        // Show uploading feedback
        DispatchQueue.main.async {
            DroppyState.shared.quickShareStatus = .uploading
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var uploadURL: URL
            var isTemporaryZip = false
            
            if urls.count == 1 {
                // Single file: upload directly
                uploadURL = urls[0]
            } else {
                // Multiple files: create a ZIP archive first
                guard let zipURL = self.createZipArchive(from: urls) else {
                    DispatchQueue.main.async {
                        DroppyState.shared.isSharingInProgress = false
                        DroppyState.shared.quickShareStatus = .failed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            DroppyState.shared.quickShareStatus = .idle
                        }
                    }
                    return
                }
                uploadURL = zipURL
                isTemporaryZip = true
            }
            
            // Upload the file (single file or zip)
            let shareURL = self.uploadTo0x0(fileURL: uploadURL)
            
            // Clean up temporary zip if we created one
            if isTemporaryZip {
                try? FileManager.default.removeItem(at: uploadURL)
            }
            
            DispatchQueue.main.async {
                DroppyState.shared.isSharingInProgress = false
                
                if let shareURL = shareURL {
                    // Success! Copy URL to clipboard
                    let clipboard = NSPasteboard.general
                    clipboard.clearContents()
                    clipboard.setString(shareURL, forType: .string)
                    
                    // Show success feedback
                    DroppyState.shared.quickShareStatus = .success(urls: [shareURL])
                    HapticFeedback.copy()
                    
                    // Hide basket and show success popup
                    FloatingBasketWindowController.shared.hideBasket()
                    QuickShareSuccessWindowController.show(shareURL: shareURL)
                    
                    // Reset status after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        DroppyState.shared.quickShareStatus = .idle
                    }
                } else {
                    // Upload failed
                    DroppyState.shared.quickShareStatus = .failed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        DroppyState.shared.quickShareStatus = .idle
                    }
                }
            }
        }
    }
    
    /// Creates a ZIP archive from multiple files and returns the temp URL
    private func createZipArchive(from urls: [URL]) -> URL? {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let zipName = "Droppy-Share.zip"
        let zipURL = tempDir.appendingPathComponent(zipName)
        
        // Remove existing zip if any
        try? fileManager.removeItem(at: zipURL)
        
        // Create a coordinator to zip files
        let coordinator = NSFileCoordinator()
        var error: NSError?
        var success = false
        
        // Use Archive utility via Process
        // First, create a temp folder with all files
        let stagingDir = tempDir.appendingPathComponent("Droppy-QuickShare-\(UUID().uuidString)")
        do {
            try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
            
            // Copy all files to staging
            for url in urls {
                let destURL = stagingDir.appendingPathComponent(url.lastPathComponent)
                try fileManager.copyItem(at: url, to: destURL)
            }
            
            // Create zip using ditto (built-in macOS command)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--keepParent", stagingDir.path, zipURL.path]
            process.standardOutput = nil
            process.standardError = nil
            
            try process.run()
            process.waitUntilExit()
            
            success = process.terminationStatus == 0
            
            // Cleanup staging folder
            try? fileManager.removeItem(at: stagingDir)
            
        } catch {
            print("❌ [Quick Share] Failed to create ZIP: \(error)")
            try? fileManager.removeItem(at: stagingDir)
            return nil
        }
        
        return success ? zipURL : nil
    }
    
    /// Upload a single file to 0x0.st and return the share URL
    private func uploadTo0x0(fileURL: URL) -> String? {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://0x0.st")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart form data
        var body = Data()
        
        // Add file field
        let filename = fileURL.lastPathComponent
        let mimeType = mimeTypeFor(fileURL)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        
        guard let fileData = try? Data(contentsOf: fileURL) else {
            print("❌ [0x0.st] Failed to read file: \(filename)")
            return nil
        }
        
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Synchronous request (we're already on background thread)
        var resultURL: String?
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("❌ [0x0.st] Upload error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [0x0.st] Invalid response")
                return
            }
            
            if httpResponse.statusCode == 200, let data = data, let urlString = String(data: data, encoding: .utf8) {
                resultURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ [0x0.st] Uploaded: \(resultURL ?? "")")
            } else {
                print("❌ [0x0.st] HTTP \(httpResponse.statusCode)")
                if let data = data, let body = String(data: data, encoding: .utf8) {
                    print("   Response: \(body)")
                }
            }
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 60) // 60 second timeout for large files
        
        return resultURL
    }
    
    /// Get MIME type for a file URL
    private func mimeTypeFor(_ url: URL) -> String {
        if let uti = UTType(filenameExtension: url.pathExtension) {
            return uti.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
    
    private func showPicker(for urls: [URL], completion: @escaping () -> Void = {}) {
        // Find a valid window to present from
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.className.contains("Basket") }),
              let contentView = window.contentView else {
            // Last resort
            let picker = NSSharingServicePicker(items: urls)
            picker.show(relativeTo: .zero, of: NSApp.windows.first?.contentView ?? NSView(), preferredEdge: .minY)
            completion()
            return
        }
        
        let picker = NSSharingServicePicker(items: urls)
        // Delegate could be used here to track exact closure, but standard practice:
        // Picker keeps window ref. We rely on the fact that we blocked auto-hide.
        picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        
        // Since we can't easily detect when the picker closes without a delegate,
        // we'll keep the lock active for a bit and then release it, OR better:
        // We RELY on the user interaction. The window is locked open.
        // But we must eventually unlock it.
        // Actually, NSSharingServicePicker blocks? No, it's a popover.
        // Let's release the lock after a short delay to let the popover establish?
        // NO - if we release, onBasketHoverExit might fire.
        
        // Better: We add a delegate to the picker.
        // But we are in a SwiftUI View struct, hard to be a delegate.
        
        // Compromise: We release the lock, but rely on the fact that
        // interacting with the picker keeps the window frontmost?
        // Wait, 'isSharingInProgress' blocks hideBasket().
        // If we never set it to false, window never auto-hides again.
        // That's bad.
        
        // Let's create a small helper class to act as delegate?
        // Or just set a timeout? 1 minute timeout?
        // Users might take time to type emails.
        
        // Actually, for now, let's just clear the flag after a delay that assumes
        // the user has likely started interacting.
        // OR: Just don't block auto-hide? No, that was the bug.
        
        // Let's use the completion immediately, but realize that the picker is open.
        // If the window closes, the picker closes.
        // CRITICAL: We need the window to stay OPEN while picker is visible.
        
        // Solution: We assume that once the picker is shown, it's modal-ish enough?
        // No, it's a popover.
        
        // Let's just release the lock after 2 seconds.
        // By then, the popover is visible.
        // If the user moves mouse OUT of basket, does it hide?
        // Yes, onBasketHoverExit checks isSharingInProgress.
        // If we clear it after 2s, and mouse is outside, it will hide.
        // And close the picker.
        
        // This is tricky. Ideally we need a SharingServiceDelegate.
        // Since we can't easily add that to this Struct, let's use a workaround:
        // We will NOT clear isSharingInProgress here.
        // We will clear it when the WINDOW loses key focus?
        // Or just let the user manually close it?
        
        // Let's try: Clear it after 5 seconds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            DroppyState.shared.isSharingInProgress = false
        }
        
        completion()
    }
}

// MARK: - Quick Drop Action Button

struct QuickDropActionButton: View {
    let actionType: QuickActionType
    var useTransparent: Bool = false
    let shareAction: ([URL]) -> Void
    
    @State private var isHovering = false
    @State private var isTargeted = false
    
    private let size: CGFloat = 48
    
    private var buttonFill: Color {
        useTransparent ? Color.white.opacity(0.12) : Color.black
    }
    
    var body: some View {
        Circle()
            .fill(buttonFill)
            .frame(width: size, height: size)
            .overlay(
                // Simple clean border - matches basket style
                Circle()
                    .stroke(Color.white.opacity(isTargeted ? 0.3 : (isHovering ? 0.15 : 0.08)), lineWidth: 1)
            )
            .overlay(
                Image(systemName: actionType.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            )
            // Grow when file dragged over
            .scaleEffect(isTargeted ? 1.18 : (isHovering ? 1.05 : 1.0))
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isTargeted)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
                // Update shared state for basket explanation overlay
                if hovering {
                    DroppyState.shared.hoveredQuickAction = actionType
                } else if DroppyState.shared.hoveredQuickAction == actionType {
                    DroppyState.shared.hoveredQuickAction = nil
                }
            }
            .contentShape(Circle().scale(1.3))
            .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
            // CRITICAL: Update shared state when this button is targeted
            // Only SET the state - clearing is handled by capsule exit or basket targeting
            .onChange(of: isTargeted) { _, targeted in
                if targeted {
                    DroppyState.shared.isQuickActionsTargeted = true
                    DroppyState.shared.hoveredQuickAction = actionType
                }
                // Don't clear here - let capsule/basket handle it
            }
            .onTapGesture {
                let urls = DroppyState.shared.basketItems.map(\.url)
                if !urls.isEmpty {
                    HapticFeedback.select()
                    shareAction(urls)
                }
            }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    } else if let url = item as? URL {
                        urls.append(url)
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                HapticFeedback.drop()
                shareAction(urls)
                // Don't auto-hide here - let the share action decide
                // iCloud sharing needs the window to stay open for the popover
            }
        }
    }
}

