#!/bin/bash

# Test if iGlance icon is visible

echo "=== iGlance Icon Test ==="
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
echo "3. IMPORTANT: Check your menu bar now!"
echo ""
echo "   You should see a '◉' symbol in your menu bar."
echo "   (It's a circle with a dot inside)"
echo ""
echo "   If you see it, the app is working correctly!"
echo ""
echo "   If you DON'T see it, please:"
echo "   - Check if there are too many items in your menu bar"
echo "   - Try resizing your menu bar"
echo "   - Check System Settings > Privacy & Security"
echo ""

# Wait for user confirmation
echo "Press Enter when you've checked the menu bar..."
read -r

echo ""
echo "4. Cleaning up..."
kill $APP_PID 2>/dev/null
sleep 1

if ! ps -p $APP_PID > /dev/null 2>&1; then
    echo "   ✓ App terminated"
else
    echo "   ⚠ App may still be running"
fi

echo ""
echo "Test complete!"
