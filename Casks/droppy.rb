cask "droppy" do
  version "2.0.1"
  sha256 "59ff10d905fb1bcdcc0172e1f8d9d948b231f534e467782e8e027aa1d8727aa9"

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
