cask "droppy" do
  version "1.0"
  sha256 "b189900bf39f24b5ca259fb9fdd0260fa14972b42584224e0e0e6936e422079a"

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
