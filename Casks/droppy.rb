cask "droppy" do
  version "6.1.9"
  sha256 "121df677b79d99268fedbe9adc1bfb97d137476aca3b726ded77b9f72a5b553c"

  url "https://github.com/iordv/Droppy/releases/download/v6.1.9/Droppy-6.1.9.zip"
  name "Droppy"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/iordv/Droppy"

  # The ZIP contains an installer app - Homebrew extracts and uses .payload/Droppy.app
  app ".payload/Droppy.app"

  postflight do
    system_command "/usr/bin/xattr",
      args: ["-rd", "com.apple.quarantine", "#{appdir}/Droppy.app"],
      sudo: false
  end

  caveats <<~EOS
    ____                             
   / __ \_________  ____  ____  __  __
  / / / / ___/ __ \/ __ \/ __ \/ / / /
 / /_/ / /  / /_/ / /_/ / /_/ / /_/ / 
/_____/_/   \____/ .___/ .___/\__, /  
                /_/   /_/    /____/   

    Thank you for installing Droppy! 
    The ultimate drag-and-drop file shelf for macOS.
  EOS

  zap trash: [
    "~/Library/Application Support/Droppy",
    "~/Library/Preferences/iordv.Droppy.plist",
  ]
end
