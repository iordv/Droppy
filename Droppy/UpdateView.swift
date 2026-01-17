//
//  UpdateView.swift
//  Droppy
//
//  Created by Jordy Spruit on 04/01/2026.
//

import SwiftUI

struct UpdateView: View {
    @ObservedObject var checker = UpdateChecker.shared
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    
    // Hover states
    @State private var isUpdateHovering = false
    @State private var isLaterHovering = false
    @State private var isOkHovering = false
    
    private var isUpToDate: Bool { checker.showingUpToDate }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with icon and version info
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(isUpToDate ? "Droppy is up to date!" : "Update Available")
                        .font(.headline)
                    
                    if isUpToDate {
                        Text("You're running the latest version (\(checker.currentVersion)).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let newVersion = checker.latestVersion {
                        Text("Version \(newVersion) is available. You are on \(checker.currentVersion).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(20)
            
            // Release Notes - Only show when update available
            if !isUpToDate {
                Divider()
                    .padding(.horizontal, 20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if let notes = checker.releaseNotes {
                            // Strip HTML tags (img, a href, etc.) that markdown can't render
                            // First strip complete <img .../> and <img ...> tags
                            var cleanedNotes = notes
                            // Remove <img...> tags (self-closing or not)
                            cleanedNotes = cleanedNotes.replacingOccurrences(of: "<img[^>]*>", with: "", options: .regularExpression)
                            // Remove any remaining HTML tags
                            cleanedNotes = cleanedNotes.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            // Clean up multiple consecutive newlines left by removed tags
                            cleanedNotes = cleanedNotes.replacingOccurrences(of: "\n\\s*\n\\s*\n", with: "\n\n", options: .regularExpression)
                            
                            ForEach(Array(cleanedNotes.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                                    if let attributed = try? AttributedString(markdown: line) {
                                        Text(attributed)
                                            .font(.system(size: 13))
                                            .textSelection(.enabled)
                                    } else {
                                        Text(line)
                                            .font(.system(size: 13))
                                            .textSelection(.enabled)
                                    }
                                } else {
                                    Spacer().frame(height: 6)
                                }
                            }
                        } else {
                            Text("No release notes available.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
                .frame(maxHeight: 200)
            }
            
            Divider()
                .padding(.horizontal, 20)
            
            // Action buttons
            HStack(spacing: 10) {
                if isUpToDate {
                    Spacer()
                    
                    Button {
                        UpdateWindowController.shared.closeWindow()
                    } label: {
                        Text("OK")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(isOkHovering ? 1.0 : 0.8))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isOkHovering = h
                        }
                    }
                } else {
                    Button {
                        UpdateWindowController.shared.closeWindow()
                    } label: {
                        Text("Later")
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background((isLaterHovering ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isLaterHovering = h
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        if let url = checker.downloadURL {
                            AutoUpdater.shared.installUpdate(from: url)
                            UpdateWindowController.shared.closeWindow()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Update & Restart")
                        }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(isUpdateHovering ? 1.0 : 0.8))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isUpdateHovering = h
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
    }
}
