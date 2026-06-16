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
# Pass --install to also copy the bundle to /Applications and register it
# with Launch Services.

set -e

APP_BUNDLE=".build/release/iGlance.app"
INSTALL_TO_APPLICATIONS=false
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL_TO_APPLICATIONS=true ;;
    esac
done

echo "Building iGlance..."

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

# Copy app icon (Liquid Glass)
cp Assets/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
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
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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
# silently drops LSUIElement. An ad-hoc re-sign with --options runtime binds
# the plist to the bundle.
echo "Re-signing bundle..."
codesign --force --sign - --options runtime --timestamp=none "$APP_BUNDLE"

# Verify the signature
echo "Verifying signature..."
codesign -dvv "$APP_BUNDLE" 2>&1 | head -5

# Unregister the dev bundle from Launch Services. Even though the bundle
# lives under .build/ (Spotlight usually skips hidden dirs), `open` on the
# path will register it, so we strip the registration here. /Applications
# stays untouched. If lsregister isn't present (rare) skip silently — the
# build itself already succeeded.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -u "$PWD/$APP_BUNDLE" 2>/dev/null || true
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
    echo ""
    echo "If the menu bar icon doesn't appear immediately:"
    echo "  1. Open System Settings -> Menu Bar"
    echo "  2. Add iGlance to the always-visible items"
    echo "  3. Or click the date/time to reveal hidden menu bar icons"
fi