cask "droppy" do
  version "2.0.2"
  sha256 "85d3348476c08fdd9a98ee250bc19e682710c54b074226b1db01476d4720d726"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy-2.0.2.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
