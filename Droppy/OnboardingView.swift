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
    // DISABLED: Lock screen features causing issues, will debug later
    // case lockScreen
    case extensions
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
    @AppStorage(AppPreferenceKey.enableUpdateHUD) private var enableUpdateHUD = PreferenceDefault.enableUpdateHUD
    
    // Lock Screen
    @AppStorage(AppPreferenceKey.enableLockScreenHUD) private var enableLockScreenHUD = PreferenceDefault.enableLockScreenHUD
    @AppStorage(AppPreferenceKey.enableLockScreenMediaWidget) private var enableLockScreenMediaWidget = PreferenceDefault.enableLockScreenMediaWidget
    
    // Appearance
    @AppStorage(AppPreferenceKey.useDynamicIslandStyle) private var useDynamicIslandStyle = PreferenceDefault.useDynamicIslandStyle
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.disableAnalytics) private var disableAnalytics = PreferenceDefault.disableAnalytics
    
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
        .background {
            if useTransparentBackground {
                AnyView(Rectangle().fill(.ultraThinMaterial))
            } else {
                AnyView(AdaptiveColors.panelBackgroundAuto)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.xxl, style: .continuous)
                .strokeBorder(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
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
        withAnimation(DroppyAnimation.onboardingBounce) {
            faceScale = 1.2
            faceRotation = direction > 0 ? 12 : -12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(DroppyAnimation.onboardingSettle) {
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
                        .transition(.opacity.animation(DroppyAnimation.hoverQuick))
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
                }
                .buttonStyle(DroppyPillButtonStyle(size: .small))
            } else {
                Spacer().frame(width: 90)
            }
            
            Spacer()
            
            // Page dots
            HStack(spacing: 6) {
                ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                    Circle()
                        .fill(page == currentPage ? Color.white : AdaptiveColors.overlayAuto(0.25))
                        .frame(width: page == currentPage ? 8 : 6, height: page == currentPage ? 8 : 6)
                        .animation(DroppyAnimation.hoverQuick, value: currentPage)
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
            }
            .buttonStyle(DroppyAccentButtonStyle(color: currentPage == .ready ? .green : .blue, size: .small))
        }
        .padding(.horizontal, 30)
    }
    
    // MARK: - Navigation
    
    private func navigateNext() {
        direction = 1
        withAnimation(DroppyAnimation.state) {
            currentPage = OnboardingPage(rawValue: currentPage.rawValue + 1) ?? .ready
        }
        if currentPage == .ready {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showConfetti = true }
        }
    }
    
    private func navigateBack() {
        direction = -1
        withAnimation(DroppyAnimation.state) {
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
        // DISABLED: case .lockScreen: return "Lock Screen Widgets"
        case .extensions: return "Extensions"
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
        // DISABLED: case .lockScreen: return "Show your notch and media controls on the lock screen"
        case .extensions: return "Extend Droppy with powerful modules"
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
                enableDNDHUD: $enableDNDHUD,
                enableUpdateHUD: $enableUpdateHUD
            )
        // DISABLED: Lock screen features causing issues
        // case .lockScreen:
        //     LockScreenContent(
        //         enableLockScreenHUD: $enableLockScreenHUD,
        //         enableLockScreenMediaWidget: $enableLockScreenMediaWidget
        //     )
        case .extensions:
            ExtensionsContent()
        case .ready:
            ReadyContent(disableAnalytics: $disableAnalytics)
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomeContent: View {
    let hasNotch: Bool
    @Binding var useDynamicIslandStyle: Bool
    
    // External display style setting (separate from built-in)
    @AppStorage(AppPreferenceKey.externalDisplayUseDynamicIsland) private var externalDisplayUseDynamicIsland = PreferenceDefault.externalDisplayUseDynamicIsland
    
    /// Whether the Mac has a built-in screen with a physical notch (MacBook Pro 14/16)
    private var hasBuiltInNotch: Bool {
        NSScreen.builtInWithNotch != nil
    }
    
    /// Whether we're currently running on an external display
    private var isOnExternalDisplay: Bool {
        guard let mainScreen = NSScreen.main else { return false }
        return !mainScreen.isBuiltIn
    }
    
    /// Whether to show any style picker at all
    /// - MacBook Pro with notch on built-in: NO choice (notch is physical)
    /// - MacBook Pro with notch on external: show external display style picker only
    /// - Non-notch Mac (iMac, mini, old MacBook): show standard style picker
    private var shouldShowStylePicker: Bool {
        if hasBuiltInNotch {
            // MacBook Pro with notch - only show picker when on external display
            return isOnExternalDisplay
        } else {
            // Non-notch Mac - show picker (they can choose notch or DI style)
            return true
        }
    }
    
    /// Label for the style picker section
    private var stylePickerLabel: String {
        if hasBuiltInNotch && isOnExternalDisplay {
            return "External display style"
        }
        return "Choose your display style"
    }
    
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
                .background(AdaptiveColors.overlayAuto(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.05), lineWidth: 1)
                )
            }
            .frame(width: 380)
            
            // Style picker - only shown when appropriate
            if shouldShowStylePicker {
                VStack(spacing: 10) {
                    Text(stylePickerLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    if hasBuiltInNotch && isOnExternalDisplay {
                        // External display style picker (for MacBook Pro users on external)
                        HStack(spacing: 8) {
                            SettingsSegmentButtonWithContent(
                                label: "Notch",
                                isSelected: !externalDisplayUseDynamicIsland,
                                action: { externalDisplayUseDynamicIsland = false }
                            ) {
                                UShape()
                                    .fill(!externalDisplayUseDynamicIsland ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 44, height: 14)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: externalDisplayUseDynamicIsland,
                                action: { externalDisplayUseDynamicIsland = true }
                            ) {
                                Capsule()
                                    .fill(externalDisplayUseDynamicIsland ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 44, height: 14)
                            }
                        }
                        .frame(width: 280)
                    } else {
                        // Standard style picker (for non-notch Macs)
                        HStack(spacing: 8) {
                            SettingsSegmentButtonWithContent(
                                label: "Notch",
                                isSelected: !useDynamicIslandStyle,
                                action: { useDynamicIslandStyle = false }
                            ) {
                                UShape()
                                    .fill(!useDynamicIslandStyle ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 44, height: 14)
                            }
                            
                            SettingsSegmentButtonWithContent(
                                label: "Island",
                                isSelected: useDynamicIslandStyle,
                                action: { useDynamicIslandStyle = true }
                            ) {
                                Capsule()
                                    .fill(useDynamicIslandStyle ? Color.blue : AdaptiveColors.overlayAuto(0.5))
                                    .frame(width: 44, height: 14)
                            }
                        }
                        .frame(width: 280)
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
        .background(AdaptiveColors.overlayAuto(0.02))
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(AdaptiveColors.overlayAuto(0.04))
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
        VStack(spacing: 20) {
            Text("Drag any file to your notch to store it temporarily.\nGrab it later and drop it anywhere you need.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 380)
            
            VStack(spacing: 10) {
                OnboardingToggle(icon: "tray.and.arrow.down.fill", title: "Enable Notch Shelf", color: .blue, isOn: $enableShelf)
                
                if enableShelf {
                    OnboardingToggle(icon: "trash.fill", title: "Auto-Clean after dragging out", color: .gray, isOn: $enableAutoClean)
                        .transition(.opacity)
                }
            }
            .frame(width: 420)
            .animation(DroppyAnimation.hoverQuick, value: enableShelf)
            
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
        VStack(spacing: 20) {
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
            .frame(width: 420)
            .animation(DroppyAnimation.hoverQuick, value: enableBasket)
            
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
        VStack(spacing: 20) {
            // Shortcut badge - pill shape
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
            .clipShape(Capsule())
            .foregroundStyle(.cyan)
            
            Text("Access everything you've copied.\nSearch, extract text from images, and pin favorites.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            
            OnboardingToggle(icon: "doc.on.clipboard.fill", title: "Enable Clipboard Manager", color: .cyan, isOn: $enableClipboard)
                .frame(width: 420)
            
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
    @Binding var enableUpdateHUD: Bool
    
    var body: some View {
        VStack(spacing: 14) {
            // HUD toggles - 7 HUDs in organized grid
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    HUDToggle(icon: "music.note", title: "Now Playing", color: .green, isOn: $showMediaPlayer, available: isMediaAvailable)
                    HUDToggle(icon: "speaker.wave.2.fill", title: "Volume", color: .blue, isOn: $enableHUD, available: true)
                }
                
                HStack(spacing: 8) {
                    HUDToggle(icon: "sun.max.fill", title: "Brightness", color: .yellow, isOn: $enableHUD, available: true)
                    HUDToggle(icon: "battery.100percent.bolt", title: "Battery", color: .green, isOn: $enableBatteryHUD, available: true, usesIOSBatteryGlyph: true)
                }
                
                HStack(spacing: 8) {
                    HUDToggle(icon: "capslock.fill", title: "Caps Lock", color: .orange, isOn: $enableCapsLockHUD, available: true)
                    HUDToggle(icon: "airpodspro", title: "AirPods", color: Color(hue: 0.58, saturation: 0.15, brightness: 0.65), isOn: $enableAirPodsHUD, available: true)
                }
                
                HStack(spacing: 8) {
                    HUDToggle(icon: "moon.fill", title: "Focus Mode", color: .purple, isOn: $enableDNDHUD, available: true)
                    HUDToggle(icon: "arrow.down.circle.fill", title: "Droppy Updates", color: .blue, isOn: $enableUpdateHUD, available: true)
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
    var secondaryColor: Color? = nil
    var usesIOSBatteryGlyph: Bool = false
    
    @State private var isHovering = false
    
    private var gradientSecondaryColor: Color {
        secondaryColor ?? color.opacity(0.7)
    }
    
    var body: some View {
        Button {
            guard available else { return }
            isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                // Premium gradient squircle icon
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, gradientSecondaryColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    // Inner highlight for 3D effect
                    RoundedRectangle(cornerRadius: DroppyRadius.small, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AdaptiveColors.overlayAuto(0.25), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    if usesIOSBatteryGlyph {
                        IOSBatteryGlyph(
                            level: 0.48,
                            outerColor: Color(white: 0.62),
                            innerColor: Color(red: 0.46, green: 0.96, blue: 0.56),
                            terminalColor: Color(white: 0.62),
                            chargingSegmentColor: Color(white: 0.58),
                            isCharging: true,
                            bodyWidth: 15,
                            bodyHeight: 8
                        )
                        .frame(width: 16, height: 13)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .droppyTextShadow()
                    }
                }
                .opacity(available ? 1.0 : 0.5)
                
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
                        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.xs))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isHovering && available ? AdaptiveColors.overlayAuto(0.06) : AdaptiveColors.overlayAuto(0.04))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(isOn && available ? color.opacity(0.3) : AdaptiveColors.overlayAuto(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(DroppySelectableButtonStyle(isSelected: isOn && available))
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
                        .stroke(AdaptiveColors.overlayAuto(0.15), lineWidth: 1)
                )
            
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    HStack {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: DroppyRadius.xs, style: .continuous)
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
                        RoundedRectangle(cornerRadius: DroppyRadius.micro)
                            .fill(AdaptiveColors.overlayAuto(0.12))
                        RoundedRectangle(cornerRadius: DroppyRadius.micro)
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
        .onDisappear {
            // PERFORMANCE FIX: Stop repeatForever animation
            withAnimation(.linear(duration: 0)) {
                progress = 0.3
            }
        }
    }
}

// MARK: - Page 6: Lock Screen Widgets

private struct LockScreenContent: View {
    @Binding var enableLockScreenHUD: Bool
    @Binding var enableLockScreenMediaWidget: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Lock Screen HUD toggle
            LockScreenToggle(
                icon: { LockScreenHUDIcon() },
                title: "Lock and Unlock Animation",
                subtitle: "Show animation when screen locks and unlocks",
                isOn: $enableLockScreenHUD,
                accentColor: .purple
            )
            
            // Now Playing widget toggle
            LockScreenToggle(
                icon: { NowPlayingIcon() },
                title: "Now Playing",
                subtitle: "Show notch & music controls on the lock screen",
                isOn: $enableLockScreenMediaWidget,
                accentColor: .green,
                isNew: true
            )
            
            Text("These features work best with a physical notch display")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

/// Lock screen toggle button with hover animation matching OnboardingToggle
private struct LockScreenToggle<Icon: View>: View {
    let icon: () -> Icon
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let accentColor: Color
    var isNew: Bool = false
    
    @State private var isHovering = false
    @State private var iconBounce = false
    
    var body: some View {
        Button {
            // Trigger bounce animation
            withAnimation(DroppyAnimation.onboardingPop) {
                iconBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(DroppyAnimation.stateEmphasis) {
                    iconBounce = false
                    isOn.toggle()
                }
            }
        } label: {
            HStack(spacing: 14) {
                icon()
                    .scaleEffect(iconBounce ? 1.15 : 1.0)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 14, weight: .medium))
                        if isNew {
                            Text("new")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.droppyAccent))
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? .green : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AdaptiveColors.overlayAuto(0.04))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .stroke(isOn ? accentColor.opacity(0.3) : AdaptiveColors.overlayAuto(0.06), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(DroppySelectableButtonStyle(isSelected: isOn))
        .onHover { hovering in
            withAnimation(DroppyAnimation.hover) {
                isHovering = hovering
            }
        }
        .frame(width: 420)
    }
}

// MARK: - Page 7: Extensions

private struct ExtensionsContent: View {
    var body: some View {
        VStack(spacing: 20) {
            // Extensions showcase - spread across full width
            VStack(spacing: 16) {
                Text("Powerful Extensions")
                    .font(.system(size: 15, weight: .semibold))
                
                // Top row - spread evenly
                HStack(spacing: 0) {
                    OnboardingExtensionIcon(definition: VoiceTranscribeExtension.self, name: "Transcribe")
                        .frame(maxWidth: .infinity)
                    OnboardingExtensionIcon(definition: AIBackgroundRemovalExtension.self, name: "AI Removal")
                        .frame(maxWidth: .infinity)
                    OnboardingExtensionIcon(definition: TermiNotchExtension.self, name: "Terminal")
                        .frame(maxWidth: .infinity)
                }
                
                // Bottom row - spread evenly
                HStack(spacing: 0) {
                    OnboardingExtensionIcon(definition: SpotifyExtension.self, name: "Spotify")
                        .frame(maxWidth: .infinity)
                    OnboardingExtensionIcon(definition: VideoTargetSizeExtension.self, name: "Compress")
                        .frame(maxWidth: .infinity)
                    OnboardingExtensionIcon(definition: ElementCaptureExtension.self, name: "Capture")
                        .frame(maxWidth: .infinity)
                }
                
                Text("And many more...")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 20)
            .frame(width: 420)
            .background(AdaptiveColors.overlayAuto(0.025))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.05), lineWidth: 1)
            )
            
            // Info card - also full width
            HStack(spacing: 10) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
                
                Text("Enable extensions in Settings → Extensions")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(width: 420)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

/// Uses real extension icons from ExtensionDefinition (same as extension store)
private struct OnboardingExtensionIcon<T: ExtensionDefinition>: View {
    let definition: T.Type
    let name: String
    
    var body: some View {
        VStack(spacing: 6) {
            CachedAsyncImage(url: definition.iconURL) { image in
                image.droppyExtensionIcon(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                    .fill(definition.iconPlaceholderColor.opacity(0.15))
                    .overlay(
                        Image(systemName: definition.iconPlaceholder)
                            .font(.system(size: 20))
                            .foregroundStyle(definition.iconPlaceholderColor)
                    )
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
            
            Text(name)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Page 8: Ready

private struct ReadyContent: View {
    @Binding var disableAnalytics: Bool
    @State private var showCheckmark = false
    @State private var showGuide = false
    @State private var showRows: [Bool] = [false, false, false, false]
    
    var body: some View {
        VStack(spacing: 24) {
            // Success icon - constrained to fixed size
            ZStack {
                // Glow
                Circle()
                    .fill(Color.green.opacity(showCheckmark ? 0.2 : 0))
                    .frame(width: 70, height: 70)
                    .blur(radius: 15)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
                    .animation(DroppyAnimation.bouncy, value: showCheckmark)
                
                // Checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                    .scaleEffect(showCheckmark ? 1 : 0)
                    .rotationEffect(.degrees(showCheckmark ? 0 : -30))
                    .animation(DroppyAnimation.bouncy.delay(0.1), value: showCheckmark)
            }
            .frame(width: 80, height: 80)
            
            // Quick start guide
            VStack(spacing: 12) {
                Text("Quick Start Guide")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(showGuide ? 1 : 0)
                    .offset(y: showGuide ? 0 : 10)
                    .animation(DroppyAnimation.viewChange.delay(0.3), value: showGuide)
                
                VStack(spacing: 0) {
                    GuideRow(icon: "cursorarrow.motionlines", color: .blue, action: "Move mouse to notch", result: "Opens shelf", isFirst: true)
                        .opacity(showRows[0] ? 1 : 0)
                        .offset(x: showRows[0] ? 0 : -20)
                        .animation(DroppyAnimation.notchState.delay(0.4), value: showRows[0])
                    
                    GuideRow(icon: "hand.draw.fill", color: .purple, action: "Shake while dragging", result: "Summons basket")
                        .opacity(showRows[1] ? 1 : 0)
                        .offset(x: showRows[1] ? 0 : -20)
                        .animation(DroppyAnimation.notchState.delay(0.5), value: showRows[1])
                    
                    GuideRow(icon: "command", color: .cyan, action: "Press ⌘⇧Space", result: "Opens clipboard")
                        .opacity(showRows[2] ? 1 : 0)
                        .offset(x: showRows[2] ? 0 : -20)
                        .animation(DroppyAnimation.notchState.delay(0.6), value: showRows[2])
                    
                    GuideRow(icon: "gearshape.fill", color: .gray, action: "Right-click notch", result: "Opens settings", isLast: true)
                        .opacity(showRows[3] ? 1 : 0)
                        .offset(x: showRows[3] ? 0 : -20)
                        .animation(DroppyAnimation.notchState.delay(0.7), value: showRows[3])
                }
                .background(AdaptiveColors.overlayAuto(0.03))
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(0.05), lineWidth: 1)
                )
            }
            .frame(width: 420)

            OnboardingToggle(
                icon: "hand.raised.fill",
                title: "Skip all analytics",
                color: .orange,
                isOn: $disableAnalytics
            )
            .frame(width: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear {
            // Trigger animations
            withAnimation {
                showCheckmark = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showGuide = true
                showRows = [true, true, true, true]
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
            // Left section: Icon + Action
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .frame(width: 24)
                
                Text(action)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 180, alignment: .leading)
            
            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.quaternary)
                .frame(width: 30)
            
            // Right section: Result
            Text(result)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 130, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(AdaptiveColors.overlayAuto(0.04))
                    .frame(height: 1)
                    .padding(.leading, 56)
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
        .background(AdaptiveColors.overlayAuto(0.04))
        .clipShape(Capsule())
    }
}
