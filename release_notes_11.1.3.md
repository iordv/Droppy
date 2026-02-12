## 🚀 Droppy v11.1.3

This release bundles **all updates since v11.1.2** into one full release.

## ⭐ Major upgrades
- Added a major ToDo + Calendar overhaul in the shelf:
  - New timeline-first task/calendar UI.
  - New split details panel for editing tasks while viewing events.
  - Combined Tasks + Calendar mode, plus tasks-only and calendar-only behavior.
  - Native day strip navigation with week paging and improved keyboard navigation.
- Added multi-calendar selection for Apple Calendar sync:
  - Select individual calendar lists.
  - Quick “All” / “None” controls.
  - Persisted calendar-list selections.
- Added due-soon reminders for tasks/events:
  - Notifications at 15 minutes and 1 minute before due/start.
  - Optional notification chime.
  - Better due-date awareness for timed vs all-day items.
- Added task timeline display options:
  - Week number display.
  - Timezone suffix display for timed items.

## 📸 Element Capture and screenshot pipeline improvements
- Fixed capture drift and coordinate issues on dock/undock and mixed-DPI setups.
- Added robust full-display capture path for ScreenCaptureKit when needed.
- Excluded Droppy helper/editor windows from captured output to avoid self-capture artifacts.
- Upgraded screenshot editor rendering so saved output matches on-canvas annotations.
- Added curved-arrow annotation tool.
- Improved annotation editing UX:
  - Better hit-testing for all annotation types.
  - More reliable annotation dragging/movement.
  - Better scaling consistency across export sizes.

## ⚙️ Settings and preferences revamp
- Reorganized Settings sections and grouping for clearer navigation.
- Added/updated settings for:
  - Cloud quick-action provider (Droppy Quickshare vs iCloud Drive).
  - Media album art glow.
  - External mouse shelf/media switch button.
  - Caffeine “instant shelf expand on hover.”
  - ToDo split view, due-soon notifications/chime, week number, timezone.
  - Media visualizer mode normalization and behavior.
- Improved privacy and accessibility settings structure and prompt flows.
- Improved settings-window lifecycle cleanup to reduce retained UI/memory.

## ☁️ Quick Actions cloud improvements
- Added cloud-provider abstraction for quick share actions:
  - Droppy Quickshare provider.
  - iCloud Drive provider with readiness checks and safer share flow.
- Updated shelf/basket quick-action bars to use selected provider.

## 🎵 Media and notch behavior improvements
- Fixed visualizer mode issues and enforced valid single-mode defaults.
- Improved mini and full visualizer observation lifecycle.
- Added full album-art glow toggle support across media views.
- Improved shelf/media switching behavior and interaction areas.
- Added optional external-mouse floating media/shelf switch button.

## 🧠 Stability, performance, and memory improvements
- Fixed Menu Bar Manager right-click menu retention/memory issues.
- Improved menu hover performance and reduced event churn.
- Added menu-open guards to avoid unnecessary hover/scroll processing.
- Optimized multiple icon/image lookup paths using shared thumbnail caching.
- Improved async image loading/caching with in-flight dedupe and bounded caches.
- Improved link-preview image decoding and request synchronization.
- Reduced unnecessary parallax and background effect computations.
- Improved preview animation timer lifecycle to avoid duplicate timers.

## 🔒 Lock screen and HUD reliability
- Fixed lock HUD display targeting and geometry behavior across display changes.
- Improved lock/unlock HUD routing to preferred display target.
- Improved notification HUD rendering rules for due-soon notifications.

## 🧩 Extensions and integrations
- AI Background Removal installer is now more robust:
  - Isolated managed venv flow.
  - Better Python runtime compatibility checks.
  - Improved install verification and cleanup.
- Terminal Notch focus and activation behavior improved.
- Finder/WindowSnap/Clipboard accessibility request flows now use clearer context handling.

## 🎬 Onboarding and Finder Services updates
- Updated onboarding flow behavior and window sizing transitions:
  - Stable page-based size handling.
  - Cleaner completion flow integration.
  - Included lock-screen onboarding page in this release flow.
- Improved Finder Services setup guidance:
  - Better deep links (Keyboard Shortcuts / Services).
  - Clearer step wording and fallback instructions if System Settings doesn’t open automatically.

## 🛠️ Additional polish
- Improved collapsed basket initial thumbnail resolution reliability.
- Improved menu scrolling responsiveness.
- Fixed notch/shelf interaction hit areas and hover/collapse behavior.
- Numerous layout, animation, and interaction refinements across Shelf, ToDo, Media, Onboarding, and Settings.
