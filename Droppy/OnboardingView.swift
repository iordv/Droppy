//
//  OnboardingView.swift
//  Droppy
//
//  Beautiful first-time onboarding wizard for new users
//

import SwiftUI
import AppKit

// MARK: - Onboarding Page Model

enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case displayMode  // Only shown on non-notch displays
    case shelf
    case basket
    case clipboard
    case huds
    case alfred
    case finish
    
    /// Whether this page should be shown for the current device
    var shouldShow: Bool {
        switch self {
        case .displayMode:
            // Only show on non-notch displays
            guard let screen = NSScreen.main else { return true }
            return screen.safeAreaInsets.top == 0
        default:
            return true
        }
    }
    
    var title: String {
        switch self {
        case .welcome: return "Welcome to Droppy"
        case .displayMode: return "Display Mode"
        case .shelf: return "The Shelf"
        case .basket: return "Floating Basket"
        case .clipboard: return "Clipboard History"
        case .huds: return "System HUDs"
        case .alfred: return "Alfred Integration"
        case .finish: return "You're All Set!"
        }
    }
    
    var subtitle: String {
        switch self {
        case .welcome: return "Your files, always within reach"
        case .displayMode: return "Choose your preferred style"
        case .shelf: return "Drop files into your notch for quick access"
        case .basket: return "A floating drop zone that follows your cursor"
        case .clipboard: return "Never lose copied text or images again"
        case .huds: return "Beautiful replacements for system controls"
        case .alfred: return "Add files to Droppy from Alfred"
        case .finish: return "Start using Droppy"
        }
    }
    
    var icon: String {
        switch self {
        case .welcome: return "sparkles"
        case .displayMode: return "rectangle.topthird.inset.filled"
        case .shelf: return "tray.and.arrow.down"
        case .basket: return "basket"
        case .clipboard: return "doc.on.clipboard"
        case .huds: return "slider.horizontal.3"
        case .alfred: return "command"
        case .finish: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    // Main feature toggles
    @AppStorage("enableNotchShelf") private var enableShelf = true
    @AppStorage("enableFloatingBasket") private var enableFloatingBasket = true
    @AppStorage("enableClipboardBeta") private var enableClipboard = false
    
    // Basket sub-settings
    @AppStorage("enableBasketAutoHide") private var enableBasketAutoHide = false
    @AppStorage("basketAutoHideEdge") private var basketAutoHideEdge = "right"
    
    // Shelf sub-settings
    @AppStorage("autoShrinkShelf") private var autoShrinkShelf = true
    @AppStorage("showOpenShelfIndicator") private var showOpenShelfIndicator = true
    @AppStorage("showDropIndicator") private var showDropIndicator = true
    
    // Clipboard sub-settings
    @AppStorage("clipboardHistoryLimit") private var clipboardHistoryLimit = 50
    
    // HUD settings
    @AppStorage("enableHUDReplacement") private var enableHUDReplacement = true
    @AppStorage("enableBatteryHUD") private var enableBatteryHUD = true
    @AppStorage("enableCapsLockHUD") private var enableCapsLockHUD = true
    @AppStorage("showMediaPlayer") private var showMediaPlayer = true
    @AppStorage("autoFadeMediaHUD") private var autoFadeMediaHUD = true
    
    // Display mode (non-notch only)
    @AppStorage("useDynamicIslandStyle") private var useDynamicIslandStyle = true
    
    @State private var currentPage: OnboardingPage = .welcome
    @State private var isNextHovering = false
    @State private var isBackHovering = false
    @State private var showConfetti = false
    @State private var pageTransition = false
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Page Content
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(currentPage) // Force view recreation for animation
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Navigation
                HStack {
                    // Back button
                    if currentPage != .welcome {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage = previousVisiblePage(from: currentPage)
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
                            .background(Color.white.opacity(isBackHovering ? 0.15 : 0.1))
                            .foregroundStyle(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                isBackHovering = h
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Page indicators (only show pages that shouldShow)
                    HStack(spacing: 6) {
                        ForEach(visiblePages, id: \.rawValue) { page in
                            Circle()
                                .fill(page == currentPage ? Color.blue : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(page == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    
                    Spacer()
                    
                    // Next/Done button
                    Button {
                        if currentPage == .finish {
                            onComplete()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                let nextPage = nextVisiblePage(from: currentPage)
                                currentPage = nextPage
                                if nextPage == .finish {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showConfetti = true
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentPage == .finish ? "Get Started" : "Next")
                            Image(systemName: currentPage == .finish ? "arrow.right.circle.fill" : "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            (currentPage == .finish ? Color.green : Color.blue)
                                .opacity(isNextHovering ? 1.0 : 0.85)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
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
        .frame(width: 680, height: 600)
        .background(Color.black)
        .clipped()
    }
    
    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case .welcome:
            welcomePage
        case .displayMode:
            displayModePage
        case .shelf:
            shelfPage
        case .basket:
            basketPage
        case .clipboard:
            clipboardPage
        case .huds:
            hudsPage
        case .alfred:
            alfredPage
        case .finish:
            finishPage
        }
    }
    
    // MARK: - Welcome Page
    
    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Icon with glow
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            }
            
            VStack(spacing: 8) {
                Text("Welcome to Droppy")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                Text("Your files, always within reach")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            Text("Droppy lives in your notch and gives you quick access to files, clipboard history, media controls, and more.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Shelf Page
    
    private var shelfPage: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // SwiftUI Preview
            NotchShelfPreview()
                .frame(maxWidth: 450, maxHeight: 180)
            
            VStack(spacing: 8) {
                Text("The Shelf")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                Text("Drop files into your notch for quick access. Hover over the notch to reveal your shelf.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
            
            // Main Toggle
            Toggle(isOn: $enableShelf) {
                HStack {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                    Text("Enable Shelf")
                        .font(.headline)
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 120)
            
            // Sub-settings (only visible if enabled)
            if enableShelf {
                VStack(spacing: 12) {
                    Text("Options")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 30) {
                        subSettingToggle(
                            icon: "arrow.down.left.arrow.up.right",
                            title: "Auto-shrink",
                            subtitle: "Collapse when mouse leaves",
                            isOn: $autoShrinkShelf,
                            color: .orange
                        )
                        
                        subSettingToggle(
                            icon: "text.bubble",
                            title: "Show Indicators",
                            subtitle: "\"Open Shelf\" & \"Drop!\"",
                            isOn: $showOpenShelfIndicator,
                            color: .green
                        )
                    }
                }
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            

            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: enableShelf)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Basket Page
    
    private var basketPage: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // SwiftUI Preview - same size as shelf
            FloatingBasketPreview()
                .frame(maxWidth: 450, maxHeight: 180)
            
            VStack(spacing: 8) {
                Text("Floating Basket")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                Text("Jiggle files to summon a floating basket that follows your cursor.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
            
            // Main Toggle - same padding as shelf
            Toggle(isOn: $enableFloatingBasket) {
                HStack {
                    Image(systemName: "basket.fill")
                        .foregroundStyle(.purple)
                        .font(.title3)
                    Text("Enable Floating Basket")
                        .font(.headline)
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 120)
            
            // Sub-settings (only visible if enabled) - matching shelf pattern
            if enableFloatingBasket {
                VStack(spacing: 12) {
                    Text("Options")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        // Auto-hide toggle - entire area clickable
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                enableBasketAutoHide.toggle()
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.right.to.line")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                Text("Auto-Hide")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                            .frame(width: 100, height: 70)
                            .background(enableBasketAutoHide ? Color.orange.opacity(0.15) : Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(enableBasketAutoHide ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        
                        // Edge picker (when auto-hide is on)
                        if enableBasketAutoHide {
                            Picker("", selection: $basketAutoHideEdge) {
                                Text("Left").tag("left")
                                Text("Right").tag("right")
                                Text("Bottom").tag("bottom")
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: enableFloatingBasket)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: enableBasketAutoHide)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Clipboard Page
    
    private var clipboardPage: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // SwiftUI Preview
            ClipboardPreview()
                .frame(maxWidth: 450, maxHeight: 160)
            
            VStack(spacing: 8) {
                Text("Clipboard History")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                Text("Access everything you've copied. Search, preview, and paste instantly.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
            
            // Main Toggle
            Toggle(isOn: $enableClipboard) {
                HStack {
                    Image(systemName: "doc.on.clipboard.fill")
                        .foregroundStyle(.cyan)
                        .font(.title3)
                    Text("Enable Clipboard History")
                        .font(.headline)
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 120)
            
            if enableClipboard {
                VStack(spacing: 16) {
                    // History Limit Slider
                    VStack(spacing: 6) {
                        HStack {
                            Text("History Limit")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(clipboardHistoryLimit) items")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(clipboardHistoryLimit) },
                            set: { clipboardHistoryLimit = Int($0) }
                        ), in: 10...200, step: 10)
                        .accentColor(.cyan)
                    }
                    .padding(.horizontal, 80)
                    
                    // Shortcuts Grid
                    VStack(spacing: 8) {
                        Text("Keyboard Shortcuts")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 24) {
                            shortcutBadge(keys: ["⌘", "⇧", "Space"], label: "Open")
                            shortcutBadge(keys: ["⌘", "S"], label: "Search")
                            shortcutBadge(keys: ["⌘", "C"], label: "Copy")
                            shortcutBadge(keys: ["⌘", "V"], label: "Paste")
                            shortcutBadge(keys: ["⌘", "D"], label: "Delete")
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            

            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: enableClipboard)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    private func shortcutBadge(keys: [String], label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - HUDs Page
    
    private var hudsPage: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // SwiftUI Preview - Real HUD component
            VolumeHUDPreview()
                .frame(maxWidth: 350, maxHeight: 100)
            
            VStack(spacing: 8) {
                Text("System HUDs")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                Text("Beautiful replacements for macOS volume, brightness, battery warnings, and media controls.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
            }
            
            // Main Toggle
            Toggle(isOn: $enableHUDReplacement) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    Text("Replace System HUDs")
                        .font(.headline)
                }
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 120)
            
            if enableHUDReplacement {
                VStack(spacing: 12) {
                    Text("HUD Options")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    // HUD toggles grid
                    HStack(spacing: 24) {
                        hudToggle(icon: "battery.100", title: "Battery", isOn: $enableBatteryHUD, color: .green)
                        hudToggle(icon: "capslock.fill", title: "Caps Lock", isOn: $enableCapsLockHUD, color: .green)
                        hudToggle(icon: "play.fill", title: "Media", isOn: $showMediaPlayer, color: .pink)
                        hudToggle(icon: "clock", title: "Auto-fade", isOn: $autoFadeMediaHUD, color: .blue)
                    }
                }
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            

            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: enableHUDReplacement)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Display Mode Page (Non-notch only)
    
    private var displayModePage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .blur(radius: 25)
                
                Image(systemName: "rectangle.topthird.inset.filled")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }
            
            VStack(spacing: 8) {
                Text("Display Mode")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                Text("Since your Mac doesn't have a notch, choose how Droppy appears at the top of your screen.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }
            
            // Mode picker
            HStack(spacing: 20) {
                // Notch option
                displayModeOption(
                    title: "Notch",
                    subtitle: "Classic notch style overlay",
                    isSelected: !useDynamicIslandStyle,
                    icon: {
                        OnboardingUShape()
                            .fill(!useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
                            .frame(width: 60, height: 18)
                    }
                ) {
                    useDynamicIslandStyle = false
                }
                
                // Dynamic Island option
                displayModeOption(
                    title: "Dynamic Island",
                    subtitle: "Floating pill style",
                    isSelected: useDynamicIslandStyle,
                    icon: {
                        Capsule()
                            .fill(useDynamicIslandStyle ? Color.blue : Color.white.opacity(0.5))
                            .frame(width: 50, height: 16)
                    }
                ) {
                    useDynamicIslandStyle = true
                }
            }
            .padding(.horizontal, 40)
            
            Text(useDynamicIslandStyle ? "Dynamic Island selected" : "Notch mode selected")
                .font(.caption)
                .foregroundStyle(.blue)
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    private func displayModeOption<Icon: View>(title: String, subtitle: String, isSelected: Bool, @ViewBuilder icon: () -> Icon, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue.opacity(0.25) : Color.white.opacity(0.08))
                        .frame(width: 120, height: 60)
                    
                    icon()
                }
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : .secondary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.12) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1.5)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(OptionButtonStyle())
    }
    
    // MARK: - Navigation Helpers
    
    /// Pages that should be shown for this device
    private var visiblePages: [OnboardingPage] {
        OnboardingPage.allCases.filter { $0.shouldShow }
    }
    
    /// Get next page that should be shown
    private func nextVisiblePage(from current: OnboardingPage) -> OnboardingPage {
        let allCases = OnboardingPage.allCases
        guard let currentIndex = allCases.firstIndex(of: current) else { return current }
        
        for i in (currentIndex.advanced(by: 1))..<allCases.count {
            if allCases[i].shouldShow {
                return allCases[i]
            }
        }
        return current
    }
    
    /// Get previous page that should be shown
    private func previousVisiblePage(from current: OnboardingPage) -> OnboardingPage {
        let allCases = OnboardingPage.allCases
        guard let currentIndex = allCases.firstIndex(of: current) else { return current }
        
        for i in stride(from: currentIndex.advanced(by: -1), through: 0, by: -1) {
            if allCases[i].shouldShow {
                return allCases[i]
            }
        }
        return current
    }
    
    // MARK: - Helper Views
    
    private func subSettingToggle(icon: String, title: String, subtitle: String, isOn: Binding<Bool>, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isOn.wrappedValue ? color : .secondary)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isOn.wrappedValue ? .white : .secondary)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 140)
            .padding(.vertical, 12)
            .background(Color.white.opacity(isOn.wrappedValue ? 0.1 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isOn.wrappedValue ? color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isOn.wrappedValue ? 1.0 : 0.98)
        }
        .buttonStyle(OptionButtonStyle())
        .contentShape(Rectangle())
    }
    
    private func hudToggle(icon: String, title: String, isOn: Binding<Bool>, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isOn.wrappedValue ? color : .secondary)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isOn.wrappedValue ? .white : .secondary)
            }
            .frame(width: 100, height: 80)
            .background(Color.white.opacity(isOn.wrappedValue ? 0.1 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isOn.wrappedValue ? color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isOn.wrappedValue ? 1.0 : 0.98)
        }
        .buttonStyle(OptionButtonStyle())
        .contentShape(Rectangle())
    }
    
    // MARK: - Alfred Page
    
    private var alfredPage: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Alfred Icon
            Image("AlfredIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            
            VStack(spacing: 8) {
                Text("Alfred Integration")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                Text("Use Alfred to quickly add files to Droppy. Select files in Finder, trigger Alfred, and send them to your Shelf or Basket.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }
            
            Button {
                if let workflowURL = Bundle.main.url(forResource: "Droppy", withExtension: "alfredworkflow") {
                    NSWorkspace.shared.open(workflowURL)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Install Alfred Workflow")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.purple.opacity(0.8))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(OptionButtonStyle())
            
            Text("Requires Alfred 4+ with Powerpack")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Finish Page
    
    private var finishPage: some View {
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
                Text("You're All Set!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.green)
                
                Text("Droppy is ready to use")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Feature summary grid
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    summaryRow(icon: "tray.and.arrow.down.fill", text: "Shelf", enabled: enableShelf)
                    summaryRow(icon: "basket.fill", text: "Basket", enabled: enableFloatingBasket)
                }
                HStack(spacing: 16) {
                    summaryRow(icon: "doc.on.clipboard.fill", text: "Clipboard", enabled: enableClipboard)
                    summaryRow(icon: "slider.horizontal.3", text: "HUDs", enabled: enableHUDReplacement)
                }
            }
            .padding(.vertical, 12)
            
            Text("Look for Droppy in your menu bar")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    private func summaryRow(icon: String, text: String, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(enabled ? .green : .secondary)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            
            Spacer()
            
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(enabled ? .green : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 180)
        .background(Color.white.opacity(enabled ? 0.08 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Confetti View

struct OnboardingConfettiView: View {
    @State private var particles: [OnboardingParticle] = []
    @State private var isVisible = true
    
    var body: some View {
        GeometryReader { geo in
            if isVisible {
                Canvas { context, size in
                    for particle in particles {
                        let rect = CGRect(
                            x: particle.currentX - particle.size / 2,
                            y: particle.currentY - particle.size * 0.75,
                            width: particle.size,
                            height: particle.size * 1.5
                        )
                        context.fill(
                            RoundedRectangle(cornerRadius: 1).path(in: rect),
                            with: .color(particle.color.opacity(particle.opacity))
                        )
                    }
                }
                .onAppear {
                    createParticles(in: geo.size)
                    startAnimation()
                }
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.blue, .green, .yellow, .orange, .pink, .purple, .cyan]
        
        for i in 0..<24 {
            var particle = OnboardingParticle(
                id: i,
                x: CGFloat.random(in: 40...(size.width - 40)),
                startY: size.height + 10,
                endY: CGFloat.random(in: -20...size.height * 0.3),
                color: colors[i % colors.count],
                size: CGFloat.random(in: 5...8),
                delay: Double(i) * 0.015
            )
            particle.currentX = particle.x
            particle.currentY = particle.startY
            particles.append(particle)
        }
    }
    
    private func startAnimation() {
        for i in 0..<particles.count {
            let delay = particles[i].delay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard i < particles.count else { return }
                withAnimation(.easeOut(duration: 1.2)) {
                    particles[i].currentY = particles[i].endY
                    particles[i].currentX = particles[i].x + CGFloat.random(in: -30...30)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.9) {
                guard i < particles.count else { return }
                withAnimation(.easeIn(duration: 0.3)) {
                    particles[i].opacity = 0
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isVisible = false
        }
    }
}

struct OnboardingParticle: Identifiable {
    let id: Int
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let color: Color
    let size: CGFloat
    let delay: Double
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var opacity: Double = 1
}

// MARK: - Window Controller

final class OnboardingWindowController: NSObject {
    static let shared = OnboardingWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    func show() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            return
        }
        
        let contentView = OnboardingView { [weak self] in
            // Defer to next runloop to avoid releasing view while callback is in progress
            DispatchQueue.main.async {
                // Mark onboarding as complete first
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                self?.close()
            }
        }
        
        let hostingView = NSHostingView(rootView: contentView)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.backgroundColor = .black
        window?.isMovableByWindowBackground = true
        window?.contentView = hostingView
        window?.center()
        window?.level = .floating
        
        // Fade in - use deferred makeKey to avoid NotchWindow conflicts
        window?.alphaValue = 0
        window?.orderFront(nil)
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.window?.makeKeyAndOrderFront(nil)
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window?.animator().alphaValue = 1.0
        }
    }
    
    func close() {
        guard let panel = window else { return }
        
        // Capture and nil reference AFTER animation to keep window alive
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // Now safe to release - animation is done
            self?.window = nil
            panel.orderOut(nil)
        })
    }
}

// MARK: - Compact GIF Component for Onboarding

struct OnboardingGIF: View {
    let url: String
    
    var body: some View {
        AnimatedGIFView(url: url)
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.3), location: 0),
                                .init(color: .white.opacity(0.1), location: 0.5),
                                .init(color: .black.opacity(0.2), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Option Button Style with Press Animation

struct OptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

// MARK: - U-Shape for Notch Icon Preview
/// Simple U-shape for notch mode icon in onboarding
struct OnboardingUShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 6
        
        // Start top-left
        path.move(to: CGPoint(x: 0, y: 0))
        // Down left side
        path.addLine(to: CGPoint(x: 0, y: rect.height - radius))
        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: radius, y: rect.height),
            control: CGPoint(x: 0, y: rect.height)
        )
        // Across bottom
        path.addLine(to: CGPoint(x: rect.width - radius, y: rect.height))
        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height - radius),
            control: CGPoint(x: rect.width, y: rect.height)
        )
        // Up right side
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        return path
    }
}
