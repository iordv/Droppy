//
//  FinderServicesCard.swift
//  Droppy
//
//  Finder Services extension card for Settings extensions grid
//

import SwiftUI
import AppKit

struct FinderExtensionCard: View {
    @State private var showSetupSheet = false
    @State private var showInfoSheet = false
    private var isInstalled: Bool { UserDefaults.standard.bool(forKey: "finderTracked") }
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, stats, and badge
            HStack(alignment: .top) {
                // Official Finder icon with squircle background
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(white: 0.15))
                    Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(2)
                }
                .frame(width: 44, height: 44)
                
                Spacer()
                
                // Stats row: installs + rating + badge
                HStack(spacing: 8) {
                    // Installs (always visible)
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                        Text("\(installCount ?? 0)")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    
                    // Rating (always visible)
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption2.weight(.medium))
                        } else {
                            Text("–")
                                .font(.caption2.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)
                    
                    // Category badge - shows "Installed" if configured
                    Text(isInstalled ? "Installed" : "Productivity")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isInstalled ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isInstalled ? Color.green.opacity(0.15) : Color.white.opacity(0.1))
                        )
                }
            }
            
            // Title & Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Finder Services")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Right-click files to add them via Services menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Status row
            HStack {
                Text("One-time setup")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .frame(minHeight: 160)
        .extensionCardStyle(accentColor: .blue)
        .contentShape(Rectangle())
        .onTapGesture {
            showInfoSheet = true
        }
        .sheet(isPresented: $showSetupSheet) {
            FinderServicesSetupSheetView()
        }
        .sheet(isPresented: $showInfoSheet) {
            ExtensionInfoView(
                extensionType: .finder,
                onAction: {
                    showInfoSheet = false
                    showSetupSheet = true
                },
                installCount: installCount,
                rating: rating
            )
        }
    }
}
