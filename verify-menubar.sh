#!/bin/bash

# Menu Bar Icon Verification Script

echo "=========================================="
echo "  iGlance Menu Bar Verification"
echo "=========================================="
echo ""

# Kill existing instances
pkill -f "iGlance" 2>/dev/null
sleep 1

# Build
echo "1. Building iGlance..."
swift build 2>&1 | grep -q "Build complete"
if [ $? -ne 0 ]; then
    echo "✗ Build failed"
    exit 1
fi
echo "✓ Build successful"

# Launch as .app bundle
echo ""
echo "2. Creating app bundle..."
rm -rf iGlance.app
./build-app.sh 2>&1 | grep -q "Build complete"
echo "✓ App bundle created"

# Run the app
echo ""
echo "3. Launching iGlance.app..."
open iGlance.app
sleep 3

# Check if running
if pgrep -f "iGlance.app/Contents/MacOS/iGlance" > /dev/null; then
    echo "✓ App is running"
else
    echo "✗ App failed to start"
    exit 1
fi

# Take screenshot
echo ""
echo "4. Taking screenshot..."
screencapture -x /tmp/iglance_verification.png

if [ -f "/tmp/iglance_verification.png" ]; then
    SIZE=$(ls -la /tmp/iglance_verification.png | awk '{print $5}')
    echo "✓ Screenshot saved ($SIZE bytes)"

    # Open screenshot
    echo ""
    echo "5. Opening screenshot..."
    open /tmp/iglance_verification.png
    echo "✓ Screenshot opened"
else
    echo "✗ Failed to take screenshot"
fi

echo ""
echo "=========================================="
echo "  Verification Steps"
echo "=========================================="
echo ""
echo "The screenshot has been opened."
echo ""
echo "Please check the TOP-RIGHT area of the screen"
echo "(this is where the menu bar icon should appear)"
echo ""
echo "You should see one of:"
echo "  - An eye icon"
echo "  - A circle symbol"
echo "  - '◉' text"
echo ""
echo "If you see the icon: The app is working correctly!"
echo "If you DON'T see the icon: Please describe what you see"
echo ""
echo "=========================================="
