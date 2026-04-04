#!/bin/bash

set -e

SCREENSHOTS_DIR="$HOME/Screenshots"
WORKFLOW_NAME="Rename Screenshot.workflow"
SHORTCUT_NAME="Rename Screenshot.shortcut"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# 3. Install the Folder Action workflow
echo "Installing Folder Action workflow..."
WORKFLOW_DEST="$HOME/Library/Workflows/Applications/Folder Actions"
mkdir -p "$WORKFLOW_DEST"
cp -R "$SCRIPT_DIR/$WORKFLOW_NAME" "$WORKFLOW_DEST/"

# 4. Install the Shortcut
SHORTCUT_PATH="$SCRIPT_DIR/$SHORTCUT_NAME"
if [ -f "$SHORTCUT_PATH" ]; then
    echo "Installing Shortcut (click 'Add Shortcut' when prompted)..."
    open "$SHORTCUT_PATH"
    echo "Waiting for Shortcut to be added..."
    sleep 3
else
    echo "WARNING: $SHORTCUT_NAME not found. Please install manually."
fi

# 5. Enable Folder Actions and attach to Screenshots folder
echo "Enabling Folder Actions..."
osascript <<EOF
tell application "System Events"
    set folder actions enabled to true
end tell
EOF

# Attach the folder action to the Screenshots directory
osascript <<EOF
tell application "System Events"
    set screenshotsFolder to POSIX file "$SCREENSHOTS_DIR" as alias
    set workflowPath to POSIX file "$WORKFLOW_DEST/$WORKFLOW_NAME" as alias

    try
        make new folder action with properties {name:"$SCREENSHOTS_DIR", path:screenshotsFolder}
    end try

    tell folder action "$SCREENSHOTS_DIR"
        try
            make new script with properties {name:"$WORKFLOW_NAME", path:workflowPath}
        end try
    end tell
end tell
EOF

echo
echo "Done! Screenshot location set to: $SCREENSHOTS_DIR"
echo
echo "You may need to grant permissions in System Settings > Privacy & Security."
echo "Take a screenshot (Cmd+Shift+4) to test it!"
