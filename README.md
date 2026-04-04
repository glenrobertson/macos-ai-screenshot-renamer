# macOS AI Screenshot Renamer

Use Apple Intelligence to automatically rename screenshots with descriptive filenames via Automator and Shortcuts.

Transform `Screenshot 2024-04-04 at 2.35.12 PM.png` into `xcode-debug-console-error-log.png`

![Demo](demo.gif)

## How It Works

1. **Automator Folder Action** watches `~/Screenshots` for new files
2. **Shortcut** sends the image to Apple Intelligence for analysis
3. Screenshot is renamed with an AI-generated description

## Requirements

- macOS 15.1+ (Sequoia) with Apple Intelligence enabled
- Apple Silicon Mac (M1 or later)

## Installation

```bash
git clone https://github.com/yourusername/macos-ai-screenshot-renamer.git
cd macos-ai-screenshot-renamer
./setup.sh
```

Click **"Add Shortcut"** when prompted, then grant any permissions in **System Settings > Privacy & Security**.

## What Setup Does

- Creates `~/Screenshots` directory
- Sets macOS to save screenshots there (`defaults write com.apple.screencapture location`)
- Installs the Automator Folder Action
- Imports the Shortcut
- Attaches the Folder Action to the Screenshots folder

## Test It

Take a screenshot with `Cmd + Shift + 4` and watch it rename automatically.

## Manual Installation

1. Set screenshot location:
   ```bash
   defaults write com.apple.screencapture location ~/Screenshots
   killall SystemUIServer
   ```

2. Copy `Rename Screenshot.workflow` to:
   ```
   ~/Library/Workflows/Applications/Folder Actions/
   ```

3. Double-click `Rename Screenshot.shortcut` to import

4. Right-click Screenshots folder → **Services** → **Folder Actions Setup** → attach the workflow

## License

MIT
