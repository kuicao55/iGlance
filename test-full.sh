#!/bin/bash

# Full iGlance test

echo "=== iGlance Full Test ==="
echo ""

# Kill existing
pkill -f "iGlance" 2>/dev/null
sleep 1

# Build
echo "1. Building..."
swift build 2>&1 | grep -E "(Build complete|error)"
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi
echo "   ✓ Build successful"

# Launch
echo ""
echo "2. Launching app..."
.build/debug/iGlance &
APP_PID=$!
sleep 3

# Check if running
if ps -p $APP_PID > /dev/null 2>&1; then
    echo "   ✓ App is running (PID: $APP_PID)"
else
    echo "   ✗ App failed to start"
    exit 1
fi

echo ""
echo "3. Menu Bar Test"
echo "   Please check your menu bar for '◉' symbol."
echo "   Press Enter when you've verified..."
read -r

echo ""
echo "4. Click Test"
echo "   Click the '◉' symbol in your menu bar."
echo "   A popover should appear with Monitor/Status/Tasks tabs."
echo "   Press Enter when you've tested..."
read -r

echo ""
echo "5. Stability Test"
echo "   Let the app run for 10 seconds..."
sleep 10

if ps -p $APP_PID > /dev/null 2>&1; then
    echo "   ✓ App is stable"
else
    echo "   ✗ App crashed"
    exit 1
fi

echo ""
echo "6. Cleanup Test"
echo "   Stopping app..."
kill $APP_PID 2>/dev/null
sleep 2

if ! ps -p $APP_PID > /dev/null 2>&1; then
    echo "   ✓ App terminated cleanly"
else
    echo "   ⚠ App may still be running"
fi

echo ""
echo "=== Test Complete ==="
echo ""
echo "If all tests passed, the app is working correctly!"
echo ""
echo "To install permanently:"
echo "  1. Build release: ./build-app.sh"
echo "  2. Copy to Applications: cp -R iGlance.app /Applications/"
echo "  3. Add to Login Items for auto-start"
