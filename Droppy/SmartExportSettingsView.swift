//
//  SmartExportSettingsView.swift
//  Droppy
//
//  Configuration sheet for Smart Export feature
//  Allows users to set up auto-save destinations for different file operations
//

import SwiftUI

struct SmartExportSettingsView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.smartExportEnabled) private var smartExportEnabled = PreferenceDefault.smartExportEnabled
    @AppStorage(AppPreferenceKey.smartExportCompressionEnabled) private var compressionEnabled = PreferenceDefault.smartExportCompressionEnabled
    @AppStorage(AppPreferenceKey.smartExportCompressionReveal) private var compressionReveal = PreferenceDefault.smartExportCompressionReveal
    @AppStorage(AppPreferenceKey.smartExportCompressionFolder) private var compressionFolder = PreferenceDefault.smartExportCompressionFolder
    @AppStorage(AppPreferenceKey.smartExportConversionEnabled) private var conversionEnabled = PreferenceDefault.smartExportConversionEnabled
    @AppStorage(AppPreferenceKey.smartExportConversionReveal) private var conversionReveal = PreferenceDefault.smartExportConversionReveal
    @AppStorage(AppPreferenceKey.smartExportConversionFolder) private var conversionFolder = PreferenceDefault.smartExportConversionFolder
    
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringClose = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Master toggle
                    masterToggleSection
                    
                    if smartExportEnabled {
                        // Compression section
                        operationSection(for: .compression, enabled: $compressionEnabled, reveal: $compressionReveal)
                        
                        // Conversion section
                        operationSection(for: .conversion, enabled: $conversionEnabled, reveal: $conversionReveal)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 450)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Footer
            footerSection
        }
        .frame(width: 480)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Animated icon (same as popover)
            SmartExportAnimatedIcon(size: 80)
            
            Text("Smart Export")
                .font(.title2.bold())
            
            Text("Automatically save processed files to designated folders")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Master Toggle
    
    private var masterToggleSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Smart Export")
                        .font(.callout.weight(.medium))
                    Text("Processed files will be saved automatically")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Toggle("", isOn: $smartExportEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(16)
        }
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Operation Section
    
    private func operationSection(for operation: FileOperation, enabled: Binding<Bool>, reveal: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            // Header row with icon and toggle
            HStack {
                // Operation icon
                Image(systemName: operation.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(operation == .compression ? .green : .orange)
                    .frame(width: 32, height: 32)
                    .background(
                        (operation == .compression ? Color.green : Color.orange).opacity(0.15)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(operation.displayName)
                        .font(.callout.weight(.medium))
                    Text(operation.description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Toggle("", isOn: enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(16)
            
            // Expanded options when enabled
            if enabled.wrappedValue {
                Divider().padding(.horizontal, 16)
                
                // Folder picker row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save to")
                            .font(.callout.weight(.medium))
                        Text("Destination folder")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    Button {
                        selectFolder(for: operation)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                            Text(folderDisplayName(for: operation))
                                .font(.callout.weight(.medium))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AdaptiveColors.subtleBorderAuto)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                
                Divider().padding(.horizontal, 16)
                
                // Reveal in Finder toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reveal in Finder")
                            .font(.callout.weight(.medium))
                        Text("Open folder after saving")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: reveal)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(16)
            }
        }
        .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: enabled.wrappedValue)
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        HStack {
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(isHoveringClose ? 1.0 : 0.85))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringClose = h
                }
            }
        }
        .padding(16)
    }
    
    // MARK: - Actions
    
    private func selectFolder(for operation: FileOperation) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        panel.message = "Choose where to save \(operation.displayName.lowercased()) files"
        
        if panel.runModal() == .OK, let url = panel.url {
            // Update both the manager and the @AppStorage for immediate UI refresh
            switch operation {
            case .compression:
                compressionFolder = url.path
            case .conversion:
                conversionFolder = url.path
            }
        }
    }
    
    /// Compute display name from @AppStorage-bound folder paths for immediate UI updates
    private func folderDisplayName(for operation: FileOperation) -> String {
        let folderPath: String
        switch operation {
        case .compression:
            folderPath = compressionFolder
        case .conversion:
            folderPath = conversionFolder
        }
        
        if folderPath.isEmpty {
            return "Downloads"
        }
        
        let url = URL(fileURLWithPath: folderPath)
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""
        
        if url.path == downloadsPath {
            return "Downloads"
        }
        return url.lastPathComponent
    }
}

// MARK: - Settings Row (for use in SettingsView)

struct SmartExportSettingsRow: View {
    @AppStorage(AppPreferenceKey.smartExportEnabled) private var smartExportEnabled = PreferenceDefault.smartExportEnabled
    @State private var showPopover = false
    @State private var showSheet = false
    @State private var isConfigureHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Info button with popover tooltip
            Button { showPopover.toggle() } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPopover, arrowEdge: .trailing) {
                smartExportPopover
            }
            
            if smartExportEnabled {
                // Enabled State: Label + Configure Button (No Toggle)
                VStack(alignment: .leading) {
                    Text("Smart Export")
                    Text("Auto-save processed files to designated folders")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    showSheet = true
                } label: {
                    Text("Configure")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isConfigureHovering ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isConfigureHovering = hovering
                    }
                }
            } else {
                // Disabled State: Master Toggle
                Toggle(isOn: Binding(
                    get: { smartExportEnabled },
                    set: { newValue in
                        smartExportEnabled = newValue
                        if newValue {
                            showSheet = true
                        }
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Smart Export")
                        Text("Auto-save processed files to designated folders")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showSheet) {
            SmartExportSettingsView()
        }
    }
    
    private var smartExportPopover: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Smart Export")
                .font(.system(size: 15, weight: .semibold))
            
            // Custom animated icon
            SmartExportAnimatedIcon()
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 5, height: 5)
                    Text("Auto-save compressed files")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Circle().fill(Color.orange).frame(width: 5, height: 5)
                    Text("Auto-save converted files")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Circle().fill(Color.blue).frame(width: 5, height: 5)
                    Text("Choose destination per type")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 200)
    }
}

// MARK: - Custom Animated Icon for Smart Export

struct SmartExportAnimatedIcon: View {
    var size: CGFloat = 50
    @State private var isAnimating = false
    
    private var iconScale: CGFloat { size / 50 }
    
    var body: some View {
        ZStack {
            // Background squarcle
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            
            // Folder tab (Back layer - drawn first)
            UnevenRoundedRectangle(topLeadingRadius: 2 * iconScale, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 2 * iconScale)
                .fill(Color(nsColor: .systemBlue))
                .frame(width: 10 * iconScale, height: 4 * iconScale)
                .offset(x: -6 * iconScale, y: -5 * iconScale)
            
            // Folder base (Front layer - drawn second)
            RoundedRectangle(cornerRadius: 3 * iconScale, style: .continuous)
                .fill(Color(nsColor: .systemBlue)) // Solid native blue
                .frame(width: 22 * iconScale, height: 16 * iconScale)
                .shadow(color: .black.opacity(0.1), radius: 2 * iconScale, x: 0, y: 1 * iconScale)
                .offset(y: 4 * iconScale)
            
            // Arrow coming down into folder
            Image(systemName: "arrow.down")
                .font(.system(size: 10 * iconScale, weight: .bold))
                .foregroundStyle(.white) // Clean white arrow
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1) // Legibility shadow
                .offset(y: isAnimating ? -2 * iconScale : -10 * iconScale)
                .opacity(isAnimating ? 0.3 : 1.0)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    SmartExportSettingsView()
        .frame(width: 765, height: 600)
}
