<p align="center">
  <img src="https://i.postimg.cc/PxdpGc3S/appstore.png" alt="Droppy Icon" width="128">
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <strong>The ultimate drag-and-drop file shelf for macOS</strong>
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#features">Features</a> •
  <a href="#usage">Usage</a> •
  <a href="#requirements">Requirements</a>
</p>

---

## What is Droppy?

Droppy is a **free, open-source** utility that makes file management on macOS effortless. It provides you with a temporary shelf to store files while you navigate between apps and folders. No more juggling finder windows or cluttering your desktop with temporary screenshots.

**Now updated to Version 2.0**, Droppy is more powerful than ever.

## Installation

### Homebrew (Recommended)

```bash
brew install iordv/tap/droppy
```

### Manual Download

1. Download [`Droppy.dmg`](https://github.com/iordv/Droppy/raw/main/Droppy.dmg)
2. Drag `Droppy.app` to your Applications folder
3. Right-click → Open (required for unsigned apps)

<!-- CHANGELOG_START -->
Fixed: App quitting when closing Settings window
Fixed: Crash when moving basket during animation
Fixed: Window memory management stability improvements
<!-- CHANGELOG_END -->

## Features

### 🗂️ Notch File Shelf
The classic experience. Drop files onto the notch area, and they'll stay there safely. Hover to expand, drag out to use.

### ✨ Liquid Glass Design
Built with a stunning, translucent interface that feels at home on modern macOS.

### 🔄 File Conversion
Right-click any file to convert between formats:
- **Images**: PNG ↔ JPEG, HEIC → JPEG/PNG, TIFF, BMP, GIF
- **Documents**: Word, Excel, PowerPoint → PDF

### 🔒 Privacy-First
- No analytics or tracking.
- Your files stay on your Mac.
- Optional Cloudmersive API usage for documents is processed in-memory and never stored.

## Usage

1. **Add files**: Drag files to the notch (or jiggle for the basket!)
2. **View shelf**: Hover over the notch area
3. **Organize**: Convert, rename, or zip files directly in the shelf
4. **Use files**: Drag them out to their final destination
5. **Clear shelf**: Click the trash icon or drag files out

<p align="center">
  <img src="https://github.com/user-attachments/assets/placeholder-jiggle" alt="Jiggle Feature" width="600">
  <br>
  <em>Enable "Jiggle to Reveal" in Settings for the ultimate drag-and-drop experience.</em>
</p>

## Requirements

- **macOS 14.0 (Sonoma)** or later
- Works on all Macs (Notch recommended but not required)

> **Note**: Since Droppy isn't code-signed, you'll need to right-click → Open on first launch, or run:
> ```bash
> xattr -d com.apple.quarantine /Applications/Droppy.app
> ```

## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/iordv">Jordy Spruit</a>
</p>
