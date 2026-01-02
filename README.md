<p align="center">
  <img src="https://github.com/iordv/Droppy/raw/main/Droppy/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Droppy Icon" width="128">
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <strong>A drag-and-drop file shelf that lives in your notch</strong>
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#features">Features</a> •
  <a href="#usage">Usage</a> •
  <a href="#requirements">Requirements</a>
</p>

---

## What is Droppy?

Droppy is a **free, open-source** macOS app that gives you a temporary file shelf right in your notch. Drop files there while you navigate to their destination — no more juggling Finder windows or cluttering your desktop.

Built with the new **Liquid Glass** design language from macOS Tahoe, Droppy feels native and beautiful.

## Installation

### Homebrew (Recommended)

```bash
brew install iordv/tap/droppy
```

### Manual Download

1. Download [`Droppy.dmg`](https://github.com/iordv/Droppy/raw/main/Droppy.dmg)
2. Drag `Droppy.app` to your Applications folder
3. Right-click → Open (required for unsigned apps)

## Features

### 🗂️ Notch File Shelf
Drop files onto the notch area and they'll stay there until you need them. The shelf expands smoothly to show your files with beautiful animations.

### ✨ Liquid Glass Design
Built for macOS 26 Tahoe with the new Liquid Glass aesthetic — translucent materials, smooth animations, and that signature refractive look.

### 🔄 File Conversion
Right-click any file to convert between formats:
- **Images**: PNG ↔ JPEG, HEIC → JPEG/PNG, TIFF, BMP, GIF
- **Documents**: Word, Excel, PowerPoint → PDF (requires [Gotenberg](https://gotenberg.dev))

### 💾 Quick Save
Right-click any file in the shelf and choose "Save" to quickly save it to a location of your choice.

### ⚙️ Customizable
- Launch at login
- Menu bar icon toggle
- Transparent background option for a cleaner look

### 🔒 Privacy-First
- No analytics or tracking
- No network requests (except optional document conversion)
- All files stay local on your Mac

## Usage

1. **Add files**: Drag files onto the notch area — it glows to show it's ready
2. **View shelf**: Hover over the notch or click to expand
3. **Use files**: Drag files out to their destination
4. **Convert files**: Right-click → Convert to...
5. **Clear shelf**: Click the trash icon or drag files out

## Requirements

- **macOS 26.0 (Tahoe)** or later
- Mac with a notch (MacBook Pro 14"/16", MacBook Air M2/M3)

> **Note**: Since Droppy isn't code-signed, you'll need to right-click → Open on first launch, or run:
> ```bash
> xattr -d com.apple.quarantine /Applications/Droppy.app
> ```

## Document Conversion Setup (Optional)

To enable Word/Excel/PowerPoint → PDF conversion, run Gotenberg locally:

```bash
docker run -d -p 3001:3000 gotenberg/gotenberg:8
```

Image conversions work natively without any additional setup.

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
