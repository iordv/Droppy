//
//  ElementCaptureInfoView.swift
//  Droppy
//
//  Element Capture extension info sheet with shortcut recording
//

import SwiftUI

struct ElementCaptureInfoView: View {
    @Binding var currentShortcut: SavedShortcut?
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringClose = false
    @State private var isRecording = false
    @State private var recordMonitor: Any?
    @State private var showReviewsSheet = false
    @State private var isHoveringReviews = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Features
            featuresSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Shortcut recording section
            shortcutSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Buttons
            buttonSection
        }
        .frame(width: 510)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black)
        .clipped()
        .onDisappear {
            stopRecording()
        }
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .elementCapture)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon - with dark squircle background matching all extensions
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.15))
                Image(systemName: "viewfinder")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.orange)
            }
            .frame(width: 64, height: 64)
            .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 4)
            
            Text("Element Capture")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            // Stats row: installs + rating + category badge
            HStack(spacing: 12) {
                // Installs
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("\(installCount ?? 0)")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                
                // Rating (clickable)
                Button {
                    showReviewsSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption.weight(.medium))
                            Text("(\(r.ratingCount))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("–")
                                .font(.caption.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                // Category badge
                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
            }
            
            Text("Keyboard shortcuts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Capture specific screen elements and copy them to clipboard or add to Droppy. Perfect for grabbing UI components, icons, or any visual element.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            
            featureRow(icon: "keyboard", text: "Configurable keyboard shortcuts")
            featureRow(icon: "rectangle.dashed", text: "Select screen regions")
            featureRow(icon: "doc.on.clipboard", text: "Copy to clipboard")
            featureRow(icon: "plus.circle", text: "Add directly to Droppy")
            
            // Screenshot loaded from web (keeps app size minimal)
            AsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/images/element-capture-screenshot.png")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.top, 8)
                case .failure:
                    EmptyView()
                case .empty:
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 150)
                        .overlay(ProgressView().scaleEffect(0.8))
                        .padding(.top, 8)
                @unknown default:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    private var shortcutSection: some View {
        VStack(spacing: 12) {
            Text("Keyboard Shortcut")
                .font(.headline)
                .foregroundStyle(.white)
            
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 8) {
                    if isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Press keys...")
                            .font(.system(size: 14, weight: .medium))
                    } else if let shortcut = currentShortcut {
                        Image(systemName: "keyboard")
                            .font(.system(size: 12))
                        Text(shortcut.description)
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Image(systemName: "record.circle")
                            .font(.system(size: 12))
                        Text("Click to record shortcut")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .foregroundStyle(isRecording ? .white : (currentShortcut != nil ? .primary : .white))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isRecording ? Color.red.opacity(0.85) : (currentShortcut != nil ? Color.white.opacity(0.1) : Color.orange.opacity(0.85)))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(isHoveringClose ? 0.15 : 0.1))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringClose = h
                }
            }
            
            // Reviews button
            Button {
                showReviewsSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.bubble")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Reviews")
                }
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(isHoveringReviews ? 0.15 : 0.1))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringReviews = h
                }
            }
            
            Spacer()
        }
        .padding(16)
    }
    
    // MARK: - Recording
    
    private func startRecording() {
        isRecording = true
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore just modifier keys pressed alone
            if event.keyCode == 54 || event.keyCode == 55 || event.keyCode == 56 ||
               event.keyCode == 58 || event.keyCode == 59 || event.keyCode == 60 ||
               event.keyCode == 61 || event.keyCode == 62 {
                return nil
            }
            
            // Capture the shortcut
            DispatchQueue.main.async {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let shortcut = SavedShortcut(keyCode: Int(event.keyCode), modifiers: flags.rawValue)
                saveShortcut(shortcut)
                stopRecording()
            }
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let m = recordMonitor {
            NSEvent.removeMonitor(m)
            recordMonitor = nil
        }
    }
    
    private func saveShortcut(_ shortcut: SavedShortcut) {
        currentShortcut = shortcut
        if let encoded = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(encoded, forKey: "elementCaptureShortcut")
            
            // Track extension activation (only once per user)
            if !UserDefaults.standard.bool(forKey: "elementCaptureTracked") {
                AnalyticsService.shared.trackExtensionActivation(extensionId: "elementCapture")
                UserDefaults.standard.set(true, forKey: "elementCaptureTracked")
            }
        }
        // Also update the manager (for global hotkey monitoring)
        Task { @MainActor in
            ElementCaptureManager.shared.shortcut = shortcut
            ElementCaptureManager.shared.startMonitoringShortcut()
        }
    }
}
