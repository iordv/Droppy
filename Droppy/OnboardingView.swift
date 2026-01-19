//
//  OnboardingView.swift
//  Droppy
//
//  Onboarding 3.0 - Polished, comprehensive guided experience
//  All toggles mirror SettingsView exactly
//  Fixed position stability during page transitions
//

import SwiftUI
import AppKit

// MARK: - Onboarding Page Model

enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case shelf
    case basket
    case clipboard
    case media
    case extras
    case ready
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
    // Shelf & Basket
    @AppStorage(AppPreferenceKey.enableNotchShelf) private var enableShelf = PreferenceDefault.enableNotchShelf
    @AppStorage(AppPreferenceKey.enableFloatingBasket) private var enableBasket = PreferenceDefault.enableFloatingBasket
    @AppStorage(AppPreferenceKey.instantBasketOnDrag) private var instantBasketOnDrag = PreferenceDefault.instantBasketOnDrag
    @AppStorage(AppPreferenceKey.enableAutoClean) private var enableAutoClean = PreferenceDefault.enableAutoClean
    
    // Clipboard
    @AppStorage(AppPreferenceKey.enableClipboard) private var enableClipboard = PreferenceDefault.enableClipboard
    
    // Media & HUDs
    @AppStorage(AppPreferenceKey.showMediaPlayer) private var showMediaPlayer = PreferenceDefault.showMediaPlayer
    @AppStorage(AppPreferenceKey.enableHUDReplacement) private var enableHUD = PreferenceDefault.enableHUDReplacement
    @AppStorage(AppPreferenceKey.enableBatteryHUD) private var enableBatteryHUD = PreferenceDefault.enableBatteryHUD
    @AppStorage(AppPreferenceKey.enableCapsLockHUD) private var enableCapsLockHUD = PreferenceDefault.enableCapsLockHUD
    @AppStorage(AppPreferenceKey.enableAirPodsHUD) private var enableAirPodsHUD = PreferenceDefault.enableAirPodsHUD
    @AppStorage(AppPreferenceKey.enableDNDHUD) private var enableDNDHUD = PreferenceDefault.enableDNDHUD
    
    // Extras
    @AppStorage(AppPreferenceKey.enablePowerFolders) private var enablePowerFolders = PreferenceDefault.enablePowerFolders
    @AppStorage(AppPreferenceKey.smartExportEnabled) private var enableSmartExport = PreferenceDefault.smartExportEnabled
    
    // Appearance
    @AppStorage(AppPreferenceKey.useDynamicIslandStyle) private var useDynamicIslandStyle = PreferenceDefault.useDynamicIslandStyle
    
    @State private var currentPage: OnboardingPage = .welcome
    @State private var isNextHovering = false
    @State private var isBackHovering = false
    @State private var showConfetti = false
    @State private var direction: Int = 1
    @State private var faceScale: CGFloat = 1.0
    @State private var faceRotation: Double = 0
    
    let onComplete: () -> Void
    
    private var hasNotch: Bool {
        guard let screen = NSScreen.main else { return false }
        return screen.safeAreaInsets.top > 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with NotchFace (hidden on welcome page - content has its own)
            if currentPage != .welcome {
                headerSection
                    .frame(height: 110)
            }
            
            // Content - fixed height, centered within
            contentSection
                .frame(height: currentPage == .welcome ? 510 : 400)
                .clipped()
            
            // Footer - fixed at bottom
            footerSection
                .frame(height: 70)
        }
        .frame(width: 700, height: 580)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .overlay {
            if showConfetti {
                OnboardingConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            // Initial face animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animateNotchFace()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            // Hide header NotchFace on welcome page (it has its own big one)
            if currentPage != .welcome {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 65, height: 65)
                        .blur(radius: 14)
                        .scaleEffect(faceScale)
                    
                    NotchFace(size: 48, isExcited: currentPage == .ready)
                        .scaleEffect(faceScale)
                        .rotationEffect(.degrees(faceRotation))
                }
            }
            
            // Hide header text on welcome page (shown in content area instead)
            if currentPage != .welcome {
                Text(pageTitle)
                    .font(.system(size: 22, weight: .bold))
                
                Text(pageSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 480)
            }
        }
        .padding(.top, 24)
        .onChange(of: currentPage) { _, _ in
            animateNotchFace()
        }
    }
    
    private func animateNotchFace() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
            faceScale = 1.2
            faceRotation = direction > 0 ? 12 : -12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                faceScale = 1.0
                faceRotation = 0
            }
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        ZStack {
            ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                if page == currentPage {
                    pageContent(for: page)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack {
            // Back button
            if currentPage != .welcome {
                Button(action: navigateBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isBackHovering ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isBackHovering = $0 }
            } else {
                Spacer().frame(width: 90)
            }
            
            Spacer()
            
            // Page dots
            HStack(spacing: 6) {
                ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                    Circle()
                        .fill(page == currentPage ? Color.white : Color.white.opacity(0.25))
                        .frame(width: page == currentPage ? 8 : 6, height: page == currentPage ? 8 : 6)
                        .animation(.easeOut(duration: 0.15), value: currentPage)
                }
            }
            
            Spacer()
            
            // Next button
            Button(action: { currentPage == .ready ? onComplete() : navigateNext() }) {
                HStack(spacing: 5) {
                    Text(currentPage == .ready ? "Get Started" : "Continue")
                    Image(systemName: currentPage == .ready ? "arrow.right" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background((currentPage == .ready ? Color.green : Color.blue).opacity(isNextHovering ? 1.0 : 0.85))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { isNextHovering = $0 }
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - Navigation
    
    private func navigateNext() {
        direction = 1
        withAnimation(.easeInOut(duration: 0.25)) {
            currentPage = OnboardingPage(rawValue: currentPage.rawValue + 1) ?? .ready
        }
        if currentPage == .ready {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showConfetti = true }
        }
    }
    
    private func navigateBack() {
        direction = -1
        withAnimation(.easeInOut(duration: 0.25)) {
            currentPage = OnboardingPage(rawValue: currentPage.rawValue - 1) ?? .welcome
        }
    }
    
    private var pageTitle: String {
        switch currentPage {
        case .welcome: return "Hey there! 👋"
        case .shelf: return "The Notch Shelf"
        case .basket: return "Floating Basket"
        case .clipboard: return "Clipboard Manager"
        case .media: return "Media & HUDs"
        case .extras: return "Power Features"
        case .ready: return "You're All Set!"
        }
    }
    
    private var pageSubtitle: String {
        switch currentPage {
        case .welcome: return "I'm Droppy, your new productivity companion"
        case .shelf: return "A temporary storage area right in your menu bar"
        case .basket: return "A drop zone that appears wherever you need it"
        case .clipboard: return "Your complete clipboard history at your fingertips"
        case .media: return "Beautiful notifications for music, volume, and more"
        case .extras: return "Advanced features to supercharge your workflow"
        case .ready: return "Droppy is ready to make your Mac more productive"
        }
    }
    
    // MARK: - Page Content Router
    
    @ViewBuilder
    private func pageContent(for page: OnboardingPage) -> some View {
        switch page {
        case .welcome:
            WelcomeContent(hasNotch: hasNotch, useDynamicIslandStyle: $useDynamicIslandStyle)
        case .shelf:
            ShelfContent(enableShelf: $enableShelf, enableAutoClean: $enableAutoClean)
        case .basket:
            BasketContent(enableBasket: $enableBasket, instantBasketOnDrag: $instantBasketOnDrag)
        case .clipboard:
            ClipboardContent(enableClipboard: $enableClipboard)
        case .media:
            MediaContent(
                showMediaPlayer: $showMediaPlayer,
                enableHUD: $enableHUD,
                enableBatteryHUD: $enableBatteryHUD,
                enableCapsLockHUD: $enableCapsLockHUD,
                enableAirPodsHUD: $enableAirPodsHUD,
                enableDNDHUD: $enableDNDHUD
            )
        case .extras:
            ExtrasContent(enablePowerFolders: $enablePowerFolders, enableSmartExport: $enableSmartExport)
        case .ready:
            ReadyContent()
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomeContent: View {
    let hasNotch: Bool
    @Binding var useDynamicIslandStyle: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Big centered NotchFace (winks naturally via its internal timer)
            NotchFace(size: 100, isExcited: true)
            
            // Title and subtitle
            VStack(spacing: 6) {
                Text("Hey there! 👋")
                    .font(.system(size: 22, weight: .bold))
                
                Text("I'm Droppy, your new productivity companion")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            // Feature list in card style
            VStack(spacing: 12) {
                Text("The native productivity layer macOS is missing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 0) {
                    WelcomeFeatureRow(icon: "tray.and.arrow.down.fill", color: .blue, text: "Drag files to your notch for quick access", isFirst: true)
                    WelcomeFeatureRow(icon: "doc.on.clipboard.fill", color: .cyan, text: "Search your clipboard history with OCR")
                    WelcomeFeatureRow(icon: "music.note", color: .green, text: "See Now Playing right in your menu bar")
                    WelcomeFeatureRow(icon: "wand.and.stars", color: .pink, text: "Auto-compress images and convert files", isLast: true)
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            .frame(width: 380)
            
            // Style picker (for non-notch Macs)
            if !hasNotch {
                VStack(spacing: 10) {
                    Text("Choose your display style")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        StyleButton(title: "Notch", isSelected: !useDynamicIslandStyle, isNotch: true) {
                            useDynamicIslandStyle = false
                        }
                        StyleButton(title: "Dynamic Island", isSelected: useDynamicIslandStyle, isNotch: false) {
                            useDynamicIslandStyle = true
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

/// Feature row for welcome page (matches GuideRow style from ReadyContent)
private struct WelcomeFeatureRow: View {
    let icon: String
    let color: Color
    let text: String
    var isFirst: Bool = false
    var isLast: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 22)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.02))
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 0.5)
            }
        }
    }
}

// MARK: - Page 2: Shelf

private struct ShelfContent: View {
    @Binding var enableShelf: Bool
    @Binding var enableAutoClean: Bool
    
    var body: some View {
        VStack(spacing: 14) {
            NotchShelfPreview()
                .scaleEffect(0.78)
            
            Text("Drag any file to your notch to store it temporarily.\nGrab it later and drop it anywhere you need.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 360)
            
            VStack(spacing: 10) {
                OnboardingToggle(icon: "tray.and.arrow.down.fill", title: "Enable Notch Shelf", color: .blue, isOn: $enableShelf)
                
                if enableShelf {
                    OnboardingToggle(icon: "trash.fill", title: "Auto-Clean after dragging out", color: .gray, isOn: $enableAutoClean)
                        .transition(.opacity)
                }
            }
            .frame(width: 400)
            .animation(.easeOut(duration: 0.15), value: enableShelf)
            
            HStack(spacing: 14) {
                FeatureChip(icon: "folder.fill", text: "Pin folders")
                FeatureChip(icon: "square.stack.3d.up.fill", text: "Multiple files")
                FeatureChip(icon: "airplane", text: "AirDrop zone")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Page 3: Basket

private struct BasketContent: View {
    @Binding var enableBasket: Bool
    @Binding var instantBasketOnDrag: Bool
    
    var body: some View {
        VStack(spacing: 14) {
            FloatingBasketPreview()
                .scaleEffect(0.72)
            
            Text(instantBasketOnDrag
                ? "A floating drop zone appears instantly when you drag.\nPerfect when your notch is on a different screen."
                : "Shake files to summon a floating drop zone anywhere.\nPerfect when your notch is on a different screen."
            )
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 380)
            
            VStack(spacing: 10) {
                OnboardingToggle(icon: "basket.fill", title: "Enable Floating Basket", color: .purple, isOn: $enableBasket)
                
                if enableBasket {
                    OnboardingToggle(icon: "bolt.fill", title: "Instant Appear (no shake needed)", color: .yellow, isOn: $instantBasketOnDrag)
                        .transition(.opacity)
                }
            }
            .frame(width: 400)
            .animation(.easeOut(duration: 0.15), value: enableBasket)
            
            HStack(spacing: 14) {
                FeatureChip(icon: "hand.draw.fill", text: instantBasketOnDrag ? "Appears on drag" : "Shake to summon")
                FeatureChip(icon: "arrow.left.and.right", text: "Auto-hides to edge")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Page 4: Clipboard

private struct ClipboardContent: View {
    @Binding var enableClipboard: Bool
    
    var body: some View {
        VStack(spacing: 14) {
            ClipboardPreview()
                .scaleEffect(0.92)
            
            // Shortcut badge
            HStack(spacing: 5) {
                Image(systemName: "command")
                Text("+")
                    .foregroundStyle(.secondary)
                Image(systemName: "shift")
                Text("+")
                    .foregroundStyle(.secondary)
                Text("Space")
                    .fontWeight(.semibold)
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.cyan.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(.cyan)
            
            Text("Access everything you've copied. Search instantly,\nextract text from images, and pin your favorites.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            
            OnboardingToggle(icon: "doc.on.clipboard.fill", title: "Enable Clipboard Manager", color: .cyan, isOn: $enableClipboard)
                .frame(width: 400)
            
            HStack(spacing: 14) {
                FeatureChip(icon: "magnifyingglass", text: "Instant search")
                FeatureChip(icon: "text.viewfinder", text: "OCR images")
                FeatureChip(icon: "star.fill", text: "Favorites")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Page 5: Media & HUDs

private struct MediaContent: View {
    @Binding var showMediaPlayer: Bool
    @Binding var enableHUD: Bool
    @Binding var enableBatteryHUD: Bool
    @Binding var enableCapsLockHUD: Bool
    @Binding var enableAirPodsHUD: Bool
    @Binding var enableDNDHUD: Bool
    
    var body: some View {
        VStack(spacing: 14) {
            OnboardingMediaPreview()
            
            // HUD toggles - 7 HUDs in organized grid
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    HUDToggle(icon: "music.note", title: "Now Playing", color: .green, isOn: $showMediaPlayer, available: isMediaAvailable)
                    HUDToggle(icon: "speaker.wave.2.fill", title: "Volume", color: .blue, isOn: $enableHUD, available: true)
                }
                
                HStack(spacing: 8) {
                    HUDToggle(icon: "sun.max.fill", title: "Brightness", color: .yellow, isOn: $enableHUD, available: true)
                    HUDToggle(icon: "battery.100.bolt", title: "Battery", color: .green, isOn: $enableBatteryHUD, available: true)
                }
                
                HStack(spacing: 8) {
                    HUDToggle(icon: "capslock.fill", title: "Caps Lock", color: .orange, isOn: $enableCapsLockHUD, available: true)
                    HUDToggle(icon: "airpods", title: "AirPods", color: .white, isOn: $enableAirPodsHUD, available: true)
                }
                
                HStack(spacing: 8) {
                    HUDToggle(icon: "moon.fill", title: "Do Not Disturb", color: .purple, isOn: $enableDNDHUD, available: true)
                        .frame(width: 195) // Single centered toggle
                }
            }
            .frame(width: 400)
            
            Text("Beautiful HUDs appear in your notch\ninstead of the default macOS overlays")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    private var isMediaAvailable: Bool {
        if #available(macOS 15.0, *) { return true }
        return false
    }
}

/// Uniform HUD toggle for the grid
private struct HUDToggle: View {
    let icon: String
    let title: String
    let color: Color
    @Binding var isOn: Bool
    let available: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        Button {
            guard available else { return }
            isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(available ? color : .secondary)
                    .frame(width: 22)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(available ? .primary : .secondary)
                
                Spacer()
                
                if available {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17))
                        .foregroundStyle(isOn ? .green : .secondary.opacity(0.4))
                } else {
                    Text("15+")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(isHovering && available ? Color.white.opacity(0.06) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isOn && available ? color.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .opacity(available ? 1.0 : 0.65)
    }
}

/// Media preview
private struct OnboardingMediaPreview: View {
    @State private var progress: CGFloat = 0.3
    
    private let hudWidth: CGFloat = 260
    private let notchWidth: CGFloat = 170
    private let notchHeight: CGFloat = 30
    
    var body: some View {
        ZStack {
            NotchShape(bottomRadius: 14)
                .fill(Color.black)
                .frame(width: hudWidth, height: notchHeight + 28)
                .overlay(
                    NotchShape(bottomRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    HStack {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.85))
                            )
                        Spacer(minLength: 0)
                    }
                    .frame(width: (hudWidth - notchWidth) / 2)
                    
                    Spacer().frame(width: notchWidth)
                    
                    HStack {
                        Spacer(minLength: 0)
                        HStack(spacing: 2) {
                            ForEach(0..<4, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.green)
                                    .frame(width: 3, height: [9, 14, 7, 12][i])
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: (hudWidth - notchWidth) / 2)
                }
                .frame(height: notchHeight)
                
                Text("Purple Rain — Prince")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(height: 18)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.12))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 12)
                .padding(.bottom, 5)
            }
            .frame(width: hudWidth)
        }
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                progress = 0.8
            }
        }
    }
}

// MARK: - Page 6: Extras

private struct ExtrasContent: View {
    @Binding var enablePowerFolders: Bool
    @Binding var enableSmartExport: Bool
    
    var body: some View {
        VStack(spacing: 14) {
            // Power Folders
            VStack(spacing: 6) {
                OnboardingToggle(icon: "folder.fill.badge.gear", title: "Power Folders", color: .orange, isOn: $enablePowerFolders)
                
                Text("Pin folders to the shelf and drop files directly into them")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 400)
            
            // Smart Export
            VStack(spacing: 6) {
                OnboardingToggle(icon: "square.and.arrow.down.fill", title: "Smart Export", color: .pink, isOn: $enableSmartExport)
                
                Text("Auto-save processed files and reveal in Finder")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 400)
            
            // Extensions showcase with REAL icons from registry
            VStack(spacing: 12) {
                Text("Plus Extensions")
                    .font(.system(size: 13, weight: .semibold))
                
                HStack(spacing: 16) {
                    OnboardingExtensionIcon(definition: VoiceTranscribeExtension.self, name: "Transcribe")
                    OnboardingExtensionIcon(definition: AIBackgroundRemovalExtension.self, name: "AI Removal")
                    OnboardingExtensionIcon(definition: TermiNotchExtension.self, name: "Terminal")
                    OnboardingExtensionIcon(definition: SpotifyExtension.self, name: "Spotify")
                    OnboardingExtensionIcon(definition: VideoTargetSizeExtension.self, name: "Compress")
                    OnboardingExtensionIcon(definition: ElementCaptureExtension.self, name: "Capture")
                }
                
                Text("Settings → Extensions")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(Color.white.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

/// Uses real extension icons from ExtensionDefinition (same as extension store)
private struct OnboardingExtensionIcon<T: ExtensionDefinition>: View {
    let definition: T.Type
    let name: String
    
    var body: some View {
        VStack(spacing: 5) {
            CachedAsyncImage(url: definition.iconURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(definition.iconPlaceholderColor.opacity(0.15))
                    .overlay(
                        Image(systemName: definition.iconPlaceholder)
                            .font(.system(size: 17))
                            .foregroundStyle(definition.iconPlaceholderColor)
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            Text(name)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Page 7: Ready

private struct ReadyContent: View {
    @State private var showCheckmark = false
    @State private var showGuide = false
    @State private var showRows: [Bool] = [false, false, false, false]
    @State private var showFooter = false
    @State private var pulseGlow = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Success icon with celebration animation
            ZStack {
                // Expanding pulse rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.green.opacity(pulseGlow ? 0 : 0.3), lineWidth: 2)
                        .frame(width: pulseGlow ? 120 + CGFloat(i * 30) : 60, height: pulseGlow ? 120 + CGFloat(i * 30) : 60)
                        .animation(.easeOut(duration: 1.0).delay(Double(i) * 0.15), value: pulseGlow)
                }
                
                // Glow
                Circle()
                    .fill(Color.green.opacity(showCheckmark ? 0.15 : 0))
                    .frame(width: 90, height: 90)
                    .blur(radius: 20)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)
                
                // Checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
                    .scaleEffect(showCheckmark ? 1 : 0)
                    .rotationEffect(.degrees(showCheckmark ? 0 : -30))
                    .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1), value: showCheckmark)
            }
            
            // Quick start guide
            VStack(spacing: 14) {
                Text("Quick Start Guide")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(showGuide ? 1 : 0)
                    .offset(y: showGuide ? 0 : 10)
                    .animation(.easeOut(duration: 0.3).delay(0.4), value: showGuide)
                
                VStack(spacing: 0) {
                    GuideRow(icon: "cursorarrow.motionlines", color: .blue, action: "Move mouse to notch", result: "Opens shelf", isFirst: true)
                        .opacity(showRows[0] ? 1 : 0)
                        .offset(x: showRows[0] ? 0 : -20)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.5), value: showRows[0])
                    
                    GuideRow(icon: "hand.draw.fill", color: .purple, action: "Shake while dragging", result: "Summons basket")
                        .opacity(showRows[1] ? 1 : 0)
                        .offset(x: showRows[1] ? 0 : -20)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.6), value: showRows[1])
                    
                    GuideRow(icon: "command", color: .cyan, action: "Press ⌘⇧Space", result: "Opens clipboard")
                        .opacity(showRows[2] ? 1 : 0)
                        .offset(x: showRows[2] ? 0 : -20)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.7), value: showRows[2])
                    
                    GuideRow(icon: "gearshape.fill", color: .gray, action: "Right-click notch", result: "Opens settings", isLast: true)
                        .opacity(showRows[3] ? 1 : 0)
                        .offset(x: showRows[3] ? 0 : -20)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.8), value: showRows[3])
                }
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
            .frame(width: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear {
            // Trigger staged animations
            withAnimation {
                showCheckmark = true
                pulseGlow = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showGuide = true
                showRows = [true, true, true, true]
                showFooter = true
            }
        }
    }
}

private struct GuideRow: View {
    let icon: String
    let color: Color
    let action: String
    let result: String
    var isFirst: Bool = false
    var isLast: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Icon column
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 40)
            
            // Action column - fixed width
            Text(action)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
            
            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.quaternary)
                .frame(width: 30)
            
            // Result column - fixed width
            Text(result)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 120, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 1)
                    .padding(.leading, 40)
            }
        }
    }
}

// MARK: - Shared Components

private struct FeatureLine: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 26)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

private struct StyleButton: View {
    let title: String
    let isSelected: Bool
    let isNotch: Bool
    let action: () -> Void
    @State private var hovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                        .frame(width: 90, height: 55)
                    
                    if isNotch {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black)
                            .frame(width: 48, height: 14)
                    } else {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: 40, height: 12)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.blue : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                )
                .scaleEffect(hovering ? 1.03 : 1.0)
                
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.1), value: hovering)
    }
}

private struct FeatureChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.blue)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
    }
}
