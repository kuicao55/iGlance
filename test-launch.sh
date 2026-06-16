#!/bin/bash

# Test iGlance launch and UI functionality

echo "=== iGlance Launch Test ==="
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
echo "3. Checking menu bar presence..."
echo "   (Please check your menu bar for an eye-like icon)"

# Wait for user to verify
sleep 2

echo ""
echo "4. Testing process stability..."
sleep 5

if ps -p $APP_PID > /dev/null 2>&1; then
    echo "   ✓ App is stable"
else
    echo "   ✗ App crashed"
    exit 1
fi

echo ""
echo "5. Testing power assertions..."
# Test if we can interact with power management
pmset -g | head -5 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ Power management accessible"
else
    echo "   ⚠ Power management not accessible"
fi

echo ""
echo "6. Testing system info..."
CPU_MODEL=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
if [ -n "$CPU_MODEL" ]; then
    echo "   ✓ CPU info available: $CPU_MODEL"
else
    echo "   ⚠ CPU info not available"
fi

echo ""
echo "7. Cleaning up..."
kill $APP_PID 2>/dev/null
sleep 1

if ! ps -p $APP_PID > /dev/null 2>&1; then
    echo "   ✓ App terminated cleanly"
else
    echo "   ⚠ App may still be running"
fi

echo ""
echo "=== Test Complete ==="
echo ""
echo "If you did NOT see an icon in your menu bar,"
echo "please run the app manually and check Console.app for errors:"
echo ""
echo "  open .build/debug/iGlance"
echo ""
echo "Or check system logs:"
echo "  log show --predicate 'process == \"iGlance\"' --last 1m"
