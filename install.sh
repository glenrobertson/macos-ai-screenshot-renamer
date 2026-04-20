#!/bin/bash
# Install Screenshot Renamer.
# Works both as a normal user (CLI install) and as root (pkg postinstall).
# Usage: install.sh [shortcut_path]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect context: running as root (pkg postinstall) vs normal user
if [ "$(id -u)" -eq 0 ]; then
    CURRENT_USER=$( /usr/bin/stat -f "%Su" /dev/console )
    USER_HOME=$( /usr/bin/dscl . -read /Users/"$CURRENT_USER" NFSHomeDirectory | /usr/bin/awk '{print $NF}' )
    CURRENT_USER_UID=$( /usr/bin/id -u "$CURRENT_USER" )
    AS_USER=(/usr/bin/sudo -u "$CURRENT_USER")
    LAUNCHCTL_CMD=(/bin/launchctl asuser "$CURRENT_USER_UID" /bin/launchctl)
    CHOWN="$CURRENT_USER"
else
    USER_HOME="$HOME"
    AS_USER=()
    LAUNCHCTL_CMD=(launchctl)
    CHOWN=""
fi

SHORTCUT_PATH="${1:-$SCRIPT_DIR/Rename Screenshot.shortcut}"
SCREENSHOTS_DIR="$USER_HOME/Screenshots"
WATCHER_SCRIPT="$USER_HOME/Library/Scripts/rename-new-screenshots.sh"
LAUNCH_AGENT_PLIST="$USER_HOME/Library/LaunchAgents/nz.glen.screenshot-renamer.plist"
LAUNCH_AGENT_LABEL="nz.glen.screenshot-renamer"

echo "Screenshot Renamer Setup"
echo "========================"
echo

# 1. Create Screenshots directory
echo "Creating $SCREENSHOTS_DIR..."
mkdir -p "$SCREENSHOTS_DIR"
[ -n "$CHOWN" ] && chown "$CHOWN" "$SCREENSHOTS_DIR"

# 2. Set macOS to save screenshots there
echo "Setting macOS screenshot location..."
"${AS_USER[@]}" defaults write com.apple.screencapture location "$SCREENSHOTS_DIR"
killall SystemUIServer 2>/dev/null || true

# 3. Install the Shortcut
if [ -f "$SHORTCUT_PATH" ]; then
    echo "Installing Shortcut (click 'Add Shortcut' when prompted)..."
    "${AS_USER[@]}" open "$SHORTCUT_PATH"
    echo "Waiting for Shortcut to be added..."
    sleep 3
else
    echo "WARNING: Shortcut not found at $SHORTCUT_PATH. Please install manually."
fi

# 4. Install the watcher script
echo "Installing watcher script..."
mkdir -p "$USER_HOME/Library/Scripts"
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
[ -n "$CHOWN" ] && chown "$CHOWN" "$WATCHER_SCRIPT"

# 5. Install and load the Launch Agent
echo "Installing Launch Agent..."
mkdir -p "$USER_HOME/Library/LaunchAgents"
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
    <string>$USER_HOME/Library/Logs/rename-screenshot.log</string>
    <key>StandardErrorPath</key>
    <string>$USER_HOME/Library/Logs/rename-screenshot.log</string>
</dict>
</plist>
PLIST
[ -n "$CHOWN" ] && chown "$CHOWN" "$LAUNCH_AGENT_PLIST"

# Unload first if already running
"${LAUNCHCTL_CMD[@]}" unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
"${LAUNCHCTL_CMD[@]}" load "$LAUNCH_AGENT_PLIST"

echo
echo "Done! Screenshot location set to: $SCREENSHOTS_DIR"
echo
echo "Take a screenshot (Cmd+Shift+4) to test it!"
echo "Logs: $USER_HOME/Library/Logs/rename-screenshot.log"
