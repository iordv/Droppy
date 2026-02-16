//
//  TidalCard.swift
//  Droppy
//
//  Tidal extension card for Settings extensions grid
//

import SwiftUI

struct TidalExtensionCard: View {
    @State private var showInfoSheet = false
    private var isInstalled: Bool { UserDefaults.standard.bool(forKey: "tidalTracked") }
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    private let tidalTeal = Color(red: 0.0, green: 0.80, blue: 0.84)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, stats, and badge
            HStack(alignment: .top) {
                Image("TidalIcon")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous))

                Spacer()

                // Stats row: installs + rating + badge
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                        Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)

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

                    if isInstalled {
                        Text("Installed")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 8))
                            Text("Community")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.purple.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.purple.opacity(0.15)))
                    }
                }
            }

            // Title & Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Tidal Integration")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Shuffle, repeat & favorites for the media player.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            // Status row - Running indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(TidalController.shared.isTidalRunning ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                Text(TidalController.shared.isTidalRunning ? "Running" : "Not running")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(TidalController.shared.isTidalRunning ? .primary : .secondary)
                Spacer()
            }
        }
        .frame(minHeight: 160)
        .extensionCardStyle(accentColor: tidalTeal)
        .contentShape(Rectangle())
        .onTapGesture {
            showInfoSheet = true
        }
        .sheet(isPresented: $showInfoSheet) {
            ExtensionInfoView(
                extensionType: .tidal,
                onAction: {
                    if let url = URL(string: "tidal://") {
                        NSWorkspace.shared.open(url)
                    }
                    TidalController.shared.refreshState()
                },
                installCount: installCount,
                rating: rating
            )
        }
    }
}
