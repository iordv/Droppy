
<p align="center">
  <img src="https://i.postimg.cc/9FxZhRf3/1024-mac.webp" alt="Droppy Icon" width="128">
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <strong>Your files. Everywhere. Instantly.</strong><br>
  <em>The free, open-source alternative to paid file management apps.</em>
</p>

<p align="center">
    <a href="https://github.com/iordv/Droppy/releases/latest"><img src="https://img.shields.io/github/v/release/iordv/Droppy?style=flat-square&color=007AFF" alt="Latest Release"></a>
    <a href="https://github.com/iordv/Droppy/releases/latest"><img src="https://img.shields.io/badge/⬇_Download-DMG-success?style=flat-square" alt="Download"></a>
    <img src="https://img.shields.io/badge/platform-macOS_14+-lightgrey?style=flat-square" alt="Platform">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="#-installation">Install</a> •
  <a href="#-core-features">Features</a> •
  <a href="#-how-to-use">Usage</a> •
  <a href="#-whats-new">Changelog</a>
</p>

---

<div align="center">

![Droppy Demo](https://github.com/user-attachments/assets/59ed67af-6719-4f83-918d-ed6d10183782)

**Drag files to your notch • Summon the basket anywhere • Right-click for powerful actions**

</div>

---

<p align="center">
  🆓 <strong>100% Free & Open Source</strong> — No subscriptions. No ads. No tracking. Forever.<br>
  🖥️ <strong>Works on ANY Mac</strong> — Non-notch displays get a gorgeous Dynamic Island-style pill interface!
</p>

---

## ✨ Core Features

### Notch Shelf
Drag files to your notch — they vanish into a sleek shelf, ready when you need them.

<p align="center">
  <img src="assets/previews/shelf_preview.gif" alt="Notch Shelf" width="600">
</p>

---

### Floating Basket
Jiggle your mouse while dragging to summon a basket anywhere on screen.

<p align="center">
  <img src="assets/previews/clipboard_preview.gif" alt="Floating Basket" width="600">
</p>

---

### Clipboard Manager
Full history with search, favorites, OCR text extraction, and drag-out support.

<p align="center">
  <img src="assets/previews/basket_preview.gif" alt="Clipboard Manager" width="600">
</p>

---

### Media Player
Now Playing controls in your notch with album art and seek slider.

<p align="center">
  <img src="assets/previews/media_player_preview.gif" alt="Media Player" width="600">
</p>

---

### Custom HUDs
Beautiful volume, brightness, battery, and Caps Lock overlays.

<p align="center">
  <img src="assets/previews/hud_preview.gif" alt="Custom HUDs" width="600">
</p>

---

## More Features

| Feature | Description |
|:--------|:------------|
| <img src="assets/spotify_icon.png" alt="Spotify" width="18" height="18"> **Native Spotify** | Shuffle, repeat, and rock-solid playback timing directly from Spotify |
| **Quick Actions** | Right-click any file for compress, convert, OCR, move, share, and more |
| **Move To...** | Send files directly to saved folder locations like your NAS or cloud drives |
| **Smart Compression** | Compress images, PDFs, and videos with auto or target size options |
| **Auto-Hide Basket** | Basket slides to screen edge when idle, peeks out on hover |
| **Multi-Monitor** | Works on external displays with smart fullscreen detection |
| **Dynamic Island** | Non-notch Macs get a beautiful floating pill interface |
| **Alfred Integration** | Push files to Droppy from Alfred with a quick action |

---

## 📦 Installation

### Homebrew (Recommended)
```bash
brew install --cask iordv/tap/droppy
```

### Manual Download
1. Download [**Droppy.dmg**](https://github.com/iordv/Droppy/releases/latest)
2. Open the DMG and drag Droppy to Applications
3. **Important:** Before first launch, run this command in Terminal:
   ```bash
   xattr -rd com.apple.quarantine /Applications/Droppy.app
   ```
4. Open Droppy from your Applications folder

> ⚠️ **"Droppy is damaged and can't be opened"?**
> 
> This happens because macOS quarantines apps downloaded from the internet. The `xattr` command above removes this flag. This is safe — Droppy is open source and you can [verify the code yourself](https://github.com/iordv/Droppy).
>
> Alternatively, use **Homebrew** which handles this automatically.

---

## 🕹️ How to Use

### Stash Files
- **Notch**: Drag any file to the black area around your webcam
- **Basket**: While dragging, **shake your mouse left-right** — a basket appears at your cursor

### Quick Actions
Right-click any item in the shelf to:
- **Move To...** — Send to saved locations
- **Compress** — Auto or specify a target size
- **Convert** — e.g., HEIC → JPEG
- **Extract Text** — OCR to copy text from images
- **Share** or **Reveal in Finder**

### Drop Files
Drag files out of the shelf and drop into any app. The file moves and vanishes from the shelf.

### Clipboard Manager

| Action | Shortcut | Description |
|:-------|:---------|:------------|
| Open | `⌘ + Shift + Space` | Opens the clipboard history panel from anywhere |
| Navigate | `↑` `↓` | Move through your clipboard history |
| Paste | `Enter` | Paste the selected item and close |
| Search | `⌘ + F` | Filter items by text content |
| Favorite | `⭐` | Pin important items to the top |

> Works everywhere — even in password fields and Terminal.

---

## Pro Tips

### <img src="assets/alfred_icon.png" alt="Alfred" width="24" height="24"> Alfred Integration
Push files from Finder to Droppy: **Settings** → **About** → **Install in Alfred**, then use Alfred's Universal Actions on any file.

### Smart Compression
- **Auto**: Balanced settings for most files
- **Target Size**: Need under 2MB? Right-click → Compress → **Target Size...**
- **Size Guard**: If compression would make the file larger, Droppy keeps the original

### Drag-and-Drop OCR
Drag an image into Droppy, hold **Shift** while dragging out, and drop into a text editor — **it's text!**

### Auto-Hide Basket
Enable in Settings → Basket → **Auto-Hide**. The basket slides to the screen edge when not in use and peeks out on hover.

---

## 🆕 What's New

<details>
<summary><strong>v5.4.2 — Rename Fix</strong></summary>

<!-- CHANGELOG_START -->
# Droppy v5.4.3 - Visual Harmony Update

## UI Improvements

- **Universal Corner Radius Harmony**: Complete audit and unification of all corner radii across the entire app
  - 16pt for buttons, cards, and medium elements
  - 14pt for thumbnails and internal cards
  - 8pt for small elements and selection indicators
  - 4pt for sliders and progress bars
  
- **Basket & Shelf Consistency**: Perfect visual parity between Floating Basket and Notch Shelf items
  - Unified thumbnail corner radius (14pt)
  - Matched hover effect backgrounds and opacities
  - Consistent text colors and font sizes
  
- **Settings Preview Polish**: Fixed PeekPreview component to match real basket proportions

## Bug Fixes

- Fixed shelf item hover effects overlapping outer edge (added proper clipping)
- Fixed basket item label color inconsistency (.primary → .white)
- Fixed NotchControlButton border opacity mismatch (0.1 → 0.15)
- Fixed HUD album art placeholder corner radius (5pt → 4pt)

## Documentation

- Cleaned up README with emoji-free tables and headers
- Added high-quality 30fps GIF previews for all features
- Added official Alfred icon to integration section
<!-- CHANGELOG_END -->

</details>

---

## ❤️ Support Droppy

<p align="center">
  <strong>Droppy is 100% free and open source — no ads, no subscriptions, ever.</strong><br>
  If it saves you time, consider fueling future development with a coffee!
</p>

<p align="center">
  <a href="https://buymeacoffee.com/droppy">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="220">
  </a>
</p>

---

## ⭐ Star History

<p align="center">
  <a href="https://star-history.com/#iordv/Droppy&Timeline">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=iordv/Droppy&type=Timeline&theme=dark" />
      <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=iordv/Droppy&type=Timeline" />
      <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=iordv/Droppy&type=Timeline" width="600" />
    </picture>
  </a>
</p>

---

<p align="center">
  <strong>MIT License</strong> — Free and Open Source forever.<br>
  Made with ❤️ by <a href="https://github.com/iordv">Jordy Spruit</a>
</p>
