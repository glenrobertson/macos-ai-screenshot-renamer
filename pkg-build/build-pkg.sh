#!/bin/bash
# Build macOS .pkg installers for Screenshot Renamer
# Produces:
#   Screenshot-Renamer.pkg          (installer)
#   Uninstall-Screenshot-Renamer.pkg (uninstaller)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/out"
IDENTIFIER="nz.glen.screenshot-renamer"
VERSION="1.0"

# Signing & notarization (opt-in: SIGN=1 ./build-pkg.sh)
# Requires:
#   - "Developer ID Installer" cert in Keychain
#   - Notarization credentials stored via:
#     xcrun notarytool store-credentials "notary-gxlabs" \
#         --apple-id <apple-id> --team-id 57MXTRM398 --password <app-specific-pw>
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Installer: gxlabs LLC (57MXTRM398)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary-gxlabs}"

SIGN_ARGS=()
if [[ "$SIGN" == "1" ]]; then
    echo "Signing enabled (identity: $SIGN_IDENTITY)"
    SIGN_ARGS=(--sign "$SIGN_IDENTITY")
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --- Install PKG ---

# Prepare payload: shortcut + install.sh in a staging directory
PAYLOAD_DIR="$BUILD_DIR/payload"
mkdir -p "$PAYLOAD_DIR/usr/local/share/screenshot-renamer"
cp "$PROJECT_DIR/Rename Screenshot.shortcut" "$PAYLOAD_DIR/usr/local/share/screenshot-renamer/"
cp "$PROJECT_DIR/install.sh" "$PAYLOAD_DIR/usr/local/share/screenshot-renamer/"
cp "$PROJECT_DIR/uninstall.sh" "$PAYLOAD_DIR/usr/local/share/screenshot-renamer/"
chmod +x "$PAYLOAD_DIR/usr/local/share/screenshot-renamer/install.sh"
chmod +x "$PAYLOAD_DIR/usr/local/share/screenshot-renamer/uninstall.sh"

# Make scripts executable
chmod +x "$SCRIPT_DIR/scripts/postinstall"

# Build the component pkg
pkgbuild \
    --root "$PAYLOAD_DIR" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --scripts "$SCRIPT_DIR/scripts" \
    "${SIGN_ARGS[@]}" \
    "$BUILD_DIR/Screenshot-Renamer.pkg"

echo "Built: $BUILD_DIR/Screenshot-Renamer.pkg"

# --- Uninstall PKG ---

# Prepare payload: uninstall.sh in a staging directory
UNINSTALL_PAYLOAD_DIR="$BUILD_DIR/payload-uninstall"
mkdir -p "$UNINSTALL_PAYLOAD_DIR/usr/local/share/screenshot-renamer"
cp "$PROJECT_DIR/uninstall.sh" "$UNINSTALL_PAYLOAD_DIR/usr/local/share/screenshot-renamer/"

chmod +x "$SCRIPT_DIR/scripts-uninstall/postinstall"

pkgbuild \
    --root "$UNINSTALL_PAYLOAD_DIR" \
    --identifier "$IDENTIFIER.uninstall" \
    --version "$VERSION" \
    --scripts "$SCRIPT_DIR/scripts-uninstall" \
    "${SIGN_ARGS[@]}" \
    "$BUILD_DIR/Uninstall-Screenshot-Renamer.pkg"

echo "Built: $BUILD_DIR/Uninstall-Screenshot-Renamer.pkg"

# Notarize & staple if signing is enabled
if [[ "$SIGN" == "1" ]]; then
    echo
    echo "Submitting packages for notarization..."
    for pkg in "$BUILD_DIR/Screenshot-Renamer.pkg" "$BUILD_DIR/Uninstall-Screenshot-Renamer.pkg"; do
        echo "Notarizing: $pkg"
        xcrun notarytool submit "$pkg" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$pkg"
        echo "Notarized and stapled: $pkg"
    done
fi

echo
echo "Done! Packages are in: $BUILD_DIR/"
