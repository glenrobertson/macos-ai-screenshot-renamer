#!/bin/bash
# Install Screenshot Renamer.
# Works both as a normal user (CLI install) and as root (pkg postinstall).
# Usage: install.sh [shortcut_path]
# Set SCREENSHOTS_DIR in the environment to skip the directory prompt.

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
DEFAULT_SCREENSHOTS_DIR="$USER_HOME/Screenshots"
WATCHER_SCRIPT="$USER_HOME/Library/Scripts/rename-new-screenshots.sh"
LAUNCH_AGENT_PLIST="$USER_HOME/Library/LaunchAgents/nz.glen.screenshot-renamer.plist"
LAUNCH_AGENT_LABEL="nz.glen.screenshot-renamer"

echo "Screenshot Renamer Setup"
echo "========================"
echo

# 1. Ask the user where screenshots should live.
#    - Env var SCREENSHOTS_DIR wins (scripted installs).
#    - Interactive terminal: read with default.
#    - No TTY (pkg postinstall runs as root, no stdin): AppleScript dialog as the console user.
#    Only files matching "Screenshot *.png" are ever renamed, so choosing a shared
#    folder like ~/Desktop won't touch unrelated files.
if [ -z "$SCREENSHOTS_DIR" ]; then
    if [ -t 0 ]; then
        printf "Where should screenshots be saved? [%s]: " "$DEFAULT_SCREENSHOTS_DIR"
        read -r SCREENSHOTS_DIR
    else
        SCREENSHOTS_DIR=$("${AS_USER[@]}" /usr/bin/osascript <<OSA 2>/dev/null || true
try
    set reply to text returned of (display dialog "Folder to save screenshots in:" default answer "$DEFAULT_SCREENSHOTS_DIR" with title "Screenshot Renamer")
    return reply
on error number -128
    return ""
end try
OSA
)
    fi
fi
SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$DEFAULT_SCREENSHOTS_DIR}"
# Expand leading ~ to the user's home
case "$SCREENSHOTS_DIR" in
    "~") SCREENSHOTS_DIR="$USER_HOME" ;;
    "~/"*) SCREENSHOTS_DIR="$USER_HOME/${SCREENSHOTS_DIR#~/}" ;;
esac
# Strip trailing slash
SCREENSHOTS_DIR="${SCREENSHOTS_DIR%/}"

echo "Using screenshots directory: $SCREENSHOTS_DIR"

# Create the directory if it doesn't exist
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
cat > "$WATCHER_SCRIPT" <<WATCHER
#!/bin/zsh
# Called by launchd WatchPaths whenever the screenshots dir changes.
# Finds screenshots that still have the default macOS name and renames them
# via the "Rename Screenshot" Shortcut. The "Screenshot *.png" glob is the
# guard that keeps unrelated files in a shared folder (e.g. ~/Desktop) safe.

SCREENSHOTS_DIR="$SCREENSHOTS_DIR"
TIMESTAMP_FILE="\$HOME/Library/Scripts/.rename-screenshot-lastrun"
LOCK_DIR="\$HOME/Library/Scripts/.rename-screenshot.lock"

if [[ ! -f "\$TIMESTAMP_FILE" ]]; then
    touch -t 197001010000 "\$TIMESTAMP_FILE"
fi

# WatchPaths fires multiple fsevents per screenshot save. Without a lock the
# parallel runs race the Shortcut's move and produce "item with the same
# name already exists" errors. Stale locks >5min get reclaimed.
if ! mkdir "\$LOCK_DIR" 2>/dev/null; then
    if [[ -z \$(find "\$LOCK_DIR" -maxdepth 0 -mmin -5 2>/dev/null) ]]; then
        rmdir "\$LOCK_DIR" 2>/dev/null
        mkdir "\$LOCK_DIR" 2>/dev/null || exit 0
    else
        exit 0
    fi
fi
trap 'rmdir "\$LOCK_DIR" 2>/dev/null' EXIT INT TERM

sleep 2

# Loop so screenshots arriving while the Shortcut is running are still
# picked up. MARKER bounds each pass so files landing after find but before
# the timestamp advance aren't skipped.
while :; do
    MARKER=\$(mktemp)
    found=0
    while IFS= read -r file; do
        [[ -f "\$file" ]] || continue
        shortcuts run "Rename Screenshot" --input-path "\$file" >/dev/null
        found=1
    done < <(find "\$SCREENSHOTS_DIR" -maxdepth 1 -name "Screenshot *.png" -newer "\$TIMESTAMP_FILE" ! -newer "\$MARKER")
    touch -r "\$MARKER" "\$TIMESTAMP_FILE"
    rm -f "\$MARKER"
    (( found == 0 )) && break
done
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
