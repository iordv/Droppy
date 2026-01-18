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
    private var isAIInstalled: Bool { AIInstallManager.shared.isInstalled }
    private var isAlfredInstalled: Bool { UserDefaults.standard.bool(forKey: "alfredTracked") }
    private var isFinderInstalled: Bool { UserDefaults.standard.bool(forKey: "finderTracked") }
    private var isSpotifyInstalled: Bool { UserDefaults.standard.bool(forKey: "spotifyTracked") }
    private var isElementCaptureInstalled: Bool {
        UserDefaults.standard.data(forKey: "elementCaptureShortcut") != nil
    }
    private var isWindowSnapInstalled: Bool { !WindowSnapManager.shared.shortcuts.isEmpty }
    private var isFFmpegInstalled: Bool { FFmpegInstallManager.shared.isInstalled }
    private var isVoiceTranscribeInstalled: Bool { VoiceTranscribeManager.shared.isModelDownloaded }
    private var isTerminalNotchInstalled: Bool { TerminalNotchManager.shared.isInstalled }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Featured Hero Section
                featuredSection
                
                // Category Pills
                categorySwiperHeader
                
                // Extensions List
                extensionsList
            }
            .padding(.top, 4)
        }
        .id(refreshTrigger)
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
            refreshTrigger = UUID()
        }
    }
    
    // MARK: - Featured Hero Section
    
    private var featuredSection: some View {
        VStack(spacing: 16) {
            // Large Featured Card (AI Background Removal)
            FeaturedExtensionCard(
                category: "AI POWERED",
                title: "Remove Backgrounds",
                subtitle: "Instantly with local AI. Works offline.",
                iconURL: "https://iordv.github.io/Droppy/assets/icons/ai-bg.jpg",
                screenshotURL: "https://iordv.github.io/Droppy/assets/images/ai-bg-screenshot.png",
                accentColor: .cyan,
                isInstalled: isAIInstalled,
                installCount: extensionCounts["aiBackgroundRemoval"]
            ) {
                AIInstallView(
                    installCount: extensionCounts["aiBackgroundRemoval"],
                    rating: extensionRatings["aiBackgroundRemoval"]
                )
            }
            
            // Two-column featured row
            HStack(spacing: 12) {
                // Voice Transcribe
                FeaturedExtensionCardCompact(
                    category: "AI POWERED",
                    title: "Voice Transcribe",
                    subtitle: "Speech to text",
                    iconURL: "https://iordv.github.io/Droppy/assets/icons/voice-transcribe.jpg",
                    screenshotURL: "https://iordv.github.io/Droppy/assets/images/voice-transcribe-screenshot.png",
                    accentColor: .cyan,
                    isInstalled: isVoiceTranscribeInstalled
                ) {
                    VoiceTranscribeInfoView(
                        installCount: extensionCounts["voiceTranscribe"],
                        rating: extensionRatings["voiceTranscribe"]
                    )
                }
                
                // Video Target Size
                FeaturedExtensionCardCompact(
                    category: "MEDIA",
                    title: "Video Target Size",
                    subtitle: "Compress videos",
                    iconURL: "https://iordv.github.io/Droppy/assets/icons/video-target-size.png",
                    screenshotURL: "https://iordv.github.io/Droppy/assets/images/video-target-size-screenshot.png",
                    accentColor: .green,
                    isInstalled: isFFmpegInstalled
                ) {
                    FFmpegInstallView(
                        installCount: extensionCounts["ffmpegVideoCompression"],
                        rating: extensionRatings["ffmpegVideoCompression"]
                    )
                }
            }
        }
        .padding(4) // Allow room for hover scale animation
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
    
    // MARK: - Extensions List
    
    private var extensionsList: some View {
        VStack(spacing: 0) {
            // Filter extensions based on selected category
            let extensions = filteredExtensions
            
            ForEach(Array(extensions.enumerated()), id: \.1.id) { index, ext in
                CompactExtensionRow(
                    iconURL: ext.iconURL,
                    title: ext.title,
                    subtitle: ext.subtitle,
                    isInstalled: ext.isInstalled,
                    installCount: extensionCounts[ext.analyticsKey]
                ) {
                    ext.detailView()
                }
                
                if index < extensions.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Filtered Extensions
    
    private var filteredExtensions: [ExtensionListItem] {
        let allExtensions: [ExtensionListItem] = [
            // AI Extensions
            ExtensionListItem(
                id: "aiBackgroundRemoval",
                iconURL: "https://iordv.github.io/Droppy/assets/icons/ai-bg.jpg",
                title: "AI Background Removal",
                subtitle: "Remove backgrounds instantly",
                category: .ai,
                isInstalled: isAIInstalled,
                analyticsKey: "aiBackgroundRemoval",
                extensionType: .aiBackgroundRemoval
            ) {
                AnyView(AIInstallView(
                    installCount: extensionCounts["aiBackgroundRemoval"],
                    rating: extensionRatings["aiBackgroundRemoval"]
                ))
            },
            ExtensionListItem(
                id: "voiceTranscribe",
                iconURL: "https://iordv.github.io/Droppy/assets/icons/voice-transcribe.jpg",
                title: "Voice Transcribe",
                subtitle: "Speech to text with AI",
                category: .ai,
                isInstalled: isVoiceTranscribeInstalled,
                analyticsKey: "voiceTranscribe",
                extensionType: .voiceTranscribe
            ) {
                AnyView(VoiceTranscribeInfoView(
                    installCount: extensionCounts["voiceTranscribe"],
                    rating: extensionRatings["voiceTranscribe"]
                ))
            },
            // Media Extensions
            ExtensionListItem(
                id: "ffmpegVideoCompression",
                iconURL: "https://iordv.github.io/Droppy/assets/icons/video-target-size.png",
                title: "Video Target Size",
                subtitle: "Compress videos to size",
                category: .media,
                isInstalled: isFFmpegInstalled,
                analyticsKey: "ffmpegVideoCompression",
                extensionType: .ffmpegVideoCompression
            ) {
                AnyView(FFmpegInstallView(
                    installCount: extensionCounts["ffmpegVideoCompression"],
                    rating: extensionRatings["ffmpegVideoCompression"]
                ))
            },
            // Productivity Extensions
            ExtensionListItem(
                id: "alfred",
                iconURL: "https://iordv.github.io/Droppy/assets/icons/alfred.png",
                title: "Alfred Workflow",
                subtitle: "Push files via keyboard",
                category: .productivity,
                isInstalled: isAlfredInstalled,
                analyticsKey: "alfred",
                extensionType: .alfred
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .alfred,
                    onAction: {
                        if let path = Bundle.main.path(forResource: "Droppy", ofType: "alfredworkflow") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        }
                    },
                    installCount: extensionCounts["alfred"],
                    rating: extensionRatings["alfred"]
                ))
            },
            ExtensionListItem(
                id: "elementCapture",
                iconURL: "https://iordv.github.io/Droppy/assets/icons/element-capture.jpg",
                title: "Element Capture",
                subtitle: "Screenshot UI elements",
                category: .productivity,
                isInstalled: isElementCaptureInstalled,
                analyticsKey: "elementCapture",
                extensionType: .elementCapture
            ) {
                AnyView(ElementCaptureInfoViewWrapper(
                    installCount: extensionCounts["elementCapture"],
                    rating: extensionRatings["elementCapture"]
                ))
            },
            ExtensionListItem(
                id: "finder",
                iconURL: "https://iordv.github.io/Droppy/assets/icons/finder.png",
                title: "Finder Services",
                subtitle: "Right-click integration",
                category: .productivity,
                isInstalled: isFinderInstalled,
                analyticsKey: "finder",
                extensionType: .finder
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .finder,
                    onAction: {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
                    },
                    installCount: extensionCounts["finder"],
                    rating: extensionRatings["finder"]
                ))
            },
            ExtensionListItem(
                id: "spotify",
                iconURL: "https://iordv.github.io/Droppy/assets/icons/spotify.png",
                title: "Spotify Integration",
                subtitle: "Control music playback",
                category: .media,
                isInstalled: isSpotifyInstalled,
                analyticsKey: "spotify",
                extensionType: .spotify
            ) {
                AnyView(ExtensionInfoView(
                    extensionType: .spotify,
                    onAction: {
                        if let url = URL(string: "spotify://") {
                            NSWorkspace.shared.open(url)
                        }
                    },
                    installCount: extensionCounts["spotify"],
                    rating: extensionRatings["spotify"]
                ))
            },
            ExtensionListItem(
                id: "windowSnap",
                iconURL: "https://iordv.github.io/Droppy/assets/icons/window-snap.jpg",
                title: "Window Snap",
                subtitle: "Snap with shortcuts",
                category: .productivity,
                isInstalled: isWindowSnapInstalled,
                analyticsKey: "windowSnap",
                extensionType: .windowSnap
            ) {
                AnyView(WindowSnapInfoView(
                    installCount: extensionCounts["windowSnap"],
                    rating: extensionRatings["windowSnap"]
                ))
            },
            ExtensionListItem(
                id: "terminalNotch",
                iconURL: "https://iordv.github.io/Droppy/assets/icons/terminal-notch.png",
                title: "Terminal Notch",
                subtitle: "Quick terminal access",
                category: .productivity,
                isInstalled: isTerminalNotchInstalled,
                analyticsKey: "terminalNotch",
                extensionType: .terminalNotch
            ) {
                AnyView(TerminalNotchInfoView())
            }
        ]
        
        switch selectedCategory {
        case .all:
            return allExtensions.filter { !$0.extensionType.isRemoved }.sorted { $0.title < $1.title }
        case .installed:
            return allExtensions.filter { $0.isInstalled && !$0.extensionType.isRemoved }.sorted { $0.title < $1.title }
        case .disabled:
            return allExtensions.filter { $0.extensionType.isRemoved }.sorted { $0.title < $1.title }
        default:
            return allExtensions.filter { $0.category == selectedCategory && !$0.extensionType.isRemoved }.sorted { $0.title < $1.title }
        }
    }
}

// MARK: - Extension List Item Model

private struct ExtensionListItem: Identifiable {
    let id: String
    let iconURL: String
    let title: String
    let subtitle: String
    let category: ExtensionCategory
    let isInstalled: Bool
    let analyticsKey: String
    let extensionType: ExtensionType
    let detailView: () -> AnyView
}

// MARK: - Featured Extension Card (Large)

struct FeaturedExtensionCard<DetailView: View>: View {
    let category: String
    let title: String
    let subtitle: String
    let iconURL: String
    let screenshotURL: String?
    let accentColor: Color
    let isInstalled: Bool
    var installCount: Int?
    let detailView: () -> DetailView
    
    @State private var showSheet = false
    @State private var isHovering = false
    
    var body: some View {
        Button {
            showSheet = true
        } label: {
            ZStack(alignment: .leading) {
                // Screenshot background on right side with fade
                if let screenshotURLString = screenshotURL,
                   let url = URL(string: screenshotURLString) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Spacer()
                            
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width * 0.6, height: geometry.size.height)
                                    .clipped()
                            } placeholder: {
                                Color.clear
                            }
                        }
                    }
                    .opacity(0.25)  // Very dark/faded
                    
                    // Gradient fade from left to blend the screenshot
                    LinearGradient(
                        stops: [
                            .init(color: Color.black, location: 0.0),
                            .init(color: Color.black, location: 0.4),
                            .init(color: Color.black.opacity(0.8), location: 0.6),
                            .init(color: Color.clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                
                // Content overlay
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Category label
                        Text(category)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(accentColor.opacity(0.9))
                            .tracking(0.5)
                        
                        // Title
                        Text(title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        
                        // Subtitle
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Spacer()
                        
                        // Get/Open Button
                        HStack(spacing: 12) {
                            Text(isInstalled ? "Open" : "Get")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(accentColor.opacity(0.4))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            
                            if let count = installCount, count > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 10))
                                    Text("\(count)")
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Icon
                    CachedAsyncImage(url: URL(string: iconURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(20)
            }
            .frame(height: 160)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .sheet(isPresented: $showSheet) {
            detailView()
        }
    }
}


// MARK: - Featured Extension Card (Compact)

struct FeaturedExtensionCardCompact<DetailView: View>: View {
    let category: String
    let title: String
    let subtitle: String
    let iconURL: String
    let screenshotURL: String?
    let accentColor: Color
    let isInstalled: Bool
    let detailView: () -> DetailView
    
    @State private var showSheet = false
    @State private var isHovering = false
    
    var body: some View {
        Button {
            showSheet = true
        } label: {
            ZStack(alignment: .leading) {
                // Screenshot background on right side with fade
                if let screenshotURLString = screenshotURL,
                   let url = URL(string: screenshotURLString) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Spacer()
                            
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width * 0.7, height: geometry.size.height)
                                    .clipped()
                            } placeholder: {
                                Color.clear
                            }
                        }
                    }
                    .opacity(0.2)  // Very dark/faded
                    
                    // Gradient fade from left
                    LinearGradient(
                        stops: [
                            .init(color: Color.black, location: 0.0),
                            .init(color: Color.black, location: 0.35),
                            .init(color: Color.black.opacity(0.7), location: 0.55),
                            .init(color: Color.clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                
                // Content overlay
                VStack(alignment: .leading, spacing: 8) {
                    // Category + Icon row
                    HStack {
                        Text(category)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(accentColor.opacity(0.9))
                            .tracking(0.5)
                        
                        Spacer()
                        
                        CachedAsyncImage(url: URL(string: iconURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(Color.white.opacity(0.1))
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    // Title
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    // Subtitle
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .sheet(isPresented: $showSheet) {
            detailView()
        }
    }
}

// MARK: - Compact Extension Row

struct CompactExtensionRow<DetailView: View>: View {
    let iconURL: String
    let title: String
    let subtitle: String
    let isInstalled: Bool
    var installCount: Int?
    let detailView: () -> DetailView
    
    @State private var showSheet = false
    @State private var isHovering = false
    
    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 12) {
                // Icon
                CachedAsyncImage(url: URL(string: iconURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                // Title + Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Get/Open Button
                Text(isInstalled ? "Open" : "Get")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AdaptiveColors.buttonBackgroundAuto)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isHovering ? Color.white.opacity(0.03) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .sheet(isPresented: $showSheet) {
            detailView()
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(isHovering ? 1.0 : 0.85))
                        .matchedGeometryEffect(id: "SelectedCategory", in: namespace)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isHovering ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.08), lineWidth: 1)
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

// MARK: - Legacy Card Styles (kept for compatibility)

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

// MARK: - AI Extension Icon

struct AIExtensionIcon: View {
    var size: CGFloat = 44
    
    var body: some View {
        ZStack {
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.2),
                    Color.pink.opacity(0.15),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
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

// MARK: - Legacy Cards (kept for compatibility)

struct AIBackgroundRemovalSettingsRow: View {
    @ObservedObject private var manager = AIInstallManager.shared
    @State private var showInstallSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/ai-bg.jpg")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "brain.head.profile").font(.system(size: 24)).foregroundStyle(.blue)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Spacer()
                
                Text("AI")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            
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
            
            if manager.isInstalled {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
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
        .onTapGesture { showInstallSheet = true }
        .sheet(isPresented: $showInstallSheet) { AIInstallView() }
    }
}

@available(*, deprecated, renamed: "AIBackgroundRemovalSettingsRow")
struct BackgroundRemovalSettingsRow: View {
    var body: some View {
        AIBackgroundRemovalSettingsRow()
    }
}

// MARK: - Element Capture Info View Wrapper
// Provides the binding for currentShortcut since the view requires it

struct ElementCaptureInfoViewWrapper: View {
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    @State private var currentShortcut: SavedShortcut? = {
        if let data = UserDefaults.standard.data(forKey: "elementCaptureShortcut"),
           let shortcut = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            return shortcut
        }
        return nil
    }()
    
    var body: some View {
        ElementCaptureInfoView(
            currentShortcut: $currentShortcut,
            installCount: installCount,
            rating: rating
        )
    }
}
