#!/bin/bash

set -e

LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/nz.glen.screenshot-renamer.plist"

echo "Screenshot Renamer Uninstall"
echo "============================"
echo

# Unload and remove Launch Agent
if [ -f "$LAUNCH_AGENT_PLIST" ]; then
    echo "Unloading Launch Agent..."
    launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
    rm "$LAUNCH_AGENT_PLIST"
    echo "Removed $LAUNCH_AGENT_PLIST"
fi

# Remove watcher script and timestamp file
rm -f "$HOME/Library/Scripts/rename-new-screenshots.sh"
rm -f "$HOME/Library/Scripts/.rename-screenshot-lastrun"
echo "Removed watcher script"

# Reset screenshot location to default Desktop
echo "Resetting screenshot location to Desktop..."
defaults write com.apple.screencapture location ~/Desktop
killall SystemUIServer 2>/dev/null || true

echo
echo "Done."
echo "The 'Rename Screenshot' Shortcut and ~/Screenshots folder were not removed."
echo "Delete them manually if you no longer need them."
