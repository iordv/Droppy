# Animation Audit

Generated: 2026-02-08 18:16:37 CET

## Summary

- Swift files scanned: 207
- Files with animation usage: 80
- Files with raw (non-SSOT) animation usage: 55
- Total animation call sites: 832
- SSOT call sites (DroppyAnimation.*): 528
- Raw call sites: 304
- Hardcoded primitive curve/timing sites: 119

## Raw Primitive Breakdown

| Primitive | Count |
|---|---:|
| `.easeInOut(` | 28 |
| `.linear(` | 22 |
| `CAMediaTimingFunction(` | 21 |
| `.spring(` | 16 |
| `.easeOut(` | 16 |
| `.smooth(` | 11 |
| `.interactiveSpring(` | 5 |

## File Coverage

| File | Sites | Raw | Status |
|---|---:|---:|---|
| `Droppy/AdaptiveColors.swift` | 0 | 0 | clean |
| `Droppy/AirPodsHUDView.swift` | 6 | 6 | raw-only |
| `Droppy/AirPodsManager.swift` | 0 | 0 | clean |
| `Droppy/AnalyticsService.swift` | 0 | 0 | clean |
| `Droppy/AnyButtonStyle.swift` | 0 | 0 | clean |
| `Droppy/AppKitMotion.swift` | 2 | 2 | raw-only |
| `Droppy/AppleScriptRuntime.swift` | 0 | 0 | clean |
| `Droppy/AudioSpectrumView.swift` | 1 | 1 | raw-only |
| `Droppy/AutoUpdater.swift` | 0 | 0 | clean |
| `Droppy/AutofadeManager.swift` | 0 | 0 | clean |
| `Droppy/BasketDragContainer.swift` | 0 | 0 | clean |
| `Droppy/BasketItemView.swift` | 31 | 11 | mixed |
| `Droppy/BasketQuickActionsBar.swift` | 10 | 0 | ssot-only |
| `Droppy/BasketStackPreviewView.swift` | 7 | 4 | mixed |
| `Droppy/BasketState.swift` | 0 | 0 | clean |
| `Droppy/BasketSwitcherView.swift` | 20 | 8 | mixed |
| `Droppy/BatteryHUDView.swift` | 1 | 0 | ssot-only |
| `Droppy/BatteryManager.swift` | 0 | 0 | clean |
| `Droppy/BrightnessManager.swift` | 0 | 0 | clean |
| `Droppy/CachedAsyncImage.swift` | 0 | 0 | clean |
| `Droppy/CapsLockHUDView.swift` | 1 | 0 | ssot-only |
| `Droppy/CapsLockManager.swift` | 0 | 0 | clean |
| `Droppy/ClipboardManager.swift` | 2 | 0 | ssot-only |
| `Droppy/ClipboardManagerView.swift` | 71 | 21 | mixed |
| `Droppy/ClipboardWindowController.swift` | 0 | 0 | clean |
| `Droppy/ContentView.swift` | 0 | 0 | clean |
| `Droppy/CrashReporter.swift` | 0 | 0 | clean |
| `Droppy/DNDHUDView.swift` | 1 | 0 | ssot-only |
| `Droppy/DNDManager.swift` | 0 | 0 | clean |
| `Droppy/DestinationManager.swift` | 0 | 0 | clean |
| `Droppy/DragMonitor.swift` | 0 | 0 | clean |
| `Droppy/DraggableArea.swift` | 0 | 0 | clean |
| `Droppy/DraggableItemWrapper.swift` | 0 | 0 | clean |
| `Droppy/DropZoneIcon.swift` | 1 | 0 | ssot-only |
| `Droppy/DroppedItem.swift` | 0 | 0 | clean |
| `Droppy/DroppedItemView.swift` | 9 | 2 | mixed |
| `Droppy/DroppyAlertView.swift` | 2 | 2 | raw-only |
| `Droppy/DroppyAnimation.swift` | 85 | 0 | ssot-only |
| `Droppy/DroppyApp.swift` | 0 | 0 | clean |
| `Droppy/DroppyButtonStyle.swift` | 17 | 0 | ssot-only |
| `Droppy/DroppyDesign.swift` | 6 | 6 | raw-only |
| `Droppy/DroppyNotifications.swift` | 0 | 0 | clean |
| `Droppy/DroppyQuickshare.swift` | 0 | 0 | clean |
| `Droppy/DroppyState.swift` | 2 | 0 | ssot-only |
| `Droppy/ExtensionInfoView.swift` | 0 | 0 | clean |
| `Droppy/ExtensionReviewViews.swift` | 3 | 1 | mixed |
| `Droppy/Extensions/AIBackgroundRemoval/AIBackgroundRemovalCard.swift` | 0 | 0 | clean |
| `Droppy/Extensions/AIBackgroundRemoval/AIBackgroundRemovalExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/AIBackgroundRemoval/AIInstallComponents.swift` | 10 | 6 | mixed |
| `Droppy/Extensions/AIBackgroundRemoval/AIInstallManager.swift` | 0 | 0 | clean |
| `Droppy/Extensions/AIBackgroundRemoval/AIInstallView.swift` | 5 | 1 | mixed |
| `Droppy/Extensions/AIBackgroundRemoval/BackgroundRemovalManager.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Alfred/AlfredCard.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Alfred/AlfredExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/AppleMusic/AppleMusicController.swift` | 0 | 0 | clean |
| `Droppy/Extensions/AppleMusic/AppleMusicExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Caffeine/CaffeineExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Caffeine/CaffeineInfoView.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Caffeine/CaffeineManager.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Caffeine/CaffeineNotchView.swift` | 5 | 1 | mixed |
| `Droppy/Extensions/Caffeine/HighAlertHUDView.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Camera/CameraExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Camera/CameraInfoView.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Camera/CameraManager.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Camera/SnapCameraShelfPanel.swift` | 0 | 0 | clean |
| `Droppy/Extensions/DroppyLoadableExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/ElementCapture/AreaSelectionWindow.swift` | 0 | 0 | clean |
| `Droppy/Extensions/ElementCapture/CapturePreviewView.swift` | 1 | 1 | raw-only |
| `Droppy/Extensions/ElementCapture/ElementCaptureCard.swift` | 0 | 0 | clean |
| `Droppy/Extensions/ElementCapture/ElementCaptureExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/ElementCapture/ElementCaptureInfoView.swift` | 1 | 0 | ssot-only |
| `Droppy/Extensions/ElementCapture/ElementCaptureManager.swift` | 2 | 2 | raw-only |
| `Droppy/Extensions/ElementCapture/ScreenshotEditorView.swift` | 1 | 1 | raw-only |
| `Droppy/Extensions/ElementCapture/ScreenshotEditorWindowController.swift` | 0 | 0 | clean |
| `Droppy/Extensions/ExtensionDefinition.swift` | 0 | 0 | clean |
| `Droppy/Extensions/ExtensionProtocol.swift` | 0 | 0 | clean |
| `Droppy/Extensions/FFmpegVideoCompression/FFmpegInstallManager.swift` | 0 | 0 | clean |
| `Droppy/Extensions/FFmpegVideoCompression/FFmpegInstallView.swift` | 7 | 1 | mixed |
| `Droppy/Extensions/FFmpegVideoCompression/FFmpegVideoCompressionCard.swift` | 0 | 0 | clean |
| `Droppy/Extensions/FFmpegVideoCompression/VideoTargetSizeExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/FinderServices/FinderServicesCard.swift` | 0 | 0 | clean |
| `Droppy/Extensions/FinderServices/FinderServicesExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/MenuBarManager/MenuBarManagerCard.swift` | 0 | 0 | clean |
| `Droppy/Extensions/MenuBarManager/MenuBarManagerExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/MenuBarManager/MenuBarManagerInfoView.swift` | 0 | 0 | clean |
| `Droppy/Extensions/MenuBarManager/MenuBarManagerManager.swift` | 0 | 0 | clean |
| `Droppy/Extensions/NotificationHUD/NotificationHUDExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/NotificationHUD/NotificationHUDInfoView.swift` | 0 | 0 | clean |
| `Droppy/Extensions/NotificationHUD/NotificationHUDManager.swift` | 0 | 0 | clean |
| `Droppy/Extensions/NotificationHUD/NotificationHUDView.swift` | 12 | 6 | mixed |
| `Droppy/Extensions/Quickshare/QuickshareExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Quickshare/QuickshareInfoView.swift` | 0 | 0 | clean |
| `Droppy/Extensions/RemoveExtensionButton.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Spotify/SpotifyAuthManager.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Spotify/SpotifyCard.swift` | 0 | 0 | clean |
| `Droppy/Extensions/Spotify/SpotifyExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/TerminalNotch/TermiNotchExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/TerminalNotch/TerminalNotchButton.swift` | 0 | 0 | clean |
| `Droppy/Extensions/TerminalNotch/TerminalNotchCard.swift` | 0 | 0 | clean |
| `Droppy/Extensions/TerminalNotch/TerminalNotchInfoView.swift` | 0 | 0 | clean |
| `Droppy/Extensions/TerminalNotch/TerminalNotchManager.swift` | 4 | 1 | mixed |
| `Droppy/Extensions/TerminalNotch/TerminalNotchView.swift` | 2 | 1 | mixed |
| `Droppy/Extensions/ToDo/ToDoExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/ToDo/ToDoInfoView.swift` | 2 | 0 | ssot-only |
| `Droppy/Extensions/ToDo/ToDoManager.swift` | 12 | 12 | raw-only |
| `Droppy/Extensions/ToDo/ToDoShelfBar.swift` | 29 | 11 | mixed |
| `Droppy/Extensions/ToDo/ToDoUndoToast.swift` | 0 | 0 | clean |
| `Droppy/Extensions/ToDo/ToDoView.swift` | 9 | 9 | raw-only |
| `Droppy/Extensions/VoiceTranscribe/VoiceRecordingWindow.swift` | 4 | 3 | mixed |
| `Droppy/Extensions/VoiceTranscribe/VoiceTranscribeCard.swift` | 0 | 0 | clean |
| `Droppy/Extensions/VoiceTranscribe/VoiceTranscribeExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/VoiceTranscribe/VoiceTranscribeInfoView.swift` | 1 | 0 | ssot-only |
| `Droppy/Extensions/VoiceTranscribe/VoiceTranscribeManager.swift` | 0 | 0 | clean |
| `Droppy/Extensions/VoiceTranscribe/VoiceTranscribeMenuBar.swift` | 0 | 0 | clean |
| `Droppy/Extensions/VoiceTranscribe/VoiceTranscriptionResultView.swift` | 1 | 0 | ssot-only |
| `Droppy/Extensions/WindowSnap/SnapPreviewWindow.swift` | 0 | 0 | clean |
| `Droppy/Extensions/WindowSnap/WindowSnapCard.swift` | 0 | 0 | clean |
| `Droppy/Extensions/WindowSnap/WindowSnapExtension.swift` | 0 | 0 | clean |
| `Droppy/Extensions/WindowSnap/WindowSnapInfoView.swift` | 2 | 0 | ssot-only |
| `Droppy/Extensions/WindowSnap/WindowSnapManager.swift` | 0 | 0 | clean |
| `Droppy/ExtensionsShopView.swift` | 9 | 1 | mixed |
| `Droppy/FileCompressor.swift` | 0 | 0 | clean |
| `Droppy/FileConverter.swift` | 0 | 0 | clean |
| `Droppy/FilePromiseDropView.swift` | 0 | 0 | clean |
| `Droppy/FinderFolderDetector.swift` | 0 | 0 | clean |
| `Droppy/FinderServicesSetupView.swift` | 4 | 0 | ssot-only |
| `Droppy/FloatingBasketView.swift` | 22 | 5 | mixed |
| `Droppy/FloatingBasketWindowController.swift` | 0 | 0 | clean |
| `Droppy/FolderIcon.swift` | 1 | 1 | raw-only |
| `Droppy/FolderPreviewPopover.swift` | 0 | 0 | clean |
| `Droppy/GlobalHotKey.swift` | 0 | 0 | clean |
| `Droppy/HUDComponents.swift` | 16 | 3 | mixed |
| `Droppy/HUDLayoutCalculator.swift` | 0 | 0 | clean |
| `Droppy/HUDManager.swift` | 3 | 0 | ssot-only |
| `Droppy/HUDOverlayView.swift` | 8 | 3 | mixed |
| `Droppy/HapticFeedback.swift` | 0 | 0 | clean |
| `Droppy/HexagonDotsEffect.swift` | 1 | 1 | raw-only |
| `Droppy/HideNotchManager.swift` | 0 | 0 | clean |
| `Droppy/KeyShortcutRecorder.swift` | 0 | 0 | clean |
| `Droppy/LicenseActivationView.swift` | 10 | 8 | mixed |
| `Droppy/LicenseManager.swift` | 0 | 0 | clean |
| `Droppy/LicenseSettingsSection.swift` | 4 | 2 | mixed |
| `Droppy/LicenseUIComponents.swift` | 3 | 2 | mixed |
| `Droppy/LicenseWindowController.swift` | 0 | 0 | clean |
| `Droppy/LinkPreviewService.swift` | 0 | 0 | clean |
| `Droppy/LiquidGlassStyle.swift` | 4 | 0 | ssot-only |
| `Droppy/LiquidSlider.swift` | 2 | 0 | ssot-only |
| `Droppy/LockScreenHUDView.swift` | 7 | 7 | raw-only |
| `Droppy/LockScreenHUDWindowManager.swift` | 4 | 1 | mixed |
| `Droppy/LockScreenManager.swift` | 2 | 2 | raw-only |
| `Droppy/LockScreenMediaPanelManager.swift` | 0 | 0 | clean |
| `Droppy/LockScreenMediaPanelView.swift` | 1 | 0 | ssot-only |
| `Droppy/MailHelper.swift` | 0 | 0 | clean |
| `Droppy/MediaKeyInterceptor.swift` | 0 | 0 | clean |
| `Droppy/MediaPlayerComponents.swift` | 25 | 10 | mixed |
| `Droppy/MediaPlayerView.swift` | 25 | 3 | mixed |
| `Droppy/MusicManager.swift` | 0 | 0 | clean |
| `Droppy/NotchDragContainer.swift` | 8 | 1 | mixed |
| `Droppy/NotchFace.swift` | 5 | 2 | mixed |
| `Droppy/NotchItemView.swift` | 24 | 7 | mixed |
| `Droppy/NotchLayoutConstants.swift` | 0 | 0 | clean |
| `Droppy/NotchShelfView.swift` | 96 | 90 | mixed |
| `Droppy/NotchWindowController.swift` | 13 | 4 | mixed |
| `Droppy/OCRResultView.swift` | 1 | 0 | ssot-only |
| `Droppy/OCRService.swift` | 0 | 0 | clean |
| `Droppy/OCRWindowController.swift` | 0 | 0 | clean |
| `Droppy/OnboardingComponents.swift` | 7 | 4 | mixed |
| `Droppy/OnboardingView.swift` | 22 | 4 | mixed |
| `Droppy/Parallax3DModifier.swift` | 2 | 1 | mixed |
| `Droppy/PermissionManager.swift` | 0 | 0 | clean |
| `Droppy/PoofEffect.swift` | 7 | 1 | mixed |
| `Droppy/QuickLookHelper.swift` | 0 | 0 | clean |
| `Droppy/QuickShareSuccessView.swift` | 7 | 3 | mixed |
| `Droppy/QuickshareItem.swift` | 0 | 0 | clean |
| `Droppy/QuickshareManager.swift` | 0 | 0 | clean |
| `Droppy/QuickshareManagerView.swift` | 1 | 0 | ssot-only |
| `Droppy/QuickshareManagerWindowController.swift` | 0 | 0 | clean |
| `Droppy/QuickshareMenuContent.swift` | 0 | 0 | clean |
| `Droppy/QuickshareSettingsContent.swift` | 0 | 0 | clean |
| `Droppy/RenameWindowController.swift` | 0 | 0 | clean |
| `Droppy/RenameWindowView.swift` | 0 | 0 | clean |
| `Droppy/ReorderSheetView.swift` | 12 | 2 | mixed |
| `Droppy/ServiceProvider.swift` | 0 | 0 | clean |
| `Droppy/SettingsPreviewViews.swift` | 17 | 7 | mixed |
| `Droppy/SettingsSidebarItem.swift` | 3 | 0 | ssot-only |
| `Droppy/SettingsView.swift` | 8 | 0 | ssot-only |
| `Droppy/SettingsWindowController.swift` | 0 | 0 | clean |
| `Droppy/SharedComponents.swift` | 31 | 0 | ssot-only |
| `Droppy/SharedDroppyComponents.swift` | 2 | 2 | raw-only |
| `Droppy/ShelfQuickActionsBar.swift` | 15 | 4 | mixed |
| `Droppy/ShelfView.swift` | 9 | 2 | mixed |
| `Droppy/SmartExportManager.swift` | 0 | 0 | clean |
| `Droppy/SmartExportSettingsView.swift` | 2 | 1 | mixed |
| `Droppy/SpotifyController.swift` | 0 | 0 | clean |
| `Droppy/SystemAudioAnalyzer.swift` | 0 | 0 | clean |
| `Droppy/TargetSizeDialog.swift` | 0 | 0 | clean |
| `Droppy/TemporaryFileStorageService.swift` | 0 | 0 | clean |
| `Droppy/ThumbnailCache.swift` | 0 | 0 | clean |
| `Droppy/TrackedFoldersManager.swift` | 0 | 0 | clean |
| `Droppy/URLSchemeHandler.swift` | 0 | 0 | clean |
| `Droppy/UpdateChecker.swift` | 0 | 0 | clean |
| `Droppy/UpdateHUDView.swift` | 1 | 0 | ssot-only |
| `Droppy/UpdateView.swift` | 0 | 0 | clean |
| `Droppy/UpdateWindowController.swift` | 0 | 0 | clean |
| `Droppy/UserPreferences.swift` | 0 | 0 | clean |
| `Droppy/Utilities/CGSShims.swift` | 0 | 0 | clean |
| `Droppy/VolumeManager.swift` | 0 | 0 | clean |

## Top Raw Hotspots

| File | Raw Sites |
|---|---:|
| `Droppy/NotchShelfView.swift` | 90 |
| `Droppy/ClipboardManagerView.swift` | 21 |
| `Droppy/Extensions/ToDo/ToDoManager.swift` | 12 |
| `Droppy/Extensions/ToDo/ToDoShelfBar.swift` | 11 |
| `Droppy/BasketItemView.swift` | 11 |
| `Droppy/MediaPlayerComponents.swift` | 10 |
| `Droppy/Extensions/ToDo/ToDoView.swift` | 9 |
| `Droppy/LicenseActivationView.swift` | 8 |
| `Droppy/BasketSwitcherView.swift` | 8 |
| `Droppy/SettingsPreviewViews.swift` | 7 |
| `Droppy/NotchItemView.swift` | 7 |
| `Droppy/LockScreenHUDView.swift` | 7 |
| `Droppy/Extensions/NotificationHUD/NotificationHUDView.swift` | 6 |
| `Droppy/Extensions/AIBackgroundRemoval/AIInstallComponents.swift` | 6 |
| `Droppy/DroppyDesign.swift` | 6 |
| `Droppy/AirPodsHUDView.swift` | 6 |
| `Droppy/FloatingBasketView.swift` | 5 |
| `Droppy/ShelfQuickActionsBar.swift` | 4 |
| `Droppy/OnboardingView.swift` | 4 |
| `Droppy/OnboardingComponents.swift` | 4 |
| `Droppy/NotchWindowController.swift` | 4 |
| `Droppy/BasketStackPreviewView.swift` | 4 |
| `Droppy/QuickShareSuccessView.swift` | 3 |
| `Droppy/MediaPlayerView.swift` | 3 |
| `Droppy/HUDOverlayView.swift` | 3 |
| `Droppy/HUDComponents.swift` | 3 |
| `Droppy/Extensions/VoiceTranscribe/VoiceRecordingWindow.swift` | 3 |
| `Droppy/ShelfView.swift` | 2 |
| `Droppy/SharedDroppyComponents.swift` | 2 |
| `Droppy/ReorderSheetView.swift` | 2 |
| `Droppy/NotchFace.swift` | 2 |
| `Droppy/LockScreenManager.swift` | 2 |
| `Droppy/LicenseUIComponents.swift` | 2 |
| `Droppy/LicenseSettingsSection.swift` | 2 |
| `Droppy/Extensions/ElementCapture/ElementCaptureManager.swift` | 2 |
| `Droppy/DroppyAlertView.swift` | 2 |
| `Droppy/DroppedItemView.swift` | 2 |
| `Droppy/AppKitMotion.swift` | 2 |
| `Droppy/SmartExportSettingsView.swift` | 1 |
| `Droppy/PoofEffect.swift` | 1 |

## Top Hardcoded Primitive Hotspots

| File | Primitive Sites |
|---|---:|
| `Droppy/MediaPlayerComponents.swift` | 9 |
| `Droppy/BasketSwitcherView.swift` | 8 |
| `Droppy/SettingsPreviewViews.swift` | 7 |
| `Droppy/LockScreenHUDView.swift` | 7 |
| `Droppy/Extensions/ToDo/ToDoShelfBar.swift` | 6 |
| `Droppy/DroppyDesign.swift` | 6 |
| `Droppy/Extensions/ToDo/ToDoView.swift` | 5 |
| `Droppy/BasketItemView.swift` | 5 |
| `Droppy/NotchShelfView.swift` | 4 |
| `Droppy/NotchItemView.swift` | 4 |
| `Droppy/Extensions/NotificationHUD/NotificationHUDView.swift` | 4 |
| `Droppy/ClipboardManagerView.swift` | 4 |
| `Droppy/BasketStackPreviewView.swift` | 4 |
| `Droppy/AirPodsHUDView.swift` | 4 |
| `Droppy/QuickShareSuccessView.swift` | 3 |
| `Droppy/OnboardingComponents.swift` | 3 |
| `Droppy/SharedDroppyComponents.swift` | 2 |
| `Droppy/ReorderSheetView.swift` | 2 |
| `Droppy/OnboardingView.swift` | 2 |
| `Droppy/NotchWindowController.swift` | 2 |
| `Droppy/LicenseActivationView.swift` | 2 |
| `Droppy/FloatingBasketView.swift` | 2 |
| `Droppy/Extensions/VoiceTranscribe/VoiceRecordingWindow.swift` | 2 |
| `Droppy/Extensions/ElementCapture/ElementCaptureManager.swift` | 2 |
| `Droppy/DroppyAlertView.swift` | 2 |
| `Droppy/AppKitMotion.swift` | 2 |
| `Droppy/SmartExportSettingsView.swift` | 1 |
| `Droppy/PoofEffect.swift` | 1 |
| `Droppy/Parallax3DModifier.swift` | 1 |
| `Droppy/MediaPlayerView.swift` | 1 |
| `Droppy/LockScreenHUDWindowManager.swift` | 1 |
| `Droppy/LicenseUIComponents.swift` | 1 |
| `Droppy/HUDOverlayView.swift` | 1 |
| `Droppy/HUDComponents.swift` | 1 |
| `Droppy/Extensions/TerminalNotch/TerminalNotchView.swift` | 1 |
| `Droppy/Extensions/TerminalNotch/TerminalNotchManager.swift` | 1 |
| `Droppy/Extensions/FFmpegVideoCompression/FFmpegInstallView.swift` | 1 |
| `Droppy/Extensions/ElementCapture/ScreenshotEditorView.swift` | 1 |
| `Droppy/Extensions/ElementCapture/CapturePreviewView.swift` | 1 |
| `Droppy/Extensions/AIBackgroundRemoval/AIInstallView.swift` | 1 |
