#!/bin/bash

# Build iGlance.app bundle
#
# This script builds the SPM target, assembles a .app bundle, writes the
# Info.plist, and (critically) re-signs the bundle so the Info.plist is bound
# to the executable. Without the final codesign step the binary is signed at
# link time as a standalone Mach-O; macOS then sees an "Info.plist=not bound"
# signature, drops LSUIElement, and the NSStatusItem ends up in the menu bar
# overflow area (or doesn't show at all).

set -e

echo "Building iGlance..."

# Clean previous builds
rm -rf .build/release
rm -rf iGlance.app

# Build release version
swift build -c release

# Create app bundle structure
mkdir -p iGlance.app/Contents/MacOS
mkdir -p iGlance.app/Contents/Resources

# Copy executable
cp .build/release/iGlance iGlance.app/Contents/MacOS/

# Copy assets (resource bundle emitted by SwiftPM)
cp -R .build/release/iGlance_iGlance.bundle iGlance.app/Contents/Resources/ 2>/dev/null || true

# Create Info.plist
cat > iGlance.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>iGlance</string>
    <key>CFBundleIconFile</key>
    <string></string>
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
codesign --force --sign - --options runtime --timestamp=none iGlance.app

# Verify the signature
echo "Verifying signature..."
codesign -dvv iGlance.app 2>&1 | head -5

echo ""
echo "Build complete! iGlance.app is ready."
echo ""
echo "To run: open iGlance.app"
echo "To install: drag iGlance.app to /Applications"
echo ""
echo "If the menu bar icon doesn't appear immediately:"
echo "  1. Open System Settings -> Menu Bar"
echo "  2. Add iGlance to the always-visible items"
echo "  3. Or click the date/time to reveal hidden menu bar icons"
