#!/bin/bash

# Configuration
MAIN_REPO="/Users/jordyspruit/Desktop/Droppy"
TAP_REPO="/Users/jordyspruit/Desktop/homebrew-tap"
DMG_NAME="Droppy.dmg"

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: ./release_droppy.sh [VERSION_NUMBER] [PATH_TO_RELEASE_NOTES]"
    echo "Example: ./release_droppy.sh 1.2 ./notes.txt"
    exit 1
fi

VERSION="$1"
NOTES_FILE="$2"

# Banner
echo "========================================"
echo "🚀 Preparing Droppy Release v$VERSION"
echo "========================================"

# Update Changelogs if notes provided
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
    echo "\n-> Updating Changelogs with notes from $NOTES_FILE..."
    
    # Read notes content
    NOTES_CONTENT=$(cat "$NOTES_FILE")
    
    # Escape special characters for sed usage
    # We replace newlines with literal '\n' for specific formats if needed, 
    # but for simple replacement we might do differently. 
    # Since multiline sed is tricky, we'll use perl which handles this better on macOS.
    
    # 1. Update SettingsView.swift
    echo "   - Updating SettingsView.swift..."
    # We look for `static let current = """` ... `"""` block
    # Note: We need to escape quote marks in the content string for Swift
    export SWIFT_CONTENT=$(echo "$NOTES_CONTENT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    cd "$MAIN_REPO" || exit
    perl -0777 -i -pe 's/static let current = \"\"\"(.*?)\"\"\"/static let current = \"\"\"\n$ENV{SWIFT_CONTENT}\n\"\"\"/s' Droppy/SettingsView.swift

    # 2. Update README.md
    echo "   - Updating README.md..."
    # We look for <!-- CHANGELOG_START --> ... <!-- CHANGELOG_END -->
    # For README, we want raw markdown, so we use NOTES_CONTENT directly but need to escape for Perl regex replacement string if it has special vars
    # A safer way with Perl is passing content as env var
    export NEW_NOTES="$NOTES_CONTENT"
    perl -0777 -i -pe 's/(<!-- CHANGELOG_START -->)(.*?)(<!-- CHANGELOG_END -->)/$1\n$ENV{NEW_NOTES}\n$3/s' README.md

else
    if [ -n "$NOTES_FILE" ]; then
        echo "⚠️ Warning: Notes file '$NOTES_FILE' not found. Skipping changelog updates."
    else
        echo "ℹ️ No release notes file provided. Skipping changelog updates."
    fi
fi

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
# Update version using sed directly on project file (agvtool is unreliable with generated Info.plist)
echo "\n-> Updating version to $VERSION in project file..."
cd "$MAIN_REPO" || exit
sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION;/" Droppy.xcodeproj/project.pbxproj

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
