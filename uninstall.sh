#!/bin/bash
# Uninstall Screenshot Renamer.
# Works both as a normal user (CLI uninstall) and as root (pkg postinstall).

set -e

# Detect context: running as root (pkg postinstall) vs normal user
if [ "$(id -u)" -eq 0 ]; then
    CURRENT_USER=$( /usr/bin/stat -f "%Su" /dev/console )
    USER_HOME=$( /usr/bin/dscl . -read /Users/"$CURRENT_USER" NFSHomeDirectory | /usr/bin/awk '{print $NF}' )
    CURRENT_USER_UID=$( /usr/bin/id -u "$CURRENT_USER" )
    AS_USER=(/usr/bin/sudo -u "$CURRENT_USER")
    LAUNCHCTL_CMD=(/bin/launchctl asuser "$CURRENT_USER_UID" /bin/launchctl)
else
    USER_HOME="$HOME"
    AS_USER=()
    LAUNCHCTL_CMD=(launchctl)
fi

LAUNCH_AGENT_PLIST="$USER_HOME/Library/LaunchAgents/nz.glen.screenshot-renamer.plist"

echo "Screenshot Renamer Uninstall"
echo "============================"
echo

# Recover the screenshots dir the user picked at install time, so we can restore
# the macOS default location correctly. Falls back to ~/Screenshots.
SCREENSHOTS_DIR=""
if [ -f "$LAUNCH_AGENT_PLIST" ]; then
    SCREENSHOTS_DIR=$(/usr/libexec/PlistBuddy -c "Print :WatchPaths:0" "$LAUNCH_AGENT_PLIST" 2>/dev/null || true)
fi
SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$USER_HOME/Screenshots}"

# Unload and remove Launch Agent
if [ -f "$LAUNCH_AGENT_PLIST" ]; then
    echo "Unloading Launch Agent..."
    "${LAUNCHCTL_CMD[@]}" unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
    rm "$LAUNCH_AGENT_PLIST"
    echo "Removed $LAUNCH_AGENT_PLIST"
fi

# Remove watcher script and timestamp file
rm -f "$USER_HOME/Library/Scripts/rename-new-screenshots.sh"
rm -f "$USER_HOME/Library/Scripts/.rename-screenshot-lastrun"
echo "Removed watcher script"

# Reset screenshot location to default Desktop
echo "Resetting screenshot location to Desktop..."
"${AS_USER[@]}" defaults write com.apple.screencapture location "$USER_HOME/Desktop"
killall SystemUIServer 2>/dev/null || true

# Clean up any leftover staging from pkg install. May fail if invoked
# without root (e.g. direct CLI run) — harmless either way.
rm -rf /usr/local/share/screenshot-renamer 2>/dev/null || true

echo
echo "Done."
echo "The 'Rename Screenshot' Shortcut and $SCREENSHOTS_DIR were not removed."
echo "Delete them manually if you no longer need them."
