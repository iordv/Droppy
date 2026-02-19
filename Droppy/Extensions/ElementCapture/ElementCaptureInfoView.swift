//
//  ElementCaptureInfoView.swift
//  Droppy
//
//  Element Capture extension info sheet with shortcut recording for all modes
//

import SwiftUI

struct ElementCaptureInfoView: View {
    @Binding var currentShortcut: SavedShortcut?
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringClose = false
    @State private var showReviewsSheet = false
    @State private var isHoveringReviews = false
    @State private var showOCRInfo = false
    
    // Recording state per capture mode
    @State private var recordingMode: ElementCaptureMode? = nil
    @State private var recordMonitor: Any?
    
    // Shortcuts for each capture mode (loaded from manager)
    @State private var elementShortcut: SavedShortcut?
    @State private var areaShortcut: SavedShortcut?
    @State private var fullscreenShortcut: SavedShortcut?
    @State private var windowShortcut: SavedShortcut?
    @State private var ocrShortcut: SavedShortcut?
    
    // Editor shortcuts state
    @State private var editorShortcuts: [EditorShortcut: SavedShortcut] = [:]
    @State private var recordingEditorShortcut: EditorShortcut? = nil
    @State private var editorRecordMonitor: Any?
    @State private var isHoveringEditorShortcut: [EditorShortcut: Bool] = [:]
    
    // Editor settings
    @AppStorage(AppPreferenceKey.editorBlurStrength) private var blurStrength = PreferenceDefault.editorBlurStrength
    @AppStorage(AppPreferenceKey.elementCaptureEditorDefaultColor) private var defaultEditorColorToken = PreferenceDefault.elementCaptureEditorDefaultColor
    @AppStorage(AppPreferenceKey.elementCaptureEditorPrefer100Zoom) private var prefer100Zoom = PreferenceDefault.elementCaptureEditorPrefer100Zoom
    @AppStorage(AppPreferenceKey.elementCaptureEditorPinchZoomEnabled) private var pinchZoomEnabled = PreferenceDefault.elementCaptureEditorPinchZoomEnabled

    private struct EditorColorOption: Identifiable {
        let token: String
        let title: String
        let color: Color
        var id: String { token }
    }

    private let editorColorOptions: [EditorColorOption] = [
        EditorColorOption(token: "red", title: "Red", color: .red),
        EditorColorOption(token: "orange", title: "Orange", color: .orange),
        EditorColorOption(token: "yellow", title: "Yellow", color: .yellow),
        EditorColorOption(token: "green", title: "Green", color: .green),
        EditorColorOption(token: "cyan", title: "Cyan", color: .cyan),
        EditorColorOption(token: "purple", title: "Purple", color: .purple),
        EditorColorOption(token: "black", title: "Black", color: .black),
        EditorColorOption(token: "white", title: "White", color: .white)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed, non-scrolling)
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Scrollable content area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Features + Screenshot
                    featuresSection
                    
                    shortcutsSection
                    
                    // Editor shortcuts reference
                    editorShortcutsSection
                    
                    // Editor settings (blur strength, etc.)
                    editorSettingsSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Buttons (fixed, non-scrolling)
            buttonSection
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .droppyTransparentBackground(useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xl, style: .continuous))
        .onAppear { loadShortcuts() }
        .onDisappear {
            stopRecording()
        }
        .sheet(isPresented: $showReviewsSheet) {
            ExtensionReviewsSheet(extensionType: .elementCapture)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon from remote URL (cached to prevent flashing)
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/element-capture.jpg")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "viewfinder")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.yellow)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .shadow(color: Color.yellow.opacity(0.4), radius: 8, y: 4)
            
            Text("Element Capture")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            // Stats row: installs + rating + category badge
            HStack(spacing: 12) {
                // Installs
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
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
                .buttonStyle(DroppySelectableButtonStyle(isSelected: false))
                
                // Category badge
                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(hue: 0.13, saturation: 0.85, brightness: 0.75))
                    )
            }
            
            Text("Capture any screen element instantly")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Screenshot and annotate with a full editor built-in.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "viewfinder", text: "Capture specific UI elements")
                featureRow(icon: "rectangle.dashed", text: "Capture fullscreen, windows, or selected areas")
                featureRow(icon: "pencil.tip", text: "Annotate with arrows, shapes & text")
                featureRow(icon: "eye.slash.fill", text: "Blur sensitive content")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Screenshot
            CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/images/element-capture-screenshot.gif")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                            .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                    )
            } placeholder: {
                EmptyView()
            }
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.yellow)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Shortcuts Section
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("Configure shortcuts for each capture mode")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 10) {
                shortcutRow(mode: .element, shortcut: $elementShortcut)
                shortcutRow(mode: .area, shortcut: $areaShortcut)
                shortcutRow(mode: .fullscreen, shortcut: $fullscreenShortcut)
                shortcutRow(mode: .window, shortcut: $windowShortcut)
                shortcutRow(mode: .ocr, shortcut: $ocrShortcut)
            }
        }
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }

    // MARK: - Editor Shortcuts Section
    
    private var editorShortcutsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Editor Shortcuts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    loadEditorDefaults()
                } label: {
                    Text("Load Defaults")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
            }
            
            // Tools grid
            VStack(alignment: .leading, spacing: 4) {
                Text("TOOLS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(EditorShortcut.tools) { action in
                        editorShortcutRow(for: action)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Actions grid
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(EditorShortcut.actions) { action in
                        editorShortcutRow(for: action)
                    }
                }
            }
        }
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Editor Settings Section
    
    private var editorSettingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Editor Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default annotation color")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("Applied when opening the editor.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Menu {
                        ForEach(editorColorOptions) { option in
                            Button {
                                defaultEditorColorToken = option.token
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 12, height: 12)
                                        .overlay(
                                            Circle()
                                                .stroke(AdaptiveColors.overlayAuto(0.24), lineWidth: 0.8)
                                        )
                                    Text(option.title)
                                    if option.token == normalizedDefaultEditorColorToken {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(selectedEditorColorOption.color)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(AdaptiveColors.overlayAuto(0.24), lineWidth: 0.8)
                                )
                            Text(selectedEditorColorOption.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(AdaptiveColors.buttonBackgroundAuto)
                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Text("Highlighter always defaults to yellow.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(AdaptiveColors.buttonBackgroundAuto)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            
            // Blur strength slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.yellow)
                    
                    Text("Blur Strength")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(blurStrength <= 8 ? "Strong" : blurStrength >= 20 ? "Subtle" : "Medium")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 8) {
                    Text("Strong")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    
                    Slider(value: $blurStrength, in: 5...30, step: 1)
                        .tint(.yellow)
                    
                    Text("Subtle")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                
                Text("Lower values create stronger pixelation blur.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(AdaptiveColors.buttonBackgroundAuto)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default zoom level")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("Open editor at native-ish zoom when possible.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Toggle("Prefer 100%", isOn: $prefer100Zoom)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12, weight: .semibold))
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pinch to zoom")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("Use trackpad pinch gesture to zoom in the editor.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $pinchZoomEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
            .padding(12)
            .background(AdaptiveColors.buttonBackgroundAuto)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
        }
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }
    
    private func editorShortcutRow(for action: EditorShortcut) -> some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: action.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.yellow)
                .frame(width: 18)
            
            // Title
            Text(action.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer()
            
            // Shortcut button
            Button {
                if recordingEditorShortcut == action {
                    stopEditorRecording()
                } else {
                    startEditorRecording(for: action)
                }
            } label: {
                HStack(spacing: 4) {
                    if recordingEditorShortcut == action {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("…")
                            .font(.system(size: 10, weight: .medium))
                    } else if let shortcut = editorShortcuts[action] {
                        Text(shortcut.description)
                            .font(.system(size: 10, weight: .semibold))
                    } else {
                        Text("Click")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(recordingEditorShortcut == action ? .primary : (editorShortcuts[action] != nil ? .primary : .secondary))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(recordingEditorShortcut == action ? Color.red.opacity(isHoveringEditorShortcut[action] == true ? 1.0 : 0.85) : (isHoveringEditorShortcut[action] == true ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
                )
            }
            .buttonStyle(DroppySelectableButtonStyle(isSelected: editorShortcuts[action] != nil))
            .onHover { h in
                withAnimation(DroppyAnimation.hoverQuick) { isHoveringEditorShortcut[action] = h }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }
    
    private func shortcutRow(mode: ElementCaptureMode, shortcut: Binding<SavedShortcut?>) -> some View {
        let isRecording = recordingMode == mode
        
        return HStack(spacing: 12) {
            // Mode icon and name
            HStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.yellow)
                    .frame(width: 20)
                
                Text(mode.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                
                // Info tooltip for OCR mode
                if mode == .ocr {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .onTapGesture { showOCRInfo.toggle() }
                        .onHover { hovering in showOCRInfo = hovering }
                        .popover(isPresented: $showOCRInfo, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "text.viewfinder")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.yellow)
                                    Text("Text Recognition")
                                        .font(.headline)
                                }
                                
                                Text("Extract text from any selected area using Apple's on-device OCR.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .frame(width: 240, alignment: .leading)
                        }
                }
            }
            .frame(width: 120, alignment: .leading)
            
            // Shortcut display
            Text(shortcut.wrappedValue?.description ?? "None")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .background(AdaptiveColors.buttonBackgroundAuto)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isRecording ? Color.orange : AdaptiveColors.subtleBorderAuto, lineWidth: isRecording ? 2 : 1)
                )
            
            // Record button
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording(for: mode)
                }
            } label: {
                Text(isRecording ? "Press…" : "Record")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(DroppyAccentButtonStyle(color: isRecording ? .red : .yellow, size: .small))
            .frame(width: 70)
            
            // Clear button
            Button {
                clearShortcut(for: mode)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(shortcut.wrappedValue != nil ? 1 : 0)
        }
        .padding(.vertical, 6)
    }
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("Close")
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            
            Spacer()
            
            // Reset all shortcuts
            Button {
                resetAllShortcuts()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(DroppyCircleButtonStyle(size: 32))
            .help("Reset All Shortcuts")
            
            DisableExtensionButton(extensionType: .elementCapture)
        }
        .padding(DroppySpacing.lg)
    }
    
    // MARK: - Recording
    
    private func loadShortcuts() {
        elementShortcut = ElementCaptureManager.shared.shortcut
        areaShortcut = ElementCaptureManager.shared.areaShortcut
        fullscreenShortcut = ElementCaptureManager.shared.fullscreenShortcut
        windowShortcut = ElementCaptureManager.shared.windowShortcut
        ocrShortcut = ElementCaptureManager.shared.ocrShortcut
        // Sync with binding for legacy compatibility
        currentShortcut = elementShortcut
        // Also load editor shortcuts
        loadEditorShortcuts()
    }
    
    private func startRecording(for mode: ElementCaptureMode) {
        // Stop any existing recording
        stopRecording()
        
        recordingMode = mode
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
                saveShortcut(shortcut, for: mode)
                stopRecording()
            }
            return nil
        }
    }
    
    private func stopRecording() {
        recordingMode = nil
        if let m = recordMonitor {
            NSEvent.removeMonitor(m)
            recordMonitor = nil
        }
    }
    
    private func saveShortcut(_ shortcut: SavedShortcut, for mode: ElementCaptureMode) {
        // Update local state
        switch mode {
        case .element:
            elementShortcut = shortcut
            currentShortcut = shortcut
        case .area:
            areaShortcut = shortcut
        case .fullscreen:
            fullscreenShortcut = shortcut
        case .window:
            windowShortcut = shortcut
        case .ocr:
            ocrShortcut = shortcut
        }
        
        // Persist to UserDefaults
        if let encoded = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(encoded, forKey: mode.shortcutKey)
            UserDefaults.standard.synchronize()
        }
        
        // Track extension activation (only once per user)
        if !UserDefaults.standard.bool(forKey: "elementCaptureTracked") {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "elementCapture")
            UserDefaults.standard.set(true, forKey: "elementCaptureTracked")
        }
        
        // Update the manager
        Task { @MainActor in
            ElementCaptureManager.shared.setShortcut(shortcut, for: mode)
            ElementCaptureManager.shared.startMonitoringShortcut(for: mode)
        }
    }
    
    private func clearShortcut(for mode: ElementCaptureMode) {
        // Update local state
        switch mode {
        case .element:
            elementShortcut = nil
            currentShortcut = nil
        case .area:
            areaShortcut = nil
        case .fullscreen:
            fullscreenShortcut = nil
        case .window:
            windowShortcut = nil
        case .ocr:
            ocrShortcut = nil
        }
        
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: mode.shortcutKey)
        
        // Update the manager
        Task { @MainActor in
            ElementCaptureManager.shared.setShortcut(nil, for: mode)
            ElementCaptureManager.shared.stopMonitoringShortcut(for: mode)
        }
    }
    
    private func resetAllShortcuts() {
        for mode in ElementCaptureMode.allCases {
            clearShortcut(for: mode)
        }
        // Also reset editor shortcuts
        ElementCaptureManager.shared.resetEditorShortcuts()
        loadEditorShortcuts()
    }
    
    // MARK: - Editor Shortcut Recording
    
    private func loadEditorShortcuts() {
        editorShortcuts = ElementCaptureManager.shared.editorShortcuts
    }
    
    private func startEditorRecording(for action: EditorShortcut) {
        // Stop any existing recording
        stopEditorRecording()
        stopRecording()
        
        recordingEditorShortcut = action
        editorRecordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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
                saveEditorShortcut(shortcut, for: action)
                stopEditorRecording()
            }
            return nil
        }
    }
    
    private func stopEditorRecording() {
        recordingEditorShortcut = nil
        if let m = editorRecordMonitor {
            NSEvent.removeMonitor(m)
            editorRecordMonitor = nil
        }
    }
    
    private func saveEditorShortcut(_ shortcut: SavedShortcut, for action: EditorShortcut) {
        // Update local state
        editorShortcuts[action] = shortcut
        
        // Persist via manager
        ElementCaptureManager.shared.setEditorShortcut(shortcut, for: action)
    }
    
    private func loadEditorDefaults() {
        ElementCaptureManager.shared.loadEditorDefaults()
        loadEditorShortcuts()
    }

    private var normalizedDefaultEditorColorToken: String {
        let normalized = defaultEditorColorToken.lowercased()
        let allowed = Set(editorColorOptions.map(\.token))
        return allowed.contains(normalized) ? normalized : PreferenceDefault.elementCaptureEditorDefaultColor
    }

    private var selectedEditorColorOption: EditorColorOption {
        editorColorOptions.first(where: { $0.token == normalizedDefaultEditorColorToken }) ?? editorColorOptions[0]
    }
}
