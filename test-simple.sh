#!/bin/bash

# Simple test to verify iGlance works

echo "Testing iGlance..."
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
echo "3. Please check your menu bar now!"
echo "   You should see a small circle icon."
echo ""
echo "   Press Enter when ready to continue..."
read

# Cleanup
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
