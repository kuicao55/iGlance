#!/bin/bash

# Simple verification script for iGlance

echo "=== iGlance Verification ==="
echo ""

PASS=0
FAIL=0

check() {
    if eval "$1" > /dev/null 2>&1; then
        echo "✓ $2"
        ((PASS++))
        return 0
    else
        echo "✗ $2"
        ((FAIL++))
        return 1
    fi
}

# Build check
echo "--- Build Verification ---"
check "swift build" "Project builds successfully"
check "[ -d iGlance.app ]" "App bundle exists"
check "[ -x iGlance.app/Contents/MacOS/iGlance ]" "Executable is valid"
check "grep -q LSUIElement iGlance.app/Contents/Info.plist" "No Dock icon configured"

echo ""
echo "--- Launch Test ---"

# Kill existing
pkill -f "iGlance.app" 2>/dev/null
sleep 1

# Launch
open iGlance.app
sleep 3

check "pgrep -f iGlance.app/Contents/MacOS/iGlance" "App is running"

PID=$(pgrep -f "iGlance.app/Contents/MacOS/iGlance" 2>/dev/null)
if [ -n "$PID" ]; then
    MEM=$(ps -o rss= -p $PID | tr -d ' ')
    MEM_MB=$((MEM / 1024))
    echo "   Memory usage: ${MEM_MB}MB"
fi

echo ""
echo "--- Stability Test ---"
echo "Running for 10 seconds..."
sleep 10

check "pgrep -f iGlance.app" "App stable after 10 seconds"

echo ""
echo "--- Data Provider Tests ---"
check "sysctl -n machdep.cpu.brand_string" "CPU model available"
check "sysctl -n hw.memsize" "Memory info available"
check "pmset -g" "Power management available"

echo ""
echo "--- Cleanup ---"
pkill -f "iGlance.app" 2>/dev/null
sleep 1
check "! pgrep -f iGlance.app" "App terminated cleanly"

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ $FAIL -eq 0 ]; then
    echo ""
    echo "All automated checks passed!"
    echo ""
    echo "Manual verification needed:"
    echo "1. Run: open iGlance.app"
    echo "2. Check menu bar for icon"
    echo "3. Click icon - popover should open"
    echo "4. Verify 3 tabs: Monitor, Status, Tasks"
    echo "5. Monitor: 4 cards in 2x2 grid"
    echo "6. Click CPU/GPU/Memory cards - should flip"
    echo "7. Status: toggle sleep prevention switches"
    echo "8. Tasks: should show scheduled jobs"
    echo "9. Click outside - popover should close"
    echo "10. Icon should update based on system load"
    exit 0
else
    echo ""
    echo "Some checks failed!"
    exit 1
fi
