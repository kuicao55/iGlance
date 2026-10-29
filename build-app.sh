#!/bin/bash

# Build iGlance.app bundle
#
# This script builds the SPM target, assembles a .app bundle, writes the
# Info.plist, and (critically) re-signs the bundle so the Info.plist is bound
# to the executable. Without the final codesign step the binary is signed at
# link time as a standalone Mach-O; macOS then sees an "Info.plist=not bound"
# signature, drops LSUIElement, and the NSStatusItem ends up in the menu bar
# overflow area (or doesn't show at all).
#
# Output location: .build/release/iGlance.app — intentionally inside .build/
# (which is gitignored and excluded from Spotlight) so Launchpad never picks
# up a duplicate icon alongside /Applications/iGlance.app.
#
# Usage:
#   ./build-app.sh                 Ad-hoc signed dev build
#   ./build-app.sh --install       Also copy to /Applications
#   ./build-app.sh --release       Also produce dist/iGlance.app.zip for GitHub
#   ./build-app.sh --notarize      Notarize + staple (requires SIGN_IDENTITY
#                                  and NOTARY_PROFILE), then produce the ZIP
#
# Environment:
#   SIGN_IDENTITY   "Developer ID Application: Name (TEAMID)" for distribution.
#                   Defaults to "-" (ad-hoc, local use only).
#   NOTARY_PROFILE  notarytool keychain profile created with
#                   `xcrun notarytool store-credentials`.
#   MARKETING_VERSION / BUILD_NUMBER  Override the bundle version.

set -e

APP_BUNDLE=".build/release/iGlance.app"
MARKETING_VERSION="${MARKETING_VERSION:-0.2.2}"
BUILD_NUMBER="${BUILD_NUMBER:-4}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

INSTALL_TO_APPLICATIONS=false
MAKE_RELEASE=false
NOTARIZE=false

for arg in "$@"; do
    case "$arg" in
        --install) INSTALL_TO_APPLICATIONS=true ;;
        --release) MAKE_RELEASE=true ;;
        --notarize) NOTARIZE=true; MAKE_RELEASE=true ;;
        --help)
            sed -n '2,33p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

if [ "$NOTARIZE" = true ] && [ "$SIGN_IDENTITY" = "-" ]; then
    echo "error: --notarize needs SIGN_IDENTITY set to a Developer ID certificate." >&2
    exit 1
fi
if [ "$NOTARIZE" = true ] && [ -z "$NOTARY_PROFILE" ]; then
    echo "error: --notarize needs NOTARY_PROFILE set to a notarytool keychain profile." >&2
    exit 1
fi

echo "Building iGlance ${MARKETING_VERSION} (${BUILD_NUMBER})..."

# Clean previous build outputs
rm -rf .build/release
rm -rf "$APP_BUNDLE"

# Build release version
swift build -c release

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp .build/release/iGlance "$APP_BUNDLE/Contents/MacOS/"

# Copy assets (resource bundle emitted by SwiftPM)
cp -R .build/release/iGlance_iGlance.bundle "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true

# Copy app icon
cp Assets/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>iGlance</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.kui.iGlance</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>iGlance</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 kui. All rights reserved.</string>
</dict>
</plist>
EOF

# Re-sign the bundle. The linker-signed binary was created BEFORE the
# Info.plist existed, so its signature is "Info.plist=not bound" and macOS
# silently drops LSUIElement. Re-signing binds the plist to the bundle.
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "Re-signing bundle (ad-hoc)..."
    codesign --force --options runtime --sign - "$APP_BUNDLE"
else
    echo "Signing with: $SIGN_IDENTITY"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
fi

echo "Verifying signature..."
codesign --verify --deep --strict "$APP_BUNDLE"
codesign -dvv "$APP_BUNDLE" 2>&1 | grep -E "Identifier|Authority|TeamIdentifier|Signature" | head -6 || true

# Unregister the dev bundle from Launch Services. Even though the bundle
# lives under .build/ (Spotlight usually skips hidden dirs), `open` on the
# path will register it, so we strip the registration here.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -u "$PWD/$APP_BUNDLE" 2>/dev/null || true
fi

if [ "$NOTARIZE" = true ]; then
    echo ""
    echo "Submitting for notarization (profile: $NOTARY_PROFILE)..."
    mkdir -p dist
    rm -f dist/iGlance-notarize.zip
    ditto -c -k --keepParent "$APP_BUNDLE" dist/iGlance-notarize.zip
    xcrun notarytool submit dist/iGlance-notarize.zip \
        --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"
    echo "Notarization ticket stapled."
fi

if [ "$MAKE_RELEASE" = true ]; then
    mkdir -p dist
    rm -f dist/iGlance.app.zip
    ditto -c -k --keepParent "$APP_BUNDLE" dist/iGlance.app.zip
    echo ""
    echo "Release archive: dist/iGlance.app.zip"
    echo "Upload it as the asset for tag v${MARKETING_VERSION}:"
    echo "  gh release create v${MARKETING_VERSION} dist/iGlance.app.zip --title \"iGlance v${MARKETING_VERSION}\""
fi

if [ "$INSTALL_TO_APPLICATIONS" = true ]; then
    echo ""
    echo "Installing to /Applications..."
    rm -rf /Applications/iGlance.app
    cp -R "$APP_BUNDLE" /Applications/iGlance.app
    echo "Installed. Open with: open /Applications/iGlance.app"
else
    echo ""
    echo "Build complete! Bundle: $APP_BUNDLE"
    echo ""
    echo "  Run dev:    open $APP_BUNDLE"
    echo "  Install:    cp -R $APP_BUNDLE /Applications/"
    echo "  Build+install:  ./build-app.sh --install"
    echo "  Release zip:    ./build-app.sh --release"
    echo ""
    echo "If the menu bar icon doesn't appear immediately:"
    echo "  1. Open System Settings -> Menu Bar"
    echo "  2. Add iGlance to the always-visible items"
    echo "  3. Or click the date/time to reveal hidden menu bar icons"
fi
