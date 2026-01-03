cask "droppy" do
  version "2.0.2"
  sha256 "746e156c62ecbdee254b6a5fdb491d5e9417e467b5b9b29c60bf17d8e68d96a1"

  url "https://raw.githubusercontent.com/iordv/Droppy/main/Droppy.dmg"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  app "Droppy.app"

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
