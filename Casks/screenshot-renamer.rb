cask "screenshot-renamer" do
  version "1.0"
  sha256 "REPLACE_WITH_SHA256_FROM_build-pkg.sh"

  # GitHub replaces spaces in asset filenames with dots in the download URL.
  url "https://github.com/glenrobertson/macos-ai-screenshot-renamer/releases/download/v#{version}/Screenshot.Renamer.pkg"
  name "Screenshot Renamer"
  desc "Auto-rename screenshots with Apple Intelligence"
  homepage "https://github.com/glenrobertson/macos-ai-screenshot-renamer"

  depends_on macos: ">= :sequoia"
  depends_on arch: :arm64

  pkg "Screenshot Renamer.pkg"

  # uninstall.sh is left on disk by the install pkg's postinstall so the cask
  # can reuse the same teardown (unload launchd agent, remove plist + watcher
  # script, reset com.apple.screencapture location). Run with sudo so it can
  # delete the staging dir under /usr/local/share and use launchctl asuser.
  uninstall early_script: {
              executable: "/usr/local/share/screenshot-renamer/uninstall.sh",
              sudo:       true,
            },
            launchctl:    "nz.glen.screenshot-renamer",
            pkgutil:      "nz.glen.screenshot-renamer"

  zap trash: [
    "~/Library/Logs/rename-screenshot.log",
  ]

  caveats <<~EOS
    During installation you'll be prompted to pick a folder for screenshots
    (defaults to ~/Screenshots), then asked to click "Add Shortcut" to import
    the Apple Intelligence Shortcut. You may need to grant Automation/Files
    permissions in System Settings > Privacy & Security.
  EOS
end
