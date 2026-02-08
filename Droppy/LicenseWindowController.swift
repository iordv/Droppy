import AppKit
import SwiftUI

final class LicenseWindowController: NSObject, NSWindowDelegate {
    static let shared = LicenseWindowController()

    private var window: NSWindow?

    var isVisible: Bool {
        window?.isVisible == true
    }

    private override init() {
        super.init()
    }

    func show() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // If already visible, bring it to front.
            if let window = self.window, window.isVisible {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                return
            }

            let view = LicenseActivationView(
                onRequestQuit: {
                    NSApplication.shared.terminate(nil)
                },
                onActivationCompleted: { [weak self] in
                    self?.close()
                    if !UserDefaults.standard.bool(forKey: AppPreferenceKey.hasCompletedOnboarding) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            OnboardingWindowController.shared.show()
                        }
                    }
                }
            )
            

            let hostingView = NSHostingView(rootView: view)

            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 430, height: 520),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            newWindow.title = "Activate License"
            newWindow.center()
            newWindow.level = .modalPanel
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .hidden
            newWindow.standardWindowButton(.closeButton)?.isHidden = true
            newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
            newWindow.standardWindowButton(.zoomButton)?.isHidden = true
            newWindow.isMovableByWindowBackground = true
            newWindow.backgroundColor = .clear
            newWindow.isOpaque = false
            newWindow.hasShadow = true
            newWindow.isReleasedWhenClosed = false
            newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            newWindow.contentView = hostingView
            newWindow.delegate = self

            self.window = newWindow

            AppKitMotion.prepareForPresent(newWindow, initialScale: 0.9)

            newWindow.orderFront(nil)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                newWindow.makeKeyAndOrderFront(nil)
            }

            AppKitMotion.animateIn(newWindow, initialScale: 0.9, duration: 0.24)

            HapticFeedback.expand()
        }
    }

    func close() {
        DispatchQueue.main.async { [weak self] in
            self?.window?.close()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let manager = LicenseManager.shared
        let canClose = !manager.requiresLicenseEnforcement || manager.isActivated
        if !canClose {
            HapticFeedback.error()
        }
        return canClose
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
