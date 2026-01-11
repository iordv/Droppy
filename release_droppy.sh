#!/bin/bash

# Configuration
MAIN_REPO="/Users/jordyspruit/Desktop/Droppy"
TAP_REPO="/Users/jordyspruit/Desktop/homebrew-tap"

# --- Colors & Styles ---
BOLD="\033[1m"
RESET="\033[0m"
BLUE="\033[1;34m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
MAGENTA="\033[1;35m"
DIM="\033[2m"

# --- Helpers ---
info() { echo -e "${BLUE}==>${RESET} ${BOLD}$1${RESET}"; }
success() { echo -e "${GREEN}✔ $1${RESET}"; }
warning() { echo -e "${YELLOW}⚠ $1${RESET}"; }
error() { echo -e "${RED}✖ Error: $1${RESET}"; exit 1; }
step() { echo -e "   ${DIM}→ $1${RESET}"; }

header() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
    ____                                
   / __ \_________  ____  ____  __  __
  / / / / ___/ __ \/ __ \/ __ \/ / / /
 / /_/ / /  / /_/ / /_/ / /_/ / /_/ / 
/_____/_/   \____/ .___/ .___/\__, /  
                /_/   /_/    /____/   
EOF
    echo -e "${RESET}"
    echo -e "   ${CYAN}Release Manager v2.0${RESET}\n"
}

# Strict error handling
set -e

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Usage:${RESET} ./release_droppy.sh [VERSION] [NOTES_FILE]"
    exit 1
fi

VERSION="$1"
NOTES_FILE="$2"
DMG_NAME="Droppy-$VERSION.dmg"

header
info "Preparing Release: ${GREEN}v$VERSION${RESET}"

# Ensure git is clean
if [ -n "$(git status --porcelain)" ]; then
    error "Git working directory is not clean. Commit or stash first."
fi

# Check Repos
[ -d "$MAIN_REPO" ] || error "Main repo not found at $MAIN_REPO"
[ -d "$TAP_REPO" ] || error "Tap repo not found at $TAP_REPO"

# Update Release Notes
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
    info "Syncing Documentation"
    step "Reading $NOTES_FILE..."
    NOTES_CONTENT=$(cat "$NOTES_FILE")
    export NEW_NOTES="$NOTES_CONTENT"
    
    step "Updating README.md Changelog..."
    # Update README with perl to handle multiline
    perl -0777 -i -pe 's/(<!-- CHANGELOG_START -->)(.*?)(<!-- CHANGELOG_END -->)/$1\n$ENV{NEW_NOTES}\n$3/s' README.md
else
    warning "No valid notes file provided. Skipping doc updates."
fi

# Update Project Version
info "Bumping Version"
cd "$MAIN_REPO" || exit
sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION;/" Droppy.xcodeproj/project.pbxproj
step "Set MARKETING_VERSION = $VERSION"

# Build
info "Compiling Binary"
APP_BUILD_PATH="$MAIN_REPO/build"
rm -rf "$APP_BUILD_PATH"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Droppy -configuration Release -derivedDataPath "$APP_BUILD_PATH" -destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO -quiet || error "Build failed"
step "Build Successful"

# Build and Bundle Helper
info "Building DroppyUpdater Helper"
HELPER_SRC="$MAIN_REPO/DroppyUpdater/main.swift"
if [ -f "$HELPER_SRC" ]; then
    # Build for ARM64
    swiftc -o "$APP_BUILD_PATH/DroppyUpdater-arm64" \
        "$HELPER_SRC" \
        -framework AppKit \
        -framework SwiftUI \
        -O \
        -target arm64-apple-macos14.0 || error "Helper build (ARM64) failed"
    
    # Build for x86_64
    swiftc -o "$APP_BUILD_PATH/DroppyUpdater-x86_64" \
        "$HELPER_SRC" \
        -framework AppKit \
        -framework SwiftUI \
        -O \
        -target x86_64-apple-macos14.0 || error "Helper build (x86_64) failed"
    
    # Create universal binary
    lipo -create -output "$APP_BUILD_PATH/DroppyUpdater" \
        "$APP_BUILD_PATH/DroppyUpdater-arm64" \
        "$APP_BUILD_PATH/DroppyUpdater-x86_64"
    rm -f "$APP_BUILD_PATH/DroppyUpdater-arm64" "$APP_BUILD_PATH/DroppyUpdater-x86_64"
    
    # Copy helper to app bundle
    HELPERS_DIR="$APP_BUILD_PATH/Build/Products/Release/Droppy.app/Contents/Helpers"
    mkdir -p "$HELPERS_DIR"
    cp "$APP_BUILD_PATH/DroppyUpdater" "$HELPERS_DIR/"
    step "Universal helper bundled at Contents/Helpers/DroppyUpdater"
else
    warning "DroppyUpdater source not found, skipping helper"
fi

# Packaging
info "Packaging DMG"
cd "$MAIN_REPO" || exit
rm -f Droppy*.dmg

# Build DroppyInstaller
info "Building DroppyInstaller"
INSTALLER_SRC="$MAIN_REPO/DroppyInstaller/main.swift"
INSTALLER_APP="$APP_BUILD_PATH/DroppyInstaller.app"
if [ -f "$INSTALLER_SRC" ]; then
    # Build for ARM64
    swiftc -o "$APP_BUILD_PATH/DroppyInstaller-arm64" \
        "$INSTALLER_SRC" \
        -framework AppKit \
        -framework SwiftUI \
        -O \
        -target arm64-apple-macos14.0 || error "Installer build (ARM64) failed"
    
    # Build for x86_64
    swiftc -o "$APP_BUILD_PATH/DroppyInstaller-x86_64" \
        "$INSTALLER_SRC" \
        -framework AppKit \
        -framework SwiftUI \
        -O \
        -target x86_64-apple-macos14.0 || error "Installer build (x86_64) failed"
    
    # Create universal binary
    lipo -create -output "$APP_BUILD_PATH/DroppyInstaller" \
        "$APP_BUILD_PATH/DroppyInstaller-arm64" \
        "$APP_BUILD_PATH/DroppyInstaller-x86_64"
    rm -f "$APP_BUILD_PATH/DroppyInstaller-arm64" "$APP_BUILD_PATH/DroppyInstaller-x86_64"
    
    # Create proper .app bundle for installer
    mkdir -p "$INSTALLER_APP/Contents/MacOS"
    mkdir -p "$INSTALLER_APP/Contents/Resources"
    cp "$APP_BUILD_PATH/DroppyInstaller" "$INSTALLER_APP/Contents/MacOS/"
    
    # Copy Droppy's icon to installer
    cp "$APP_BUILD_PATH/Build/Products/Release/Droppy.app/Contents/Resources/AppIcon.icns" "$INSTALLER_APP/Contents/Resources/" 2>/dev/null || true
    
    # Create Info.plist
    cat > "$INSTALLER_APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DroppyInstaller</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.iordv.DroppyInstaller</string>
    <key>CFBundleName</key>
    <string>Install Droppy</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST
    step "DroppyInstaller.app built"
else
    warning "DroppyInstaller source not found"
fi

# Packaging DMG with both apps
info "Packaging DMG"
APP_PATH="$APP_BUILD_PATH/Build/Products/Release/Droppy.app"
DMG_BACKGROUND="$MAIN_REPO/assets/dmg/background.png"

# Create temp folder with both apps
mkdir -p dmg_root
cp -R "$APP_PATH" dmg_root/

if [ -d "$INSTALLER_APP" ]; then
    cp -R "$INSTALLER_APP" "dmg_root/Install Droppy.app"
    
    # Simple DMG with installer as focus
    if [ -f "$DMG_BACKGROUND" ]; then
        # Use create-dmg with installer focus
        if command -v create-dmg &> /dev/null && create-dmg \
            --volname "Droppy" \
            --background "$DMG_BACKGROUND" \
            --window-pos 200 120 \
            --window-size 660 480 \
            --icon-size 96 \
            --icon "Install Droppy.app" 330 200 \
            --hide-extension "Install Droppy.app" \
            --hide-extension "Droppy.app" \
            --icon "Droppy.app" 330 350 \
            --no-internet-enable \
            "$DMG_NAME" \
            "dmg_root" 2>/dev/null; then
            success "$DMG_NAME created (native installer)"
        else
            # Fallback
            warning "create-dmg failed, using fallback"
            rm -f "$DMG_NAME" rw.*.dmg 2>/dev/null
            hdiutil create -volname Droppy -srcfolder dmg_root -ov -format UDZO "$DMG_NAME" -quiet || error "DMG creation failed"
            success "$DMG_NAME created (basic)"
        fi
    else
        hdiutil create -volname Droppy -srcfolder dmg_root -ov -format UDZO "$DMG_NAME" -quiet || error "DMG creation failed"
        success "$DMG_NAME created (basic)"
    fi
else
    # Fallback to old style without installer
    ln -s /Applications dmg_root/Applications
    hdiutil create -volname Droppy -srcfolder dmg_root -ov -format UDZO "$DMG_NAME" -quiet || error "DMG creation failed"
    success "$DMG_NAME created (drag-to-apps)"
fi
rm -rf dmg_root

# Checksum
info "Generating Integrity Checksum"
HASH=$(shasum -a 256 "$DMG_NAME" | awk '{print $1}')
step "SHA256: ${DIM}$HASH${RESET}"

# Generate Cask
CASK_CONTENT="cask \"droppy\" do
  version \"$VERSION\"
  sha256 \"$HASH\"

  url \"https://github.com/iordv/Droppy/releases/download/v$VERSION/$DMG_NAME\"
  name \"Droppy\"
  desc \"Drag and drop file shelf for macOS\"
  homepage \"https://github.com/iordv/Droppy\"

  app \"Droppy.app\"

  postflight do
    system_command \"/usr/bin/xattr\",
      args: [\"-rd\", \"com.apple.quarantine\", \"#{appdir}/Droppy.app\"],
      sudo: false
  end

  caveats <<~EOS
    ____                             
   / __ \\_________  ____  ____  __  __
  / / / / ___/ __ \\/ __ \\/ __ \\/ / / /
 / /_/ / /  / /_/ / /_/ / /_/ / /_/ / 
/_____/_/   \\____/ .___/ .___/\\__, /  
                /_/   /_/    /____/   

    Thank you for installing Droppy! 
    The ultimate drag-and-drop file shelf for macOS.
  EOS

  zap trash: [
    \"~/Library/Application Support/Droppy\",
    \"~/Library/Preferences/iordv.Droppy.plist\",
  ]
end"

# Update Casks
info "Updating Homebrew Casks"
echo "$CASK_CONTENT" > "$MAIN_REPO/Casks/droppy.rb"
echo "$CASK_CONTENT" > "$TAP_REPO/Casks/droppy.rb"
step "Cask files written"

# Commit Changes
info "Finalizing Git Repositories"

# Confirm
if [ "$3" == "-y" ] || [ "$3" == "--yes" ]; then
    REPLY="y"
else
    echo -e "\n${BOLD}Review Pending Changes:${RESET}"
    echo -e "   • Version: ${GREEN}$VERSION${RESET}"
    echo -e "   • Binary:  ${CYAN}$DMG_NAME${RESET}"
    echo -e "   • Hash:    ${DIM}${HASH:0:8}...${RESET}"
    read -p "❓ Publish release now? [y/N] " -n 1 -r
    echo
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Main Repo Commit
    cd "$MAIN_REPO"
    step "Pushing Main Repo..."
    git pull origin main --quiet
    git rm --ignore-unmatch Droppy*.dmg --quiet
    git add "$DMG_NAME"
    git add .
    git commit -m "Release v$VERSION" --quiet
    git tag "v$VERSION"
    git push origin main --quiet
    git push origin "v$VERSION" --quiet
    
    # Tap Repo Commit
    cd "$TAP_REPO"
    step "Pushing Tap Repo..."
    git fetch origin --quiet
    git reset --hard origin/main --quiet
    echo "$CASK_CONTENT" > "Casks/droppy.rb" # Rewrite after reset
    git add .
    git commit -m "Update Droppy to v$VERSION" --quiet
    git push --force origin HEAD:main --quiet

    # GitHub Release
    info "Creating GitHub Release"
    cd "$MAIN_REPO"
    gh release create "v$VERSION" "$DMG_NAME" --title "v$VERSION" --notes-file "$NOTES_FILE"
    
    echo -e "\n${GREEN}✨ RELEASE COMPLETE! ✨${RESET}"
    echo -e "Users can now update with: ${CMD}brew upgrade droppy${RESET}\n"
else
    warning "Release cancelled. Changes pending locally."
fi
