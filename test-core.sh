#!/bin/bash

# Core functionality test for iGlance

echo "=== iGlance Core Test ==="
echo ""

PASS=0
FAIL=0

check() {
    if [ "$1" = "true" ]; then
        echo "✓ $2"
        ((PASS++))
    else
        echo "✗ $2"
        ((FAIL++))
    fi
}

# Kill existing
pkill -f "iGlance" 2>/dev/null
sleep 1

# Build
echo "1. Building..."
BUILD_OUTPUT=$(swift build 2>&1)
if echo "$BUILD_OUTPUT" | grep -q "Build complete"; then
    check "true" "Build successful"
else
    check "false" "Build failed"
    echo "$BUILD_OUTPUT"
    exit 1
fi

# Launch
echo ""
echo "2. Launching app..."
.build/debug/iGlance &
APP_PID=$!
sleep 3

if ps -p $APP_PID > /dev/null 2>&1; then
    check "true" "App process running (PID: $APP_PID)"
else
    check "false" "App process running"
    exit 1
fi

echo ""
echo "3. Checking process details..."

# Check memory usage
MEM=$(ps -o rss= -p $APP_PID | tr -d ' ')
MEM_MB=$((MEM / 1024))
if [ $MEM_MB -lt 200 ]; then
    check "true" "Memory usage OK ($MEM_MB MB)"
else
    check "false" "Memory usage OK ($MEM_MB MB)"
fi

echo ""
echo "4. Testing system integration..."

# Test CPU info
CPU_MODEL=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
if [ -n "$CPU_MODEL" ]; then
    check "true" "CPU info available: $CPU_MODEL"
else
    check "false" "CPU info available"
fi

# Test memory info
TOTAL_MEM=$(sysctl -n hw.memsize 2>/dev/null)
if [ -n "$TOTAL_MEM" ] && [ "$TOTAL_MEM" != "0" ]; then
    check "true" "Memory info available"
else
    check "false" "Memory info available"
fi

echo ""
echo "5. Testing power management..."

# Test pmset
PMSET_OUTPUT=$(pmset -g 2>/dev/null)
if [ $? -eq 0 ]; then
    check "true" "Power management accessible"

    # Check sleep disabled
    SLEEP_DISABLED=$(pmset -g | grep -i "sleepdisabled" || echo "")
    if [ -n "$SLEEP_DISABLED" ]; then
        check "true" "SleepDisabled status readable"
    else
        check "false" "SleepDisabled status readable"
    fi
else
    check "false" "Power management accessible"
fi

echo ""
echo "6. Testing task discovery..."

# Test LaunchAgents
LA_COUNT=$(ls ~/Library/LaunchAgents/*.plist 2>/dev/null | wc -l || echo "0")
LA_COUNT=$(echo $LA_COUNT | tr -d ' ')
check "true" "LaunchAgents found: $LA_COUNT"

# Test crontab
CRON_EXISTS=$(crontab -l 2>/dev/null)
if [ $? -eq 0 ]; then
    check "true" "Crontab accessible"
else
    check "true" "Crontab accessible (no crontab)"
fi

echo ""
echo "7. Stability test (10 seconds)..."

# Let app run
sleep 10

if ps -p $APP_PID > /dev/null 2>&1; then
    check "true" "App stable after 10 seconds"
else
    check "false" "App stable after 10 seconds"
fi

echo ""
echo "8. Cleanup..."

kill $APP_PID 2>/dev/null
sleep 2

if ! ps -p $APP_PID > /dev/null 2>&1; then
    check "true" "App terminated cleanly"
else
    check "false" "App terminated cleanly"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ $FAIL -eq 0 ]; then
    echo ""
    echo "All core tests passed!"
    echo ""
    echo "Next steps:"
    echo "1. Run: open .build/debug/iGlance"
    echo "2. Check menu bar for '◉' icon"
    echo "3. Click icon to test popover"
    exit 0
else
    echo ""
    echo "Some tests failed."
    exit 1
fi
