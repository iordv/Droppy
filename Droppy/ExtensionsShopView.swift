import SwiftUI

// MARK: - Extensions Shop
// Extracted from SettingsView.swift for faster incremental builds

struct ExtensionsShopView: View {
    @State private var selectedCategory: ExtensionCategory = .all
    @Namespace private var categoryAnimation
    @State private var extensionCounts: [String: Int] = [:]
    @State private var extensionRatings: [String: AnalyticsService.ExtensionRating] = [:]
    @State private var refreshTrigger = UUID() // Force view refresh
    
    // MARK: - Installed State Checks
    // Use tracking keys for consistency (set by AnalyticsService.trackExtensionActivation)
    // OR real-time checks for extensions with observable state
    
    // Real-time check: AI model exists on disk
    private var isAIInstalled: Bool { AIInstallManager.shared.isInstalled }
    // Tracking key: set when workflow is opened
    private var isAlfredInstalled: Bool { UserDefaults.standard.bool(forKey: "alfredTracked") }
    // Tracking key: set when services are enabled
    private var isFinderInstalled: Bool { UserDefaults.standard.bool(forKey: "finderTracked") }
    // Tracking key: set when Spotify integration is first used (playing music)
    private var isSpotifyInstalled: Bool { UserDefaults.standard.bool(forKey: "spotifyTracked") }
    // Real-time check: has shortcut data
    private var isElementCaptureInstalled: Bool {
        UserDefaults.standard.data(forKey: "elementCaptureShortcut") != nil
    }
    // Real-time check: has shortcuts configured  
    private var isWindowSnapInstalled: Bool { !WindowSnapManager.shared.shortcuts.isEmpty }
    // Real-time check: FFmpeg installed
    private var isFFmpegInstalled: Bool { FFmpegInstallManager.shared.isInstalled }
    
    /// Check if extension should be shown based on selected category
    private func shouldShow(extensionType: ExtensionType, category: ExtensionCategory, isInstalled: Bool) -> Bool {
        let isRemoved = extensionType.isRemoved
        
        switch selectedCategory {
        case .all:
            return true // Show all extensions including disabled
        case .installed:
            return isInstalled && !isRemoved
        case .disabled:
            return isRemoved
        default:
            return !isRemoved && selectedCategory == category
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category Swiper Header
            categorySwiperHeader
                .padding(.bottom, 20)
            
            // Extensions Grid
            extensionsGrid
        }
        .id(refreshTrigger) // Force refresh when trigger changes
        .onAppear {
            Task {
                async let countsTask = AnalyticsService.shared.fetchExtensionCounts()
                async let ratingsTask = AnalyticsService.shared.fetchExtensionRatings()
                
                if let counts = try? await countsTask {
                    extensionCounts = counts
                }
                if let ratings = try? await ratingsTask {
                    extensionRatings = ratings
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .extensionStateChanged)) { _ in
            // Force refresh when extension is disabled/enabled
            refreshTrigger = UUID()
        }
    }
    
    // MARK: - Category Swiper
    
    private var categorySwiperHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ExtensionCategory.allCases) { category in
                    CategoryPillButton(
                        category: category,
                        isSelected: selectedCategory == category,
                        namespace: categoryAnimation
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }
    
    private var extensionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            // AI Background Removal
            if shouldShow(extensionType: .aiBackgroundRemoval, category: .ai, isInstalled: isAIInstalled) {
                AIBackgroundRemovalCard(
                    installCount: extensionCounts["aiBackgroundRemoval"],
                    rating: extensionRatings["aiBackgroundRemoval"]
                )
                .opacity(ExtensionType.aiBackgroundRemoval.isRemoved ? 0.5 : 1.0)
            }
            
            // Alfred Integration
            if shouldShow(extensionType: .alfred, category: .productivity, isInstalled: isAlfredInstalled) {
                AlfredExtensionCard(
                    installCount: extensionCounts["alfred"],
                    rating: extensionRatings["alfred"]
                )
                .opacity(ExtensionType.alfred.isRemoved ? 0.5 : 1.0)
            }
            
            // Element Capture
            if shouldShow(extensionType: .elementCapture, category: .productivity, isInstalled: isElementCaptureInstalled) {
                ElementCaptureCard(
                    installCount: extensionCounts["elementCapture"],
                    rating: extensionRatings["elementCapture"]
                )
                .opacity(ExtensionType.elementCapture.isRemoved ? 0.5 : 1.0)
            }
            
            // Finder Services
            if shouldShow(extensionType: .finder, category: .productivity, isInstalled: isFinderInstalled) {
                FinderExtensionCard(
                    installCount: extensionCounts["finder"],
                    rating: extensionRatings["finder"]
                )
                .opacity(ExtensionType.finder.isRemoved ? 0.5 : 1.0)
            }
            
            // Spotify Integration
            if shouldShow(extensionType: .spotify, category: .media, isInstalled: isSpotifyInstalled) {
                SpotifyExtensionCard(
                    installCount: extensionCounts["spotify"],
                    rating: extensionRatings["spotify"]
                )
                .opacity(ExtensionType.spotify.isRemoved ? 0.5 : 1.0)
            }
            
            // Voice Transcribe
            if shouldShow(extensionType: .voiceTranscribe, category: .ai, isInstalled: VoiceTranscribeManager.shared.isModelDownloaded) {
                VoiceTranscribeCard(
                    installCount: extensionCounts["voiceTranscribe"],
                    rating: extensionRatings["voiceTranscribe"]
                )
                .opacity(ExtensionType.voiceTranscribe.isRemoved ? 0.5 : 1.0)
            }
            
            // Window Snap
            if shouldShow(extensionType: .windowSnap, category: .productivity, isInstalled: isWindowSnapInstalled) {
                WindowSnapCard(
                    installCount: extensionCounts["windowSnap"],
                    rating: extensionRatings["windowSnap"]
                )
                .opacity(ExtensionType.windowSnap.isRemoved ? 0.5 : 1.0)
            }
            
            // FFmpeg Video Compression
            if shouldShow(extensionType: .ffmpegVideoCompression, category: .media, isInstalled: isFFmpegInstalled) {
                FFmpegVideoCompressionCard(
                    installCount: extensionCounts["ffmpegVideoCompression"],
                    rating: extensionRatings["ffmpegVideoCompression"]
                )
                .opacity(ExtensionType.ffmpegVideoCompression.isRemoved ? 0.5 : 1.0)
            }
        }
    }
}

// MARK: - Category Pill Button

struct CategoryPillButton: View {
    let category: ExtensionCategory
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.blue.opacity(isHovering ? 1.0 : 0.85))
                        .matchedGeometryEffect(id: "SelectedCategory", in: namespace)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(isHovering ? 0.12 : 0.06))
                }
            }
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isSelected ? 0.3 : 0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}


// MARK: - Extension Cards

struct ExtensionCardStyle: ViewModifier {
    let accentColor: Color
    @State private var isHovering = false
    
    private var borderColor: Color {
        if isHovering {
            return accentColor.opacity(0.7)
        } else {
            return Color.white.opacity(0.1)
        }
    }
    
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    func extensionCardStyle(accentColor: Color) -> some View {
        modifier(ExtensionCardStyle(accentColor: accentColor))
    }
}

// Special AI card style with gradient border on hover
struct AIExtensionCardStyle: ViewModifier {
    @State private var isHovering = false
    
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isHovering
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.purple.opacity(0.8), .pink.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(Color.white.opacity(0.1)),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    func aiExtensionCardStyle() -> some View {
        modifier(AIExtensionCardStyle())
    }
}

// MARK: - AI Extension Icon with Magic Overlay

/// Droppy icon with subtle magic sparkle overlay for AI feature
struct AIExtensionIcon: View {
    var size: CGFloat = 44
    
    var body: some View {
        ZStack {
            // Droppy app icon as base
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            
            // Subtle magic gradient overlay
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.2),
                    Color.pink.opacity(0.15),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Sparkle accents
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.2, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .purple.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .purple.opacity(0.5), radius: 2)
                        .offset(x: -2, y: 2)
                }
                Spacer()
                HStack {
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(color: .pink.opacity(0.5), radius: 2)
                        .offset(x: 4, y: -4)
                    Spacer()
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.227, style: .continuous))
    }
}

// MARK: - Extension Cards (Modular)
// Extension card structs are now in their own files:
// - Extensions/AIBackgroundRemoval/AIBackgroundRemovalCard.swift
// - Extensions/Alfred/AlfredCard.swift
// - Extensions/FinderServices/FinderServicesCard.swift
// - Extensions/Spotify/SpotifyCard.swift
// - Extensions/ElementCapture/ElementCaptureCard.swift
// - Extensions/WindowSnap/WindowSnapCard.swift

/// Settings row for managing AI background removal with one-click install

struct AIBackgroundRemovalSettingsRow: View {
    @ObservedObject private var manager = AIInstallManager.shared
    @State private var showInstallSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon
            HStack(alignment: .top) {
                // AI Icon from remote URL (cached to prevent flashing)
                CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/ai-bg.jpg")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "brain.head.profile").font(.system(size: 24)).foregroundStyle(.blue)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Spacer()
                
                // Clean grey badge
                Text("AI")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            
            // Title & Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Background Removal")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Remove backgrounds from images using AI. Works offline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
            
            // Status
            if manager.isInstalled {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Installed")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.green)
                }
            } else {
                Text("One-click install")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 160)
        .aiExtensionCardStyle()
        .contentShape(Rectangle())
        .onTapGesture {
            showInstallSheet = true
        }
        .sheet(isPresented: $showInstallSheet) {
            AIInstallView()
        }
    }
}

// Keep old struct for compatibility but mark deprecated
@available(*, deprecated, renamed: "AIBackgroundRemovalSettingsRow")
struct BackgroundRemovalSettingsRow: View {
    var body: some View {
        AIBackgroundRemovalSettingsRow()
    }
}
