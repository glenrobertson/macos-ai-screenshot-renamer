#!/bin/bash

set -e

SCREENSHOTS_DIR="$HOME/Screenshots"
SHORTCUT_NAME="Rename Screenshot.shortcut"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

WATCHER_SCRIPT="$HOME/Library/Scripts/rename-new-screenshots.sh"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/nz.glen.screenshot-renamer.plist"
LAUNCH_AGENT_LABEL="nz.glen.screenshot-renamer"

echo "Screenshot Renamer Setup"
echo "========================"
echo

# 1. Create Screenshots directory
echo "Creating $SCREENSHOTS_DIR..."
mkdir -p "$SCREENSHOTS_DIR"

# 2. Set macOS to save screenshots there
echo "Setting macOS screenshot location..."
defaults write com.apple.screencapture location "$SCREENSHOTS_DIR"
killall SystemUIServer 2>/dev/null || true

# 3. Install the Shortcut
SHORTCUT_PATH="$SCRIPT_DIR/$SHORTCUT_NAME"
if [ -f "$SHORTCUT_PATH" ]; then
    echo "Installing Shortcut (click 'Add Shortcut' when prompted)..."
    open "$SHORTCUT_PATH"
    echo "Waiting for Shortcut to be added..."
    sleep 3
else
    echo "WARNING: $SHORTCUT_NAME not found. Please install manually."
fi

# 4. Install the watcher script
echo "Installing watcher script..."
mkdir -p "$HOME/Library/Scripts"
cat > "$WATCHER_SCRIPT" <<'WATCHER'
#!/bin/zsh
# Called by launchd WatchPaths whenever ~/Screenshots changes.
# Finds screenshots that still have the default macOS name and renames them
# via the "Rename Screenshot" Shortcut.

SCREENSHOTS_DIR="$HOME/Screenshots"
TIMESTAMP_FILE="$HOME/Library/Scripts/.rename-screenshot-lastrun"

if [[ ! -f "$TIMESTAMP_FILE" ]]; then
    touch -t 197001010000 "$TIMESTAMP_FILE"
fi

# Small sleep to let the screenshot finish writing to disk
sleep 2

find "$SCREENSHOTS_DIR" -maxdepth 1 -name "Screenshot *.png" -newer "$TIMESTAMP_FILE" | while IFS= read -r file; do
    shortcuts run "Rename Screenshot" --input-path "$file"
done

touch "$TIMESTAMP_FILE"
WATCHER
chmod +x "$WATCHER_SCRIPT"

# 5. Install and load the Launch Agent
echo "Installing Launch Agent..."
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$LAUNCH_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LAUNCH_AGENT_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>$WATCHER_SCRIPT</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>$SCREENSHOTS_DIR</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/rename-screenshot.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/rename-screenshot.log</string>
</dict>
</plist>
PLIST

# Unload first if already running
launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
launchctl load "$LAUNCH_AGENT_PLIST"

echo
echo "Done! Screenshot location set to: $SCREENSHOTS_DIR"
echo
echo "Take a screenshot (Cmd+Shift+4) to test it!"
echo "Logs: $HOME/Library/Logs/rename-screenshot.log"
