//
//  UpdateView.swift
//  Droppy
//
//  Created by Jordy Spruit on 04/01/2026.
//

import SwiftUI

struct UpdateView: View {
    @ObservedObject var checker = UpdateChecker.shared
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    
    // Hover states
    @State private var isUpdateHovering = false
    @State private var isLaterHovering = false
    @State private var isOkHovering = false
    
    private var isUpToDate: Bool { checker.showingUpToDate }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with NotchFace
            VStack(spacing: 16) {
                NotchFace(size: 60, isExcited: isUpToDate)
                
                Text(isUpToDate ? "Droppy is up to date!" : "Update Available")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Version info card
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isUpToDate ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                        .foregroundStyle(isUpToDate ? .green : .blue)
                        .font(.system(size: 14))
                        .frame(width: 22)
                    
                    if isUpToDate {
                        Text("You're running the latest version (\(checker.currentVersion)).")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    } else if let newVersion = checker.latestVersion {
                        Text("Version \(newVersion) is available. You are on \(checker.currentVersion).")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.02))
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            // Release Notes - Only show when update available
            if !isUpToDate {
                Divider()
                    .padding(.horizontal, 20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if let notes = checker.releaseNotes {
                            // Strip HTML tags (img, a href, etc.) that markdown can't render
                            let cleanedNotes = notes
                                .replacingOccurrences(of: "<img[^>]*>", with: "", options: .regularExpression)
                                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                .replacingOccurrences(of: "\n\\s*\n\\s*\n", with: "\n\n", options: .regularExpression)
                            
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
                    }
                    .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                } else {
                    Button {
                        UpdateWindowController.shared.closeWindow()
                    } label: {
                        Text("Later")
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))
                    
                    Spacer()
                    
                    Button {
                        if let url = checker.downloadURL {
                            AutoUpdater.shared.installUpdate(from: url)
                            UpdateWindowController.shared.closeWindow()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Update & Restart")
                        }
                    }
                    .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                }
            }
            .padding(16)
        }
        .frame(width: 380)
        .fixedSize(horizontal: true, vertical: true)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
