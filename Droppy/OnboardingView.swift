//
//  OnboardingView.swift
//  Droppy
//
//  Clean, focused onboarding wizard - 4 pages only
//

import SwiftUI
import AppKit

// MARK: - Onboarding Page Model

enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case features
    case setup
    case basics
    case ready
    
    /// Whether this page should be shown for the current device
    var shouldShow: Bool { true }
}

// MARK: - Onboarding Toggle

/// Toggle button for onboarding with icon bounce animation
/// Designed for the 2x2 grid layout in Quick Setup page


// MARK: - Onboarding Display Mode Button

/// Display mode button for onboarding with icon bounce animation
/// Designed for the Notch/Dynamic Island selection


// MARK: - Onboarding View

struct OnboardingView: View {
    // Essential toggles
    @AppStorage("enableNotchShelf") private var enableShelf = true
    @AppStorage("enableFloatingBasket") private var enableBasket = true
    @AppStorage("enableClipboardBeta") private var enableClipboard = true  // ON by default
    @AppStorage("enableHUDReplacement") private var enableHUDs = true
    @AppStorage("useDynamicIslandStyle") private var useDynamicIslandStyle = true
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    // Additional toggles for 8-toggle grid
    @AppStorage("showMediaPlayer") private var showMediaPlayer = true
    @AppStorage("autoExpandShelf") private var autoExpandShelf = true
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    
    @State private var currentPage: OnboardingPage = .welcome
    @State private var isNextHovering = false
    @State private var isBackHovering = false
    @State private var showConfetti = false
    
    // Animation states for features page
    @State private var featuresAnimated = false
    
    let onComplete: () -> Void
    
    /// Check if this Mac has a notch
    private var hasNotch: Bool {
        guard let screen = NSScreen.main else { return false }
        return screen.safeAreaInsets.top > 0
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Page Content
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(currentPage)
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Navigation
                HStack {
                    // Back button
                    if currentPage != .welcome {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage = OnboardingPage(rawValue: currentPage.rawValue - 1) ?? .welcome
                                if currentPage == .features {
                                    featuresAnimated = false
                                    triggerFeaturesAnimation()
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Back")
                            }
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background((isBackHovering ? AdaptiveColors.hoverBackgroundAuto : AdaptiveColors.buttonBackgroundAuto))
                            .foregroundStyle(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                isBackHovering = h
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Page indicators
                    HStack(spacing: 6) {
                        ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                            Circle()
                                .fill(page == currentPage ? Color.blue : AdaptiveColors.subtleBorderAuto)
                                .frame(width: 8, height: 8)
                                .scaleEffect(page == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    
                    Spacer()
                    
                    // Next/Done button
                    Button {
                        if currentPage == .ready {
                            onComplete()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage = OnboardingPage(rawValue: currentPage.rawValue + 1) ?? .ready
                                if currentPage == .features {
                                    triggerFeaturesAnimation()
                                }
                                if currentPage == .basics {
                                    triggerFeaturesAnimation() // Reuse for basics animation
                                }
                                if currentPage == .ready {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showConfetti = true
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentPage == .ready ? "Get Started" : "Next")
                            Image(systemName: currentPage == .ready ? "arrow.right.circle.fill" : "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            (currentPage == .ready ? Color.green : Color.blue)
                                .opacity(isNextHovering ? 1.0 : 0.85)
                        )
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
                            isNextHovering = h
                        }
                    }
                }
                .padding(20)
            }
            
            // Confetti overlay
            if showConfetti {
                OnboardingConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 780, height: 720)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case .welcome:
            welcomePage
        case .features:
            featuresPage
        case .setup:
            setupPage
        case .basics:
            basicsPage
        case .ready:
            readyPage
        }
    }
    
    private func triggerFeaturesAnimation() {
        featuresAnimated = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                featuresAnimated = true
            }
        }
    }
    
    // MARK: - Page 1: Welcome
    
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App Icon with glow
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: 140, height: 140)
                    .blur(radius: 40)
                
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            
            VStack(spacing: 10) {
                Text("Your all-in-one Mac")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
                Text("productivity companion")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
            }
            
            VStack(spacing: 8) {
                Text("Free forever. No subscriptions. No hidden costs.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.blue)
                
                Text("We built Droppy because you deserve a beautiful,\npowerful tool without paying monthly.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.top, 4)
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Page 2: Features Overview
    
    private var featuresPage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Everything in one place")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            
            // Feature cards - 2 column grid layout (8 cards total)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                compactFeatureCard(
                    icon: "tray.and.arrow.down.fill",
                    color: .blue,
                    title: "Shelf",
                    description: "Drop files into your notch",
                    delay: 0
                )
                
                compactFeatureCard(
                    icon: "basket.fill",
                    color: .purple,
                    title: "Basket",
                    description: "Jiggle to summon drop zone",
                    delay: 0.06
                )
                
                compactFeatureCard(
                    icon: "doc.on.clipboard.fill",
                    color: .cyan,
                    title: "Clipboard",
                    description: "History, search, and OCR",
                    delay: 0.12
                )
                
                compactFeatureCard(
                    icon: "slider.horizontal.3",
                    color: .orange,
                    title: "System HUDs",
                    description: "Volume, brightness, and more",
                    delay: 0.18
                )
                
                compactFeatureCard(
                    icon: "play.circle.fill",
                    color: .pink,
                    title: "Media Player",
                    description: "Control music from your notch",
                    delay: 0.24
                )
                
                compactFeatureCard(
                    icon: "hand.draw.fill",
                    color: .green,
                    title: "Gestures",
                    description: "Swipe between media & shelf",
                    delay: 0.30
                )
                
                compactFeatureCard(
                    icon: "eye.fill",
                    color: .yellow,
                    title: "Quick Look",
                    description: "Press Space to preview files",
                    delay: 0.36
                )
                
                // Extensions card
                VStack(spacing: 8) {
                    CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/extensions.png")) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .frame(width: 36, height: 36)
                    
                    VStack(spacing: 2) {
                        Text("Extensions")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("AI, Alfred, Spotify, & more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .background(AdaptiveColors.buttonBackgroundAuto)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AdaptiveColors.buttonBackgroundAuto, lineWidth: 1)
                )
                .opacity(featuresAnimated ? 1 : 0)
                .offset(y: featuresAnimated ? 0 : 10)
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.42), value: featuresAnimated)
            }
            .padding(.horizontal, 50)
            
            Spacer()
        }
        .onAppear {
            triggerFeaturesAnimation()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    private func featureRow(icon: String, color: Color, title: String, description: String, delay: Double) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.15))
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.monochrome)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AdaptiveColors.buttonBackgroundAuto, lineWidth: 1)
        )
        .opacity(featuresAnimated ? 1 : 0)
        .offset(y: featuresAnimated ? 0 : 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay), value: featuresAnimated)
    }
    
    /// Compact feature card for 2-column grid layout
    private func compactFeatureCard(icon: String, color: Color, title: String, description: String, delay: Double) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.15))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.monochrome)
            }
            .frame(width: 36, height: 36)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AdaptiveColors.buttonBackgroundAuto, lineWidth: 1)
        )
        .opacity(featuresAnimated ? 1 : 0)
        .offset(y: featuresAnimated ? 0 : 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay), value: featuresAnimated)
    }
    
    // MARK: - Page 3: Quick Setup
    
    private var setupPage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Quick Setup")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Toggle the features you want. You can always change these in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            // Essential toggles grid with icon bounce animation (8 toggles - 2x4 grid)
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    OnboardingToggle(icon: "tray.and.arrow.down.fill", title: "Shelf", color: .blue, isOn: $enableShelf)
                    OnboardingToggle(icon: "basket.fill", title: "Basket", color: .purple, isOn: $enableBasket)
                }
                
                HStack(spacing: 12) {
                    OnboardingToggle(icon: "doc.on.clipboard.fill", title: "Clipboard", color: .cyan, isOn: $enableClipboard)
                    OnboardingToggle(icon: "slider.horizontal.3", title: "System HUDs", color: .orange, isOn: $enableHUDs)
                }
                
                HStack(spacing: 12) {
                    OnboardingToggle(icon: "music.note", title: "Media Player", color: .pink, isOn: $showMediaPlayer)
                    OnboardingToggle(icon: "arrow.up.left.and.arrow.down.right", title: "Auto Expand", color: .teal, isOn: $autoExpandShelf)
                }
                
                HStack(spacing: 12) {
                    OnboardingToggle(icon: "power", title: "Start at Login", color: .indigo, isOn: $startAtLogin)
                    OnboardingToggle(icon: "menubar.rectangle", title: "Menu Bar Icon", color: .gray, isOn: $showInMenuBar)
                }
            }
            .padding(.horizontal, 60)
            
            // Display mode picker (only for non-notch Macs)
            if !hasNotch {
                VStack(spacing: 12) {
                    Text("Display Mode")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        OnboardingDisplayModeButton(
                            title: "Notch",
                            isSelected: !useDynamicIslandStyle,
                            action: { useDynamicIslandStyle = false }
                        ) {
                            // Notch icon (simple rounded rectangle)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(!useDynamicIslandStyle ? Color.blue : AdaptiveColors.buttonBackgroundAuto)
                                .frame(width: 50, height: 16)
                        }
                        
                        OnboardingDisplayModeButton(
                            title: "Dynamic Island",
                            isSelected: useDynamicIslandStyle,
                            action: { useDynamicIslandStyle = true }
                        ) {
                            // Dynamic Island icon
                            Capsule()
                                .fill(useDynamicIslandStyle ? Color.blue : AdaptiveColors.buttonBackgroundAuto)
                                .frame(width: 44, height: 14)
                        }
                    }
                    .padding(.horizontal, 60)
                }
                .padding(.top, 8)
            }
            
            // Keyboard shortcut hint
            HStack(spacing: 6) {
                Text("Tip:")
                    .foregroundStyle(.secondary)
                HStack(spacing: 3) {
                    keyBadge("⌘")
                    keyBadge("⇧")
                    keyBadge("Space")
                }
                Text("opens Clipboard")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.top, 8)
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
        
    private func keyBadge(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(AdaptiveColors.hoverBackgroundAuto)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(AdaptiveColors.hoverBackgroundAuto, lineWidth: 0.5)
            )
    }
    
    // MARK: - Page 4: Basics (Great To Know Tips)
    
    private var basicsPage: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text("Great to Know")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Essential tips to get the most out of Droppy")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Tips grid - 2 column layout (8 tips)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 10) {
                basicsTip(
                    icon: "arrow.down.right.and.arrow.up.left",
                    color: .blue,
                    title: "Auto Collapse",
                    description: "Shelf collapses after a delay when you move your mouse away",
                    delay: 0
                )
                
                basicsTip(
                    icon: "arrow.up.left.and.arrow.down.right",
                    color: .teal,
                    title: "Auto Expand",
                    description: "Move cursor to top edge to expand the shelf automatically",
                    delay: 0.06
                )
                
                basicsTip(
                    icon: "hand.draw.fill",
                    color: .green,
                    title: "Swipe Gestures",
                    description: "Swipe left/right on notch to switch between shelf & media",
                    delay: 0.12
                )
                
                basicsTip(
                    icon: "eye.fill",
                    color: .yellow,
                    title: "Quick Look",
                    description: "Select a file and press Space to preview it instantly",
                    delay: 0.18
                )
                
                basicsTip(
                    icon: "cursorarrow.click.2",
                    color: .purple,
                    title: "Click to Expand",
                    description: "Single click on the collapsed notch to expand the shelf",
                    delay: 0.24
                )
                
                basicsTip(
                    icon: "keyboard",
                    color: .cyan,
                    title: "Keyboard Shortcuts",
                    description: "⌘⇧Space opens Clipboard, customize more in Settings",
                    delay: 0.30
                )
                
                basicsTip(
                    icon: "contextualmenu.and.cursorarrow",
                    color: .orange,
                    title: "Right-Click Menu",
                    description: "Right-click on files for compress, convert, share & more",
                    delay: 0.36
                )
                
                basicsTip(
                    icon: "gearshape.fill",
                    color: .gray,
                    title: "Settings",
                    description: "Find Droppy in your menu bar to access all settings",
                    delay: 0.42
                )
            }
            .padding(.horizontal, 50)
            
            Spacer()
        }
        .onAppear {
            triggerFeaturesAnimation()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    /// Compact tip card for basics page grid
    private func basicsTip(icon: String, color: Color, title: String, description: String, delay: Double) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.15))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.monochrome)
            }
            .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AdaptiveColors.buttonBackgroundAuto, lineWidth: 1)
        )
        .opacity(featuresAnimated ? 1 : 0)
        .offset(y: featuresAnimated ? 0 : 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay), value: featuresAnimated)
    }
    
    // MARK: - Page 5: Ready
    
    private var readyPage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
            }
            
            VStack(spacing: 8) {
                Text("You're all set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.green)
                
                Text("Droppy is ready to boost your productivity")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            // Extension Store preview card
            Button {
                // Open Settings → Extensions tab
                onComplete() // Close onboarding first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    SettingsWindowController.shared.showSettings(openingExtension: nil)
                    // Navigate to Extensions tab
                    NotificationCenter.default.post(name: .openExtensionFromDeepLink, object: nil)
                }
            } label: {
                HStack(spacing: 14) {
                    CachedAsyncImage(url: URL(string: "https://iordv.github.io/Droppy/assets/icons/extensions.png")) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .frame(width: 48, height: 48)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Explore Extensions")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("AI background removal, Alfred, Spotify & more")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(AdaptiveColors.buttonBackgroundAuto)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 80)
            .padding(.top, 8)
            
            Text("Look for Droppy in your menu bar")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
}


