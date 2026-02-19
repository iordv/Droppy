<p align="center">
  <img src="docs/assets/images/droppy-icon-dark.png" alt="Droppy" width="140" />
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <b>The native productivity layer macOS is missing.</b><br>
  <sub>100% Swift • Signed & Notarized • Source-Available</sub>
</p>

<p align="center">
  <a href="https://github.com/iordv/Droppy/releases/latest"><img src="assets/download-macos.png" alt="Download for macOS" width="200" /></a>
</p>
<p align="center">
  <a href="https://iordv.gumroad.com/l/Droppy"><b>Buy License on Gumroad (€6.99)</b></a>
</p>

<p align="center">
  <a href="https://github.com/iordv/Droppy/releases/latest"><img src="https://img.shields.io/github/v/release/iordv/Droppy?style=flat-square&label=Version" /></a>
  <a href="https://github.com/iordv/Droppy/stargazers"><img src="https://img.shields.io/github/stars/iordv/Droppy?style=flat-square" /></a>
  <a href="https://github.com/iordv/Droppy/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-Source--Available-blue?style=flat-square" /></a>
  <a href="https://discord.gg/YCMDFV5M7d"><img src="https://img.shields.io/badge/Discord-Join-5865F2?style=flat-square&logo=discord&logoColor=white" /></a>
</p>

---

## Latest Release

<!-- CHANGELOG_START -->
## 🚀 Droppy v11.2.1
**New Features**
- Added screenshot step annotations: tap, enter a number, done.
- Added beautiful screenshot-editor backgrounds with gradients, shadows, and independent corner radius controls for screenshot and background exports.
- Added magnifier tool support (`M`) with source-point placement, post-placement dragging, and consistent preview/save rendering.
- Added magnifier hint badge, edge-resize behavior, and size-based zoom scaling for larger lenses.
- Added a background-source option for stylized screenshot-editor backgrounds.
- Added picture-in-picture mode for Element Capture screenshot editing.
- Added meeting-link actions in Calendar + Task view for instant join.
- Added watched-folder origin labels and tracked capsule badges for Shelf/Basket items that came from tracked folders.
- Expanded Element Capture menu into a full submenu: Element, Area, Fullscreen, Window, Scrolling, OCR, and Configure.
- Expanded Window Snap menus to all `SnapAction.allCases`, grouped with Configure action.
- Added Menu Manager/Floating Bar side-aware RTL handling so Arabic/RTL menu bars behave as first-class layouts.
- Added stale-notification filtering and payload deduplication to suppress repeated calendar burst notifications.
- Added internal quick-view fetch path so installs/stars load correctly when opened from the eye-icon quick view.
- Added quarter-step volume/brightness support on Option+Shift, including Karabiner remaps emitting those modifiers.
- Added fallback to real app icon for dashed placeholders (for Alfred-like entries).
- Added WebP recognition in file-converter `availableConversions(for:)`, with JPEG/PNG-equivalent conversion options.
**Bug Fixes**
- Fixed screen-detection edge cases and removed the misleading mode picker on desktop Macs so external-display style controls behave correctly.
- Fixed shelf/media open-close, click-drag hit handling, and alignment consistency across shelf view, controller, and drag-container paths.
- Fixed Dock icon sizing in Settings to match menu-bar icon sizing.
- Fixed floating-bar icon tinting by replacing contextual `.primary` dependence with adaptive app label colors for light/dark readability.
- Fixed targeted stuck dim overlay issue after closing extension sheets.
- Fixed menu-window detection by tracking owner menus even when cursor is outside the menu window.
- Fixed menu dismissal reliability with a forced close fallback (Escape + short wait) when a menu remains active at dismissal boundary.
- Fixed restore-task cancellation flow by applying the same dismissal behavior before canceling in-flight restore when a restore/menu session exists.
- Fixed wrong-screen menu-session persistence by hardening interactive-zone screen resolution using divider-edge anchoring.
- Fixed floating bar placement/hover behavior so it stays under the divider and no longer disappears on hover or jumps under left menu-bar items.
- Fixed Notification HUD foreground contrast in transparent modes by switching to adaptive dark/light foregrounds.
- Fixed white-on-white regressions in HUD/media components by removing hardcoded white text and unifying adaptive foreground logic for transparent non-physical-notch modes.
- Fixed Caffeine/High Alert foreground contrast to follow the same adaptive HUD/media foreground behavior.
- Fixed terminal panel readability for command output, command text, placeholder text, and input chrome in light backgrounds.
- Fixed light-mode color handling for volume/brightness HUDs.
- Fixed settings icon rendering to match floating-bar renderer so white glyphs switch dark in light/white modes.
- Fixed calendar layout spacing by moving calendar content up in dual and single modes.
- Fixed single-pane day visibility and small-mode day-strip readability so all days remain visible.
- Fixed dynamic-island + light-mode notification white-on-white issue.
- Fixed Menu Bar Manager performance when opening from right-click on its menu-bar icon.
- Fixed granted-permissions UI to show confirmed badges instead of toggle-looking controls.
- Fixed rehide behavior to timed-only flow with delay tuning only.
- Fixed Menu Bar settings clarity with cleaner hierarchy and lower text density.
- Fixed default media-key target behavior to use the display under pointer for immediate third-party external display control compatibility.
- Fixed stale Spotify artwork persistence when source changes (for example Eter) without usable art.
- Fixed issue #267 so shelf actions are no longer interrupted by shelf dismissal.
- Fixed Notify Me queue handling so notifications queued behind another HUD are retried automatically.
- Fixed tracked-item lifecycle by carrying watched-folder metadata on tracked-folder drops and auto-cleaning ghost items when files are trashed externally (including closing empty baskets).
- Fixed icon-menu responsiveness across Droppy icons so menus feel near-instant.
- Fixed expanded Shelf/Basket thumbnail sizing to improve visual clarity.
- Fixed list-row rendering overhead by caching file-size metadata asynchronously instead of per-frame disk reads.
- Fixed Finder drop responsiveness by moving “drop selected to Finder” detection/copy work off the main thread and keeping UI updates on main.
- Fixed drag/render overhead by removing hot-path logging and redundant animation work.
- Fixed NotificationHUD cross-thread UI-state mutation risk.
- Fixed ToDo list animation overhead by switching triggers to cached signatures.
- Fixed screenshot-editor toolbar density by collapsing sticker tools into a single popover picker and exposing one visible color + one visible thickness control with hover/tap pickers.
- Fixed symbol/accessibility consistency by including PR #261 RTL/accessibility symbol + shortcut-order improvements and missed external-link icons.
<!-- CHANGELOG_END -->

## See Droppy in Action

<div align="center">
  <video src="https://github.com/user-attachments/assets/813c3eea-6588-4f23-880f-135833d26a16" width="100%" autoplay loop muted playsinline>
    Your browser does not support the video tag.
  </video>
  <sub>📱 Can't see the video? <a href="https://github.com/user-attachments/assets/813c3eea-6588-4f23-880f-135833d26a16">Watch it here</a></sub>
</div>


<h2 align="left">Core Features</h2>

<h3 align="center">File Shelf</h3>

<p align="center"><img src="docs/assets/images/feature-shelf.png" width="500" alt="File Shelf" /></p>

- Drop files, folders, images, and URLs onto the notch — pick them up in any app
- Create folders, pin favorites, or watch a directory so its contents appear automatically
- Right-click for Copy, Move, Share, AirDrop, Rename, Quick Look, OCR, and more
- Quickshare: upload any file and get a shareable link in one click
- ZIP and Unzip files directly from the shelf
- Convert between dozens of file types — images, videos, audio, documents

---

<h3 align="center">Floating Basket</h3>

<p align="center"><img src="docs/assets/images/feature-basket.png" width="500" alt="Floating Basket" /></p>

- Jiggle your mouse while dragging to spawn a floating basket anywhere on screen
- Multiple color-coded baskets for organizing different workflows
- Cmd+Tab-style basket switcher to jump between baskets instantly
- List and grid view for browsing basket contents
- Quick actions to open, share, copy, or remove items fast
- Auto-hide when empty or idle — batch-drag items between apps

---

<h3 align="center">Clipboard Manager</h3>

<p align="center"><img src="docs/assets/images/feature-clipboard.png" width="500" alt="Clipboard Manager" /></p>

- Saves every text, image, file, link, and color you copy — persistent across restarts
- Full PDF and Office document viewer, plus inline video playback
- Custom tags with deep customization — filter, rename, color-code, and organize
- Flag, favorite, or star entries for quick access
- Push clipboard entries directly to the shelf or basket
- Source app filtering and full-text search across your entire history

---

<h3 align="center">Beautiful HUDs</h3>

<p align="center"><img src="docs/assets/images/feature-huds.png" width="500" alt="Beautiful HUDs" /></p>

- Replaces macOS system overlays with beautifully animated HUDs in your notch
- Volume, brightness, and keyboard backlight — including full external monitor support
- Now-playing with album art, progress scrubbing, and visualizer (Spotify & Apple Music)
- Full Apple Music controls: shuffle, repeat, love tracks, skip, and scrub
- AirPods connection with per-ear battery levels and charging state
- Notification banners, Do Not Disturb, power state, and mic/camera indicators

## <img src="https://getdroppy.app/assets/icons/extensions.png" width="24"> Extensions

Modular extensions add even more power. **Install only what you need.**

| Icon | Extension | Description |
|:----:|-----------|-------------|
| <img src="https://getdroppy.app/assets/icons/apple-music.png" width="24"> | [**Apple Music**](https://getdroppy.app/extensions.html) | Full playback controls with shuffle, repeat, love tracks & lyrics |
| <img src="https://getdroppy.app/assets/icons/spotify.png" width="24"> | [**Spotify**](https://getdroppy.app/extensions.html) | Spotify playback with album art, visualizer & media controls |
| <img src="https://getdroppy.app/assets/icons/notification-hud.png" width="24"> | [**Notify Me!**](https://getdroppy.app/extensions.html) | Beautiful notification banners that appear in your notch |
| <img src="https://getdroppy.app/assets/icons/window-snap.jpg" width="24"> | [**Window Snap**](https://getdroppy.app/extensions.html) | Keyboard shortcuts for snapping windows to screen edges & displays |
| <img src="https://getdroppy.app/assets/icons/high-alert.jpg" width="24"> | [**High Alert**](https://getdroppy.app/extensions.html) | Keep your Mac awake with customizable timers & schedules |
| <img src="https://getdroppy.app/assets/icons/terminotch.jpg" width="24"> | [**Termi-Notch**](https://getdroppy.app/extensions.html) | Quick terminal access with hotkey — run commands instantly |
| <img src="https://getdroppy.app/assets/icons/alfred.png" width="24"> | [**Alfred**](https://getdroppy.app/extensions.html) | Deep Alfred integration — trigger workflows from your notch |
| <img src="https://getdroppy.app/assets/icons/finder.png" width="24"> | [**Finder Services**](https://getdroppy.app/extensions.html) | Right-click in Finder to add files to Shelf or Basket |
| <img src="https://getdroppy.app/assets/icons/quickshare.jpg" width="24"> | [**Quickshare**](https://getdroppy.app/extensions.html) | Upload files to the cloud, get instant shareable links |
| <img src="https://getdroppy.app/assets/icons/targeted-video-size.jpg" width="24"> | [**Video Target Size**](https://getdroppy.app/extensions.html) | Compress videos to exact file sizes using FFmpeg |
| <img src="https://getdroppy.app/assets/icons/element-capture.jpg" width="24"> | [**Element Capture**](https://getdroppy.app/extensions.html) | Screenshot & annotate with full editor: arrows, blur, text, shapes, configurable shortcuts |
| <img src="https://getdroppy.app/assets/icons/voice-transcribe.jpg" width="24"> | [**Voice Transcribe**](https://getdroppy.app/extensions.html) | Transcribe audio to text using on-device AI |
| <img src="https://getdroppy.app/assets/icons/ai-bg.jpg" width="24"> | [**Background Removal**](https://getdroppy.app/extensions.html) | Remove image backgrounds with AI — one click |
| <img src="https://getdroppy.app/assets/icons/menubarmanager.png" width="24"> | [**Menu Bar Manager**](https://getdroppy.app/extensions.html) | Hide & organize menu bar icons with hover reveal, plus the new Floating Bar Manager under the menu bar |
| <img src="https://getdroppy.app/assets/icons/reminders.png" width="24"> | [**Reminders**](https://getdroppy.app/extensions.html) | Capture tasks in natural language & sync with Apple Reminders |
| <img src="https://getdroppy.app/assets/icons/snap-camera-v2.png" width="24"> | [**Notchface**](https://getdroppy.app/extensions.html) | Floating camera button with full live preview in your notch |

## FAQ

<details>
<summary><b>How much does Droppy cost?</b></summary>
<br>
Droppy is a one-time payment of €6.99 — lifetime. All features, all extensions, and all future updates included. No subscriptions, no recurring fees.
</details>

<details>
<summary><b>Is it safe to install?</b></summary>
<br>
Droppy is signed and notarized by Apple. You can install it without any security warnings.
</details>

<details>
<summary><b>Does it work on Macs without a notch?</b></summary>
<br>
Yes! Droppy works on all Macs (with or without physical notch) using a "Dynamic Island" style.
</details>

<details>
<summary><b>How do I get updates?</b></summary>
<br>
Droppy has built-in update notifications. Or use Homebrew: <code>brew upgrade --cask droppy</code>
</details>

<details>
<summary><b>Can I contribute?</b></summary>
<br>
Absolutely! PRs welcome. Check out the issues for ideas or propose your own.
</details>


## License

Droppy is source-available under [GPL-3.0 with Commons Clause](LICENSE).
This license is not OSI open source and restricts selling the software.

<p align="center">
  <sub>Made with ❤️ in The Netherlands</sub>
</p>

<details>
<summary><sub>Credits & Acknowledgements</sub></summary>
<sub>
<br>
<b>macOS Productivity Community</b> — Thanks to the developers and contributors who inspired better notch and menu bar experiences.
</sub>
</details>
