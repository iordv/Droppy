//
//  TerminalNotchInfoView.swift
//  Droppy
//
//  Extension store info view for Terminal Notch
//

import SwiftUI

/// Extension Store detail view for Terminal Notch
struct TerminalNotchInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager = TerminalNotchManager.shared
    @State private var isInstalling = false
    
    private let extensionType = ExtensionType.terminalNotch
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Screenshot
                screenshotSection
                
                // Features
                featuresSection
                
                // Install/Open button
                actionSection
            }
            .padding(24)
        }
        .frame(width: 500, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            extensionType.iconView
            
            VStack(alignment: .leading, spacing: 4) {
                Text(extensionType.title)
                    .font(.system(size: 20, weight: .semibold))
                
                Text(extensionType.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 6) {
                    Text(extensionType.category.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(extensionType.categoryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(extensionType.categoryColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Screenshot
    
    private var screenshotSection: some View {
        Group {
            if let url = extensionType.screenshotURL {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Features
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Features")
                .font(.system(size: 15, weight: .semibold))
            
            Text(extensionType.description)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(extensionType.features, id: \.text) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(extensionType.categoryColor)
                            .frame(width: 24)
                        
                        Text(feature.text)
                            .font(.system(size: 13))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Action
    
    private var actionSection: some View {
        VStack(spacing: 12) {
            if manager.isInstalled {
                HStack(spacing: 12) {
                    Button("Open Terminal") {
                        manager.show()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Remove") {
                        extensionType.setRemoved(true)
                        extensionType.cleanup()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            } else {
                Button(action: install) {
                    if isInstalling {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Install")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isInstalling)
            }
        }
    }
    
    // MARK: - Actions
    
    private func install() {
        isInstalling = true
        
        // Simulate brief install
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            manager.isInstalled = true
            extensionType.setRemoved(false)
            isInstalling = false
        }
    }
}

// MARK: - Preview

#Preview {
    TerminalNotchInfoView()
}
