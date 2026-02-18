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
    clear || true
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
NOTES_FILE="${2:-}"
AUTO_APPROVE_FLAG="${3:-}"
DMG_NAME="Droppy-$VERSION.dmg"

header
info "Preparing Release: ${GREEN}v$VERSION${RESET}"

# Check Repos
[ -d "$MAIN_REPO" ] || error "Main repo not found at $MAIN_REPO"
[ -d "$TAP_REPO" ] || error "Tap repo not found at $TAP_REPO"
cd "$MAIN_REPO" || error "Cannot enter main repo at $MAIN_REPO"

# Validate version format early (X.Y or X.Y.Z)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    error "Version must follow semantic format X.Y or X.Y.Z (received: $VERSION)"
fi

# Ensure git is clean
if [ -n "$(git status --porcelain)" ]; then
    error "Git working directory is not clean. Commit or stash first."
fi
if [ -n "$(git -C "$TAP_REPO" status --porcelain)" ]; then
    error "Homebrew tap working directory is not clean. Commit or stash first."
fi

# Update Release Notes
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
    info "Syncing Documentation"
    step "Reading $NOTES_FILE..."
    NOTES_CONTENT=$(cat "$NOTES_FILE")
    export NEW_NOTES="$NOTES_CONTENT"
    
    step "Updating README.md Changelog..."
    # Update README with perl to handle multiline
    perl -0777 -i -pe 's/(<!-- CHANGELOG_START -->)(.*?)(<!-- CHANGELOG_END -->)/$1\n$ENV{NEW_NOTES}\n$3/s' README.md
    
    step "Updating Website Version to $VERSION..."
    # Update DROPPY_VERSION in docs/index.html and docs/extensions.html
    sed -i '' "s/const DROPPY_VERSION = '[^']*';/const DROPPY_VERSION = '$VERSION';/" docs/index.html
    sed -i '' "s/const DROPPY_VERSION = '[^']*';/const DROPPY_VERSION = '$VERSION';/" docs/extensions.html
    
    # Update centralized version.js
    sed -i '' "s/version: '[^']*'/version: '$VERSION'/" docs/assets/js/version.js
    sed -E -i '' "s/Droppy-[0-9]+\.[0-9]+(\.[0-9]+)?\.dmg/Droppy-$VERSION.dmg/g" docs/assets/js/version.js
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
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Droppy -configuration Release -derivedDataPath "$APP_BUILD_PATH" -destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY="Developer ID Application: Jordy Spruit (NARHG44L48)" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=NARHG44L48 -quiet || error "Build failed"
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

# Code Signing
info "Signing Application"
APP_PATH="$APP_BUILD_PATH/Build/Products/Release/Droppy.app"
SOURCE_INFO_PLIST="$MAIN_REPO/Droppy/Info.plist"
APP_INFO_PLIST="$APP_PATH/Contents/Info.plist"
RESOURCE_INFO_PLIST="$APP_PATH/Contents/Resources/Info.plist"
SIGNING_IDENTITY="Developer ID Application: Jordy Spruit"

# Ensure release bundle includes all privacy and license metadata from source Info.plist.
info "Syncing App Metadata"
METADATA_KEYS=(
    NSAppleEventsUsageDescription
    NSBluetoothAlwaysUsageDescription
    NSCameraUsageDescription
    NSMicrophoneUsageDescription
    NSRemindersUsageDescription
    NSRemindersFullAccessUsageDescription
    NSCalendarsUsageDescription
    NSCalendarsFullAccessUsageDescription
    GumroadProductID
    GumroadProductPermalink
    GumroadPurchaseURL
)

[ -f "$SOURCE_INFO_PLIST" ] || error "Source Info.plist missing at $SOURCE_INFO_PLIST"
[ -f "$APP_INFO_PLIST" ] || error "Built app Info.plist missing at $APP_INFO_PLIST"

read_plist_value() {
    local plist_path="$1"
    local key="$2"
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null || true
}

sync_metadata_keys() {
    local target_plist="$1"
    local key source_value
    [ -f "$target_plist" ] || return 0

    for key in "${METADATA_KEYS[@]}"; do
        source_value="$(read_plist_value "$SOURCE_INFO_PLIST" "$key")"
        if [ -n "$source_value" ]; then
            plutil -replace "$key" -string "$source_value" "$target_plist"
        fi
    done
}

validate_required_app_keys() {
    local target_plist="$1"
    local key product_id product_permalink

    for key in NSRemindersUsageDescription NSCalendarsUsageDescription GumroadPurchaseURL; do
        /usr/libexec/PlistBuddy -c "Print :$key" "$target_plist" >/dev/null 2>&1 || error "Missing required key $key in $target_plist"
    done

    product_id="$(read_plist_value "$target_plist" "GumroadProductID")"
    product_permalink="$(read_plist_value "$target_plist" "GumroadProductPermalink")"
    if [ -z "$product_id" ] && [ -z "$product_permalink" ]; then
        error "Missing Gumroad product configuration in $target_plist (need GumroadProductID or GumroadProductPermalink)"
    fi
}

validate_dmg_bundle_metadata() {
    local dmg_path="$1"
    local mount_dir dmg_app_info dmg_purchase_url

    mount_dir="$(mktemp -d /tmp/droppy-dmg-XXXX)"
    if ! hdiutil attach -nobrowse -readonly -mountpoint "$mount_dir" "$dmg_path" >/dev/null; then
        rmdir "$mount_dir" 2>/dev/null || true
        error "Failed to mount $dmg_path for metadata verification"
    fi

    dmg_app_info="$mount_dir/Droppy.app/Contents/Info.plist"
    if [ ! -f "$dmg_app_info" ]; then
        hdiutil detach "$mount_dir" >/dev/null 2>&1 || true
        rmdir "$mount_dir" 2>/dev/null || true
        error "Droppy.app Info.plist missing inside $dmg_path"
    fi

    validate_required_app_keys "$dmg_app_info"

    dmg_purchase_url="$(read_plist_value "$dmg_app_info" "GumroadPurchaseURL")"
    if [ -n "$GUMROAD_PURCHASE_URL" ] && [ "$dmg_purchase_url" != "$GUMROAD_PURCHASE_URL" ]; then
        hdiutil detach "$mount_dir" >/dev/null 2>&1 || true
        rmdir "$mount_dir" 2>/dev/null || true
        error "DMG purchase URL mismatch. Expected $GUMROAD_PURCHASE_URL but found $dmg_purchase_url"
    fi

    hdiutil detach "$mount_dir" >/dev/null 2>&1 || error "Failed to detach DMG mount after verification"
    rmdir "$mount_dir" 2>/dev/null || true
}

sync_metadata_keys "$APP_INFO_PLIST"
sync_metadata_keys "$RESOURCE_INFO_PLIST"
validate_required_app_keys "$APP_INFO_PLIST"
GUMROAD_PURCHASE_URL="$(read_plist_value "$APP_INFO_PLIST" "GumroadPurchaseURL")"
step "App metadata synced and validated"

# Sign all nested components first (helpers, frameworks)
find "$APP_PATH/Contents" -name "*.dylib" -o -name "*.framework" | while read -r item; do
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$item" 2>/dev/null || true
done

# Sign helper if exists
if [ -f "$APP_PATH/Contents/Helpers/DroppyUpdater" ]; then
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$APP_PATH/Contents/Helpers/DroppyUpdater"
    step "Signed DroppyUpdater helper"
fi

# Sign the main app
codesign --force --options runtime --sign "$SIGNING_IDENTITY" --entitlements "$MAIN_REPO/Droppy/Droppy.entitlements" "$APP_PATH" || error "Code signing failed"
step "Signed Droppy.app with Developer ID"

# Verify signature
codesign --verify --deep --strict "$APP_PATH" || error "Signature verification failed"
step "Signature verified"

# Packaging DMG (classic drag-to-Applications)
info "Packaging DMG"
DMG_NAME="Droppy-$VERSION.dmg"
rm -f Droppy*.zip Droppy*.dmg rw.*.dmg

# Create DMG using Sindre's create-dmg (clean, respects user's appearance)
npx create-dmg "$APP_PATH" . --overwrite 2>/dev/null || error "DMG creation failed"

# Rename to our versioned name
mv "Droppy $VERSION.dmg" "$DMG_NAME" 2>/dev/null || mv Droppy*.dmg "$DMG_NAME" 2>/dev/null

# Validate final packaged app metadata before signing/publishing.
validate_dmg_bundle_metadata "$DMG_NAME"
step "DMG metadata validated"

# Sign the DMG too
codesign --force --sign "$SIGNING_IDENTITY" "$DMG_NAME" || error "DMG signing failed"
step "Signed DMG"

# Notarization
info "Notarizing with Apple"
step "Submitting to Apple notary service..."

# Submit for notarization (uses stored credentials "Droppy-Notarize")
if ! xcrun notarytool submit "$DMG_NAME" --keychain-profile "Droppy-Notarize" --wait; then
    error "Notarization failed. Configure credentials with 'xcrun notarytool store-credentials Droppy-Notarize'."
fi

# Staple the notarization ticket to the DMG
if ! xcrun stapler staple "$DMG_NAME" 2>/dev/null; then
    error "Stapling failed. Refusing to publish unstapled DMG."
fi
step "Notarization ticket stapled"

success "$DMG_NAME created and notarized"

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

  auto_updates true

  app \"Droppy.app\"

  postflight do
    system_command \"/usr/bin/xattr\",
      args: [\"-d\", \"com.apple.quarantine\", \"#{appdir}/Droppy.app\"],
      must_succeed: false,
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

# Verify both casks have correct version URL
if ! grep -q "v$VERSION/$DMG_NAME" "$MAIN_REPO/Casks/droppy.rb"; then
    error "Main repo cask verification failed"
fi
if ! grep -q "v$VERSION/$DMG_NAME" "$TAP_REPO/Casks/droppy.rb"; then
    error "Tap repo cask verification failed"
fi
step "Cask files written and verified for v$VERSION"

# Commit Changes
info "Finalizing Git Repositories"

# Confirm
if [ "$AUTO_APPROVE_FLAG" == "-y" ] || [ "$AUTO_APPROVE_FLAG" == "--yes" ]; then
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
    git pull --ff-only origin main --quiet
    git rm --ignore-unmatch Droppy*.dmg Droppy*.zip --quiet 2>/dev/null || true
    git add "$DMG_NAME"
    git add .
    git commit -m "Release v$VERSION" --quiet
    git push origin main --quiet
    if git ls-remote --tags origin "refs/tags/v$VERSION" | grep -q .; then
        warning "Tag v$VERSION already exists on origin. Skipping tag create/push."
    else
        git tag "v$VERSION"
        git push origin "v$VERSION" --quiet
    fi
    
    # Tap Repo Commit
    cd "$TAP_REPO"
    step "Pushing Tap Repo..."
    git fetch origin --quiet
    git checkout main --quiet
    git pull --ff-only origin main --quiet
    echo "$CASK_CONTENT" > "Casks/droppy.rb"
    
    # Verify cask contains correct version in URL (guard against variable corruption)
    if ! grep -q "v$VERSION/$DMG_NAME" "Casks/droppy.rb"; then
        error "Cask verification failed: URL does not contain v$VERSION/$DMG_NAME"
    fi
    step "Cask verified: URL points to v$VERSION"
    
    git add .
    git commit -m "Update Droppy to v$VERSION" --quiet || warning "No changes to commit in tap repo"
    git push origin HEAD:main --quiet

    # GitHub Release
    info "Creating GitHub Release"
    cd "$MAIN_REPO"
    
    # Append installation instructions to notes
    TEMP_NOTES=$(mktemp)
    if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
        cat "$NOTES_FILE" > "$TEMP_NOTES"
    else
        cat > "$TEMP_NOTES" << FALLBACK_NOTES
## What's New
- Release v$VERSION
FALLBACK_NOTES
    fi
    cat >> "$TEMP_NOTES" << INSTALL_FOOTER

---

## Installation

<img src="https://raw.githubusercontent.com/iordv/Droppy/main/docs/assets/macos-disk-icon.png" height="24"> **Recommended: Direct Download** (signed & notarized)

Download \`Droppy-$VERSION.dmg\` below, open it, and drag Droppy to Applications. That's it!

> ✅ **Signed & Notarized by Apple** — No quarantine warnings, no terminal commands needed.

<img src="https://brew.sh/assets/img/homebrew.svg" height="24"> **Alternative: Install via Homebrew**
\`\`\`bash
brew install --cask iordv/tap/droppy
\`\`\`

## License

Buy a license on Gumroad: $GUMROAD_PURCHASE_URL  
Already purchased? Open Droppy and click **Activate License**.
INSTALL_FOOTER
    
    gh release create "v$VERSION" "$DMG_NAME" --title "v$VERSION" --notes-file "$TEMP_NOTES"
    rm -f "$TEMP_NOTES"
    
    echo -e "\n${GREEN}✨ RELEASE COMPLETE! ✨${RESET}"
    echo -e "Users can now update with: ${CYAN}brew upgrade --cask droppy${RESET}\n"
else
    warning "Release cancelled. Changes pending locally."
fi
