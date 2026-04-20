#!/bin/bash
# Build macOS .pkg installers for Screenshot Renamer
# Produces:
#   Screenshot Renamer.pkg          (installer)
#   Uninstall Screenshot Renamer.pkg (uninstaller)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/out"
IDENTIFIER="nz.glen.screenshot-renamer"
VERSION="1.0"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- Install PKG ---

# Prepare payload: just the .shortcut file in a staging directory
PAYLOAD_DIR="$BUILD_DIR/payload"
mkdir -p "$PAYLOAD_DIR/usr/local/share/screenshot-renamer"
cp "$PROJECT_DIR/Rename Screenshot.shortcut" "$PAYLOAD_DIR/usr/local/share/screenshot-renamer/"

# Make scripts executable
chmod +x "$SCRIPT_DIR/scripts/postinstall"

# Build the component pkg
pkgbuild \
    --root "$PAYLOAD_DIR" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --scripts "$SCRIPT_DIR/scripts" \
    "$BUILD_DIR/Screenshot Renamer.pkg"

echo "Built: $BUILD_DIR/Screenshot Renamer.pkg"

# --- Uninstall PKG ---

# Uninstaller is script-only (nopayload)
chmod +x "$SCRIPT_DIR/scripts-uninstall/postinstall"

pkgbuild \
    --nopayload \
    --identifier "$IDENTIFIER.uninstall" \
    --version "$VERSION" \
    --scripts "$SCRIPT_DIR/scripts-uninstall" \
    "$BUILD_DIR/Uninstall Screenshot Renamer.pkg"

echo "Built: $BUILD_DIR/Uninstall Screenshot Renamer.pkg"

echo
echo "Done! Packages are in: $BUILD_DIR/"
