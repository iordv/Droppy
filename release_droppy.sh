#!/bin/bash

# Configuration
MAIN_REPO="/Users/jordyspruit/Desktop/Droppy"
TAP_REPO="/Users/jordyspruit/Desktop/homebrew-tap"
DMG_NAME="Droppy.dmg"

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: ./release_droppy.sh [VERSION_NUMBER]"
    echo "Example: ./release_droppy.sh 1.2"
    exit 1
fi

VERSION="$1"

# Banner
echo "========================================"
echo "🚀 Preparing Droppy Release v$VERSION"
echo "========================================"

# Check Repos
if [ ! -d "$MAIN_REPO" ]; then
    echo "❌ Error: Main repo not found at $MAIN_REPO"
    exit 1
fi
if [ ! -d "$TAP_REPO" ]; then
    echo "❌ Error: Tap repo not found at $TAP_REPO"
    exit 1
fi

# 1. Update Workspace Version
echo "\n-> Use agvtool to update version to $VERSION..."
cd "$MAIN_REPO" || exit
if [ -d "Droppy.xcodeproj" ]; then
    xcrun agvtool new-marketing-version "$VERSION" > /dev/null
else
    echo "❌ Error: No Xcode project found in $MAIN_REPO"
    exit 1
fi

# 2. Build Release Configuration
echo "-> Building App (Release)..."
APP_BUILD_PATH="$MAIN_REPO/build"
rm -rf "$APP_BUILD_PATH"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Droppy -configuration Release -derivedDataPath "$APP_BUILD_PATH" -quiet
if [ $? -ne 0 ]; then
    echo "❌ Error: Build failed."
    exit 1
fi

# 3. Create DMG
echo "-> Creating $DMG_NAME..."
cd "$MAIN_REPO" || exit
rm -f "$DMG_NAME"
mkdir -p dmg_root
cp -R "$APP_BUILD_PATH/Build/Products/Release/Droppy.app" dmg_root/
ln -s /Applications dmg_root/Applications
hdiutil create -volname Droppy -srcfolder dmg_root -ov -format UDZO "$DMG_NAME" -quiet
rm -rf dmg_root build
if [ ! -f "$DMG_NAME" ]; then
    echo "❌ Error: DMG creation failed."
    exit 1
fi

# 4. Calculate Hash
HASH=$(shasum -a 256 "$DMG_NAME" | awk '{print $1}')
echo "   SHA256: $HASH"

# 5. Generate Cask Content
CASK_CONTENT="cask \"droppy\" do
  version \"$VERSION\"
  sha256 \"$HASH\"

  url \"https://raw.githubusercontent.com/iordv/Droppy/main/Droppy.dmg\"
  name \"Droppy\"
  desc \"Drag and drop file shelf for macOS\"
  homepage \"https://github.com/iordv/Droppy\"

  app \"Droppy.app\"

  zap trash: [
    \"~/Library/Application Support/Droppy\",
    \"~/Library/Preferences/iordv.Droppy.plist\",
  ]
end"

# 6. Update Casks
echo "-> Updating Cask files..."
echo "$CASK_CONTENT" > "$MAIN_REPO/Casks/droppy.rb"
echo "$CASK_CONTENT" > "$TAP_REPO/Casks/droppy.rb"

# 7. Commit Repos
echo "-> Committing changes..."

# Main Repo
cd "$MAIN_REPO" || exit
git add .
git commit -m "Release v$VERSION"
git tag "v$VERSION"

# Tap Repo
cd "$TAP_REPO" || exit
git add .
git commit -m "Update Droppy to v$VERSION"

# 8. Confirmation
echo "\n========================================"
echo "✅ Release v$VERSION prepared successfully!"
echo "   - App built & DMG created"
echo "   - Cask updated in Main Repo and Tap Repo"
echo "   - Changes committed locally"
echo "========================================"
read -p "❓ Do you want to PUSH changes to GitHub now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "\n-> Pushing Main Repo..."
    cd "$MAIN_REPO" || exit
    git push origin main
    git push origin "v$VERSION"

    echo "-> Pushing Tap Repo..."
    cd "$TAP_REPO" || exit
    git push origin main

    echo "\n🎉 DONE! Release is live."
    echo "Users can run 'brew upgrade droppy' to get the new version."
else
    echo "\n🛑 Push cancelled. Changes are committed locally."
fi
