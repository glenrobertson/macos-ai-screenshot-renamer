# macOS AI Screenshot Renamer

Use Apple Intelligence to automatically rename screenshots with descriptive filenames via a launchd agent and Shortcuts.

![Demo](demo.gif)

## How It Works

1. **launchd Launch Agent** watches your chosen screenshots folder for new files
2. **Shortcut** sends the image to Apple Intelligence for analysis
3. Screenshot is renamed with an AI-generated description

Only files whose names start with `Screenshot ` (the default macOS filename) are
renamed, so you can safely point the watcher at a shared folder like `~/Desktop`
without touching unrelated files.

## Requirements

- macOS 15.1+ (Sequoia) with Apple Intelligence enabled
- Apple Silicon Mac (M1 or later)

## Installation

### Option 1: Homebrew

```bash
brew install --cask https://raw.githubusercontent.com/glenrobertson/macos-ai-screenshot-renamer/main/Casks/screenshot-renamer.rb
```

You'll be prompted to pick a folder for screenshots (defaults to `~/Screenshots`). Then click **"Add Shortcut"** when prompted, and grant any permissions in **System Settings > Privacy & Security**. Uninstall with `brew uninstall --cask screenshot-renamer`.

### Option 2: Installer Package

Download `Screenshot-Renamer.pkg` from the [latest release](https://github.com/glenrobertson/macos-ai-screenshot-renamer/releases) and double-click to install.

You'll be prompted to pick a folder for screenshots (defaults to `~/Screenshots`). Then click **"Add Shortcut"** when prompted, and grant any permissions in **System Settings > Privacy & Security**.

### Option 3: Command Line

```bash
git clone https://github.com/glenrobertson/macos-ai-screenshot-renamer.git
cd macos-ai-screenshot-renamer
./install.sh
```

The installer will ask where to save screenshots (defaults to `~/Screenshots`; set `SCREENSHOTS_DIR=...` in the environment to skip the prompt). Then click **"Add Shortcut"** when prompted, and grant any permissions in **System Settings > Privacy & Security**.

## What Setup Does

- Asks for a screenshots folder (default `~/Screenshots`) and creates it
- Sets macOS to save screenshots there (`defaults write com.apple.screencapture location`)
- Imports the Shortcut
- Installs a watcher script at `~/Library/Scripts/rename-new-screenshots.sh`
- Installs and loads a Launch Agent at `~/Library/LaunchAgents/nz.glen.screenshot-renamer.plist`

Run `./uninstall.sh` to reverse these changes.

## Test It

Take a screenshot with `Cmd + Shift + 4` and watch it rename automatically.

Logs are written to `~/Library/Logs/rename-screenshot.log`.

## Manual Installation

1. Set screenshot location:
   ```bash
   defaults write com.apple.screencapture location ~/Screenshots
   killall SystemUIServer
   ```

2. Double-click `Rename Screenshot.shortcut` to import

3. Create the watcher script at `~/Library/Scripts/rename-new-screenshots.sh`:
   ```bash
   mkdir -p ~/Library/Scripts
   cat > ~/Library/Scripts/rename-new-screenshots.sh <<'EOF'
   #!/bin/zsh
   SCREENSHOTS_DIR="$HOME/Screenshots"
   TIMESTAMP_FILE="$HOME/Library/Scripts/.rename-screenshot-lastrun"
   if [[ ! -f "$TIMESTAMP_FILE" ]]; then
       touch -t 197001010000 "$TIMESTAMP_FILE"
   fi
   sleep 2
   find "$SCREENSHOTS_DIR" -maxdepth 1 -name "Screenshot *.png" -newer "$TIMESTAMP_FILE" | while IFS= read -r file; do
       shortcuts run "Rename Screenshot" --input-path "$file"
   done
   touch "$TIMESTAMP_FILE"
   EOF
   chmod +x ~/Library/Scripts/rename-new-screenshots.sh
   ```

4. Create and load the Launch Agent:
   ```bash
   mkdir -p ~/Library/LaunchAgents
   cat > ~/Library/LaunchAgents/nz.glen.screenshot-renamer.plist <<EOF
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>Label</key>
       <string>nz.glen.screenshot-renamer</string>
       <key>ProgramArguments</key>
       <array>
           <string>/bin/zsh</string>
           <string>$HOME/Library/Scripts/rename-new-screenshots.sh</string>
       </array>
       <key>WatchPaths</key>
       <array>
           <string>$HOME/Screenshots</string>
       </array>
       <key>RunAtLoad</key>
       <false/>
       <key>StandardOutPath</key>
       <string>$HOME/Library/Logs/rename-screenshot.log</string>
       <key>StandardErrorPath</key>
       <string>$HOME/Library/Logs/rename-screenshot.log</string>
   </dict>
   </plist>
   EOF
   launchctl load ~/Library/LaunchAgents/nz.glen.screenshot-renamer.plist
   ```

## Uninstall

If you installed via Homebrew: `brew uninstall --cask screenshot-renamer`.

If you installed via the `.pkg`, double-click `Uninstall-Screenshot-Renamer.pkg` from the [latest release](https://github.com/glenrobertson/macos-ai-screenshot-renamer/releases). Otherwise:

```bash
./uninstall.sh
```

This will unload and remove the Launch Agent, remove the watcher script, and reset the screenshot save location back to Desktop.

Your screenshots folder and the "Rename Screenshot" Shortcut are left in place — delete them manually if you no longer need them.

## License

MIT
